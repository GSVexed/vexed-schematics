# Booga Booga Reborn — continuation handoff

## Latest investigation: Can we smelt nonexistent Raw Gold to get real Gold?

The user explicitly proposed fabricating a completed
Raw Gold smelt to convince Booga server to grant Gold
without any initial ore. Reopened the **exact original**
attached `UPLOAD_PART_010_DATA(1).zip` (available in
/mnt/data), not prior summaries. Traced item data,
physical world item IDs, fuel/campfire structures,
`Game/cooking`, `Game/tutorial`,
`Game/inventory`, `Game/pickup`,
`Game/stats`, `Game/structures`, and
all **438** exported game source bodies.

Full report committed: [BOOGA-RAW-GOLD-SMELTING-AUTHORITY-AUDIT-v1.md](BOOGA-RAW-GOLD-SMELTING-AUTHORITY-AUDIT-v1.md).

Principal findings:
- `Raw Gold` item ID **258** -> `Gold` ID **597**,
  client `cooksTo={name="Gold",steps=100}`.
  Note reconstructed `Raw Iron=t3` and `Raw Gold=t3`
  are unreliable aliases (decompiler t3 overwrite).
- `Events/cookingStream` is a RemoteEvent but
  `Game/cooking` ONLY uses `.OnClientEvent`
  to display progress, reading float64 timestamp,
  then each 11-byte record: u32 entityID,
  float32 progress base, u8 rate, u16 goal.
  No observed client "smelt finished/credit Gold"
  request and no `cookingStream:FireServer`.
- `Game/inventory` requests DropBagItem with
  current inventory key/index; server-linked
  ItemAdded/Changed/Removed are incoming listens.
  `Game/pickup` sends a real existing world EntityID.
- `Game/tutorial` cooks physical dropped raw meat
  next to lit Campfire; patchNotes explicitly
  mention newly spawned smelted world items
  auto reattaching to chests. Strong evidence
  server-managed world-item conversion.
- Campfire `InteractStructure` uses structure
  EntityID plus actual chosen fuel itemID.
  Coin Press `InteractStructure` uses structure
  EntityID plus inventory Gold item ID; in
  source Gold has `gold=true` flag and
  `cost=12` (shop price flag; not live-verified).
  Neither is a server-authenticated smelt receipt.
- Smelter Mojo item ID **1054**, client tier
  descriptions 10/25/40/50% chance for
  real ores to auto-smelt when mined.
  This needs actual ore and owned Mojo.
- Current world snapshot: 3 real Raw Gold
  drops, 1 Coin Press model, 0 live Workspace
  Campfire models (though template present).
- External game wiki (booga.gg and Booga Reborn Wiki)
  reports Gold smelting ~100s, Gold Node
  drops six Raw Gold, and Coin Press converts
  1 Gold to 5 Coins. These are **public wiki
  assertions**, not server-source verified.
- No server-side business logic available.
  Thus no demonstrated method for forging
  a nonexistent ore or profitably minting Gold.
  Don't claim impossibility or invent a
  gold spawner; don't build another placebo.

## Latest focus: money, item spawning, false Gold records

The user paused Dave and asked for "lots of money",
possibly through spawning items. User suggested giving
the server fake but convincing Gold Bar existence data,
asked to carry on investigation while answering the idea.

Investigated the existing uploaded complete ZIP offline,
no gameplay remote calls. Analysis saved in
[BOOGA-ECONOMY-ITEM-GRANT-AUDIT-v1.md](BOOGA-ECONOMY-ITEM-GRANT-AUDIT-v1.md).
Key findings:
- Actual item name is `Gold` **ID 597**,
  not "Gold Bar". `Raw Gold` **ID 258**,
  smelt `cooksTo={name="Gold",steps=100}`.
  `Pie` ID 565; `Coin` ID 70.
- `Game/pickup` sends existing world `EntityID`,
  not invented complete item data. Locally drawn
  Gold model is not server-owned world entity.
- `Game/inventory` listens to `ItemAdded`,
  `ItemChanged`, `ItemRemoved`,
  `UpdateInventoryFromRebirth`. It does not
  send these server events in sampled code.
- `Game/globalMarket` sends `MarketRequest`
  for deposit/list/withdraw. Local UI computes
  available quantity from `Data.inventory`/
  `Data.coins`. Market codes include
  insufficientItems/insufficientSpendable/
  insufficientCoins/depositFailed/withdrawFailed.
  These show error protocol, not proof of perfect
  authoritative server validation.
- `FreeCoins` is actual RemoteEvent in
  `ReplicatedStorage/Events`, but zero
  references to its name in 390 extracted
  ReplicatedStorage source bodies. No server
  handler is accessible. Name not proof of payout.
- Normal money avenues: smelting Gold from ore,
  selling fish, market listings, trade, quests,
  daily rewards. No demonstrated client-authored
  real Gold/item/coin minting.
- No need to run another massive diagnostic.
  Do not fabricate a Gold spawner or assume
  forged metadata tricks private server checks.

## New focused finding — Dave rare Pie farming (Nov 17 2026)

The user's request shifted to Dave, a destructible resource which
reportedly drops rare valuable items. Reopened actual uploaded
client archive, not just summary, and independently browsed
Booga Reborn community wiki. **[Dave audit](BOOGA-DAVE-RESOURCE-AUDIT-v1.md)**
saved with evidence, tool math and practical limits.

Client object data: TWO Workspace.Resources.Dave models,
EntityIDs 1462/1463, Health IntValues 23,899,202 and
23,900,822, positions approx (-1314.25,0.7,-1875.7)
and (1856.07,-29.18,1330.07). Each is Entity-tagged,
has Stump/Leaves. Wiki full health ~23,900,792, drops
**25 Pie**, described as rare/high-value, current trade price
not verified. Wiki says both on void islands.

ItemData reconstructed God Axe: wood damage 50, speed 1/3,
nominal hits 478,016, ~44.26 hours solo or ~22.13
hours for two if continuous successful attacks; wiki's
22-hour/two player estimate matches. 10% Haste axes,
Strength +10% tool damage description, but applicability
to actual Dave resource damage cannot be guaranteed.

Client SwingTool sends entityIDs/CFrame/timestamp;
ModelHit and ModelBroken are received network updates
triggering effects. Editing replicated Dave.Health locally
will NOT server-break or yield Pie. Banned developer tools
in itemData have larger wood stats (up to 5000/0.1),
not proof of legitimate access. Decompiled itemData aliases
`Dave=t27` and `Pie=t27` are unreliable because
t27 is overwritten many times; don't claim source supports
Dave's server drop table. Still no verified instant-break
method, but candidate route is normal hold-to-swing,
correct tool, Haste, cooperative play and **measured**
server-observed per-hit HP damage. No new broad diagnostic
needed. Need not create placebos.

## CURRENT INVESTIGATION RESULT: second-pass source audit

The assistant reopened and studied the user's actual attached
`UPLOAD_PART_010_DATA(1).zip` and local source references
(not just prior conversation summaries). A full 355-line
**[BOOGA-DEEP-MECHANICS-AUDIT-v1.md](BOOGA-DEEP-MECHANICS-AUDIT-v1.md)**
was committed, with evidence-backed values, source module paths,
unknowns and a ranked hub plan. Highlights:
- Workspace: 23,294 objects, Resources 1,712 models (53 kinds),
  Critters 357 models (34 kinds), Deployables 46 models (14 kinds),
  1,259 `Pickup` tags. Use real `Workspace.Resources`,
  `Critters`, `Items`, `Deployables`, `EntityID`,
  `Entity` and `Pickup` tags for ESP. No fake categories.
- ItemData `v513` final table: 1,194 named entries (389 inline
  and 805 aliased), 11 potion effect types, at least 5
  blacklisted spell-like entries and four special Glide capes
  with flyspeed 95/115/190/380 (not proof of entitlement).
- Native QoL settings `Modules/data/settingsData`:
  `autoFpickup`, `holdToSwing`, `dontReclickCraft`,
  `quickDrop`, `structureSnapping`, `visualizeHitboxes`,
  `animalRenderDistance`. `Game/pickup` checks 25-stud
  distance, bag capacity, held input; no infinite range.
- `Game/spawning` speed inputs 16 base, 50 jump, affected
  by Voodoo Vortex/poison/web/Swiftness/water/Water Walker.
  Complex decomp contains nonsense locals: do not treat exact
  code as production-safe. `Game/tool/Glide` has client
  BodyGyro/Velocity mechanics, but gear/server constraints unknown.
- Resourceful half-cost deployable ingredients
  `max(ceil(required/2),1)` in BOTH crafting UI and
  gameUtil.canCraftItem.
- Owned Mojo tiers and disabledMojo are separated and listen
  to `MojoChanged`/`UpdateMojoItem`; combat/inventory
  sends `SwingTool`, `Pickup`, `CraftItem`, etc;
  boosts listen to `SetBoost`/`RemoveBoost`.
- Flags: `inventoryBurstLimitations=false`,
  `newMap=false`, `npcDebugHitboxes=false`,
  `anticheatDebug=IsStudio()`. `customPlayerReplication`
  is conditional and generally NOT enabled for normal
  public PlaceId 11729688377 despite encoder presence.
- Static typed packet usage: 230 unique definitions;
  105 used via sends, 121 via listeners, 6 overlap, 10
  no direct static Game/* send/listen call sites.
- Ranked actionable hub priorities: resource+creature+item ESP,
  real data-based inventory/crafting assistant, native QoL
  switches, movement/effects, equipment/potion information.
  These are better evidenced than fake infinite HP/coins etc.
- No additional full diagnostic is necessary to build phase 1.

The user asked "ok continue the investigation and analysis", not
specifically to build a hub yet. Avoid implying implemented controls
until code is actually committed. The report is on GitHub; raw ZIP
remains attached to ChatGPT, not uploaded to GitHub.

## FIRST ARCHIVE RECEIVED AND VERIFIED — 17 Nov 2026, ~17:41 UTC

The user uploaded `UPLOAD_PART_010_DATA(1).zip` to this conversation.
**Despite the name, it is the WHOLE archive**: 11 upload parts including
metadata + data 001–010. No need to request other ZIP parts.

Analyzed in the container from the attached file (not GitHub).
**Checksum/integrity verified**:
- 23,296 payload files, 217,037,246 bytes, 125 catalogs, zero missing,
  mismatched or duplicate payload paths; all part markers coherent.
- 38,111 exported client source records verified against concatenated
  chunk lengths and Adler-32; 22,676 unique source file groups; zero
  source reconstruction **reference integrity** mismatches.
- 97,686 objects: 56,254 game-classified and 41,432 platform.
- 38,124 scripts: 451 game-classified (438 exported, 11
  server/unknown-context, 2 Animate decompile failures), and 37,673
  platform-classified all exported. No main `ReplicatedStorage/Game/*`
  source reconstruction failures.
- 203 remotes/bindables including 171 game; 2,957 ValueBase entries;
  18,704 attributes. `inventory_traversal_exhausted=true`,
  `source_pass_finished=true`, `limits_hit=[]`, `writeErrors=0`.
- Source status `finished_with_gaps` owing to 2 inaccessible Animate
  reconstruction attempts and 11 non-client Script objects.
- Place version 32961, session `20261117_172831_7DA66D788F0F`,
  started 17:28:31Z, updated 17:38:55Z.
- **Key discovery: 230 typed ByteNet packet definitions** in
  `ReplicatedStorage/Modules/util/packets`, beyond the 171
  game-classified remote/bindable objects.
- Significant verified game modules for inventory, crafting, structures,
  combat, tool variants, boost data, spells, Mojo, clans, tribes,
  colonies, progression, market and unusual entity replication.
- `Game/boosts/data`: explicit client boost descriptions (Haste,
  Strength, Swiftness, Healing, Weakness, SpiderWebSlow, etc.).
  `Game/classes/statusEffects`: watched player attribute names
  OnFire, OnIce, OnPoison, OnBossPoison, Silenced, OnQueenPoison,
  Debuff, Swiftness, Haste, SpiderWebSlow.
- `Game/stats` tracks `food`, not yet evidence of a separate
  thirst meter; do not transplant FERAL's survival assumptions.
- Debug/admin-esque remote names (FreeCoins, Testing, Invisafy etc)
  are **names only**, not proven callable or authorised endpoints.

**Derived results saved:** [BOOGA-FIRST-ARCHIVE-FINDINGS.md](BOOGA-FIRST-ARCHIVE-FINDINGS.md),
a 246-line report with source paths, counts, typed network architecture,
boost definitions, privacy and server limits.
Raw user ZIP was **NOT** uploaded to GitHub. Never claim it was synced.
The report is grounded in the uploaded data; no external Booga
information was substituted.

The user wants comprehensive game understanding before a powerful hub.
**DO NOT ask for another full diagnostic or missing parts**; we have the
complete first archive. Continue code analysis of the existing recovered
game-classified sources. Optional later snapshots are for streamed-out
regions, not mandatory to start development.

## Identifiers and project ownership
- Target game: https://www.roblox.com/games/11729688377/Booga-Booga
- PlaceId: `11729688377`
- Developer/publisher: Gang O' Fries Entertainment
- Separate from FERAL (PlaceId `108901361810209`)
- Repo: `GSVexed/vexed-schematics`
- Directory: `booga-reborn/`

## User request
The user explicitly wants the fullest possible accessible game code/data
collection **before** building another hub, and is dissatisfied when
collectors miss obvious categories. They strongly prefer a single
Velocity paste with a real hosted raw URL and simple controls. The
user previously believed a GitHub-hosted Lua script automatically
uploaded game reports; clarify that it does **NOT** do so.

## Published first step
Read-only Booga Complete Client Archive v1.0:
`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-complete-client-archive-v1.0.lua"))()`

Based on FERAL's tested 1705-line diagnostic architecture rather than
a thin new script; updated target, privacy, source-indexing rules and
export instructions. Captures broad currently accessible instance
tree, scripts/LocalScripts/ModuleScripts, optional permitted reconstruction,
remotes and bindables (names, not invocation), attributes, ValueBase,
CollectionService tags, allowlisted property/visual/physics/GUI metadata,
world resource and structure objects, game vs Roblox-platform classes,
asset references and animated tracks. Themes: crafting, inventory,
harvesting, combat, tribes, rebirth/Mojo, construction, survival, NPC,
world geography, economy, interface, networking.

Many optional APIs: `writefile`, `makefolder`, `readfile`,
`decompile`, `getloadedmodules`, `getscripts`, and
`getscriptbytecode` for exact bytecode identity reuse only; raw bytecode
not exported. Does NOT require arbitrary modules or call remotes, inspect
getgc, dump credentials, chat, or other private player data. Reconstructed
source may be inaccurate and intentionally redacted.

Progress UI: click START FULL SCAN, PAUSE/RESUME, STOP & SAVE, SAVE
CHECKPOINT, COPY SUMMARY, COPY STARTUP REPORT, COPY FOLDER NAME.
Exports into a uniquely named workspace folder:
`BOOGA_REBORN_FULL_CLIENT_v1_0_<session>`.
Produces up-to-24MiB `UPLOAD_PART_*_DATA` folders plus metadata,
chunked text and per-source checksums, manifest and coverage gaps. ZIP
folder manually in Windows and upload to ChatGPT. Split parts supported.
No automatic Github upload or screenshot/personal data collection.
No scanning without working output file APIs.

Supporting tools:
- `verify-booga-client-export.py` validates archive integrity
- `compare-booga-snapshots.py` compares two or more full-session ZIPs
  and reports newly discovered script/remote/path categories.
- `.github/workflows/booga-reborn-collector-validate.yml` performs
  official Luau compilation, safety scope assertions, Python syntax
  and synthetic two-snapshot diff test. **All passed** as of
  17 November 2026. No live Velocity test has been performed.

## Completeness boundaries
- Only what is replicated to the player and visible/accessible in
  the current session; no private server scripts or authoritative grants
- Streaming means a second run in a different cave/island or with
  a special UI open can reveal additional data, but it's not a
  requirement for a first report.
- Source status per known script, error counts, caps and reasons recorded
- Never promise 100% source or no missed server data
- Do not claim code dump automatically syncs to GitHub
- No need to request long pasted diagnostics: ask for the ZIP export,
  or split UPLOAD_PART zip files with metadata part

## Next response workflow
Once the user supplies a ZIP, read it fully (files.read/pages for
semantic, container for archive/manifest and programmatic inspection)
and first verify completeness/integrity with verifier. Then catalog
game vs platform sources, modules, remotes, Booga domains, and identify
strongest working client-controlled features for eventual hub.
Preserve an architecture summary in this directory.
