# FERAL NOVA v13.0 — Project Renaissance Engineering Closure

**Release date:** 21 November 2026  
**Final engineering build:** `feral-nova-v13.0-renaissance-stable-potassium.lua`  
**Automated validation:** [GitHub Actions — v13.0 PASS](https://github.com/GSVexed/vexed-schematics/actions/runs/44948654286)  
**Provenance:** 23 bundled modules, 19 byte-identical module bodies from v12.2, 4 revised modules, unchanged previous versions.

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v13.0-renaissance-stable-potassium.lua"))()
```

Press End to close the previous hub first; press Right Shift to toggle the FERAL HUB display. v12.2 and other earlier releases remain available.

## Final source-guided correction (not merely instrumentation)

While auditing the recovered FERAL client, the game controller in `UPLOAD_PART_002_DATA.zip`, `UPLOAD_PART_003_DATA/sources/game/S0003869_part001.source.txt`, shows:

- `FeedCan` is set to **`"eat"` or `"drink"`** when the native game has found an eligible food/water target, or `false` when unavailable.
- `WolfFeed` is set to **`"eat"` or `"drink"`** when the native feed action is actually active, or `false` when stopped.
- The E key invokes `toggleFeed` through ContextActionService, returning `Sink`, so Roblox can mark a genuine feed input as processed.
- `FeralFeedTap` changes invoke `toggleFeed` regardless of the attribute's new value.

The earlier hub erroneously tested `WolfFeed==true` and `FeedCan==true` in several places. In FERAL's actual string-valued states those checks were false, which could make recovery, climb and shared action priority fail to see real eating/drinking.

**v13.0 now recognizes `"eat"`, `"drink"` and legacy boolean `true`, rejecting `false`, `nil` and unrelated values.** This source-verified change was applied consistently to:

1. `feral-nova-native-recovery-v13.0.lua`: native feeding detection, feed watcher, feed interval isolation, early E and FeedCan click protection and automatic Rest arbitration. The E key no longer pauses recovery when native feeding is unavailable.
2. `feral-nova-action-core-v13.0.lua`: both feeding-active and feeding-available state recognition, feeding priority over recovery/AFK/flight/carry, while preserving respawn-safe state cache.
3. `feral-nova-climb-v13.0.lua`: quick-climb gating while native feeding/drinking is active.
4. `feral-nova-ui-v13.0.lua`: correct version identity and clarification of string-valued native feed states; v12.2 responsive full-card click targets, duplicate-click suppression, Eagle display fix and visible error feedback retained.

The four revised modules are embedded byte-identically into the v13.0 23-module launcher. The other 19 module bodies are unchanged.

## System-by-system closure

| System | Code-level result | Live FERAL server caveat |
|---|---|---|
| Hub loader, lifecycle and UI | 23/23 compile; consistent identity, close/reload lifecycle; fixed display and responsive controls | Potassium live clicks must still be verified per actual client |
| Recovery and physical pose | One native hub-owned Rest writer; feeding, manual Rest, combat and input priorities; bounded own-pose masking | Other players' view and authoritative recovery rates not proved |
| Hunger/thirst action priority | Correct native eat/drink strings, eligible E/click/FeedTap early handoff, state-aware resume | Real Hunger/Thirst gains remain game-owned |
| Negative condition clearance | Injury, bleeding, venom clearing measured including attribute disappearance; comparable windows tracked | Genuine 4× server status reduction not confirmed |
| Eagle Talon and carrying | Remote rebinding, target ObjectValue changes, timestamp-domain comparison, carry action arbitration and physical-hold evidence | Oversized pickups and shorter server-authoritative Talon cooldown not confirmed |
| Native Grab V2 | Session-safe end/strike events, bounded native timing, priority reservations | No guarantee of server-graded Perfect strikes |
| Carry | Deferred G cancelled when animal respawns or becomes captured | Server may reject requested carry for gameplay reasons |
| Flight/climb | Input and action-priority arbitration, native action preservation | Server decides accepted movement |
| Anti-AFK | Existing nonintrusive options retained | Roblox session and survival-bonus retention not guaranteed |
| Diagnostics/evidence | Read-only comparisons and truthful server outcome disclaimers | Observations cannot substitute for server proof |

## Verified test results

Workflow: https://github.com/GSVexed/vexed-schematics/actions/runs/44948654286 — **SUCCESS**.

- Official Luau compilation of the launcher and each of the 23 embedded modules.
- Exact source vs embedded body, 23 loader references, preflight loading order, 19 unchanged modules, and one automatic Rest sender.
- Runtime simulation of active `WolfFeed="eat"` releasing hub-owned Rest, then resumed recovery after feeding.
- `FeedCan="eat"` early click and `FeedCan="drink"` processed E-key handoff, with a stray E key **not** interrupting recovery without a native feed target.
- Source-aware action prioritization using `WolfFeed="drink"` and `FeedCan="eat"`; legacy boolean values retained.
- Climb helper accepts real eating and drinking strings, rejects false/nil/unrelated values.
- FeralFeedTap behavior, manual Rest protection, delayed own-Rest echo handling, and cleared condition attributes.
- Existing ranked leases, Eagle remote reconnection, clock-domain conversion, stale Grab V2 packets, respawn-safe carry.
- UI click dispatch, duplicate mouse events, callback-error feedback and non-existent Eagle counter regression.
- The actual extracted startup self-check passed **73/73** in the test environment, and a deliberately removed required field was correctly reported as a failure.
- Permanent check of every property referenced by the UI refresh against its corresponding packaged module. This guards against the stale-property crash found in v12.1.

## What “finished” means

**Project Renaissance's code-level integration, module review and automated validation are complete in this release.** The recovered source produced a real interaction fix, and previously identified source/UI/module conflicts have been corrected.

**It does not establish that every original gameplay ambition is possible on FERAL's production server.** Server-controlled health/status multipliers, oversized Eagle carrying, Talon cooldown restrictions, real resource awards, automatic Perfect outcomes, full AFK survival credit and other-player visible animations require live evidence and may be prevented by the server. No client-side loader can guarantee authority it does not possess. This report deliberately does not label those goals as achieved.

The final release has not been tested inside a live Potassium/FERAL session by this automated workflow; the first live v13.0 startup result should be checked without assuming that the offline 73/73 proves all gameplay outcomes. Previous releases remain available for rollback.
