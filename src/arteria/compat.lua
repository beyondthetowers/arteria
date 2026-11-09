-- Only the dependency contracts used by the allowlisted legacy modules.
local Compat = {}
local function set(values)
    local result = {}
    for _, value in ipairs(values) do result[value] = true end
    return result
end
function Compat.configure(runtime)
    local env = getgenv()
    env.is_depths = game.PlaceId == 5735553160
    env.is_eastern = game.PlaceId == 6473861193
    env.is_etrean = game.PlaceId == 6032399813
    env.is_chime = game.PlaceId == 6832944305
    env.debug_print = function(...) if runtime.flags.debug then print("[arteria]", ...) end end
    local defaults = {
        dont_process_players_over_studs = 500, dont_process_mobs_over_studs = 2000,
        task_concurrency = 20, anti_ap_breaker_max_speed = 5, anti_ap_breaker_minimum_wt = 10,
        anti_ap_breaker_length_ms = 50, parry_to_fallback_chance = 0, bluff_feint_chance = 0,
        bi_punishable_time = 650, extra_bi_punishable_time = 0, max_boxes = 5, hb_trans = 100,
        info_logger_range = 1, feint_chance = 100,
    }
    for _, prefix in ipairs({ "pve_", "pvp_" }) do
        defaults[prefix .. "parry_chance"] = 100
        defaults[prefix .. "max_roll_cancel_delay"] = 150
        defaults[prefix .. "min_roll_cancel_delay"] = 70
        defaults[prefix .. "roll_cancel_chance"] = 90
    end
    for _, suffix in ipairs({ "undefined", "spells", "critical", "m1" }) do defaults["parry_to_dodge_chance_" .. suffix] = 0 end
    for key, value in pairs(defaults) do runtime.flags[key] = value end
    local options = {
        allowed_targets = set({ "Unknown", "PVE", "PVP", "All" }),
        filters = set({ "Dont Parry If Typing", "Dont Parry If Knocked" }),
        fallbacks = set({ "Curse of the Unbidden" }),
        validation_filters = set({ "WT <= X (WT = WeightTarget)", "Core Priority", "Idle Priority", "Priority Hiding", "S >= X (S = Speed)", "Fadetime" }),
        validation_log_filters = {}, blocked_auto_feint_moves = {},
        auto_feint_own_tags = set({ "M1", "Spell" }), blocked_safe_input_moves = {},
        blocked_safe_input_user_moves = {}, allowed_bi_targets = {}, blocked_timings = {},
        bi_punishable_type = "Static", m1_timing_hitbox_type = "Block",
        aggressive_3_break_on = set({ "Spells", "M1s" }),
        anim_speed_changer_types = set({ "Criticals", "Untagged", "Spells", "Bells", "M1s" }),
        no_stun_items = set({ "LightningStun", "PreventAction", "OffhandAttack", "UsingCritical", "MobileAction", "MediumAttack", "CarryObject", "PreventRoll", "LightAttack", "HeavyAttack", "InDialogue", "UsingSpell", "NoParkour", "NoJumpAlt", "Blocking", "NoAttack", "Carried", "Falling", "Chilled", "Pinned", "Action", "Dodged", "NoJump", "NoRoll", "NoMove", "Stun" }),
        ally_settings = {}, ally_guilds_input = "", ally_players_input = "",
    }
    for key, value in pairs(options) do env.aztup_options[key] = { Value = value } end
    Compat.animation_speed(runtime, 1)
end

function Compat.animation_speed(runtime, value)
    for _, id in ipairs({ "anim_critical_speed", "anim_untagged_speed", "anim_spell_speed", "anim_bell_speed", "anim_m1_speed" }) do
        runtime.flags[id] = { min = value, max = value }
    end
end

function Compat.restore_point(id)
    local lighting = game:GetService("Lighting")
    local env = getgenv()
    if id == "no_shadows" then
        local value = lighting.GlobalShadows
        return function() lighting.GlobalShadows = value end
    elseif id == "no_fog" then
        local distance = lighting.FogEnd
        local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
        local density = atmosphere and atmosphere.Density
        return function()
            lighting.FogEnd = distance
            if atmosphere and atmosphere.Parent then atmosphere.Density = density end
        end
    elseif id == "no_blur" then
        local values = {}
        for _, object in ipairs(lighting:GetChildren()) do
            if object:IsA("BlurEffect") then values[object] = object.Size end
        end
        return function()
            for object, value in pairs(values) do if object.Parent then object.Size = value end end
        end
    elseif id == "no_blind" or id == "no_one_bit" then
        local passives = env.EffectReplicator.Passives
        if not passives then return end
        local keys = id == "no_blind" and { "Blind", "Blinded" } or { "OneBit" }
        local values = {}
        for _, key in ipairs(keys) do values[key] = passives[key] end
        return function() for _, key in ipairs(keys) do passives[key] = values[key] end end
    elseif id == "no_sanity_vfx" then
        local gui = env.local_player.instance:FindFirstChild("PlayerGui")
        local overlay = gui and gui:FindFirstChild("OverlayGui")
        local enabled = overlay and overlay.Enabled
        return function() if overlay and overlay.Parent then overlay.Enabled = enabled end end
    elseif id == "void_mobs" then
        local value = workspace.FallenPartsDestroyHeight
        local attribute = workspace:GetAttribute("OriginalFPDH")
        return function()
            workspace.FallenPartsDestroyHeight = value
            workspace:SetAttribute("OriginalFPDH", attribute)
        end
    end
end

function Compat.prepare(runtime)
    if runtime.prepared then return end
    local env = getgenv()
    env.Latency = require("@src/utility/latency")
    env.scheduler = require("@src/utility/scheduler")
    env.general = require("@src/utility/deepwoken/general_utilitys")
    env.fflags = require("@src/utility/fflags")
    env.InstanceWatcher = require("@src/utility/instancewatcher")
    local data = env.local_player
    data.character_added = require("@src/utility/signal").new()
    runtime.maid:give_task(function() data.character_added:destroy() end)
    data.tracker = require("@src/utility/deepwoken/action_tracker").new(data)
    runtime.maid:give_task(data.tracker.on_mantra_request)
    env.chance_store = require("@src/features/auto-parry/data/chance_store")
    env.TargetFilter = require("@src/features/auto-parry/util/target-filter")
    require("@src/features/auto-parry/block-input-manager")

    -- Stable hook handles: the old handler used mutable array indices, so
    -- disabling one feature could leave another feature's hook registered.
    local hooks = {}
    local handler = {}
    function handler:hook(kind, callback)
        local token = { kind = kind, callback = callback, owner = runtime.enabling, threads = {} }
        hooks[token] = true
        function token:remove()
            hooks[self] = nil
            for thread in pairs(self.threads) do pcall(task.cancel, thread) end
            table.clear(self.threads)
        end
        return token
    end
    env.EffectReplicatorHandler = handler
    runtime.maid:give_task(function()
        for token in pairs(hooks) do token:remove() end
    end)
    for _, pair in ipairs({ { "added", env.EffectReplicator.EffectAdded }, { "removed", env.EffectReplicator.EffectRemoved } }) do
        runtime.maid:give_task(pair[2]:Connect(function(effect)
            if not runtime.alive or not data.root_part or not data.humanoid then return end
            for token in pairs(hooks) do
                if token.kind == pair[1] and (not token.owner or runtime.flags[token.owner]) then
                    local thread
                    thread = task.defer(function()
                        if not runtime.alive or not hooks[token] then return end
                        local ok, err = pcall(token.callback, effect)
                        if not ok then
                            if token.owner then runtime:set(token.owner, false) end
                            warn("[arteria] effect hook: " .. tostring(err))
                        end
                        token.threads[thread] = nil
                    end)
                    token.threads[thread] = true
                end
            end
        end))
    end
    runtime.prepared = true
end

function Compat.observers(runtime)
    Compat.prepare(runtime)
    if runtime.observers_loaded then return end
    -- These modules install observers; execution remains flag-driven.
    require("@src/features/auto-parry/auto-parry")
    require("@src/features/auto-parry/handlers/animator-handler")
    runtime.observers_loaded = true
end
return Compat
