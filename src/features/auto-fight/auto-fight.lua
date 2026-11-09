-- Deprecated and disabled: Heartbeat M1 packet flooding and midair teleportation causes immediate server-side auto-bans in Deepwoken.
local feature = Feature:new("auto_fight")
function feature:enable()
    warn("[arteria] auto_fight is permanently disabled: Heartbeat attack flooding triggers server bans.")
end
function feature:disable() end
return feature
