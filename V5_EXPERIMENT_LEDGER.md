# V5 experiment ledger — resume here, do not restart research

Updated 2026-10-12. This ledger separates completed evidence, closed branches and the single current next test. Historical handoffs are preserved, but their old next-step lists are superseded.

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
| Automatic lava gate | E066 failed | Shelved; user accepts manual OFF/settle. Keep fast generator. |
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

## Current different architecture: P29 passive melon module

E136 tests a new complete two-deck natural-growth candidate: 132 mature stems, 36 hoppers, two moving hopper carts, 1,803 non-air blocks in 16³. Mud fruit rows, waterlogged hydration slabs, local physical harvest clock, composting, full-buffer stop, local lever and boundary export. Initial bonemeal is zero and steady operation consumes none; natural growth requires a nearby player.

The run generates a versioned schematic, preserves cart startup Motion, then builds **only from decoded exact bytes**. A successful structural file check is explicitly not functional acceptance. Warm-up rejection precedes a 72,000-tick hour, a real five-minute measurement, actual manual OFF/restart/true unload/RUN, and physical full-output/drain scenarios. Fault-injected bonemeal is separate from production.

[E136 Windows run](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38246047435) · [Original P29 builder](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_module_p29_builder.py). Result pending; no performance or winner claim.

## Rules for the next continuation

1. Read the last submitted run and preserve its actual result before making another task commit. Reconnects do not justify rerunning completed tests.
2. Give every new experiment a specific unresolved question, changed mechanic and rejection condition. Run short rejection screens before expensive hour/normal-speed acceptance.
3. Keep an explicit decision when a branch fails. Avoid small timing permutations once a bounded screen rejects them.
4. Component tests never become net-farm proof. Count only actual sustainable inventory surplus, with seed and fault injections handled separately.
5. Finish evidence in GitHub using fresh HEAD leases, preserving simultaneous Club Sana work. Back up the owned V5 world; never alter live worlds.
6. Continue comparing genuinely different architectures. No final winner is selected. Missing final work includes integrated output/TPS comparison, interruption sweep, native client paste, Donut verification and external shulker/storage/sell infrastructure.
