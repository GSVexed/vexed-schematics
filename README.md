# Vexed Schematics

Download the same Minecraft Litematica files used by GSVexed.

## Bonemeal factory V4

[Download the complete bonemeal farm](https://github.com/GSVexed/vexed-schematics/raw/main/bonemeal.litematic)

This is the corrected full four-module layout: two double modules, the second on the right when viewed from the front sell wall, one shared sell wall, and one master lever.

Put the downloaded `.litematic` file in your Minecraft instance's `schematics` folder, then load it with Litematica (M → Load Schematics).

For an existing first double module, align its bottom module origin with local **(20, 1, 2)** in the full schematic. Match the same rotation. The second pair lies 20 blocks along the first pair's negative local X axis, leaving a four-block gap. Do not move the first pair.

[Expansion-only schematic](https://github.com/GSVexed/vexed-schematics/raw/main/bonemeal-expansion.litematic) · [Connection schematic](https://github.com/GSVexed/vexed-schematics/raw/main/bonemeal-connection.litematic)

These component origins are relative to the first pair: expansion **(-20, 0, 0)**, connection **(-20, -1, -2)**. The complete farm file already includes both.

Keep the main lever powered/paused while building. Install carts and fluids manually, seed each growth dispenser with 64 bonemeal, and stock empty shulkers. After construction, verify that all four modules respond to the first pair's lever.

Design credit: BasicRedstone / DaveRooney; Codex integration and right-side connections. These are the user's existing files, published unchanged. Native Java 26.3 validation is documented with the project; live DonutSMP testing and chunk-unload reliability are not claimed.
