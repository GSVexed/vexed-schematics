# Booga Booga Reborn — First full client export findings

**Evidence:** User-supplied ZIP `UPLOAD_PART_010_DATA(1).zip`, received
17 November 2026; scanned local Booga client, PlaceId `11729688377`.
This page stores a **derived technical summary**, **not** the user's
223-MB uncompressed archive, decompiled source bodies or other-player data.

## Archive integrity — VERIFIED

The ZIP had a misleading name suggesting only part 010, but contained
all **11 complete export sections**: `UPLOAD_PART_000_METADATA` and
`UPLOAD_PART_001_DATA` through `UPLOAD_PART_010_DATA`.

- File size: **34,240,151 bytes** compressed (about 32.7 MiB)
- ZIP entries including directories: **23,765**
- Non-directory ZIP files: **23,689**
- Saved payloads: **23,296**
- Payload bytes: **217,037,246**
- Metadata file catalogs: **125**, all checked against Adler-32
- Unique payload catalog paths: **23,296**; **0 duplicates**
- **All 23,296 payload files** matched declared byte length and Adler-32.
- **All 38,111 exported source records** correctly referenced complete
  source chunks with matching concatenated lengths and Adler-32.
- Unique source file groups checked: **22,676**; **0 mismatches**
- Per-part session markers matched the manifest.
- ZIP CRC validation passed with no reported corrupt members.
- The collector recorded `writeErrors=0`, `unverified=0`,
  `limits_hit=[]`; `inventory_traversal_exhausted=true`,
  `source_pass_finished=true`.
- Archive is internally intact. Checksums detect accidental damage,
  **not** malicious alteration; this cannot establish decompiler accuracy
  or full server-side coverage.

## Collector session provenance

| Field | Recorded value |
|---|---|
| Session ID | `20261117_172831_7DA66D788F0F` |
| PlaceId | `11729688377` |
| Universe/GameId | `4154513353` |
| Game place version observed | `32961` |
| Started UTC | `2026-11-17T17:28:31Z` |
| Manifest updated UTC | `2026-11-17T17:38:55Z` |
| Collector elapsed | 623 s |
| Manifest phase | `finished_with_gaps` |

## What was captured

| Measurement | Total | Game-classified | Roblox-platform-classified |
|---|---:|---:|---:|
| Objects | **97,686** | **56,254** | 41,432 |
| Scripts | **38,124** | **451** | 37,673 |
| Source-eligible scripts | 38,113 | 440 | 37,673 |
| Source records exported | **38,111** | **438** | 37,673 |
| Source not eligible (server/unknown run context) | **11** | 11 | 0 |
| Source reconstruction failures | **2** | 2 | 0 |
| Remotes and bindables | **203** | **171** | 32 |

Other counts: **2,957** ValueBase objects, **18,704** attributes,
**52** recorded active animation tracks and **36** private/other-player
roots excluded. The collector logged **233,374** privacy/source
redactions or omitted comment/literal content; the exported Lua is
privacy-filtered reconstruction, not byte-for-byte original Studio code.

All **11** non-client-context scripts are recorded but not recovered.
The **two** accessible game-classified source failures were:

- `game/StarterPlayer/StarterCharacterScripts/Animate`
- `game/Workspace/Players/LocalPlayer/Animate`

Both failures reported `api_error_details_withheld` and are variants
of the animation controller; **no recorded
`ReplicatedStorage/Game/*` gameplay module failed source export**.

The nominal **37,673 platform-classified** scripts are mostly Roblox
`CorePackages` (35,630) and `CoreGui` (1,963). These counts must not
be confused with a 38,000-script Booga game project. The genuinely
interesting part for the new hub is approximately **451 game-classified
script entries** (including Roblox-provided AvatarAbilities and some
UI duplicates) plus resource, attributes, models and typed interfaces.

## Game architecture — specific recovered source modules

The following are actual **exported client source paths**, not
guesses based only on object labels.

| Subsystem | Source paths / architectural evidence |
|---|---|
| Combat/hit detection | `Game/tool/Combat`, `Game/tool/Slash`, `BOOLET/modules/RaycastHitboxV4`, `Game/armor`, `Modules/data/itemData/data` |
| Inventory and equipment | `Game/inventory`, `Game/toolbar`, `Game/tool`, `Modules/data/itemData`, `itemIDS`, `Game/tool/Repair`, `Throw`, `Rod`, `Glide`, `Shovel`, `Hoe` |
| Crafting/survival | `Game/crafting`, `Modules/data/recipeInformation`, `Game/cooking`, `Game/cauldron`, `Modules/data/cauldronRecipes`, `Game/stats` |
| Player networking | `Modules/util/packets`, `Modules/libraries/byteNet`, `Game/rendering/localMovement`, `rendering/codec`, `rendering/interpolation`, `rendering/steering` |
| Structures/colonies | `Game/structures`, `Game/structures/snapStructure`, `Game/colonies`, `Game/worldEffects/structures` |
| Tribes/clans | `Game/tribes`, `Game/clans`, `Game/clans/upgrades`, `Modules/data/clanData` |
| Progression/economy | `Game/mojos`, `Game/quests`, `Game/trading`, `Game/globalMarket`, `Game/boosts`, `Game/boosts/data`, `Modules/data/levelData`, `quests/Main/Rebirth*` |
| Abilities and effects | `Game/spells`, `Game/spells/Soul Dash`, `Spirit Link`, `Game/classes/statusEffects`, `Game/worldEffects/effectKit` |
| World/entities | `Game/entities`, `Game/rendering/createAnimalEntity`, `createPlayerEntity`, `createVehicleEntity`, `Game/worldEffects/animals`, `resources`, `Game/weather/*` |
| Other mechanisms | `Game/aircrafts`, `Game/ballista`, `Game/mounts`, `Game/fisherman`, `Game/fletchingTable`, `Game/wanderingTrader`, `Game/forgottenKnightSystem`, `Game/greybeardSystem`, `Game/headlessHorsemanSystem`, `Game/killEvent`, `Game/battlepass`, `Game/dailyRewards` |

Game-related data definitions of particular importance:
- `Modules/data/itemData/data`: **356,032** reconstructed bytes of item
  definitions with fields such as health, recipe, craftLevel, costs,
  load and uses. This is strong evidence of a large item/config catalog,
  **not** proof the values are server-authoritative.
- `Modules/data/skinData`: **142,596** bytes.
- `Game/globalMarket`: **128,700** bytes.
- `Modules/data/itemIDS`: **66,225** bytes.
- `Game/structures`: **56,585** bytes.
- `Game/clans`: **49,150** bytes.
- `Modules/data/biomeData`: **48,705** bytes.
- `Game/spawning`: **42,616** bytes.
- `Game/inventory`: **40,008** bytes.
- `Game/crafting`: **20,613** bytes.

## Networking: important finding

The object tree contains **171 game-classified remotes/bindables**
(203 across game and platform). However these are **not the entire
logical network API**.

The reconstructed `Modules/util/packets` (31,602 bytes) defines
**230 distinct named typed packets** via ByteNet-style `definePacket`
declarations, carried by a smaller set of underlying transport
remotes (`ByteNetReliable` and `ByteNetUnreliable` are visible).

Illustrative typed packet names from the exported definition:

- Combat: `SwingTool`, `CreateProjectile`,
  `ProjectileImpact`, `ModelHit`, `Damage` is not established
- Inventory/items: `Pickup`, `DropBagItem`, `UseBagItem`,
  `MoveItem`, `EquipTool`, `Consume`
- Crafting/building: `CraftItem`, `CraftArrow`,
  `CraftPotion`, `PlaceStructure`, `PlaceVoxel`,
  `InteractStructure`
- Progression: `Rebirth`, `PurchaseMojoItem`, `ToggleMojo`,
  `VoodooSpell`, `UpdateStats`
- Tribes/clans: `CreateTribe`, `TribeInvite`,
  `ManageTribeMember`, `CreateClan`, `UpdateClanData`
- World: `Weather`, `RequestCurrentWeather`,
  `SetWorkerPath`, `RequestAntPaths`, `Aircraft`

The legacy `ReplicatedStorage/Events/` tree also contains names
such as `SwingTool`, `CraftItem`, `PlaceStructure`, `Rebirth`,
`VoodooSpell`, `AdminPanel`, `Invisafy`, `FreeCoins`
and `Testing`. **Object names are not proof that these paths are
usable, active, client-trusted or unprotected.** Do not treat these
as server grant APIs without verification.

The recovered client combat handler prepares a `SwingTool` typed
packet including fields for detected `entityIDs`, `cframe`,
`timestamp` and optional `playerStates`. This describes client
request structure, **not** whether the server accepts a forged
target/damage claim.

The client also contains a local movement/vehicle replication encoder
using `EntityPositionalReplication`; this involves player/vehicle
positions and packed data. It is not proof that server position checks
can be bypassed.

## Actual client-defined status effects and boost descriptions

`Game/classes/statusEffects` watches attribute names:

`OnFire`, `OnIce`, `OnPoison`, `OnBossPoison`, `Silenced`,
`OnQueenPoison`, `Debuff`, `Swiftness`, `Haste`,
`SpiderWebSlow`.

`Game/boosts/data` visibly defines:

| Client boost label | Client description/configuration |
|---|---|
| `Haste` | Pickaxes and axes are **10% faster** |
| `Strength` | Tools deal **10% more damage** |
| `Weakness` | Tools deal **10% less damage** |
| `Healing` | Regeneration faster, displayed as **+2 HP/s** and 20% |
| `Swiftness` | **10% faster** |
| `OnIce` | **25% slower** |
| `SpiderWebSlow` | **25% slower** |
| `FireResistance` | **100%** resistance to fire (client description) |
| `GhostSpawning` | Ghost spawn likelihood boost, client `percent=20` |
| `Booga Plus` | EXP boost, client `percent=20` |
| `Pink Diamond Armor` | Faster regeneration (no amount in this descriptor) |
| `Magnetite Armor` | Poison resistance (no amount in descriptor) |
| `Adurite Armor` | Fire resistance (no amount in descriptor) |

Other labels include `Friendship`, `Voodoo Passive`,
`Clan EXP`, `Jelly Sandwich`, `Void Armor`,
`Starter Pack`, `XP Boost`, and `Protection`.
These are recovered **client descriptors**, not authority to
grant a boost or proof all are live/obtainable in this game version.

`Game/stats` reads a client data state containing
`coins`, `essence`, `food`, `voodoo`, `level`, `mojo`
and HUD health from the local Humanoid. **Do not transplant FERAL's
hunger-and-thirst assumptions:** we saw a `food` bar but have
not established a separate thirst meter in this Booga UI.

## Interesting additional discovery leads

These are **present in the client export**; feature availability
and permissions are not confirmed:

1. `Game/spells` references **Soul Dash**, **Spirit Link** and
   Voodoo selection, with rebirth-related UI checks.
2. `Game/colonies` contains **ant colony worker pathing/mounds**
   and path-preview UI.
3. `Game/rendering` contains interpolated entities and **local
   movement/vehicle** updates, not only ordinary Roblox Humanoid movement.
4. `Game/tool` has specialised aircraft, grappling/rod,
   gliding, repair, projectile and different combat modules.
5. `Game/globalMarket`, trading, clans and quests are sizeable
   systems with independent client logic.
6. `MainGui/LeftPanel/QuestsOld` is present in GUI sources;
   that name alone **does not prove an active hidden quest feature**.
7. `ReplicatedStorage/Events` exposes debugging/moderation-style
   names (`DebugOn`, `AdminPanel`, `ModPanel`,
   `FreeCoins`, `Testing`). They must be treated as
   **named objects only**, not as usable privilege or payout features.

## What still cannot be inferred from this snapshot

- Private authoritative server scripts or real server anti-cheat checks
- Whether any optional combat/network claim is accepted without validation
- Whether a hidden client GUI corresponds to a deployed gameplay feature
- Real eligibility/ownership for Mojo, rewards, quests or cosmetics
- Unreplicated islands, caves, map sectors and future game updates
- Accurate original code where reconstruction is intentionally redacted
  or the script was server-only/unavailable

## Second-pass correction to custom replication interpretation

The separate `Modules/util/flags` module in the same export
gates `customPlayerReplication` behind Studio/test PlaceIds
and selected private-server conditions. The captured game's
ordinary public PlaceId `11729688377` is not in the
explicit allowlist. The presence of
`EntityPositionalReplication` and its client encoder therefore
**does not establish that the custom player-position protocol is
active in a normal public server**. See
[BOOGA-DEEP-MECHANICS-AUDIT-v1.md](BOOGA-DEEP-MECHANICS-AUDIT-v1.md)
for source relationships and limitations.

## Best next engineering step

**Do not run another broad diagnostic yet.** This first snapshot is
complete and internally verified. Before hub development:
1. Study the `Game/*` and `Modules/data/*` source families for
   actual client-owned controls and limitations.
2. Decode packet names/types for documented network architecture,
   without executing remote calls.
3. Trace inventory/crafting/structure/health/movement relationships.
4. Rank features by `confirmed client-owned`, `observed server-held`,
   and `unverified` rather than inventing fake power toggles.
5. Only then publish a Booga-specific hub.

The original archive stays in the current ChatGPT attachment; this
GitHub report is a concise derived findings log, not an upload of
the full user-supplied game data.
