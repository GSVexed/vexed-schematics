# FERAL NOVA v13.2 — Saltwater Crocodile Death Roll guard

**Date:** 21 November 2026  
**Base:** v13.1 Project Renaissance, 23 embedded modules  
**Validation:** [GitHub Actions run 44952708088 — SUCCESS](https://github.com/GSVexed/vexed-schematics/actions/runs/44952708088)  
**Bundle:** `feral-nova-v13.2-renaissance-death-roll-guard-potassium.lua`

## Loader

Stop the prior FERAL hub with **End** before loading this version in Potassium:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v13.2-renaissance-death-roll-guard-potassium.lua"))()
```

## What changed

The recovered game client identifies Saltwater Crocodile's F ability as **Death Roll**, with a distinct `FeralDeathRollPhys` ability-state attribute and `FeralDeathRollFX` render pipeline. v13.1 automatic Rest relinquished control on mouse attacks but not this ability's F-key action. That could allow hub-owned Rest and pose masking to resume while the roll was still resolving.

v13.2 revises only the native recovery module:
- Recognizes Saltwater Crocodile, including stage-named variants.
- Yields hub-owned native Rest on actual F input (including input processed by ContextActionService), leaving the game's own Death Roll ability untouched.
- Maintains a short initial grace and then defers automatic Rest while native Death Roll physics is present, with a short settling interval after it disappears.
- Limits cleanup to a maximum of three locally echoed `WolfRest` poses in a narrow hub-owned release window, preserving intentional manual Rest.
- Adds read-only counters for Death Roll input, recognized native state, Rest suppression, echo cleanup and potentially stale native state.

The other **22 embedded modules remain byte-for-byte identical to v13.1**. Combat-tag status recovery, responsive UI, feeding guards, Eagle/flight/carry logic and the other Renaissance work are preserved. One additional startup check verifies the new guard is mounted.

## Validation and limits

[Workflow 44952708088](https://github.com/GSVexed/vexed-schematics/actions/runs/44952708088) passed an official Luau compile of the full launcher and all 23 modules, bundled source identity checks, sole Rest-owner checks and a Luau runtime test of species/native-state detection.

**Not yet live verified.** CI does not prove an in-game animation fix or server-awarded recovery. The underlying stuck animation might originate from the game's Death Roll visual/physics script or a lingering server state rather than automatic Rest. If it persists with the v13.2 hub disabled, do not claim the hub fixed it; investigate native ability cleanup.

## Rollback

The unchanged v13.1 launcher remains available at:
`feral-nova-v13.1-renaissance-combat-status-recovery-potassium.lua`.
