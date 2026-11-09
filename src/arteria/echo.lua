-- Soup echo cycle, with explicit slot consent and locally guarded continuation.
local Scope = require("@src/arteria/scope")
local Transfer = require("@src/arteria/echo_transfer")
local Echo = {}
Echo.__index = Echo
local STATE = "Arteria/echo-session.json"
local BOOTSTRAP = "Arteria/bootstrap.lua"
local function read_state()
    local ok, result = pcall(function()
        if not isfile(STATE) then return {} end
        return game:GetService("HttpService"):JSONDecode(readfile(STATE))
    end)
    return ok and type(result) == "table" and result or {}
end
local function save(state)
    if not isfolder("Arteria") then makefolder("Arteria") end
    writefile(STATE, game:GetService("HttpService"):JSONEncode(state))
end
local function decode(payload)
    local encoding = game:GetService("EncodingService")
    return buffer.tostring(encoding:DecompressBuffer(encoding:Base64Decode(buffer.fromstring(payload)), Enum.CompressionAlgorithm.Zstd))
end
function Echo.new(runtime, prepare)
    local self = setmetatable({ runtime = runtime, prepare = prepare, session = read_state(),
        running = false, state = "idle", owned = {}, resume_authorized = getgenv().Arteria_resume_requested == true }, Echo)
    getgenv().Arteria_resume_requested = nil
    -- Never honor another farm's flags or a malformed saved session.
    local s = self.session
    if s.mode ~= "soup" or type(s.token) ~= "string" or type(s.slot) ~= "string" then self.session = {} end
    if type(self.session.transfer_error) == "string" then self.error = self.session.transfer_error; self.state = "transfer failed" end
    return self
end
function Echo:refresh()
    if self.runtime.alive and self.runtime.refresh then self.runtime.refresh() end
end
function Echo:guard(source)
    return string.format([[
local ok, session = pcall(function()
    return game:GetService("HttpService"):JSONDecode(readfile(%q))
end)
if not ok or not session.enabled or session.token ~= %q then return end
]], STATE, self.session.token) .. source
end
function Echo:queue(source)
    assert(self.running and self.scope.active, "Echo farm stopped")
    local queue = queue_on_teleport or queueonteleport
    assert(type(queue) == "function", "Executor does not support teleport continuation")
    queue(self:guard(source))
end
function Echo:queue_bootstrap()
    local queue = queue_on_teleport or queueonteleport
    assert(type(queue) == "function", "Executor does not support teleport continuation")
    assert(isfile(BOOTSTRAP), "Local Arteria bootstrap is missing; inject the rebuilt bundle")
    queue(self:guard(string.format('getgenv().Arteria_resume_requested = true; assert(loadstring(readfile(%q), "=arteria-resume"))()', BOOTSTRAP)))
end
function Echo:stop(reason, preserve)
    if not preserve then
        self.resume_authorized = false
        self.session.enabled = false
        local ok, err = pcall(save, self.session)
        if not ok then self.error = "Could not invalidate queued continuation: " .. tostring(err) end
    end
    self.running = false
    if self.scope then
        self.scope:stop()
        if getgenv().persistent_data == self.scope.store then getgenv().persistent_data = self.previous_store end
        self.scope = nil
    end
    for id, value in pairs(self.owned) do self.runtime:set(id, value) end
    table.clear(self.owned)
    self.state = reason or "stopped"
    self:refresh()
end
function Echo:start(slot_confirmation, resuming)
    if self.running then return false end
    local runtime, env = self.runtime, getgenv()
    if runtime.status ~= "ready" or runtime.busy or not env.local_player.root_part then
        self.error = "Wait for the character and AC initialization."
        self:refresh()
        return false
    end
    local slot = tostring(env.local_player.instance:GetAttribute("DataSlot") or "")
    if slot == "" or slot_confirmation ~= slot or (resuming and self.session.slot ~= slot) then
        self.error = "Slot confirmation does not match the selected character."
        self:refresh()
        return false
    end
    local allowed = env.is_etrean or env.is_eastern or env.is_depths
    if not allowed then self.error = "Soup cycles require Etrean, Eastern, or the Depths."; self:refresh(); return false end
    self.error = nil
    runtime.busy = true
    self.state = "preparing"
    self:refresh()
    local ok, err = pcall(function()
        self.prepare(runtime)
        assert(runtime.alive, "Arteria was unloaded during farm preparation")
        env.StateMachine = require("@src/utility/statemachine")
        if env.Arteria_bootstrap_b64 then
            if not isfolder("Arteria") then makefolder("Arteria") end
            writefile(BOOTSTRAP, decode(env.Arteria_bootstrap_b64))
        end
        assert(isfile(BOOTSTRAP), "Inject the latest Arteria bundle before starting a farm")
        assert(type(queue_on_teleport or queueonteleport) == "function", "Teleport continuation is unavailable")
        if not resuming then
            self.session = { mode = "soup", slot = slot, token = game:GetService("HttpService"):GenerateGUID(false),
                enabled = true, started = os.time(), cycles = 0, echoes = 0 }
        end
        save(self.session)
        self.resume_authorized = true
        local scope = Scope.new()
        self.scope, self.running = scope, true
        scope.on_error = function(message)
            self.error = tostring(message)
            warn("[arteria] echo farm: " .. self.error)
            self:stop("error")
        end
        scope.queue = function(_, source) return self:queue(source) end
        scope.store = {
            get = function(_, key, fallback)
                if key == "soup_echo_farm_origin" then return "Etris" end
                local map = { cycle_count = "cycles", echoes_gained = "echoes", started_farm_at = "started", wiped_at = "wiped_at" }
                local value = self.session[map[key] or key]
                if value == nil then return fallback end
                return value
            end,
            set = function(_, key, value)
                local map = { cycle_count = "cycles", echoes_gained = "echoes", wiped_at = "wiped_at" }
                self.session[map[key] or key] = value
                save(self.session)
                self:refresh()
            end,
        }
        scope.Tween = { new = function(...)
            local tween = env.Tween.new(...)
            scope:track(function() tween.stop() end)
            return tween
        end }
        local function transition(slot_id, small, sound, wipe)
            assert(scope.active, "Echo farm stopped")
            scope:queue(Transfer.source(slot_id or slot, wipe, self.session.token, game.JobId))
            self.state = wipe and "wiping confirmed slot" or "changing server"
            self:refresh()
            scope.task.spawn(function()
                env.local_player.instance:Kick("arteria / echo cycle transfer")
                while scope.active do
                    game:GetService("TeleportService"):Teleport(4111023553)
                    scope.task.wait(1)
                end
            end)
        end
        scope.servers = {
            hop = function(_, slot_id, small, sound) transition(slot_id, small, sound, false) end,
            obliteration = function(_, slot_id) transition(slot_id, false, false, true) end,
        }
        self.previous_store = env.persistent_data
        env.persistent_data = scope.store
        local farm = require("@src/automation/persistent_tasks/soup_echofarm")
        assert(runtime.alive and scope.active, "Echo farm stopped during module initialization")
        farm:bind_scope(scope)
        self.farm = farm
        self:queue_bootstrap()
        runtime.busy = false
        -- Use the controller, not legacy struct:run(), to avoid duplicate
        -- connections and the old farm HUD. Restore prior values on Stop.
        for _, id in ipairs(farm.features) do
            self.owned[id] = runtime.flags[id] == true
            runtime:set(id, true)
            assert(runtime.alive and scope.active, "Echo farm stopped during dependency initialization")
            assert(runtime.flags[id], "Farm dependency unavailable: " .. id)
        end
        self.state = "running"
        scope.task.spawn(function() farm.state_machine:start() end)
        scope.task.spawn(function()
            while scope.active do self:refresh(); scope.task.wait(0.5) end
        end)
    end)
    runtime.busy = false
    if not ok then self.error = tostring(err); self:stop("error"); warn("[arteria] echo farm: " .. self.error) end
    self:refresh()
    return ok
end
function Echo:resume()
    if self.running or not self.session.enabled then return end
    if not self.resume_authorized then self.state = "confirmation required"; self:refresh(); return end
    if game.PlaceId == 4111023553 then
        local ok, err = pcall(function() self:queue_bootstrap() end)
        self.state = "waiting for world"
        if not ok then self.error = tostring(err) end
        self:refresh()
    elseif self.runtime.status == "ready" and getgenv().local_player.root_part then
        self:start(self.session.slot, true)
    end
end
return Echo
