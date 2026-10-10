# Vexed Kelp Module V2

An eight-cell raw-kelp module with four bonemeal-shulker unloaders, a kelp-shulker loader, a front sell wall, and a separate large store for emptied bonemeal boxes. Footprint **16 × 16**, height **13**. Each stacked module has its own supplies and stop lever; place the next identical origin **13 blocks higher**.

Download `Vexed-Kelp-Module-V2.litematic` into your Minecraft instance's `schematics` folder. Load it in Litematica with **M → Load Schematics**. Follow the complete schematic, including repeater delays, hopper directions, observer directions, glass supports, and the two mud blocks.

## First start

1. Finish the structure with the stop lever **powered / STOP**. The lever is at local **(11, 7, 15)**. Keep it powered while stocking and building.
2. Manually place the water, waterlog all **16 slabs**, and plant the **eight kelp bases**. There are **12 water-source positions**; the other water cells form by flowing. Schematic helpers may require these steps to be done manually.
3. Put **exactly one paper** in the clock hopper at **(14, 7, 14)**. Keep the other seven clock hoppers empty. Survival placement does not copy the schematic's inventory contents.
4. Put full bonemeal shulkers into **all four input double chests** shown below. For the tested setup, use **four full boxes in each chest**. The unloaders place, empty, and replace their working boxes automatically.
5. Put separate **empty shulkers** into the kelp supply chest at **(4/5, 5, 1)**. Start with at least **12**. These boxes become full kelp boxes for the sell wall.
6. For an immediate first start, fill **all nine slots of each of the eight upward-facing growth dispensers** with stacks of bonemeal: **576 per dispenser**, **4,608 total / 72 stacks**. Their positions are **(x, 8, 9)**, where x is **2, 3, 4, 5, 9, 10, 11, 12**. This gives every cell enough meal while the long supply pipes prime. Filling only one dispenser per pair leaves the other cell waiting.
7. Turn the lever **unpowered / RUN**. Keep the module loaded while it operates. Check that every cell grows and harvests, that full kelp boxes arrive in the sell wall, and that empty bonemeal boxes arrive in the return bank.

The dispenser stocking in step 6 is for the first start or recovery after the supply has completely drained. The unloaders provide ongoing bonemeal. The alternative cold start is to leave the stocked module **paused and loaded for about 30 minutes**, then inspect all eight growth dispensers before switching it on.

## Chest locations

Coordinates are relative to the schematic origin **(0, 0, 0)** before rotation or mirroring. The front wall is **z = 0**; increasing z goes toward the back. Coordinates rotate with the schematic.

| Use | Local positions | Capacity |
|---|---|---|
| Full bonemeal shulkers A | x 2/3, y 12, z 3 | 54 input boxes |
| Full bonemeal shulkers B | x 5/6, y 12, z 0 | 54 input boxes |
| Full bonemeal shulkers C | x 9/10, y 12, z 3 | 54 input boxes |
| Full bonemeal shulkers D | x 12/13, y 12, z 0 | 54 input boxes |
| Empty boxes for the kelp loader | x 4/5, y 5, z 1 | 54 empty boxes |
| Full kelp sell wall | x pairs 1/2, 3/4, 5/6, 7/8, 9/10, 11/12; y 0; z 0 | 6 double chests / 324 full boxes |
| Returned bonemeal boxes | x pairs 0/1, 2/3, 7/8, 10/11; y 1, 3, 5, 7; z 0 | 16 double chests / **864 empty boxes** |

Take the returned empty bonemeal boxes from their dedicated bank, refill them, and put them back into the four input chests. They stay separate from the kelp loader's empty-box supply.

The front sell wall is storage for full raw-kelp shulkers, ready for your normal selling routine. Each full box contains **1,728 raw kelp**. No furnaces, dried-kelp production, or automatic server sell commands are included.

## Blocks to keep exact

- Keep both mud blocks under the working kelp box and its side input. They let the lower hoppers collect the broken full box. If the helper refuses to place mud on a hopper, **crouch and place the mud manually**.
- Keep the double chest at **(6, 5, 10/11)** over the raw-kelp feed and the single chest at **(7, 5, 11)** over the empty-box feed. They prevent broken full kelp boxes from entering the feed hoppers. Leave these cover chests in place; use the front supply chest for empty kelp boxes.
- Use the schematic's repeater delays and comparator modes. Place supporting blocks before redstone. Check dust connections against the overlay if they appear as dots or disconnected lines.
- Leave the unloader and loader working-box spaces clear during construction. Stock their supply chests; the dispensers place the working shulkers.
- Keep the input, return, raw-kelp, empty-kelp-box, and packed-kelp pipes connected exactly as shown. Swapping a monitored unloader's output chest for a hopper can eject a source box before it has emptied.

## Running and stopping

The clock uses one bonemeal per active cell every 56 game ticks. Expect roughly **10.3k raw kelp per hour per supplied, loaded module at 20 TPS**. Lower server TPS lowers production per real hour.

Refill all four bonemeal input chests and the separate empty-kelp-box chest. Remove packed kelp boxes from the sell wall and returned bonemeal boxes from the return bank as needed. The loader retains its working full box when the output collector backs up; **the farm has no overall storage-full stop**, so pause the clock before the storage or supply routes become blocked. Leave it paused while changing blocks or diagnosing a stall.

If kelp grows but the sell wall stays empty, first check the kelp loader's separate supply of empty shulkers, then check both mud blocks, the feed-hopper cover chest, hopper directions, and redstone. If only some cells run, check the bonemeal stock in **all eight** growth dispensers and **all four** input chests.

## Replacing V1

For a new build, use the complete V2 file. If V1 is already built, preserve its origin and rotation, pause it, and empty its inventories first. Follow `Vexed-Kelp-Module-V2-upgrade.txt` to remove or replace the old blocks that differ, then finish the complete V2 overlay. Placing V2 over V1 does not automatically remove old blocks that should now be air.

## Test record and credits

The exact final file passed a **72,000-game-tick / one-hour** vanilla Java 26.2 run with natural random growth disabled: **10,288 bonemeal used**, **10,276 kelp collected**, **five full kelp boxes** in the sell wall, **all 16 empty source boxes** returned, and **no loose items or packed boxes in the feed pipes**. Remaining kelp was in the loader's working box. The same file also passed an actual native Java 26.3 hour run: **10,278 kelp collected**, five full sell-wall boxes and all 16 empty source boxes returned. Native stop/restart and 13-block stacking also passed. One loose raw-kelp item remained near the outer edge in that test; no loose shulker was reported. See the accompanying validation record for the full checks. Tests use accelerated game ticks; the farm still runs at the normal clock rate when played at 20 TPS.

The tests import block states and inventories decoded from the delivered `.litematic`. Survival placement, the schematic helper, and DonutSMP plugins are separate from those engine tests; follow the manual fluid, planting, and inventory steps above.

Growth engine and integration: **GSVexed / Codex**. Bonemeal unloader mechanism: **misterkartoffel and sergyd**, [Storage Catalog BU003 Small 1x Box Unloader](https://storagecatalog.org/archives/BU003-Small-1x-Box-Unloader/). Kelp loader adapted from the existing GSVexed/Codex loader with two input hoppers and a cover to keep full boxes out of the feed.

Schematic SHA-256: `b25750fcc8e7e86fefb6ba9a0b9c3d436fffc7369f4ac1883c9c76e38d16f261`.
