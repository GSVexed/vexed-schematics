# V5 development checkpoint — 2026-10-11, 14:17 UTC

This checkpoint continues the original research. **No complete production module, sustainable net bonemeal/hour, or final V5 schematic is proven yet.** Existing schematics, mods and user worlds remain preserved.

## Actual new evidence

| Experiment | Actual observation | Interpretation |
|---|---|---|
| E048 | No physical clocked push; escaped water damaged controls | FAIL. A queued job and a valid schematic cannot establish function. |
| E049 | Clock did not actuate in isolated server; restart and true unload were exercised | FAIL. Initial harness lacked assertions and incorrectly emitted PASS; result was explicitly adjudicated and harness repaired. |
| E051 | Repeater facing property identified its input orientation; revised circuit made two pushes, then stalled | FAIL. Bonemeal/headspace/output clearance remained unresolved. |
| E052 | 80 trials, 76 fungus growths, 198 bonemeal used; 4,429 wart blocks inside nominal module, 347 outside; three leaking trials | An ordinary obsidian ceiling does not enforce the 16-block height requirement. Command resets/counts were used; no physical harvesting or farm profit claimed. |
| E053 | Two-output-cell drain produced two pushes and then stalled; real chunk unload confirmed | FAIL. Persistent moss carpet above seed prevented later effective doses. |
| E054 | Physical clock kept cycling; plant-clear wire received power but clearing piston never extended | Observation diagnostic. Replace indirect terminating dust with a directly aimed repeater. |
| E056 | Corrected plant-clear circuit: 16 physical pushes, 17 stone formations; zero observed water loss or cobblestone; 100 bonemeal consumed during 9,600-tick phase | FAIL against continuous-operation assertions. Second output vegetation blocks further conversion; bonemeal input is external. |
| E057 | Two headspaces now have separate positively powered pistons | Execution in progress; no result assumed. |
| E055 | 48 samples per sea-pickle/nylium/moss-height case, first compost-layer control, and 120-second physical hopper-composter throughput | Execution in progress. First launch failed before Minecraft due to embedded Python import isolation; repaired and recorded. |

Fungus E050 without an active player paused at 60 seconds and completed only 20 growths. Its apparent lack of leakage is **inconclusive**, not evidence of roof containment. E052 adds an active Carpet fake player and confirms it survived through the test.

## Testing improvements

A separate disposable Minecraft 26.2 runtime and world live under `%LOCALAPPDATA%\ChatGPT-PCLab\v5-engine\runtime-049`. Only runtime dependencies were copied from the legacy installation; no user worlds, account data or security settings were copied or changed. Backups of this new isolated world precede subsequent mutating experiments.

The versioned [engine runner](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_engine_runner.py) records every console command, real server observations, specification hashes, numeric assertions and bounded phases. It stops only the process it created. Minecraft 26.2 gamerules use namespaced snake-case IDs. Automatic empty-server pausing is disabled in this isolated runtime.

- Accelerated tick sprints prove mechanical game-tick behavior. Their elapsed milliseconds/tick are **not** normal 20-TPS performance measurements.
- Real-time runs record game time and tick-query output before/after; calculate rates from actual inventory deltas.
- Removing a forceload is insufficient by itself: an `execute unless loaded` probe must actually confirm unload.
- `OBSERVED` phases and `COMPLETED` observation jobs do not establish a working farm.
- Result JSON is committed permanently; detailed console/command evidence is also uploaded as workflow artifacts with 30-day retention.

## Candidate engineering decisions

1. **Moss, raised seed, burst refill and timed water wash.** Separate stationary seed from horizontally pushed stone. A raised seed may avoid inserting it in the refill plane. Test its actual scan depth before layout selection. Refill can stop safely against a fixed boundary if a subsequent growth destroys blocks in each piston lane. This needs measured recovery when any lane temporarily fails to convert.
2. **Crimson/warped nylium with water wash.** No stone or lava machinery, potentially multiple shallow layers. Determine Java 26.2 compostable drops per verified dose; community claims conflict between editions. Ignore nether sprouts requiring tools unless physical harvest actually recovers them.
3. **Coral/sea pickle.** No stone generator and dense item counts, but preserve the seed colony and prove compost return exceeds input. First-layer composter behavior can change a marginal ranking; investigate directly.
4. **Giant fungus at the actual world ceiling.** An ordinary roof has failed. The build limit could reject or truncate tall growth; test exact behavior rather than infer it. A ceiling-only design sacrifices vertical stackability and still needs playerless replant, physical harvest, nylium survival and Donut support.
5. **Biome-specific vegetation.** Investigate grass/wildflower/pink-petal water-harvest drops. Reusable soil could remove all stone machinery. Measure real drops, including seed chances and petal item counts; do not rank by visible plants.
6. **Passive crop or bone-producing route.** Retain as an independent comparator and potential recovery source. Server-specific virtual spawners need verified mechanics and capital-cost accounting before being considered production-module substitutes.

The composter model is pending a direct first-layer test. If the first layer is guaranteed and all following layers succeed with probability (p), expected homogeneous input becomes (1+6/p), not (7/p). Full physical throughput also includes the ripening wait, hopper cooldowns, congestion and inventory routing.

## Reproducible evidence

- [All versioned specifications](https://github.com/GSVexed/chatgpt-minecraft-testlab/tree/main/experiments/v5)
- [Permanent V5 result records](https://github.com/GSVexed/chatgpt-minecraft-testlab/tree/main/results)
- [E052 full engine log](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/052-20261011-v5-fungus-roof-active-control/minecraft-latest.log)
- [E056 result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5-056/result.json)
- [E057 and repaired E055 workflow](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38145888986)

## Donut SMP compatibility

**Unverified.** An independent Fabric/Carpet/TIS 26.2 runtime does not establish Donut backend equivalence. Public secondary reports describe non-vanilla hopper behavior and changing TNT support. Official rules and a safely isolated actual-server probe are required before reliance on those details. No current Donut hopper rate, TNT legality, redstone/entity limit or backend version is claimed.

## Next execution

Retrieve E057 and E055 actual results. If the stone cell cycles continuously, measure crop/item recovery and then expand to a wider pad; do not enlarge a failing cell. Execute controlled build-limit fungus and biome-vegetation tests. Use measured net return and physical bottlenecks to select full prototypes. The final module must include physical composting, recycle priority, surplus export, stop/backpressure and restart recovery inside 16³; shared shulker/storage/sell infrastructure remains external.
