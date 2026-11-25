# FERAL Project Renaissance 15.4.0

The v2412 client hub retains all 21 approved functions in one compact four-tab interface. Right Shift, permanent Bite Reach, hollow-only outlines and schema-15 saved settings are preserved.

This release adds first-safe-window minigame timing, one bounded deadline timer, resilient native-state reads, immediate native-action recovery handoffs, extended stamina consumption coverage, current target geometry, guarded talon/dive flight recovery and safer feeding/rescue/idle transitions. It passes 176 scenarios and 18 compile checks locally, including a 72-case timing replay matrix. See docs/V15_4_UPGRADES.md for measurements, the full upgrade decisions and live limits.

The retained recovery correction preserves native Rest factors, removes false recurrence pauses, keeps automatic-response provenance, separates camera input from attacks, and resets the owned native animation blend. Actual HP increases and unchanged windows are distinguished; sustained 2x/4x gameplay effects remain unverified. See docs/V15_2_1_RECOVERY.md.

The retained 15.2 behavior keeps ESP/tags restricted to real players, colours outlines green-to-red by current health, and removes floating percentages/distances. It coordinates native feeding approaches and one stalled-session repair, filters invalid bite targets, buffers a post-Rest bite through the original native function, separates predicted impacts from game replies, and adds a bounded G-key water-cub rescue attempt using native pickup rules.

CLEAN v14, its clean loader and complete 15.0.0/15.1.0/15.2.0/15.2.1/15.3.0 bundles remain byte-for-byte unchanged. No threshold-based auto food/water, forced resource refill, oversized carrying or other removed feature is restored.

## Start

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()

The launcher pins immutable source [ef1544f](https://github.com/GSVexed/vexed-schematics/blob/ef1544f25d37f071df90dd1da84b9fd5df60bdaf/roblox-tools/feral-renaissance-v15.4.0.lua). All 176 regressions, 18 compile checks, source parity and rollback checks pass locally and in [published source CI](https://github.com/GSVexed/vexed-schematics/actions/runs/45643744396). Exact Potassium staging in FERAL v2412 confirmed all 13 modules, rapid timing logic, native minigame/feeding handlers, the 17-field stamina plan, renderer construction and clean shutdown while retaining the active 15.3 hub. Validation made zero gameplay requests and zero attribute writes. Actual minigame win rates, rendered/remote pose, flight repair and sustained recovery/stamina/range results remain unverified.

## Build and test

Use official Luau commit 97b2f4bf9cd935bed666f3e643a3b749b4d22f38, then:

    python3 roblox-tools/renaissance/run_tests.py --luau /path/to/luau --compiler /path/to/luau-compile

This rebuilds deterministically, compiles all thirteen modules, fixtures, bundle and launcher, checks source parity and preserved rollback hashes, and runs the service-boundary suite. test-results.json records source hashes and results. CI repeats it on the published commit.

## Records

- docs/FEATURE_AUDIT.md: all 21 retained functions and explicit user-requested interaction improvements.
- docs/V15_4_UPGRADES.md: rapid minigame timing, extended native coordination, per-feature upgrade decisions and boundaries.
- docs/ARCHITECTURE.md: ownership, activation, cleanup and evidence.
- docs/V15_3_IMPROVEMENTS.md: recent trends, native guide, work bounds, operation comparison and Vulture handoff.
- docs/V15_2_1_RECOVERY.md: automatic Rest ownership, native animation correction and actual progress evidence.
- docs/V15_2_INTERACTIONS.md: current native feeding/combat/carry contracts and implementation limits.
- docs/V15_1_INPUT_REVIEW.md: retained minigame input separation.
- docs/source-traces.json: v2412 fingerprints and compiler provenance.
- docs/LIVE_EVIDENCE.md: version-specific executor checks.
- docs/RELEASE_NOTES.md and release.json: source pin, tests, release status and rollback.

There is no diagnostics tab, private-data export or automatic upload.
