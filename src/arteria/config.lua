-- Named local profiles: JSON data only, never executable code or farm consent.
local Config = {}
Config.__index = Config
local ROOT = "Arteria/Configs"
local AUTOLOAD_PATH = ROOT .. "/autoload.json"
local RESERVED = { Unknown = true, V = true, Escape = true, Tab = true, Return = true, Backspace = true }

local function key(name)
    if type(name) ~= "string" or RESERVED[name] then return nil end
    local ok, value = pcall(function() return Enum.KeyCode[name] end)
    return ok and value or nil
end

local function valid_name(name)
    assert(type(name) == "string", "Enter a profile name")
    name = name:match("^%s*(.-)%s*$")
    assert(#name >= 1 and #name <= 48 and name:match("^[%w][%w _%-]*$"), "Use 1–48 letters, numbers, spaces, underscores or hyphens")
    return name
end

function Config.new(runtime)
    return setmetatable({
        runtime = runtime,
        message = "Profiles are local. Echo-farm consent is never saved in a config.",
        profiles = {},
    }, Config)
end

function Config:path(name) return ROOT .. "/profile-" .. valid_name(name) .. ".json" end

function Config:list()
    local result = {}
    if isfolder(ROOT) then
        for _, path in ipairs(listfiles(ROOT)) do
            local basename = path:gsub("\\", "/"):match("([^/]+)$")
            local name = basename and basename:match("^profile%-(.+)%.json$")
            if name and pcall(valid_name, name) then table.insert(result, name) end
        end
    end
    table.sort(result)
    self.profiles = result
    return result
end

function Config:snapshot()
    local runtime = self.runtime
    local data = {
        version = 1,
        flags = {},
        options = {},
        bindings = {},
        ui_key = (runtime.ui_key or Enum.KeyCode.RightShift).Name,
        reduce_motion = runtime.reduce_motion == true,
    }
    for _, entry in ipairs(runtime.catalog.entries) do
        data.flags[entry.id] = runtime.flags[entry.id] == true
        local binding = runtime.bindings and runtime.bindings[entry.id]
        data.bindings[entry.id] = binding and binding.Name or false
        for _, option in ipairs(entry.settings) do data.options[option.id] = runtime.flags[option.id] end
    end
    return data
end

function Config:validate(data)
    assert(type(data) == "table" and data.version == 1, "Unsupported or invalid profile format")
    assert(type(data.flags) == "table" and type(data.options) == "table" and type(data.bindings) == "table", "Incomplete profile")
    local result = { flags = {}, options = {}, bindings = {}, ui_key = key(data.ui_key), reduce_motion = data.reduce_motion == true, resets = 0 }
    assert(result.ui_key, "Invalid UI key")
    local used = { [result.ui_key.Name] = true }
    for _, entry in ipairs(self.runtime.catalog.entries) do
        local enabled = data.flags[entry.id]
        assert(enabled == nil or type(enabled) == "boolean", "Invalid feature state: " .. entry.id)
        result.flags[entry.id] = enabled == true
        local value = data.bindings[entry.id]
        if value ~= nil and value ~= false then
            local binding = key(value)
            assert(binding and not used[binding.Name], "Invalid or duplicate keybind: " .. entry.id)
            result.bindings[entry.id], used[binding.Name] = binding, true
        end
        for _, option in ipairs(entry.settings) do
            local value = data.options[option.id]
            if value == nil then value = option.value end
            local valid = true
            if option.values then
                -- A choice saved by an older build may hold a legacy value
                -- (e.g. a boolean where the schema now expects a string).
                -- Reset to the default instead of aborting the whole load.
                valid = table.find(option.values, value) ~= nil
            else
                if not (type(value) == "number" and value == value and math.abs(value) < math.huge) then
                    valid = false
                else
                    value = math.clamp(value, option.low, option.high)
                    if option.id == "min_speed_mult" or option.id == "max_speed_mult" then value = math.floor(value) end
                end
            end
            if not valid then
                value = option.value
                result.resets += 1
            end
            result.options[option.id] = value
        end
    end
    return result
end

function Config:save(name)
    local vname = valid_name(name)
    local path = self:path(vname)
    local data = self:snapshot()
    self:validate(data)
    local encoded = game:GetService("HttpService"):JSONEncode(data)
    if not isfolder("Arteria") then makefolder("Arteria") end
    if not isfolder(ROOT) then makefolder(ROOT) end
    writefile(path, encoded)
    self:list()
    self.message = "Saved / " .. vname
end

function Config:load(name, restore_flags)
    local raw = readfile(self:path(name))
    assert(#raw <= 1024 * 1024, "Profile exceeds the size limit")
    self:apply(game:GetService("HttpService"):JSONDecode(raw), restore_flags, valid_name(name))
end

function Config:apply(payload, restore_flags, label)
    assert(not (self.runtime.echo and self.runtime.echo.running), "Stop the echo cycle before loading a profile")
    local data = self:validate(payload)
    local runtime = self.runtime
    runtime.bindings = runtime.bindings or {}
    table.clear(runtime.bindings)
    for id, value in pairs(data.bindings) do runtime.bindings[id] = value end
    runtime.ui_key, runtime.reduce_motion = data.ui_key, data.reduce_motion
    for _, entry in ipairs(runtime.catalog.entries) do
        for _, option in ipairs(entry.settings) do runtime:option(option, data.options[option.id]) end
    end
    local failed = 0
    if restore_flags == true then
        for _, entry in ipairs(runtime.catalog.entries) do runtime:set(entry.id, false) end
        for _, entry in ipairs(runtime.catalog.entries) do
            if data.flags[entry.id] then runtime:set(entry.id, true); if not runtime.flags[entry.id] then failed += 1 end end
        end
    end
    self.message = "Loaded / " .. (label or "session") .. (restore_flags and " · saved toggles applied" or " · settings and binds only")
        .. (data.resets > 0 and (" · " .. data.resets .. " legacy option(s) reset to default") or "")
        .. (failed > 0 and (" · " .. failed .. " unavailable feature(s)") or "")
    if runtime.refresh then runtime.refresh() end
end

function Config:delete(name)
    local vname = valid_name(name)
    local path = self:path(vname)
    assert(isfile(path), "Profile does not exist")
    delfile(path)
    local auto_name = self:get_autoload()
    if auto_name == vname then self:clear_autoload() end
    self:list()
    self.message = "Deleted / " .. vname
end

function Config:get_autoload()
    if not isfile(AUTOLOAD_PATH) then return nil, false end
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(readfile(AUTOLOAD_PATH))
    end)
    if ok and type(result) == "table" and type(result.name) == "string" and pcall(valid_name, result.name) then
        return result.name, result.restore_flags == true
    end
    return nil, false
end

function Config:set_autoload(name, restore_flags)
    local vname = valid_name(name)
    assert(isfile(self:path(vname)), "Save the profile first before setting it as autoload")
    if not isfolder("Arteria") then makefolder("Arteria") end
    if not isfolder(ROOT) then makefolder(ROOT) end
    local data = { name = vname, restore_flags = restore_flags == true }
    writefile(AUTOLOAD_PATH, game:GetService("HttpService"):JSONEncode(data))
    self.message = "Autoload set / " .. vname .. (restore_flags and " (with toggles)" or " (settings only)")
    if self.runtime.refresh then self.runtime.refresh() end
end

function Config:clear_autoload()
    if isfile(AUTOLOAD_PATH) then delfile(AUTOLOAD_PATH) end
    self.message = "Autoload cleared."
    if self.runtime.refresh then self.runtime.refresh() end
end

function Config:autoload()
    local name, restore_flags = self:get_autoload()
    if not name or not isfile(self:path(name)) then return false end
    local ok, err = pcall(function()
        self:load(name, restore_flags)
    end)
    if ok then
        self.message = "Autoloaded / " .. name .. (restore_flags and " (with toggles)" or " (settings only)")
        return true
    else
        self.message = "Autoload failed / " .. tostring(err)
        return false
    end
end

return Config
