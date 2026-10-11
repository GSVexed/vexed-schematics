# Work Mode handoff — Minecraft bonemeal V5

Status at 2026-10-11: Active research, actual independent Minecraft mechanics tests completed. **No V5 Litematica build yet.**

## User's specific goals

Create an A-tier, **fully original** modular bonemeal factory, not an incremental improvement of the V4 that originated from another builder. Each *complete standalone production core*, including bonemeal generation, harvesting, local composting, closed-loop recycling, initial prime storage, congestion safety and local stop, must fit within a **maximum 16×16×16 block cube** and ideally a **single horizontally aligned chunk**. Need not consume all 16 height. External to module: shared shulker loading, empty shulker supply, bulk storage and single sell wall. Every production core must remain independently functional, stack and tile without dependence on external shulker mechanics.

Maximise **measured sustainable net bonemeal/hour** subject to TPS load, complete recovery after chunk unload, safe stop/restart, full output, bad stone fluid timing, and no reliance on unsupported Donut SMP exploits. Optimise **the whole 3D space**, not merely the top-down footprint.

**Baseline V4**: file `bonemeal.litematic` in this repo, SHA-256 `44b409d5d6b8b3c58ddd34ce6c546b97caebfb91fb499e0565585bb0b138f310`. Four original moss engines in 36×29×18 with 487 total hoppers (including shared infrastructure), not a V5 template. Original files are preserved.

## Verified PC infrastructure

The user has a private GitHub repo `GSVexed/chatgpt-minecraft-testlab`, which a Windows x64 self-hosted runner executes on the user's PC. A separate legacy Minecraft TestLab supervisor and agent (running through a scheduled task) watch `jobs/<job-id>/manifest.json` in that repo and write `results/<job-id>/result.json` and `minecraft-latest.log` to GitHub. Minecraft engine tested: **Java 26.2**.

- [PC Lab operating guide](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/PC_LAB_OPERATIONS.md)
- [Protocol](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/CHATGPT_BRIDGE_PROTOCOL.md)
- Windows development tasks can be executed by updating `pc-lab/task.ps1`, triggering `.github/workflows/pc-lab-task.yml`. Portable Git and embedded Python are installed; use paths in operating guide.
- The remote computer must be on/connected. Never assume execution based on queuing only; inspect both run status and actual test logs. Workflow processes are not durable background tasks unless separately scheduled.
- Never reset the existing Minecraft TestLab world or change the user's real Minecraft game world without safe backup and scope.

## Verified experiments and links

- E01: upward dispenser directly beneath source moss used bonemeal and converted neighbouring stone. [Results](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/035-20261011-v5-bottom-dispenser-moss/result.json).
- E02: actual moss growth trials 7×7, 8 doses: **216 moss blocks** (27/dose); 5×7, 8 doses: **182 blocks** (22.75/dose). Stone regenerated with commands (not renewable loop). [Test log](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/036-20261011-v5-moss-pad-geometry/minecraft-latest.log).
- E03: 5×5, 12 doses: **265 moss** (22.08/dose) [log](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/037-20261011-v5-compact-five-square/minecraft-latest.log).
- E04: **4/4 separate 5×5 moss pads** fit and grew simultaneously in a 16×16 horizontal chunk, but no physical full farm. [Result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/038-20261011-v5-quad-pad-simultaneous/result.json).
- E05: **huge crimson fungus** grown with a dispenser produced **67 crimson nether wart blocks, 8 stems, one bonemeal consumed** in one growth; blocks were measured and removed using commands, not actually harvested. [Result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/039-20261011-v5-giant-fungus-yield/result.json) and [server log](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/039-20261011-v5-giant-fungus-yield/minecraft-latest.log). **Serious high-yield challenger**, but giant fungus can exceed 16 blocks tall and playerless replant/harvest within 16³ is unproved.
- E06: **underwater sea pickles on living coral**, 1 bonemeal application increased count from 4 to 12 (8 new), in five colonies. 65% compost success makes that trial insufficient to cover the 1 bonemeal spent on an expectation basis (8×0.65/7≈0.74). Not a proven self-sustaining system. [Server log](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/040-20261011-v5-sea-pickle-net-growth/minecraft-latest.log).
- E07: bone mealing a 5×5 patch of crimson nylium generated **one crimson fungus and eleven crimson roots** after the dispenser used 2 bonemeal in the experiment. This proves playerless *fungus seed formation*, not deterministic placement or a full fungus cycle. [Server log](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/041-20261011-v5-nylium-auto-fungus-seed/minecraft-latest.log).
- E08: single-cell real lava/water stone regeneration + piston push experiment queued as `jobs/042-20261011-v5-renewable-stone-cell/manifest.json`; inspect status/log before deciding next step.

All above are **isolated growth/mechanics tests, not bonemeal/hour production results**.

## Source research and major clues

- [First-principles R&D document](BONEMEAL_V5_FROM_SCRATCH_RND.md) for hypotheses and raw measurement notes.
- [Architecture](BONEMEAL_V5_ARCHITECTURE.md) for 16³ constraints.
- A wart block has **85% chance** to increment composter and giant fungus success per bone meal attempt is ~40%, but these advantages only help if there is a fully playerless, lossless harvest and replant loop. Fungi can sometimes grow up to 27 tall. Sources: [Minecraft huge fungi guide](https://minecraft.wiki/w/Tutorial:Huge_fungus_generation), [Technical Minecraft wiki](https://techmcdocs.github.io/pages/GameMechanics/HugeFungi/).
- Sea pickles have 65% compost chance; grow underwater on live coral with bone meal, requiring no stone generator. [Wiki guide](https://minecraft.wiki/w/Tutorial:Sea_Pickle_farming).
- Lava flowing down into water makes moss-convertible **stone** (not cobblestone); its fluid ordering and chunk reload need dedicated fail-safe testing. [Stone generator mechanics](https://minecraft.wiki/w/Tutorial:Cobblestone_farming).
- Hoppers transfer one item per 8 game ticks = **9000 items/hour/hopper**, putting a ceiling on composters fed via a single hopper. Design **parallel composters and transport channels** based on measured input.
- Donut SMP reportedly enabled **TNT duplication** in June 2026 (separate from prohibited generic item duplication), but require latest confirmation and compatibility tests before depending on it. [DonutSMP TNT policy](https://donutsmp.wiki/tnt-duping).

## Next research/development steps

1. Retrieve E08 actual engine result/log. If it failed, adjust the test cell and repeat until a physical reproducible stone generator makes and re-makes clean stone after piston removal.
2. Engineer (from scratch) a compact **self-regenerating stone cell → multi-cell stone pad → moss source → piston harvester** within an exact 16³ occupancy model. Do not command-replace stone during functional trials.
3. Add pickup and composters as physical blocks; test initial seed, closed-loop bonemeal refill and surplus. Verify real counts in inventories and item entity loss at 20 TPS. The winner is **net bonemeal/time**, not moss conversions per shot.
4. In parallel, test repeatable playerless fungus seeding/harvest without leakage beyond 16 height; if impossible within constraints, rule it out despite excellent yield in one test.
5. Repeat sea pickle trials if credible as self-sustaining; likely weaker at small footprint, but potentially simpler as no stone generator is needed.
6. Implement backpressure, module isolating stop/restart, chunk unload/reload and multi-module output integration; require long-duration testing 72,000 ticks.
7. Generate candidate .litematic files only when actual machine circuits exist; run schematic structure CI and Minecraft import test; preserve separate labeled prototypes, hashes and PASS/FAIL evidence.

## Important reality checks

- V5 **is not built or validated yet**.
- Do not infer live Donut SMP equivalence from test engine 26.2 alone.
- All local Windows changes and GitHub jobs have real side effects: work in disposable/test areas and avoid secret exposure.
- User prefers independent initiative and minimal manual steps; only request clarification for consequential build constraints, missing access and safety decisions.
