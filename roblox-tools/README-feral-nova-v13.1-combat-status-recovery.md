# FERAL NOVA v13.1 — Combat-Compatible Native Status Rest

**Date:** 21 November 2026  
**Validation:** [GitHub Actions 44950094401 — SUCCESS](https://github.com/GSVexed/vexed-schematics/actions/runs/44950094401)  
**Bundle:** `feral-nova-v13.1-renaissance-combat-status-recovery-potassium.lua`

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v13.1-renaissance-combat-status-recovery-potassium.lua"))()
```

Press End to stop the prior build before launching v13.1.

## User-reported discrepancy and source explanation

The user reported no 4× recovery for negative statuses under the automated hub, while **manual Rest still accelerated status clearing during combat**.

The recovered FERAL `StatusConfig` (`UPLOAD_PART_002_DATA.zip`, `S0000500_part001.source.txt`) supplies `REST_MULT = 4` independently for injury, bleeding and venom. The recovered `NeedsConfig` (`S0000448_part001.source.txt`) separately contains `HEALTH_NO_REGEN_IN_COMBAT = true`. Ordinary **health** regeneration during combat and **negative-effect decay** while resting are different mechanics and should not be conflated.

The prior hub unnecessarily blocked automatic Rest requests whenever `FeralCombatUntil` was active or the combat clock was unavailable, even if the animal was otherwise eligible to rest.

## Code fix

- `feral-nova-action-core-v13.1.lua`: The `allowed("recovery")` decision no longer treats `S.combat` or `S.combatTimeUnknown` as exclusion by themselves. Combat continues to suppress unsafe AFK walking. Actual attack input, active Grab V2, captive states, feeding/drinking, menus and AFK travel still retain their relevant priority.
- `feral-nova-native-recovery-v13.1.lua`: Removed the duplicate `FeralCombatUntil` exclusion from the native Rest owner. Automatic Rest can remain enabled during combat tags without calling the visible Rest toggle. The same native `WolfActions:FireServer("Rest", true)` path is reused; no fabricated status award or direct effect attribute write.
- Real primary mouse attacks temporarily cancel hub-owned Rest via `Rest(false)` and briefly yield control, so the game can process bites. The signal is automatically rearmed after its ordinary action cooldown. This means **not** literally 100% Rest uptime during repeated/held attacks.
- Manual Rest is still preserved. The source-verified `"eat"`/`"drink"` feeding protection remains in place.
- Added `auto_combat`, `manual_combat` and `baseline_combat` status measurement buckets so negative effect clearing can be compared within combat, rather than averaging all combat into one uninformative bucket. Where meaningful comparable samples exist, the native recovery report prints the combat automatic-Rest/baseline ratio. Insufficient samples are explicitly indicated instead of reported as 4×.
- `feral-nova-active-recovery-v13.1.lua`: Removes stale descriptions that claimed combat tags automatically disable status recovery; no new competing Rest writer.
- `feral-nova-ui-v13.1.lua`: Adds native combat Rest signal seconds and status sample totals in the Survival DATA tab.

Four module bodies were revised and 19 preserved unchanged from v13.0. All 23 are embedded in the new launcher. Only the native recovery module sends automatic `Rest` requests.

## Validation

[GitHub Actions run 44950094401](https://github.com/GSVexed/vexed-schematics/actions/runs/44950094401) passed:

1. Official Luau compilation of the full bundle and all 23 embedded modules.
2. Source-to-bundle identity, preserved legacy modules, sole Rest owner and accurate v13.1 release metadata.
3. Native Rest controller activation while `FeralCombatUntil` remains active; the mocked Rest(true) is sent without requiring the combat tag to expire.
4. Separate combat auto-Rest status rate attribution, including observed `FeralBleed` attribute reduction.
5. A real attack input still cancels owned Rest promptly and the controller rearms after input cooldown while combat remains tagged.
6. Shared action policy allows recovery during combat but continues to reject unsafe AFK movement, feeding conflicts, Grab priority and other unsafe actions.
7. All earlier feed, carry, climb, flight, Eagle, Grab V2 and responsive UI regression tests.
8. **75/75** startup checks through the actual extracted launcher self-check function in a simulated runtime, and a deliberate missing-field check still reports INCOMPLETE.

## Critical server-side limitation

**This release proves removal of an incorrect client-side combat exclusion, not a server-confirmed always-on 4× recovery rate.** The server may refuse moving or simultaneous attacking/resting, or clear Rest if movement violates native eligibility. A client-side `REST_MULT=4` constant, a sent `Rest(true)` request or a locally masked pose does not prove accelerated *server-awarded* status clearance.

The user's manual-Rest observation is consistent with the game's exposed config and supports removing the combat tag gate, but it does not establish that production servers grant the same 4× bonus while constantly moving and attacking.

The measured *actual negative-effect attributes* are the relevant in-game outcome. Do not relabel the feature server-verified unless comparable rates show that result.

## Rollback

The previous `feral-nova-v13.0-renaissance-stable-potassium.lua` remains unchanged for rollback.
