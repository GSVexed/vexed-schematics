# Booga Reborn: Raw Gold → Gold smelting authority audit (v1)

**Date investigated:** 17 November 2026.
**User goal:** Determine whether one can convince the live server that
Raw Gold has been smelted and receive real Gold **without any Raw Gold
having existed**. This report distinguishes exact *client archive
evidence*, inference, public wiki context and unknown server behaviour.

**Source:** Original user-uploaded `UPLOAD_PART_010_DATA(1).zip`.
Although the filename implies a single part, it contained all 11
parts. This investigation reopened the exact ZIP, used its existing
index to reconstruct and inspect every **438 exported game-classified
source bodies**, examined pertinent object rows, and traced cooking,
structures, items, pickup, inventory and stats modules.

**Scope and limits:** This is static, privacy-filtered **client**
reconstruction from PlaceId `11729688377`, captured on game place
version `32961`; the server game scripts and persistent inventory
database are *not* available. No server packets or balance-modifying
actions were sent during investigation.

## 1. Verified item identities and relevant client data

| Thing | Recovered information | Source |
|---|---|---|
| Raw Gold | `Modules/data/itemIDS["Raw Gold"] = 258` | `9392.luau`, around 2251 |
| Gold | `Modules/data/itemIDS["Gold"] = 597` | `9392.luau` |
| Conversion definition | `cooksTo = {name = "Gold", steps = 100}` | `9390.luau`, around 37–43 |
| Normal Gold item | `gold=true`, `cost=12`, `amount=1`, `shopOrder=21`, `load=.5` | `9390.luau`, 11102–11112 |
| Raw ore in world | Three `Workspace/Items/Raw Gold` MeshParts with distinct `EntityID`, `Pickup`/`Entity`/`Draggable` tags | original ZIP `objects/game_*.ndjson.txt` |
| Cooking progress remote | `game/ReplicatedStorage/Events/cookingStream`, a `RemoteEvent` | original ZIP object row |
| Live Coin Press | `Workspace/Deployables/Coin Press` Model with `EntityID` and `deployable`/`Entity` tags | original ZIP object row |

**Caution about recovered `itemData/data`:** the decompiler
reuses/reassigns `t3`: both `Raw Iron` and `Raw Gold` end up
referencing `t3` in the reconstructed final table, although
separate initial literals indicate Iron's 60-step and Gold's
100-step cooking recipes. Treat final aliased table equality as
a reconstruction artifact, not proof the live game would
accidentally turn iron into gold.

The archive's **100 steps** are a client-defined goal. An
independent resource wiki describes Gold as smelting in
approximately **100 seconds**, but that real-time conversion
is not established solely by the decompiled code.
- https://www.booga.gg/wiki/resources

## 2. Crucial finding: cookingStream is *server-to-client progress*

File: `game/ReplicatedStorage/Game/cooking` (**source ID 10384**).

It:
1. Obtains the `Events/cookingStream` RemoteEvent.
2. Connects an `OnClientEvent` callback to read a network buffer.
3. Reads a **float64 timestamp** at offset 0.
4. For each 11-byte cooked-item record, reads
   **u32 existing entity ID**, **float32 progress base**,
   **u8 rate**, and **u16 progress goal**.
5. Finds the local visible entity through `Game/entities.getEntity`.
6. Updates a *local* progress UI by calculating
   `(base + (now-since)*rate)/goal`, clamped 0–1.
7. Removes or hides progress UI for objects no longer
   present or no longer reporting a positive rate.

**We found no `cookingStream:FireServer`, no outgoing
`CookItem` or `SmeltComplete` packet, and no local
request like `GrantGold` in the recovered client.**
In particular, changing the displayed progress to
100% does not invoke a real smelt or award Gold.

Important nuance: reconstructed `Game/cooking` contains
nonsensical variable reuse around `ReplicatedStorage` and
the GUI definition; it is decompiled, not valid original
Studio source. The `OnClientEvent`, buffer field layout and
display-only update flow are clearly visible nonetheless.

## 3. How actual items reach the fire

File: `Game/inventory` (**source ID 10366**):
- Inventory items are displayed and indexed in
  `gameUtil.Data.inventory`.
- Right-click/drop sends typed `DropBagItem` with
  **a bag-index/key**, not a new item descriptor.
- Raw Gold must have a real inventory entry in the
  authoritative game state for that to be a real world drop.
- `ItemAdded`, `ItemChanged`, `ItemRemoved` and
  `UpdateInventoryFromRebirth` are incoming
  `.listen` calls that reconcile the UI.

File: `Game/tutorial` (**source ID 10372**):
- Teaches cooking with Raw Meat. The exact instructions
  tell the player to drop the item beside a lit Campfire.
- Then the tutorial watches for a **new cooked world drop**
  and instructs pickup.
- This is strong evidence that ordinary ore smelting
  follows the same *physical world-item transformation*
  pipeline rather than crediting the player's inventory
  directly on a completion message.

File: `Modules/data/patchNotes` (**source ID 9396**):
- Contains the update note that items smelted **in a chest**
  now reattach to the chest **when the smelted material spawns**.
- Again, this points toward real world objects with entity
  state, not a button in the client awarding a Gold balance.

External game-specific wiki also says raw ores cook by
being placed **near a Campfire**, and multiple fires
can increase cooking speed:
- https://booga-booga-reborn-wiki.fandom.com/wiki/Cooking/Smelting

## 4. Fuel and structure interactions are a different API

File: `Game/structures` (**source ID 10350**).

The `Campfire` and `Christmas Fireplace` menus filter
the player's **existing inventory** to entries whose
`itemData` declares `fuels`, then submit:
`InteractStructure.send({entityID = selected campfire,
itemID = selected fuel})`.

This means **a fuel-add request, not a finished-smelt
notification**. Coal has `fuels=100` in the
client item data.

Other structure interactions use the **same** typed
`InteractStructure` packet:
- `Coin Press`: chooses a real inventory item whose
  item-data entry has `gold=true`. The client
  sends the selected Coin Press `EntityID` plus
  selected gold item ID.
- `Pot o' Gold`: similar selection.
- `Grinder`: selection by `grindsTo`.
- `Saw Mill`: selection by `cutsTo`.
- `Plant Box`: selection by `grows`.

A request containing `itemID=597` is **not** an
authoritative proof of possession. To mint gold/coins
without owning inputs, a flaw would have to exist in the
**server's structure transaction checks**, which are
not disclosed by the client archive. We did not demonstrate
such a flaw.

## 5. Where coins enter the picture

There are two separate concepts:

1. **Gold** = physical or inventory material (ID 597).
2. **Coins** = player economy currency. `Game/stats`
   (source 10326) listens to `UpdateStats`/
   `UpdateStatsUnreliable`, which update
   `gameUtil.Data.coins` and HUD text.

Community sources say the Coin Press yields
**5 Coins per 1 Gold**, which would mean
six Raw Gold from a typical Gold Node is
**up to 30 Coins** after 1:1 smelting and pressing,
before costs and eligibility. This is not
a verified live balance conversion.
- https://booga-booga-reborn-wiki.fandom.com/wiki/Coin
- https://www.booga.gg/wiki/structures
- https://www.booga.gg/wiki/resources

The reconstructed Gold shop definition advertises
`cost=12` coins. If its current shop price
is really 12 coins and Coin Press payout really 5,
buy-to-press arbitrage would lose 7 coins/Gold.
They are data from different evidence scopes;
not guaranteed simultaneous live prices.

## 6. The Smelter Mojo is different from a fake smelting receipt

`Modules/data/itemData/data` source 9390 contains
a `Smelter` Mojo with four client descriptions:
- Tier 1: 10% chance a particular mined ore auto-smelts.
- Tier 2: 25%.
- Tier 3: 40%.
- Tier 4: 50%.

The `Smelter` item ID is `1054`; the same archive's
patch notes say this Mojo is toggleable. These
descriptions are client data; we did **not** see
the private server's roll or reward handler.

This is a **legitimate way of skipping campfire
processing for some real ore**, not a proven way
of producing Gold from an ore that never existed.

## 7. Completeness of client-source search

All **438 exported game-classified source bodies**
were reconstructed from the original ZIP and scanned.

| Term | Modules where present |
|---|---:|
| `cookingStream` | 1 (`Game/cooking`) |
| `cooksTo` | 1 (`Modules/data/itemData/data`) |
| Case-insensitive `smelt*` | 3 (item data, item IDs, patch notes) |
| `InteractStructure` | 4 (structures, market, Hoe, packets) |
| `DropBagItem` | 2 (inventory and packet schema) |
| `ItemAdded` | 2 (inventory and packet schema) |
| Client `Cook*.send` or `Smelt*.send` | **0** |

The **absence of a named send call in reconstructed
client sources is not a proof that no server flaw
exists**. It shows there is no obvious client
"smelt succeeded" request to falsify.

The captured world contained:
- **3 actual Raw Gold world item MeshParts**,
- **1 actual Coin Press deployable**,
- **no active Workspace Campfire**, though the
  Campfire model template exists in ReplicatedStorage.

Accordingly, this snapshot cannot show a live
Gold smelting transition or the server's transaction
details. Source content is sometimes decompiler-corrupted.

## 8. What the proposed false-input scheme would require

The user's suggestion was to send believable
metadata stating Raw Gold existed and is now
smelted, with no original Raw Gold resource.

The client protocol in this archive supplies
**no evident report of smelt completion**.
Instead, the observed flows use (a) authoritative
inventory/drop world entities, (b) incoming cooking
progress, (c) creation of an actual cooked world
item, (d) normal pickup of that existing
entity ID and (e) server-fed inventory updates.

Without a server-side validation defect, a
fabricated raw ore, a made-up entity ID, or
a forged displayed progress bar would not
create a legitimate Gold or Coin balance.
A server defect is not proven or ruled out,
because private code is inaccessible.

**A reliable unlimited Gold spawner, duplication
method or profitable exploit has not been
discovered from this archive.** No money minting
claim should be made on the basis of these data.

## 9. Productive next steps

If prioritising **real money instead of looking
for a minting exploit**:
- Measure normal Gold Node yields and the
  real Coin Press payout in a current server;
  observe incoming replicated balances.
- Use Smelter Mojo where actually owned/
  available to skip some campfire work.
- Process ore in bulk near a fuelled
  Campfire and stage items in a chest
  where the current game supports it.
- Build an ore locator, collection timer,
  cooking progress and Coin Press assistance
  tool using **existing world objects**.
- Compare all of that with current market
  sale prices; no invented profits.

**Main finding:** There is no visible
client-side smelting-completion message to
spoof for a gold reward. The real conversion
appears to run as a server-controlled
world-object transformation.
