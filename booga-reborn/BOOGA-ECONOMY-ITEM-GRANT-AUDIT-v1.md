# Booga Reborn — Item spawning and money routes (source audit v1)

**Target:** Booga Booga Reborn, PlaceId `11729688377`, archived place version 32961.
**Evidence:** The user's uploaded, integrity-verified
`UPLOAD_PART_010_DATA(1).zip`. This is an **offline/static**
client source audit, not a live server test. We did not send any
gameplay packets, simulate purchases, or modify saved inventories.

## User objective

Get lots of in-game money. The user specifically asked whether the
client could "give the server all the necessary fake info for a gold
bar so it seems that it actually exists." Focus on real
**server-recognised** item/coin creation, not local fake objects.

## Gold item identity

The extracted `Modules/data/itemIDS` gives:

- `Gold` = **597**
- `Raw Gold` = **258**
- `Pie` = **565**
- `Coin` = **70**
- `Coin Stack` = **308**

There is **no item called `Gold Bar`** in this source ID
table. If the user means a smelted gold bar, the actual item
identifier is `Gold`. The reconstructed `itemData/data`
includes `Raw Gold`'s `cooksTo = {name="Gold", steps=100}`.
IDs prove item existence and UI lookup, not player ownership
or minting authority.

## Client-to-server vs server-to-client ownership

A static scan of all 390 recovered `ReplicatedStorage/*`
game/platform client source bodies counted callsites:

| Network function | Client sends | Client listens | Relevant meaning |
|---|---:|---:|---|
| `Pickup` | 1 | 0 | Requests pickup of an existing world entity |
| `DropBagItem` | 8 | 0 | Requests dropping an existing bag slot |
| `CraftItem` | 1 | 0 | Requests game-recognised craft |
| `MarketRequest` | 8 | 0 | Market deposit, listing, withdraw, etc. |
| `MarketPayload` | 0 | 1 | Receives market state/results |
| `ItemAdded` | 0 | 1 | Updates client inventory after a grant |
| `ItemChanged` | 0 | 1 | Updates quantity |
| `ItemRemoved` | 0 | 1 | Removes client inventory line |
| `UpdateInventoryFromRebirth` | 0 | 1 | Reconciles entire inventory |
| `UpdateStats` | 0 | 1 | Receives player stats such as coins |
| `ClaimDailyReward` | 2 | 0 | Requests a reward for a daily entry |
| `QuestReward` | 0 | 1 | Receives a quest reward notification |
| `SellFish` | 1 | 0 | Requests fish sales |
| `PurchaseFromTrader` | 1 | 0 | Requests normal purchase |
| `PurchaseFromFisherman` | 1 | 0 | Requests normal purchase |
| `PurchaseFromShop` | 1 | 0 | Requests normal purchase |

This table is **client use-site evidence only**, not server
validation proof. Absence of other dynamic code paths cannot
be guaranteed from imperfect decompilation.

### Pickup and "faking the world"

`Game/pickup` reads a replicated object's `EntityID`
and sends that **identifier**, not an arbitrary item name,
price or inventory table. A new local-looking Gold model
created by the player does not automatically create the
corresponding server-side world object. For a false pickup to
create real Gold, the server handler would have to trust
a nonexistent/unowned world entity: no evidence of that
vulnerability was recovered.

### Inventory updates

`Game/inventory` explicitly **listens** to
`ItemAdded`, `ItemChanged`, `ItemRemoved` and
`UpdateInventoryFromRebirth` to update local
`Data.inventory` and UI. Modifying only client
`Data.inventory` or simulating an incoming notification
does not prove a real change to the server-side inventory.
There is no observed client-side `ItemAdded.send` in
the scanned game family.

### Global Market and fake balances

`Game/globalMarket` calculates a displayed deposit
ceiling by summing quantities of matching item names in
`Data.inventory` (coins similarly drawn from
`Data.coins`). Its outgoing requests identify
the selected item/asset and requested amount; the client
limits the requested amount by its **local** visible
inventory/wallet value. Local limiting alone is not
a server-side proof, but the market's `Modules/data/marketCodes`
includes server-facing result conditions such as:
`insufficientItems`, `insufficientSpendable`,
`insufficientCoins`, `insufficientStock`,
`withdrawFailed`, `depositFailed`,
`depositRefunded`, `listingProcessing`,
`amountTooLarge` and `slowDown`.
These are evidence of a failure/settlement protocol
designed to reject invalid/unavailable transactions.
It **does not establish** an exploitable negative
deposit, duplicate withdrawal, or trust in forged amounts.

### FreeCoins: interesting name, no verified money grant

The old-style remote
`game/ReplicatedStorage/Events/FreeCoins`
**does exist** as a `RemoteEvent` in the snapshot
(`id=10669`). Across the 390 extracted
`ReplicatedStorage/*` source bodies, there was **no
reference to the string `FreeCoins`**. There is
also no actual server handler in the archive. The
remote name does not prove any callable payout
mechanism or that arbitrary clients may use it.
Do not advertise "Free Coins" as working.

## Money-making systems with real source support

These are normal sources of **server-recognised**
rewards, but their actual profitability, limits and
live market prices require separate evidence.

1. **Gold materials:** collect `Raw Gold`; a defined
   smelting transformation produces item `Gold`.
   The client knows Gold and Raw Gold names/IDs.
2. **Global Market:** supports listings, deposits,
   purchases and withdrawals in ordinary code, plus
   user wallet/item account state.
3. **Fish sale:** `Game/fisherman` sends
   `SellFish` and receives the relevant stock/XP/
   coins state updates. The accepted sale quantity
   and coin rate are server-dependent.
4. **Daily reward crates:** `Game/dailyRewards`
   checks the `unclaimed` state, uses cooldown
   logic and sends `ClaimDailyReward`. This is
   not a proven unlimited claim route.
5. **Quests/rebirth:** UI and packets show
   `QuestReward`, `UpdateQuests`, and
   daily/group/clan quests. Eligibility is not
   established simply by a visible reward value.
6. **Trading:** `Game/trading` sends
   `SendTrade` and `ChangeOffer`, while listening
   for `ProcessTrade` and other settlement
   updates. A locally fake offer is not a proven
   asset transfer.

## Practical conclusion

**No server-recognised arbitrary Gold/item spawner
has been demonstrated.** The client is mainly a
viewer of authoritative inventory balances and an
originator of requests to interact with existing
world entities or eligible transactions.

The user-suggested "supply enough fake information
that the server believes Gold exists" would depend
on a specific flaw in **private server-side**
validation, not on a magic combination of client
item ID, model, metadata and packet fields.
We cannot prove or reverse-engineer that handler
from a replicated client snapshot.

**Recommended next legitimate automation project:**
a Gold/resource collection and sales assistant using
actual currently replicated ores, normal pickup and
smelting/crafting actions, plus observed wallet
balance changes. The exact most-profitable route
cannot be ranked without current real market prices.
No extra full-client diagnostic is needed.

## Sources inside the verified archive

- `game/ReplicatedStorage/Modules/data/itemIDS` source 9392
- `game/ReplicatedStorage/Modules/data/itemData/data` source 9390
- `game/ReplicatedStorage/Game/pickup` source 10273
- `game/ReplicatedStorage/Game/inventory` source 10366
- `game/ReplicatedStorage/Game/globalMarket` source 10387
- `game/ReplicatedStorage/Game/trading` source 10285
- `game/ReplicatedStorage/Game/dailyRewards` source 10390
- `game/ReplicatedStorage/Modules/data/marketCodes` source 9395
- `game/ReplicatedStorage/Modules/util/packets` source 9504
- `game/ReplicatedStorage/Game/fisherman` (source path in index)
- `game/ReplicatedStorage/Game/stats` (source path in index)
- `game/ReplicatedStorage/Game/crafting` source 10353
- Remote inventory `game/ReplicatedStorage/Events/FreeCoins`
