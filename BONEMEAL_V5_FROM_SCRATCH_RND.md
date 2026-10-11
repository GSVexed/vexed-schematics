# V5 Research Programme — ORIGINAL design from first principles

Status: discovery and experimental validation. NOT a released farm.

## Mandate
User explicitly rejected an incremental reskin of the legacy V4. V4 is a modified version of another builder's design and is **only a performance benchmark**. Build genuinely original mechanisms, optimise every block in the entire 16×16×16 module envelope, and compare radically different architectures. The module must independently create net bonemeal surplus with local recycling; only shulker loaders, central storage, and the sell wall may be external.

### Objective function
1. Maximise **measured net bone meal per real hour at 20 TPS** in a single 16³ module, defined as output exported plus increase in all local inventory, minus initial bonemeal inventory, minus any externally inserted bone meal.
2. Avoid permanent stops at restart, interruption, full output, and chunk unload/reload.
3. Reduce milliseconds-per-tick, hopper/comparator/entity load, and total placed blocks per **1,000 net bone meal/hour**.
4. Remain legal and functional in Donut SMP, accounting for server mechanics (TNT duplication and chunk loading not assumed).
5. Module can share a global STOP bus and a bonemeal output conveyor but no mechanical timing required from neighbours.

## Alternative production systems to compare

**C1: Twin independent 7×7 moss pads per horizontal layer**
- Each growth source can convert close to a 7×7 stone area; test seed spacing and whether two pads fit inside the 16×16 chunk with generator/feed machinery. Do not assume pads fit physically until generator clearance is measured.
- Advantages: independent source timing, reduced shared clock dependency.
- Risks: piston and stone-generator footprint, access to lava/water, item pickup congestion.

**C2: Two-stage vertical moss conversion from one source**
- Use moss's vertical propagation target selection and deliberately controlled water/non-air scan to alternate between stone platforms above a single moss source.
- Experimental, not guaranteed superior; explore if extra vertical growth surfaces increase growth events per dispenser or reduce redstone volume.
- Compare with dual independent moss sources. Reject if timing/backpressure is more fragile.

**C3: Multi-layer compact sequential harvest with common composter feed**
- Use 16-block height for separated generation layers if there is enough room for stone creation, water flush, recovery and wiring, potentially two or three vertically stacked lanes.
- One module, one consistent output and independent refill loop. Do not assume adding layers improves per-block efficiency without measuring tick and compost capacity.

**C4: Unconventional alternate production**
- Consider bone-source/composter byproduct and plant mechanisms other than moss, subject to three conditions: fully automatic, positive/renewable net output, independently operable inside 16³.
- Mob farms relying on unbounded spawn spaces/spawners or an external fuel source are a different category and are not a comparable standalone module.

## Scientific comparison experiments

**E01 mechanics validation:** can a bottom-facing-up bonemeal dispenser trigger moss spread without occupying its growing-surface? Verify actual dispenser inventory decrement and adjacent moss conversion.

**E02 geometry/probability:** for repeated single-dose tests, compare conversion yield for unobstructed 7×7, 5×7 and other realistic pad shapes (30+ independent repetitions each; actual engine commands; capture counts not just PASS marker).

**E03 regeneration/timing:** build self-generating stone lanes and measure replacement delay and chance of cobblestone instead of stone after unload/restart.

**E04 compost capacity:** measure how many 8-game-tick hopper feeds and composter conversions are needed to sustain each growth frequency, avoiding a single bottleneck and return starvation.

**E05 net closed loop:** combine source, harvest, recycling, and output. Require collection rate, exact initial seed, all inventory deltas, and 72,000 ticks actual runtime at stable TPS.

**E06 resilience:** stop at random phases, remove/restore loading, fill output, empty inputs, induce lag; ensure the design restarts without manual intervention or losses.

## Go/no-go
- No use of another person's schematic as the V5 core.
- No throughput claim based solely on mathematical expectation, a command-constructed farm, or a structural pass.
- No Litematica promoted to recommended until actual engine proof for its exact hash and integration tests.
- Credit any outside physics findings or inspirations in final release, while making geometry, circuitry and testing original.

## Immediate evidence
- Verified V4 baseline: 4 moss seeds at (7,8,10), (27,8,10), (7,22,10), (27,22,10) in 36×29×18; 555/555 block-entity index matches. Its 487 hoppers include external shared transport and must not be naively divided by 4.
- Minecraft wiki explains 7×7 moss conversion, above/below scan and need to clear vegetation. Rough theoretical 2.5–3 bone meal return per one invested in ideal conditions is NOT actual throughput. Reference: https://minecraft.wiki/w/Tutorial:Bone_Meal_farming
- Observed competitor concepts (for inspiration ONLY): recent single-chunk layered moss build with per-module composters, source: https://www.reddit.com/r/technicalminecraft/comments/1vj0g3m/fast_maintainable_and_expandable_mossbonemeal_farm/ ; note reported overall footprint 18×17, not strictly 16×16. Our design is independent.
- Timing pitfall worth testing: dispenser fires after several game ticks, while pistons actuate sooner; requires sequencing, source: https://www.reddit.com/r/technicalminecraft/comments/1vfaa8p/my_dispenser_wont_dispense_bone_meal_into_moss/

Goal: design the world's best *for the user's constraints*, not claim a world record without comparison and measured evidence.

## Experimental record — 2026-10-11 (all local Minecraft Java 26.2)

The following test jobs executed on the user's PC through the recovered Minecraft TestLab, not simulated in the assistant. Trials are **growth only**: temporary stone platforms regenerated with test commands, so they are *not* sustainable farms or measurements of bonemeal profit.

| Test | Setup | Doses | Stone converted to moss | Mean converted per dose | Outcome |
|---|---|---:|---:|---:|---|
| E01 | Upward-facing dispenser under source moss | 1 | Adjacent moss confirmed | n/a | **PASS**, confirmed dispenser consumed bonemeal |
| E02a | 7×7 flat stone pad | 8 | 216 | **27.00** | PASS |
| E02b | 5×7 flat stone pad | 8 | 182 | **22.75** | PASS |
| E03 | 5×5 flat stone pad | 12 | 265 | **22.08** | PASS |

E01 [result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/035-20261011-v5-bottom-dispenser-moss/result.json) and [log](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/035-20261011-v5-bottom-dispenser-moss/minecraft-latest.log).

E02 [result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/036-20261011-v5-moss-pad-geometry/result.json) and [log with per-trial scoreboard totals](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/036-20261011-v5-moss-pad-geometry/minecraft-latest.log).

E03 [result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/037-20261011-v5-compact-five-square/result.json) and [log](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/037-20261011-v5-compact-five-square/minecraft-latest.log).

**Interpretation:** the 5×7 experiment used 35/49 = 71.4% as many stone-pad cells as 7×7 and produced 22.75/27 = 84.3% as many moss blocks per dose in these eight-trial sets. The 5×5 result is promising at 25 cells but has high small-sample uncertainty; do not rank architectures from these rates alone. Every trial re-created stones using Minecraft console commands, so stone-generator footprint, collection efficiency, moss vegetation drops, composter throughput, and net bonemeal production have **not** been tested here.

### 16×16 horizontal layout budget study

The [first-principles space layout script](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_layout_candidates.py) independently analysed five candidate arrangements, validated non-overlap and chunk bounds, and ran on the real PC [here](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38141318471):

| Concept | Pads/level | Pad cells in a 16×16 slice | Free cells |
|---|---:|---:|---:|
| Four 7×7 | 4 | 196 | 60 |
| Four 5×7 | 4 | 140 | 116 |
| Four 5×5 | 4 | 100 | 156 |
| Two 7×7 | 2 | 98 | 158 |
| Six 3×5 | 6 | 90 | 166 |

**Space packing is not a functional proof**. Specifically, theoretical four 7×7 pads leave extremely little lateral room for stone generation, composter input and collection hardware. Four smaller pads offer more room for the rest of the engineering, but require evidence that the stone supply and composter count can keep up. We must engineer/verify the full height envelope as well, not just 16×16 plan view.

Pending: E04 four simultaneous 5×5 pads in a single chunk; exact test manifest [here](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/jobs/038-20261011-v5-quad-pad-simultaneous/manifest.json).
