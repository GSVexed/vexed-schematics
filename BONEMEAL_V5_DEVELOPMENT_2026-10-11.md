# V5 development checkpoint — 2026-10-11, 16:15 UTC

**No sustainable complete V5 module or released Litematica is proven yet.** This is an active engineering record. Isolated engine experiments and versioned 16³ prototypes are real; prototype checks and queued jobs are not functional proof.

## Current user decisions

- Preserve every existing schematic, mod, working system and user world. New work uses a separate backed-up test world.
- Explore original architectures, including giant fungi; V4 is a benchmark only.
- The user specifically highlighted hopper-minecart placement and partial-height pickup blocks. E068 tested this rather than assuming a mechanism.
- **Speed remains a priority.** E063's 48-game-tick generator is still a candidate under a tested manual shutdown procedure. The user accepts turning the machine off before unloading/leaving it. Accidental live unloading is a known failure of that variant, not concealed.
- **E066 lava shutoff is shelved.** Do not spend more usage repairing that branch. A slower baseline does not select the final production speed.
- Keep experiments bounded and inspect real failure traces before another layout change.

## Verified component evidence

| Experiment | Measured result | Scope and decision |
|---|---|---|
| E057 | 100 pushes/101 stone formations over 9,600 ticks, then 10 after saved restart and 20 after confirmed unload; total 130 pushes/131 formations; zero observed cobble or lost water | Physical 96-tick primitive PASS. Externally supplied bonemeal, no compost/recycle. |
| E059 | Stationary rail cart captured 98 moss, 12 carpet, 3 seeds, 2 azalea and 1 flowering azalea after 100 cycles; moss reached 128 after restart/reload phases | Pickup through the field is physically proven. Overall harness FAIL was a slot-zero seed count mistaken for moss; retain failure plus adjudication. No cart was pushed into another block. |
| E063 | 48-tick primitive completed 100 initial pushes and 10 after restart; after confirmed unload it made cobble and stalled (114 pushes, 113 stone formations) | Fast operation is real. Live unload recovery failed. The exported count 1,068 is invalid: a temporary score was not reset for unmatched inventory slots. |
| E066 | 251 clock/piston cycles across the test sequence, but only the initial stone and zero exported moss | Lava-shutoff prototype FAIL. Moving pistons and cobble-free empty operation do not prove generation. Shelved. |
| E068 | Ordinary hopper: 64/64 items through soul sand, mud, honey block, farmland and bottom slab; 0/64 through stone or chest. Rail cart: 64/64 through stone, soul sand and air. Water channel: 64/64 | Externally supplied component PASS. Use water-to-hopper pickup where it fits; cart through stone remains an option. |
| E068 | Water-bucket dispenser comparator signals: contained 2, released 1, recovered 2 | Actual usable water-state sensor; a level-2 comparison can select dry growth. |
| E055 | 256/256 first wheat seeds advanced empty composters to level 1 | Guaranteed first layer verified. Expected homogeneous input is 1+6/p, not 7/p. |
| E061 | Observer dropper clock measured 402 rising edges in 120 seconds; ordinary hopper/observer-fed wart columns output 30/34 bone meal, pumpkin pie 33/40 | Actual supplied component capacity; observer period is 6 ticks. Short moss difference is not a statistical conclusion. |
| E062 | Attenuated comparator clock measured 603 rising edges in 120 seconds; hopper/dropper outputs: moss 24/41, wart 28/45, pie 33/50 | A measured ~4-tick dropper feed. Faster compost feeding is promising, not a farm-production result. |

See [permanent results](https://github.com/GSVexed/chatgpt-minecraft-testlab/tree/main/results), [specifications](https://github.com/GSVexed/chatgpt-minecraft-testlab/tree/main/experiments/v5), and [versioned scripts](https://github.com/GSVexed/chatgpt-minecraft-testlab/tree/main/pc-lab).

## Alternative production routes

E055 independently sampled 48 trials per case. The first 5×5 pickle trial consumed no bonemeal and is excluded from its verified sample; the raw aggregate FAIL is preserved.

- Sea pickles: new-pickle means 4.383 (5×5, verified n=47), 4.792 (7×7, n=48), 5.354 (9×9, n=48).
- Ordinary crimson/warped nylium drops: approximately 7.21–7.42 compostable roots/fungi per dose in the sampled 5×5 and 7×7 pads. These samples do not support a positive closed-loop return.
- Moss 7×7: mean 26.75 new moss at field-level seed, 26.646 with seed raised 2, 23.979 raised 4, and zero raised 6. These are command-reset growth samples.
- E060 biome water-harvest samples remain **preliminary**. Residual cross-case item contamination and a missing basin wall prevent using them to select or rule out a biome architecture. Do not silently promote the cherry/meadow counts to farm profit.

### Giant crimson fungi remain a challenger

E058 ran 64 trials in each of four conditions, with command resets and block counts:

| Nylium placement | Bonemeal used | Wart blocks inside 16-height region | Outside warts | Leaking trials | Nylium lost |
|---|---:|---:|---:|---:|---:|
| Y80, open | 128 | 3,723 | 289 | 3 | 0 |
| Y80, obsidian roof | 158 | 3,335 | 443 | 5 | 0 |
| Y304, actual world limit | 150 | 3,719 | 0 | 0 | 0 |
| Y308, actual world limit | 158 | 3,106 | 0 | 0 | 2 |

Y304 provides a genuine geometry clue: 58.11 wart blocks/growth, 2.344 bonemeal/growth in these samples, no observed leakage or nylium loss. **This is not net bone meal or a farm.** Playerless seeding, actual destruction, collection, composting, repeatability and Donut permission remain unproven. A build-limit layout also cannot vertically stack.

Primary research reference: [ncolyer's huge-fungus experiments and code analysis](https://techmcdocs.github.io/pages/GameMechanics/HugeFungi/). Engine tests supersede historical assumptions about the build limit.

## Integrated original prototypes

[P01–P04 manifests](https://github.com/GSVexed/chatgpt-minecraft-testlab/tree/main/prototypes/v5) specify all blocks, inventories and cart coordinates inside a chunk-aligned 16×16×16 volume. Existing prototype areas are preserved; each revision uses another isolated chunk. No V4 blocks or geometry were used.

- P01/E072, P02/E073 and P03/E074 retained 128 startup bonemeal after 28,800 accelerated ticks, fired no growth doses and made one main piston extension. **FAIL, net zero, no sustained production.**
- The initial diagnosis of a clock stall was wrong. E075 observed transferring hopper inventories, moving redstone positions and changing piston phases. A blocked main piston does not establish a stalled clock.
- Builder and console inspection identified unsupported water-sensor comparators. They broke, so growth could not trigger. The full-buffer sensor also lacked support.
- P04/E076 lowers the source into the washable field plane, explicitly supports all diodes, and routes the growth delay/reserve under the field. Its comparators survive and show expected output. It still fired no automatic growth doses over 28,800 ticks. **FAIL.**
- E077/E078 control traces measured cycling clocks, a self-powering push bus, discontinuous diagonal wire paths, failed glass-supported descents, and water washing away an elevator wire. One explicitly command-powered dose converted 17 cells; this is a mechanics probe, not autonomous production.
- P05/E079 corrected those paths and seals. Over 28,800 ticks it fired 61 automatic dispenser triggers but consumed no bonemeal, made one main piston extension and retained all 128 startup bonemeal. **FAIL, net zero.** The center bucket was empty while water remained in the field, consistent with the three sources replenishing one another. Trigger counts do not establish successful growth.
- P06/E080 is testing one water source with the **48-tick push clock**, a correspondingly faster harvest clock, diagnostic pulse/field counters and the user-approved manual OFF/settle/restart/unload protocol. Results are pending; do not claim a rate or working shutdown.

These failures are retained as evidence. The module's intended generation, collection, composting, recycle and surplus blocks do not mean it works. No net bone meal/hour is claimed.

## Benchmark discipline

The [isolated engine runner](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_engine_runner.py) journals setup, mutations, console responses and timing. The [integrated test](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_module_p01_test.py) reads every inventory by item identity and subtracts the 128-item startup supply.

- Tick sprints establish game-tick operation; their speed/MSPT is not a normal-TPS measurement.
- Real-time runs measure actual inventory deltas, game ticks and wall time.
- Long tests, restart/unload and throughput comparisons are skipped while basic operation fails.
- No commands replenish stone or bonemeal during an integrated benchmark.
- Component inventory measurements must reset temporary scores for every filtered slot, or use typed real-inventory snapshots.
- Keep explicit FAIL, ERROR, observation-only COMPLETED and preliminary functional results distinct.
- Final validation still needs exact schematic paste, 72,000 game ticks, full-buffer stop/resume, empty seed, interrupted harvesting, two/four modules, and external shared infrastructure.

## Donut SMP

**Not verified.** Public server status, rules and actual server mechanics require their own evidence. The official support page links rules.donutsmp.net, but the rules endpoint is not retrievable in the current search environment. Secondary reports of batch hoppers and altered redstone/TNT behavior are leads only. Vanilla hopper clocks cannot be declared Donut compatible.

## Immediate next work

Retrieve P06/E080 actual results. If a sustained surplus is established, compare slower/faster clocks and complete longer normal-TPS, shutdown and congestion tests. If it fails, follow typed inventories and physical control/field counters. The faster generator remains eligible with manual OFF before unloading; E066 lava shutoff remains shelved. Keep giant fungi as a separate challenger.
