# FERAL Amber Autopilot 0.6.0

Territory farming is now a permanent **Territory** page in Renaissance 15.6.0. The hub owns its window, scheduler, controls and shutdown.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-amber.lua"))()
```

Spawn, join a pack and select **START FARMING**. The engine starts disabled. **STOP FARMING** releases owned movement and feeding input. **Right Shift** opens or hides the main hub; hiding it or changing tabs keeps farming active. **SKIP TARGET** defers the current hex. **COPY STATUS** copies a local report and performs no upload.

The 0.6.0 overhaul adds committed prey pursuit, original native attack dispatch without an advisory cooldown veto, continuous direct-route recovery, precise detours, terrain-drop checks, guarded Burst when stamina telemetry is absent, stable resource searches, survival forecasting and nested objective resumption. See the [release report](docs/V0_6_RELEASE.md).

## Farming behavior

- Complete the live configuration's regions in a snake: top-left → top-middle → top-right → middle-right → centre → middle-left → bottom-left → bottom-middle → bottom-right. Finish eligible claims within the selected region, follow a local neighboring route, and revisit deferred areas. Critically fading scent can interrupt the sweep.
- Skip a hex occupied by a non-pack player and select another in the same coordinator tick. Nearby people do not cause a blanket pause. Packmates do not enter the contest map.
- Retain progressing, nearly completed territory work before routine care, then observe stable replicated completion before departure. Critical needs and genuine native interruptions still take priority.
- Hold sprint on travel, request eligible Burst on clear straights, and brake for corners and interactions. Confirmed sprint can upgrade to Burst immediately. Requests and observed native gaits are displayed separately.
- Check animal-sized collision clearance, avoid canopy waypoints, and try a local outward detour when touching a tree. Ineffective travel is retried within seconds; path jobs are cancellable and bounded.
- Follow moving NPC prey from behind, match approach speed with ordinary input, and stop to bite stationary prey when native attack geometry permits. Verify HP decline and abandon ineffective targets promptly. Only eligible NPCs are hunted.
- Drink to the native thirst maximum, including convenient native drink offers during travel. A manually interrupted or prematurely ended drink can restart. Food, water and hunts share one objective owner; territory resumes after care. Missing resources cause a search route when one is available.

Native Species/Forage configuration supplies diet and capabilities. Bear/Spirit Bear is covered by the fixtures; coat is display metadata. The framework supports ground and surface-swimming travel. Aerial routes and underwater navigation remain manual.

## Verification

The pinned official Luau toolchain passes **215/215 Amber regressions** and **187/187 retained Renaissance regressions**. Both bundles have exact source parity; previous versioned bundles remain hash protected. Scenarios include native hub lifecycle, interrupted/full drinking, contested hexes, region ordering, stable completion, Burst acknowledgements, prey following, tree overlap and bounded stalls.

These are deterministic simulations and service mocks. **Current live FERAL travel, gait acceptance, NPC damage, feeding rates and Amber/hour are unverified for this release.** Configuration and local observations cannot independently prove server persistence or reward attribution.

See the [0.5 release report](docs/V0_5_RELEASE.md), [test results](test-results.json) and [static native contracts](docs/native-contracts.json). Previous [0.4 engineering evidence](docs/V0_4_RELEASE.md) remains historical.

## Modules

| Module | Responsibility |
|---|---|
| `planner` | Region completion, local tours and critical scent priorities |
| `agent` | One objective, territory evidence, care suspension and resume |
| `care` | Feeding request, interruption, retry, resource gain and full thirst |
| `hunt` | Trailing pursuit, speed matching, native attack evidence and abandonment |
| `nav` | Streamed routes, body clearance, detours and physical progress |
| `gait` | Gait selection, observed acknowledgements and owned toggles |
| `bridge` | Native configuration, state, food, water, NPC eligibility and inputs |
| `driver` | Movement callback discovery and exact ownership restoration |
| `ui` | Built-in page and local status controls |
| `runtime` | Renaissance scheduling, engine reuse and cleanup |

```bash
python3 roblox-tools/feral-amber/build.py
python3 roblox-tools/renaissance/build.py
python3 roblox-tools/feral-amber/run_tests.py \
  --luau /path/to/luau --compiler /path/to/luau-compile
python3 roblox-tools/renaissance/run_tests.py \
  --luau /path/to/luau --compiler /path/to/luau-compile
```

Official toolchain commit: `97b2f4bf9cd935bed666f3e643a3b749b4d22f38`. Amber introduces no root transform, velocity, resource, ownership or direct gameplay-remote writer.

## Rollback

The previous complete 15.5.0 / Amber 0.5.0 integrated bundle remains unchanged:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/ecd087cabbafcea08a73b3dd56401faca1cdb6ca/roblox-tools/feral-renaissance-v15.5.0.lua"))()
```

Earlier companion and core bundles remain hash protected. Historical rollout details are in the [0.5 report](docs/V0_5_RELEASE.md).
