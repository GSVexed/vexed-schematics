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

## Kelp module V1

[Download the kelp module](https://github.com/GSVexed/vexed-schematics/raw/main/kelp.litematic)

Original eight-cell raw-kelp build by GSVexed / Codex. **16 × 16 footprint, 13 high**, matching one bonemeal module. Stack identical independent modules at 13-block vertical spacing.

The final file passed a 72,000-tick vanilla Java 26.2 test with natural growth disabled: **10,288 bonemeal used, 10,272 kelp delivered to the output chests** (99.84% collection). Roughly **10.3k raw kelp per hour at 20 TPS** per loaded, supplied module. Native Java 26.3 also passed import, harvest, stop/restart, 13-block stacking, refill recovery, and age-25 kelp tests.

Build paused. Set water and plant the eight kelp bases manually in survival. Use exactly one paper in the clock hopper at local **(14, 7, 14)**. The stop lever at **(11, 7, 15)** is powered for STOP, unpowered for RUN. Empty output before storage fills.

[Setup guide](kelp-setup.md) · [Validation record](kelp-validation.txt)

SHA-256: `3385bd9abbc084badcde574df71f645b3867ce69d284a89e19a10a3cf0efbbdd`.
