const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { execFileSync } = require("node:child_process");
const root = path.resolve(__dirname, "..");
const binary = process.argv[2];
if (!binary) throw new Error("Pass the official Luau CLI path");
const directory = fs.mkdtempSync(path.join(process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, "Temp", "opencode") : os.tmpdir(), "arteria-esp-"));
const file = path.join(directory, "esp-test.lua");
const source = `
local warn=function()end
local function signal()
    local event={connections={}}
    function event:Connect(callback) local c={active=true,callback=callback};function c:Disconnect()self.active=false end;table.insert(self.connections,c);return c end
    function event:Fire(...)for _,c in ipairs(self.connections)do if c.active then c.callback(...)end end end
    return event
end
local V={}
function V.__index(self,key) if key=="Magnitude" then return math.sqrt(self.X^2+self.Y^2+self.Z^2)end end
function V.__sub(a,b)return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z},V)end
function V.__add(a,b)return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z},V)end
local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z},V)end
local CF={}
function CF.__mul(a,b)return setmetatable({Position=vec(a.Position.X+b.Position.X,a.Position.Y+b.Position.Y,a.Position.Z+b.Position.Z)},CF)end
local CFrame={new=function(x,y,z)return setmetatable({Position=vec(x,y,z)},CF)end}
local Vector2={new=function(x,y)return {X=x,Y=y}end}
local UDim2={fromOffset=function(x,y)return {x=x,y=y}end}
local Color3={fromRGB=function()return {}end}
local Vector3={new=vec}
local Enum=setmetatable({},{__index=function(t,k)local e=setmetatable({},{__index=function(s,n)rawset(s,n,n);return n end});rawset(t,k,e);return e end})
local function model(parts)
    local object={parts=parts,FindFirstChild=function(self,name)return self.parts[name]end,
        FindFirstChildOfClass=function(self,class)return class=="Humanoid" and self.parts.Humanoid or nil end,
        IsA=function(_,class)return class=="Model"end,GetAttribute=function()return nil end,
        FindFirstChildWhichIsA=function(self,class)for _,part in pairs(self.parts)do if part.IsA and part:IsA(class)then return part end end end}
    for _,part in pairs(parts)do part.Parent=object end
    return object
end
local function part(x,y,z)return {Position=vec(x,y,z),CFrame=CFrame.new(x,y,z),Size={Y=2},IsA=function(_,class)return class=="BasePart"end,
    FindFirstChild=function()return nil end,GetAttribute=function()return nil end}end
local own={Team="red",Character=model({HumanoidRootPart=part(0,0,10)})}
local enemy={Team="blue",Character=model({Head=part(40,20,10),Torso=part(40,40,10),["Left Arm"]=part(25,40,10),["Right Arm"]=part(55,40,10),["Left Leg"]=part(35,60,10),["Right Leg"]=part(45,60,10),HumanoidRootPart=part(40,40,10),Humanoid={Health=100}})}
enemy.Name,enemy.DisplayName,enemy.GetAttribute="test-user","Test Display",function()return "Test Character"end
local player_gui={}
function own:WaitForChild(name)assert(name=="PlayerGui");return player_gui end
local player_list={own,enemy}
local players={LocalPlayer=own,PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function()return player_list end}
local run={RenderStepped=signal()}
local project=function(_,point)return point,point.Z>0 and point.X>=0 and point.X<=200 and point.Y>=0 and point.Y<=200 end
local camera={CFrame=CFrame.new(0,0,10),ViewportSize={X=200,Y=200},WorldToViewportPoint=project}
local workspace={CurrentCamera=camera}
local game={GetService=function(_,name)if name=="Players"then return players elseif name=="RunService"then return run end;error(name)end}
local objects={}
local Instance={new=function(class)
    local o={ClassName=class,Visible=false}
    function o:Destroy()
        for _,child in ipairs(objects)do if child.Parent==self then child:Destroy()end end
        self.destroyed=true;self.Visible=false;self.Parent=nil
    end
    table.insert(objects,o);return o
end}
local aztup={flags={skeleton_esp_range=2000,skeleton_esp_thickness=1}}
local aztup_options={skeleton_esp_targets={Value="Everyone"}}
local env={arteria={errors={},refresh=function()end}}
local function getgenv()return env end
local feature
local aztup_toggles={skeleton_esp={SetValue=function(_,value)assert(value==false);feature:disable()end}}
feature=(function() ${fs.readFileSync(path.join(root, "src/arteria/skeleton_esp.lua"), "utf8")} end)()
local function visible()
    local count=0;for _,o in ipairs(objects)do if o.ClassName=="Frame" and o.Visible and not o.destroyed then count+=1 end end;return count
end
assert(#objects==0,"no overlay objects while disabled")
feature:enable();run.RenderStepped:Fire()
assert(visible()==9,"R6 center bones and limb extremities")
local initial=#objects
for _=1,20 do run.RenderStepped:Fire()end
assert(#objects==initial,"render loop must not allocate new GUI objects")
aztup_options.skeleton_esp_targets.Value="Other teams";enemy.Team="red";run.RenderStepped:Fire()
assert(visible()==0,"team filter")
enemy.Team="blue";aztup.flags.skeleton_esp_range=1;run.RenderStepped:Fire();assert(visible()==0,"range culling")
aztup.flags.skeleton_esp_range=2000
local old_root=enemy.Character.parts.HumanoidRootPart;enemy.Character.parts.HumanoidRootPart=nil
run.RenderStepped:Fire();assert(visible()==0,"streamed-out root")
enemy.Character.parts.HumanoidRootPart=old_root
enemy.Character.parts.Humanoid.Health=0;run.RenderStepped:Fire();assert(visible()==0,"dead target")
local parts={HumanoidRootPart=part(40,40,10),Humanoid={Health=100}}
for i,name in ipairs({"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"})do parts[name]=part(20+i*3,20+i*4,10)end
enemy.Character=model(parts);run.RenderStepped:Fire();assert(visible()==14,"R15 rig replacement")
players.PlayerRemoving:Fire(enemy);assert(visible()==0 and not feature.targets[enemy],"player removal cleanup")
players.PlayerAdded:Fire(enemy);run.RenderStepped:Fire();assert(visible()==14,"late player support")
feature:disable()
assert(visible()==0 and not run.RenderStepped.connections[1].active,"disable disconnects rendering")
feature:enable();camera.WorldToViewportPoint=function()error("fixture projection failure")end
run.RenderStepped:Fire()
assert(feature.gui==nil and env.arteria.errors.skeleton_esp,"projection errors fail closed")
print("arteria ESP: R6/R15 rigs, no per-frame allocation, team/range/death/streaming filters, player changes, cleanup and error isolation passed")
camera.WorldToViewportPoint=project
local theme=(function() ${fs.readFileSync(path.join(root, "src/arteria/theme.lua"), "utf8")} end)()
local require=function(name)assert(name=="@src/arteria/theme");return theme end
local player_esp=(function() ${fs.readFileSync(path.join(root, "src/arteria/player_esp.lua"), "utf8")} end)()
aztup.flags.arteria_player_range,aztup.flags.arteria_player_text=2000,13
for name,value in pairs({arteria_player_teams="Everyone",arteria_player_boxes="Corners",arteria_player_health="Bar and value",arteria_player_names="Character",arteria_player_distance="Shown",arteria_player_highlight="Outline"})do aztup_options[name]={Value=value}end
parts.Humanoid.MaxHealth=100
aztup_toggles.player_esp={SetValue=function()player_esp:disable()end}
player_esp:enable();run.RenderStepped:Fire(0.1)
local p=assert(player_esp.targets[enemy])
assert(p.name.Visible and p.name.Text=="Test Character" and p.fill.Visible,"player names and health")
assert(p.lines[1].Visible and p.glow[1].Visible and p.highlight.Enabled,"corner frames, neon halo and outline")
local allocations=#objects;for _=1,10 do run.RenderStepped:Fire(0.1)end
assert(#objects==allocations,"player render loop allocates no UI objects")
enemy.Character.parts.HumanoidRootPart=nil;run.RenderStepped:Fire(0.1)
assert(not p.name.Visible and not p.highlight.Enabled,"player streaming cleanup")
enemy.Character.parts.HumanoidRootPart=old_root
player_esp:disable();assert(not p.lines[1].Visible and player_esp.gui==nil,"player backend cleanup")
local world_esp=(function() ${fs.readFileSync(path.join(root, "src/arteria/world_esp.lua"), "utf8")} end)()
local mob=model({HumanoidRootPart=part(40,40,10),Humanoid={Health=80,MaxHealth=100}});mob.Name=".guard_etrean123"
local chest=model({Lid=part(50,50,10)});chest.Name="Chest"
local artifact=part(60,60,10);artifact.Name="BigArtifact"
local ingredient=part(70,70,10);ingredient.Name="Browncap"
local containers={}
local function container(name,children)
    local object={GetChildren=function()return children end}
    for _,entity in ipairs(children)do entity.Parent=object end
    containers[name]=object
end
container("Live",{mob});container("Thrown",{chest,artifact});container("Ingredients",{ingredient})
workspace.FindFirstChild=function(_,name)return containers[name]end
for name,value in pairs({arteria_world_range=2000,arteria_world_limit=64,arteria_world_text=13,arteria_world_rate=20})do aztup.flags[name]=value end
aztup_options.arteria_world_category={Value="All"}
aztup_toggles.world_esp={SetValue=function()world_esp:disable()end}
world_esp:enable();run.RenderStepped:Fire(0.1)
assert(world_esp.visible_count==4,"legacy mob/chest/ingredient/artifact classifiers")
allocations=#objects;for _=1,10 do run.RenderStepped:Fire(0.1)end
assert(#objects==allocations,"world label pool has no per-update allocations")
aztup_options.arteria_world_category.Value="Chests";run.RenderStepped:Fire(0.1)
assert(world_esp.visible_count==1 and world_esp.labels[1].Text:find("CHESTS",1,true),"world category filter")
aztup_options.arteria_world_category.Value="All";aztup.flags.arteria_world_limit=2;run.RenderStepped:Fire(0.1)
assert(world_esp.visible_count==2,"world label budget")
world_esp:disable();assert(world_esp.gui==nil,"world backend cleanup")
aztup.brand="arteria"
local LPH_NO_VIRTUALIZE=function(f)return f end
require=function(name)
    if name=="@src/arteria/player_esp"then return player_esp end
    if name=="@src/arteria/world_esp"then return world_esp end
    error("Legacy backend was initialized unexpectedly: "..name)
end
local old_player=(function() ${fs.readFileSync(path.join(root, "src/features/visuals/player_esp.lua"), "utf8")} end)()
local old_world=(function() ${fs.readFileSync(path.join(root, "src/features/visuals/base_esp.lua"), "utf8")} end)()
assert(old_player()==player_esp and old_world()==world_esp,"existing ESP entry points must route into Arteria")
print("arteria ESP expansion: neon player frames/names/health/highlights, bounded world categories, label budgets, pooling, legacy routing and cleanup passed")
`;
try { fs.writeFileSync(file, source); console.log(execFileSync(binary, [file], { cwd: root, encoding: "utf8" })); }
finally { fs.unlinkSync(file); fs.rmdirSync(directory); }
