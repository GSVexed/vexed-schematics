# FERAL NOVA v11.3.2 — Startup Self-Check Compatibility Fix

**Date:** 21 November 2026  
**Release:** `feral-nova-v11.3.2-renaissance-stable-potassium.lua`  
**Automated validation:** [GitHub Actions run 44945240351](https://github.com/GSVexed/vexed-schematics/actions/runs/44945240351) — PASS.

## Issue reproduced from user's Potassium startup report

v11.3.1 compiled and attached all 23 modules but reported `DEGRADED`, `SELF-CHECK INCOMPLETE 62/65`. Exactly three startup assertions referred to old Eagle API counters:

| Obsolete assertion | Current module-backed replacement |
|---|---|
| `v5_all_physical_holds` / `anyClampObservations` | `v1132_eagle_replicated_holds`: `actualClampObservations` + `actualClampHoldSeconds` |
| `v6_native_eagle_remote` / `remoteBinds` | `v1132_eagle_native_remote_lifecycle`: `nativeLungeBinds` + `nativeLungeRebinds` |
| `v7_talon_clock_domains` / `incomparableTargetPressClocks` | `v1132_eagle_target_timing`: `lastTargetAt`, `selectedTargetUpdates`, `serverDeadlineOverwrites` |

All replacement counters actually exist and are initialized by `feral-nova-eagle-actions-v11.3.1.lua`.

## Changes

- Replaced the three obsolete startup assertions with checks of real v11.3.1 Eagle-module fields.
- Updated startup version, banner and interface to v11.3.2.
- Preserved all 22 other gameplay module bodies **byte-for-byte**; the only embedded module updated was UI v11.3.2, to reflect release identity.
- Preserved all 23 load order entries and the single native Rest request owner.
- No fabricated counters or forced READY override; a missing new counter still causes a DEGRADED result.

## Validation

The v11.3.2 workflow passed full bundle + embedded Luau compilation and all previous feed, Rest, action priority, Grab, Eagle and deferred-carry mocks.

A dedicated runtime test extracted the **actual** `H.selfCheck(ctx)` function from the published launcher. With realistic controller field shapes, the function returned `SELF-CHECK PASS 65/65`; after removing `nativeLungeRebinds`, it correctly returned `SELF-CHECK INCOMPLETE 64/65`. This regression prevents obsolete checks and prevents hiding genuine missing fields.

This test is an automated simulation, **not a confirmed Potassium session**. Real-game server-received hunger, thirst, 4× status recovery and oversized Eagle carry remain unverified.

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v11.3.2-renaissance-stable-potassium.lua"))()
```

Close the prior running version with End before launching the new one. Your v11.3.1 build remains available as a fallback.
