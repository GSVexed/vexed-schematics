# Booga Booga Reborn — Voodoo regeneration authority audit
**18 November 2026 | PlaceId 11729688377 | Archived game version 32961**

## Goal and scope
The goal is a genuine server-accepted increase in Voodoo regeneration, or server-approved damaging Energy Bolts without normal Voodoo spending. Repeated packet attempts are **not** a success criterion.

Reopened the user's recovered `UPLOAD_PART_010_DATA(1).zip` and script index, inspected the original archived reconstructed game source, and content-searched every game-source file. The index records 451 game-classified entries: **438 exported**, 11 not-client-source and 2 API-error entries. The captured script code is **client-side**, not original developer server code; the absence of an exposed exploit is not proof that no server bug exists.

A full search located `voodoo` in 15 canonical source files, `SetBoost` in two, `VoodooSpell` in three, `UpdateStats` in two, `UseBagItem` in two, and `ToggleMojo` in two. No client-side numeric Voodoo regeneration calculator was recovered. Examined full bodies for spells, stats, boosts, boost data, armor, inventory, Mojo, packets, gameUtil, cooking, crafting, cauldron, spawning, weather/void, item definitions and patch notes.

## Source-backed authority map

| Path / source | Actual operation | Finding |
|---|---|---|
| `Game/spells` S0010320 | Sends `VoodooSpell.send({targetPos,aimDirection})`, based on own selected spell; local Voodoo controls animation, not sending | Sending more requests does **not** establish accepted extra damage |
| `Game/stats` S0010326 | Listens for `UpdateStats` and `UpdateStatsUnreliable`, updates `gameUtil.Data.voodoo` and HUD | Local Voodoo cache edits do not create authoritative Voodoo |
| `Game/boosts` S0010367 | Listens for incoming `SetBoost` and `RemoveBoost`; creates visible icons, percent and duration | **Display-only path**; no `SetBoost.send` route found |
| `Game/boosts/data` S0010368 | Lists `Voodoo Passive`, `Void Armor`, `Jelly Sandwich` as “Flat voodoo boost” | Descriptions, not a server regen formula |
| `Game/armor` S0010324 | Incoming `UpdateArmor` sets `Data.armor`; sends `UnequipArmor` on user click | Wearing genuine armor is an actual game state; altering the local view is not |
| `Game/inventory` S0010366 | `UseBagItem` sends an **inventory item key** after looking up own item and lock status | Credible action for an **owned** item; no demonstrated ability to activate nonexistent items |
| `Game/mojos` S0010323 | Uses `PurchaseMojoItem` and `ToggleMojo` with item IDs; toggle checks ownership and toggleable | **Spellmaster is passive, not toggleable**, and costs 3 Mojo Points |
| `Game/weather/void` S0010361 | Starts local weather lightning visuals | Not a damaging free `VoodooSpell` alternative |
| `Modules/data/itemData/data` S0009390 | Energy Bolt `voodooCost=30`, `damage=35`; description says 30 AOE | Distinguish definition from server-accepted impact |

## Regeneration candidates

**Void Armour:** Three pieces `Void Shroud`, `Void Chestplate`, `Void Greaves`. Server-recognised equipping should correspond with actual `UpdateArmor` and a change in Voodoo progression, not a local inventory flag.

**Void Bag:** Reborn wiki reports **0.5 Voodoo/second**. The similarly named **Void Pouch does not regenerate Voodoo**. Current strength and stacking on live servers need measurement.

**Spellmaster:** The recovered item definition says “Extra voodoo Regeneration” and specifies 3 Mojo Points. It is a passive upgrade; repeatedly invoking `ToggleMojo` on it is not a grounded activation mechanism.

**Jelly Sandwich:** Reborn wiki reports a **20% Voodoo boost for 30 seconds**. Multiple consumptions reportedly **refresh duration rather than stack**, so a rapid-use loop is not a promising multiplier. Source `boosts/data` describes a flat Voodoo boost without an authoritative numeric formula.

**Dimension:** Archived `patchNotes` S0009396 historically says Voodoo regeneration was **1.5× in the overworld vs 2× in the Void**. Treat that as historical patch text, not proven current server behaviour. Weather visuals do not grant Voodoo.

External verification: [Reborn Spell](https://booga-booga-reborn-wiki.fandom.com/wiki/Spell) · [Reborn Food](https://booga-booga-reborn-wiki.fandom.com/wiki/Food) · [Reborn Bags](https://booga-booga-reborn-wiki.fandom.com/wiki/Bags) · [Reborn Pouch](https://booga-booga-reborn-wiki.fandom.com/wiki/Pouch) · [Mojo shop](https://www.booga.gg/wiki/rebirth).

## Throughput requirement
At 30 Voodoo per Energy Bolt, sustained throughput requires:
- 1 accepted bolt/s: **30 Voodoo/s**
- 2 accepted bolts/s: **60 Voodoo/s**
- 4 accepted bolts/s: **120 Voodoo/s**

The normal Voodoo capacity is 100 according to the Reborn wiki. No evidence supports server-recognised regen approaching these values. Packet attempt counts and local effect displays must never be reported as actual damaging strikes.

## Candidate conclusions
- **Rejected as evidence:** editing `Data.voodoo`, editing client item cost, simulating `SetBoost`, spamming packets at zero Voodoo, visual weather lightning, spoofing local ownership.
- **Credible but bounded:** genuinely equip **owned** Void gear/bag, purchase Spellmaster via normal UI, consume **owned** Jelly Sandwich, use valid area-specific bonuses.
- **Unproven:** obtaining actual buffs without ownership, increasing server regeneration rate with client-controlled fields, or free damaging casts. The blacklisted zero-cost ray definitions are not normal authorised spells.

## Decisive live test
Perform **one-variable-at-a-time** comparisons at below 70 Voodoo, with no casting during each 20–30 second window:
1. No sources, then each owned source individually, then combinations; compare the Void versus overworld as separate conditions.
2. Observe native `UpdateArmor` after equipment, `ItemChanged`/`ItemRemoved` after genuine consumable use, `SetBoost` for duration only, and **`UpdateStats` Voodoo deltas as the decisive outcome**.
3. Do not use or spend consumables/Mojo automatically; never add fabricated buff values. Exclude repeated sandwiches because non-stacking is reported.
4. Calculate accepted bolt throughput from actual Voodoo spending and (where measurable) resulting damage—not outbound request counters. Receiving an `EnergyBolt` visual alone may reflect another player's cast.
5. Only build another hub if an effect yields a measurable real increase, a practical owned-effect optimisation, or a genuinely distinct server-recognised effect. No more disguised packet-loop versions.

**Verdict 18 Nov:** No confirmed server-recognised spoofed regeneration, unlimited Voodoo, or zero-cost damaging Lightning mechanism was found. No v6 “breakthrough hub” published on this evidence.
