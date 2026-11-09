-- Arteria NPC ESP: Neon text labels and distance markers.
-- Bounded, pre-allocated text pool. Zero per-frame allocations.
local theme = require("@src/arteria/theme")
local C = theme.color
local feature = { id = "npc_esp", pool = {} }
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
    if name == "" then name = "NPC" end
    return name
end

local MAX_NPCS = 50

function feature:render(dt)
    local camera = workspace.CurrentCamera
    if not camera or camera.ViewportSize.X < 16 or camera.ViewportSize.Y < 48 then return end

    local own_character = players.LocalPlayer.Character
    local own_root = own_character and own_character:FindFirstChild("HumanoidRootPart")
    local origin = own_root and own_root.Position or camera.CFrame.Position

    local max_dist = aztup.flags.arteria_npc_range or 2000
    local text_size = aztup.flags.arteria_npc_text or 13

    local npcs_folder = workspace:FindFirstChild("NPCs")
    if not npcs_folder then return end

    local candidates = {}
    for _, npc in ipairs(npcs_folder:GetChildren()) do
        local root = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso") or npc:FindFirstChildWhichIsA("BasePart")
        if root and root:IsA("BasePart") then
            local dist = (root.Position - origin).Magnitude
            if dist <= max_dist then
                table.insert(candidates, { npc = npc, root = root, dist = dist })
            end
        end
    end

    table.sort(candidates, function(a, b) return a.dist < b.dist end)

    local active_count = math.min(#candidates, MAX_NPCS)

    for i = 1, MAX_NPCS do
        local slot = self.pool[i]
        if i <= active_count then
            local item = candidates[i]
            local npc, root, dist = item.npc, item.root, item.dist
            local point, on_screen = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2, 0))

            if on_screen and point.Z > 0 then
                local name = clean_name(npc:GetAttribute("NPC_rich_name") or npc:GetAttribute("Name") or npc.Name)
                slot.label.Text = string.format("[NPC] %s  ·  %d studs", name, math.floor(dist))
                slot.label.TextSize = text_size
                slot.label.Position = UDim2.fromOffset(point.X, point.Y - 10)
                slot.label.Visible = true

                slot.dot.Position = UDim2.fromOffset(point.X, point.Y)
                slot.dot.Visible = true
            else
                slot.label.Visible = false
                slot.dot.Visible = false
            end
        else
            slot.label.Visible = false
            slot.dot.Visible = false
        end
    end
end

function feature:enable()
    self:disable()
    self.pool = {}

    self.gui = create("ScreenGui", {
        Name = "ArteriaNPCESP",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 94,
    }, players.LocalPlayer:WaitForChild("PlayerGui"))

    for i = 1, MAX_NPCS do
        local slot = {}

        slot.dot = create("Frame", {
            Name = "Dot",
            BorderSizePixel = 0,
            BackgroundColor3 = C.neon,
            Size = UDim2.fromOffset(3, 3),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Visible = false,
        }, self.gui)

        slot.label = create("TextLabel", {
            Name = "NPCLabel",
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

        table.insert(self.pool, slot)
    end

    self.conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
        local ok, err = pcall(self.render, self, dt)
        if not ok then
            aztup_toggles.npc_esp:SetValue(false)
            local runtime = getgenv().arteria
            if runtime then runtime.errors.npc_esp = tostring(err); runtime.refresh() end
            warn("[arteria] NPC ESP: " .. tostring(err))
        end
    end)
end

function feature:disable()
    if self.conn then self.conn:Disconnect(); self.conn = nil end
    if self.gui then self.gui:Destroy(); self.gui = nil end
    self.pool = {}
end

return feature
