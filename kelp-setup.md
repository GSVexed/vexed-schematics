# Vexed Kelp Module V1

A self-contained raw-kelp module for GSVexed. **16 × 16 blocks, 13 blocks high**, matching the footprint and height of your single bonemeal module. Eight growth cells, four input double chests, and twenty output double chests. No fuel, furnace, crafter, or shulker loader is required.

## Load and place

Put `Vexed-Kelp-Module-V1.litematic` in your Minecraft `schematics` folder, load it in Litematica, then create a placement. For Lunar, use the Minecraft folder belonging to the Lunar instance you actually launch.

The origin is the lowest north-west corner of the 16 × 16 outline. The chest fronts face local north, toward decreasing Z. The tested orientation is the orientation saved in the file. Coordinates below are **local X, Y, Z offsets from the schematic origin**, not world coordinates.

| Part | Local position |
|---|---|
| Input chest pairs | X = 2–3, 4–5, 9–10, 11–12; Y = 9; Z = 5 |
| Output chest pairs | Same X pairs; Y = 0, 2, 4, 6, 8; Z = 2 |
| Master stop lever | (11, 7, 15) |
| Put the single clock paper here | (14, 7, 14) |
| Eight kelp bases | X = 2, 3, 4, 5, 9, 10, 11, 12; Y = 9; Z = 9 |
| Waterlogged front ledges | Same eight X values; Y = 10; Z = 8; **bottom slabs** |
| Waterlogged cell caps | Same eight X values; Y = 11; Z = 9; **top slabs** |
| Four still-water side buffers | X = 1, 6, 8, 13; Y = 10; Z = 9 |
| Ladder | (7, 1–8, 4) |
| Second module origin | First origin + (0, 13, 0) |

## Build and start

1. Build the dry blocks first. Keep the stop lever **powered** and all clock hoppers empty. Follow the hopper directions and repeater delays in the schematic. The eight harvest repeaters behind the pistons have **four-tick delay**; the other repeaters have one-tick delay.
2. Waterlog the eight bottom ledge slabs and eight top cap slabs. Put a source in each of the four side-buffer positions. Fill each plant-base position with water, then plant one kelp on each upward dispenser. Leave each plant only one block tall. The collection current runs across the higher row, at Y = 11.
3. Put **exactly one paper**, not a stack, in the clock hopper at (14, 7, 14). Leave the other seven clock hoppers empty. With the lever powered, the paper moves to the locked part of the loop and stops.
4. Fill the four input double chests on the accessible front landing. Use bonemeal only. Give the feed hoppers about ten seconds to prime.
5. Flip the lever to **unpowered** to run. Kelp should grow, be cut, float into the raised collection hoppers, and reach the front storage banks. Check all four banks during the first minute.
6. Flip the lever back to **powered** to stop. Allow the last pulse and items already in transit to finish. Clear output chests before the twenty double chests fill.

Survival Litematica placement does not install hopper inventory or water for you. Even if the ghost shows a planted crop, you still need to place the water and eight kelp bases manually. Creative pasting may restore the saved clock paper; inspect the clock before adding another.

Each stacked module has its own lever and paper. Stack at **13-block vertical spacing**, with the same rotation and X/Z origin. This is an independent kelp build; it is not a connection module for the bonemeal farm.

## Output and cost

The twenty output double chests hold **69,120 raw kelp**, with additional hopper buffering. Input capacity is four double chests, **13,824 bonemeal**, plus feed/dispenser buffering. There is no automatic storage-full shutoff. Empty the output regularly or pause the farm.

The final file ran for **72,000 game ticks (one hour at 20 TPS)** in vanilla Java 26.2, with natural growth disabled. It used **10,288 bonemeal** and delivered **10,272 raw kelp into the output chests**, after 600 settling ticks. That is **99.84% collection**, about **1.002 bonemeal per collected kelp**. The clock cycles every 56 game ticks.

Expect roughly **10.3k raw kelp per hour per module at 20 TPS** while loaded and supplied. Lag reduces the real-time rate. Two independent stacked modules would nominally double that rate; the one-hour measurement is for one module.

A bonemeal-fed kelp farm needs a cheap bonemeal supply. Compare the current sell price of raw kelp with the value of the bonemeal you spend; feeding bonemeal into kelp is not automatically more profitable than selling that bonemeal directly. No current DonutSMP price or profit is assumed here.

## Placement helper notes

For blocks on hoppers or chests, **hold sneak (usually Shift) while right-clicking** with the required block selected. If assisted placement refuses, temporarily turn Easy Place off and place that block manually. This also applies to mud on hoppers in your bonemeal build.

In Litematica, `easyPlaceMode` is in the Generic configuration tab. Multiplayer servers without the matching placement protocol cannot reliably supply every orientation automatically. The project's official [Easy Place documentation](https://github.com/maruohon/litematica/wiki/Easy-Place) recommends `Auto`, `Slabs Only`, or `None` for those servers. Verify hoppers, upward dispensers, north-facing pistons, and slab halves visually; do not assume a successful click means the orientation is right.

If nothing runs, check the one paper, eight hopper directions, lever state, and bonemeal feed. If growth works but storage stays empty, check the Y = 11 water current, all sixteen waterlogged slabs, the four still-water buffers, and collection hopper directions. Use the verifier after the dry build, then inspect water and inventories separately.

## Validation scope

The exact delivered `.litematic` was independently decoded, imported, and tested in the **vanilla Java 26.2 engine** for one simulated hour. Static checks also cover its 16 × 13 × 16 bounds, block entities, redstone supports, and paired chest states. The **native Java 26.3 engine** also passed the exact-file import, paused start, running harvest, stop/restart, **13-block stacking**, empty/refilled supply, and forced age-25 kelp tests. Its 1,200-tick run used 176 bonemeal and stored all 176 kelp, with no floating drops after settling.

Tests use actual Minecraft block, fluid, inventory, and entity behavior. Server plugins, live DonutSMP rates, lag, and chunk unload/reload behavior are separate conditions; they have not been certified by these tests. Keep the farm loaded while it runs, and pause before leaving it.
