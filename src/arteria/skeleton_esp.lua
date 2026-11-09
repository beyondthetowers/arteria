-- Image-free R6/R15 skeleton overlay. No Drawing API, physics or remotes.
local feature = { id = "skeleton_esp" }
local players = game:GetService("Players")
local rigs = {
    r6 = { {"Head","Torso"}, {"Torso","Left Arm"}, {"Torso","Right Arm"},
        {"Torso","Left Leg"}, {"Torso","Right Leg"} },
    r15 = { {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
        {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
        {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
        {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
        {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"} },
}
local function point(part)
    return part and part:IsA("BasePart") and part.Position or nil
end
local function line(parent)
    local object = Instance.new("Frame")
    object.Name, object.BorderSizePixel, object.BackgroundColor3 = "Bone", 0, Color3.fromRGB(232, 230, 227)
    object.AnchorPoint, object.Visible, object.Parent = Vector2.new(0.5, 0.5), false, parent
    return object
end
function feature:render()
    local camera = workspace.CurrentCamera
    local own = players.LocalPlayer
    local own_character = own.Character
    local own_root = own_character and own_character:FindFirstChild("HumanoidRootPart")
    local origin = own_root and own_root.Position or (camera and camera.CFrame.Position)
    for player, data in pairs(self.targets) do
        for _, bone in ipairs(data.lines) do bone.Visible = false end
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local other_team = not (own.Team ~= nil and own.Team == player.Team)
        local filter = aztup_options.skeleton_esp_targets.Value
        if not camera or not origin or not root or not humanoid or humanoid.Health <= 0
            or (filter == "Other teams" and not other_team)
            or (root.Position - origin).Magnitude > aztup.flags.skeleton_esp_range then continue end
        local graph = character:FindFirstChild("UpperTorso") and rigs.r15 or rigs.r6
        local count = 0
        for _, pair in ipairs(graph) do
            local a, b = point(character:FindFirstChild(pair[1])), point(character:FindFirstChild(pair[2]))
            if a and b then
                count += 1
                local p, p_visible = camera:WorldToViewportPoint(a)
                local q, q_visible = camera:WorldToViewportPoint(b)
                local bone = data.lines[count]
                if p_visible and q_visible and p.Z > 0 and q.Z > 0 then
                    local dx, dy = q.X - p.X, q.Y - p.Y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance > 0.5 then
                        bone.Position = UDim2.fromOffset((p.X + q.X) / 2, (p.Y + q.Y) / 2)
                        bone.Size = UDim2.fromOffset(distance, aztup.flags.skeleton_esp_thickness)
                        bone.Rotation, bone.Visible = math.deg(math.atan2(dy, dx)), true
                    end
                end
            end
        end
        -- R6 has rigid limbs: extend each center to the extremity, instead of
        -- inventing elbow/knee joints that the rig does not actually possess.
        if graph == rigs.r6 then
            for _, name in ipairs({ "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
                local limb = character:FindFirstChild(name)
                if not limb or not limb:IsA("BasePart") then continue end
                count += 1
                local a, a_visible = camera:WorldToViewportPoint(limb.Position)
                local b, visible = camera:WorldToViewportPoint((limb.CFrame * CFrame.new(0, -limb.Size.Y / 2, 0)).Position)
                local bone = data.lines[count]
                local dx, dy = b.X - a.X, b.Y - a.Y
                local distance = math.sqrt(dx * dx + dy * dy)
                if a_visible and visible and a.Z > 0 and b.Z > 0 and distance > 0.5 then
                    bone.Position, bone.Size = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2), UDim2.fromOffset(distance, aztup.flags.skeleton_esp_thickness)
                    bone.Rotation, bone.Visible = math.deg(math.atan2(dy, dx)), true
                end
            end
        end
    end
end
function feature:add(player)
    if player == players.LocalPlayer or self.targets[player] then return end
    local data = { lines = {} }
    for _ = 1, #rigs.r15 do table.insert(data.lines, line(self.gui)) end
    self.targets[player] = data
end
function feature:remove(player)
    local data = self.targets[player]
    if not data then return end
    for _, bone in ipairs(data.lines) do bone:Destroy() end
    self.targets[player] = nil
end
function feature:enable()
    self:disable()
    self.targets = {}
    self.gui = Instance.new("ScreenGui")
    self.gui.Name, self.gui.IgnoreGuiInset, self.gui.ResetOnSpawn, self.gui.DisplayOrder = "ArteriaSkeletonESP", true, false, 99
    self.gui.Parent = players.LocalPlayer:WaitForChild("PlayerGui")
    self.added = players.PlayerAdded:Connect(function(player) self:add(player) end)
    self.removing = players.PlayerRemoving:Connect(function(player) self:remove(player) end)
    for _, player in ipairs(players:GetPlayers()) do self:add(player) end
    self.conn = game:GetService("RunService").RenderStepped:Connect(function()
        local ok, err = pcall(self.render, self)
        if not ok then
            aztup_toggles.skeleton_esp:SetValue(false)
            if getgenv().arteria then getgenv().arteria.errors.skeleton_esp = tostring(err); getgenv().arteria.refresh() end
            warn("[arteria] skeleton ESP: " .. tostring(err))
        end
    end)
end
function feature:disable()
    for _, id in ipairs({ "conn", "added", "removing" }) do
        if self[id] then self[id]:Disconnect(); self[id] = nil end
    end
    if self.gui then self.gui:Destroy(); self.gui = nil end
    self.targets = {}
end
return feature
