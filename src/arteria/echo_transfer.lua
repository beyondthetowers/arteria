-- A bounded menu continuation using the same StartMenu/Servers interfaces as
-- the legacy hopper, without its missing IP-data file or endless click loop.
local Transfer = {}
function Transfer.source(slot, wipe, token, previous_server)
    local source = [[
if not game:IsLoaded() then game.Loaded:Wait() end
if game.PlaceId ~= 4111023553 then return end
local slot, wipe, token, previous = __SLOT__, __WIPE__, __TOKEN__, __PREVIOUS__
local http = game:GetService("HttpService")
local function active()
    local ok, value = pcall(function() return http:JSONDecode(readfile("Arteria/echo-session.json")) end)
    return ok and type(value) == "table" and value.enabled and value.token == token
end
if not active() then return end
local connections = {}
local ok, err = pcall(function()
    local rs = game:GetService("ReplicatedStorage")
    local player = game:GetService("Players").LocalPlayer
    local requests = assert(rs:WaitForChild("Requests", 30), "Requests unavailable")
    local menu = assert(requests:WaitForChild("StartMenu", 30), "StartMenu unavailable")
    local show = assert(requests:WaitForChild("ShowServers", 15), "Server list unavailable")
    local pick_slot = assert(menu:WaitForChild("PickSlot", 15), "Slot selection unavailable")
    local pick_server = assert(menu:WaitForChild("PickServer", 15), "Server selection unavailable")
    local servers = assert(rs:WaitForChild("Servers", 15), "Servers unavailable")
    local joining
    table.insert(connections, show.OnClientEvent:Connect(function(luminant)
        if not active() or joining then return end
        local group = servers:FindFirstChild(tostring(luminant))
        if not group then return end
        local candidates = {}
        for _, server in ipairs(group:GetChildren()) do
            local count, capacity = server:FindFirstChild("NumPlayers"), server:FindFirstChild("MaxPlayers")
            local id = server:GetAttribute("JobId")
            if count and capacity and id and id ~= previous and count.Value < capacity.Value then
                table.insert(candidates, { id = id, count = count.Value })
            end
        end
        table.sort(candidates, function(a,b) return a.count < b.count end)
        local choice = candidates[1]
        if choice and active() then joining = choice.id; pick_server:FireServer(choice.id) end
    end))
    table.insert(connections, game:GetService("TeleportService").TeleportInitFailed:Connect(function()
        joining = nil
    end))
    local deadline = os.clock() + 120
    while active() and (not workspace:GetAttribute("ServerReady") or not player:GetAttribute("GameLoaded")) do
        assert(os.clock() < deadline, "Menu initialization timed out")
        task.wait(0.25)
    end
    if not active() then return end
    if wipe then
        local remote = assert(requests:WaitForChild("WipeSlot", 15), "WipeSlot unavailable")
        if not active() then return end
        remote:InvokeServer(slot)
    end
    local deadline = os.clock() + 90
    while active() and os.clock() < deadline do
        if not joining then pick_slot:FireServer(slot, { PrivateTest = false }) end
        task.wait(5)
    end
    if active() then error("Echo transfer timed out; check the selected slot and available servers") end
end)
for _, connection in ipairs(connections) do connection:Disconnect() end
if not ok then
    warn("[arteria] echo transfer: " .. tostring(err))
    local loaded, state = pcall(function() return http:JSONDecode(readfile("Arteria/echo-session.json")) end)
    if loaded and state.token == token then
        state.enabled, state.transfer_error = false, tostring(err)
        writefile("Arteria/echo-session.json", http:JSONEncode(state))
    end
end
]]
    local values = { __SLOT__ = string.format("%q", slot), __WIPE__ = tostring(wipe == true),
        __TOKEN__ = string.format("%q", token), __PREVIOUS__ = string.format("%q", previous_server or "") }
    return (source:gsub("__[A-Z]+__", function(key) return assert(values[key], key) end))
end
return Transfer
