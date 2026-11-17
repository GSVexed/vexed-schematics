# Booga Reborn — Deep gameplay mechanics audit v1

**Source:** The user's 17 Nov 2026 `UPLOAD_PART_010_DATA(1).zip`,
an internally verified 11-part archive of PlaceId 11729688377, place
version 32961. This report is a **derived analysis**, not a redistribution
of private gameplay telemetry, full reconstructed game source, or the
~217-MB raw archive. Read
[BOOGA-FIRST-ARCHIVE-FINDINGS.md](BOOGA-FIRST-ARCHIVE-FINDINGS.md)
for all collector and checksum details.

## Analysis coverage

This pass directly inspected the reconstructed source bodies for
`Game/stats`, `Game/spawning`, `Game/tool`, `Game/tool/Combat`,
`Game/tool/Slash`, `Game/tool/Glide`, `Game/pickup`,
`Game/inventory`, `Game/crafting`, `Game/mojos`,
`Game/spells`, `Game/boosts`, `Game/boosts/data`,
`Game/classes/statusEffects`, `Game/settings`,
`Game/structures`, `Game/cauldron`, `Game/toolbar`,
`Game/rendering`, `Game/rendering/localMovement`,
`Game/rendering/steering`, and data/util modules:
`Modules/data/itemData/data`, `Modules/data/itemData`,
`Modules/data/recipeInformation`, `Modules/data/settingsData`,
`Modules/util/gameUtil`, `Modules/util/flags` and
`Modules/util/packets`. A static cross-reference pass covered
all 390 extracted `ReplicatedStorage/*` source bodies, including
`Game/*`, `Modules/data/*`, `Modules/util/*` and libraries.
The raw 451-entry game-classified source index was used as a locator,
not as a substitute for direct source reading.

## 1. World objects — a much stronger basis for ESP than name guessing

This pass parsed every game-classified `objects/game_*.ndjson.txt`
row in the ZIP and counted actual replicated Workspace models and tags.

| Scope | Recorded in this one session |
|---|---:|
| `game/Workspace/*` object rows | **23,294** |
| `Workspace/Resources` instances | **9,062** |
| Actual `Resources` models | **1,712** |
| Distinct resource-model names | **53** |
| `Workspace/Critters` instances | **9,311** |
| Actual `Critters` models | **357** |
| Distinct critter-model names | **34** |
| `Workspace/Items` instances | **1,098** |
| `Workspace/Deployables` models | **46** |
| Distinct deployable-model names | **14** |
| Workspace `Pickup`-tagged objects | **1,259** |
| Workspace `Entity`-tagged objects | **13,173** |

All **1,712 resource models**, **351 of 357 critter models**,
all 46 deployable models and selected other entities had a replicated
`EntityID` attribute. This is the meaningful identity used in many
client data and rendering systems. The counts are **a single streamed
snapshot**, not all possible resource spawns.

Examples of **actual replicated resources** and model counts:
Small Tree 331, Bush 271, Big Bush 156, Vines 110,
Driftwood 89, Small Rock 76, Stone Node 75, Iron Node 75,
Gold Node 42, Coal Node 34, Emerald Lode 8,
Adurite Node 5, Crystal Lode 3.

Examples of **actual critters** and model counts:
Bird 70, Stone Shelly 36, Goober 30, Turtle 19,
Lurky Boi 19, Big Stone Shelly 17, Peeper 16,
Penguin 15, Lil Banto 15, Black Ant 12, Fire Ant 9,
Queen Ant's Servant 4, Magnetite Shelly 4, Giant Shelly 1.

Actual replicated **ground items** include Wood, Berry, Log, Stone,
Leaves, Raw Morsel, Raw Meat, Essence, Iron, Adurite and Raw Fish.
Actual replicated **deployables** include Wood Fence, Plant Box,
Wood Wall, Big Ol' Hut, Dock, Bridge, Ice Wall, Bed and Market.

**Engineering conclusion:** A named/rarity-filtered resource and creature
ESP could be built against real `Workspace.Resources`, `Critters`,
`Items`, `Deployables` and CollectionService `Entity`/`Pickup`
tags, instead of thousands of speculative path-name filters.
This would observe current replicated entities; it cannot reveal
streamed-out or truly server-only ones.

## 2. Movement, slowdowns and modifiers

Directly from `Game/spawning`'s per-frame controller, a main branch
uses base **WalkSpeed 16** and **JumpPower 50**. It checks:
- local character `Humanoid` / `HumanoidRootPart` and movement mode
- environmental water contact and owned/active `Water Walker` Mojo
- `OnIce`, `OnBossPoison`, `OnQueenPoison`,
  `Swiftness`, `SpiderWebSlow` status effects
- a Voodoo Vortex-region test and some immobility/control states
- camera lock, shift lock, mouse/camera orientation and flipped state

A branch sets a **slower value of 12** for vortex, certain poison or web
conditions; `Swiftness` scales the speed coefficient by **1.1**
outside one vortex condition; a water branch divides its speed by
**2.5**, unless an owned/enabled `Water Walker` changes the
water-state logic. These are reconstructed client behaviours,
not verified server movement limits.

**Caution:** the decompilation of this function has demonstrably
inconsistent/nonsensical local variable assignments in places
(including one `OnIce` branch). Do not reproduce it verbatim as
trustworthy Luau or promise exact slowdown precedence without a live
test and more careful decompilation.

`Game/rendering/localMovement` separately encodes own/vehicle
positions for an optional
`Events/EntityPositionalReplication` path. However
`Modules/util/flags` enables `customPlayerReplication`
only for Studio, listed alternate PlaceIDs or particular private-server
conditions. **The captured public game PlaceId 11729688377 is not
itself on that allowlist**, so presence of the encoder is **not**
proof that this custom replication mode is active in ordinary public
Booga servers. This corrects the overbroad interpretation in the
first findings report.

`Game/tool/Glide` is a real client routine constructing
`BodyGyro`/`BodyVelocity`, playing hover/fly animations and
using a held item's `flyspeed` setting. Four item-data entries
describe special capes with `flyspeed` **95**, **115**,
**190** and **380**, including `Jogo's Cape`,
`Bullet's Cape`, `Bullet's Dark Cape` and
`Lightning Cape`. All are special `Glide` tools with
`noDrop`/`rebirthPersist` metadata; the archive does **not**
establish ordinary ownership, entitlement, deployment or
server-accepted high-speed flight.

## 3. Combat and harvest timing

`Modules/util/gameUtil` declares a client melee-box size of
**Vector3(6,11,5)**. The reconstructed `Game/tool/Combat`
and `Game/tool/Slash` handlers build a box in front of the player,
use `Workspace:GetPartBoundsInBox`, gather unique hit-model
`EntityID` values and send a typed `SwingTool` request with
entity list, character `CFrame`, timestamp and optional
player-state hints. This establishes *the client's target-detection
and request workflow*, not the server's acceptance of submitted targets,
hit distance or extra damage.

`Game/tool` dispatches different use types (Slash, Rod, Hoe,
Drink, Glide, Target etc) and consults `itemData.speed`,
`Data.lastToolUse` and the `Haste` effect for Axe/Pick.
`Game/tool` listens for `UpdateLastToolUse` from the network.
One relevant decompiled expression contains an uninitialised
temporary variable, so **do not call its literal math proven**.
The reliable evidence is that timing is client-mediated and has a
network-synchronised last-use signal.

Separate potion descriptions and status data state:
`Haste` boosts chopping/mining speed by 10%,
`Strength` says +10% tool damage,
`Weakness` says -10% tool damage and
`Swiftness` says +10% movement speed.
These numbers are **client descriptors**, not recovered server
damage/delay enforcement.

## 4. Inventory and native quality-of-life — already implemented by Booga

`Game/inventory` keeps a local view of
`gameUtil.Data.inventory`, calculates held weight/bag
`playerCacheLoad`, and listens for typed
`ItemAdded`, `ItemChanged`, `ItemRemoved` and rebirth
inventory updates. It also sends `DropBagItem`,
`UseBagItem`, `MoveItem` and chest requests.
These clients are reconciled by server messages; changing an
item count locally is **not a proved real inventory grant**.

`Modules/data/settingsData` includes **native, functional
quality-of-life settings**. Important examples:

| Native setting key | Label / effect |
|---|---|
| `autoFpickup` | **Quick Pickup** (OFF by default) |
| `holdToSwing` | **Hold to Swing** (ON) |
| `dontReclickCraft` | **Quick Place** (OFF) |
| `quickDrop` | **Quick Drop** (OFF) |
| `structureSnapping` | **Structure Snapping** (OFF) |
| `visualizeHitboxes` | **Structure Hitbox Visual** (OFF) |
| `animalRenderDistance` | **Entity Render Distance**, 600–2048, default 1024 |
| `fieldOfView` | Field of View, 70–120, default 70 |
| `camLock` | Camera Lock (ON) |
| `hideShadows` | Shadows toggle (ON) |

`Game/pickup` confirms `autoFpickup` is a real handler:
a held input can repeat `Pick` each update, but it still checks
living player state, current cursor ray, pickup availability, item lock,
a **25-stud distance condition**, available load and sends
a standard `Pickup` request.
`Game/interface` invokes the hold-swing behaviour based on
`holdToSwing`. `Game/structures` uses
`dontReclickCraft`, `visualizeHitboxes` and
`structureSnapping` in real placement logic.
**Implication:** These are practical, game-native switches a future
hub can surface immediately. They are not unlimited-distance
vacuuming or server-bypassing resource grants.

## 5. Crafting, Mojo ownership and status effects

`Modules/data/itemData/data`'s large final item table has
**1,194 named entries**. **389** entries are direct table
definitions and **805** are shared variable aliases in the
reconstructed source. Thus, the item-name count is not proof of
1,194 independently obtainable usable items or fully reconstructed
individual configs.

`Game/crafting` and `Modules/util/gameUtil.canCraftItem`
both check level, owned items, recipes and Mojo eligibility.
For `Resourceful`, when an item is
`deployable` and **not** `excludeDiscount`, the visible
ingredient calculation uses
`max(ceil(required/2),1)`. This appears in both UI and shared
eligibility logic, not just a pretty buff label.
The shared module has both client and server paths in reconstructed
source; **server acceptance is not directly visible**.

`Game/mojos` stores tiers in `Data.mojoItems` and
disabled state separately in `Data.disabledMojo`. It listens
for `MojoChanged` and `UpdateMojoItem`; rebirth/purchase
actions send `Rebirth` / `PurchaseMojoItem` requests.
An optional paid double-Mojo entitlement affects a displayed
rebirth outcome, but this doesn't mean an ordinary client can award
itself additional Mojo.

`Game/spells` shows `Voodoo Vortex` as visible on the
selection screen after at least **2 rebirths** and `Shadow Warp`
after at least **3 rebirths**; `Soul Dash` and
`Spirit Link` are instead tied to a separate
`Data.unlockedSpells` state.
`VoodooSpell` is a typed request; `Data.voodoo` is the
local replicated resource. Spells cannot be assumed free to unlock
or cast simply by toggling the client menu.

`Game/classes/statusEffects` tracks ten player attributes:
`OnFire`, `OnIce`, `OnPoison`, `OnBossPoison`,
`Silenced`, `OnQueenPoison`, `Debuff`, `Swiftness`,
`Haste` and `SpiderWebSlow`.
`Game/boosts` listens to network `SetBoost` and
`RemoveBoost`, adds/removes the actual client's displayed
buff cards, updates duration/percentage and shows descriptions
from `Game/boosts/data`. **A client-only buff card would
not itself prove a granted server buff.**

`itemData/data` explicitly describes **11 standard potion
types**: Poison, Swiftness, GhostSpawning/Phantasm, Haste,
FireResistance, Strength, Weakness, Ice, Healing, Harming,
Placebo; the table also includes splash potion versions.
`Game/tool/Drink` uses a drink animation and a
`DrinkPotion` request; `Game/cauldron` requires both
a bottle and ingredient quantities before its normal
`CraftPotion` action.

## 6. Hidden, disabled and development-looking code

`Modules/util/flags` currently declares:

| Flag | Recovered value |
|---|---|
| `resourceEffects` | true |
| `worldEffects` | true |
| `animalEffects` | true |
| `foliageWind` | true |
| `tutorial` | true |
| `inventoryBurstLimitations` | false |
| `newMap` | false |
| `deterministicSpawnPoints` | true |
| `tutorialDebugSteps` | false |
| `plantBoxDebug` | false |
| `npcDebugHitboxes` | false |
| `marketDecimalPrices` | true |
| `anticheatDebug` | `RunService:IsStudio()` |
| `customPlayerReplication` | conditional; generally false for ordinary public PlaceId |

These are **source-level flags**, not a menu of server-authorised
unlocks. In particular, `anticheatDebug` is explicitly
Studio-only.

The item table contains special `Glide` capes, some entries
marked `blacklisted=true`, and spell-like names such as
`Time Stop`, `Stop Time`, `Hate Train`,
`Amaterasu` and `Cleave`. Specifically,
five direct item entries have **both**
`voodooSpell=false` and `blacklisted=true`:
`Conqueror's Haki`, `Bullet's Ray`,
`God's Bolt`, `Rainbow Ray` and
`Equinox Bolt`.
Other special entries have inconsistent/copied descriptions
and may be vestigial or non-deployed. Their source presence
does **not** show they are obtainable or supported by the server.

## 7. Networking architecture and ownership signals

`Modules/util/packets` defines exactly **230 unique named typed
packets** via `definePacket`. Static cross-reference across
the captured `Game/*` script family found:

| Static usage | Distinct packet definitions |
|---|---:|
| Used with at least one client `.send(...)` | **105** |
| Used with at least one client `.listen(...)` | **121** |
| Used both ways in one or more game source paths | **6** |
| Not directly referenced via either form in scanned `Game/*` paths | **10** |

These counts overlap as above and cover **all 230** packet names
(`105 + 121 - 6 + 10 = 230`).
Some packets may be used from other source families or dynamically;
the absence of a static reference is not proof of an unused endpoint.

Useful inferred ownership boundaries:
- `SetBoost`/`RemoveBoost` come **into** the client boost UI.
- `ItemAdded`/`ItemChanged`/`ItemRemoved` reconcile
  the displayed inventory.
- `MojoChanged`/`UpdateMojoItem` reconcile owned Mojo states.
- `UpdateLastToolUse` reconciles client timing.
- `CraftItem`, `SwingTool`, `VoodooSpell`,
  `PlaceStructure`, `Pickup` and `PurchaseMojoItem`
  are client requests, **not proofs of automatic server approval**.
- `EntityPositionalReplication` raw buffer traffic
  uses a separate feature-gated path, as noted above.

## 8. Ranked design decisions for a real Booga hub

| Priority | Candidate | Basis | Confidence / constraint |
|---|---|---|---|
| **1** | **Resource, item, NPC and special-entity ESP** with rarity/type filtering, health, distance and temporary screen labels | Thousands of real named replicated models and `Entity`/`Pickup` tags | **High** for local visibility; streaming still limits |
| **2** | **Crafting + inventory assistant**: recipe search, missing materials, current load, equipment, Mojo unlock and Resourceful recipe cost | Shared `Data.inventory`, 1,194 item names, verified `canCraftItem` | **High** for readouts and planning; actual craft must be accepted |
| **3** | **Practical built-in game controls**: Quick Pickup, Hold to Swing, Quick Place, Quick Drop, snapping, hitboxes, render distance | Real native setting definitions and handlers | **High** for in-client settings; bounded native action limits remain |
| **4** | **Movement/effects dashboard**: actual WalkSpeed, status attributes, Water Walker state, buff timers, Voodoo/food/HP | Per-frame movement controller, native `SetBoost` and effect attributes | **High** for monitoring; medium for local adjustments; not server immunity |
| **5** | **Equipment/crafting combat insights**: equipped tool swing speed, ingredient efficiency, target health, potion availability | Combat box, Haste branch, item stats, cauldron | **Medium/high** for information; not guaranteed damage |
| **6** | **Species/entity utility**: critter IDs, ore tiers, pickup and deployable sorting, ant mound details | Real world entity hierarchy and tags | **High** for visual client data |
| **7** | **Mojo/spell and progression controls**: see owned ranks, unlock conditions and active buffs | `MojoChanged`, `unlockedSpells`, `VoodooSpell` | **High** for truthful state, **low** for arbitrary grants |
| **8** | **Experimental movement and local ability changes** | Per-frame WalkSpeed/JumpPower and Glide client routine | **Unverified** in-game; potential correction or side effects |

**Not justified as real features from this archive:** free server
coins, force-owned Mojo, infinite damage/HP, remote-only arbitrary
pickups, respawn-invulnerability or unlocking all blacklisted
developer items. A bright ON button would not establish authority.

## Key reliability caveat

This is a decompiled, privacy-filtered snapshot, not a Studio source
repository. Several reconstructed methods contain lost/upvalued
temporary variables (e.g. tool timing and OnIce movement branches).
**We can trust the existence of modules, flags, packet names, many
declared constants and broad call relationships more than we can
trust every exact statement/order of complex reconstructed code.**
The private server's handlers and anti-cheat remain unseen.

## Next development step

No further full diagnostic is needed for the first hub.
Build a separate Booga prototype around the highly grounded
client-visible systems **1–4**, with reversible controls, no
speculative server grants and clear feedback about actual local
state. A second snapshot is optional only if the user later wants
to capture a new streamed region or game version.
