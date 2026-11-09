-- Arteria backend for legacy base_esp categories. Bounded, pooled labels.
local theme = require("@src/arteria/theme")
local C = theme.color
local feature = { id = "world_esp" }
local groups = { "Live", "Thrown", "Ingredients" }
local function category(group, entity)
    if group == "Live" and entity.Name:sub(1,1) == "." and not entity.Name:match("watcher") then return "Mobs" end
    if group == "Ingredients" then return "Ingredients" end
    if group == "Thrown" then
        if entity.Name == "BigArtifact" then return "Artifacts" end
        if entity.Name == "Chest" or entity:FindFirstChild("Lid") then return "Chests" end
    end
end
local function root(entity)
    if entity:IsA("BasePart") then return entity end
    for _,name in ipairs({"HumanoidRootPart","Lid"}) do
        local part=entity:FindFirstChild(name)
        if part and part:IsA("BasePart") then return part end
    end
    return entity:FindFirstChildWhichIsA("BasePart",true)
end
function feature:scan()
    table.clear(self.targets)
    for _, name in ipairs(groups) do
        local group = workspace:FindFirstChild(name)
        if not group then continue end
        for _, entity in ipairs(group:GetChildren()) do
            local tag = category(name,entity)
            if tag then table.insert(self.targets,{entity=entity,tag=tag}) end
            if #self.targets >= 2000 then return end
        end
    end
end
function feature:render(dt)
    self.elapsed = self.elapsed + dt
    if self.elapsed < 1 / aztup.flags.arteria_world_rate then return end
    self.elapsed = 0
    if os.clock() >= self.next_scan then self.next_scan=os.clock()+1;self:scan() end
    for _, label in ipairs(self.labels) do label.Visible=false end
    local camera = workspace.CurrentCamera
    if not camera then return end
    if camera.ViewportSize.X < 16 or camera.ViewportSize.Y < 48 then return end
    local player = game:GetService("Players").LocalPlayer
    local own = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local origin = own and own.Position or camera.CFrame.Position
    local candidates = {}
    local selected = aztup_options.arteria_world_category.Value
    for _, item in ipairs(self.targets) do
        local entity = item.entity
        if not entity.Parent or (selected ~= "All" and selected ~= item.tag) then continue end
        local part = root(entity)
        if not part or not part:IsA("BasePart") then continue end
        local distance = (part.Position-origin).Magnitude
        if distance > aztup.flags.arteria_world_range then continue end
        local humanoid = item.tag == "Mobs" and entity:FindFirstChildOfClass("Humanoid") or nil
        if item.tag == "Mobs" and (not humanoid or humanoid.Health <= 0) then continue end
        local point, visible = camera:WorldToViewportPoint(part.Position)
        if not visible or point.Z <= 0 then continue end
        table.insert(candidates,{item=item,point=point,distance=distance,humanoid=humanoid})
    end
    table.sort(candidates,function(a,b)return a.distance<b.distance end)
    local count = math.min(#candidates,math.floor(aztup.flags.arteria_world_limit),#self.labels)
    for index=1,count do
        local entry = candidates[index]
        local entity, tag = entry.item.entity, entry.item.tag
        local name = entity:GetAttribute("MOB_rich_name") or entity.Name
        name = tostring(name):gsub("<[^>]*>",""):gsub("^%.",""):gsub("%d+$",""):gsub("_"," ")
        local label = self.labels[index]
        local text = string.format("%s / %s / %d studs",string.upper(tag),name,math.floor(entry.distance))
        if entry.humanoid then text = text .. string.format("\n%d / %d HP",math.floor(entry.humanoid.Health),math.floor(entry.humanoid.MaxHealth)) end
        label.Text,label.TextSize = text,aztup.flags.arteria_world_text
        local width,height=math.min(260,camera.ViewportSize.X-8),entry.humanoid and 40 or 24
        label.Size=UDim2.fromOffset(width,height)
        label.Position=UDim2.fromOffset(math.clamp(entry.point.X,width/2,camera.ViewportSize.X-width/2),
            math.clamp(entry.point.Y-18,height/2,camera.ViewportSize.Y-height/2))
        label.Visible = true
    end
    self.visible_count = count
end
function feature:enable()
    self:disable()
    self.targets,self.labels,self.elapsed,self.next_scan = {},{},0,0
    self.gui = Instance.new("ScreenGui")
    self.gui.Name,self.gui.IgnoreGuiInset,self.gui.ResetOnSpawn,self.gui.DisplayOrder = "ArteriaWorldESP",true,false,97
    self.gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    for _=1,200 do
        local label = Instance.new("TextLabel")
        label.Name,label.Font,label.TextColor3,label.TextStrokeColor3 = "WorldLabel",theme.font.mono,C.text,C.ink
        label.TextStrokeTransparency,label.TextSize,label.RichText = 0.2,13,false
        label.BorderSizePixel,label.BackgroundColor3,label.BackgroundTransparency = 0,C.surface,0.2
        label.AnchorPoint,label.Visible,label.Parent = Vector2.new(0.5,0.5),false,self.gui
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode,stroke.Color,stroke.Transparency,stroke.Thickness = Enum.ApplyStrokeMode.Border,C.neon,0.7,1
        stroke.Parent = label
        table.insert(self.labels,label)
    end
    self.conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
        local ok,err=pcall(self.render,self,dt)
        if not ok then
            aztup_toggles.world_esp:SetValue(false)
            local runtime=getgenv().arteria
            if runtime then runtime.errors.world_esp=tostring(err);runtime.refresh() end
            warn("[arteria] world ESP: "..tostring(err))
        end
    end)
end
function feature:disable()
    if self.conn then self.conn:Disconnect();self.conn=nil end
    if self.gui then self.gui:Destroy();self.gui=nil end
    self.targets,self.labels,self.visible_count = {},{},0
end
return feature
