# FERAL Renaissance 16.1.2 — held-input continuation candidate

This candidate retains the complete 16.1.1 reliability reconciliation and addresses another pair of code-level hold-input cancellations reported during play. It contains **29 modules**, **28 core feature records**, and **Territory 0.8.0**.

**The implementation is automatically verified; live gameplay acceptance is unverified.** The exact current results, source fingerprint and bundle digest are in [candidate.json](candidate.json). The new input findings are in [16.1.2 held-input notes](docs/V16_1_2_HELD_INPUT.md); the full module audit and remaining limits are in the [16.1.1 engineering report](docs/V16_1_1_ENGINEERING_REPORT.md).

## Open this build

Use the pinned **16.1.2 candidate** loader below. Confirm `RENAISSANCE / 16.1.2` in the window. The old `main/roblox-tools/feral-renaissance.lua` URL still selects the separately recorded **15.7.0 stable baseline**; it does not select this candidate.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/63b189fc871dbc48315e24cdbfe16d1df8246589/roblox-tools/feral-renaissance-v16.1.2.lua"))()
```

The immutable [source commit](https://github.com/GSVexed/vexed-schematics/commit/63b189fc871dbc48315e24cdbfe16d1df8246589) contains the exact tested source and bundle. The older [candidate launcher](../feral-renaissance-candidate.lua) remains on its previous version; use the exact versioned loader above for 16.1.2. Its SHA-256 is `b8d63d8456f21ed61457b60559720ea03dc25bf7a66c7e696d927c8ab452de0b`.

The integrated hub opens with **Right Shift**. On touch devices, the small reopen button remains available when the window is hidden. All controls remain in their existing pages; longer pages scroll.

Hold to Repeat Bites is in **Combat**. The 16.1.2 input patch prevents delayed processed synthetic-click echoes from latching a permanent input suspension, and hovering the hub now pauses without forgetting an existing physical world-originating hold. It still respects native readiness and cancels on real release, explicit UI clicks, focus loss, menus, character changes and unload. The UI distinguishes a native callback from an unverified input-replay fallback. Unsupported discovery stays visible as WAITING/PARTIAL instead of pretending repeated attacks succeeded.

Recovery and Bite Reach default ON for new settings, and explicit saved OFF preferences are honored. Nearby players alone do not disable recovery. Existing native combat and action restrictions remain in force. Territory starts OFF; use **Territory → START FARMING** to start it. Hiding the menu does not stop farming; STOP or unload releases its owned resources.

## What changed

- 16.1.2: Preserve held attack ownership across hub hover and delayed synthetic processed mouse echoes; real consumed UI clicks still cancel.
- 16.1.2: Three additional regressions bring the core total to 424; the existing 305 Territory checks remain required.
- Reliable cancellation of pending synthetic input, callback identity renewal, focus/text/UI ownership, and bounded discovery.
- Restored failed-Rest handling, character state reset, minigame ordering and clock-loss behavior.
- Restored configuration ownership, verified settings backups, responsive UI layout, and independent cleanup.
- Longer bounded hit-observation windows, conservative attribution of overlapping replies, and isolation of ability feedback from ordinary-bite timing.
- Voice/camera rollback after partial failure, including temporarily detached voice emitters.
- Restored missing regression suites; required test inventory; one candidate version source; exact source fingerprints in runtime reports; both core and Territory evidence saved together.

See [CHANGELOG.md](CHANGELOG.md) for details. Previous versioned bundles and stable launchers are protected by hashes.

## Build and verify

Build the official Luau compiler/interpreter at the commit in [version.json](version.json), then run:

```bash
python3 roblox-tools/renaissance/verify_candidate.py \
  --luau /path/to/luau \
  --compiler /path/to/luau-compile
```

This checks protected historical artifacts, compiles all modules and fixtures, runs every required core suite and all Territory suites, verifies exact source/bundle parity and deterministic rebuilding, then writes the candidate report. Source or test changes invalidate the saved evidence. CI performs the same gate without committing generated changes.

The local own-character report is saved automatically when file access is available. It includes the actual hub version, deterministic source fingerprint and save timestamp; no extra diagnostic collector is required. A private report synchronization service may have its own older allowlist and connection limitations, so a local save is not a claim of remote retrieval.

## Evidence and history

- [Candidate verification](candidate.json), [core test results](test-results.json), [Territory results](../feral-amber/test-results.json), [manifest](manifest.json).
- [16.1.2 input continuation report](docs/V16_1_2_HELD_INPUT.md), [full 16.1.1 engineering report and module inventory](docs/V16_1_1_ENGINEERING_REPORT.md).
- [Previous 16.1.0 and 15.x release notes](docs/V16_1_0_HISTORY.md).
- [Stable release metadata](release.json), [historical feature audit](docs/FEATURE_AUDIT.md).

Native executor capabilities, accepted repeat attacks/damage, sustained recovery, voice audibility, full-map retention and live device performance require current runtime evidence. Compilation and simulated service boundaries cannot establish those outcomes.
