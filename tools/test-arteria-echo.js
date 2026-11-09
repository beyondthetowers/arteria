// Exercises the real echo controller/scope with memory-only storage and fake
// farm modules. No remotes, real slots, teleports, wipes or live clients.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { execFileSync } = require("node:child_process");
const root = path.resolve(__dirname, "..");
const binary = process.argv[2];
if (!binary) throw new Error("Pass the official Luau CLI path");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const directory = fs.mkdtempSync(path.join(process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, "Temp", "opencode") : os.tmpdir(), "arteria-echo-"));
const file = path.join(directory, "echo-test.lua");
const source = `
local warn = function() end
local queue, queued_sources = {}, {}
local task = {}
function task.defer(callback,...)
    local thread=coroutine.create(callback)
    table.insert(queue,{thread=thread,args=table.pack(...)})
    return thread
end
task.spawn=task.defer
function task.delay(_,callback,...) return task.defer(callback,...) end
function task.wait() return coroutine.yield() end
function task.cancel(thread) coroutine.close(thread) end
local function pump()
    local current=queue;queue={}
    for _,entry in ipairs(current) do if coroutine.status(entry.thread)~="dead" then
        local ok,err=coroutine.resume(entry.thread,table.unpack(entry.args,1,entry.args.n));assert(ok,err)
    end end
end
local function clone(value)
    if type(value)~="table" then return value end
    local result={};for k,v in pairs(value) do result[k]=clone(v) end;return result
end
local encoded,files={},{}
local http={}
function http:JSONEncode(value) local token="json-"..(#encoded+1);table.insert(encoded,clone(value));return token end
function http:JSONDecode(value) local index=tonumber(value:match("json%-(%d+)"));return clone(assert(encoded[index],"Invalid fixture JSON")) end
function http:GenerateGUID() return "fixture-"..tostring(#queued_sources+1) end
local function readfile(path) return assert(files[path],"File missing "..path) end
local function writefile(path,value) files[path]=value end
local function isfile(path) return files[path]~=nil end
local function isfolder() return true end
local function makefolder() end
local function queue_on_teleport(source) table.insert(queued_sources,source) end
local Enum={CompressionAlgorithm={Zstd="zstd"}}
local encoding={Base64Decode=function(_,value)return value end,DecompressBuffer=function(_,value)return value end}
local slot="A"
local player={GetAttribute=function(_,name) if name=="DataSlot" then return slot end end,Kick=function() error("No real kick is permitted in tests") end}
local game={PlaceId=6032399813,JobId="old-server",GetService=function(_,name)
    if name=="HttpService" then return http end
    if name=="EncodingService" then return encoding end
    error("Unexpected service "..name)
end}
local old_store={old=true}
local env={local_player={root_part={},instance=player},is_etrean=true,persistent_data=old_store,
    Arteria_bootstrap_b64="fixture-bootstrap",Tween={new=function() return {stop=function()end} end}}
local function getgenv() return env end
local Scope=(function() ${read("src/arteria/scope.lua")} end)()
local Transfer=(function() ${read("src/arteria/echo_transfer.lua")} end)()
local farm={features={"fly","noclip","no_fall"},state_machine={current="idle"}}
local machine_starts=0
function farm:bind_scope(scope) self.scope=scope;self.state_machine.current="idle" end
function farm.state_machine:start() machine_starts+=1 end
local require=function(name)
    if name=="@src/arteria/scope" then return Scope end
    if name=="@src/arteria/echo_transfer" then return Transfer end
    if name=="@src/utility/statemachine" then return {} end
    if name=="@src/automation/persistent_tasks/soup_echofarm" then return farm end
    error("Unexpected module "..name)
end
local Echo=(function() ${read("src/arteria/echo.lua")} end)()
local runtime={alive=true,status="ready",flags={fly=true,noclip=false,no_fall=false},refresh=function()end}
function runtime:set(id,value) if self.reject~=id then self.flags[id]=value end end
local echo=Echo.new(runtime,function()end)
runtime.echo=echo
assert(not echo.session.enabled and not echo.running,"no unsolicited farm startup")
assert(not echo:start("B"),"wrong slot must fail")
assert(not echo.running and #queued_sources==0,"wrong slot creates no queued work")
assert(echo:start("A"),"explicit matching slot start")
assert(echo.running and runtime.flags.noclip and runtime.flags.no_fall,"farm dependencies enabled")
assert(isfile("Arteria/bootstrap.lua"),"local continuation saved")
local guarded=echo:guard('return "ran"')
local function execute_guard(source)
    local chunk=assert(loadstring(source))
    setfenv(chunk,setmetatable({game=game,readfile=readfile},{__index=getfenv()}))
    return chunk()
end
assert(execute_guard(guarded)=="ran","active continuation accepted")
local started_scope=echo.scope
local callback_runs=0
started_scope.task.delay(60,function()callback_runs+=1 end)
local cleaned=0;started_scope:track(function()cleaned+=1 end)
echo:stop("stopped")
pump()
assert(not echo.running and not echo.session.enabled,"stop clears active session")
assert(callback_runs==0 and machine_starts==0,"stop cancels queued farm work before execution")
assert(cleaned==1 and not started_scope.active,"scope resources cleaned")
assert(runtime.flags.fly and not runtime.flags.noclip and not runtime.flags.no_fall,"restore prior toggles")
assert(env.persistent_data==old_store,"restore shared store")
assert(execute_guard(guarded)==nil,"stale queued wipe/continuation invalidated")
assert(echo:start("A"),"restart after stop")
local manual=Echo.new(runtime,function()end)
manual:resume();assert(not manual.running and manual.state=="confirmation required","manual injection must not silently resume a saved farm")
assert(execute_guard(guarded)==nil,"prior token cannot affect the new session")
pump();assert(machine_starts==1,"only confirmed farm state machine runs")
echo:stop("waiting for character",true)
assert(echo.session.enabled and not echo.running,"respawn preserves only confirmed intent")
echo:resume();assert(echo.running,"resume same confirmed slot")
echo:stop("stopped")
runtime.reject="noclip"
assert(not echo:start("A"),"dependency failure must abort")
assert(not echo.running and not echo.session.enabled and runtime.flags.fly,"failed startup rolls back and invalidates continuation")
runtime.reject=nil
assert(echo:start("A"))
slot="B"
echo:stop("waiting",true)
echo:resume();assert(not echo.running,"saved session cannot run on another slot")
echo:stop("stopped")
slot="A"
local transfer=Transfer.source("A",true,"token-with-quote\\\"","old-server")
assert(loadstring(transfer),"queued transfer source must compile")
assert(not string.find(transfer,"__SLOT__",1,true),"all transfer placeholders substituted")
assert(string.find(transfer,"remote:InvokeServer(slot)",1,true),"explicit wipe action is kept")
assert(string.find(transfer,"if not active() then return end",1,true),"transfer is revocable")
local s=Scope.new(task)
local ran=0
s.task.defer(function() ran+=1;s.task.wait();ran+=1 end)
pump();assert(ran==1,"scoped work starts")
s:stop();pump();assert(ran==1,"suspended work stays cancelled")
s:stop()
print("arteria echo: slot guards, local resume, token revocation, dependency rollback, prior-state restoration and scoped cancellation passed; no gameplay executed")
`;
try {
    fs.writeFileSync(file, source);
    console.log(execFileSync(binary, [file], { cwd: root, encoding: "utf8" }));
} finally {
    fs.unlinkSync(file);
    fs.rmdirSync(directory);
}
