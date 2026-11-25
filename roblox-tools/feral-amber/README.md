# FERAL Amber Autopilot 0.4.0

This continues the published Amber system and the unfinished `renaissance/amber-v0.4-reliability` branch. It uses continuous animal input, one objective coordinator and measured game-state changes.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-amber.lua"))()
```

Select **START** after spawning and joining a pack. The combined launcher loads Renaissance if needed. Amber starts disabled. **STOP** releases movement and owned pending inputs. **Right Shift** follows Renaissance's menu visibility. The header drags the panel; **MIN** and hiding the panel leave farming active. **COPY STATUS** copies a short report locally; no automatic upload occurs.

The current reference is Bear with the Spirit Bear coat. Coat is display metadata. Native Species/Forage configuration supplies diet and swimming information for other animals. The strategic territory framework is shared; aerial travel and underwater route control are not implemented.

## What changed

- Steering passes through the detected PlayerModule `moveFunction` before FERAL's `WolfMove` reads movement input. Both PlayerScripts and the captured StarterPlayer layouts are supported. Unsupported or inaccessible layouts use native keys, with observed movement and bounded retries.
- Streamed route segments are prefetched. Pending computations cannot resume after STOP, unload or character change. Progress survives moving-target updates and ordinary route replanning. Terrain walls, body width, sharp turns, overshot waypoints, circling and repeated position corrections are handled explicitly.
- Ground/water transitions use sampled terrain and continuous horizontal input. Swimming no longer causes the main coordinator to pause. Difficult banks trigger alternative local probes and bounded route failure.
- Gaits have separate requested and observed states. Sprint uses held Left Shift; Burst and trot use their native Begin toggles. Missing acknowledgements cause a bounded retry, an alternative input provider when available, and a slower fallback. A numeric `HudBurstNo` pulse expires correctly.
- Hunts pursue eligible NPCs, lead moving targets, retain close pursuit speed, check native geometry/visibility and verify prey HP. Inputs alone never count as damage, death or a meal. Ineffective prey are abandoned and cooled down.
- Food and water have approach, interaction and actual-resource verification. Pending native feeding owns its approach; repeated E cannot cancel it. Care remains latched through its target, and the suspended territory objective is resumed.
- All current eligible hexes are considered, with ownership, scent, partial progress, known reward values, travel distance, player hazards, failed targets and waiting time affecting selection. No map-size constant is used.
- Unloading/replacing Renaissance or re-executing Amber closes the previous companion, releases inputs, invalidates path jobs and restores its owned movement callback.

## Verification and limits

See [release report](docs/V0_4_RELEASE.md), [test results](test-results.json), and [static native contracts](docs/native-contracts.json).

The official pinned Luau compiler/interpreter runs the component, simulated travel and complete-package lifecycle suites. Renaissance's separate regression suite is also run. These establish build and client-contract behavior; **live FERAL travel, gait acceptance, prey damage, feeding rates and Amber/hour have not been tested for 0.4.0**.

Native HUD flags are client observations. HP/resource/territory changes are observations of the available game state; the addon cannot independently prove server persistence or causally attribute every change. The report preserves that distinction.

### Remaining targeted gameplay check

1. As Bear/Spirit Bear, join a pack and select START. Allow roughly a minute of territory travel, including a water crossing if the selected route has one. Check that the reported travelled distance grows.
2. When a normal low need triggers care, check that the need actually rises and territory work resumes. NPC damage should appear as observed HP declines, not just attack requests.
3. Select STOP, then unload Renaissance. Movement should return to normal and Amber's panel should disappear. If something stalls, click COPY STATUS before unloading and provide that single report.

### Rollback

The immutable `feral-amber-autopilot-v0.3.lua` bundle is retained. With Renaissance loaded:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-amber-autopilot-v0.3.lua"))()
```

The old v0.1/v0.2 bundles and Renaissance 15.4.3 are also protected by hashes. To revert the default, restore only `roblox-tools/feral-amber.lua` to its preceding v0.3 version.

## Modules and local validation

| File | Responsibility |
|---|---|
| `src/agent.luau` | Objective ownership, care latch, interruption and territory evidence |
| `src/planner.luau` | Pure strategic territory scoring |
| `src/nav.luau` | Cancellable streamed routing and measured physical progress |
| `src/driver.luau` | Runtime movement callback discovery and ownership restoration |
| `src/gait.luau` | Gait decisions, acknowledgements, retry limits and toggles |
| `src/hunt.luau` | Pursuit, interception, attack evidence and abandonment |
| `src/bridge.luau` | Native config/state, food/water/NPC eligibility and inputs |
| `src/ui.luau` | Compact controls and local status copying |

```bash
python3 roblox-tools/feral-amber/build.py
python3 roblox-tools/feral-amber/run_tests.py \
  --luau /path/to/luau --compiler /path/to/luau-compile
```

CI uses official Luau commit `97b2f4bf9cd935bed666f3e643a3b749b4d22f38`. `build.py --check` requires byte-for-byte bundle parity. The gate also verifies rollback hashes and rejects direct resource, position, velocity, CFrame and gameplay-remote writers in Amber source.
