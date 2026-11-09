-- Arteria backend for the existing visual/player_esp entry point.
local theme = require("@src/arteria/theme")
local C = theme.color
local feature = { id = "player_esp", targets = {} }
local players = game:GetService("Players")
local function create(class, props, parent)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end
local function segment(parent, glow)
    local line = create("Frame", { Name = glow and "NeonHalo" or "FrameLine", BorderSizePixel = 0,
        BackgroundColor3 = C.neon, BackgroundTransparency = glow and 0.87 or 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Visible = false }, parent)
    if not glow then create("UIStroke",{Color=C.ink,Transparency=0.25,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},line) end
    return line
end
local function label(parent)
    return create("TextLabel", { Name = "Label", BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = theme.font.mono, TextColor3 = C.text, TextStrokeColor3 = C.ink, TextStrokeTransparency = 0.15,
        RichText = false, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 13, Size = UDim2.fromOffset(260, 20), AnchorPoint = Vector2.new(0.5, 0.5),
        Text = "", Visible = false }, parent)
end
local function hide(data)
    for _, line in ipairs(data.lines) do line.Visible = false end
    for _, line in ipairs(data.glow) do line.Visible = false end
    data.name.Visible, data.info.Visible, data.track.Visible, data.fill.Visible, data.highlight.Enabled = false, false, false, false, false
end
local function draw(data,index,x,y,width,height)
    local line,glow=data.lines[index],data.glow[index]
    line.Position,line.Size,line.Visible=UDim2.fromOffset(x,y),UDim2.fromOffset(width,height),true
    glow.Position,glow.Size,glow.Visible=line.Position,UDim2.fromOffset(width+3,height+3),true
end
function feature:add(player)
    if player == players.LocalPlayer or self.targets[player] then return end
    local data = { lines = {}, glow = {} }
    for _ = 1, 8 do table.insert(data.lines, segment(self.gui, false)); table.insert(data.glow, segment(self.gui, true)) end
    data.name, data.info = label(self.gui), label(self.gui)
    data.track = create("Frame", { Name = "HealthTrack", BorderSizePixel = 0, BackgroundColor3 = C.ink,
        BackgroundTransparency = 0.2, Visible = false }, self.gui)
    data.fill = create("Frame", { Name = "HealthFill", BorderSizePixel = 0, BackgroundColor3 = C.neon, Visible = false }, self.gui)
    data.highlight = create("Highlight", { Name = "ArteriaOutline", Enabled = false, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        FillColor = C.text, OutlineColor = C.neon, FillTransparency = 1, OutlineTransparency = 0.15 }, self.highlights)
    self.targets[player] = data
end
function feature:remove(player)
    local data = self.targets[player]
    if not data then return end
    for _, line in ipairs(data.lines) do line:Destroy() end
    for _, line in ipairs(data.glow) do line:Destroy() end
    for _, key in ipairs({ "name", "info", "track", "fill", "highlight" }) do data[key]:Destroy() end
    self.targets[player] = nil
end
function feature:render()
    local camera = workspace.CurrentCamera
    local own = players.LocalPlayer
    local own_root = own.Character and own.Character:FindFirstChild("HumanoidRootPart")
    local origin = own_root and own_root.Position or (camera and camera.CFrame.Position)
    local now = os.clock()
    for player, data in pairs(self.targets) do
        hide(data)
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local head = character and character:FindFirstChild("Head")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not camera or not origin or not root or not head or not humanoid or humanoid.Health <= 0 then continue end
        if aztup_options.arteria_player_teams.Value == "Other teams" and own.Team ~= nil and own.Team == player.Team then continue end
        local distance = (root.Position - origin).Magnitude
        if distance > aztup.flags.arteria_player_range then continue end
        local top, top_visible = camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y / 2 + 0.3, 0))
        local bottom, bottom_visible = camera:WorldToViewportPoint(root.Position - Vector3.new(0, (humanoid.HipHeight or 0) + root.Size.Y / 2 + 2, 0))
        if not top_visible or not bottom_visible or top.Z <= 0 or bottom.Z <= 0 then continue end
        local height = math.abs(bottom.Y - top.Y)
        if height < 6 or height > camera.ViewportSize.Y * 2 then continue end
        local width, cx, y = height * 0.48, (top.X + bottom.X) / 2, math.min(top.Y, bottom.Y)
        local left, right, lower = cx - width / 2, cx + width / 2, y + height
        local style = aztup_options.arteria_player_boxes.Value
        if style ~= "No box" then
            local h, v = width * 0.27, height * 0.18
            if style == "Full box" then h, v = width / 2, height / 2 end
            draw(data,1,left+h/2,y,h,1);draw(data,2,left,y+v/2,1,v)
            draw(data,3,right-h/2,y,h,1);draw(data,4,right,y+v/2,1,v)
            draw(data,5,left+h/2,lower,h,1);draw(data,6,left,lower-v/2,1,v)
            draw(data,7,right-h/2,lower,h,1);draw(data,8,right,lower-v/2,1,v)
        end
        local health = math.clamp(humanoid.Health / math.max(1,humanoid.MaxHealth),0,1)
        local health_mode = aztup_options.arteria_player_health.Value
        if health_mode == "Bar" or health_mode == "Bar and value" then
            data.track.Position, data.track.Size, data.track.Visible = UDim2.fromOffset(left-7,y-1), UDim2.fromOffset(4,height+2), true
            data.fill.Position, data.fill.Size, data.fill.Visible = UDim2.fromOffset(left-6,lower-height*health), UDim2.fromOffset(2,height*health), true
        end
        local name_mode = aztup_options.arteria_player_names.Value
        data.name.Position, data.name.TextSize, data.name.Visible = UDim2.fromOffset(cx,y-13), aztup.flags.arteria_player_text, name_mode ~= "Hidden"
        data.info.Position, data.info.TextSize = UDim2.fromOffset(cx,lower+13), aztup.flags.arteria_player_text
        if not data.updated or now-data.updated >= 0.1 then
            data.updated = now
            data.name.Text = name_mode == "Character" and (player:GetAttribute("CharacterName") or player.Name)
                or (name_mode == "Display name" and player.DisplayName or player.Name)
            local info = {}
            if aztup_options.arteria_player_distance.Value == "Shown" then table.insert(info,string.format("%d studs",math.floor(distance))) end
            if health_mode == "Value" or health_mode == "Bar and value" then table.insert(info,string.format("%d / %d HP",math.floor(humanoid.Health),math.floor(humanoid.MaxHealth))) end
            data.info.Text = table.concat(info,"  /  ")
        end
        data.info.Visible = data.info.Text ~= ""
        local highlight_mode = aztup_options.arteria_player_highlight.Value
        data.highlight.Adornee, data.highlight.Enabled = character, highlight_mode ~= "Off"
        data.highlight.FillTransparency = highlight_mode == "Silhouette" and 0.9 or 1
    end
end
function feature:enable()
    self:disable()
    self.gui = create("ScreenGui", { Name = "ArteriaPlayerESP", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 98 }, players.LocalPlayer:WaitForChild("PlayerGui"))
    self.highlights = create("Folder", { Name = "ArteriaESPHighlights" }, workspace)
    self.added = players.PlayerAdded:Connect(function(player) self:add(player) end)
    self.removing = players.PlayerRemoving:Connect(function(player) self:remove(player) end)
    for _, player in ipairs(players:GetPlayers()) do self:add(player) end
    self.conn = game:GetService("RunService").RenderStepped:Connect(function()
        local ok, err = pcall(self.render,self)
        if not ok then
            aztup_toggles.player_esp:SetValue(false)
            local runtime=getgenv().arteria
            if runtime then runtime.errors.player_esp=tostring(err);runtime.refresh() end
            warn("[arteria] player ESP: " .. tostring(err))
        end
    end)
end
function feature:disable()
    for _, key in ipairs({ "conn", "added", "removing" }) do if self[key] then self[key]:Disconnect(); self[key]=nil end end
    if self.gui then self.gui:Destroy(); self.gui=nil end
    if self.highlights then self.highlights:Destroy(); self.highlights=nil end
    self.targets = {}
end
return feature
