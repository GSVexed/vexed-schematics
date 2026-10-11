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


## Verified continuation — 2026-10-11 18:40 UTC

P09 is the first sustainable fast autonomous baseline, not the final A-tier design. E088 returned PRELIMINARY_PASS in the isolated Minecraft Java 26.2 lab. The complete original module fits a chunk-aligned 16×16×16 cube, recycles its own bonemeal and exports surplus.

- One-hour phase: +87 net bonemeal over 72,002 measured game ticks, with no external replenishment.
- Normal-speed measurement: +12 net bonemeal over 300.055 seconds / 6,001 game ticks, approximately 20 TPS.
- Actual manual lever OFF, settling, saved server restart, witnessed true chunk unload, reload while OFF and manual RUN all passed. No cobblestone or lost-water fault was observed.
- Fast generation remains included under the user's accepted manual OFF-before-unload operating procedure. The unsuccessful automatic lava gate remains shelved.
- This output is modest. No A-tier, optimality, Donut compatibility, exact Litematica-paste, multi-module or final-release claim is justified yet.

Evidence: [E088 full result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/088-integrated-p09.json), [actual PC run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38159860775), [P09 manifest](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/prototypes/v5/p09-module.json).

E085 showed moss carpets obstruct both conversion and source fertilization, so a faster dry harvester must clear them. E087 demonstrated vertical honey/slime harvest and stone return, but collection was incomplete. E090's hopper-under-honey trials had partial pickup and a reset flaw: clearing old fixtures after killing entities could introduce drops into the next trial. Those collection totals must not rank architectures. E091 now uses a fresh isolated chunk and clears, settles, kills drops and asserts a clean reset before each of 16 bounded trials. [E091 run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38164945270).

The integrated harness cleanup is corrected to click OFF and settle before unloading a fast module. Previously the final cleanup unloaded it while running; therefore a saved P09 area must be freshly rebuilt before another clean benchmark.

Remaining work: select a materially higher-output architecture using uncontaminated mechanical tests; measure resource consumption and collection losses; full-buffer and empty-seed behavior; interruption phases; baseline and multiple-module load; actual Donut mechanics; exact Litematica creative paste; external shulker/storage/sell infrastructure. Existing prototypes and other concurrent PC projects are preserved.


### Follow-up experiment decisions — 18:52 UTC

E091 clean-reset test failed collection: the five-moss-cell strip collected 10 of 20 supplied moss blocks and 4 of 20 carpets across four trials. All 16 resets were verified clean. Mixed 2×2 trials collected all 8 supplied moss blocks, but that does not prove the all-moss worst case. E092 contained pickup follow-up stopped with a fixture error (power replaced a queried barrel); E094 corrects that coordinate and repeats the bounded test. Do not interpret the E092 error as mechanism failure.

E093/P10 shortened only the harvest clock from 15 to 8 items. It failed sustained production: net zero over the initial 28,804 game ticks, only one monitored generator push, and no moss present at snapshots. After switching OFF, a delayed growth consumed one bonemeal and produced moss. Reject P10. E095/P11 now tests the faster interval together with a shorter growth delay (10 affected repeaters, summed delay 64→36 game ticks); this is a test hypothesis, not a speed claim. Fresh separate prototype areas and pre-test world backups are used.

[E091 results](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/091-honey-hopper-clean-probe.json) · [E093 results](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/093-integrated-p10.json)


### Additional measured decisions — 19:00 UTC

E094 corrected containment test: four five-cell honey-strip trials collected all 20 supplied moss blocks and all 20 carpets; all carpets cleared and the five-stone strip returned all stones in 4/4 trials. Broader all-moss 2×2 case collected only 14/16 moss. Overall status FAIL, with a promising strip component subset; not an autonomous farm proof. E096 slime/cart five-cell strip collected 18/20 moss and 14/20 carpets, so its current collector does not qualify for dense mixed-material adoption.

E095/P11 restored actual growth with shorter delays, but net remained -8 bonemeal after 28,804 game ticks. Reject this variant as a performance improvement; hour and real-time extensions were skipped. E097 physical 32-GT ring made 200 piston cycles over 6,403 ticks but only 11 stone-regeneration events and 24 cobblestone-detection ticks, water retained. Reject that timing. E098 tests a 40-GT intermediate with 200 cycles. Do not replace proven 48-GT baseline until an alternative passes.

[E094](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/094-contained-honey-probe.json) · [E095](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/095-integrated-p11.json) · [E096](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/096-slime-cart-probe.json) · [E097](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/097-32gt-generator.json)


### Completed bounded timing sweep and next architecture

E098/40 GT failed: 5 pushes, 5 stone formations, 32 cobblestone-detection ticks, water retained, while the clearing piston still cycled 200 times. E099 fresh 48-GT positive control passed: 200 pushes, 201 stone formations including the initial stone, zero cobblestone/lost-water detections. This establishes that the fixture works at 48 GT and rejects the tested shorter timings in this geometry. E100 conditional Nether 32-GT test, using command-created water, failed: 3 pushes, 1 stone formation, 6,366 cobblestone-detection ticks and no water loss. No Donut or survival water-placement conclusion follows from that conditional test.

Ten PC experiments E091–E100 completed in this continuation, with failures and fixture errors preserved. The bounded sweep ends here. No lava-gate work was resumed. Stronger dry-harvest architecture is checkpointed with explicit collision and source-protection constraints, rather than falsely presenting it as a working farm: [dry-core design](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/prototypes/v5/dry-honey-core-design.json). It must become an actual synchronized autonomous module before production comparison or a final schematic release.

[E098 result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/098-40gt-generator.json) · [E099 control](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/099-48gt-positive-control.json) · [E100 conditional result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/100-nether-32gt-conditional.json)


### Dry integration — E101/E102/E103

E101 tested a downward-facing sticky root, normally extended as an immovable end stop for each generator lane. Removing root power pulls the five-cell honey strip upward through the moss surface; restoring power returns surviving stone and the end stop. Eight clean component trials passed: all four moss trials collected 20/20 moss and 20/20 carpets in total, lifted five honey cells, and cleared carpets; all four stone trials returned all five stones and restored the piston head. COMPONENT_PASS, not a farm. [E101 evidence](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/101-down-root-probe.json).

P12/E102 physically combined four such strips, the verified fast generator, automatic sequencing, four composters, bonemeal recycling, reserve control and local stop inside 16³, without minecart entities or harvest water. The first autonomous benchmark FAILED: only one fertilizer dose and four generator pushes over 28,804 measured game ticks, net -1 bonemeal, no observed cobble or water loss. No hour, real-time or recovery certification follows. Static geometry and support checks were clean, demonstrating why those checks are insufficient. Both master-clock hoppers were disabled with the manual lever OFF, and source-head clearing did not repeat. [E102 actual run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38168747083) · [E102 result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/102-integrated-p12.json).

P13/E103 separates the master-stop dust from the B comparator's powered output and adds a repeater in the long growth descent. The current bounded PC run uses read-only command-block edge counters on 20 control nodes, with no driver pulses or material replenishment during observation. It must establish actual repeating operation before a performance benchmark. [Trace script](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_dry_sequence_probe.py) · [Run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38169255759). P09 remains the sustainable baseline. E066 remains shelved; 32/40-GT generator branches remain rejected.


### Bounded dry diagnosis and collection benchmark — E103–E107

Read-only sequence traces are OBSERVED, not functional PASS. E103 confirmed the repaired master clock repeats (33 pulses in 10,006 game ticks), but growth and source clearing latched continuously and the pause path did not reach the lower lock. P14/E104 separated that feedback and repaired zigzag wire descents; 31 growth/source-clear pulses repeated, but there was no surplus and only one generator push. P15/E105 traced up to six field moss blocks and real compost increments; net -27 over 10,006 game ticks, with the pause signal disappearing after two events. Missing water floors/rear source walls were found in the new dry geometry: intact source counters did not detect spills.

P16/E106 sealed those water paths. All monitored leak locations stayed free of water, but all 20 honey cells remained raised for nearly the entire run, generator pushes stopped at one and net was -31. The integrated strip also has a stone cache adjacent to its first moving cell, absent from the E101 isolated trials. This creates a mechanical attachment/clearance concern even though the component passed. The dry layout is shelved; do not spend more usage on a complex cache shuttle without a separately compelling mechanism test. This does not reject every dry architecture or invalidate E101's narrower component result. No automatic lava-gate work was resumed.

P17/E107 is a controlled P09 collection variant with 20 rail carts below all 20 renewable field cells, carrying captured drops toward the same four composters. P09's fast clock, growth/water timings and real manual-OFF protocol are retained. The integrated harness now counts mature composter transitions as gross production, alongside typed total bone-meal inventory for net production. Cart positions are preserved in full evidence. P17 must complete actual sustainability, real-time and interruption tests before it can replace P09. [P17 builder](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_module_p17_builder.py) · [Manifest](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/prototypes/v5/p17-module.json).

[E103](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/103-p13-dry-sequence.json) · [E104](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/104-p14-dry-sequence.json) · [E105](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/105-p15-dry-sequence.json) · [E106](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/106-p16-dry-sequence.json).


### Collection and fungus continuation — E107–E112

P17/E107 failed before fertilization: rails overwrote existing reserve and seed-power controls. Its stationary cart positions do not establish production. P18/E108 now asserts every protected P09 control/support is unchanged and permits rails only at safe collection positions (14 carts). The hour phase produced +108 net over 72,002 ticks (413 gross compost increments minus 305 fertilizer doses), but the normal-speed 120-second phase produced zero net. Strict FAIL; do not report 108 as a normal-speed measured hourly rate.

P19/E110 retained the protected 14-cart collection and increased the wash-clock interval from 15 to 20 items. PRELIMINARY_PASS: +89 net over 72,002 ticks; +9 in 300.047 seconds / 6,001 ticks (~20 TPS). Manual OFF/settle/hold, saved restart, witnessed true chunk unload, reload OFF and manual RUN passed. No monitored cobblestone or water-loss fault. Output is comparable to P09's +87/+12 baseline, not an A-tier gain. Full-buffer, empty-seed, interrupted phases, multiple modules, exact Litematica paste and Donut behavior remain untested. [E108 result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/108-integrated-p18.json) · [E110 result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/110-integrated-p19.json) · [E110 actual run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38173453435).

E109 tested supplied fungus growth under unusual obstruction: all 48 growths succeeded across six eight-trial cases. Dense downward dispensers Y310 with a 9×9 obsidian roof Y311 above nylium Y308 yielded 369 wart blocks using 14 bonemeal in eight growths, with zero feeder or nylium losses. This proves the supplied growth interaction, not autonomous planting/harvest, complete footprint containment, collection, compost output or sustainable net production. [E109 evidence](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/109-fungus-overhead-feed.json).

E111 rejected the tested directly-below source/flow water geometry: no stone was observed at the target before or after pushing, and water was lost. The side-flow positive control formed, pushed and regenerated stone while preserving water. Keep the verified 48-GT side-flow design. [E111 evidence](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/111-water-under-stone.json).

E112 has actually started on the isolated Windows runner: four supplied growth/blast trials each for one, two and four TNT above the protected deck, plus an unroofed control. Counts wart blocks before/after real explosions, loose item drops, feeder/nylium losses and surviving root stems. TNT and growth inputs are supplied; drops are not inventory collection, composted output or net production. Pending actual result; do not infer harvest success from the script. [E112 source](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_fungus_blast_probe.py) · [E112 actual run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38175920766).
