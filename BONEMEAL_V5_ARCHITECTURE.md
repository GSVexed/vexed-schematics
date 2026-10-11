# Bonemeal V5 — 16×16×16 chunk-aligned production modules

Status: **Architecture selected; no V5 schematic released or functionally tested yet.**

## User-approved design (2026-10-11)

Each module: **maximum 16 wide × 16 long × 16 tall**, **production-only**, with **shared external shulker loading, bulk storage and one sell wall**. Preserve all original V4 assets for reference.

### Inside each production module

- Moss generation, harvesting, item collection, composters and locally recycled bonemeal; initial bonemeal seed may be required.
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

## Immediate next step

Map V4 schematic moss blocks, dispensers, piston harvesters, redstone and composting/collection clusters to understand its production core, without modifying the existing schematic or user world. Then build two candidate core prototypes and test them.
