# FERAL Project Renaissance 15.0.0

The scoped client-hub rewrite for the v2412 research baseline retains all 21 approved functions in one compact four-tab interface. Server-dependent outcomes remain unverified unless explicitly documented.

CLEAN v14 and its clean loader remain byte-for-byte unchanged. Renaissance has a separate versioned source and loader.

## Start

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()

The launcher pins source 59e0a6d0db6d1a9e8c9f57f7a8368e858f8ec600. The hub is already live-checked for startup, settings, reload and cleanup. All 54 regression scenarios pass. Server-dependent benefits remain explicitly unverified.

## Build and test

Use official Luau commit 97b2f4bf9cd935bed666f3e643a3b749b4d22f38, then:

    python3 roblox-tools/renaissance/run_tests.py --luau /path/to/luau --compiler /path/to/luau-compile

This rebuilds deterministically, compiles modules and fixtures, checks embedded parity and rollback hashes, and runs the full service-boundary suite. test-results.json records the bundle hash and results. CI repeats it on the published commit.

## Records

- docs/FEATURE_AUDIT.md: every function, native dependency and limitation.
- docs/ARCHITECTURE.md: ownership, activation, cleanup and evidence.
- docs/source-traces.json: v2412 fingerprints and compiler provenance.
- docs/LIVE_EVIDENCE.md: scoped live checks and their limits.
- docs/RELEASE_NOTES.md: release status, use and rollback.

The bounded internal ledger is available on the returned hub for programmatic validation. There is no diagnostics tab, private-data export or automatic upload.
