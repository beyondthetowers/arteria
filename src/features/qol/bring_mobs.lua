-- Deprecated and disabled: setting MaxSimulationRadius to 3000 to force network ownership of mobs triggers server bans.
local feature = Feature:new("bring_mobs")
function feature:enable()
    warn("[arteria] bring_mobs is permanently disabled: network ownership theft triggers server bans.")
end
function feature:disable() end
return feature
