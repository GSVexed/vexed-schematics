# V5 experiment ledger — resume here, do not restart research

## Latest checkpoint — E251–E256, 13 October 2026 (chat continuation)

**RESUME HERE.** The user's Work-mode project was transferred to the research bonemeal chat using the [exact transfer](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/0593c3d95c5f5b20996c2ca07836b93e84c839fa/results/v5/V5_CHAT_TRANSFER_2026-10-13.md). This is the same project, not a restart. E250 had failed; E251–E256 below were actually performed on the existing PC Minecraft TestLab. **E256 is the new highest-integrated native crop/recycling/export checkpoint.** Never rerun E250/E251–E256 unchanged.

| Evidence | Actual result, scope and decision |
| --- | --- |
| E251 / P36r24 | Fresh changed4-cycle screen rejected after crop2 (18/23STONE, five inner moss remaining). Removed E250's erroneous84GT inner signal, but output repeater/harvest measured0 ticks. Preserved [full evidence](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/251-native-isolated-inner-hold.pc.full.json.gz). |
| E252 | **Read-only saved E251** 512GT trace: comparator pair and loop wire each20GT HIGH per edge; repeater(3,15,7), entire descending route and physical inner output **0GT**. Signal lost at repeater. [Summary](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/252-saved-inner-route-trace.pc.summary.json). |
| E253 | Controlled WEST/EAST redstone-block injection on backed-up failed E251; originally used **strict** placement, so direction conclusion was withheld due missing neighbor notifications. Raw preserved. |
| E254 | Corrected normal-neighbor-update probe on same failed, backed-up fixture. Repeater at(3,15,7) **facing=east did not power when WEST side was stimulated; powered when EAST side was stimulated**, simultaneously powering top/upper descent wires. Therefore return the builder's repeater to **facing=west** for this exact signal orientation, while keeping the E251 isolated staircase away from(3,14,7). [Summary](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/254-saved-driver-updates.pc.summary.json). |
| **E255 / P36r25** | **Fresh 16³ exact-source native4-cycle PASS:** 4/4 growth, all23STONE/23AIR, seven guaranteed inner moss, exactly one charged dose each, four actual inner edges with **80 total high GT =20GT/edge**, no recorded crop faults, all23 lava buckets/one phase stone retained. Stock128→127BM over short transient; not sustainable profit proof. [Result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/255-native-inner-correction.pc.summary.json). |
| **E256 / saved P36r25** | **BOUNDED_NATIVE_CROP_PASS:** resumed the saved E255 RUN fixture with **no repaste, no extra bone meal, no clock/field/fluid reset**. **65 observed actual native growth events** over64×168GT samples /10,880GT; **all 65** had23STONE,23AIR,7 inner moss, exactly one charged dose, zero bad-stone/headroom/inner faults; inner driver65 edges/1,300 high GT (20GT each). Bone meal **127→174 (+47)** during continuation, +46 vs original128; final **source125, reserve40, external export8**,23 buckets and phase item retained. **First long native autonomous recycle/export PASS.** [Full result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/256-saved-native64-resource.pc.full.json.gz) · [summary](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/256-saved-native64-resource.pc.summary.json) · [Windows run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38410778035). |

**Current source:** `pc-lab/v5_integrated_controller_builder.py` now builds `P36r25-native-direction-correct-inner-hold168`,947 module blocks; E255 source commit `aea349f5662d42b9af114cefeb276d2481420107`. E256 run source `2b49509aae8369bcf0bee8252459d6b72b99f77f`; evidence-preserving HEAD advanced after it. Current saved WIN fixture is `%LOCALAPPDATA%/ChatGPT-PCLab/v5-engine/runtime-049/v5-isolated-world` at module base **(7616,80,3200)**; E255 fresh output `results/255-native-driven-inner-hold-pc`, E256 continuation output `results/256-saved-native64-resource-pc`. The owned server was stopped/saved; preserve old worlds and backups.

**Next highest-value gate (not submitted):** a **bounded true RUN chunk unload/reload** of this saved P36r25 fixture, with actual witnessed unload, no lever OFF/repaste/clock or inventory resets, and post-reload continuing positive native crop/resource/export. Preserve backup first and reject any unsafe state early. Then systematically widen the interruption phases, verify startup/native paste, and optimise throughput. **Performance is still far below the exact original SINGLE module +2501 net BM/72002GT (E147)**; E256's short accelerated result is not a real-hour rate. Arbitrary RUN unload, long20TPS/hour,2/4module scaling, Donut confirmation and final Litematica remain open. Keep the at-most-one P37 density challenger; no broad research restart or speculative lava timing sweeps.

## Historical checkpoint — E241–E250, 13 October 2026

**Resume the E250 inner-output coupling diagnosis; do not restart research or rerun unchanged baselines.** The project is not finished. P36r13 remains the independent resource/export lead: Windows E206 measured **+74 net bonemeal over64 supplied crop cycles**, source127/reserve41/export34. Those controls were supplied; it is not the autonomous production winner.

| Experiment | Actual result and limit |
| --- | --- |
| E241 | Saved wiring isolation restored distinct physical ports: growth84GT level; inner and outer harvest8GT pulses;84GT generator interval. Signal proof only. |
| E242–E243 | Initial bulb FALSE grew while lava remained above the field. Initial TRUE lets the native clock emit first, prime23STONE with empty source, then retrieve and grow. No command-supplied stone was needed. E243 exposed a missing physical repeater support; the two root-powered inner harvesters also required auditing at5GT rather than7GT. |
| E244 | Four native crop events passed:23STONE and23AIR before each, all seven guaranteed inner moss targets, exactly one charged dose each, one conserved phase item, physical fixture names intact.128→131BM (**+3**), source124/reserve6/export0. This short test did not prove sustainable recycling. |
| E245 | Saved read-only timing found the84GT source signal and complementary root utility held the recycle dropper triggered throughout1026GT. Delivery hopper had only24 enabled ticks. This identified a recycle bottleneck. |
| E246 | Upper controller OR branch shortened source growth power. Four native crops passed,128→131BM (**+3**), source125/reserve3/delivery1/export0. Actual delivery to the source resumed. This is not a64-cycle or real-hour pass. |
| E247 | Resumed saved RUN fixture without repaste/provision/reset. Native recycling retained source125; observed total160BM (**+32**), reserve35/export0. Rejected at35 observed growth events because only21/23STONE existed before a growth event. The full local raw file is currently inaccessible; the committed observed-summary explicitly states this limitation. |
| E248 | Actual Windows P36r22 test,929 blocks inside16³. Comparator hold change rejected at growth2:18STONE/23AIR, all7 inner targets, one dose. Five missing targets were still moss at local(6,6,6),(6,6,7),(7,6,6),(8,6,6),(8,6,7); no water/cobble in the fault mask. Total127BM, source126, no export. Full result preserved in Git, not merely an artifact. |
| E249 | Saved E248 read-only512GT trace completed. Both extender comparators actually20GT HIGH, but physical inner output/piston0 edges/0GT. Source6GT pulse, delivery82GT enabled per complete edge; phase1; BM127→129. Identified disconnected output, not a farm pass. |
| E250 | Windows driven-output change,941blocks, source21730cddb8a2d727b5ebffc8a59ed88bdfe89fe5. First crop rejected:16STONE/16AIR before growth,0inner/13MOSS,1dose; inner84GT HIGH rather than20GT. Total127BM/source127/16buckets. New dust4,14,7 touches strong positive controller obsidian3,14,7; suspected84GT coupling, not yet physically isolated. |


[E244 raw](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/244-native-supported-harvest/result.json) · [E246 raw](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/246-native-short-growth/result.json) · [E247 partial observed record](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/247-native-resource-resume/observed-summary.json) · [E248 full raw gzip](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/248-native-inner-hold.pc.full.json.gz) · [E248 workflow](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38403274938) · [E249 plan](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/249-saved-inner-extender.plan.json).

The five E248 targets are exactly the inner pistons that lack root-utility power. E249 measured the disconnected output; E250's new output picked up an84GT signal. Inspect/isolate the new wire4,14,7 beside strong controller block3,14,7 before another fresh crop test. Measure actual output timing. E247's rare incomplete harvest remains unresolved. Initial priming and native Litematica startup are still separate acceptance requirements.

**Execution recovery:** The chat's own temporary execution service returned409 `environment_offline` after E247 had stopped and saved its owned server. No exposed host restart/reconnect control was found. Connected GitHub and the Windows self-hosted runner remain operational: E248 ran on the PC. Source/results through E246 are durable; E247 has a clearly labelled partial observed summary; E248–E250 full raw records are durable. Use remote GitHub edits and backed-up PC execution rather than repeating failed local calls. No client/live-world/account/security changes.

**Remaining gates:** complete native resource/export run; optimize measured output against the exact original SINGLE benchmark; real-hour/TPS and material costs;>=100 varied full-module true RUN unload/restart trials plus lazy/loading/stock/output faults; native Litematica paste; Donut-specific verification;2/4 module scaling; external shulker/storage/sell infrastructure. No outstanding-performance or finish-date claim is justified by the short crop passes. All older “Next” entries below are historical and superseded by this checkpoint.

**Chat transfer:** The user requested a paste to resume this exact project in “research bonemeal project”. No further experiments are being submitted from this Work Mode thread. E250 completed; E251 has not run. [Authoritative transfer](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/V5_CHAT_TRANSFER_2026-10-13.md) contains execution paths, exact wiring cause, records and next step. Do not run two writing/testing owners at once.

## Historical checkpoint — E230–E240, 13 October 2026

P36r13 remains the independently tested resource/export lead: Windows E206 measured **+74 net bonemeal/64 supplied crop cycles**, source127/reserve41/export34. Do not rerun it unchanged. The connected autonomous controller still has no accepted crop/output result; the final machine remains unfinished.

- E230 rejected the first floor-growth route because the below-reserve export lock failed. E232/E233 recovered23STONE/23lava buckets but the short growth pulse recorded zero charged dose. E234's saved physical trace confirmed that the floor inverter reaches the source. Widening supplied growth to20GT/OFF8GT in E235 completed four crops, exactly one charged dose each, all seven guaranteed inner targets,23STONE regeneration and23buckets. Inventory128→130 (**+2 net**), source127→125/reserve5/export0. Raw overall status is COMPONENT_REJECTED because the short test wrongly required export below its42-item threshold. Preserve this as four supplied crop passes only; sustainable recycling, reserve and export on the new floor route remain unproved.
- E231/E236/E238 connected native fixtures all rejected empty-source priming **before bonemeal loading**. E237's actual signal trace found grow permanently OFF and update/inner/outer controls held HIGH despite an84GT physical clock and intact one-item phase. Saved-wire analysis found a repeater loop and three unintended wire joins; E238 isolated them.
- E238 reached a maximum16/23STONE, but failed safe priming. The saved field contained seven inner stones pushed up toY7; seven outer pistons were extended. Only16lava buckets remained in the dispenser inventories. These are a failed startup fixture, not production or a generator impossibility verdict. [E238 raw result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/238-native-feedback-isolated/result.json).
- E239 resumed E238 read-only: clock period84GT,7GT HIGH, one timing item preserved. Grow remained OFF, floor-negative stayed HIGH; north/east harvest remained HIGH for most of each cycle. Actual wire components joined grow to the reserve lock at6,2,2↔6,1,1 and9,2,2↔8,1,2; the growth descent also joined outer harvest at14,6,1↔13,6,1. Update joined reserve comparator dust via3,2,7/4,2,7.
- E240 backed up the exact owned chunk and entities to Git, then changed only29 wiring/support cells on that saved failed fixture, with expected-name/field/inventory guards. No field, stock or phase reset. Growth resumed with6GT pulses and north/east harvest returned to8GT pulses. The negative distribution still stayed HIGH nearly all the time; south harvest showed84GT HIGH. Two additional contacts were identified: the positive update repeater strongly powers block3,14,9 beside negative wire2,14,9; update descent1,6,14 joins south harvest1,6,13. This is causal signal work, **not crop/output proof**.

Next: E241 is prepared to move the negative spiral one block south and turn the south-west harvest corner one block earlier, then measure the physical ports. Keep the saved failure intact; zero-bonemeal dry harvest pushes unconverted stone up into the dispenser roof, so do not mistake that startup protocol for a valid complete-farm rejection. Once signals are correct, use a fresh fixture with an explicitly counted initial stone field, an OFF growth phase and128BM loaded once before starting the clock; no continuing field/item/phase resets. That initial setup is not native Litematica paste acceptance.

Current sources: v5_integrated_controller_builder.py (P36r17,895blocks,16³), v5_floor_growth_builder.py, parameterised v5_saved_connected_signal_timing.py, v5_wire_feedback_audit.py. Linux mirror uses independently owned loopback25596 and restored JRE java-restored-222; Windows acceptance/PC hardware timing still required. E240 process is closed. No Windows job was submitted in these local diagnostic experiments.

Still required: sustainable native crop/recycle/export, production-hour and normal-speed TPS/material counts, ≥100 varied full-module true RUN unloads and saved/forced/lazy interruption recovery, fault/backpressure tests, exact native Litematica paste,2/4-module scaling, Donut mechanics/access verification and external shulker/storage/sell systems. No finish date or A-tier claim yet.

## Previous checkpoint — E222–E229, 13 October 2026

P36r13 remains the resource/export lead; its Windows E206 +74 net/64 supplied cycles is preserved, not rerun. Autonomous crop control, hourly output, full-module RUN recovery, native Litematica and Donut acceptance remain unfinished.

- E222: the first local launch failed before server load with invalid retained Java module contents. Restored the retained JRE archive into a separate directory. A temporary spectator in the isolated loopback world then loaded saved E219 and confirmed **six loose moss blocks**, two carpets and one wheat seed. Temporary player removed; no crop pulses, field reset or inventory replacement. This explains why E221's zero live entities was not collection proof.
- E223: static hopper minecarts beneath full **stone/honey/slime** floors each captured **32/32 diagnostic moss** from naturally flowing level7 water (96/96 total). This is collection geometry, not farm production or moving-cart proof.
- E224: a fresh23-target four-sheet fixture with16 underfloor rails rejected. One rail was absent before actuation; none of the four sheets lifted. Keep as a failed isolated fixture; do not infer all rail arrangements impossible. Do not use it for crops.
- E225: six-hopper clock measured exact42GT,49 comparator edges,7GT HIGH and conserved one timing item; its downward bulb relay failed.
- E226: direct adjacent powered-block bulb connection passed49 clock edges/25 half-output edges. Component only.
- E227: harvest gate with a side solid block rejected:48 pulses every42GT rather than one per84GT crop cycle.
- E228: side dust correction passed **24 harvest pulses, exact84GT interval,4GT HIGH**,49 input/25 half-output edges and conserved timing item. The controller is separate from the crop bed. No crop/hour/RUN proof.

**E229 physical control ordering passed:** growth rising → root blocked9GT → update ON19GT → harvest23GT. After growth falls, root opens9GT later; update falls10GT after root opening. Twenty-four actual harvest-piston edges, exact84GT interval,8GT HIGH; timing item conserved. These are test pistons, not a connected crop source. Startup emitter/retriever parity still requires an actual guarded crop test.

**Next bounded work:** connect tested clock/divider/harvest components to an isolated P36 bed, verifying growth → root block → harvest → root reopening/source update ordering and the emitter/retriever phase. Initialization must not trigger a growth dose before stone exists. Preserve dedicated P36 source update (E220 omission rejected); do not assume P37 can omit it. Then measure unsupplied crop cycles and sustainable output. Address the six loose moss in the sole P37 density challenger using proven pickup geometry; do not repeat broad crop searches or unchanged baselines.

Raw results, prepared sources and healthy E219 block/entity NBT snapshots are durable in the [TestLab continuation checkpoint](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/V5_CONTINUATION_2026-10-13.md). Local experimental servers are stopped. No new Windows runner task submitted; no live user client/Donut/account/settings touched.


Updated 2026-10-13. **The [master directive](V5_MASTER_ENGINEERING_DIRECTIVE_2026-10-12.md) requires arbitrary-phase RUN-state unloading/restart and unattended recovery. Manual OFF is experimental preservation only. Moss leads; benchmark the original single module.** This ledger separates completed evidence, closed branches and the single current next test. Historical handoffs are preserved, but their old next-step lists are superseded.

**Prior checkpoint E206–E221 (12 October):** The main lead is **P36r13**, an original anchored23-target moss crop core with native composting, recycling, reserve control and boundary export. Fresh **E206 on the PC passed64 supplied physical crop cycles: +74 net bonemeal; source128→127; reserve41; external export34; exactly one measured growth dose in every cycle; all23 lava buckets and expected fixture names retained.** No continuing material input or console recycling transfer/pulse. Footprint475 module blocks, occupiedX0..13/Y0..9/Z1..15; the boundary sink is external. **Autonomous crop sequencing and net/hour are still pending.**

E199–203 failed seed/export gates and stopped before64. E202 proved an update-input analogue short; E208 isolated the downstream hopper intake bypass. E205 caught unscheduled replacement-hopper lock initialization before spending any seed. E209 then passed64 crop/recycle cycles (+78) but rejected export because the lock torch powered an incoming queue. E212 moved that torch and exposed a second powered queue beside the comparator output. E213 moved the complete77BM queued hopper intact and detoured it, conserving281BM/23 lava buckets, then passed16 cycles +20net/source79→80. Its87 boundary arrivals included old stock. E206's separate fresh PC run excludes that backlog and proves new production/export. **E220 omitted only the dedicated update actuator and failed on the second growth attempt (zero charged dose): retain that actuator; no repeat.**

The single density challenger is now the **P37 four-sheet attachment**, preserving the earlier24-piston E195 reference (+68/64 PC). Two adjacent six-cell honey/slime sheets passed worst all-STONE lift/return in E210; an immovable hopper halo also passed E214. Fresh E215's four-sheet24-cell bed passed its all-STONE preflight and16 actual crop cycles, +9net/one dose each. E219 applied the proven raised source/blocked-head/update mechanism: four actuators,23 targets, seven guaranteed inner cells, occupied height8; worst all-STONE preflight plus8 crop cycles passed, +5net. These are density/mechanical component gates, **not a measured yield winner**. Inspect actual pickup before integrating; do not infer that all drops reached composting from a positive net total.

E198 measured the saved physical32-stage sequencer: **224GT period, min=max224; each port normally HIGH7GT**. Earlier192 copper-divider and196 hopper-ring tests each passed six witnessed RUN unloads and saved RUN restart, with no full-farm controller connection. E217's corrected saved two-by-two conducting wire spiral transmitted a10GT pulse over nine blocks of height, measured5GT end-to-end delay. E211's torch input and E216's misplaced receiver were harness limitations, separately recorded; do not call them general mechanism failures. E218 timestamped naturally regenerated stone in saved E215: **all24STONE ready35GT after emission, all24 buckets recovered, seed112 unchanged**. This supports testing shorter timing; no faster complete farm/hour/recovery claim yet.

E221's live saved-loot query returned no entities, while direct Anvil readback of the healthy saved E219 chunk contains six item entities (six moss blocks, two carpets and one wheat seed), mainly low in field water. **Live query coverage is unresolved; its empty result does not prove full collection.** Back up the owned Linux world and validate entity loading before a causal collection/cart test. PC206's complete raw artifact is hash-verified and preserved in GitHub. Existing worlds, schematics and successful benchmarks remain untouched.

[Fresh PC E206 result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/206-native-reserve-export.pc.json) · [PC run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38320301766) · [Four-sheet E219](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/219-raised-sheet23-crop.linux.json) · [Measured generator timing](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/218-saved-sheet-stone-generation-timing.linux.json) · [Compact signal spiral](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/217-saved-spiral-wire-receiver.linux.json)

**Next work: validate pickup readback, integrate real autonomous crop timing with the retained update actuator, then measure complete modules and pack the strongest16³ design.** Full-module100 RUN/lazy/forced/seed/output recovery, real hardware TPS/hour, native Litematica paste, verified Donut compatibility,2/4-module scaling and shared shulker/storage/sell infrastructure remain unfinished. E152's one-cell100RUN proof and E147's original single-module +2501/72002GT benchmark remain preserved; do not repeat them unchanged. No broad crop search or blind delay sweep. Historical next-step lists below are superseded.

## Preserved working baseline — do not rerun without a new acceptance reason

| Evidence | Actual result | Decision |
|---|---|---|
| E123 exact P23 schematic | +106 net / 72,002 game ticks; +9 net / real 300 seconds at 20 TPS; export, actual OFF, restart, true unload and recovery passed | Preserved benchmark and exact bytes. Modest prototype, not A-tier winner. |
| E124 exact-file fault scenarios | Full-output stop/restart/unload; external drain resumes; zero seed stable; reprime 128→163 / 24 minutes | Passed. No repeat needed for unchanged P23. |
| E068 pickup materials | Hopper below soul sand/mud/honey/farmland/slab and cart below stone passed controlled collection | Established component fact; test new integrated geometry only. |

[Exact P23 file](prototypes/v5/Bonemeal_V5_P23_Baseline_Prototype.litematic) · [E123](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/123-exact-schematic-p23.json) · [E124](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/124-exact-schematic-congestion.json)

## Closed or shelved — no further variants without a concrete new mechanism/evidence

| Branch | Evidence | Decision |
|---|---|---|
| Old automatic lava gate | E066 failed | Exact old gate remains shelved. A physically different sequenced-lava mechanism requires new causal evidence; manual OFF is no longer final acceptance. |
| Faster 32/40-GT regeneration | E097/E098/E100 cobble; 48-GT control E099 passed | Rejected tested faster settings. |
| Dense dry honey layout | P12–P16 integration failed despite isolated strip success | Shelved; no moving-cache redesign justified by usage. |
| Denser opposed rear feeds on P23 | E128/P24 failed; E129/P25 seal closed water leak but still cobble | Failed full integrations preserved. |
| Rear pulse timing rescue | E130 first-fault trace located both rear cells; E131/P26/P27/P28 delays 2/3/4 all still cobble | Close this integration branch. No further timing sweep. |

E131 24-minute screens ended +52, +57, +55 respectively, but these are **rejected transient runs**, not valid hourly production. Their cobblestone was pushed into the crop lanes. All five failed integrations were parked and preserved, not released.

## Fungus work — new mechanism, not a repeat of old stem transfer

| Evidence | Scope and result | Decision |
|---|---|---|
| E113 | Physical nylium seeding/growth; no harvest/net | Existing growth evidence; do not repeat merely to recount wart. |
| E117 | One-cell sideways stem transfer/clear; supplied sequence/TNT | Existing component only; not an autonomous 25-cell farm. |
| E132 | Move **nylium itself** upward and retract, leaving air below floating stem. Eight-cell controls with 1/5/10 supplied stem blocks all passed; actual first growth/TNT cycle passed; second lost one nylium | New mechanical evidence. Overall FAIL preserved. |
| E133 | Resumed saved pad; lost block was netherrack. Side dispensers restored it; eight continuation cycles passed, five actual fungi, 54 bonemeal removed; passed controls skipped | COMPONENT_PASS, no net-farm proof. |
| E134 | Added wash/pickup/composting; first water bucket was not returned | Collector fixture failed. Original -7 is not a crop sustainability verdict. |
| E135 | Reserved two waterloggable source cells; eight harvest cycles, both buckets recovered; 42 bonemeal removed, 2 recovered, net -40; 83 wart blocks remained unharvested | Current eight-target seeding/partial-harvest layout is shelved. Soil mechanism remains a reusable component. No further small variants. |

[E132](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/132-nylium-plunger.json) · [E133 run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38241148259)

## Current different architecture: corrected P30 passive melon module

| Evidence | Actual result | Decision |
|---|---|---|
| E136 / P29 exact file | 132 stems and hydration survived; no meaningful harvesting or output after 24 simulated minutes | FAIL preserved. Long benchmark skipped; do not rerun this file. |
| E137 saved-fixture trace | Clock ran and 98 melons stood, but the downstream harvest pulse stayed disconnected | Diagnosed a missing direct pickup wire; no crop-growth retest needed. |
| E138 controlled saved-fixture repair | Add the missing wire and restore 36 altered rail shapes. Both carts visited all 22 field rows; both decks harvested; 56 bonemeal reached external output | Repair evidence only. Existing standing melons make this a transient, not an hourly production result. |
| E139 / P30 fresh exact file | PRELIMINARY_PASS: +149 net / 72,002 GT, +16 / real 300 seconds at 20 TPS; all 22 cart rows and 308 rail shapes, manual OFF/restart/true unload/RUN/full-output/drain passed | Preserved working alternative, about 41% above the P23 game-hour sample. Not exceptional output or final winner. |

P30 consumes no fertiliser in steady operation and requires a nearby player for natural random ticks. The run generates a new schematic, preserves cart startup Motion, and builds only from decoded exact bytes. Rail shapes are placed with strict mode because ordinary sequential block updates rerouted P29's return curves. This setup is explicitly **not native Litematica or practical survival rail-placement acceptance**.

The fresh-file test rejects unhealthy warm-up before a 72,000-tick production hour, a real five-minute measurement, actual manual OFF/restart/true unload/RUN, and full-output/external-drain scenarios. Fault-injected bonemeal is excluded from production.

[E136 failure](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/136-passive-p29.json) · [E137 trace](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/137-saved-p29-trace.json) · [E138 repair](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/138-saved-p29-pulse-rail-repair.json) · [E139 Windows run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38249096042) · [P30 builder](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_module_p30_builder.py)

## Closed additional crop: E140 small-plant nylium economics

This differs from the shelved giant-fungus layout: do **not** grow fungi into trees, use TNT or pay giant-growth/soil-repair costs. A fresh 7×7 static crimson-nylium pad receives 32 single real dispenser doses from a finite 64-bonemeal stock. Seven guarded water sources harvest the small plants into a physical hopper/composter/export chain. No crop resets or inventory conversion/replenishment occur between cycles.

Tutorial literature labels profitable nylium-only farming Bedrock-specific, so this is a **bounded Java economic rejection screen**, not an assumption of viability. Reject an uneconomic fully functioning collector before engineering autonomous recycling. If collection/soil/water fails, record a fixture failure rather than a crop verdict. Provided control pulses do not establish an autonomous farm or hourly throughput.

**E140 complete: NET_SCREEN_REJECTED.** All 32 real single-dose/harvest cycles passed: 233 plants generated, every wash cleared all 49 cells, all seven buckets returned, nylium intact, no remaining loose item drops. 32 bone meal consumed, 22 physically recovered, **net −10** after drainage. This root-only Java route is closed; do not scale it or retest merely with a full controller. [Result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/140-nylium-small-plant-net.json).

## Latest E141–E143 stacked continuation

E141/P31 failed after one growth: 27 moss and eight stone persisted, net −1. E142's saved-fixture trace found the clock and upper inputs working; the lower signal died at the first glass-supported descending step. E143 replaced exactly three descent supports with obsidian, recovered the prior shot, and passed three remaining lower-only, four upper-only and eight dual-deck cycles. Both fields renewed to 35 stone, all 96 rail shapes and both buckets survived, and no monitored cobble/water loss occurred. Stock ended 161 from original 128: **+33 net**.

**Scope:** supplied finite seed and sequencing; repaired saved fixture rather than fresh exact-file/native paste. Candidate P32 bytes were generated. No complete autonomous recycling/export/hour/MSPT/RUN-unload acceptance. [E143 run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38254377614).

## E144 — new RUN-unload gate rejected

[Result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/144-running-unload-gates.json), [run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38268243461). Two actual unloads were witnessed from a distant guarded audit. First recovered; second produced no new stone/push over 240 GT, with clear-piston activity continuing. Seed remained 568 after warmup. Zero monitored cobblestone/water loss; fluid-order blame is not established. No saved RUN restart was attempted after rejection.

Static full output-hopper composter case retained level 8 on this Java 26.2 engine. Locked full case also retained and accepted one bone meal after capacity restored. Reported deletion bug not reproduced in this configuration; race/piston/hopper variants remain separate questions.

Decision: hold full integration, close blind timing adjustments, inspect actual dispensed-lava/state-based reference and benchmark the recovered original single module. E145 public reference retrieval submitted at `a96b2fce58cdbc2f0e1aa9410ee0c5ca494e7d1c`; read it before any new task.

## New critical gate

Gate complete-module integration on actual generator recovery from RUN-state unloading/restart. Apply a bounded phase sweep to the known sealed 48-GT component (ordinary cycles already passed), inspect Ryuuoy's actual reference material, recover the original single-module asset, and reproduce Java 26.2 composter-output backpressure loss.

Keep one leading moss architecture and at most one evidence-based challenger. Preserve P30 without reopening broad crop research. Serious finalists need at least 100 varied RUN-unloads, complete net/TPS/recycle/export, scaling and native Litematica acceptance.

## Rules for the next continuation

1. Read the last submitted run and preserve its actual result before making another task commit. Reconnects do not justify rerunning completed tests.
2. Give every new experiment a specific unresolved question, changed mechanic and rejection condition. Run short rejection screens before expensive hour/normal-speed acceptance.
3. Keep an explicit decision when a branch fails. Avoid small timing permutations once a bounded screen rejects them.
4. Component tests never become net-farm proof. Count only actual sustainable inventory surplus, with seed and fault injections handled separately.
5. Finish evidence in GitHub using fresh HEAD leases, preserving simultaneous Club Sana work. Back up the owned V5 world; never alter live worlds.
6. Continue comparing genuinely different architectures. No final winner is selected. Missing final work includes integrated output/TPS comparison, interruption sweep, native client paste, Donut verification and external shulker/storage/sell infrastructure.

## E145–E148 — exact benchmark and actual reference

E145 recovered the original exact bytes but requested invalid reference height1. Its info endpoint gave min21/max320/mod11,10. E146 validated height21 and recovered actual public bytes; no login blocker. [Reference provenance](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/146-reference-height21.json), immutable base64 in TestLab references/v5. Actual geometry18x21x18/3184nonair/658blockentities/eight sources; generated structural metadata is placeholder, not proof. Root source sits five blocks below its field, with direct lava dispensers above and piston harvest into water/composters. Physical functioning still unproved until E148.

E147 measured ONE original16x13x16 module: +2501 inventory bone meal/72002GT after warmup (2500.93/hour normalized), +205 over6000GT in300.014real seconds/19.999TPS, seed122 sustained. Source SHA1d51b0f0aa9575f2a6d5943588b6b6d2dd02d4fb8620649e0c628e0de82bc591. All1542block types verified; five saved-position carts included. Startup128BM/27empty shulkers; no layout changes/ongoing supply. Loaded-box nested contents counted once. Console reconstruction/native paste and RUN unload not yet proved. #moss counter was not implemented; its zeros are not crop evidence. Startup idle phase had catch-up, so sampled MSPT is preliminary only. [Result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/147-original-single-benchmark.json), [run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38270511120).

Decision: P23's106/hour is4.2% of original benchmark. Preserve it; investigate in-place stone regeneration to remove transfer rather than polishing the low-yield baseline. E148 (`24a84ed46bb9a54f5af54f35b7256137a2f930d2`) is submitted: actual reference ordinary/RUN-unload control, not V5 design/size/throughput acceptance. Read its result before another task.

## E148–E151 — recoverable reference and original cell investigation

E148 completed **BOUNDED_REFERENCE_GATE_PASS**: twelve true all-four-chunk RUN unload/reloads and saved RUN restart, all eight dose counters continued, source moss intact, zero monitored cobblestone. Inventory1024→2637 across mixed phases supports positive economics; it is not a stable net/hour measurement and the18x21x18 layout is outsideV5. [Result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/148-reference-physical-gate.json).

E149 fixed-target cell failed ordinary screen:0stone,10dose/harvest rises, no crops/output. Offline geometry showed source-clear/growth contact and a harvest rise bridging pre/post-delay growth. E150 rerouted those and isolated supports:25dose/harvest rises/2306GT, seed576→550, still0stone/crops; source/backstop/bucket retained, no monitored cobble. No unloads attempted. This narrows the remaining problem to actual fluid/piston phase behaviour; do not assert a cause from the end frame. [E149](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/149-fixed-target-cell.json), [E150](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/150-fixed-target-cell.json).

E151 (`30ee18cf7484012e81b0cca1a2faba7e4e191266`) is submitted: resume savedE150 without reset and capture48state frames, then park. Also export only owned serverJARs and verified Temurin25LinuxJRE to enable faster scratch screens while PC runs acceptance. Never claim scratch timings as PC/Donut performance. Read the result before proceeding; no unchanged test repetitions.
