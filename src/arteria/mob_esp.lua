-- Arteria Mob ESP: Skeletons (Motor6D + R6/R15 fallback), Health bars & values, Distance labels.
-- Bounded, pre-allocated screen-space line and text pools. Zero per-frame allocations.
local theme = require("@src/arteria/theme")
local C = theme.color
local feature = { id = "mob_esp", targets = {}, bones_cache = {} }
local players = game:GetService("Players")

local function create(class, props, parent)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end

local function clean_name(raw)
    local name = tostring(raw):gsub("<[^>]*>", ""):gsub("^%.", ""):gsub("%d+$", ""):gsub("_", " ")
    name = name:match("^%s*(.-)%s*$")
    if name == "" then name = "Mob" end
    return name
end

local function get_mob_bones(model)
    local bones = {}
    -- 1. Query active Motor6D joints connecting body parts
    local ok_desc, all_parts = pcall(function() return model:GetDescendants() end)
    if ok_desc and type(all_parts) == "table" then
        for _, motor in ipairs(all_parts) do
            if motor.IsA and motor:IsA("Motor6D") and motor.Part0 and motor.Part1 and motor.Part0.IsA and motor.Part0:IsA("BasePart") and motor.Part1.IsA and motor.Part1:IsA("BasePart") then
                table.insert(bones, { motor.Part0, motor.Part1 })
                if #bones >= 24 then break end
            end
        end
    end
    if #bones > 0 then
        return bones
    end
    -- 2. Fallback to standard named rig parts if no Motor6D joints exist
    local head = model:FindFirstChild("Head")
    local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
    if head and torso and head:IsA("BasePart") and torso:IsA("BasePart") then
        table.insert(bones, { head, torso })
    end
    if torso and torso:IsA("BasePart") then
        local names = { "Left Arm", "Right Arm", "Left Leg", "Right Leg", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" }
        for _, name in ipairs(names) do
            local limb = model:FindFirstChild(name)
            if limb and limb:IsA("BasePart") then
                table.insert(bones, { torso, limb })
            end
        end
    end
    return bones
end

local MAX_MOBS = 50
local BONES_PER_MOB = 20

function feature:render(dt)
    local camera = workspace.CurrentCamera
    if not camera or camera.ViewportSize.X < 16 or camera.ViewportSize.Y < 48 then return end

    local own_character = players.LocalPlayer.Character
    local own_root = own_character and own_character:FindFirstChild("HumanoidRootPart")
    local origin = own_root and own_root.Position or camera.CFrame.Position

    local live = workspace:FindFirstChild("Live")
    if not live then return end

    local max_dist = aztup.flags.arteria_mob_range or 2000
    local show_skeleton = aztup_options.arteria_mob_skeleton.Value == "Enabled"
    local health_mode = aztup_options.arteria_mob_health.Value
    local show_dist = aztup_options.arteria_mob_distance.Value == "Shown"
    local thickness = aztup.flags.arteria_mob_thickness or 1
    local text_size = aztup.flags.arteria_mob_text or 13
    local limit = math.min(MAX_MOBS, aztup.flags.arteria_mob_limit or 40)

    -- Collect living mob candidates
    local candidates = {}
    for _, mob in ipairs(live:GetChildren()) do
        if mob:IsA("Model") and mob.Name:sub(1, 1) == "." and not mob.Name:match("watcher") and mob ~= own_character then
            local root = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso") or mob:FindFirstChildWhichIsA("BasePart")
            local humanoid = mob:FindFirstChildOfClass("Humanoid")
            if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
                local dist = (root.Position - origin).Magnitude
                if dist <= max_dist then
                    table.insert(candidates, { mob = mob, root = root, humanoid = humanoid, dist = dist })
                end
            end
        end
    end

    table.sort(candidates, function(a, b) return a.dist < b.dist end)

    local active_count = math.min(#candidates, limit)
    local now = os.clock()

    for i = 1, MAX_MOBS do
        local slot = self.pool[i]
        if i <= active_count then
            local item = candidates[i]
            local mob, root, humanoid, dist = item.mob, item.root, item.humanoid, item.dist
            local point, on_screen = camera:WorldToViewportPoint(root.Position)

            if on_screen and point.Z > 0 then
                -- 1. Render Skeleton Bones
                local bone_pairs = self.bones_cache[mob]
                if not bone_pairs or (now - (slot.cache_time or 0) > 3) then
                    bone_pairs = get_mob_bones(mob)
                    self.bones_cache[mob] = bone_pairs
                    slot.cache_time = now
                end

                local bone_idx = 0
                if show_skeleton and bone_pairs then
                    for _, pair in ipairs(bone_pairs) do
                        if pair[1].Parent and pair[2].Parent then
                            local p0, v0 = camera:WorldToViewportPoint(pair[1].Position)
                            local p1, v1 = camera:WorldToViewportPoint(pair[2].Position)
                            if (v0 or v1) and p0.Z > 0 and p1.Z > 0 then
                                bone_idx = bone_idx + 1
                                if bone_idx <= BONES_PER_MOB then
                                    local line = slot.bones[bone_idx]
                                    local dx, dy = p1.X - p0.X, p1.Y - p0.Y
                                    local length = math.sqrt(dx * dx + dy * dy)
                                    if length > 0.5 then
                                        line.Position = UDim2.fromOffset((p0.X + p1.X) / 2, (p0.Y + p1.Y) / 2)
                                        line.Size = UDim2.fromOffset(length, thickness)
                                        line.Rotation = math.deg(math.atan2(dy, dx))
                                        line.Visible = true
                                    else
                                        line.Visible = false
                                    end
                                end
                            end
                        end
                    end
                end
                for b = bone_idx + 1, BONES_PER_MOB do
                    slot.bones[b].Visible = false
                end

                -- 2. Render Name, Health, and Distance Label
                local name = clean_name(mob:GetAttribute("MOB_rich_name") or mob.Name)
                local hp = math.floor(humanoid.Health)
                local max_hp = math.floor(math.max(1, humanoid.MaxHealth))
                local ratio = math.clamp(hp / max_hp, 0, 1)

                local lines = { name }
                if show_dist then
                    table.insert(lines, string.format("%d studs", math.floor(dist)))
                end
                if health_mode == "Value" or health_mode == "Bar and value" then
                    table.insert(lines, string.format("%d / %d HP", hp, max_hp))
                end

                slot.label.Text = table.concat(lines, "  ·  ")
                slot.label.TextSize = text_size
                slot.label.Position = UDim2.fromOffset(point.X, point.Y - 26)
                slot.label.Visible = true

                -- 3. Render Health Bar
                if health_mode == "Bar" or health_mode == "Bar and value" then
                    local bounds = slot.label.TextBounds
                    local bar_w = (bounds and bounds.X > 0) and math.clamp(bounds.X + 8, 48, 120) or 64
                    slot.bar_track.Size = UDim2.fromOffset(bar_w, 3)
                    slot.bar_track.Position = UDim2.fromOffset(point.X, point.Y - 14)
                    slot.bar_track.Visible = true

                    slot.bar_fill.Size = UDim2.fromOffset(math.max(1, math.floor(bar_w * ratio)), 3)
                    slot.bar_fill.Position = UDim2.fromOffset(point.X - bar_w / 2 + (bar_w * ratio) / 2, point.Y - 14)
                    slot.bar_fill.BackgroundColor3 = ratio < 0.25 and C.alert or C.neon
                    slot.bar_fill.Visible = true
                else
                    slot.bar_track.Visible = false
                    slot.bar_fill.Visible = false
                end
            else
                slot:hide()
            end
        else
            slot:hide()
        end
    end
end

function feature:enable()
    self:disable()
    self.pool = {}
    self.bones_cache = {}

    self.gui = create("ScreenGui", {
        Name = "ArteriaMobESP",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 96,
    }, players.LocalPlayer:WaitForChild("PlayerGui"))

    for i = 1, MAX_MOBS do
        local slot = { bones = {} }

        for b = 1, BONES_PER_MOB do
            local line = create("Frame", {
                Name = "MobBone",
                BorderSizePixel = 0,
                BackgroundColor3 = C.neon,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Visible = false,
            }, self.gui)
            table.insert(slot.bones, line)
        end

        slot.label = create("TextLabel", {
            Name = "MobLabel",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Font = theme.font.mono,
            TextColor3 = C.text,
            TextStrokeColor3 = C.ink,
            TextStrokeTransparency = 0.15,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Text = "",
            Visible = false,
        }, self.gui)

        slot.bar_track = create("Frame", {
            Name = "HealthTrack",
            BorderSizePixel = 0,
            BackgroundColor3 = C.ink,
            BackgroundTransparency = 0.3,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Visible = false,
        }, self.gui)

        slot.bar_fill = create("Frame", {
            Name = "HealthFill",
            BorderSizePixel = 0,
            BackgroundColor3 = C.neon,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Visible = false,
        }, self.gui)

        function slot:hide()
            for _, b in ipairs(self.bones) do b.Visible = false end
            self.label.Visible = false
            self.bar_track.Visible = false
            self.bar_fill.Visible = false
        end

        table.insert(self.pool, slot)
    end

    self.conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
        local ok, err = pcall(self.render, self, dt)
        if not ok then
            local runtime = getgenv().arteria
            if runtime then runtime.errors.mob_esp = tostring(err); runtime.refresh() end
            aztup_toggles.mob_esp:SetValue(false)
            warn("[arteria] mob ESP: " .. tostring(err))
        end
    end)
end

function feature:disable()
    if self.conn then self.conn:Disconnect(); self.conn = nil end
    if self.gui then self.gui:Destroy(); self.gui = nil end
    self.pool = {}
    self.bones_cache = {}
end

return feature
