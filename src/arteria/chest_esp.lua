-- Arteria Chest ESP: Neon corner brackets and distance labels.
-- Bounded, pre-allocated screen-space line and text pools. Zero per-frame allocations.
local theme = require("@src/arteria/theme")
local C = theme.color
local feature = { id = "chest_esp", pool = {} }
local players = game:GetService("Players")

local function create(class, props, parent)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end

local MAX_CHESTS = 40

function feature:render(dt)
    local camera = workspace.CurrentCamera
    if not camera or camera.ViewportSize.X < 16 or camera.ViewportSize.Y < 48 then return end

    local own_character = players.LocalPlayer.Character
    local own_root = own_character and own_character:FindFirstChild("HumanoidRootPart")
    local origin = own_root and own_root.Position or camera.CFrame.Position

    local max_dist = aztup.flags.arteria_chest_range or 3000
    local show_opened = aztup_options.arteria_chest_opened.Value == "Show"
    local text_size = aztup.flags.arteria_chest_text or 13

    local candidates = {}

    local function check_container(container)
        if not container or not container.GetChildren then return end
        local ok, children = pcall(function() return container:GetChildren() end)
        if not ok or type(children) ~= "table" then return end
        for _, entity in ipairs(children) do
            if entity.Name == "Chest" or entity:FindFirstChild("Lid") then
                local lid = entity:FindFirstChild("Lid")
                local part = lid or entity:FindFirstChildWhichIsA("BasePart")
                if part and part:IsA("BasePart") then
                    local is_opened = entity:GetAttribute("Opened") == true
                    if show_opened or not is_opened then
                        local dist = (part.Position - origin).Magnitude
                        if dist <= max_dist then
                            table.insert(candidates, { entity = entity, part = part, dist = dist, opened = is_opened })
                        end
                    end
                end
            end
        end
    end

    check_container(workspace:FindFirstChild("Thrown"))
    check_container(workspace:FindFirstChild("Chests"))
    check_container(workspace)

    table.sort(candidates, function(a, b) return a.dist < b.dist end)

    local active_count = math.min(#candidates, MAX_CHESTS)

    for i = 1, MAX_CHESTS do
        local slot = self.pool[i]
        if i <= active_count then
            local item = candidates[i]
            local part, dist, opened = item.part, item.dist, item.opened
            local point, on_screen = camera:WorldToViewportPoint(part.Position)

            if on_screen and point.Z > 0 then
                -- Project corner box around chest size
                local size = part.Size
                local sy = size and size.Y or 2
                local p_top, v_top = camera:WorldToViewportPoint(part.Position + Vector3.new(0, sy / 2 + 0.5, 0))
                local p_bot, v_bot = camera:WorldToViewportPoint(part.Position - Vector3.new(0, sy / 2 + 0.5, 0))

                local h = math.clamp(math.abs(p_bot.Y - p_top.Y), 16, 120)
                local w = h * 1.3
                local cx, cy = point.X, point.Y

                local left, right = cx - w / 2, cx + w / 2
                local top, bottom = cy - h / 2, cy + h / 2
                local arm_w, arm_h = w * 0.28, h * 0.28

                -- 8 corner bracket segments
                local segments = {
                    { left + arm_w / 2, top, arm_w, 1 },
                    { left, top + arm_h / 2, 1, arm_h },
                    { right - arm_w / 2, top, arm_w, 1 },
                    { right, top + arm_h / 2, 1, arm_h },
                    { left + arm_w / 2, bottom, arm_w, 1 },
                    { left, bottom - arm_h / 2, 1, arm_h },
                    { right - arm_w / 2, bottom, arm_w, 1 },
                    { right, bottom - arm_h / 2, 1, arm_h },
                }

                for s_idx, seg in ipairs(segments) do
                    local line = slot.lines[s_idx]
                    line.Position = UDim2.fromOffset(seg[1], seg[2])
                    line.Size = UDim2.fromOffset(seg[3], seg[4])
                    line.BackgroundColor3 = opened and C.muted or C.neon
                    line.Visible = true
                end

                local label_text = string.format("CHEST  ·  %d studs", math.floor(dist))
                if opened then
                    label_text = label_text .. "  (OPEN)"
                end

                slot.label.Text = label_text
                slot.label.TextSize = text_size
                slot.label.TextColor3 = opened and C.muted or C.text
                slot.label.Position = UDim2.fromOffset(cx, top - 14)
                slot.label.Visible = true
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

    self.gui = create("ScreenGui", {
        Name = "ArteriaChestESP",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 95,
    }, players.LocalPlayer:WaitForChild("PlayerGui"))

    for i = 1, MAX_CHESTS do
        local slot = { lines = {} }

        for b = 1, 8 do
            local line = create("Frame", {
                Name = "Bracket",
                BorderSizePixel = 0,
                BackgroundColor3 = C.neon,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Visible = false,
            }, self.gui)
            table.insert(slot.lines, line)
        end

        slot.label = create("TextLabel", {
            Name = "ChestLabel",
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

        function slot:hide()
            for _, line in ipairs(self.lines) do line.Visible = false end
            self.label.Visible = false
        end

        table.insert(self.pool, slot)
    end

    self.conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
        local ok, err = pcall(self.render, self, dt)
        if not ok then
            aztup_toggles.chest_esp:SetValue(false)
            local runtime = getgenv().arteria
            if runtime then runtime.errors.chest_esp = tostring(err); runtime.refresh() end
            warn("[arteria] chest ESP: " .. tostring(err))
        end
    end)
end

function feature:disable()
    if self.conn then self.conn:Disconnect(); self.conn = nil end
    if self.gui then self.gui:Destroy(); self.gui = nil end
    self.pool = {}
end

return feature
