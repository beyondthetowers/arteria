// Read-only source checks plus isolated default/legacy bundle builds.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const zlib = require("node:zlib");
const { execFileSync } = require("node:child_process");
const root = path.resolve(__dirname, "..");
const tempRoot = process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, "Temp", "opencode") : os.tmpdir();
const temp = fs.mkdtempSync(path.join(tempRoot, "arteria-test-"));
const read = (name) => fs.readFileSync(path.join(root, name), "utf8");
try {
    const init = read("src/arteria/init.lua");
    const catalog = read("src/arteria/catalog.lua");
    const ids = Array.from(catalog.matchAll(/^add\("[^"]+", "([^"]+)"/gm), (m) => m[1]);
    assert.equal(new Set(ids).size, ids.length, "duplicate allowlist entry");
    const expected = ["fly","speed","multiply_s","infinite_jump","noclip","dont_noclip_while_knocked","auto_parry","m1_hold","auto_dustlunge","easy_roll_cancel","auto_roll_cancel","easy_feint","fast_swing","no_stun","anim_speed_changer","auto_air_counter","auto_reinforce","auto_golden_tongue","auto_ardour","auto_flow_state","auto_uppercut","show_hitbox_simulation","player_esp","skeleton_esp","mob_esp","npc_esp","chest_esp","mod_detector","full_bright","free_cam","inf_zoom","zoom","streamer_mode","ap_breaker","fake_void","tp_eastern","tp_depths","tp_etrean","tp_trial","tp_voidheart","tp_floor","no_fall","anti_afk","no_respawn_time","no_castle_light_gate","no_yun_shul_gate","no_hive_gate","no_sanity_vfx","no_one_bit","no_shadows","no_clouds","no_blind","no_fire","no_wind","no_blur","no_sea","no_fog","auto_builder","auto_chime_requeue","auto_fish","auto_loot"];
    assert.equal(ids.length, expected.length, "catalog count mismatch");
    assert.deepEqual(ids, expected, "catalog must match expected controls exactly");
    for (const id of ["fly", "speed", "infinite_jump"]) {
        assert(catalog.includes(`@src/features/movement/${id}"`));
    }
    for (const excluded of ["@src/features/loader", "@src/ui/ui", "@src/automation/loader", "@src/utility/frutiger/theme"]) {
        assert(!init.includes(excluded), `unexpected legacy initialization: ${excluded}`);
    }
    assert(init.includes('require("@src/features/hooking")'));
    assert(init.includes("feature.current_connection:Disconnect()"));
    assert(init.includes("CharacterRemoving:Connect"));
    assert(init.includes('local module = require(entry.path)'), "features must load lazily");
    assert(init.includes('needs_observers and not self.observers_loaded'), "failed observer setup must be retried");
    assert(init.includes('typeof(feature.conn) ~= "RBXScriptSignal"'), "self-managed connections must not be connected twice");
    const ui = read("src/arteria/ui.lua");
    assert(ui.includes("LOADED · UNVERIFIED"));
    assert(ui.includes("GetFocusedTextBox()"));
    assert(ui.includes("math.clamp(math.floor(value * 100 + 0.5) / 100, option.low, option.high)"));
    assert(ui.includes("WindowFocusReleased"));
    for (const entry of ["src/arteria/init", "src/init"]) {
        const out = path.join(temp, entry === "src/init" ? "legacy.lua" : "arteria.lua");
        const args = ["tools/bundle.js", "--no-assets", `--out=${out}`];
        if (entry === "src/init") args.push(`--entry=${entry}`);
        const log = execFileSync(process.execPath, args, { cwd: root, encoding: "utf8" });
        assert(log.includes("all references resolved"), log);
        const bundle = fs.readFileSync(out, "utf8");
        assert(bundle.includes(`end, "@${entry}");`));
        assert(bundle.includes('__modules["src/ui/ui"]'), "legacy source must stay bundled");
        for (const name of ["base.json", "extra_data.json"]) {
            const key = `@assets/${name}`;
            const literal = `[${JSON.stringify(key)}] = "`;
            const start = bundle.indexOf(literal);
            assert(start !== -1, `minimal build omitted required timing asset: ${name}`);
            const payload = bundle.slice(start + literal.length).split('"')[0];
            const decoded = zlib.zstdDecompressSync(Buffer.from(payload, "base64"));
            assert.deepEqual(decoded, fs.readFileSync(path.join(root, "assets", name)), `asset round-trip: ${name}`);
            if (name.endsWith(".json")) JSON.parse(decoded.toString("utf8"));
        }
        assert(!bundle.includes('["@assets/lexend.ttf"] = "'), "minimal build should omit optional media");
        if (entry === "src/arteria/init") {
            const match = bundle.match(/getgenv\(\)\.Arteria_bootstrap_b64 = "([^"]+)"/);
            assert(match, "missing local echo continuation bootstrap");
            const bootstrap = zlib.zstdDecompressSync(Buffer.from(match[1], "base64")).toString();
            assert(bootstrap.includes('end, "@src/arteria/init");'), "continuation must run Arteria, not the legacy client");
            assert(!bootstrap.includes('getgenv().Arteria_bootstrap_b64 = "'), "continuation must not embed itself recursively");
        }
    }
    assert.throws(() => execFileSync(process.execPath,
        ["tools/bundle.js", "--entry=src/missing", "--no-assets", `--out=${path.join(temp, "invalid.lua")}`],
        { cwd: root, stdio: "pipe" }));
    assert(!fs.existsSync(path.join(temp, "invalid.lua")));
    console.log("arteria: source contracts, default/legacy builds, reference resolution and invalid entry checks passed");
} finally {
    for (const name of fs.readdirSync(temp)) fs.unlinkSync(path.join(temp, name));
    fs.rmdirSync(temp);
}
