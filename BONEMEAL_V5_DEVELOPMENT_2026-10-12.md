# Bonemeal V5 development checkpoint — 2026-10-12

**New acceptance:** [Master directive](V5_MASTER_ENGINEERING_DIRECTIVE_2026-10-12.md) replaces manual-OFF final operation with arbitrary-phase RUN-unload/restart recovery. Moss leads; benchmark the original single module. E143 passed a repaired stacked component (+33 net), with supplied sequencing; no complete/hourly/RUN-unload claim. See the updated [ledger](V5_EXPERIMENT_LEDGER.md) for the next gate.

## Current result and scope

P23 is the preserved, sustainable 16×16×16 baseline. Its exact schematic was reconstructed from decoded file bytes in Minecraft Java 26.2 and measured in E123. It is a modest prototype, not the final A-tier design. Native Litematica client paste and live Donut SMP equivalence remain unverified.

- [Exact tested schematic](prototypes/v5/Bonemeal_V5_P23_Baseline_Prototype.litematic); SHA-256 `a2a9534f4141572d4c0497f83cc4684748c8dd43bde91e0d581b5564bb4af39b`.
- [Operating notes](prototypes/v5/P23_BASELINE_NOTES.md).
- [E123 exact-file evidence](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/123-exact-schematic-p23.json): **+106 net bonemeal in 72,002 game ticks**, 305 growth doses, 411 gross compost outputs. Actual normal-speed 300.003 seconds / 6,000 ticks: **+9 net**. Count seed once across all internal inventories, carts and external witness output.
- Actual manual OFF, settling, saved restart, witnessed true unload, OFF reload, RUN and continued export passed; no monitored cobblestone or lost generator water. Cleanup parked.
- 624 non-air blocks; 43 hoppers and seven positioned rail carts; 59 block entities. The output witness barrel at local [7,0,16] is external.
- [E124 exact-file congestion and seed evidence](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/124-exact-schematic-congestion.json): full external and internal output held clocks stopped through restart and true unload. Draining only the external barrel resumed production. Zero seed remained stable; reprime 128 yielded 163 after 28,804 ticks (+35). Fault-injected stock is never production.

## Opposed generator experiments

[E125 trace](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/125-opposed-power-trace.json) located a water seal above a rising wire that blocked the old proposed layout. Relocating the generator banks by one Z block preserved the known working clock clearance.

[E126 corrected component](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/126-opposed-corrected.json) harvested and autonomously regenerated all 35 cells through twelve controlled moss cycles, with no cobblestone or lost water. Its original FAIL is preserved: an invalid arbitrary piston-activity threshold rejected a full pad, which appropriately stops pushing. Adjudication is recorded, not rewritten as autonomous farm proof.

[E127 component recovery](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/127-opposed-recovery.json), COMPONENT_PASS: twelve cycles, actual saved restart and true unload, then a new growth/wash/automatic-regeneration cycle. Collected 247 moss, 25 carpets, 15 seeds, 11 azaleas and 11 flowering azaleas in the twelve-cycle phase; after reload the new cycle collected another 16 moss. Growth and wash pulses and seed were supplied; 35 static pickup carts were a measurement fixture. No integrated net-farm claim.

[E128 complete P24 integration](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/128-integrated-p24.json), FAIL: two rear generators renewed former odd support lanes, raising productive cells from 20 to 30 with nine carts, full local recycling, export and stop controls. At 24 simulated minutes net was +49, but cobblestone was detected and rear piston activity stalled (132 at eight minutes, only 138 at 24 minutes). Hour and normal-speed phases were correctly skipped; OFF cleanup preserved the fixture. Initial positive output does not validate the added feeds.

[E129/P25](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/129-integrated-p25.json) failed: the centre seal eliminated monitored leakage, but cobblestone persisted; at 24 minutes net was +47 and rear pushes stalled. The seal was not the root-cause fix.

[E130 first-fault trace](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/130-integrated-fluid-trace.json) captured cobblestone at both rear targets while their source water and falling lava remained intact. Cobblestone subsequently filled the five-cell growing lanes.

[E131 rear pulse delays 2/3/4](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38239147786) all failed with cobblestone. The front fast clock remained six items. P26/P27/P28 ended +52/+57/+55 at 24 minutes, but fluid faults invalidate them as candidates. This rear-feed integration/timing branch is now shelved; do not run further timing variations.

[E132 nylium plunger](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/132-nylium-plunger.json) is a different fungus mechanism: lift/retract the soil itself rather than sideways stem transfer. Eight-cell mechanical controls with 1/5/10 supplied stem blocks all passed. Actual first seeded fungus/growth/TNT cycle restored eight soil blocks and all gaps; the second cleared the gaps but lost one nylium. Overall FAIL preserved, two actual fungi, eight bonemeal removed, two supplied TNT.

[E133](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/133-nylium-soil-restoration.json) inspected that same saved pad: the lost soil was netherrack, not an air hole. Physical side bonemeal dispensers restored the soil; all eight continuation cycles passed. Five fungi grew, 54 bonemeal was removed. Passed controls and initial construction were skipped. This is soil/movement evidence, not net or autonomous farm proof.

[E134](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/134-fungus-harvest-net.json) added real washing, hopper pickup and composting, but a bucket entered collection and was not returned. Original negative net is preserved with a collector-fixture adjudication.

[E135](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/135-fungus-guarded-wash-net.json) reserved waterloggable source cells. Both buckets returned in all eight cycles. Two fungi grew; 42 bonemeal removed, 2 recovered in actual composted inventory: **net -40**, with 83 wart blocks still standing. This eight-target seeding/single-TNT harvest layout is shelved; do not extrapolate this partial harvest into a verdict against all fungus architectures. The nylium-movement component remains proven.

## Current different architecture: corrected P30 passive melon module

| Evidence | Actual result | Decision |
|---|---|---|
| E136 / P29 exact file | 132 stems and hydration survived; no meaningful harvesting or output after 24 simulated minutes | FAIL preserved. Long benchmark skipped; do not rerun this file. |
| E137 saved-fixture trace | Clock ran and 98 melons stood, but the downstream harvest pulse stayed disconnected | Diagnosed a missing direct pickup wire; no crop-growth retest needed. |
| E138 controlled saved-fixture repair | Add the missing wire and restore 36 altered rail shapes. Both carts visited all 22 field rows; both decks harvested; 56 bonemeal reached external output | Repair evidence only. Existing standing melons make this a transient, not an hourly production result. |
| E139 / P30 fresh exact file | PRELIMINARY_PASS: +149 net / 72,002 GT and +16 / real 300 seconds at 20 TPS; physical restart/unload and congestion/drain passed | Working alternative, not final winner; exact bytes preserved. |

P30 consumes no fertiliser in steady operation and requires a nearby player for natural random ticks. The run generates a new schematic, preserves cart startup Motion, and builds only from decoded exact bytes. Rail shapes are placed with strict mode because ordinary sequential block updates rerouted P29's return curves. This setup is explicitly **not native Litematica or practical survival rail-placement acceptance**.

The fresh-file test rejects unhealthy warm-up before a 72,000-tick production hour, a real five-minute measurement, actual manual OFF/restart/true unload/RUN, and full-output/external-drain scenarios. Fault-injected bonemeal is excluded from production.

[E136 failure](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/136-passive-p29.json) · [E137 trace](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/137-saved-p29-trace.json) · [E138 repair](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/138-saved-p29-pulse-rail-repair.json) · [E139 Windows run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38249096042) · [P30 builder](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_module_p30_builder.py)

## Closed additional crop: E140 small-plant nylium economics

This differs from the shelved giant-fungus layout: do **not** grow fungi into trees, use TNT or pay giant-growth/soil-repair costs. A fresh 7×7 static crimson-nylium pad receives 32 single real dispenser doses from a finite 64-bonemeal stock. Seven guarded water sources harvest the small plants into a physical hopper/composter/export chain. No crop resets or inventory conversion/replenishment occur between cycles.

Tutorial literature labels profitable nylium-only farming Bedrock-specific, so this is a **bounded Java economic rejection screen**, not an assumption of viability. Reject an uneconomic fully functioning collector before engineering autonomous recycling. If collection/soil/water fails, record a fixture failure rather than a crop verdict. Provided control pulses do not establish an autonomous farm or hourly throughput.

**E140 complete: NET_SCREEN_REJECTED.** All 32 real single-dose/harvest cycles passed: 233 plants generated, every wash cleared all 49 cells, all seven buckets returned, nylium intact, no remaining loose item drops. 32 bone meal consumed, 22 physically recovered, **net −10** after drainage. This root-only Java route is closed; do not scale it or retest merely with a full controller. [Result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/140-nylium-small-plant-net.json).

## Current next test: E141 / P31 vertical moss fields

A different complete-crop geometry is now under a component test: two 35-cell stone/moss fields at local Y4/Y12, with raised sources Y6/Y14, **one moving cart per field**, a shared physical 48-GT generator clock, a merged hopper/composter output, and all blocks inside 16³. The expected five-block moss search should exclude the other deck; only the actual engine trial can establish that separation.

This is not a further P24–P28 hybrid rear-feed timing permutation. It uses the standalone dense field's proved mechanical geometry, vertically separated, replacing the old 35-carts-per-field measurement fixture. New questions are cross-deck growth, full-layer fluid renewal, moving pickup, and actual net after composting. Supplied finite seed and clear/grow/wash pulses are explicitly component controls; autonomous sequencing, recycling, boundary export and full stop remain absent.

A fresh exact component schematic is generated and decoded before placement. Four lower-only, four upper-only and eight dual-deck cycles reject failed geometry before complete architecture work. No timing sweep is scheduled. [Builder](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_module_p31_builder.py) · [Test](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_stacked_moss_probe.py) · [Windows run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38253508815). **Inspect E141 before making another task commit.**

## Keep these decisions

- Retain the tested fast 48-game-tick generator option. Do not reopen the failed automatic lava gate. Manual OFF and 480 ticks settling before unload are the accepted operating procedure.
- Never derive hourly net production from growth-only yield, structural checks, short transients or external fault-injected inventories.
- Keep P23 exact bytes immutable. Do not reuse old running/unloaded fixtures; paste new variants in fresh isolated areas with backups.
- Dense dry honey integration is shelved after repeated failures. Reopening it without a new component result is not justified by the user's usage budget.
- Giant crimson fungus remains a separate candidate: seeding/growth and one-cell physical root removal passed components, but full-pad autonomous harvest, collection, TNT supply, net yield, all-block 16³ containment and Donut compatibility remain unresolved. One-cell seed efficiency cannot be credited with whole-pad yields.
- Normal hopper pickup beneath soul sand, mud, honey, farmland and bottom slabs passed controlled collection tests; rail carts also retrieve through stone. Collection choice must match actual growth/regeneration geometry, not an isolated pickup result.
- Share local analysis and Windows testing efficiently. Preserve simultaneous Club Sana work by using fresh GitHub HEAD leases and only the owned V5 Java process/runtime.

## Remaining acceptance

Winning architecture and exceptional production are not established. Still required: repeatable integrated performance, interruption-phase sweep, two/four-module idle-relative TPS measurement, native Litematica import/paste, live Donut rules/mechanics verification, then shared shulker loading/storage and one central sell wall. Do not claim these complete.
