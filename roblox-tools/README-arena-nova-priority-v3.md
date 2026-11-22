# ARENA NOVA v3 — Priority Collector (gameplay-first)

This collector replaces the old all-at-once FERAL-derived Arena v1.x and the overly broad Arena v2 scan. It is built for the Roblox Arena of Survival experience (universe `7209131331`).

## Potassium launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/arena-nova-priority-collector-v3.0.lua"))()
```

**Do not run alongside an older diagnostic.** If one is still running, use **STOP & SAVE**, keep its export, then close that panel.

## Why your v2 scan was so slow

Your v2 summary showed **53,303 observed objects**, **38,602 eligible client scripts**, **25,000 queued source candidates**, **290 exported sources**, **170 source failures**, **1,042 written files**, and **129.4 seconds elapsed**. This is not acceptable for live gameplay. The previous inventory intentionally included Roblox platform code, which can dwarf game-specific scripts; the summary does not by itself establish how many were platform-owned.

## v3 collection strategy

- **Platform exclusions:** explicitly skip deep traversal of `CorePackages`, `CoreGui`, `RobloxReplicatedStorage`, `RobloxReplicatedScriptStorage`, `PlayerModule`, and `ChatScript`. Write a separate `excluded_platform` record for each. Roblox platform source **is not decompiled** in this fast collector. This is a deliberate scope trade-off.
- **Game code first:** depth-first traversal with priority given to ReplicatedFirst, ReplicatedStorage, StarterPlayer, StarterPack, StarterGui, and Players before broad Workspace geometry. Script and remote inventories are retained, and relevant object attributes and selected properties are captured.
- **Focused properties:** inspect attributes and extra properties on significant objects rather than automatically inspecting every descendant of a broadly named `Map` or `Arena` branch.
- **Metadata stage capped:** up to 35,000 in-scope objects and a maximum cooperative metadata stage of 26 seconds in lobby or 11 seconds in match; incomplete coverage is marked honestly.
- **Source stage capped:** up to 48 native source attempts in lobby, and 2 in match, within total session cooperative time budgets: **48 seconds lobby / 16 seconds match**. Failed source can optionally use an equally bounded bytecode recovery. Do not expect every client script to be decompiled in a single pass.
- **FPS protection:** observes RunService heartbeat; if estimated FPS stays below roughly 28 during source extraction for about 1.5 seconds, stops expensive decompilation and seals the capture.
- **Circuit breaker:** repeated native timeouts/failed reconstructions end the source stage rather than continuing to grind.
- **Persistent source cache:** `ARENA_NOVA_PRIORITY_V3/cache_index.json.txt`; tries importing existing `ARENA_NOVA_SMART_V2/cache_index.json.txt` when the v3 cache is absent. Only same PlaceId, script class, path and PlaceVersion are eligible. Cache reuse is **not** verified bytecode identity; this limitation is recorded. Successfully exported source is stored once as a file in the capture; the cache index points to that copy, avoiding v2's duplicate source-file writes. **Keep previous capture folders if you want to preserve this cache.**
- **Portable ZIP:** every capture includes the actual sanitized source files it used, including cache hits, and a manifest with explicit completeness flags. Upload the timestamped capture ZIP, not necessarily the entire cache root.

## Use

1. Join the Arena lobby and execute the launcher.
2. Leave **MODE: LOBBY** and click **START SMART SCAN**.
3. After the run, locate the capture folder under `ARENA_NOVA_PRIORITY_V3/captures/`, zip that **whole timestamped folder**, and upload it to ChatGPT.
4. For a match, load the same launcher, switch the mode to **MATCH**, and start the capture. Match mode has a short budget and is not intended to decompile the whole game.
5. If performance drops despite protection, click **STOP & SAVE** or end the scan. A native executor decompilation call may block the client and cannot always be pre-empted by Luau; the specified budgets are **not guaranteed hard wall-clock limits**.

**Coverage and privacy:** The collector records a client-side snapshot only, not server-only code. It does not invoke gameplay remotes, modify gameplay data, hook APIs or upload anything. Chat and other-player private branches are excluded; source strings are heuristically scrubbed before writing. Inspect exported files before sharing if they may contain sensitive data. An incomplete inventory or source stage is not claimed complete.

**Verification:** [GitHub Actions Luau compile and static safety checks](https://github.com/GSVexed/vexed-schematics/actions/workflows/arena-nova-priority-v3-validation.yml) passed. This verifies source syntax and stated design invariants, **not measured Potassium speed or successful runtime behaviour inside Roblox**.
