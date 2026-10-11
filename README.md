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

## Kelp module V2

[Download the kelp schematic](https://github.com/GSVexed/vexed-schematics/raw/main/kelp.litematic) · [Download the complete V2 pack](https://github.com/GSVexed/vexed-schematics/raw/main/kelp-v2-pack.zip)

Eight-cell raw-kelp farm by GSVexed / Codex: **16 × 16 footprint, 13 high**. Four bonemeal-shulker unloaders supply the cells, and the kelp loader packs the output into shulkers. Stack identical independent modules at 13-block vertical spacing.

The **six-double-chest sell wall** receives full kelp boxes. Emptied bonemeal boxes go to a separate **16-double-chest return bank (864 boxes)**, ready to refill. The kelp loader has its own separate empty-box supply.

The exact final file passed actual Java 26.2 and native 26.3 engine tests, including a full game hour, box routing, stop/restart and two-module stacking. Production is roughly **10.3k raw kelp per game hour at 20 TPS** per loaded, supplied module. See the validation record for measured counts and test scope.

Build paused. Stock all four full-bonemeal-box inputs and the separate empty-kelp-box chest. For an immediate first start, fill all nine slots of each of the eight growth dispensers with bonemeal; the long feed pipes prime while it runs. Place water, waterlogged slabs and the eight kelp bases manually. Use exactly one paper in the clock hopper at local **(14, 7, 14)**. The stop lever at **(11, 7, 15)** is powered for STOP, unpowered for RUN.

[Setup guide](kelp-setup.md) · [Materials](kelp-materials.txt) · [V1 replacement checklist](kelp-upgrade.txt) · [Validation record](kelp-validation.txt)

Growth module and integration: GSVexed / Codex. Bonemeal unloader mechanism: misterkartoffel and sergyd, [Storage Catalog BU003](https://storagecatalog.org/archives/BU003-Small-1x-Box-Unloader/).

SHA-256: `b25750fcc8e7e86fefb6ba9a0b9c3d436fffc7369f4ac1883c9c76e38d16f261`.

[Archived V1 schematic](https://github.com/GSVexed/vexed-schematics/raw/main/kelp-v1.litematic).


## Schematic quality checks

Every committed `.litematic` is now checked by [automated structural CI](https://github.com/GSVexed/vexed-schematics/actions/workflows/validate-schematics.yml) using a portable, standard-library NBT decoder. The first verified run on 2026-10-11 passed all five tracked schematics: [see actual test result](https://github.com/GSVexed/vexed-schematics/actions/runs/38136857710).

These checks detect malformed block-state data, invalid palette indices, duplicate or out-of-bounds block entities, and metadata problems. **They do not establish that a farm produces items or remains reliable after lag/chunk unloads.** Functional testing requires real Minecraft engine tests, and Donut SMP server-specific claims require separate observation. See the [bonemeal V4 reliability and benchmarking plan](BONEMEAL_V4_VALIDATION_PLAN.md).
