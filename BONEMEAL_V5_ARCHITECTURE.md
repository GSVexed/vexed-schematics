# Bonemeal V5 — 16×16×16 independent production modules

**Superseding acceptance, 12 October 2026:** [Master engineering directive](V5_MASTER_ENGINEERING_DIRECTIVE_2026-10-12.md) is authoritative. Moss is the leading technology. The final machine must unload/reload and restart **while RUNNING at arbitrary phases**, automatically recover without user intervention, and protect seed and output under congestion. Manual OFF + settling is experimental preservation only; it no longer satisfies final acceptance.

P23 (+106 net/game hour) and P30 (+149) remain preserved baselines, neither a final high-performance release. E143 repaired P31's descending signal supports and passed 15 continuation cycles of two vertically separated fields with two moving carts, ending +33 net including the earlier shot. That is supplied-sequence component evidence, **not** an autonomous hourly benchmark, fresh exact-file acceptance or running-unload proof. Gate further complete-module integration on generator running-unload evidence.

Benchmark **one original single module** (16×13×16, SHA-256 `1d51b0f0aa9575f2a6d5943588b6b6d2dd02d4fb8620649e0c628e0de82bc591`) against one complete V5 module; the four-module factory is a separate asset. Finalists need actual production and normal-TPS runs, idle-relative MSPT, two/four-module tests, varied RUN-state interruptions (target at least 100), native Litematica paste and precisely reported Donut limits.

## Preserved earlier architecture and history — superseded where inconsistent

## User-approved design (2026-10-11)

Each module: **maximum 16 wide × 16 long × 16 tall**, **production-only**, with **shared external shulker loading, bulk storage and one sell wall**. Preserve all original V4 assets for reference.

### Inside each production module

- Independent generation, harvesting, item collection, composting and locally recycled bonemeal; material choice remains open and initial bonemeal seed may be required.
- Positive **net** bonemeal surplus after startup, not just impressive gross harvest counts.
- Exactly one documented surplus output interface, a small bounded output buffer and backpressure-safe stop behaviour.
- Independent local run/stop plus optional shared master STOP; a single disabled module must not break other modules.
- Keep clock and recycling machinery local so external shulker storage is never necessary to operate a standalone module.
- Minimise always-active hoppers, moving entities and redundant redstone while preserving reliability.
- Exact 16×16 horizontal footprint must be deliberately aligned to the chunk boundary; height 16 is a **maximum**, not a requirement to waste space.

### Outside the module

- Multiplexed bonemeal collection and transportation.
- Central shulker loaders, fresh empty-box supply and bulk storage.
- One shared sell wall.
- Output congestion handling and isolation of a stalled module from the shared transport network.
- Shared master STOP wiring optional; recycling independence is not negotiable.

## Physical interfaces — positions to be fixed after geometry trials

- **BONEMEAL_OUT**: one consistent side/height/orientation for every module with a buffered, backpressure-safe interface.
- **RUN/STOP**: local fail-safe stop control with optional shared STOP bus. Document power polarity.
- **SERVICE**: accessible bonemeal startup prime and maintenance access.
- **NO INTERNAL SHULKER MACHINERY**: all shulker packing and box management belong to the external system.

## Research tracks

A. Existing V4 compact core as performance and failure-mode baseline.
B. Throughput-focused moss variant: growth-pad area, dispense interval, harvest mechanics, pickup efficiency.
C. Reliability/TPS-focused moss variant: simpler clock, reduced idle activity and safer stop/start/backpressure.

Compare by **verified net bonemeal/hour**, TPS cost, uptime, restart robustness, materials, and compactness. Every benchmark must document exact schematic SHA-256, game version, ticks and prime inventory.

## Tests required before recommending a new schematic

1. Import the exact final Litematica into an isolated Minecraft engine; validate real spreading, harvesting, composting and local recycle. A hopper/composter smoke test is not enough.
2. Record a sustained 72,000-game-tick run, net of initial seed and outside inputs.
3. Force storage-full, depleted seed, master stop, local stop, lag, chunk unload/reload, and interrupted harvesting states.
4. Operate two modules and then four modules feeding shared transport; measure per-core output and common-output bottlenecks.
5. Explain vanilla/Carpet versus Donut SMP differences, especially anti-lag and TPS.
6. Final delivery requires exact installation position, prime inventory, water/cart requirements, schematic checksum, tested variant, and setup instructions.

## Project mandate: original A-tier engineering, not a V4 upgrade

The user has explicitly confirmed that V4 was based on another builder's design and subsequently enhanced. **Do not use V4 as a V5 schematic template.** Reference its performance only. The goal is radical 16×16×16 spatial and throughput optimisation using new growth, stone-generation, harvest, recycling and congestion-control circuitry. Investigate unconventional architectures where worthwhile; measure rather than assume. See [original R&D programme and engine test data](BONEMEAL_V5_FROM_SCRATCH_RND.md).

## Current engineering status

- Verified the exact V4 component geometry on the PC for historical benchmarking.
- Verified bottom-fed moss dispenser behaviour, 7×7 and 5×7 growth yields, 5×5 growth yields and 4/4 independent 5×5 simultaneous sources inside one chunk, on a real Minecraft Java 26.2 engine.
- Evaluated five theoretical 16×16 grow-pad packings; **no automated closed-loop V5 core has yet been built, measured or released**.
- **Next step:** create and prove a renewable, reload-resistant stone generator and moss harvester within the 16³ envelope. After validating production and collection, add parallel composting, local recycling and output backpressure.

## V4 structural mapping completed — 2026-10-11

The exact V4 schematic was decoded on the user's real PC using a SHA-256-checked reference, with coordinate-order verification of **555 out of 555** block entities. [Successful inspection workflow](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38140353271).

- Four moss seeds at V4-local coordinates **(7,8,10), (27,8,10), (7,22,10), (27,22,10)**: 20-block horizontal spacing and 14-block vertical spacing.
- **8 dispensers and 8 droppers**, including machinery beyond the growth dispenser at each seed.
- **44 composters:** 22 in the lower layer (Y=7), 22 upper (Y=21); **11 composters per production level/column combination**.
- Full factory totals: **487 hoppers, 579 redstone wire, 120 pistons, 116 sticky pistons**. These include shared transport, control and storage parts; don't assume each core has one quarter of the hoppers.
- V4 full footprint is **36×29×18** in its one schematic region, including shared infrastructure.

**Implication:** The V5 goal is not just to copy an old mechanism into an extra three vertical blocks. Benchmark standalone V4 cores first, then compare simplified recycling/transport and an independently controllable local core. The existing V4 geometry does not establish how many hoppers are actually needed per independent core.

**Still unknown:** V4 per-module net production, effective compost/feed capacity, reason the user's modules stalled, and whether the machine reliably restarts after chunk unloading. The above analysis is structural and is not an in-game functionality PASS.

## Latest engineering continuation — 2026-10-11, 16:15 UTC

Read the [current development checkpoint](BONEMEAL_V5_DEVELOPMENT_2026-10-11.md) before older status entries. The user accepts switching off before unloading and explicitly wants the 48-tick generator retained in the performance comparison. That variant failed accidental live unload; a tested OFF/settle/unload procedure is necessary. The unsuccessful lava-shutoff branch is shelved to conserve usage. Original P01–P04 full-volume prototypes exist but have not achieved automatic growth or positive net output. The final architecture and speed remain open. Stationary carts on ordinary rails, partial-height block pickup and water-to-hopper pickup have been tested; collection convenience is an engineering criterion, not a substitute for performance.
