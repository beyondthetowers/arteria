const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { execFileSync } = require("node:child_process");
const root = path.resolve(__dirname, "..");
const binary = process.argv[2];
if (!binary) throw new Error("Pass the official Luau CLI path");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const directory = fs.mkdtempSync(path.join(process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, "Temp", "opencode") : os.tmpdir(), "arteria-config-"));
const file = path.join(directory, "config-test.lua");
const source = `
local Enum={KeyCode={}}
for _,name in ipairs({"F","G","J","K","V","Home","RightShift","Unknown","Tab","Return","Escape","Backspace"}) do Enum.KeyCode[name]={Name=name} end
local files,folders,encoded={},{},{}
local function clone(value) if type(value)~="table" then return value end;local t={};for k,v in pairs(value) do t[k]=clone(v) end;return t end
local http={}
function http:JSONEncode(value) table.insert(encoded,clone(value));return tostring(#encoded) end
function http:JSONDecode(value) return clone(assert(encoded[tonumber(value)],"Bad JSON")) end
local game={GetService=function(_,name) assert(name=="HttpService");return http end}
local function isfolder(path) return folders[path]==true end
local function makefolder(path) folders[path]=true end
local function isfile(path) return files[path]~=nil end
local function writefile(path,body) files[path]=body end
local function readfile(path) return assert(files[path],"Missing file") end
local function delfile(path) assert(files[path]);files[path]=nil end
local function listfiles(root)
    local list={};for path in pairs(files) do if path:sub(1,#root+1)==root.."/" then table.insert(list,(path:gsub("/","\\\\"))) end end;return list
end
local catalog=(function() ${read("src/arteria/catalog.lua")} end)()
local Config=(function() ${read("src/arteria/config.lua")} end)()
local toggles=0
local runtime={catalog=catalog,flags={},bindings={fly=Enum.KeyCode.F,speed=Enum.KeyCode.G,infinite_jump=Enum.KeyCode.J},ui_key=Enum.KeyCode.Home,echo={running=false}}
function runtime:set(id,value) toggles+=1;self.flags[id]=value end
function runtime:option(option,value) self.flags[option.id]=value end
for _,entry in ipairs(catalog.entries) do runtime.flags[entry.id]=false;for _,o in ipairs(entry.settings) do runtime.flags[o.id]=o.value end end
runtime.flags.fly=true
local config=Config.new(runtime)
assert(#config:list()==0,"empty storage")
config:save("one")
assert(files["Arteria/Configs/profile-one.json"] and #config:list()==1,"save/list")
local snapshot=config:snapshot()
assert(snapshot.echo==nil and snapshot.farm==nil and snapshot.token==nil,"farm consent is excluded")
local reference=runtime.bindings
runtime.flags.fly=false;runtime.flags.walk_speed=99;runtime.bindings.fly=Enum.KeyCode.K
config:load("one",false)
assert(runtime.bindings==reference and runtime.bindings.fly==Enum.KeyCode.F,"shared binding table preserved")
assert(runtime.flags.walk_speed==32 and runtime.flags.fly==false and toggles==0,"default load changes settings, not toggles")
config:load("one",true)
assert(runtime.flags.fly and toggles>=47,"explicit toggle restoration")
assert(runtime.echo.running==false,"config never starts a farm")
config:set_autoload("one",true)
local a_name,a_flags=config:get_autoload()
assert(a_name=="one" and a_flags==true,"autoload getter")
runtime.flags.fly=false
assert(config:autoload(),"autoload execute")
assert(runtime.flags.fly,"autoload restores saved state")
config:clear_autoload()
assert(config:get_autoload()==nil,"autoload cleared")
for _,name in ipairs({"../bad","x/y","x\\\\y","",string.rep("x",49)}) do assert(not pcall(config.save,config,name),"invalid profile name accepted") end
local bad=clone(snapshot);bad.bindings.speed="F"
files["Arteria/Configs/profile-bad.json"]=http:JSONEncode(bad)
assert(not pcall(config.load,config,"bad"),"duplicate bind accepted")
assert(runtime.bindings==reference and runtime.bindings.fly==Enum.KeyCode.F,"invalid load mutates nothing")
bad=clone(snapshot);bad.options.fly_speed=math.huge
files["Arteria/Configs/profile-bad.json"]=http:JSONEncode(bad)
assert(pcall(config.load,config,"bad"),"nonfinite number must not abort load")
assert(runtime.flags.fly_speed==60,"nonfinite number reset to default")
bad=clone(snapshot);bad.options.walk_speed=999999
assert(config:validate(bad).options.walk_speed==250,"numeric limit validation")
bad=clone(snapshot);bad.options.fly_speed="fast"
files["Arteria/Configs/profile-bad.json"]=http:JSONEncode(bad)
assert(pcall(config.load,config,"bad"),"wrong-type number must not abort load")
assert(runtime.flags.fly_speed==60,"wrong-type number reset to default")
-- legacy build compatibility: a boolean where the schema now expects a choice string
bad=clone(snapshot);bad.options.fly_speed=nil;bad.options["auto_feint"]=true
files["Arteria/Configs/profile-bad.json"]=http:JSONEncode(bad)
local ok_load=pcall(config.load,config,"bad")
assert(ok_load,"legacy boolean choice must not abort load")
bad=clone(snapshot);bad.ui_key="V"
assert(not pcall(config.validate,config,bad),"reserved menu key accepted")
bad=clone(snapshot);bad.bindings.fly="NotARealKey"
assert(not pcall(config.validate,config,bad),"invalid enum name accepted")
bad=clone(snapshot);bad.version=2
assert(not pcall(config.validate,config,bad),"unknown version accepted")
runtime.echo.running=true
assert(not pcall(config.load,config,"one"),"load while farm owns controls accepted")
runtime.echo.running=false
files["Arteria/Configs/profile-large.json"]=string.rep("x",1024*1024+1)
assert(not pcall(config.load,config,"large"),"oversize profile accepted")
config:delete("one");assert(not isfile("Arteria/Configs/profile-one.json"),"exact-profile delete")
print("arteria config: save/load/list/delete, shared bindings, settings-only default, toggle opt-in, path/schema/key validation and farm exclusion passed")
`;
try { fs.writeFileSync(file, source); console.log(execFileSync(binary, [file], { cwd: root, encoding: "utf8" })); }
finally { fs.unlinkSync(file); fs.rmdirSync(directory); }
