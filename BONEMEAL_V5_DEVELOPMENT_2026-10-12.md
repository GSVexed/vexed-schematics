# Bonemeal V5 development checkpoint — 2026-10-12

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

E129/P25 is currently submitted: [Windows run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38237804549), commit `726a091aa03d7519d4b52dc830fafda8bfc005ee`, fresh base [3952,80,2928]. P24 omitted the rear centre generator but left its row slot [7,8,13] open between two water sources; P25 closes this one slot. Whether that fixes cobblestone is unproven until server results arrive. Added water-leak monitors are disjoint from the other diagnostic command chain and included in rejection criteria.

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
