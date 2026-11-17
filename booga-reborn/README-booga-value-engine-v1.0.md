# Booga Booga Reborn — VALUE ENGINE v1.0

**Roblox target:** `11729688377` (Booga Booga Reborn)
**File:** [booga-value-engine-v1.0.lua](booga-value-engine-v1.0.lua)
**Design basis:** The user's full verified Booga client archive,
`UPLOAD_PART_010_DATA(1).zip` containing all 11 export parts
(place version 32961, 17 November 2026), not speculative public
outdated Booga script examples.

## One-paste Velocity launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-value-engine-v1.0.lua"))()
```

Run the launcher **after fully joining Booga**.
A dark teal `BOOGA / VALUE ENGINE` hub appears, with
`FARM`, `FISH` and `MARKET` tabs.
Press **F6 / STOP ALL** to stop every feature; re-running
replaces the previous UI and releases old listeners.

The hub uses the **game's actual existing packet/module system**
(`Modules/util/packets`, `gameUtil`, `clock`,
`data/itemData`, `data/itemIDS`, `marketCodes`,
`fishermanData` and, where available,
`Game/tool/Rod`). It does not install a
computer app, read files, write game secrets,
intercept authentication, or upload your inventory.

## Three workflows / seven switches

### FARM — Gold, resources and coins

1. **PICKUP MAGNET** — looks for existing, replicated,
   `Pickup`-tagged `Workspace.Items` with real
   `EntityID` values within **23 studs**. Sends
   legitimate pickup requests, throttled to about
   3.5 per second, with per-object retries no sooner
   than every 3 seconds. Does not spawn items, move
   them from distant islands, or modify your inventory.
2. **AUTO MINE ORES** — prioritises **actual nearby**
   `Workspace.Resources` models from a source-backed
   rare-ore list (Magnetite, Adurite, Crystal Lode,
   Emerald, Gold, Iron, Coal, Stone). Sends normal
   typed `SwingTool` requests at the equipped
   tool's advertised interval with one real
   `EntityID`, normal character CFrame and timestamp.
   If a resource's replicated HP fails to decrease,
   it skips that resource rather than faking success.
   It **does not** bypass the server's hit/health checks,
   and will not mine Dave's 23.9M HP as a default.
3. **WALK TO NODES** — optional pathfinding-assisted
   travel to ore nodes within **155 studs**, using
   `PathfindingService` and `Humanoid:MoveTo`.
   No position spoofing or teleporting; cannot
   reliably cross islands/water/impassable terrain.
   OFF by default so the player stays in place.
4. **AUTO PRESS GOLD → COINS** — checks actual
   `Gold` in your inventory, finds a real replicated
   `Workspace.Deployables/Coin Press` within **18
   studs**, and sends the normal
   `InteractStructure({entityID,itemID=Gold})`
   request. It only increments confirmed
   `Gold pressed` when the **server-replicated
   inventory Gold count decreases**; after
   6 seconds with no decrement it stops.
   Enable PICKUP MAGNET at the same time
   to collect actual produced coin drops.
   Important: this uses existing Gold and
   does **not** create Gold or money from nothing.

Practical sequence: equip a real ore tool,
turn on magnet and miner in an ore area,
optionally enable WALK TO NODES; after
collecting and smelting real Gold, stand
near a Coin Press and enable AUTO PRESS
GOLD → COINS with magnet still active.
The hub does **not** auto-smelt Raw Gold;
normal cooking near a lit Campfire is
server-controlled and no safe no-input
smelt-completion packet was discovered.

### FISH — Additional economy and rare loot

5. **AUTO CAST + REEL** — requires an **equipped
   fishing rod** and camera **aimed at water**.
   Calls the actual game rod's cast function,
   watches incoming `BobberState` for the
   local owner's `state="hooked"`, then sends
   the normal `RodEnd` response after a short
   delay. Attempts another cast after the
   existing line is no longer active.
   It watches actual inventory for newly added
   sellable fish, rather than reporting
   invented catches.
6. **AUTO SELL NEAR TRADER** — requires an existing
   **Fisherman Trader** within **23 studs**
   and actual fish in the inventory.
   Uses the exact `SellFish.send(fishName)`
   call seen in the recovered Fisherman GUI.
   Waits for inventory quantity reduction
   or a Fisherman Coin increase before
   attempting a subsequent sale; after
   6 seconds without confirmation it
   stops that feature rather than flooding
   the trade system.

The source `Modules/data/fishermanData.sellPrices`
defines fish prices. At the captured
place version, examples range from
`Raw Fish=100` to `Gold Squid=65,000` and
`Flaming Chomper=110,000`. **These values
are Fisherman Coins, a separate currency
from normal game Coins**. Rare fish aren't
guaranteed; the hub cannot guarantee
a catch rate or an uninterrupted fishing
session. The rod's behaviour is
server-dependent and must be tested in-game.

### MARKET — Ordinary Coin-market opportunities

7. **SCAN WATCHLIST** — for each known ID
   (Pie, Gold, rare ores and other
   high-interest items), sends the game's
   `MarketRequest.itemView` with
   `listingType.item` and
   `priceAscending` order, spaced
   ~2.6 seconds apart. It reads
   incoming `MarketPayload.item.listings`
   and `rapHistoryTenths`, showing
   **the cheapest listed price** compared
   with the **most recent RAP**.

The hub displays the top six price-vs-RAP
discounts (which may be negative);
**a low price relative to RAP is not guaranteed
to be a profitable flip**. Fees, liquidity,
market manipulation, seller risk and current
buyer demand are not inferred.

An additional **BUY TOP DEAL / CONFIRM**
button exists but **does not auto-buy**.
It only offers a deal at least 35% below
RAP and requires **two deliberate clicks
within five seconds**. It also checks that
a usable **Market wallet balance** has
been received and meets the item price,
and refuses listings whose last
observation is older than 60 seconds.
It requests **one item** with the
listing ID, quantity 1 and expected
price; the *server* settles or rejects
the purchase. The UI never claims a
purchase succeeded without a settlement
notice; check the native market before
reselling.

Market queries/purchases may require
the user to be near a live Global Market
structure or to have the native market
interface open, depending on server
restrictions. A timeout is reported;
nothing is automatically spent merely
by toggling market scanning.

## Top-level dashboard and correctness

The status/footer shows:
- Real replicated ordinary `Data.coins`
- Real replicated `Data.fishermanCoins`
- Session change in both balances
- **Actual observed** gain/loss per hour
- Actual currently held Raw Gold and Gold
- Pickups **requested** (not falsely counted as
  credited inventory)
- Resource attacks attempted, and
  **Gold consumed** by Coin Press (confirmed
  by inventory quantity changes)
- Newly observed fish and confirmed
  fish sales
- Market opportunities and current
  watchlist query progress
- A warning/status if an API or
  server acknowledgement doesn't work

No fake coins, fake pies, fake ore instances,
balance edits or spoofed rare drops.

The hub doesn't intentionally perform
actions while a game chat/text input has
focus. It includes a best-effort normal
Roblox idle safeguard while any engine
is enabled, but may still be disconnected
by Roblox/game policy. F6 always stops
active automation; closing the hub
disconnects global UI events and other
registered listeners.

## What has and has not been validated

**Validated:** An official Luau v0.747
compiler accepts the source, and
GitHub Actions checks the required
packet names and protective code paths.

**Not validated:** An actual Velocity
session or a live Booga server.
The server is entitled to reject
unusual pickup, mining, fishing,
sale or market requests and could
enforce anti-automation or anti-cheat
rules. Code that compiles does not prove
it makes money, nor that it meets
a "game-breaking" profit target.
The hub displays feedback so
unsupported modes can be
distinguished from genuine value.

**Troubleshooting**:
- `Required Booga modules unavailable`:
  load fully, ensure correct PlaceId.
- `Equip a Fishing Rod`: use a
  real rod equipped in toolbar.
- `Cast attempted` but no fish:
  aim at water; watch whether
  `Fishing` attribute changes
  and `BobberState` messages
  arrive. Try the native rod
  once if needed.
- `No Coin Press within 18 studs`:
  approach a real player-made
  or world Coin Press.
- `Gold was NOT consumed`:
  the server did not confirm the
  conversion; don't keep sending.
- `Market wallet balance not verified`:
  open/use the native market,
  wait for wallet updates. Never
  assume `Data.coins` equals the
  market's spendable wallet.
- `No real HP loss`:
  equipped tool/position/server
  validation requires review.
- If a feature shows a no-confirmation
  state, do not repeatedly spam it.
  The status message matters.

## Evidence links

- [Archive integrity and architecture](BOOGA-FIRST-ARCHIVE-FINDINGS.md)
- [Deep mechanics and current game flags](BOOGA-DEEP-MECHANICS-AUDIT-v1.md)
- [Gold and smelting authority](BOOGA-RAW-GOLD-SMELTING-AUTHORITY-AUDIT-v1.md)
- [Money and item grant audit](BOOGA-ECONOMY-ITEM-GRANT-AUDIT-v1.md)
- [Official Luau compile workflow](../.github/workflows/booga-value-engine-v1-validate.yml)

**Project principle:** Build features
that perform actual existing
game requests, measure real
server-fed outcomes and stop
when those aren't confirmed.
A credible automation hub
is more useful than a
nonexistent "server believes
I own unlimited Gold" button.
