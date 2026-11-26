# FERAL Amber Autopilot 0.7.0

Territory farming is now a permanent **Territory** page in Renaissance 15.7.0. The hub owns its window, scheduler, controls and shutdown.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-amber.lua"))()
```

Spawn, join a pack and select **START FARMING**. The engine starts disabled. **STOP FARMING** releases owned movement and feeding input. **Right Shift** opens or hides the main hub; hiding it or changing tabs keeps farming active. **SKIP TARGET** defers the current hex. **COPY STATUS** copies a local report and performs no upload.

The 0.7 update executes the Territory prep across scheduling, travel, survival, hunting, lifecycle and measurement. See the [release report](docs/V0_7_RELEASE.md), [44-item execution ledger](docs/PREPARATION_EXECUTION_LEDGER.md) and [62-scenario evidence map](docs/V0_7_SCENARIOS.md). Flight, native climbing, underwater routing, full-map steady-state capacity and live acceptance remain incomplete; the ledger retains those requirements.

## Farming behavior

- Enter the live configuration's region snake near the current animal and choose its useful orientation. Keep a short, revalidated local itinerary that uses priority, observed access cost and fairness. Tight measured scent slack can interrupt acquisition; report estimated due-work pressure without claiming full-map feasibility.
- Skip a hex occupied by a non-pack player and select another in the same coordinator tick. Nearby people do not cause a blanket pause. Packmates do not enter the contest map.
- Retain progressing, nearly completed territory work before routine care, then observe stable replicated completion before departure. Critical needs and genuine native interruptions still take priority.
- Hold sprint on travel, request eligible Burst on clear straights, and brake for corners and interactions. Confirmed sprint can upgrade to Burst immediately. Requests and observed native gaits are displayed separately.
- Check body-sized collision and shoulder support, use dense support checks within the stopping horizon, and prefer checked clear straights. Use checked long mesh routes and expiring passage knowledge beyond local obstacles; remember repeated recovery locations. Late paths rejoin forward progress. These finite checks cannot guarantee every fall is impossible.
- Follow moving NPC prey from behind, match approach speed with ordinary input, and stop to bite stationary prey when native attack geometry permits. Verify HP decline and abandon ineffective targets promptly. Only eligible NPCs are hunted.
- Drink to the native thirst maximum. Convenient offers interrupt only when thirst is below 82% and the last full drink was over 90 seconds ago. A manually interrupted or prematurely ended drink can restart. Food, water and hunts share one objective owner; territory resumes after care. Missing resources cause a search route when one is available.

Native Species/Forage configuration supplies diet and capabilities. Bear/Spirit Bear is covered by the fixtures; coat is display metadata. The framework supports ground and surface-swimming travel. Aerial routes, native climbing transitions and underwater navigation remain manual. Known configuration enables only partial support; COPY STATUS records bounded encountered profiles without promoting them to live-verified coverage.

## Verification

The pinned official Luau toolchain passes **263/263 Amber regressions** and **202/202 retained Renaissance regressions**. Both bundles have exact source parity; previous versioned bundles remain hash protected. Scenarios include native hub lifecycle, interrupted/full drinking, contested hexes, region ordering, stable completion, Burst acknowledgements, prey following, tree overlap and bounded stalls.

These are deterministic simulations and service mocks. **Current live FERAL travel, gait acceptance, NPC damage, feeding rates and Amber/hour are unverified for this release.** Configuration and local observations cannot independently prove server persistence or reward attribution.

See the [0.7 release report](docs/V0_7_RELEASE.md), [test results](test-results.json) and [static native contracts](docs/native-contracts.json). Previous [0.4 engineering evidence](docs/V0_4_RELEASE.md) remains historical.

## Modules

| Module | Responsibility |
|---|---|
| `planner` | Priority/time itineraries, region entry, scent slack, due-work pressure and unified care decisions |
| `ledger` | Exclusive run clocks, observed outcomes, currency and bounded profiling |
| `model` | Generation-scoped directed travel observations and checked passage graph |
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

The previous complete 15.6.2 / Amber 0.6.1 integrated bundle, including Zoom Unlock, remains unchanged:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/71051c5b707076f3a78080e745c649ae95ee4ae2/roblox-tools/feral-renaissance-v15.6.2.lua"))()
```

Earlier companion and core bundles remain hash protected. Historical rollout details are in the [0.5 report](docs/V0_5_RELEASE.md).
