# Arteria

Minimal interface with 46 selected legacy controls plus three Arteria ESP controls, across
Movement, Combat, World, Removals and Visuals. Automation contains the Soup
echo-farm workflow; Settings contains profiles and keybinds. Existing AC layer retained.
Architectural sidebar, condensed editorial headings, black/graphite surfaces,
bone-white text, neon-white edge lighting, square controls, and separator-led rows. No external UI assets.
All original modules and the legacy interface remain in the source tree.

## Run Arteria

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/beyondthetowers/arteria/main/dist/arteria.lua"))()
```

## Arteria build

```bash
node tools/bundle.js --no-assets
```

The generated `dist/arteria.lua` can also be run locally. The Frutiger URLs in
the legacy section below still refer to the old release, not this rework.
Arteria does not load the old feature registry, ESP, unrelated farms, legacy
theme passes, or asset extraction. `src/arteria/catalog.lua` is the explicit feature
allowlist. Selected modules load on first enable; unselected factories remain
bundled but are not initialized. Combat observers load only when needed.
`--no-assets` excludes optional fonts/media but always embeds the required
`base.json` and `extra_data.json` timing data. Missing required data fails the
build, rather than producing a client that cannot initialize auto parry.

- `F`: fly; `G`: walk speed; `J`: infinite jump.
- Hold `V` while auto assassination is enabled to trigger dustlunge.
- Movement / Combat / World / Removals navigation; search spans all sections.
- Visuals adds a bone-white R6/R15 player skeleton ESP, with distance,
  team-filter and line-width controls. It uses pooled native screen-space lines,
  not Drawing API or per-frame object creation; disabling removes the overlay
  and its connections. It handles rig changes and streamed-out body parts.
- Player ESP reworks the existing player-ESP entry point for Arteria: neon
  corner/full frames, character/display/user names, health bars and HP values,
  distance labels, team filtering, and optional outline/silhouette highlights.
- World ESP reworks the existing base-ESP entry point for Arteria: the legacy
  mob/chest/ingredient/artifact classification rules, nearest-first label budgets,
  distance limits and configurable update rates. Labels and player graphics are
  pooled; no per-frame GUI creation. Legacy Frutiger keeps its original backends.
- A left sidebar replaces the old tab strip; compact screens use an abbreviated
  rail without reducing text size. Portrait and short landscape layouts reflow.
- Tab / Shift-Tab moves through visible controls; Enter activates a focused
  control or edits a field. Escape cancels rebinding or hides the interface.
- Roblox's reduced-motion preference is honored, with a manual override to
  reduce motion further. Page slides/fades, staggered row entrances, press
  feedback, neon hover/focus transitions, expanding settings, moving selection
  markers and toggle transitions remain bounded and cancellable. Neon is
  bone-white, not a rainbow palette; no world-lighting effects are installed.
- The sidebar hides its distracting scroll stripe and keeps selection markers
  at least 20 px away from desktop navigation text. Settings uses brighter body
  copy, a labelled profile field, a clear Next Saved Profile action and distinct
  save/load/delete buttons.
- `+` expands a feature's settings; mode buttons cycle through their values.
- Right Shift shows/hides the panel by default. The header HIDE button hides it too.
- Click a key label to rebind; Escape cancels; Backspace clears. Duplicate
  bindings, the current menu key and V are reserved. Numeric fields reject invalid values
  and clamp finite values to their limits.
- All feature toggles default off and reset off on respawn. Settings are session-only unless saved to a named profile.
- Auto fight remains WIP. Auto feint depends on auto parry. Validation is an
  auto-parry option, not a separate action. Hitbox visualization shows processed
  attacks; hitbox simulation is independent.
- Fake void and Castle Light/Yun Shul gate removals require the Depths; Hive
  gate removal requires Eastern Luminant. Fake void loads the original internal
  no-kill-bricks dependency when enabled.
- The original clouds/sea removals are not fully reversible; rejoin to restore.
- AC status is **loaded, unverified**, not a guarantee of protection.
- `getgenv().arteria:destroy()` disables selected features and removes the interface.
  Existing AC hooks remain because the legacy layer exposes no uninstall API.

### Settings and profiles

Settings provides a menu-key binding, a keybind list for every feature, and
named Save / Load / Delete profiles in `Arteria/Configs/profile-<name>.json`.
Delete requires confirmation. Profile names cannot traverse directories.
Malformed JSON, unknown schema versions, duplicate/reserved binds and nonfinite
option values are rejected before application. Numeric options are bounded.

Load restores settings, bindings and reduced motion by default. **Restore saved
feature toggles** is a separate opt-in. Profiles never contain farm consent,
slot-reset tokens, or automatic farm-start instructions. Loading is blocked
while an echo cycle owns the controls. There is no automatic config loading.

### Automation / Echoes

The Automation sidebar page integrates the existing **Soup echo cycle**, not the
other legacy echo routes. It shows cycle/echo counters, stage/errors, Start and
Stop. It never starts just because the page is opened.

**This cycle intentionally kills, wipes and recreates the selected character.**
Starting requires typing the current slot and explicitly accepting deletion.
Only use a disposable slot. Stop cannot undo a wipe already sent to the server.

- The farm owns scoped timers, child tasks, score connections and tweens. Stop
  cancels those and restores feature states it temporarily enabled.
- The legacy farm HUD is not mounted; status appears in the new interface.
- `Arteria/echo-session.json` stores confirmed intent, counters and a per-run
  token. `Arteria/bootstrap.lua` stores a local continuation. No remote loader
  is fetched for resuming.
- Queued farm actions check the saved token; Stop invalidates that token before
  cleanup. Character replacement pauses work and resumes only the confirmed
  slot. An unrelated slot cannot inherit the farm.
- Manual injection does not automatically resume a saved farm; confirmation is
  required again. Only the token-guarded queued continuation carries resume intent.
- Menu transfers are bounded and use the legacy StartMenu/Servers interfaces,
  without requiring the old hopper's IP/location file.
- Full gameplay/teleport behavior still requires in-client validation. Tests
  never execute an actual farm, character deletion, remote call or teleport.

Checks:

```bash
node tools/test-arteria.js
node tools/test-arteria-runtime.js path/to/luau.exe
node tools/test-arteria-ui.js path/to/luau.exe
node tools/test-arteria-echo.js path/to/luau.exe
node tools/test-arteria-config.js path/to/luau.exe
node tools/test-arteria-esp.js path/to/luau.exe
luau-compile --null dist/arteria.lua
```

The runtime test uses fake modules/signals and never connects to Roblox.
Passing these checks does not verify legacy gameplay behavior in the live game.

Asset regression: enabling auto parry in the old minimal build failed on every
reported attempt (four in the supplied log): omitted timing assets entered a
disk fallback that called the wrong Base64 API, then passed an empty payload to
decompression. Required-asset round-trip tests and explicit missing-file errors
now guard that path. The timing-speed helper also reads `track.Speed` directly
instead of recursively calling itself.

Legacy build (unchanged entry point):

```bash
node tools/bundle.js --entry=src/init --out=dist/frutiger.lua
```

## Legacy Frutiger

A Deepwoken client. Previously released as Project Rain, then rebuilt through an
intermediate rename; the tree, the build tooling and the single-file bundle are
all here.

## run it

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/beyondthetowers/project-rain/main/dist/frutiger.lua"))()
```

`dist/frutiger.lua` is a single self-contained chunk: it flattens the module
tree, installs a resolver for `@src/...` requires, inlines the assets, and does
not touch the filesystem except for the config folder.

`dist/loader.lua` is a thin fetcher for the same bundle -- it pulls the file and
runs it, and checks the raw URL actually returned Lua rather than a GitHub 404
page.

## layout

```
src/                    module tree
  init.lua              entry point
  luarmor_init_script   build-time primitives + legacy folder migration
  features/             movement, combat, visuals, exploits, removals, qol
  automation/           persistent farm tasks
  security/             anti-cheat layer
  utility/              UI library, deepwoken helpers, managers
  ui/                   tabs and components
assets/                 fonts, sounds, morph model, planner data
tools/
  bundle.js             flattens src/ into dist/
  gen-registry.js       regenerates src/features/loader.lua from the tree
  rebrand.js            rename tooling (dry-run by default)
  lua-guard.js          refuses a build containing a JS-style comment in Lua
dist/                   generated -- do not edit by hand
repro.lua               standalone detection-bisect harness
```

## building

```bash
node tools/gen-registry.js                              # after adding/removing feature modules
node tools/bundle.js --entry=src/init --out=dist/frutiger.lua
node tools/bundle.js --entry=src/init --no-assets --out=dist/frutiger-lite.lua
```

`--out=` is what decides the filename; `--no-assets` only controls whether the
20 bundled assets are inlined.

`tools/gen-registry.js` rewrites `src/features/loader.lua` from scratch. If you
hand-edit that file, don't re-run the generator without stashing your changes.

`tools/bundle.js` refuses to emit if any module contains a `//` comment -- Lua
has none, and an invalid chunk fails silently under `pcall`. It also reports any
`@src/...` or `@assets/...` reference it cannot resolve; a missing asset shows up
there.

## upstream

This began as an open-source release of Project Rain. Large parts of the
original were stripped before publication -- the security layer, the feature
registry, several modules and scattered logic. Those have been reconstructed
here where possible; `git log` describes what was rebuilt and why.
