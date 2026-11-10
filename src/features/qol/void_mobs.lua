-- Void mobs, rebuilt. The original had four lethal defects:
--
--   1. workspace.FallenPartsDestroyHeight = 0/0 (NaN). NaN in the physics
--      broadphase deadlocked the render thread -> 0 FPS freeze, both bans
--      happened while the client was in this frozen/anomalous state.
--   2. sethiddenproperty(player, "SimulationRadius", 3000). Forcing ownership
--      of distant server NPCs is a one-line server-side detection.
--   3. Velocity = (0, -12500, 0) on multi-part Motor6D rigs -> stretched
--      constraints across the whole map, impossible position deltas.
--   4. Unbounded loop over every mob on every Heartbeat.
--
-- This version keeps none of them. It only ever touches BaseParts Roblox has
-- ALREADY assigned to this client through normal proximity ownership, moves
-- them with position-only CFrame writes (zero velocity), and is rate-limited.
local feature = {};

local peer;
do
    local probe = Instance.new("Part");
    probe.Parent = workspace;
    local ok, id = pcall(gethiddenproperty, probe, "NetworkOwnerV3");
    probe:Destroy();
    if ok and id ~= nil then
        peer = id;
    end;
end

function feature:owner(part)
    if not peer then return false end
    local ok, id = pcall(gethiddenproperty, part, "NetworkOwnerV3");
    return ok and id == peer;
end

sf_isnetworkowner = function(part)
    return feature:owner(part);
end

-- Far below any map content, but a finite sane number (no NaN, no -12500).
local VOID_DEPTH = -2000;
-- At most this many mobs per Heartbeat tick, and per-mob cooldown.
local TICK_BUDGET = 2;
local COOLDOWN = 2;
local mob_last_void = setmetatable({}, { __mode = "k" });

local function void_mob(mob)
    local now = tick();
    if mob_last_void[mob] and now - mob_last_void[mob] < COOLDOWN then
        return false;
    end

    local humanoid = mob:FindFirstChildOfClass("Humanoid");
    local root = mob:FindFirstChild("HumanoidRootPart");
    if not humanoid or humanoid.Health <= 0 or not root or not feature:owner(root) then
        return false;
    end

    for _, part in mob:GetChildren() do
        if part:IsA("BasePart") and feature:owner(part) then
            part.AssemblyLinearVelocity = Vector3.zero;
            part.CFrame = CFrame.new(part.Position.X, VOID_DEPTH, part.Position.Z);
        end
    end

    mob_last_void[mob] = now;
    return true;
end

function feature:run()
    local live = workspace:FindFirstChild("Live");
    if not live then return end

    local processed = 0;
    for _, mob in live:GetChildren() do
        if processed >= TICK_BUDGET then break end
        if mob:IsA("Model") and mob.Name:sub(1, 1) == "." and mob.Name:match("watcher") == nil then
            if void_mob(mob) then
                processed += 1;
            end
        end
    end
end

local feat = Feature:new("void_mobs", game:GetService("RunService").Heartbeat, function()
    local ok, err = pcall(feature.run, feature);
    if not ok then
        warn("[arteria] void_mobs: " .. tostring(err));
    end
end);
return feat
