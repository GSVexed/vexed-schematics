# Booga Booga Reborn — research & hub project

## Chest request trial — 18 November 2026

Current chest-only continuation: [Unowned Chest Trial v1.1](README-booga-chest-trial-v1.1.md).
It adds native falling-chest feedback and fixed server-notice classifications
while retaining the zero-owned gate and one request. No purchases or owned
tests are included. [The lifecycle review](BOOGA-CHEST-LIFECYCLE-v1.md)
documents the failed v1.0.1 Resource Chest attempt and the remaining unknowns.
**A working free spawn has not been established.**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-chest-trial-v1.1.lua"))()
```

[Chest Trial v1.0.1](README-booga-chest-trial-v1.0.md) sends one normal
chest-open request after a readable inventory shows zero owned. It uses
the native live game cache when the separate server refresh is unavailable,
and records the source explicitly. The cache may be stale.
It observes matching world chests and checks the final coin/chest balance.
**Free chest spawning is unverified.** No purchase request or inventory edit
is performed. Compilation and 30 core workflow checks passed. The first
v1.0 user run stopped before any request with BEFORE_UNAVAILABLE; hotfix
behavior and the actual chest request remain unverified in-game.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-chest-trial-v1.0.lua"))()
```

## NEW: VALUE ENGINE v1.0 — ready for in-game validation

**[Full Value Engine setup guide](README-booga-value-engine-v1.0.md)**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-value-engine-v1.0.lua"))()
```

Independent FARM/FISH/MARKET systems: smart
Pickup-tag magnet, resource-priority mining,
PathfindingService ore navigation,
**Gold-to-Coin-Press conversion**
(with server-observed inventory decrement),
auto-cast/reel via recovered Rod game module,
actual Fisherman sale requests
(**waits for Fisherman Coin payout**)
and live marketplace
**lowest-price-versus-RAP radar** with
two-click manual purchase safeguard.
Tracks normal Coins and separate
Fisherman Coins, their observed
session changes and gain rates.
F6 stops all; no forged item grants
or silent background transactions.

**Compilation/static checks only, no live Booga
server test yet.** This is a genuine
feature-rich first testable version,
not a verified money exploit.
The server can reject requests and
locations/conditions affect success.

---

## Raw Gold smelting and gold creation — traced

**[Raw Gold → Gold smelting authority audit](BOOGA-RAW-GOLD-SMELTING-AUTHORITY-AUDIT-v1.md)**.
All 438 exported game-classified source bodies were scanned. The
`Game/cooking` module listens for inbound `cookingStream`
progress (timestamp + 11-byte entity/progress/rate/goal records);
there is **no discovered outgoing "smelt completed,
award Gold" call**. Smelting appears to be a server-owned
world-item transformation near a fuelled Campfire.

`DropBagItem` requests an existing inventory slot;
`Pickup` requires an existing world `EntityID`;
`InteractStructure` adds genuine existing fuel to
Campfire or uses existing `Gold` for Coin Press.
A client-created Raw Gold item or 100%-progress bar
is not demonstrated to mint real Gold. The source
archive has no private server-side handlers, so
unseen validation flaws are unverified, not disproven.

Other concrete findings: Gold item ID 597; Raw Gold
258; conversion `cooksTo=Gold, steps=100`; three
world Raw Gold instances, one actual Coin Press,
but no active Workspace Campfire in the snapshot.
`Smelter` Mojo advertises tiered 10%–50%
auto-smelt chance on real mined ore. Community
documentation puts Coin Press payout at five coins
per actual Gold. No arbitrary gold or money grant
is proven.

---

## Item spawning / money-source investigation

**[Economic item-grant and Gold audit](BOOGA-ECONOMY-ITEM-GRANT-AUDIT-v1.md)**:
The game item is **`Gold` (ID 597)**, not `Gold Bar`.
`Raw Gold` (ID 258) smelts to Gold. The recovered
`Pickup` request uses existing world `EntityID`, and
inventory/coins are updated by incoming server messages.
The Market has deposit/list/withdraw requests and
insufficient-items/funds settlement codes, but no confirmed
client-forgeable minting path. A `FreeCoins` RemoteEvent
exists with no discovered client calls or known server
handler. No working arbitrary item spawner is proven.

The supported money systems include normal smelting,
the global market, fishing sales, daily rewards,
quests and trading; their profitability is not yet
verified from live pricing.

---

## Targeted investigation: Dave / rare Pie

**[Dave 23.9M-health resource audit](BOOGA-DAVE-RESOURCE-AUDIT-v1.md)**
traces two actual replicated Dave models and their health attributes,
client attack request vs incoming break confirmation, God Axe DPS,
the community-wiki **25 Pie** reward and why no server-confirmed
instant-break technique is established.

The archive directly observed Dave at approximate X/Z
`-1314/-1876` and `1856/1330`; its HP is near 23.9M.
Normal God Axe effective wood damage=50 and a 1/3-second
swing interval imply ~44.3 hours solo or ~22.1 hours for two
players at continuous ideal accepted hits. Haste speeds axes
10% in its client descriptor; Strength's applicability to
resource damage is unconfirmed. Client Health edits/visual
ModelBroken do NOT establish real drops. Some much stronger
tool config entries are banned/blacklisted, not proved available.

---

## Phase 2 — deeper mechanics audit complete

**[Read the deep source audit](BOOGA-DEEP-MECHANICS-AUDIT-v1.md)**.
The archive is no longer just a folder of code; it has been traced
into actual client features, what the server appears to reconcile,
and a ranked list of worthwhile Booga-specific hub functions.

Important second-pass discoveries:
- **1,712 resource models** (53 names), **357 critter models**
  (34 names), **46 deployable models**, **1,259 Pickup-tagged objects**
  in the current streamed Workspace
- **1,194 named item-data entries**, including 11 ordinary potion
  effect types, special capes and blacklisted spell-like items
- Native controls: Quick Pickup, Hold to Swing, Quick Place, Quick Drop,
  Structure Snapping, hitbox visualisation, 600–2048 render distance
- Resourceful Mojo discounts eligible deployable ingredients;
  owned and disabled Mojo states are separately tracked
- Movement depends on status effects and Water Walker; exact
  complex timing code has decompiler artefacts
- Typed network coverage: 230 packet definitions, 105 referenced
  from client send sites, 121 from client listen sites
- Feature-gated custom player replication may be **off** in ordinary
  public servers; old reports must not imply it is always active

**No extra full diagnostic is needed** for first Booga hub engineering.

---

**Game:** [Booga Booga](https://www.roblox.com/games/11729688377/Booga-Booga),
PlaceId `11729688377`, by Gang O' Fries Entertainment.

This is a **new standalone project**. FERAL Aurora work is preserved under
`roblox-tools/`, and none of its client-controller assumptions should be
carried into Booga without evidence.

## First full archive received — integrity verified

The first uploaded ZIP turned out to contain **all 11 parts**. The
collector logged **97,686 objects**, **451 game-classified scripts**
(**438 reconstructed**), **203 remotes/bindables**, and **230 named
typed packet definitions** in the client network schema. All **23,296
saved payloads** and **38,111 reconstructed source references** passed
file-length and checksum verification.

**[Read the full code-backed first-export findings](BOOGA-FIRST-ARCHIVE-FINDINGS.md)**

The archive is saved in the ChatGPT conversation, **not** uploaded raw to
GitHub. The project findings are saved here for continuity. No additional
full diagnostic is necessary to begin technical analysis.

---

## Phase 1 — Complete visible-client collection

**[Start here: v1.0 collector instructions](README-booga-reborn-collector-v1.0.md)**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-complete-client-archive-v1.0.lua"))()
```

The collector inventories **all currently accessible game/client objects**
and reconstructs eligible client scripts where the executor permits it,
without modifying gameplay or calling game remotes. Output is a unique local
folder with completeness/gap manifests and upload-sized parts.

### Files

- [One-paste full client collector](booga-complete-client-archive-v1.0.lua)
- [Collector instructions / archive format](README-booga-reborn-collector-v1.0.md)
- [ZIP integrity verifier](verify-booga-client-export.py)
- [Two-or-more-capture comparison](compare-booga-snapshots.py)
- [Booga project handoff](BOOGA-HANDOFF.md)
- [CI validation](../.github/workflows/booga-reborn-collector-validate.yml)

The offline comparator identifies newly visible game scripts, remote
interfaces, named system categories and other paths when players scan
different areas/states of the map. It does not assert missing server content.

## Phases after first export

1. Analyze accessible source bodies and establish how Booga's client
   is arranged: inventory, crafting, combat, resource collection, equipment,
   movement, survivability, tribes, buildings, rebirth and Mojo.
2. Separate local/client effects from server-validated mechanics.
3. Prioritize worthwhile gameplay functions based on real code, not
   invented settings.
4. Build the polished Booga-only hub with reversible controls and proven
   feature explanations.

**No silent GitHub upload:** exports remain in the Velocity workspace
until explicitly shared. GitHub merely hosts the code and documentation.
