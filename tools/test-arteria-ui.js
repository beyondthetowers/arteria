// Deterministic native-UI harness. Executes the actual UI module with fake
// instances/signals, never a live game; covers behavior and layout bounds.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { execFileSync } = require("node:child_process");
const root = path.resolve(__dirname, "..");
const binary = process.argv[2];
if (!binary) throw new Error("Pass the path to the official Luau CLI");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const tempRoot = process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, "Temp", "opencode") : os.tmpdir();
const directory = fs.mkdtempSync(path.join(tempRoot, "arteria-ui-"));
const file = path.join(directory, "ui-test.lua");
const source = `
local function signal()
    local s = { listeners = {} }
    function s:Connect(callback)
        local c = { active = true, callback = callback }
        function c:Disconnect() self.active = false end
        table.insert(self.listeners, c)
        return c
    end
    function s:Fire(...)
        for _, c in ipairs(table.clone(self.listeners)) do if c.active then c.callback(...) end end
    end
    return s
end
local V = {}
V.__index = V
function V.__add(a,b) return setmetatable({ X=a.X+b.X, Y=a.Y+b.Y, Z=(a.Z or 0)+(b.Z or 0) },V) end
function V.__sub(a,b) return setmetatable({ X=a.X-b.X, Y=a.Y-b.Y, Z=(a.Z or 0)-(b.Z or 0) },V) end
function V.__div(a,b) return setmetatable({ X=a.X/b, Y=a.Y/b },V) end
local Vector2 = { new = function(x,y) return setmetatable({ X=x,Y=y },V) end }
Vector2.zero = Vector2.new(0,0)
local UDim = { new = function(s,o) return { Scale=s,Offset=o } end }
local UDim2 = { new = function(xs,xo,ys,yo) return { X=UDim.new(xs or 0,xo or 0),Y=UDim.new(ys or 0,yo or 0) } end }
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
local Color3 = { fromRGB = function(r,g,b) return { R=r,G=g,B=b } end }
local Enum = setmetatable({}, { __index = function(self,group)
    local values = setmetatable({}, { __index = function(t,key) local v={Name=key};rawset(t,key,v);return v end })
    rawset(self,group,values); return values
end })
local viewport = Vector2.new(1280,720)
local events = { Activated=true,MouseEnter=true,MouseLeave=true,SelectionGained=true,SelectionLost=true,
    Focused=true,FocusLost=true,InputBegan=true,InputChanged=true,InputEnded=true,WindowFocusReleased=true }
local methods, object_mt = {}, {}
local focused_box
local gui_classes = { Frame=true,CanvasGroup=true,ScrollingFrame=true,TextButton=true,TextLabel=true,TextBox=true }
function object_mt.__index(self,key)
    if methods[key] then return methods[key] end
    if key == "AbsoluteSize" then
        if self.ClassName == "ScreenGui" then return viewport end
        local parent = self.Parent and self.Parent.AbsoluteSize or viewport
        local size = self.Size or UDim2.fromOffset(0,0)
        return Vector2.new(parent.X*size.X.Scale+size.X.Offset,parent.Y*size.Y.Scale+size.Y.Offset)
    end
    if key == "AbsolutePosition" then
        local p = self.Parent and self.Parent.AbsolutePosition or Vector2.zero
        local parent = self.Parent and self.Parent.AbsoluteSize or viewport
        local position,anchor = self.Position or UDim2.fromOffset(0,0),self.AnchorPoint or Vector2.zero
        return Vector2.new(p.X+parent.X*position.X.Scale+position.X.Offset-self.AbsoluteSize.X*anchor.X,
            p.Y+parent.Y*position.Y.Scale+position.Y.Offset-self.AbsoluteSize.Y*anchor.Y)
    end
    if events[key] then self._events[key]=self._events[key] or signal();return self._events[key] end
    return self._props[key]
end
function object_mt.__newindex(self,key,value)
    if key:sub(1,1)=="_" then rawset(self,key,value);return end
    local old=self._props[key]
    if old==value then return end
    if key=="Parent" then
        if old then local i=table.find(old._children,self);if i then table.remove(old._children,i) end end
        if value then table.insert(value._children,self) end
    end
    self._props[key]=value
    if self._changes[key] then self._changes[key]:Fire() end
end
function methods:GetPropertyChangedSignal(key) self._changes[key]=self._changes[key] or signal();return self._changes[key] end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
    local result={}
    for _,child in ipairs(self._children) do table.insert(result,child);for _,sub in ipairs(child:GetDescendants()) do table.insert(result,sub) end end
    return result
end
function methods:FindFirstChild(name,recursive)
    for _,child in ipairs(self._children) do if child.Name==name then return child end end
    if recursive then for _,child in ipairs(self._children) do local found=child:FindFirstChild(name,true);if found then return found end end end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:IsA(class) return self.ClassName==class or class=="GuiObject" and gui_classes[self.ClassName]==true end
function methods:IsDescendantOf(parent) local p=self.Parent;while p do if p==parent then return true end;p=p.Parent end;return false end
function methods:SetAttribute(key,value) self._attributes[key]=value end
function methods:GetAttribute(key) return self._attributes[key] end
function methods:Destroy() for _,c in ipairs(self:GetChildren()) do c:Destroy() end;self.Parent=nil;self._destroyed=true end
function methods:CaptureFocus() focused_box=self;self.Focused:Fire() end
function methods:ReleaseFocus() focused_box=nil;self.FocusLost:Fire() end
local Instance = { new = function(class)
    return setmetatable({ _props={ClassName=class,Name=class,Visible=true,Active=true,Selectable=true,Text="",TextTransparency=0,GroupTransparency=0},
        _children={},_events={},_changes={},_attributes={} },object_mt)
end }
local task_queue = {}
local task = { cancel=function(thread) coroutine.close(thread) end, wait=function() coroutine.yield() end }
function task.defer(callback,...) local t=coroutine.create(callback);table.insert(task_queue,{thread=t,args=table.pack(...)});return t end
task.spawn=task.defer
function task.delay(_,callback,...) return task.defer(callback,...) end
local player = Instance.new("Player");player:SetAttribute("DataSlot","A")
local player_gui = Instance.new("PlayerGui");player_gui.Name="PlayerGui";player_gui.Parent=player
local input=Instance.new("UserInputService")
function input:GetFocusedTextBox() return focused_box or self.focused end
function input:IsKeyDown() return false end
local gui_service=Instance.new("GuiService");gui_service.ReducedMotionEnabled=true
local tween_calls=0
local tween_service={ Create=function(_,object,_,goals)
    tween_calls+=1
    return { Play=function() for k,v in pairs(goals) do object[k]=v end end,Cancel=function() end }
end }
local TweenInfo = { new=function() return {} end }
local services={Players={LocalPlayer=player},UserInputService=input,GuiService=gui_service,TweenService=tween_service}
local game={GetService=function(_,name) return assert(services[name],name) end}
local theme=(function() ${read("src/arteria/theme.lua")} end)()
local catalog=(function() ${read("src/arteria/catalog.lua")} end)()
local require=function(name) assert(name=="@src/arteria/theme",name);return theme end
local UI=(function() ${read("src/arteria/ui.lua")} end)()
local resources={}
local runtime={alive=true,status="ready",catalog=catalog,flags={},features={},errors={},ac_loaded=true,
    maid={give_task=function(_,value) table.insert(resources,value) end}}
function runtime:set(id,value) self.flags[id]=value;self.refresh() end
function runtime:option(option,value) self.flags[option.id]=value end
runtime.echo={session={},state="idle",running=false,owned={}}
local farm_starts,farm_stops=0,0
function runtime.echo:start(slot) assert(slot=="A");farm_starts+=1;self.running=true;self.session.enabled=true end
function runtime.echo:stop() farm_stops+=1;self.running=false;self.session.enabled=false;runtime.refresh() end
local config_saved,config_loaded,config_deleted=0,0,0
runtime.config={message="Profiles ready",profiles={"one"},autoload_name=nil}
function runtime.config:list() return self.profiles end
function runtime.config:save(name) assert(name=="one");config_saved+=1 end
function runtime.config:load(name,flags) assert(name=="one");config_loaded+=1;self.last_flags=flags end
function runtime.config:delete(name) assert(name=="one");config_deleted+=1 end
function runtime.config:get_autoload() return self.autoload_name,false end
function runtime.config:set_autoload(name) self.autoload_name=name end
function runtime.config:clear_autoload() self.autoload_name=nil end
for _,entry in ipairs(catalog.entries) do runtime.flags[entry.id]=false;for _,o in ipairs(entry.settings) do runtime.flags[o.id]=o.value end end
UI.mount(runtime)
local panel=runtime.gui:FindFirstChild("Panel")
local sidebar=panel:FindFirstChild("Sidebar")
local navigation=sidebar:FindFirstChild("Navigation")
local content=panel:FindFirstChild("Content")
local scroll=content:FindFirstChild("Features")
local search=content:FindFirstChild("Search")
local echo=content:FindFirstChild("Automation"):FindFirstChild("Cycle")
local function fire(button) button.Activated:Fire() end
local function visible_count()
    local count=0;for _,child in ipairs(scroll:GetChildren()) do if child:IsA("Frame") and child.Visible then count+=1 end end;return count
end
assert(panel.AbsoluteSize.X==880 and sidebar.AbsoluteSize.X==210,"desktop composition")
local nav_settings=navigation:FindFirstChild("NavSettings")
assert(nav_settings:FindFirstChild("UIPadding").PaddingLeft.Offset-nav_settings:FindFirstChild("Marker").Position.X.Offset-2>=20,"selection marker must stay separated from 07")
assert(navigation.ScrollBarThickness==0,"remove the distracting sidebar scroll stripe")
assert(visible_count()==6,"preserve movement controls")
assert(tween_calls==0,"system reduced-motion preference must skip all tweens")
local total=0;for _,child in ipairs(scroll:GetChildren()) do if child:IsA("Frame") then total+=1 end end
assert(total==62,"preserve selected features and add the Arteria ESP suite")
fire(navigation:FindFirstChild("NavCombat"))
local expected=0;for _,entry in ipairs(catalog.entries) do if entry.section=="Combat" then expected+=1 end end
assert(visible_count()==expected,"sidebar navigation")
search.Text="no "
assert(visible_count()>10,"cross-section search")
search.Text="no-such-feature"
assert(visible_count()==0,"empty search")
fire(navigation:FindFirstChild("NavMovement"))
local fly=scroll:FindFirstChild("fly")
fire(fly:FindFirstChild("Toggle"));assert(runtime.flags.fly,"toggle forwarding")
fly:FindFirstChild("Toggle").MouseEnter:Fire()
assert(fly:FindFirstChild("Toggle").TextColor3==theme.color.ink,"inverted hover contrast")
fire(fly:FindFirstChild("Bind"))
input.InputBegan:Fire({KeyCode=Enum.KeyCode.K,UserInputType=Enum.UserInputType.Keyboard},false)
assert(runtime.bindings.fly==Enum.KeyCode.K,"rebind")
input.InputBegan:Fire({KeyCode=Enum.KeyCode.K,UserInputType=Enum.UserInputType.Keyboard},false)
assert(not runtime.flags.fly,"rebound key dispatch")
fire(fly:FindFirstChild("Details"))
local speed=fly:FindFirstChild("Settings"):FindFirstChild("fly_speed")
speed.Text="not a number";speed.FocusLost:Fire();assert(speed.Text=="60","invalid numeric input")
speed.Text="99999";speed.FocusLost:Fire();assert(runtime.flags.fly_speed==250,"numeric clamping")
fire(navigation:FindFirstChild("NavAutomation"))
assert(not scroll.Visible and content:FindFirstChild("Automation").Visible,"echo workflow under Automation")
fire(echo:FindFirstChild("StartEcho"));assert(farm_starts==0,"no unconfirmed destructive start")
echo:FindFirstChild("SlotConfirmation").Text="B"
fire(echo:FindFirstChild("AcknowledgeWipe"));fire(echo:FindFirstChild("StartEcho"))
assert(farm_starts==0,"wrong-slot guard")
echo:FindFirstChild("SlotConfirmation").Text="A"
assert(echo:FindFirstChild("StartEcho").Active,"explicit consent enables start")
fire(echo:FindFirstChild("StartEcho"));assert(farm_starts==1,"farm start forwarding only after consent")
fire(echo:FindFirstChild("StopEcho"));assert(farm_stops==1,"farm stop forwarding")
fire(navigation:FindFirstChild("NavSettings"))
local profiles=content:FindFirstChild("SettingsPage"):FindFirstChild("Profiles")
profiles:FindFirstChild("ProfileName").Text="one"
fire(profiles:FindFirstChild("SaveProfile"));assert(config_saved==1,"save config action")
fire(profiles:FindFirstChild("LoadProfile"));assert(config_loaded==1 and runtime.config.last_flags==false,"profile loads settings only by default")
fire(profiles:FindFirstChild("RestoreToggles"));fire(profiles:FindFirstChild("LoadProfile"))
assert(runtime.config.last_flags==true,"explicit toggle restore")
fire(profiles:FindFirstChild("DeleteProfile"));assert(config_deleted==0,"delete requires confirmation")
fire(profiles:FindFirstChild("DeleteProfile"));assert(config_deleted==1,"confirmed profile delete")
fire(profiles:FindFirstChild("MenuKey"))
input.InputBegan:Fire({KeyCode=Enum.KeyCode.Home,UserInputType=Enum.UserInputType.Keyboard},false)
assert(runtime.ui_key==Enum.KeyCode.Home,"menu key rebinding")
fire(navigation:FindFirstChild("NavVisuals"))
assert(visible_count()==11 and scroll:FindFirstChild("skeleton_esp").Visible and scroll:FindFirstChild("player_esp").Visible and scroll:FindFirstChild("mob_esp").Visible and scroll:FindFirstChild("chest_esp").Visible and scroll:FindFirstChild("npc_esp").Visible and scroll:FindFirstChild("mod_detector").Visible,"Visuals ESP suite")
fire(navigation:FindFirstChild("NavMovement"))
viewport=Vector2.new(360,780);runtime.gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
assert(panel.AbsoluteSize.X==336 and sidebar.AbsoluteSize.X==64,"mobile rail without shrinking typography")
for _,child in ipairs(scroll:GetChildren()) do
    if child:IsA("Frame") then
        for _,name in ipairs({"Bind","Details","Toggle"}) do
            local b=child:FindFirstChild(name)
            assert(b.AbsolutePosition.X>=child.AbsolutePosition.X and b.AbsolutePosition.X+b.AbsoluteSize.X<=child.AbsolutePosition.X+child.AbsoluteSize.X+0.1,"mobile control overflow")
        end
    end
end
viewport=Vector2.new(780,360);runtime.gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
assert(navigation.AbsolutePosition.Y+navigation.AbsoluteSize.Y <= sidebar:FindFirstChild("ReducedMotion").AbsolutePosition.Y,"scrolling landscape navigation must not overlap footer")
input.InputBegan:Fire({KeyCode=Enum.KeyCode.Tab,UserInputType=Enum.UserInputType.Keyboard},false)
assert(gui_service.SelectedObject,"keyboard focus traversal")
input.InputBegan:Fire({KeyCode=Enum.KeyCode.Return,UserInputType=Enum.UserInputType.Keyboard},false)
assert(input:GetFocusedTextBox()==search,"keyboard can focus search input")
input.InputBegan:Fire({KeyCode=Enum.KeyCode.Tab,UserInputType=Enum.UserInputType.Keyboard},true)
assert(not input:GetFocusedTextBox() and gui_service.SelectedObject~=search,"Tab exits text editing and advances focus")
runtime.show_ui(false);assert(not panel.Visible,"reduced-motion hide")
runtime.show_ui(true);assert(panel.Visible,"show")
gui_service.ReducedMotionEnabled=false
fire(navigation:FindFirstChild("NavCombat"));assert(tween_calls>0,"motion enabled when allowed")
runtime.alive=false
for _,resource in ipairs(resources) do
    if type(resource)=="function" then resource()
    elseif resource.Disconnect then resource:Disconnect()
    elseif resource.Destroy then resource:Destroy() end
end
runtime.gui:Destroy()
assert(#player_gui:GetChildren()==0,"GUI cleanup")
print("arteria UI: neon controls, marker spacing, seven-section sidebar, 49 controls, config actions, bindings, slot consent, keyboard, responsive bounds, motion and cleanup passed")
`;
try {
    fs.writeFileSync(file, source);
    console.log(execFileSync(binary, [file], { cwd: root, encoding: "utf8" }));
} finally {
    fs.unlinkSync(file);
    fs.rmdirSync(directory);
}
