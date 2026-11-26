# FERAL Renaissance 16.0.0 candidate

One integrated hub: **22 retained feature records, 14 core modules and 12 Territory modules**. Territory 0.8.0 uses the same five-tab window, scheduler, settings and unload lifecycle. This branch consolidates the recovery work from PR #13, combat integration from PR #15 and the full execution specifications from PR #14.

**16.0.0 is a candidate, not a promoted stable release.** Automated compilation and regression evidence are recorded in [test-results.json](test-results.json) and the [Territory results](../feral-amber/test-results.json). No current live Roblox gameplay was executed for this overhaul. Server-accepted recovery, hits, grades, motion, resources and rewards remain live verification gates.

## Load the candidate

Use the separate [candidate loader](../feral-renaissance-candidate.lua). Its URL is pinned to the immutable implementation commit in [candidate.json](candidate.json); it does not follow an evolving branch. The complete [16.0.0 bundle](../feral-renaissance-v16.0.0.lua) includes all 26 modules and makes no runtime Territory source downloads.

Recovery and Zoom retain their existing new-install defaults. Every saved explicit OFF is preserved. **Territory always starts OFF**; open its tab and choose START FARMING when wanted. Changing tabs or hiding the hub does not stop an active farming session; STOP or Unload releases it.

Right Shift toggles the menu. A small FERAL button reopens a hidden menu without a keyboard. The window fits and clamps to the viewport, supports dragging, and retains the compact bite marker, hollow health outlines and independent pack-coloured names.

## What changed

- Recovery reserves attack priority through native stand-up timing, treats each negative condition independently, and restores owned pose state immediately after a failed request.
- Deferred bites cancel when the native attack already succeeded. Target geometry preserves native species bonuses, rejects stale targets, prefers clear eligible targets, and shares the stock eligibility calculation with Territory hunting.
- Hit replies, local impact and observed target HP remain separate. Delayed replies can update the correct bounded transaction; ambiguous overlapping damage remains unattributed.
- Minigame timing and native session adoption run before background Territory work. Legal timing recovery, clock gaps, session retirement, manual bindings and automation-OFF session ownership are covered.
- Native callbacks and nested configuration leases follow actual script/table identities. Game updates cannot silently reuse private v2412 offsets.
- Feeding, carrying, flight, swimming, climbing, gamepad input, AFK, camera limits, settings backup and cleanup received targeted repairs.
- Territory estimates recurring scent work, defers expansion under overload, respects manual input, discards stale asynchronous routes, and checks real resource/HP continuity.

See the [release report and rollback](docs/OVERHAUL_16_RELEASE.md), [native mechanism evidence](docs/NATIVE_MECHANISMS_16.md), and [all-feature/module/acceptance ledger](docs/OVERHAUL_16_ACCEPTANCE.md) for exact changes and remaining limits. Autonomous Territory climb, flight and underwater-depth routing remain unsupported; they release ground steering instead of claiming completion.

## Stable and rollback

The existing main launcher remains pinned to **15.7.0 / Territory 0.7.0**. Its source, release metadata and earlier versioned bundles are unchanged. To load that exact stable bundle:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/3434396b4a9057bdba8c1f146325bd26f697d1ce/roblox-tools/feral-renaissance-v15.7.0.lua"))()
```

Use the hub's Unload control first when manually rolling back. The bootstrap also retires an existing compatible owner on successful hot reload. If candidate staging fails, it keeps the previous owner; if activation fails after retirement, it cleans the candidate and asks for the pinned stable loader rather than pretending to resurrect closed legacy callbacks.

## Build and verify

Official Luau revision: `97b2f4bf9cd935bed666f3e643a3b749b4d22f38`.

```bash
python3 roblox-tools/feral-amber/build.py
python3 roblox-tools/renaissance/run_tests.py \
  --luau /path/to/luau --compiler /path/to/luau-compile
python3 roblox-tools/feral-amber/run_tests.py \
  --luau /path/to/luau --compiler /path/to/luau-compile \
  --output roblox-tools/feral-amber/test-results.json
```

The core runner deterministically rebuilds the bundle and manifest, compiles every module and fixture, checks exact embedded-source parity, protects historical hashes, and validates both the stable pin and candidate pin. The Territory runner now tests the current manifest's integrated candidate and separately retains stable-hub compatibility coverage.

## Project records

- [Execution directive](docs/PRO_ONE_SHOT_FULL_OVERHAUL_HANDOFF_2026-11-26.md), [70 original acceptance scenarios](docs/FULL_HUB_PERFECTION_ACCEPTANCE_MATRIX_2026-11-26.md), [combat investigation](docs/P0_COMBAT_GHOST_HITS_AND_MISSING_BITES_PREPARATION_2026-11-26.md).
- [Current architecture](docs/ARCHITECTURE.md), [historical feature audit](docs/FEATURE_AUDIT.md), [release history](docs/RELEASE_NOTES.md), [historical live evidence](docs/LIVE_EVIDENCE.md).
- [Territory T01–T44](../feral-amber/docs/PREPARATION_EXECUTION_LEDGER.md), [S01–S62](../feral-amber/docs/V0_7_SCENARIOS.md), [native contracts](../feral-amber/docs/native-contracts.json).

Historical live observations are not current-server validation. There is no automatic diagnostic upload, raw native capture, credential, or local health/resource forgery in the candidate.
