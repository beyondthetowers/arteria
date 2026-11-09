// tools/bundle.js
//
// Flattens the module tree into one self-contained Lua chunk that
// can be run through loadstring / game:HttpGet.
//
// What it does:
//   - walks every .lua and .json under src/
//   - emits each as a factory in a __modules table
//   - installs a require() shim that resolves "@src/..." out of that table and
//     delegates everything else to the executor's real require
//   - replaces list_modules() with static lists computed from the tree
//   - pre-encodes assets/ as base64(zstd(bytes)) so inline_asset_b96 works with
//     no disk access
//   - runs @src/arteria/init by default; --entry=src/init selects legacy
//
// Usage:
//   node tools/bundle.js                 -> dist/arteria.lua
//   node tools/bundle.js --no-assets     -> skip asset embedding (much smaller)
//   node tools/bundle.js --out=path.lua

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

// Repo root, derived from this file's location so the tree builds anywhere.
const ROOT = path.resolve(__dirname, "..");
const SRC = path.join(ROOT, "src");
const ASSETS = path.join(ROOT, "assets");

const argv = process.argv.slice(2);
const EMBED_ASSETS = !argv.includes("--no-assets");
const ENTRY = (argv.find((a) => a.startsWith("--entry=")) || "--entry=src/arteria/init").slice(8).replace(/^@/, "");
const OUT = (() => {
    const flag = argv.find((a) => a.startsWith("--out="));
    return flag ? flag.slice(6) : path.join(ROOT, "dist", "arteria.lua");
})();

// ── helpers ────────────────────────────────────────────────────────────────

// Refuse to emit a bundle containing a JS comment in a Lua file. A parse failure
// costs the entire build AND reports nothing, because every consumer wraps
// loadstring in pcall -- which is how one bad comment survived four verification
// runs unnoticed. See tools/lua-guard.js.
require("./lua-guard.js").check(ROOT);

function walk(dir, out = []) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            walk(full, out);
        } else {
            out.push(full);
        }
    }
    return out;
}

function rel(p) {
    return path.relative(ROOT, p).split(path.sep).join("/");
}

function luaLongString(text) {
    // Pick a bracket level that cannot appear inside the payload.
    let level = 0;
    for (;;) {
        const close = "]" + "=".repeat(level) + "]";
        if (!text.includes(close) && !text.includes("[" + "=".repeat(level) + "[")) {
            break;
        }
        level += 1;
        if (level > 10) throw new Error("could not find a safe long-string level");
    }
    const eq = "=".repeat(level);
    return "[" + eq + "[" + text + "]" + eq + "]";
}

function luaString(text) {
    return JSON.stringify(text);
}

// ── module collection ──────────────────────────────────────────────────────

const allFiles = walk(SRC).filter((f) => f.endsWith(".lua") || f.endsWith(".json"));

const modules = [];        // { id, kind, file }
const moduleIds = new Set();

for (const file of allFiles) {
    const id = rel(file).replace(/\.(lua|json)$/, "");
    const kind = file.endsWith(".json") ? "json" : "lua";
    if (moduleIds.has(id)) continue;
    moduleIds.add(id);
    modules.push({ id, kind, file });
}

modules.sort((a, b) => a.id.localeCompare(b.id));
if (!moduleIds.has(ENTRY)) throw new Error(`Unknown entry module: ${ENTRY}`);

// ── globs ──────────────────────────────────────────────────────────────────

const globPatterns = ["automation/persistent_tasks/*", "features/auto-parry/data/effects/*",
                      "features/auto-parry/fallbacks/objects/*", "ui/tabs/*"];

const globTables = globPatterns.map((pattern) => {
    const dir = pattern.slice(0, pattern.lastIndexOf("/"));
    const prefix = "src/" + dir + "/";
    const matches = modules
        .filter((m) => m.id.startsWith(prefix) && !m.id.slice(prefix.length).includes("/"))
        .map((m) => "@" + m.id);
    return { pattern, matches };
});

// ── assets ─────────────────────────────────────────────────────────────────

const assets = [];
// --no-assets skips optional media, never data required by selected features.
const REQUIRED_ASSETS = new Set(["@assets/base.json", "@assets/extra_data.json"]);
if (fs.existsSync(ASSETS)) {
    for (const file of walk(ASSETS)) {
        const key = "@assets/" + rel(file).slice("assets/".length);
        if (!EMBED_ASSETS && !REQUIRED_ASSETS.has(key)) continue;
        const raw = fs.readFileSync(file);
        const compressed = zlib.zstdCompressSync(raw);
        assets.push({ key, b64: compressed.toString("base64") });
    }
    assets.sort((a, b) => a.key.localeCompare(b.key));
}
for (const key of REQUIRED_ASSETS) {
    if (!assets.some((asset) => asset.key === key)) throw new Error(`Required runtime asset missing: ${key}`);
}

// ── emit ───────────────────────────────────────────────────────────────────

const chunks = [];

chunks.push(`--[[
    Arteria — bundled build
    generated ${new Date().toISOString()}
    modules: ${modules.length}
    assets:  ${assets.length}
]]`);
chunks.push("");

// module factories
chunks.push("local __modules = {};");
chunks.push("local __cache = {};");
chunks.push("local __loaded = {};");
chunks.push("local __loading = {};");
chunks.push("local __real_require = require;");
chunks.push("");

for (const mod of modules) {
    const source = fs.readFileSync(mod.file, "utf8");
    chunks.push(`__modules[${luaString(mod.id)}] = function()`);
    if (mod.kind === "json") {
        chunks.push(`    return game:GetService("HttpService"):JSONDecode(${luaLongString(source)});`);
    } else {
        chunks.push(source.endsWith("\n") ? source : source + "\n");
    }
    chunks.push("end;");
    chunks.push("");
}

// module resolver
chunks.push(`local function __resolve(target)
    local key = target:gsub("^@", "");
    if __modules[key] then return key end;
    if __modules[key .. ".lua"] then return key .. ".lua" end;
    if __modules[key .. ".json"] then return key .. ".json" end;

    -- Tolerate a module id that already carries its extension.
    local stripped = key:gsub("%.lua$", ""):gsub("%.json$", "");
    if stripped ~= key and __modules[stripped] then return stripped end;

    return nil;
end;

local function __unpack_cached(key)
    local packed = __cache[key];
    if not packed then return end;
    return table.unpack(packed, 1, packed.n);
end;

local function __require(target)
    if type(target) == "string" then
        local key = __resolve(target);
        if key then
            if __loaded[key] then return __unpack_cached(key) end;
            if __loading[key] then
                -- circular require: hand back whatever is cached so far
                return __unpack_cached(key);
            end;

            __loading[key] = true;
            local results = table.pack(pcall(__modules[key]));
            __loading[key] = nil;

            if not results[1] then
                error(string.format("[bundle] module %s failed: %s", key, tostring(results[2])), 0);
            end;

            -- A Luau module may return more than one value, and require() has to
            -- forward all of them. src/ui/ui.lua reads
            --     local func, data = require(module)
            -- and tab modules return  function(tab) ... end, { name = "Main" }.
            -- Collapsing to a single value here leaves data nil.
            __cache[key] = table.pack(table.unpack(results, 2, results.n));
            __loaded[key] = true;
            return __unpack_cached(key);
        end;
    end;

    return __real_require(target);
end;

require = __require;

-- Assigned to the global only for the duration of this chunk. Executors give
-- each executed script its own environment, so a later execute_script cannot
-- see it. Expose it on getgenv() so diagnostics and hot-patches can reach the
-- module table.
getgenv().Frutiger_require = __require;
getgenv().Frutiger_modules = __modules;
getgenv().Arteria_require = __require;
getgenv().Arteria_modules = __modules;`);

// list_modules
chunks.push("");
chunks.push("local __module_lists = {");
for (const { pattern, matches } of globTables) {
    chunks.push(`    [${luaString(pattern)}] = {`);
    for (const m of matches) chunks.push(`        ${luaString(m)},`);
    chunks.push("    },");
}
chunks.push("};");
chunks.push("");
chunks.push(`list_modules = function(pattern)
    return __module_lists[pattern] or {};
end;`);

// assets
chunks.push("");
if (assets.length) {
    chunks.push("getgenv().__BUNDLED_ASSETS = {");
    for (const { key, b64 } of assets) {
        chunks.push(`    [${luaString(key)}] = ${luaString(b64)},`);
    }
    chunks.push("};");
} else {
    chunks.push("getgenv().__BUNDLED_ASSETS = getgenv().__BUNDLED_ASSETS or {};");
}

// run
chunks.push("");
const runner = `local __ok, __err = xpcall(__require, function(e)
    return tostring(e) .. "\\n" .. debug.traceback();
end, ${luaString("@" + ENTRY)});

if not __ok then
    warn("[bundle] init failed: " .. tostring(__err));
end;

return __ok;`;
// A local continuation can resume an explicitly confirmed echo session after
// teleport, without fetching arbitrary remote code or resetting user settings.
// The saved bootstrap deliberately omits its own embedded copy.
if (ENTRY === "src/arteria/init") {
    const resume = chunks.join("\n") + "\n" + runner;
    const encoded = zlib.zstdCompressSync(Buffer.from(resume)).toString("base64");
    chunks.push(`getgenv().Arteria_bootstrap_b64 = ${luaString(encoded)};`);
}
chunks.push(runner);

const output = chunks.join("\n");

if (!fs.existsSync(path.dirname(OUT))) {
    fs.mkdirSync(path.dirname(OUT), { recursive: true });
}
fs.writeFileSync(OUT, output);

// ── verify every require() call site has a module ──────────────────────────

const referenced = new Set();
const refRe = /"@(src|assets)\/([^"]+)"/g;
for (const mod of modules) {
    if (mod.kind !== "lua") continue;
    const source = fs.readFileSync(mod.file, "utf8");
    let m;
    while ((m = refRe.exec(source)) !== null) {
        referenced.add(m[1] + "/" + m[2]);
    }
}

const missing = [];
for (const ref of referenced) {
    if (ref.startsWith("assets/")) {
        if (EMBED_ASSETS && !assets.some((a) => a.key === "@" + ref)) missing.push("@" + ref);
        continue;
    }
    if (!moduleIds.has(ref)) missing.push("@" + ref);
}

console.log(`modules:  ${modules.length}`);
console.log(`assets:   ${assets.length}${EMBED_ASSETS ? "" : " (required data only)"}`);
console.log(`globs:    ${globTables.map((g) => g.pattern + "=" + g.matches.length).join(", ")}`);
console.log(`out:      ${OUT}  ${(output.length / 1024 / 1024).toFixed(2)} MB`);
if (missing.length) {
    console.log(`\nUNRESOLVED REFERENCES (${missing.length}):`);
    for (const m of missing) console.log("  " + m);
} else {
    console.log("all references resolved");
}
