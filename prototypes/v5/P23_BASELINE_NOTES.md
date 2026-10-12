# Bonemeal V5 P23 — tested baseline prototype

This original 16×16×16 production module generates stone/moss, harvests, collects, composts, recycles and exports bonemeal without replenishment after its startup prime. It is a preserved working baseline, not the final A-tier design.

## Exact artifact and actual evidence

- File: `Bonemeal_V5_P23_Baseline_Prototype.litematic`
- SHA-256: `a2a9534f4141572d4c0497f83cc4684748c8dd43bde91e0d581b5564bb4af39b`
- Litematica format 7, Minecraft saved-world DataVersion 4903; tested in Java 26.2 Fabric/Carpet lab.
- One 16³ region, 624 non-air blocks, 43 hoppers, 7 rail-mounted hopper minecarts and 59 block entities. Four composters produce bonemeal; two others provide comparator reference levels.
- Starting contents already encoded: 128 bonemeal in the seed dispenser, 6/15 stone clock items, one water bucket; five generator water sources and four sealed lava sources.

[E123 exact-file evidence](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/123-exact-schematic-p23.json): reconstructed exclusively from the file's packed block palette, block-entity inventories and cart positions. +106 net bonemeal over 72,002 game ticks after warmup, consuming 305 growth doses and making 411 gross compost outputs. +9 net over 300.003 real seconds / 6,000 ticks at 20 TPS. External export continued after real lever OFF/settle, saved restart, witnessed chunk unloading, OFF reload and RUN. No monitored cobblestone or water-loss faults. Whole-lab tick readings are not an isolated module TPS-cost measurement.

[E124 same-file fault evidence](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/v5/124-exact-schematic-congestion.json): saturate the external barrel, all seven export hoppers and local output barrel; clocks stop automatically. Restart/unload/reload preserves stopped state. Drain only the external barrel with RUN unchanged: real backpressure releases and production resumes. Complete zero-input start stays stable; re-prime 128 yields 163 after 28,804 game ticks. Supplied full-storage stocks and drained resources are fault-test inputs, never production output.

[Actual workflow and raw evidence](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/38180915573).

## Placement and interfaces

Align the region's minimum X and Z to multiples of 16. Pick a supported normal building height with all 16 vertical blocks inside the world. Local coordinates below are relative to that minimum corner; NORTH is −Z and SOUTH is +Z.

| Interface | Local coordinate | Behavior |
| --- | --- | --- |
| Surplus export | (7,0,15) | Hopper pushes SOUTH into external storage/transport at (7,0,16) |
| Local output buffer | (7,1,9) | 27-slot barrel; automatic full-storage stop |
| RUN/OFF lever | (11,2,9) | Powered/ON = OFF; unpowered = RUN |
| Seed dispenser | (7,7,9) | 128 initial bonemeal already encoded |
| Permanent moss source | (7,8,9) | Keep this source intact |

All shulker loading, empty-box supply, shared storage and the eventual sell wall remain external to this region. The test witness barrel is excluded from the schematic/module. Attach an external inventory at the export coordinate so the module can empty its buffer.

The file includes cart entities in their intended positions, so a creative paste that includes entities should not require manual cart pushing. It also includes inventories and fluid blocks. Native Litematica client import/paste and its update ordering remain unverified: E123 proves actual Minecraft operation after server reconstruction from these exact bytes, not native client-paste behavior.

For planned unloading or restart, use the real lever OFF and let the module settle at least 480 game ticks (24 seconds at 20 TPS). Live unloading previously failed fluid recovery; this prototype uses the user-approved manual OFF procedure. Do not use a command that merely replaces the lever state as an equivalent: real lever operation was necessary to notify the stop circuit in testing.

## Remaining engineering

Measured output is modest and the strongest architecture is still being investigated. Native paste, interruption phase sweeps, two/four-module scaling with idle-relative cost, Donut-specific mechanics and shared shulker/storage/sell infrastructure remain unfinished. Preserve this prototype while higher-output candidates are tested. V4 geometry was not used as a template.
