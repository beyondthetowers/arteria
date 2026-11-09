-- Deprecated and disabled: setting FallenPartsDestroyHeight to NaN and throwing mob parts to -12500 causes a client engine deadlock (0 FPS freeze) and server-side exploit bans.
local feature = Feature:new("void_mobs")
function feature:enable()
    warn("[arteria] void_mobs is permanently disabled: network ownership voiding freezes client physics and triggers server bans.")
end
function feature:disable() end
return feature
