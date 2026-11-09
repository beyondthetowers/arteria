// Executes the production controller methods with isolated fake feature modules.
// No Roblox client, networking, remotes or game modification is involved.
// Usage: node tools/test-arteria-runtime.js <path-to-luau.exe>
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { execFileSync } = require("node:child_process");
const root = path.resolve(__dirname, "..");
const binary = process.argv[2];
if (!binary) throw new Error("Pass the path to the official Luau CLI");
const source = fs.readFileSync(path.join(root, "src/arteria/init.lua"), "utf8");
const controller = source.slice(source.indexOf("function runtime:set"), source.indexOf("local function bind_character"));
const primitives = fs.readFileSync(path.join(root, "src/luarmor_init_script.lua"), "utf8");
const assetHelper = primitives.slice(primitives.indexOf('genv["inline_asset_b96"] = function(path)'), primitives.indexOf("-- globals.lua carries"));
const timings = fs.readFileSync(path.join(root, "src/features/auto-parry/data/base.lua"), "utf8");
const speedHelper = timings.slice(timings.indexOf("local function speed_of(track)"), timings.indexOf("local ht ="));
const tempRoot = process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, "Temp", "opencode") : os.tmpdir();
const temp = fs.mkdtempSync(path.join(tempRoot, "arteria-runtime-"));
const file = path.join(temp, "test.lua");
const harness = `
local warn = function(...) print("expected fixture warning:", ...) end
local real_typeof = typeof
local typeof = function(value)
    return type(value) == "table" and value._type or real_typeof(value)
end
local env = { local_player = { root_part = {}, character = {}, humanoid = { Health = 100 } }, aztup_options = {}, is_depths = false, is_eastern = false }
local services = { UserInputService = { GetFocusedTextBox = function() return nil end } }
local registry, imports = {}, {}
local require = function(name)
    imports[name] = (imports[name] or 0) + 1
    if name == "broken" then error("fixture import failure") end
    assert(registry[name], "Unexpected import " .. name)
    return registry[name]
end
local compat = { prepare = function() end, observers = function() end, restore_point = function() end, animation_speed = function(r, v) r.animation_speed = v end }
local runtime = { entries = {}, features = {}, flags = {}, errors = {}, restorers = {}, alive = true, status = "ready", refresh = function() end,
    maid = { do_cleaning = function(self) self.cleaned = true end } }
local function feature(id, owns_connection)
    local f = { enabled = 0, disabled = 0, updates = 0 }
    f.conn = { _type = "RBXScriptSignal", Connect = function(_, callback)
        local conn = { callback = callback, Disconnect = function(self) self.disconnected = true end }
        f.last_connection = conn
        return conn
    end }
    function f:enable()
        self.enabled += 1
        if owns_connection then self.conn = { _type = "RBXScriptConnection" } end
    end
    function f:disable() self.disabled += 1 end
    function f.update() f.updates += 1; if f.fail_update then error("fixture update failure") end end
    registry[id] = f
    runtime.entries[id] = { id = id, path = id }
    runtime.flags[id] = false
    return f
end
${controller}
local fly = feature("fly")
local jump = feature("infinite_jump")
runtime:set("fly", true)
assert(runtime.flags.fly and fly.enabled == 1 and imports.fly == 1, "enable/lazy import")
fly.last_connection.callback(0.016)
assert(fly.updates == 1, "update dispatch")
runtime:set("fly", true)
assert(fly.enabled == 1, "idempotent enable")
runtime:set("fly", false)
assert(not runtime.flags.fly and fly.last_connection.disconnected and fly.disabled == 1, "disable/disconnect")
runtime:set("fly", true)
assert(imports.fly == 1 and fly.enabled == 2, "cached factory")
local owned = feature("auto_fight", true)
runtime:set("auto_fight", true)
assert(runtime.flags.auto_fight and owned.current_connection == nil, "self-managed connection")
local native = feature("native_visual", true)
runtime.entries.native_visual.kind = "visual-init"
registry.native_visual = function() return native end
runtime:set("native_visual", true)
assert(runtime.features.native_visual == native and native.enabled == 1, "legacy visual initializer returns its Arteria feature")
runtime.entries.basic_validation = { id = "basic_validation", kind = "flag" }
runtime:set("basic_validation", true)
assert(runtime.flags.basic_validation and imports.basic_validation == nil, "flag-only feature")
runtime.entries.auto_parry = { id = "auto_parry", kind = "parry" }
runtime:set("auto_parry", true)
assert(runtime.flags.auto_parry, "parry observer flag")
env.DefendActionManager = { actions_to_play_through = { 1, 2 } }
runtime:set("auto_parry", false)
assert(#env.DefendActionManager.actions_to_play_through == 0, "parry queue cleanup")
runtime.entries.broken = { id = "broken", path = "broken" }
runtime:set("broken", true)
assert(not runtime.flags.broken and runtime.errors.broken and runtime.status == "ready", "failure isolation")
runtime.entries.fake_void = { id = "fake_void", path = "fake_void", note = "Depths only" }
runtime:set("fake_void", true)
assert(not imports.fake_void and runtime.errors.fake_void == "Depths only", "place guard")
runtime:set("infinite_jump", true)
jump.fail_update = true
jump.last_connection.callback(0.016)
assert(not runtime.flags.infinite_jump and jump.last_connection.disconnected and runtime.errors.infinite_jump, "update failure cleanup")
local cancel = feature("cancel")
function cancel:enable() runtime:set("cancel", false) end
runtime:set("cancel", true)
assert(not runtime.flags.cancel and not cancel.current_connection, "self-cancel must not attach a stale update")
runtime:option({ id = "arteria_anim_speed" }, 1.25)
assert(runtime.animation_speed == 1.25, "animation option forwarding")
runtime:destroy()
assert(not runtime.alive and runtime.maid.cleaned and not runtime.flags.fly and not runtime.flags.auto_fight and not runtime.flags.basic_validation, "destroy resets modules and flags")
assert(fly.last_connection.disconnected, "destroy disconnects updates")
runtime:set("fly", true)
assert(not runtime.flags.fly, "dead runtime cannot enable")
print("arteria runtime: 15 lifecycle, lazy-load, flag, dependency, option and failure-isolation assertions passed")
do
    ${speedHelper}
    for i = 1, 10 do
        assert(speed_of(nil) == 1)
        assert(speed_of({ Speed = 0 }) == 1)
        assert(speed_of({ Speed = -1 }) == 1)
        assert(speed_of({ Speed = 0/0 }) == 1)
        assert(speed_of({ Speed = math.huge }) == 1)
        assert(speed_of({ Speed = "invalid" }) == 1)
        assert(speed_of({ Speed = 1.25 }) == 1.25)
    end
end
do
    local genv = { __BUNDLED_ASSETS = { ["@assets/base.json"] = "embedded" } }
    local encoding = {}
    function encoding:CompressBuffer(raw, algorithm)
        assert(buffer.tostring(raw) == "raw-data", "disk input")
        return buffer.fromstring("compressed-data")
    end
    function encoding:Base64Encode(raw)
        assert(buffer.tostring(raw) == "compressed-data", "Base64Encode requires a buffer")
        if self.fail then error("fixture encoding failure") end
        return buffer.fromstring("base64-data")
    end
    local game = { GetService = function(_, name)
        assert(name == "EncodingService", "Wrong encoding service: " .. name)
        return encoding
    end }
    local Enum = { CompressionAlgorithm = { Zstd = "fixture-zstd" } }
    local readfile = function(name)
        if name == "assets/base.json" then return "raw-data" end
        error("fixture file missing")
    end
    ${assetHelper}
    assert(genv.inline_asset_b96("@assets/base.json") == "embedded", "embedded asset lookup")
    genv.__BUNDLED_ASSETS = nil
    for i = 1, 10 do
        assert(genv.inline_asset_b96("@assets/base.json") == "base64-data", "EncodingService fallback")
        local found, message = pcall(genv.inline_asset_b96, "@assets/missing.json")
        assert(not found and string.find(message, "asset not found on disk or in bundle", 1, true), "missing assets must fail clearly")
    end
    encoding.fail = true
    local encoded, message = pcall(genv.inline_asset_b96, "@assets/base.json")
    assert(not encoded and string.find(message, "failed to encode asset", 1, true), "encoding failures must not return empty payloads")
end
print("arteria assets: 10 repeated fallback/missing-file runs and 70 timing-speed checks passed")
`;
try {
    fs.writeFileSync(file, harness);
    console.log(execFileSync(binary, [file], { cwd: root, encoding: "utf8" }));
} finally {
    fs.unlinkSync(file);
    fs.rmdirSync(temp);
}
