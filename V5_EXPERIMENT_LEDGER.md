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

## Current next test: E140 small-plant nylium economics

This differs from the shelved giant-fungus layout: do **not** grow fungi into trees, use TNT or pay giant-growth/soil-repair costs. A fresh 7×7 static crimson-nylium pad receives 32 single real dispenser doses from a finite 64-bonemeal stock. Seven guarded water sources harvest the small plants into a physical hopper/composter/export chain. No crop resets or inventory conversion/replenishment occur between cycles.

Tutorial literature labels profitable nylium-only farming Bedrock-specific, so this is a **bounded Java economic rejection screen**, not an assumption of viability. Reject an uneconomic fully functioning collector before engineering autonomous recycling. If collection/soil/water fails, record a fixture failure rather than a crop verdict. Provided control pulses do not establish an autonomous farm or hourly throughput.

[Experiment source](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/v5_nylium_roots_net_probe.py). Inspect the E140 run/result first on continuation.

## Rules for the next continuation

1. Read the last submitted run and preserve its actual result before making another task commit. Reconnects do not justify rerunning completed tests.
2. Give every new experiment a specific unresolved question, changed mechanic and rejection condition. Run short rejection screens before expensive hour/normal-speed acceptance.
3. Keep an explicit decision when a branch fails. Avoid small timing permutations once a bounded screen rejects them.
4. Component tests never become net-farm proof. Count only actual sustainable inventory surplus, with seed and fault injections handled separately.
5. Finish evidence in GitHub using fresh HEAD leases, preserving simultaneous Club Sana work. Back up the owned V5 world; never alter live worlds.
6. Continue comparing genuinely different architectures. No final winner is selected. Missing final work includes integrated output/TPS comparison, interruption sweep, native client paste, Donut verification and external shulker/storage/sell infrastructure.
