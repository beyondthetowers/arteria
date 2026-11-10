-- Arteria has its own entry point. The complete legacy tree remains available.
if not game:IsLoaded() then game.Loaded:Wait() end
local env = getgenv()
if env.arteria then env.arteria:destroy() end
if env.aztup and env.aztup.detach then env.aztup:detach() end

require("@src/luarmor_init_script")
env.env = env
if not isfolder("Frutiger") then makefolder("Frutiger") end
local Maid = require("@src/utility/maid")
local catalog = require("@src/arteria/catalog")
local compat = require("@src/arteria/compat")
local runtime = {
    maid = Maid.new(), features = {}, flags = {
        fly = false, speed = false, infinite_jump = false,
        fly_speed = 60, walk_speed = 32, jump_power = 50,
    },
    farms = {}, silent_mode = true, alive = true, status = "loading", catalog = catalog,
    entries = {}, errors = {}, restorers = {}, brand = "arteria",
}
env.arteria = runtime
env.aztup = runtime -- Compatibility contract used by the retained modules.
runtime.automation = {
    has_any = function() return runtime.echo and runtime.echo.running or false end,
    should_auto_start = function() return runtime.echo and runtime.echo.session.enabled == true or false end,
}
env.Logger = require("@src/utility/logger")
env.Library = {
    AccentColor = Color3.fromRGB(222, 219, 210),
    AddTextToInfoLogger = function(_, message) print("[arteria]", message) end,
    Notify = function(_, message) warn("[arteria]", message) end,
    NotifyWithSound = function(_, message) warn("[arteria]", message) end,
}
env.Logger.notify_sound = function(_, message) warn("[arteria]", message) end
env.Logger.long_notify_sound = env.Logger.notify_sound
env.Feature = require("@src/features/generic_feature")
env.Tween = require("@src/utility/deepwoken/safe_tween")
env.aztup_toggles = {}
env.aztup_options = {}
compat.configure(runtime)
for _, entry in ipairs(catalog.entries) do
    runtime.entries[entry.id] = entry
    runtime.flags[entry.id] = false
    for _, option in ipairs(entry.settings) do
        runtime.flags[option.id] = option.value
        env.aztup_options[option.id] = { Value = option.value }
    end
    env.aztup_toggles[entry.id] = { SetValue = function(_, value) runtime:set(entry.id, value) end }
end
-- Fake void's original implementation requires this internal dependency.
runtime.entries.no_kill_bricks = { id = "no_kill_bricks", path = "@src/features/removals/no_kill_bricks", settings = {} }
env.aztup_toggles.no_kill_bricks = { SetValue = function(_, value) runtime:set("no_kill_bricks", value) end }
runtime.flags.no_kill_bricks = false
local farm_dependencies = {
    mod_detector = "@src/features/misc/mod_detector/mod_detector",
    jesus = "@src/features/qol/jesus",
    auto_equip_weapon = "@src/features/automation/auto_equip_weapon",
}
for id, path in pairs(farm_dependencies) do
    runtime.entries[id] = { id = id, path = path, settings = {} }
    runtime.flags[id] = false
    env.aztup_toggles[id] = { SetValue = function(_, value) runtime:set(id, value) end }
end

local player = services.Players.LocalPlayer
env.local_player = { instance = player }
local character_maid = Maid.new()
runtime.maid:give_task(character_maid)

function runtime:set(id, enabled)
    local entry = self.entries[id]
    if not self.alive or not entry or self.flags[id] == enabled then return end
    if enabled and (self.status ~= "ready" or self.busy) then return end
    if enabled and not env.local_player.root_part then return end
    if enabled and ((id == "fake_void" or id == "no_castle_light_gate" or id == "no_yun_shul_gate") and not env.is_depths
        or id == "no_hive_gate" and not env.is_eastern) then
        self.errors[id] = entry.note
        self.refresh()
        return
    end
    if entry.kind == "action" then
        self.busy = true
        self.refresh()
        local ok, err = pcall(function()
            compat.prepare(self)
            local action_fn = require(entry.path)
            if type(action_fn) == "function" then
                action_fn()
            elseif type(action_fn) == "table" and type(action_fn.run) == "function" then
                action_fn:run()
            end
        end)
        self.busy = false
        if not ok then
            self.errors[id] = tostring(err)
            warn("[arteria] " .. id .. ": " .. tostring(err))
        end
        self.flags[id] = false
        self.refresh()
        return
    end
    local needs_observers = entry.kind == "parry" or entry.kind == "parry-flag" or entry.kind == "observer"
    if enabled and entry.kind ~= "flag" and (not self.features[id] or needs_observers and not self.observers_loaded) then
        self.busy = true
        self.refresh()
        local loaded, load_err = pcall(function()
            if entry.kind ~= "visual" and entry.kind ~= "visual-init" then compat.prepare(self) end
            self.restorers[id] = compat.restore_point(id)
            if entry.path and not self.features[id] then
                local module = require(entry.path)
                if entry.kind == "visual-init" then module = module() end
                self.features[id] = module
            end
            if needs_observers then
                compat.observers(self)
            end
        end)
        self.busy = false
        if not self.alive then
            local late_feature = self.features[id]
            if late_feature then pcall(late_feature.disable, late_feature) end
            if self.restorers[id] then pcall(self.restorers[id]); self.restorers[id] = nil end
            self.maid:do_cleaning()
            return
        end
        if not loaded then
            if self.restorers[id] then pcall(self.restorers[id]); self.restorers[id] = nil end
            self.errors[id] = tostring(load_err)
            warn("[arteria] " .. id .. ": " .. tostring(load_err))
            self.refresh()
            return
        end
    end
    local feature = self.features[id]
    self.errors[id] = nil
    if not feature then
        self.flags[id] = enabled
        if id == "auto_parry" and not enabled and env.DefendActionManager then
            table.clear(env.DefendActionManager.actions_to_play_through)
        end
        self.refresh()
        return
    end
    local was_enabled = self.flags[id]
    self.flags[id] = enabled
    local ok, err = pcall(function()
        if feature.current_connection then
            feature.current_connection:Disconnect()
            feature.current_connection = nil
        end
        if enabled then
            if not self.restorers[id] then self.restorers[id] = compat.restore_point(id) end
            self.enabling = id
            if id == "auto_builder" then
                local mode = env.aztup_options.auto_builder_mode and env.aztup_options.auto_builder_mode.Value or "Talents & Points"
                feature.shrined = (env.aztup_options.auto_builder_shrined and env.aztup_options.auto_builder_shrined.Value == "On")
                if mode == "Talents & Points" or mode == "Talents only" then pcall(function() feature:build() end) end
                if mode == "Talents & Points" or mode == "Points only" then pcall(function() feature:put_points() end) end
            else
                feature:enable()
            end
            self.enabling = nil
            if not self.alive then feature:disable(); return end
            if not self.flags[id] then return end
            -- Auto-fight owns an RBXScriptConnection rather than a signal.
            if typeof(feature.conn) ~= "RBXScriptSignal" then return end
            feature.current_connection = feature.conn:Connect(function(dt)
                local data = env.local_player
                if not self.alive or not self.flags[id] then return end
                if not data.character or not data.root_part or not data.humanoid then return end
                if data.humanoid.Health <= 0 or services.UserInputService:GetFocusedTextBox() then return end
                local updated, update_err = pcall(feature.update, dt)
                if not updated then
                    self:set(id, false)
                    self.errors[id] = tostring(update_err)
                    warn("[arteria] " .. id .. ": " .. tostring(update_err))
                    if self.refresh then self.refresh() end
                end
            end)
        else
            if id == "auto_builder" then
                pcall(function() feature:killswitch() end)
                pcall(function() feature:points_killswitch() end)
            else
                feature:disable()
            end
            if self.restorers[id] then self.restorers[id](); self.restorers[id] = nil end
        end
    end)
    self.enabling = nil
    if not ok then
        self.flags[id] = false
        if feature.current_connection then feature.current_connection:Disconnect() end
        feature.current_connection = nil
        pcall(feature.disable, feature)
        if self.restorers[id] then pcall(self.restorers[id]); self.restorers[id] = nil end
        self.errors[id] = tostring(err)
        warn("[arteria] " .. id .. ": " .. tostring(err))
    end
    -- The legacy modules schedule the shared cap override for deletion. Wait
    -- until that deletion has passed before renewing it for a remaining user.
    if was_enabled and not enabled and (id == "fly" or id == "speed") and (self.flags.fly or self.flags.speed) and env.EffectReplicator then
        local renewal = task.delay(1.1, function()
            if self.alive and (self.flags.fly or self.flags.speed) then
                env.EffectReplicator:CreateEffect("OverrideSpeedCap")
            end
        end)
        self.maid:give_task(function() pcall(task.cancel, renewal) end)
    end
    if self.refresh then self.refresh() end
end

function runtime:option(option, value)
    self.flags[option.id] = value
    if env.aztup_options[option.id] then env.aztup_options[option.id].Value = value end
    if option.id == "arteria_anim_speed" then compat.animation_speed(self, value) end
    if option.id == "auto_feint" then self.flags.auto_feint = (value == "On") end
    if option.id == "basic_validation" then self.flags.basic_validation = (value == "On") end
    if option.id == "view_hitboxes" then self.flags.view_hitboxes = (value == "On") end
    if option.id == "auto_parry_fallback" and env.aztup_options.fallbacks then
        env.aztup_options.fallbacks.Value = { [value] = true }
    end
end

function runtime:destroy()
    if not self.alive then return end
    if self.echo then self.echo:stop("stopped") end
    -- Disable dependants before the internal dependency they own.
    self:set("fake_void", false)
    for id in pairs(self.entries) do self:set(id, false) end
    self.alive = false
    self.maid:do_cleaning()
    if self.gui then self.gui:Destroy() end
    -- Existing security hooks are not reversible through the legacy API.
    -- Keep the disabled compatibility state alive for their closures.
end
runtime.detach = runtime.destroy

local function bind_character(character)
    for id in pairs(runtime.entries) do runtime:set(id, false) end
    character_maid:do_cleaning()
    env.local_player.character = character
    env.local_player.root_part = character:FindFirstChild("HumanoidRootPart")
    env.local_player.humanoid = character:FindFirstChildOfClass("Humanoid")
    if env.local_player.character_added then env.local_player.character_added:fire(character) end
    character_maid:give_task(character.ChildAdded:Connect(function(child)
        if child.Name == "HumanoidRootPart" then env.local_player.root_part = child end
        if child:IsA("Humanoid") then env.local_player.humanoid = child end
        if runtime.echo and runtime.status == "ready" and env.local_player.root_part and env.local_player.humanoid then runtime.echo:resume() end
    end))
    character_maid:give_task(character.ChildRemoved:Connect(function(child)
        if child == env.local_player.root_part then env.local_player.root_part = nil end
        if child == env.local_player.humanoid then env.local_player.humanoid = nil end
    end))
end
runtime.maid:give_task(player.CharacterAdded:Connect(bind_character))
runtime.maid:give_task(player.CharacterRemoving:Connect(function()
    if runtime.echo and runtime.echo.running then runtime.echo:stop("waiting for character", true) end
    for id in pairs(runtime.entries) do runtime:set(id, false) end
    character_maid:do_cleaning()
    env.local_player.character = nil
    env.local_player.root_part = nil
    env.local_player.humanoid = nil
end))
runtime.echo = require("@src/arteria/echo").new(runtime, compat.prepare)
runtime.config = require("@src/arteria/config").new(runtime)
runtime.ui_key = Enum.KeyCode.RightShift
if player.Character then bind_character(player.Character) end

require("@src/arteria/ui").mount(runtime)
if game.PlaceId == 4111023553 then
    runtime.status = "join a game first"
    runtime.refresh()
    runtime.echo:resume()
    return runtime
end

-- Load the existing AC path unchanged. Requiring it does not prove that its
-- asynchronous hooks succeed; the UI deliberately never claims protection.
task.spawn(function()
    local ok, err = pcall(function()
        assert(require("@src/features/hooking"), "existing AC layer failed to load")
        if not runtime.alive then return end
        runtime.ac_loaded = true
        local raw_effects = services.ReplicatedStorage:WaitForChild("EffectReplicator", 15)
        assert(raw_effects, "EffectReplicator unavailable")
        env.EffectReplicator = base_require(raw_effects)
        -- Feature factories are now loaded on first enable, never at startup.
        if runtime.alive then runtime.status = "ready"; runtime.echo:resume() end
    end)
    if not runtime.alive then return end
    if not ok then
        runtime.status = "initialization failed"
        warn("[arteria] " .. tostring(err))
    end
    runtime.refresh()
end)
return runtime
