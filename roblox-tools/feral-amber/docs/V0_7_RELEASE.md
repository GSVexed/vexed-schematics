# Territory 0.7.0 / Renaissance 15.7.0 release

Date: 2026-11-26. This is the implementation release for the Territory preparation, with an additional Hippo ability gait correction. It retains the integrated Territory page, one launcher, Right Shift, Zoom Unlock, all previous feature records and all historical documents/bundles.

**The full requested perfect/all-animal unattended milestone remains incomplete.** Ground and configured surface swimming are implemented with stronger simulated evidence. Native climb/flight/depth adapters, sustainable full-map capacity, real-device calibration and repeated live acceptance remain open. The [44-item ledger](PREPARATION_EXECUTION_LEDGER.md) and [62-scenario map](V0_7_SCENARIOS.md) preserve each requirement and its evidence.

## What changed

- Territory strategy uses priority/time and observed directed access costs, chooses a nearby region entry/orientation, retains a short itinerary, estimates scent slack and reports pressure among known due maintenance jobs. Idle maintenance waits for useful work instead of touring owned territory needlessly.
- Navigation can attempt checked long streamed-goal mesh routes and reuse expiring checked passages. Delayed paths join current forward progress. Inclined body clearance, shoulder support, dense stopping-horizon checks and spatial/trajectory recurrence memory address slopes, cliffs, stuck loops and repeated dead ends.
- One survival decision table handles health, critical needs, forecasts and recovery. Both native need maxima are validated. Temporary recovery ownership respects saved settings, measures progress and releases on STOP. Coarse water discovery keeps refining during approach; tiny top-ups no longer repeatedly interrupt work.
- Hunting retains viable prey, smooths pursuit velocity, uses native gait speed estimates and cooldown-aware HP observation windows. Native bite dispatch temporarily clears unrelated shared reach targeting. HP decline remains an observation with unverified attribution. Prey-down must lead to real edible food and nutrition before a meal completes.
- Feeding falls through from a rejected virtual E API to paired executor keys. Generation keys use actual object references and body/profile changes; expired model exclusions are pruned. Partial construction, STOP and late callbacks unwind owned work.
- Bounded accounting separates wall/active/pause/unobserved clocks, care phases, manual episodes, observed completions, currency inflow/outflow/net and unattributed rates. COPY STATUS includes encountered partial/unknown profiles, gait/mode seconds, local operation counts, coordinator percentiles and opaque native helper costs.

## Hippo ability speed

The prior cap-only change did not alter the captured v2412 controller's forced-trot calculation. Read-only inspection of the user-provided capture found:

| Native contract | Evidence |
|---|---|
| Active FeralCrushAt clears requested run and forces trot | WolfController prototype 186, words 2394–2402 |
| Forced branch consumes 16.8 / 42 × Species.scaled(species, gait, growth) × walk multiplier × speed scale × input magnitude | Same prototype, words 3092–3104 |
| Ordinary sprint consumes Species.scaled(speed) and NeedsConfig.RUN_SPEED; Burst settings come from NeedsConfig.BURST | WolfController original config imports and speed branches |
| Species gait is a numeric native scalar | Captured Species scaling consumer; not a speed-mode table |

The reversible Hippo-only Species.scaled lease adapts the actual consumed scalar to the requested native sprint/Burst tier for Shift/X, including native swimSprint and water Burst multipliers. Walk/trot pass through. Native denial, StaminaOut, capture, menus, Rest, ability timing and configuration ownership are guarded. It restores on animal/profile change and unload; external edits are preserved. No Humanoid movement-field, transform, ability timestamp or raw gameplay-remote writer is introduced.

Captured bytecode SHA-256 fingerprints: WolfController `7ed422d081bac217084eda4fd6c3699a17973434dad31a52ee2688ed23903ccb`; FeralHippoClient `65290350eb0d9cb373049d9b3a23fed4bd9a10ef26be8b276c9c381e241d2f12`; Species `850dfabd0bbf3d14089cb1391e3751b66c2746ddd12b9acd0e054baaf7824aa0`. Raw private capture/disassembly is not included or executed. Nine new core cases cover the native arithmetic, input, land/water, denial, intent continuity, external edits and restoration. This is a source-grounded client correction; server-accepted speed is live-unverified and later game versions are not adapted blindly.

## Verification

| Gate | Result |
|---|---|
| Official Luau revision | 97b2f4bf9cd935bed666f3e643a3b749b4d22f38 |
| Territory suite | 263 / 263; 24 compile targets; 12 historical artifacts protected |
| Retained core + Hippo suite | 202 / 202; 26 embedded modules; source parity and rollback guard |
| Complete integrated simulation | 7,200 simulated seconds; five prey-down sequences, twelve meals, thirteen drinks, one claim, thirty-seven scents; no manual intervention or starvation |
| Fixed paired region fixture | 3,276.8 → 2,428.3 studs, about 25.9% less |
| Fixed paired deadline fixture | 50.83 → 30.83 simulated seconds against a 40-second deadline |
| Live gameplay/retention/Amber per hour | Unverified |

The two-hour fixture is a small two-hex simulated world with finite edible corpses and new prey, not a full live-map soak. The paired comparisons isolate strategy mechanisms; neither establishes universal efficiency or yield. Existing tests remain; the late-HP fixture observation time was extended to match the now cooldown-aware pending window. The earlier apparent listener leak was a fixture accounting error: cleanup correctly preserves the native game's own listener baseline.

Hub bundle SHA-256: `d54b1b1e94849a5e4c41947a2ce659e35f6ddf22591aa75b3e4288a15e5ed8bb`. Territory bundle SHA-256: `18949113ea36458a2db37581cfdfa458f53a28923580ad45afbb3566acd4ad74`. Exact source SHA, normal launcher pin and historical rollback are in [release.json](../../renaissance/release.json). Both GitHub Actions gates validate the published PR/main tree; their native run records provide publication evidence.

## Supported scope and incomplete requirements

| Capability | Current status |
|---|---|
| Known native diet, ground movement, ordinary hunting/feeding/drinking | Implemented; bounded simulation coverage; live acceptance unverified |
| Configured surface swimming | Implemented; partial transition coverage; live banks/exits unverified |
| Unknown species | Explicit UNKNOWN; no blanket swim capability assumption |
| Native climbing, autonomous flight and depth navigation | Unimplemented; native active modes yield movement |
| All-map sustainable capacity / overload policy | Known currently due deadline pressure only; full steady-state model incomplete |
| Measured device performance and repeated live efficiency | Instrumented but uncalibrated/unverified |
| Territory reward or individual damage attribution | Unknown unless independent native evidence exists; balance/HP changes remain observations |

## Launch and rollback

Normal complete launcher:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()
```

Territory starts disabled; open Territory and select START FARMING. Hide/tab changes keep it running. STOP/unload releases owned work. No automatic status upload is added.

Previous complete 15.6.2 / Territory 0.6.1 with Zoom Unlock:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/71051c5b707076f3a78080e745c649ae95ee4ae2/roblox-tools/feral-renaissance-v15.6.2.lua"))()
```
