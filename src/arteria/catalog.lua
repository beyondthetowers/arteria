-- Explicit allowlist. Unlisted legacy modules are archived, not initialized.
local catalog = { sections = { "Movement", "Combat", "Visuals", "World", "Removals", "Automation" }, entries = {} }
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

-- Movement
add("Movement", "fly", "Fly", "@src/features/movement/fly", { number("fly_speed", "Speed", 60, 1, 250) })
add("Movement", "speed", "Walk speed", "@src/features/movement/speed", { number("walk_speed", "Speed", 32, 1, 250) })
add("Movement", "multiply_s", "Walkspeed multiplier", "@src/features/movement/multiply_s", {
    number("min_speed_mult", "Minimum boost %", 10, 1, 200), number("max_speed_mult", "Maximum boost %", 10, 1, 200),
    choice("multiplier_type", "Mode", "Walkspeed", { "Walkspeed", "CFrame (legit)", "CFrame (blatant)" }),
})
add("Movement", "infinite_jump", "Infinite jump", "@src/features/movement/infinite_jump", { number("jump_power", "Jump power", 50, 1, 150) })
add("Movement", "noclip", "Noclip", "@src/features/movement/noclip")
add("Movement", "dont_noclip_while_knocked", "Disable noclip while knocked", nil, nil, "flag", "Applies while noclip is enabled")

-- Combat
add("Combat", "auto_parry", "Auto parry", nil, {
    choice("auto_feint", "Auto Feint", "On", { "On", "Off" }),
    number("feint_chance", "Feint Chance %", 100, 0, 100),
    number("parry_chance", "Parry Chance %", 100, 0, 100),
    choice("basic_validation", "Anti-AP Validation", "On", { "On", "Off" }),
    choice("auto_parry_fallback", "Fallback Move", "Curse of the Unbidden", { "Curse of the Unbidden", "Block", "Vent", "Prediction" }),
    number("dont_process_players_over_studs", "Player Range", 500, 50, 5000),
    number("dont_process_mobs_over_studs", "Mob Range", 2000, 50, 5000),
    choice("view_hitboxes", "Hitbox Visuals", "Off", { "Off", "On" }),
}, "parry", "Automated parry defense · feints · validation · range filters")
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
add("Combat", "show_hitbox_simulation", "Hitbox simulation", "@src/features/auto-parry/hitbox_simulator", {
    choice("HS_HitboxType", "Shape", "Block", { "Block", "Ball", "Cylinder" }),
    number("HS_HitboxSizeX", "Width", 4, 0.1, 250), number("HS_HitboxSizeY", "Height", 4, 0.1, 250),
    number("HS_HitboxSizeZ", "Depth", 4, 0.1, 250), number("HS_ShiftOffset", "Offset", 0, -250, 30),
})

-- Visuals
add("Visuals", "player_esp", "Player ESP", "@src/arteria/player_esp", {
    choice("arteria_player_boxes", "Box Style", "Corners", { "Corners", "Full box", "No box" }),
    choice("arteria_player_names", "Name Display", "Character", { "Character", "Display name", "Username", "Hidden" }),
    choice("arteria_player_health", "Health Display", "Bar and value", { "Bar and value", "Bar", "Value", "Hidden" }),
    choice("arteria_player_distance", "Distance Display", "Shown", { "Shown", "Hidden" }),
    choice("arteria_player_highlight", "Highlight Mode", "Off", { "Off", "Outline", "Silhouette" }),
    choice("arteria_player_teams", "Target Filter", "Everyone", { "Everyone", "Other teams" }),
    number("arteria_player_range", "Maximum Range", 2000, 25, 10000),
    number("arteria_player_text", "Text Size", 13, 10, 20),
}, "visual", "Neon player boxes · health · names · distance · optional highlights")
add("Visuals", "skeleton_esp", "Player Skeleton ESP", "@src/arteria/skeleton_esp", {
    number("skeleton_esp_range", "Maximum Range", 2000, 25, 10000),
    number("skeleton_esp_thickness", "Bone Thickness", 1, 1, 4),
    choice("skeleton_esp_targets", "Players", "Everyone", { "Everyone", "Other teams" }),
}, "visual", "Bone-white R6 / R15 skeletons for players")
add("Visuals", "mob_esp", "Mob ESP", "@src/arteria/mob_esp", {
    choice("arteria_mob_skeleton", "Mob Skeleton", "Enabled", { "Enabled", "Disabled" }),
    choice("arteria_mob_health", "Health Display", "Bar and value", { "Bar and value", "Bar", "Value", "Hidden" }),
    choice("arteria_mob_distance", "Distance Display", "Shown", { "Shown", "Hidden" }),
    number("arteria_mob_range", "Maximum Range", 2000, 25, 10000),
    number("arteria_mob_thickness", "Bone Thickness", 1, 1, 4),
    number("arteria_mob_limit", "Max Visible Mobs", 40, 5, 100),
    number("arteria_mob_text", "Text Size", 13, 10, 20),
}, "visual", "Mob skeletons (humanoid & monsters) · health bar & value · distance")
add("Visuals", "npc_esp", "NPC ESP", "@src/arteria/npc_esp", {
    number("arteria_npc_range", "Maximum Range", 2000, 25, 10000),
    number("arteria_npc_text", "Text Size", 13, 10, 20),
}, "visual", "NPC markers and distance labels")
add("Visuals", "chest_esp", "Chest ESP", "@src/arteria/chest_esp", {
    choice("arteria_chest_opened", "Show Opened", "Hide", { "Hide", "Show" }),
    number("arteria_chest_range", "Maximum Range", 3000, 25, 10000),
    number("arteria_chest_text", "Text Size", 13, 10, 20),
}, "visual", "Chest corner boxes and distance labels")
add("Visuals", "mod_detector", "Mod Notification", "@src/arteria/mod_detector", {
    choice("arteria_mod_serverhop", "Auto Serverhop", "Off", { "Off", "On" }),
    choice("arteria_mod_sound", "Alert Sound", "On", { "On", "Off" }),
}, "visual", "Detects Deepwoken staff & moderators · screen-space neon alert banner")
add("Visuals", "full_bright", "Full Bright", "@src/features/visuals/full_bright", {
    number("fullbright_intensity", "Intensity %", 100, 0, 100),
}, nil, "Brightens ambient lighting")
add("Visuals", "free_cam", "Freecam", "@src/features/visuals/free_cam", {
    number("free_cam_speed", "Speed", 4, 1, 30),
    choice("safe_spot", "Safe Spot Mode", "Off", { "Off", "On" }),
}, nil, "Free-flying camera with safe spot option")
add("Visuals", "inf_zoom", "Infinite Zoom", "@src/features/visuals/inf_zoom", nil, nil, "Unlocks camera zoom distance")
add("Visuals", "zoom", "Zoom", "@src/features/visuals/zoom", {
    number("zoom_sens_mult", "Sensitivity Mult", 0.5, 0.1, 1),
    choice("zoom_apply_mouse_sens", "Apply Sensitivity", "On", { "On", "Off" }),
}, nil, "Field of view zoom with sensitivity scaling")
add("Visuals", "streamer_mode", "Streamer Mode", "@src/features/misc/streamer_mode", nil, nil, "Hides character name, slot, server info and user ID")

-- World
add("World", "ap_breaker", "AP breaker", "@src/features/exploits/ap_breaker", {
    choice("ap_breaker_type", "Mode", "Passive", { "Passive", "Aggressive", "Aggressive 2 (Blatant)", "Aggressive 3 (Blatant)" }),
    number("ap_breaker_intensity", "Intensity", 4, 1, 500),
}, "observer")
add("World", "fake_void", "Fake void", "@src/features/qol/fake_void", nil, nil, "Depths only · uses no-kill-bricks dependency")

-- Removals
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

-- Automation
add("Automation", "auto_builder", "Auto Builder", "@src/features/auto-builder/auto_builder", {
    choice("auto_builder_mode", "Target Mode", "Talents & Points", { "Talents & Points", "Talents only", "Points only" }),
    choice("auto_builder_shrined", "Shrined Status", "Off", { "Off", "On" }),
}, "builder", "Auto-allocates build stats & burns talents from builder link")
add("Automation", "auto_chime_requeue", "Auto Join / Chime Requeue", "@src/features/automation/auto_chime_requeue", nil, nil, "Automatically joins next Chime of Conflict match")
add("Automation", "auto_fish", "Auto Fish", "@src/features/automation/auto_fish", nil, nil, "Automates fishing rod casting & minigame")
add("Automation", "auto_loot", "Auto Loot", "@src/features/auto-loot/auto-loot", nil, nil, "Automatically loots nearby chests & drops")

return catalog
