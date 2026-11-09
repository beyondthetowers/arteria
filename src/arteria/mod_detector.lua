-- Arteria Mod Notification: Real-time Deepwoken staff and moderator detection.
-- Displays a prominent neon alert banner on screen and updates Arteria status.
local theme = require("@src/arteria/theme")
local C = theme.color
local feature = { id = "mod_detector", detected_mods = {}, active_alerts = {} }
local players = game:GetService("Players")
local raw_task = task or { spawn = function(f) coroutine.resume(coroutine.create(f)) end, wait = function() end }

local moderator_map = require("@src/features/misc/mod_detector/group_members")

local function create(class, props, parent)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end

function feature:show_banner(player_name, role)
    if not self.gui then return end

    local text_content = string.format("STAFF DETECTED  //  %s  (%s)", string.upper(player_name), string.upper(role))

    local banner = create("Frame", {
        Name = "ModAlert_" .. player_name,
        BackgroundColor3 = C.ink,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(480, 50),
        Position = UDim2.new(0.5, -240, 0, 18),
        ZIndex = 10,
    }, self.gui)

    local stroke = create("UIStroke", {
        Color = C.alert,
        Thickness = 1.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, banner)

    local outer_glow = create("UIStroke", {
        Color = C.alert_glow,
        Thickness = 5,
        Transparency = 0.85,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, banner)

    local icon = create("TextLabel", {
        Text = "[ ! ]",
        Font = theme.font.heading,
        TextSize = 18,
        TextColor3 = C.alert,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.fromOffset(40, 50),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 11,
    }, banner)

    local msg = create("TextLabel", {
        Text = text_content,
        Font = theme.font.mono,
        TextSize = 13,
        TextColor3 = C.text,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(60, 0),
        Size = UDim2.new(1, -110, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 11,
    }, banner)

    local dismiss = create("TextButton", {
        Text = "DISMISS",
        Font = theme.font.mono,
        TextSize = 10,
        TextColor3 = C.muted,
        BackgroundColor3 = C.surface,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -80, 0.5, -13),
        Size = UDim2.fromOffset(70, 26),
        ZIndex = 12,
    }, banner)

    dismiss.Activated:Connect(function()
        banner:Destroy()
    end)

    -- Play alert sound
    if aztup_options.arteria_mod_sound.Value == "On" then
        pcall(function()
            local sound = Instance.new("Sound", game:GetService("CoreGui"))
            sound.SoundId = "rbxassetid://9069609200"
            sound.Volume = 1.5
            sound:Play()
            game:GetService("Debris"):AddItem(sound, 3)
        end)
    end
end

function feature:check_player(player)
    if player == players.LocalPlayer then return end
    local uid = tostring(player.UserId)
    local role = moderator_map[uid]

    if not role then
        local success, in_group = pcall(function()
            return player:GetRankInGroup(5212858) > 0
        end)
        if success and in_group then
            role = "Staff Group Member"
        end
    end

    if role and not self.detected_mods[player] then
        self.detected_mods[player] = role
        self:show_banner(player.Name, role)

        local runtime = getgenv().arteria
        if runtime then
            runtime.errors.mod_detector = string.format("STAFF: %s (%s)", player.Name, role)
            if runtime.refresh then runtime.refresh() end
        end

        warn(string.format("[arteria] MODERATOR DETECTED: %s (%s)", player.Name, role))

        -- Optional auto-serverhop
        if aztup_options.arteria_mod_serverhop.Value == "On" then
            pcall(function()
                local slot = players.LocalPlayer:GetAttribute("DataSlot")
                server_utility:hop(slot, "any", true)
            end)
        end
    end
end

function feature:enable()
    self:disable()
    self.detected_mods = {}

    self.gui = create("ScreenGui", {
        Name = "ArteriaModAlerts",
        ResetOnSpawn = false,
        DisplayOrder = 999,
    }, players.LocalPlayer:WaitForChild("PlayerGui"))

    self.conn_added = players.PlayerAdded:Connect(function(player)
        raw_task.wait(1)
        self:check_player(player)
    end)

    self.conn_removed = players.PlayerRemoving:Connect(function(player)
        if self.detected_mods[player] then
            self.detected_mods[player] = nil
        end
    end)

    -- Scan current players in server
    raw_task.spawn(function()
        for _, player in ipairs(players:GetPlayers()) do
            self:check_player(player)
        end
    end)
end

function feature:disable()
    if self.conn_added then self.conn_added:Disconnect(); self.conn_added = nil end
    if self.conn_removed then self.conn_removed:Disconnect(); self.conn_removed = nil end
    if self.gui then self.gui:Destroy(); self.gui = nil end
    self.detected_mods = {}
end

return feature
