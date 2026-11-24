# FERAL Project Renaissance 15.1.0

The v2412 client hub retains all 21 approved functions in one compact four-tab interface. Right Shift, permanent Bite Reach, hollow-only outlines and schema-15 saved settings are preserved. All thirteen deliberate removals stay excluded.

This update separates bite clicks from automatic native minigame presses, handles multi-hunter updates and missed timing crossings, broadens rear/vertical client targeting, moves health/distance above names, and separates condition recovery from the HP combat exclusion.

CLEAN v14, its clean loader and the complete 15.0.0 bundle remain byte-for-byte unchanged.

## Start

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()

The launcher pins immutable source [5529650](https://github.com/GSVexed/vexed-schematics/blob/552965031659c52e36bf8bda436d0d07d348abd6/roblox-tools/feral-renaissance-v15.1.0.lua). Compilation and 73 regressions pass locally and in [published source CI](https://github.com/GSVexed/vexed-schematics/actions/runs/45456403524). The current Potassium request was acknowledged without a matching console result; new live functionality and server-dependent benefits remain unverified.

## Build and test

Use official Luau commit 97b2f4bf9cd935bed666f3e643a3b749b4d22f38, then:

    python3 roblox-tools/renaissance/run_tests.py --luau /path/to/luau --compiler /path/to/luau-compile

This rebuilds deterministically, compiles all ten modules, fixtures, bundle and launcher, checks source parity and both rollback versions, and runs the service-boundary suite. test-results.json records the source hash and results. CI repeats it on the published commit.

## Records

- docs/FEATURE_AUDIT.md: every retained function, native dependency and limit.
- docs/ARCHITECTURE.md: ownership, activation, cleanup and evidence.
- docs/V15_1_INPUT_REVIEW.md: native minigame input contract and interaction changes.
- docs/source-traces.json: v2412 fingerprints and compiler provenance.
- docs/LIVE_EVIDENCE.md: version-specific live checks and their limits.
- docs/RELEASE_NOTES.md and release.json: release state, use and rollback.

The bounded internal ledger is available on the returned hub for programmatic validation. There is no diagnostics tab or automatic upload.
