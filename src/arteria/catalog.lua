-- Explicit allowlist. Unlisted legacy modules are archived, not initialized.
local catalog = { sections = { "Movement", "Combat", "World", "Removals", "Visuals" }, entries = {} }
local function add(section, id, label, path, settings, kind, note)
    table.insert(catalog.entries, { section = section, id = id, label = label,
        path = path, settings = settings or {}, kind = kind or "module", note = note })
end
local function number(id, label, value, low, high)
    return { id = id, label = label, value = value, low = low, high = high }
end
local function choice(id, label, value, values)
    return { id = id, label = label, value = value, values = values }
end
add("Movement", "fly", "Fly", "@src/features/movement/fly", { number("fly_speed", "Speed", 60, 1, 250) })
add("Movement", "speed", "Walk speed", "@src/features/movement/speed", { number("walk_speed", "Speed", 32, 1, 250) })
add("Movement", "multiply_s", "Walkspeed multiplier", "@src/features/movement/multiply_s", {
    number("min_speed_mult", "Minimum boost %", 10, 1, 200), number("max_speed_mult", "Maximum boost %", 10, 1, 200),
    choice("multiplier_type", "Mode", "Walkspeed", { "Walkspeed", "CFrame (legit)", "CFrame (blatant)" }),
})
add("Movement", "infinite_jump", "Infinite jump", "@src/features/movement/infinite_jump", { number("jump_power", "Jump power", 50, 1, 150) })
add("Movement", "noclip", "Noclip", "@src/features/movement/noclip")
add("Movement", "dont_noclip_while_knocked", "Disable noclip while knocked", nil, nil, "flag", "Applies while noclip is enabled")
add("Combat", "auto_parry", "Auto parry", nil, nil, "parry")
add("Combat", "auto_fight", "Auto fight mobs", "@src/features/auto-fight/auto-fight", nil, nil, "WIP · limited mob support")
add("Combat", "m1_hold", "M1 hold", "@src/features/combat/m1_hold")
add("Combat", "auto_dustlunge", "Auto assassination / dustlunge", "@src/features/combat/auto_dustlunge", nil, nil, "Hold V to trigger")
add("Combat", "easy_roll_cancel", "Easy roll cancel", "@src/features/combat/easy_roll_cancel")
add("Combat", "auto_roll_cancel", "Auto roll cancel", "@src/features/automation/auto_roll_cancel")
add("Combat", "easy_feint", "Easy feint", "@src/features/combat/easy_feint", { choice("easy_feint_timing", "Timing", "Late", { "Late", "Early" }) })
add("Combat", "fast_swing", "Remove weapon endlag", "@src/features/combat/fast_swing")
add("Combat", "no_stun", "No stun", "@src/features/removals/no_stun")
add("Combat", "anim_speed_changer", "Animation speed changer", "@src/features/combat/anim_speed_changer", { number("arteria_anim_speed", "Speed multiplier", 1, 0.1, 2.1) }, "observer")
add("Combat", "auto_air_counter", "Auto air counter", "@src/features/combat/auto_air_counter", { number("air_counter_range", "Range", 60, 1, 100) })
add("Combat", "auto_reinforce", "Auto reinforce", "@src/features/combat/auto_reinforce")
add("Combat", "auto_golden_tongue", "Auto golden tongue", "@src/features/combat/auto_golden_tongue", { choice("auto_golden_tongue_mode", "Mode", "Blatant", { "Blatant", "Legit" }) }, nil, "Legit mode sends chat messages")
add("Combat", "auto_ardour", "Auto ardour", "@src/features/combat/auto_ardour")
add("Combat", "auto_flow_state", "Auto flow state", "@src/features/automation/auto_flow_state")
add("Combat", "auto_uppercut", "Auto uppercut", "@src/features/automation/auto_uppercut")
add("Combat", "auto_feint", "Auto feint", nil, { number("feint_chance", "Chance %", 100, 0, 100) }, "parry-flag", "Requires auto parry")
add("Combat", "basic_validation", "Anti-AP-breaker validation", nil, nil, "flag", "Applies to auto parry")
add("Combat", "view_hitboxes", "Hitbox visualization", nil, nil, "parry-flag", "Shows processed attack hitboxes")
add("Combat", "show_hitbox_simulation", "Hitbox simulation", "@src/features/auto-parry/hitbox_simulator", {
    choice("HS_HitboxType", "Shape", "Block", { "Block", "Ball", "Cylinder" }),
    number("HS_HitboxSizeX", "Width", 4, 0.1, 250), number("HS_HitboxSizeY", "Height", 4, 0.1, 250),
    number("HS_HitboxSizeZ", "Depth", 4, 0.1, 250), number("HS_ShiftOffset", "Offset", 0, -250, 30),
})
add("World", "ap_breaker", "AP breaker", "@src/features/exploits/ap_breaker", {
    choice("ap_breaker_type", "Mode", "Passive", { "Passive", "Aggressive", "Aggressive 2 (Blatant)", "Aggressive 3 (Blatant)" }),
    number("ap_breaker_intensity", "Intensity", 4, 1, 500),
}, "observer")
add("World", "bring_mobs", "Bring mobs", "@src/features/qol/bring_mobs", nil, nil, "Requires network ownership")
add("World", "void_mobs", "Void mobs", "@src/features/qol/void_mobs", nil, nil, "Requires network ownership")
add("World", "fake_void", "Fake void", "@src/features/qol/fake_void", nil, nil, "Depths only · uses no-kill-bricks dependency")
add("Removals", "no_fall", "No fall damage", "@src/features/removals/no_fall")
add("Removals", "anti_afk", "No AFK kick", "@src/features/removals/anti_afk")
add("Removals", "no_respawn_time", "No respawn timer / cooldown", "@src/features/misc/override_roblox_reset")
add("Removals", "no_castle_light_gate", "No Castle Light gate", "@src/features/removals/no_cl_gate", nil, nil, "Depths only")
add("Removals", "no_yun_shul_gate", "No Yun Shul gate", "@src/features/removals/no_yun_shul_gate", nil, nil, "Depths only")
add("Removals", "no_hive_gate", "No Hive gate", "@src/features/removals/no_hive_gate", nil, nil, "Eastern Luminant only")
add("Removals", "no_sanity_vfx", "No sanity VFX", "@src/features/removals/no_sanity_vfx")
add("Removals", "no_one_bit", "No One Bit", "@src/features/removals/no_one_bit")
add("Removals", "no_shadows", "No shadows", "@src/features/visuals/no_shadows")
add("Removals", "no_clouds", "No clouds", "@src/features/removals/no_clouds", nil, nil, "Legacy removal · rejoin to fully restore")
add("Removals", "no_blind", "No blindness", "@src/features/removals/no_blind")
add("Removals", "no_fire", "No fire", "@src/features/removals/no_fire")
add("Removals", "no_wind", "No wind", "@src/features/removals/no_wind")
add("Removals", "no_blur", "No blur", "@src/features/removals/no_blur")
add("Removals", "no_sea", "No sea", "@src/features/removals/no_sea", nil, nil, "Legacy removal · rejoin to fully restore")
add("Removals", "no_fog", "No fog", "@src/features/removals/no_fog")
add("Visuals", "skeleton_esp", "Skeleton ESP", "@src/arteria/skeleton_esp", {
    number("skeleton_esp_range", "Maximum distance", 2000, 25, 10000),
    number("skeleton_esp_thickness", "Line thickness", 1, 1, 4),
    choice("skeleton_esp_targets", "Players", "Everyone", { "Everyone", "Other teams" }),
}, "visual", "Bone-white R6 / R15 skeletons · players only")
add("Visuals", "player_esp", "Player ESP", "@src/features/visuals/player_esp", {
    number("arteria_player_range", "Maximum distance", 2000, 25, 10000),
    choice("arteria_player_boxes", "Frame style", "Corners", { "Corners", "Full box", "No box" }),
    choice("arteria_player_names", "Name labels", "Character", { "Character", "Display name", "Username", "Hidden" }),
    choice("arteria_player_health", "Health display", "Bar and value", { "Bar and value", "Bar", "Value", "Hidden" }),
    choice("arteria_player_distance", "Distance labels", "Shown", { "Shown", "Hidden" }),
    choice("arteria_player_highlight", "Character highlight", "Off", { "Off", "Outline", "Silhouette" }),
    choice("arteria_player_teams", "Target filter", "Everyone", { "Everyone", "Other teams" }),
    number("arteria_player_text", "Text size", 13, 10, 20),
}, "visual-init", "Corner frames · names · health · distance · optional highlights")
add("Visuals", "world_esp", "World ESP", "@src/features/visuals/base_esp", {
    choice("arteria_world_category", "Show objects", "All", { "All", "Mobs", "Chests", "Ingredients", "Artifacts" }),
    number("arteria_world_range", "Maximum distance", 2000, 25, 10000),
    number("arteria_world_limit", "Visible label budget", 64, 8, 200),
    number("arteria_world_text", "Text size", 13, 10, 20),
    number("arteria_world_rate", "Updates per second", 20, 5, 60),
}, "visual-init", "Legacy mob/chest/ingredient/artifact detection · Arteria labels")
return catalog
