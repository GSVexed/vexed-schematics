# BONEMEAL V5 — DEFINITIVE MASTER ENGINEERING DIRECTIVE
## Project takeover: Design, optimise, validate and deliver an exceptional 16×16×16 Minecraft bone meal factory

**Date:** 12 October 2026  
**Project:** Existing Bonemeal V5 development  
**Target:** Donut SMP, Minecraft Java Edition  
**Primary technology:** High-performance moss farming  
**Maximum module envelope:** 16 × 16 × 16 blocks  
**Status:** Active research and prototype engineering, NOT final release

---

# 1. YOUR MISSION — TAKE FULL ENGINEERING OWNERSHIP

You are continuing an established, technically ambitious Minecraft engineering project.

The user wants an **exceptional, original, extraordinarily efficient and genuinely reliable bone meal factory**.

Not an ordinary farm.

Not a lightly modified existing schematic.

Not an experimental prototype presented as finished.

Not a farm that produces impressive numbers for 20 minutes and then breaks when its chunk unloads.

The objective is to engineer the strongest practical, self-contained bone meal production module possible within 16×16×16, with exceptionally high sustainable NET bone meal production and reliable unattended operation.

**Take ownership of the entire technical process.**

You are authorised to make engineering decisions, invent mechanisms, analyse alternatives, create scripts, run controlled Minecraft experiments, modify project code, produce schematics and document results through the existing authorised infrastructure.

Use the most effective combination of available tools, GitHub, mathematical analysis, research and the user's connected PC.

Do not unnecessarily involve the user in routine engineering decisions.

Do not ask the user to:
- Research Minecraft mechanics.
- Manually analyse schematics.
- Run tests that can be run through the established TestLab.
- Compare experiment data.
- Choose between minor engineering alternatives.
- Transfer research between project files.
- Diagnose redstone circuits.
- Perform calculations you can perform yourself.
- Repeatedly confirm established requirements.

Only seek user input when genuinely essential, such as a significant change to the agreed size constraint, an action requiring unavailable authority, or a potentially destructive change to the user's live world.

**Your task is to transform the current project into a genuinely exceptional finished engineering product.**

The user is not requesting another extended theoretical discussion. Make measurable progress toward the actual working schematic.

---

# 2. HARD REQUIREMENT: COMPLETELY UNATTENDED OPERATION

This is the most important new instruction.

**The final machine must survive its chunks unloading while the farm is RUNNING, at arbitrary phases, without the user touching anything.**

The user intends to scale the farm into many modules. Repairing each individual module after leaving the area would be unacceptable.

The following must not require manually switching the farm off:

- Walking away.
- Teleporting.
- Logging out.
- Disconnecting unexpectedly.
- Leaving simulation distance.
- Chunk unload.
- Chunk reload.
- Server save/restart.
- Returning to the area after an extended absence.

The farm may stop producing when its chunks are not ticking. That is normal.

The requirement is that it **automatically resumes correctly when those chunks become active again**.

The final module must also withstand:

- Full output storage.
- Temporary item transportation congestion.
- Low bone meal reserves.
- Partial inventory states.
- Interrupted harvesting.
- Interrupted stone generation.
- Interrupted fluid updates.
- Dispenser timing changes.
- Piston states and redstone clock recovery.
- Other modules independently loading or unloading.

The previous manual OFF + 480-game-tick settling procedure is no longer an acceptable final operating requirement.

It remains acceptable for preserving experimental prototypes, but not for final release.

**A farm requiring manual shutdown before unloading fails acceptance, regardless of its output.**

A farm that occasionally makes unrecoverable cobblestone also fails acceptance.

Aim for safety inherent in the underlying architecture, not just a clock that happens to work under ideal conditions.

Absolute infallibility cannot be established through a finite test series. Combine mechanical reasoning, state analysis and extensive physical testing to achieve the strongest practical assurance possible.

---

# 3. MAXIMUM QUALITY WITHOUT WASTING WORK USAGE

The user's Work-mode usage is limited.

The project must conserve usage **without compromising final quality in any way**.

This is not an instruction to perform fewer necessary tests, reduce ambition, use weaker designs or stop early.

It is an instruction to eliminate waste through intelligent engineering.

## Mandatory efficiency principles

1. Never repeat completed experiments without a new, specific reason.
2. Read the current saved project state before starting work.
3. Use mathematical analysis before building expensive alternatives.
4. Use the smallest useful Minecraft experiment to test each uncertain mechanic.
5. Stop failed experiments once the decisive failure is understood.
6. Don't repeatedly adjust timing on a design whose underlying mechanics are unsound.
7. Write scripts that automatically run and analyse bounded test batches.
8. Prefer one leading architecture and at most one evidence-based challenger at a time.
9. Do not optimise a component endlessly before establishing that it can integrate into a complete farm.
10. Preserve every meaningful result in GitHub.
11. Keep the current best working prototype available while developing improved variants.
12. Use appropriate parallelism for independent analysis, but avoid competing jobs modifying the same Minecraft world or GitHub files.
13. Reserve sufficient resources for final reliability testing, native Litematica validation and scaling experiments.
14. After an interruption or connection failure, read the latest durable project checkpoint instead of repeating earlier work.
15. Do not spend extended Work usage narrating plans without executing them.

**Protect the final standard, not inefficient processes.**

Every experiment must answer a decision-changing question.

The project must reach the final validated schematic rather than exhausting available resources while repeatedly researching the same mechanisms.

---

# 4. CURRENT PROJECT STATUS — READ THIS BEFORE DOING ANYTHING

## Canonical repositories

Project schematics, architectural requirements and experiment ledger:

https://github.com/GSVexed/vexed-schematics

User's Windows PC TestLab, GitHub Actions runner, scripts and actual Minecraft evidence:

https://github.com/GSVexed/chatgpt-minecraft-testlab

Read these in this order:

1. `V5_EXPERIMENT_LEDGER.md`
2. `BONEMEAL_V5_DEVELOPMENT_2026-10-12.md`
3. `V5_WORK_MODE_HANDOFF.md`
4. `BONEMEAL_V5_ARCHITECTURE.md`
5. `BONEMEAL_V5_FROM_SCRATCH_RND.md`
6. `BONEMEAL_V4_VALIDATION_PLAN.md`
7. TestLab `PC_LAB_OPERATIONS.md`
8. TestLab `CHATGPT_BRIDGE_PROTOCOL.md`

Always check the latest GitHub HEAD first.

The descriptions below are the confirmed checkpoint available to this handoff. The Work project may have advanced since then.

Use newer completed evidence wherever available.

## Existing P23 moss baseline

Complete, previously tested 16³ module:

- +106 NET bone meal per 72,002 game ticks.
- +9 NET bone meal in approximately 300 real seconds at 20 TPS.
- 305 growth doses per tested game hour.
- 411 gross bone meal from composting.
- 20 renewable growing cells.
- Four production composters.
- 43 hoppers.
- Seven hopper minecarts.
- Local recycling and output passed.
- Manual OFF/restart/true unload while OFF/RUN passed.
- Full-output congestion and recovery passed.

Exact production evidence:

https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/123-exact-schematic-p23.json

**P23 does NOT satisfy the new arbitrary-running-unload requirement.**

Preserve its tested exact bytes and use it only as an established baseline.

Do not spend substantial effort polishing P23 into a final design if a fundamentally better architecture is available.

## Existing P30 passive melon baseline

P30 achieved:

- +149 NET bone meal per tested game hour.
- +16 NET during approximately 300 real seconds.
- 132 mature stems.
- No steady-state fertiliser expenditure.
- Physical production, export and controlled shutdown/recovery evidence.

https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/139-passive-p30.json

Preserve it as an alternative and a useful reference for storage/collection engineering.

Do not divert the main programme into melons without strong new evidence.

## E141/P31 stacked moss experiment

The latest independently inspected result was:

https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38253508815

**Actual outcome: FAILURE in the first integrated component cycle.**

The lower field started with 35 stone positions.

After the first bone meal growth:
- 27 moss blocks.
- Eight stone blocks.
- No cobblestone detected.

After the attempted harvest/refill:
- Still 27 moss.
- Still eight stone.
- No demonstrated productive regeneration or collected compost surplus.
- Net bone meal change: −1.

This shows successful moss growth but failed physical integration of harvesting/refill.

It does NOT prove that vertical stacking is inherently bad.

Inspect the preserved artifact and determine the first actual failed mechanism.

Do not rerun the unchanged complete experiment.

If E141 has since been superseded, continue from the newer evidence.

## Historical rejected approaches

The current ledger preserves important failures:

- Old automatic lava gate E066.
- Previously tested faster generator timing variants.
- Dense dry honey integrations P12–P16.
- Opposed rear-feed integrations P24–P28.
- Repeated rear-feed timing adjustments resulting in cobblestone.
- Partial-harvest giant fungus architectures.
- Small-plant nylium E140, which consumed 32 bone meal and recovered 22.

Do not repeat those experiments without a fundamentally new mechanism or material new evidence.

The previously stable 48-game-tick stone-generator control remains useful as a component reference, but it is not proven arbitrary-unload-safe.

---

# 5. BENCHMARK THE ORIGINAL SINGLE MODULE

A critical mistake in previous comparisons was confusing the original four-module factory with the old standalone module.

The user has:

**Original standalone moss module**
- Approximately 16 × 13 × 16.
- 1,542 non-air blocks.
- SHA-256 `1d51b0f0aa9575f2a6d5943588b6b6d2dd02d4fb8620649e0c628e0de82bc591`.

**Original four-module factory**
- Approximately 36 × 29 × 18.
- Contains shared infrastructure.
- SHA-256 `44b409d5d6b8b3c58ddd34ce6c546b97caebfb91fb499e0565585bb0b138f310`.

The fair performance comparison is:

**ONE original single production module versus ONE new complete V5 production module.**

Not the combined four-module factory against one new module.

The old single-module actual sustainable net production has not been established in the currently inspected engineering records.

Arrange one proper benchmark early, unless a valid recent measurement already exists.

Record:
- Net bone meal/hour.
- Total crop conversion.
- Harvest collection efficiency.
- Recycling efficiency.
- MSPT.
- Module footprint.
- Unload/reload behaviour.
- Reliability failure modes.

Use that evidence as the practical performance baseline.

A farm outperforming P23 by 100% is not necessarily competitive with the original module or external technical designs.

**The objective is a meaningful improvement over established alternatives, not merely over weak prototypes.**

---

# 6. SELECTED TECHNOLOGY: HIGH-PERFORMANCE MOSS

Moss is the leading engineering direction.

It offers:

- Dispenser-triggered growth.
- High renewable compostable block yield.
- Additional compostable vegetation.
- Potentially rapid, repeatable production.
- Compact and tileable mechanical arrangements.
- Opportunities for dense multi-source layouts.
- Existing published unload-resistant designs.

However, selecting moss does not prove it is mathematically superior to all possible farms.

If decisive evidence shows moss cannot meet our final reliability/performance requirements, reconsider the mechanism based on evidence.

Do not waste effort restarting a broad crop search simply because a prototype fails.

The priority is now to produce an exceptional original moss-based module.

---

# 7. EXTERNAL TECHNICAL RESEARCH — READ THESE REFERENCES

The following designs and mechanics are useful, but their published performance and reliability claims must be independently validated.

## A. Ryuuoy unload-proof tileable moss farm

https://redenmc.com/litematica/ryuuoymossbonemealfarm

This is the highest-priority reference.

Published claims:

- Normal 2×2 arrangement: approximately 10,600 bone meal/hour.
- Cheap 2×2 arrangement: approximately 11,100 bone meal/hour.
- Compact and tileable.
- Described as unload-proof.
- Claimed restart survival.
- Low reported MSPT with Lithium.
- Approximately 10×9×10 dimensions are mentioned for the compact design.
- The published 2×2 arrangement is described as fitting within one chunk.

The module configuration, exact dimensions, rate accounting and testing conditions must be verified from the actual material.

### Most important mechanism

The design describes delaying lava release until water has finished flowing.

It also uses 2-game-tick scheduled-tick components in its clock to tolerate reload timing.

**Investigate how these properties work physically.**

Do not simply copy the schematic.

Inspect:
- Fluid source arrangements.
- Dispenser-controlled lava.
- Scheduled update ordering.
- Piston sequence.
- Stone transfer.
- Moss growth.
- Collection.
- Recycling.
- Startup inventory.
- Clock restart behaviour.

### Critical weaknesses to improve

The published design warns that:
- Certain bottom dispensers must begin with at least 12 bone meal.
- Empty dispensers can break the farm.
- A cheap version can be affected by rapid switching.
- Operation in lazy-loaded chunks can generate heavy lag.

These are significant limitations.

**Our design should aim to preserve its strongest principles while eliminating or containing these weaknesses.**

Its unload-proof claim is not proof of compatibility with our exact Minecraft version or Donut SMP.

## B. Chromoss/Chronos efficiency reference

https://redenmc.com/litematica/10e32a32-aea5-4a2f-a43c-6484fc659442

Research its productive-area density, processing and lag-conscious engineering.

Do not assume it meets the arbitrary unload requirement.

## C. Dustmoss Refined

https://redenmc.com/litematica/dustmossrefined

Useful as a high-throughput reference.

It is described as not unload-proof.

Study throughput and compactness, but do not adopt vulnerable timings.

## D. Java scheduled-tick mechanics

https://minecraftdocs.dev/systems/world/scheduled-ticks

This is essential.

The document explains:
- Independent block and fluid scheduled-tick queues.
- Tick priorities.
- Per-position/type scheduling and deduplication.
- Saved scheduled ticks during chunk unloading.
- Relative delay reconstruction during reload.
- Ordering between saved ticks and newly scheduled ticks.
- Behaviour when a queued tick no longer matches the current block.
- Differences between registered and actively ticking chunks.

The document discusses Minecraft Java 26.3; verify all material behaviour in the actual 26.2 test environment and target server.

The purpose is to understand **why a mechanism remains safe even when timing is interrupted**, not to assume a particular clock is safe merely because it uses repeaters.

## E. Java moss bone meal mechanics

https://minecraft.wiki/w/Tutorial:Bone_Meal_farming

Investigate exact spread geometry, vertical search rules, surface eligibility, source clearance, vegetation and harvesting.

## F. Water-state-gated stone generator

https://www.reddit.com/r/technicalminecraft/comments/1epglt5/unloadproof_stone_generator_for_moss_farms_no/

This is a Bedrock-oriented technical idea.

Its concept is to confirm water readiness before allowing lava.

**Do not assume it works in Java.**

Treat it as inspiration for a different architecture and test the precise mechanics.

## G. Real-world failure reports

https://www.reddit.com/r/technicalminecraft/comments/1rj2mrw/lava_turning_into_stone_when_unloaded_in_my_moss/

This discussion describes a failure where stone was not transferred after an interruption and newly generated stone was pushed into an unsafe location.

Important lesson:

**A stone generator can fail because of piston sequencing and occupied cells, not only because of water/lava timing.**

Investigate the complete block-motion system.

Another discussion:

https://www.reddit.com/r/technicalminecraft/comments/1s9z054/how_do_you_prevent_cobblestone_from_forming_in_a/

The community discusses different stone-generation strategies and unload failures.

Use community reports to identify potential failure mechanisms, not as proof of universal behaviour.

## H. Critical composter/hopper bug

https://bugs.mojang.com/browse/MC/issues/MC-311649

The reported issue describes bone meal being deleted when a composter's output hopper is unable to accept it.

The report references longstanding MC-175090.

This is highly relevant to our factory's storage-backpressure requirement.

**Investigate the exact affected versions and reproduce the condition on the actual test engine.**

Ensure the final output system cannot silently delete bone meal when full.

Do not assume a stopped composter always retains its produced bone meal safely.

---

# 8. INVESTIGATE ALL GAME-CHANGING MECHANICS

Research the mechanics that could transform our architecture, not just conventional moss-farm construction.

Prioritise by potential impact.

## Moss generation

- Exact spread probability by coordinate.
- Source height and clearance.
- Maximum usable growth area.
- Vertical search and candidate selection.
- Existing moss interference.
- Nonconvertible blocks.
- Moss carpets and azalea obstruction.
- Vegetation generation.
- Expected harvestable items per dose.
- Conversion efficiency of different stone layouts.

## Stone generation

- Downward lava into water.
- Sideways water/lava contact.
- Source versus flowing fluid.
- Fluid tick ordering.
- Dispensed versus permanent lava.
- Waterlogged blocks.
- Piston movement and fluid updates.
- Safe regeneration with occupied cells.
- Block-update ordering.
- Unloading during partial stone pushes.
- Correct reset of mechanical states.

## Redstone and pistons

- Repeater tick priority.
- Scheduled-tick persistence.
- Observers.
- Quasi-connectivity.
- Block-event handling and piston state persistence.
- Short-pulse behaviour.
- Comparator thresholds.
- Hopper clocks.
- Clock reconciliation.
- Mechanical interlocks.
- Push limits.
- Sticky/slime/honey interactions.
- Immovable blocks.
- Directional behaviour.

## Harvesting

- Moss breaking under pistons.
- Moss carpet clearing.
- Water flushing.
- Dry piston harvesting.
- Hybrid harvesting.
- Harvesting while protecting the original moss source.
- Collection loss under dense production.
- Item entities during chunk unloading.
- Block replacement and dropped-item behaviour.

## Collection and composting

- Hopper speeds.
- Hopper locking.
- Hopper minecart pickup.
- Minecart unloading.
- Collection through blocks.
- Water streams.
- Item grouping.
- Multiple composter inputs.
- Composter processing and output extraction.
- Full-output behaviour.
- Hopper deletion bugs.
- Bone meal return distribution.
- Item sorting and mixed compostable streams.

## Reliability and server performance

- Chunk borders.
- Block versus entity ticking.
- Lazy-loaded chunks.
- Server saves.
- Restart recovery.
- Redstone phase persistence.
- Independent neighbouring chunks.
- MSPT effects.
- Hopper scanning overhead.
- Fluid update overhead.
- Item-entity count.
- Piston activity.
- Donut SMP anti-lag mechanisms and actual TPS.

For each interesting discovery, establish:

1. Exact mechanism.
2. Why it could improve the farm.
3. Compatibility with Java/Donut.
4. Extra complexity or reliability risk.
5. Cheapest decisive test.
6. Whether the result changes the leading design.

Do not produce an enormous research catalogue with no engineering decisions.

---

# 9. ORIGINAL DESIGN HYPOTHESES — USE OR IMPROVE THESE

The following are serious engineering proposals, not verified working designs.

Evaluate them critically. Invent better alternatives when justified.

## Hypothesis A — Physically isolated stone-generation chamber

Separate renewable stone generation from the growing surface.

Generate ordinary stone inside a protected chamber, then mechanically transfer completed stone into the moss field.

Potential benefits:
- Less direct exposure of productive moss cells to fluid faults.
- Independent generator timing.
- Opportunity to buffer finished stone.
- Easier fault isolation.
- Easier readiness detection.

Potential problems:
- Space cost.
- Piston push limits.
- Transfer throughput.
- Extra actuator complexity.
- Difficulty fitting complete machinery inside 16³.

Model expected output and occupancy before implementing a full farm.

## Hypothesis B — Transactional fluid sequencing

Develop a stone generator whose operation follows a safe sequence:

`SAFE IDLE → WATER PREPARATION → WATER CONFIRMATION → LAVA RELEASE → STONE CONFIRMATION → FLUID ISOLATION → STONE TRANSFER → SAFE IDLE`

The idea is to avoid relying entirely on a permanently running clock with narrowly timed fluid arrival.

Advance only when the necessary safe state has been established, wherever the physical Minecraft mechanics allow reliable confirmation.

Critical concern: observers and redstone signals do not automatically prove the fluid state we think they prove.

Verify each sensing assumption.

Do not construct an elaborate controller whose complexity makes it less reliable than a simple robust design.

## Hypothesis C — Self-reconciling redstone

Investigate a controller that can return to a safe state after reloading, rather than requiring its clocks to restart in perfect synchronisation.

Possible methods:
- Physical state indicators.
- Interlocked actuators.
- Deterministic return positions.
- Safe idle states.
- Pulse-independent reset paths.
- Mechanically constrained sequences.
- Restart behaviour insensitive to a limited scheduling offset.

Examine both saved block state and pending scheduled ticks.

Use an explicit state-transition model where valuable.

## Hypothesis D — Generator occupancy protection

A particularly important overlooked problem is that the generator may create new stone while old stone is still occupying a transfer cell.

Investigate mechanisms that prevent:
- Two stone blocks occupying an intended one-block transfer path.
- Newly generated stone being pushed into lava.
- Piston pushback into a fluid source.
- Generator activation while the destination is obstructed.
- Permanent jams following an interrupted transfer.

A reliable lava/water timing sequence is not enough if the block-transfer system is unsafe.

This should be an independent design and test requirement.

## Hypothesis E — High-density independent micro-engines

Fit multiple productive moss sources and small growth fields within the 16³ module.

Investigate whether several smaller fields can outperform one large field once generator, harvest and transport space are included.

Possible benefits:
- Higher productive cell density.
- Parallel growth.
- Reduced harvest burst size.
- Independent fault containment.
- Staggered production.

Potential disadvantages:
- Duplicated redstone.
- Greater startup seed.
- More generators.
- More simultaneous block updates.
- Higher materials and MSPT.

Optimise the complete design, not just the crop pads.

## Hypothesis F — Shared stone generation across fields

Explore one robust generator supplying multiple growing areas.

This could reduce duplicated fluid machinery, but risks creating a major bottleneck or single point of failure.

Evaluate actual stone production capacity, transfer footprint and interrupt safety.

Do not pursue it merely to reduce component count.

## Hypothesis G — Optimised vertical moss fields

The current 16-block height is a limited but valuable resource.

Investigate whether two or more growing planes can occupy the same vertical column efficiently.

Potential mechanisms include:
- Independent vertically separated growth sources.
- Shared collection layers.
- Common composting.
- Staggered harvest phases.
- Compact downward or sideways block transfer.

Explicitly test moss's vertical search behaviour and cross-deck interference.

The E141 failed harvest integration must not be repeated unchanged.

## Hypothesis H — Hybrid piston and collection system

A fully water-washed field may be slower or more fragile than necessary.

Investigate:
- Piston breaking of moss.
- Dry collection through suitable blocks.
- Stationary hopper minecarts in limited locations.
- Water only for moving item drops, not regulating stone growth.
- Gravity-fed collection.
- Reduced moving-cart paths.

Previous dry-honey integrations failed; do not reopen the exact same mechanics without a genuinely different hypothesis.

## Hypothesis I — Adaptive growth readiness

A productive module should avoid wasting bone meal on a field that isn't ready.

Investigate whether growth can depend on physical surface renewal or a robust cycle-completion signal.

Potential advantages:
- Better bone meal efficiency.
- Less feedstock starvation.
- Lower wasted cycles.
- Improved stability during lag.

Compare against a simple conservative cycle to ensure that control overhead is worthwhile.

## Hypothesis J — Phase-staggered engines

If several independent growth engines fit in one module, operate them at staggered phases rather than simultaneously.

Investigate whether this:
- Smooths item collection.
- Reduces peak entity counts.
- Reduces burst piston activity.
- Improves bone meal return latency.
- Reduces peak MSPT.

Do not assume lower peak load means lower average MSPT. Measure both.

## Hypothesis K — Self-protecting and fault-isolating modules

Explore how a module can detect or contain a problem before it damages the rest of the system.

For example:
- Hold stone generation when its transfer area is obstructed.
- Prevent growth dosing during incomplete regeneration.
- Maintain essential seed reserves.
- Stop generating drops when collection is fully congested.
- Isolate an engine that has entered an unsafe state.

True automatic repair of accidentally generated cobblestone may be difficult or impossible within our restrictions.

Prioritise fault prevention and containment rather than assuming broken blocks can always be fixed automatically.

---

# 10. MATHEMATICALLY OPTIMISE MOSS GEOMETRY

The final layout should be chosen using the actual growth algorithm, not visual intuition alone.

Build a programmatic model of moss conversion.

For each realistic candidate layout:

1. Define the moss source positions.
2. Define all convertible stone positions.
3. Include the exact vertical eligibility rules.
4. Include machine blocks that obstruct or modify growth.
5. Calculate expected conversion probability by position.
6. Calculate expected compostable item output.
7. Estimate how quickly stone can be regenerated.
8. Include collection and harvesting constraints.
9. Include controller and generator footprint.
10. Estimate sustainable net output within the full 16³ envelope.

Consider:
- Single large field.
- Several smaller fields.
- Asymmetric growing regions.
- Independently staggered fields.
- Vertically separated fields.
- Shared versus independent generators.

Previous growth-only tests observed approximately:
- 27 moss blocks/dose on a 7×7 pad.
- 22.75 on a 5×7 pad.
- 22.08 on a 5×5 pad.

These are experimental samples, not guaranteed yields.

They suggest that smaller fields may have favourable output relative to their physical area.

Use simulations, analytical optimisation and actual engine validation to establish the most productive complete architecture.

**Optimise usable bone meal output per complete cycle, not just the number of stone blocks visible in a schematic.**

---

# 11. COMPLETE PRODUCTION ECONOMICS

The correct objective is:

**NET bone meal/hour = new bone meal generated minus bone meal consumed.**

Count every bone meal item exactly once across:
- Dispensers.
- Hoppers.
- Droppers.
- Minecarts.
- Internal buffers.
- Local recycling storage.
- Exported output.
- External witness inventories.

Exclude:
- Initial seed counted as new production.
- Fault-injected inventory.
- Command-created resources.
- Manually supplied bone meal.
- Uncollected vegetation.
- Theoretical outputs never physically composted.

Approximate composter probabilities:

| Item | Chance |
|---|---:|
| Moss block | 65% |
| Moss carpet | 30% |
| Azalea | 65% |
| Flowering azalea | 85% |
| Wheat/melon seeds | 30% |

For uniform inputs, expected items per produced bone meal under the standard first-layer rule are:

`1 + 6/p`

Where `p` is compost probability.

At 65%:

`1 + 6/0.65 ≈ 10.23 moss blocks per bone meal`

A pad yielding 27 collected moss blocks per dose would theoretically generate about 2.64 gross bone meal before vegetation.

After spending one bone meal:

`approximately +1.64 net bone meal/dose`

At 600 successful complete doses/hour:

`approximately +984 net bone meal/hour`

This is only a growth-only illustration, not measured integrated production.

The engineering challenge is achieving the complete sustainable cycle rate without dropping items, wasting doses or creating mechanical faults.

### Mixed-item optimisation

Model actual mixtures of:
- Moss.
- Carpets.
- Seeds.
- Azaleas.
- Flowering azaleas.

Investigate selective use of low-value items for guaranteed early composter advancement if economically meaningful.

Do not add sorting complexity without demonstrating an improvement.

### Transport bottlenecks

One vanilla hopper transfers approximately one item per eight game ticks, or 9,000 items/hour at 20 TPS.

A high-output moss farm may need parallel processing paths.

Measure:
- Harvest rate.
- Pickup rate.
- Transport rate.
- Composter input.
- Composter output.
- Return supply.
- Export rate.

The slowest effective stage determines sustained throughput.

Don't optimise an already over-capacity stage while ignoring the actual bottleneck.

### Composter deletion under backpressure

Specifically test the reported composter/hopper issue when downstream storage is blocked.

Ensure the final design cannot lose bone meal silently under full or partially blocked inventory conditions.

---

# 12. DESIGN FOR LOW SERVER IMPACT

The best farm should be powerful enough to scale.

Track:
- Active MSPT.
- Idle MSPT.
- Cost per 1,000 NET BM/hour.
- Hopper count.
- Moving hopper minecarts.
- Redstone dust.
- Active pistons.
- Fluid updates.
- Item entities.
- Dispenser activity.
- Continuous clock activity.
- Transport overhead.
- Chunk-boundary updates.

Investigate appropriate hopper-overhead reduction techniques, but do not implement lag-reduction tricks that interfere with pickup or processing.

Measure server performance using a consistent empty-world or idle-relative baseline.

Test multiple modules to identify scaling nonlinearities.

The final result should not achieve exceptional output by making the server practically unplayable.

---

# 13. BONE MEAL RESERVE AND STARVATION SAFETY

The module must have a protected recycling system.

Required behaviour:

- Startup with clearly documented seed inventory.
- Sufficient reserve for safe production.
- Recycled bone meal prioritised over surplus export.
- Low-stock conditions stop unsafe new growth cycles.
- Zero-stock conditions do not physically damage the machine.
- The machine retains a recoverable state during prolonged starvation.
- Replenished input allows automatic recovery without resetting redstone.
- A temporary recycling delay cannot strand the machine permanently.

Do not claim the farm can spontaneously recover bone meal from zero stock without an actual source. The goal is to prevent unsafe depletion and require no routine manual intervention.

Where possible, make reserve handling mechanical and inherently safe.

---

# 14. OUTPUT STORAGE MUST NOT BREAK THE FARM

Many modules will feed a shared transport and storage system.

The production core must contain its own bounded safety mechanisms.

When external storage fills:

- Surplus output must safely stop or buffer.
- Essential recycling must remain protected.
- Item entities must not accumulate indefinitely.
- Composters must not delete items.
- Harvesting must not permanently jam.
- The module must not lose its ability to resume.

When the external system becomes available again, recovery must happen automatically.

Test both isolated-module and multi-module output congestion.

The shared infrastructure must never become necessary for local bone meal recycling.

---

# 15. 16×16×16 PHYSICAL REQUIREMENTS

All essential standalone production machinery must fit within a maximum 16×16×16 region.

That includes:
- Stone generation.
- Growth.
- Harvesting.
- Item pickup.
- Composting.
- Internal recycling.
- Seed protection.
- Local control.
- Local output buffer.
- Required moving machinery.

The following may be external:
- Shared shulker loaders.
- Empty shulker supply.
- Central bulk storage.
- Central sell wall.
- Shared transport infrastructure.

The complete production mechanism must remain within one horizontal chunk column.

No essential mechanical timing may rely on neighbouring chunks being loaded simultaneously.

All block states, fluids, moving entities and attachments must remain within valid build limits during operation.

A module that appears 16³ but grows or moves critical blocks outside its boundary fails the constraint.

Use all useful space, but do not fill empty space unnecessarily.

For user-approved changes to maximum height, seek permission only if a clearly proven breakthrough requires it. Otherwise remain within 16³.

---

# 16. TESTING STRATEGY — STRONGER EVIDENCE, LESS WASTE

Implement progressive engineering gates.

## Gate 1 — Mechanical feasibility

Test the stone-generation concept independently.

Prove:
- Renewable ordinary stone.
- Correct fluid states.
- No cobblestone in ordinary cycles.
- Correct piston reset.
- Stable physical source blocks.
- Recoverable interrupted states.

Use short decisive tests first.

## Gate 2 — Arbitrary-unload stone generation

Unload the component while RUNNING at distinct meaningful phases.

Test:
- Before water arrives.
- After water arrives.
- Before lava release.
- With lava flowing.
- During stone formation.
- Before piston movement.
- After partial piston movement.
- With an occupied transfer cell.
- During scheduled redstone transitions.

Verify genuine chunk unloading, not a fake OFF state.

Observe the complete physical recovery.

Do not continue to full farm integration if the generator fails this critical gate.

## Gate 3 — Efficient moss growth and harvesting

Use the chosen safe generator with the best realistic growing-field geometry.

Prove physical:
- Growth.
- Harvest.
- Stone replacement.
- Source preservation.
- Vegetation clearing.
- Pickup.

Count actual collected items.

## Gate 4 — Complete autonomous production

Integrate:
- Composting.
- Bone meal return.
- Stock protection.
- Output.
- Backpressure handling.

Confirm sustainable positive NET production.

Use short functional rejection screens before lengthy benchmarks.

## Gate 5 — Performance optimisation

Measure the complete system and locate the bottleneck.

Optimise:
- Productive growing cells.
- Cycle frequency.
- Parallelism.
- Harvest efficiency.
- Collection.
- Compost capacity.
- Recycle latency.
- Controller overhead.
- MSPT.

Do not trade away arbitrary-unload safety for minor throughput improvements.

## Gate 6 — Extended endurance and reliability

After functional stability, run:
- At least one full 72,000-game-tick sustainable production benchmark.
- A separate actual real-time normal-TPS measurement.
- Extended regeneration tests.
- Reproducible arbitrary-phase unload/reload trials.
- Actual saved server restart while RUNNING.
- Relevant process-interruption tests on isolated backups.
- Full-storage and empty-storage recovery.
- Low-seed and restored-seed tests.
- Fault containment tests.

For serious finalists, target at least 100 varied and reproducible abrupt unload/reload trials across meaningful phases.

State modelling must accompany empirical testing.

A clean 100-trial run does not prove zero theoretical failure probability.

## Gate 7 — Scaling

Test two modules and four modules.

Measure:
- Per-module output.
- Combined output.
- Server performance.
- Chunk-load independence.
- One stalled module.
- Shared output congestion.
- Mixed running/stopped modules.
- Independent and simultaneous unload/reload.
- Recovery after restart.

## Gate 8 — Exact Litematica acceptance

Validate the exact deliverable:
- File format.
- SHA-256.
- Palette.
- Block orientation.
- Coordinates.
- Inventories.
- Entities.
- Rails.
- Fluids.
- Startup requirements.
- Boundary containment.

Test the exact file's actual Minecraft functionality.

Finally test native Litematica import/paste behaviour.

Prior project failures show that reconstructing rail shapes or entities on the server may not behave exactly like a native client paste.

Do not claim instant, no-setup pasting without verifying it.

---

# 17. FAILURE MODES THAT MUST BE ELIMINATED OR CONTAINED

The final design must address:

- Cobblestone forming in production lanes.
- Stone pushed into lava.
- Unsafe occupied generator cells.
- Water source loss.
- Lava source loss.
- Incomplete fluid isolation.
- Unsynchronised pistons.
- Stuck piston states.
- Clocks failing to restart.
- Persistent dispenser powering.
- Missing dispenser pulses.
- Bone meal starvation.
- Harvesting while the surface is incomplete.
- Moss source obstruction.
- Unharvested carpets.
- Item collection congestion.
- Moving minecart stranding.
- Broken rail placement.
- Item entity despawning.
- Partially blocked composters.
- Bone meal deletion in full output systems.
- Storage backpressure.
- Unsafe chunk-boundary interaction.
- Restart timing changes.
- Server lag.
- Partial block/entity ticking.
- Cross-module failures.
- Incorrect startup inventories.
- Incorrect native Litematica placement.

Where possible, eliminate a failure by changing the physical architecture rather than adding an unreliable detector to a fragile mechanism.

---

# 18. ENGINEERING DECISION PROCESS

Maintain one leading architecture and one challenger only when justified.

Every proposed experiment should include:

**Hypothesis:** What precise mechanism or advantage are we testing?

**Evidence:** What do previous experiments and Minecraft mechanics already establish?

**Potential impact:** How much could this improve throughput or reliability?

**Cost:** How much building, scripting and runtime is required?

**Fast rejection:** What's the smallest decisive test?

**Failure condition:** What result means we should stop?

**Next action:** What happens if the experiment passes or fails?

Prefer high-information experiments.

Avoid repeatedly varying one clock delay unless a causal analysis predicts a meaningful difference.

If several related experiments fail, inspect the actual Minecraft implementation or underlying mechanics rather than guessing.

Record decisions durably so reconnects do not cause repetition.

---

# 19. USE ALL AVAILABLE TOOLS INTELLIGENTLY

The user has previously established a working connection between ChatGPT and their PC.

Use the existing infrastructure, including:

- GitHub-connected project files.
- The self-hosted GitHub Actions Windows runner.
- The isolated Minecraft Java TestLab.
- Python and other available local tooling.
- Programmatic schematic generation.
- World-state inspection.
- Automated inventory accounting.
- Mathematical simulation and geometry search.
- Web research for version-specific mechanics.
- Reproducible test scripts.
- Structured result logging.

Use each tool where it is strongest.

Do not assume everything needs to be done inside Work's browser or inside the user's PC exclusively.

Avoid unnecessary transfers between tools.

Do not modify the user's live Donut SMP world while running destructive experiments.

Preserve the unrelated Club Sana work and any active processes.

Use fresh GitHub HEAD checks and established task ownership procedures.

Do not overwrite `pc-lab/task.ps1` while an existing task is running.

Keep backups of experimental worlds.

If a tool or access path is unavailable, use another appropriate existing method when possible.

---

# 20. DONUT SMP COMPATIBILITY

The test environment uses Minecraft Java 26.2 with Fabric/Carpet infrastructure.

Donut SMP may behave differently.

Establish where possible:
- Actual current server version.
- Redstone limitations.
- Fluid behaviour.
- Hopper transfer behaviour.
- Simulation distance.
- Entity ticking.
- Anti-lag modifications.
- Server TPS.
- Permitted mechanics.
- Relevant chunk-loading limitations.

Do not assume a vanilla or Fabric pass proves a Donut SMP pass.

Conversely, do not spend large amounts of time speculating about server differences without a testable hypothesis.

Use safe isolated tests first.

Do not perform live-server actions that alter protected areas, violate server rules or risk the user's existing builds.

If final Donut confirmation requires unavailable access or human-only actions, complete every other acceptance gate, document that limitation precisely and avoid falsely claiming live compatibility.

---

# 21. EFFICIENCY MILESTONES — PRESERVE USEFUL RESULTS

The project must produce useful deliverables throughout, not only at the theoretical final step.

Save milestone artifacts such as:

**Milestone A:** Verified unload-safe stone-generation mechanism, including exact component schematic and test evidence.

**Milestone B:** Optimised moss-growing and harvesting assembly with measured crop yield.

**Milestone C:** Complete sustainable working 16³ module, even if not yet maximally optimised.

**Milestone D:** Improved production candidate, with measured net-output gains and preserved reliability.

**Milestone E:** Fully tested final design with multi-module scalability and installation evidence.

These are development milestones, not permission to lower final standards.

Always preserve the best functional design before replacing it.

If a later optimisation fails, the project must still retain an earlier proven working version.

If available Work usage becomes constrained, save the current project state and the precise continuation point rather than burning through the remaining allowance on uncertain research.

Never mislabel an intermediate prototype as the finished A-tier deliverable.

---

# 22. PERFORMANCE TARGETS — BE AMBITIOUS, BUT EVIDENCE-DRIVEN

P23's +106 net bone meal/hour is not an acceptable final ambition.

P30's +149 net bone meal/hour is not an acceptable final ambition either.

Published technical references show that moss mechanisms can achieve far higher performance, although their reported rates, exact modules and unload reliability are not directly comparable to ours.

Aim for the highest **measured sustainable net output** possible under the fixed 16³ and reliability constraints.

Do not invent or promise a particular output figure without actual test evidence.

Determine what the physics, geometry and measured bottlenecks permit.

If a design is substantially below external high-performance references, investigate why.

If it underperforms the original single module, it cannot be considered a meaningful final upgrade unless the trade-off is clearly justified and accepted.

A genuinely A-tier result must excel in more than one dimension:

- High actual net production.
- Reliable unattended operation.
- Compact, complete machinery.
- Excellent scale behaviour.
- Manageable MSPT.
- Minimal maintenance.
- Exact reproducible installation.
- Robust mechanical design.

The best solution is not necessarily the most elaborate.

It is the strongest solution supported by evidence.

---

# 23. WHAT COUNTS AS FINISHED

Do not present this project as complete until the following have been established.

## Production

- Real renewable stone generation.
- Real moss growth.
- Actual harvesting.
- Actual item collection.
- Actual composting.
- Actual internal bone meal recycling.
- Actual exported surplus.
- Sustained positive net production.
- Competitive performance against the old single-module benchmark.

## Reliability

- Unloading while RUNNING passes.
- Automatic reload recovery passes.
- Running server restart passes.
- Fluid sources remain intact.
- No permanent cobblestone contamination.
- No unrecoverable block-motion jam.
- No stuck clock.
- Low-stock behaviour is safe.
- Restored stock allows recovery.
- Full-storage behaviour is safe.
- Restored output capacity allows recovery.
- Multi-module operation remains isolated.

## Physical module

- Maximum 16×16×16.
- Entire production system contained.
- Single chunk-column alignment.
- Independent self-recycling.
- Consistent output interface.
- Shared external shulker loading.
- Accessible documented startup procedure.
- No hidden infrastructure needed outside the approved boundary.

## Performance

- Complete game-hour net benchmark.
- Separate normal-speed measurement.
- Accurate full inventory accounting.
- Startup seed excluded from profit.
- Actual item collection measured.
- MSPT measured against idle conditions.
- Multiple modules tested.

## Installation

- Exact `.litematic`.
- SHA-256 checksum.
- Correct block states.
- Correct entity positions.
- Correct inventories.
- Proper orientation.
- Correct startup materials.
- Native Litematica compatibility tested.
- Clear installation instructions.
- Clear output interface.
- Documented version compatibility.

## Evidence

- Actual game-engine runs.
- Saved scripts.
- Saved result JSON.
- Failure and recovery records.
- Reproducible performance figures.
- Documented limitations.
- No unverified claims represented as completed tests.

**Passing one test does not substitute for passing the others.**

---

# 24. FINAL DELIVERABLES

Produce:

1. The strongest fully tested standalone V5 bone meal `.litematic`.
2. Exact file hash and tested Minecraft version.
3. Complete material list.
4. Measured sustainable NET BM/hour.
5. MSPT and scaling measurements.
6. Reliability results.
7. Startup/setup instructions.
8. Module placement and orientation.
9. Surplus output position.
10. Protected bone meal recycling description.
11. Unload/reload and restart evidence.
12. Multi-module operating evidence.
13. Native Litematica installation evidence.
14. Known compatibility limitations.
15. Technical comparison with the old single module and relevant outside designs.
16. Complete preserved engineering records.

All shared storage, shulker infrastructure and central sell-wall work can be integrated after the production core is validated, unless it is necessary to test output/backpressure.

Do not expand the production module past 16³ in order to hide essential mechanisms outside its footprint.

---

# 25. EXECUTE NOW — WITHOUT MAKING THE USER MANAGE THE PROJECT

You are not being asked to provide another list of research ideas.

You are being asked to proceed with the engineering work.

Follow this execution sequence intelligently:

**1. Refresh state.** Check the latest GitHub HEAD, active jobs, experiment ledger and actual completed results. Do not restart historical work.

**2. Update requirements.** Formally replace manual-OFF-before-unload acceptance with arbitrary-running-unload acceptance.

**3. Inspect the latest failure.** Analyse E141 if it hasn't already been superseded. Preserve its evidence and identify the exact failed mechanism.

**4. Study the strongest unload-resistant reference.** Understand Ryuuoy's actual fluid sequencing, scheduled ticks, source protection and weaknesses.

**5. Investigate alternative fail-safe mechanisms.** Prioritise isolated stone manufacture, controlled lava dispensing, state-confirmed water, safe transfer occupancy and self-reconciling controllers.

**6. Choose the most promising mechanism using evidence.** Don't blindly implement every theoretical idea.

**7. Run a short physical Minecraft test.** Prove safe repeated ordinary stone generation and genuine mid-cycle unload/reload recovery.

**8. Optimise moss growing geometry mathematically.** Use the actual Java algorithm and complete machinery footprint.

**9. Integrate harvesting and collection.** Prove the materials are physically recovered.

**10. Build a complete sustainable candidate.** Include composting, recycling, stock protection, bounded storage and export.

**11. Measure real performance.** Identify actual bottlenecks and optimise the most impactful components.

**12. Compare with the original single-module schematic.** Establish real competitive improvement.

**13. Validate arbitrary unloads and restart.** Use systematic phases, reproducible random trials and physical recovery observations.

**14. Validate scaling.** Test two/four modules and independent chunk interruptions.

**15. Validate the exact native Litematica.** Do not assume a server-reconstructed schematic behaves identically when pasted.

**16. Deliver the best proven final artifact and documentation.**

Carry out these stages autonomously through the authorised tools and infrastructure, without unnecessary user questions.

If a critical mechanical uncertainty remains, resolve it using the smallest useful experiment.

If a branch fails, preserve the result and move to the next genuinely different idea.

If another architecture becomes demonstrably better, adopt it.

Do not spend Work usage repeatedly restating what should happen. Perform the work, save the evidence and continue.

---

# 26. FINAL OPERATING PRINCIPLES

**Engineering authority:** You have freedom to redesign, invent, optimise and reject mechanisms based on evidence.

**Reliability:** The user must be able to walk away or disconnect at any time without needing to repair modules.

**Performance:** Maximise genuine sustainable NET bone meal/hour, not theoretical crop yield or temporary output.

**Efficiency:** Conserve Work usage by eliminating wasted effort, not by reducing final quality.

**Originality:** Study the best existing farms but create an original, independently proven design.

**Scalability:** Design the first module as something that can be duplicated many times without increasing the user's maintenance burden.

**Evidence:** Never describe a schematic as confirmed working until actual Minecraft behaviour supports that claim.

**Initiative:** Make ordinary decisions yourself; do not turn the user into the project manager.

**Persistence:** Preserve the latest exact state so interrupted sessions resume instead of repeating.

**Ambition:** Do not settle for a mediocre farm simply because it is functional.

---

# THE ULTIMATE OBJECTIVE

Create a Minecraft bone meal production module that is:

**Original. Extremely productive. Entirely self-contained within 16×16×16. Fully automated. Self-recycling. Efficient. Scalable. Safe to unload while running. Automatically recoverable. Low-maintenance. Rigorously tested. And demonstrably better than the user's existing single-module factory.**

The user wants something exceptional enough to justify building and scaling many copies.

Take complete engineering ownership of achieving that result.

Use the established project infrastructure intelligently, avoid repeating completed work, preserve the user's Work usage, challenge conventional designs where useful, and pursue every substantial improvement supported by Minecraft's mechanics.

**Do not sacrifice reliability for output. Do not sacrifice output unnecessarily for simplicity. Do not sacrifice final quality to conserve usage. Eliminate waste through superior engineering decisions.**

Produce the strongest genuinely validated schematic the constraints allow.

**Begin immediately from the latest verified project state and continue toward the finished artifact.**
