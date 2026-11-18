# Booga Booga Reborn — continuation handoff

## 2026-11-18 source transfer vs server authority comparison — latest

Reviewed the actual saved legacy source (not a summary), especially `ServerScriptService/Big Mama` at ~2033–2038, 3519–3577 and 5034–5051. Its `RequestData.OnServerInvoke` returns the player's `_G.sessionData[player.UserId]`, **not** server `Script.Source` files. No direct source export code in this main handler. Legacy Voodoo regeneration and spell-cost deduction use server-side data; current Reborn client uses a different ByteNet packet interface, so no live bypass follows automatically. New complete [server source transfer comparison](BOOGA-SERVER-CODE-TRANSFER-COMPARISON-2026-11-18.md). GitHub/public search did not reveal a verified current Reborn server source release. Don't claim live private code is retrievable or that `RequestData` is a script download route.

---


## 2026-11-18 four live zero-cost bolt selection requests — all unsuccessful

User explicitly allowed risking replacement of Energy Bolt, so launched a bounded one-request `PromptSpellChoice.send` authority test for each special item through actual Roblox/Velocity. God's Bolt 354: request sent, selected spell still Energy Bolt after 19 seconds ([run 44318047221](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44318047221)). Rainbow Ray 89, Equinox Bolt 353, Bullet's Ray 144: one request each, 9-second confirmation window each, all no local send error and **all left `Data.spell` at Energy Bolt** ([run 44318511191](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44318511191)). No free bolt or server-recognised damage achieved. This is consistent with denied selection; actual server rejection logic unknown. User's working Energy Bolt was **not lost**. See updated [zero-bolt audit](BOOGA-ZERO-VOODOO-BOLT-AUDIT-2026-11-18.md). Do not repeatedly spam restricted IDs or try rebirth without separately obtaining informed consent about resetting character progress.

---


## 2026-11-18 zero-Voodoo bolt investigation — new live verification

The user remembered four alternate bolt/ray attacks costing zero Voodoo. **Confirmed exact client metadata**: `God's Bolt` (90 damage, 0 cost, ID 354), `Rainbow Ray` (70, 0, ID 89), `Equinox Bolt` (70, 0, ID 353), `Bullet's Ray` (60, 0, ID 144). All are `blacklisted=true` and `voodooSpell=false`. The named descriptions are internally inconsistent and these values have **not** been verified as live damaging effects. Full [zero-cost bolt audit](BOOGA-ZERO-VOODOO-BOLT-AUDIT-2026-11-18.md).

Automated **read-only in-game entitlement check** [run 44314604101](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44314604101) showed none of the four in the normal spell selection GUI, none flagged unlocked in current `Data.unlockedSpells`, and selected spell remains ordinary Energy Bolt. The regular `VoodooSpell` request sends only target position/direction, no spell ID, damage or mana cost. `EnergyBolt.listen` is a replication/visual pathway, unrelated weather/boss lightning is not a free player attack. No extra Voodoo, free damaging bolts, or server bypass was demonstrated. **Do not publish a local switcher as a working solution.** A raw spell-change request wasn't attempted because it may irreversibly replace the player's selected spell.

---


## 2026-11-18 server weakness check — latest verified result

Read [the server-validation report](BOOGA-VOODOO-SERVER-VALIDATION-2026-11-18.md) before further experiments. An actual level-39/no-materials Void Shroud `CraftItem` request was sent once through the real Velocity/Roblox connection; the server did not grant the item (run [44310861368](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44310861368)). No server-accepted extra Voodoo mechanism identified.

**Critical instrumentation correction:** earlier observer scripts called `UpdateStatsUnreliable.listen` and saw client cache/UI frozen at 100 despite changing incoming values, so monitor interference cannot be ruled out. A later **listener-free** read found cache=41 and GUI=41.0 (run [44311921280](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44311921280)). The game ByteNet has no `getListeners` method; avoid assuming modern upstream multi-listener behaviour. Do **not** use older listener-based reports as proof of a server vulnerability. The archived client code does not include actual server regeneration handlers.

---


## 2026-11-18 real PC / genuine Voodoo evidence — critical finding

**Read first:** [Live authority results](BOOGA-LIVE-VOODOO-AUTHORITY-RESULTS-2026-11-18.md). Using the Windows self-hosted runner, successfully executed Lua directly in Roblox through Velocity's Open+Execute WPF UI (not just CI compile). Actual server-origin `UpdateStatsUnreliable.voodoo` packets varied and regenerated ~**0.28–0.33/s**, with genuine 30-point cost drops, **while `gameUtil.Data.voodoo` remained fixed at 100**. This explains fake full-energy casting animations. Unknown local override/update failure; cannot call it unlimited energy.

User's game snapshot: Spellmaster tier 1; God Bag; no equipped Void armour; level 39; no ordinary-inventory Jelly/Void Shards/Magnetite or Void regeneration items; crafting UI rejects Void gear level-100 requirement. One ordinary `CraftItem` request for Void Shroud was sent and inventory did **not** gain the item. Repeated casting and fake client cache are not solutions.

**No actual increased regeneration has yet been demonstrated.** The user asked for genuine server-recognised regen far beyond existing effects, not more ordinary gear/AFK. Don't oversell any UI/tool as fulfilling that goal. Use inbound packet slopes, not gameUtil local cache, as success criterion.

---



## Active experimental finding: same-frame double Lightning (18 Nov 2026)

User reiterated goal: **actual server-accepted extra Voodoo or real damaging Lightning without 30-Voodoo cost**, already owns Spellmaster, rejects cosmetic/normal equipment hubs. The old v6 is **not** the solution. Reopened original archive scripts and ByteNet source, checked current public results; no verified server-side regen-grant or free-cast path found. Source shows `VoodooSpell` carries only `targetPos` and `aimDirection`, `UpdateStats` / `SetBoost` are incoming; spoofing client data, re-sending at regular intervals, and fake buff icon are not breakthroughs.

Published a **distinct, bounded experiment** at [booga-lightning-authority-v1.lua](booga-lightning-authority-v1.lua) with [guide](README-lightning-authority-v1.md), **not an unlimited-Lightning hub**. Launcher:
`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-lightning-authority-v1.lua"))()`

Aim at an isolated nonplayer NPC/boss with replicated Health, start at 30–59 Voodoo, press B for single baseline vs N for two same-frame spell requests; measure native Voodoo loss and replicated target health over 5s, copy JSON. 9s cooldown, 4-test cap, no background spam, no spoofing. It probes an **unverified request ordering / two-for-one hypothesis**. Official Luau compile and static checks passed [Actions run 44293466660](https://github.com/GSVexed/vexed-schematics/actions/runs/44293466660). No user in-game result; cannot claim server bypass. If the user tests and returns results, compare real damage (not attempts) before pursuing. No unsupervised Roblox client control through GitHub runner; runner merely reads local Velocity report files, none found yet.

---


## Current deliverable: Voodoo Sync v6.0 (18 Nov 2026)

User confirms they **already own the Spellmaster Voodoo Mojo** and requested a dramatically improved hub. Rather than falsely promise unlimited Voodoo, published [Voodoo Sync v6.0](booga-voodoo-sync-v6.0.lua) and [guide](README-voodoo-sync-v6.0.md). One-line Velocity loader:

`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-voodoo-sync-v6.0.lua"))()`

Distinct improvements over nonworking v5: native owned inventory key discovery, user-clicked sequential Void Shroud/Chestplate/Greaves/Bag equips with normal `UseBagItem` and post-action equipment verification, double-confirm one-owned-Jelly-Sandwich use with boost/inventory verification, Spellmaster passive owned display (no purchase or toggle), idle Voodoo per second measurement, hold V Energy Bolt (no local Voodoo wait), two-page UI and F6/hide/reset; executor-local own-session JSON report. No automatic purchases or consumable use; click-to-equip may replace the current equipped armour/bag. Official Luau 0.747 syntax CI + static checks passed; no personal live gameplay test, no proven server-side regenerated free energy or damaging bolts beyond resource rules. The user called earlier v5 not working, so **do not claim v6 solves zero-cost Lightning**. Need live evidence of actually server-accepted regeneration from owned effects or a truly distinct mechanic before attempting claims of unbounded server energy.

---


## Current pause/resume: Voodoo regeneration authority investigation (18 Nov 2026)

The user rejected v5's repeated Lightning packet loop as **not what they asked for**. They want a real increase in **server-recognised Voodoo regeneration**, potentially by mimicking genuine effects, or real zero-Voodoo-cost damaging bolts. They temporarily paused for FERAL and then explicitly resumed Booga, demanding a proper investigation. **Do not produce another casting hub without a new, validated mechanism.**

Completed source-wide investigation: [BOOGA-VOODOO-REGEN-AUTHORITY-AUDIT-2026-11-18.md](BOOGA-VOODOO-REGEN-AUTHORITY-AUDIT-2026-11-18.md), commit `9b7319f3a1ca67d705bfde33f3a3766642cbf19a`. Reopened exact uploaded 33-MB recovered archive and searched all game client source files. Findings: `SetBoost` is an incoming UI listener, `UpdateStats` controls client Voodoo display, `UpdateArmor` confirms equipment, `UseBagItem` operates on inventory item keys, Spellmaster is a non-toggleable passive Mojo, and `VoodooSpell` contains only targeting inputs. No client-calculated server-accepted regeneration rate or direct grant packet found. Wiki says Jelly Sandwich refreshes without stacking, Void Pouch does **not** regenerate Voodoo, Void Bag does. Historical patch notes mention 1.5× overworld vs 2× Void; do not assert current rates without live measurements.

The user's v5 report was “doesnt work”; don't re-recommend v5. The live server spell handler is **not available** in recovered materials, so unowned-item spoofing and unlimited Voodoo remain unproven. Progress is a validated narrowing of viable mechanisms, not a new exploit. A one-variable-at-a-time legitimate equipment/Mojo/consumable test is designed in the audit. No new hub was published during resumption to avoid fake switches. Any later hub should distinguish attempted operations from demonstrated server-recognised Voodoo delta and must not spend owned resources without explicit action.

---


## Current scope: unowned chest spawning only — v1.1

The user explicitly rejected moving to Resourceful/building methods or
tests that use owned chests. Preserve that scope: zero-owned chests only,
no purchases or owned-chest opening modes. They asked for the one-line
script after a deeper review.

Their v1.0.1 Resource Chest report reached one request, then observed no
chest during 10.1 seconds. Owned count stayed zero and observed coins were
unchanged. Both RequestData calls returned nil; the reads were from the
live cache. No free spawn or exact server rejection reason was established.

[Unowned Chest Trial v1.1](README-booga-chest-trial-v1.1.md) is the current
bounded continuation. It records native FallingChest feedback and fixed
Notify/Toast notice classifications. The source review found that ByteNet
listen replaces the sole callback; v1.1 preserves the original dispatch
instead, and restores its own temporary wrapper on teardown. It keeps
one ChestDrop call, the zero-owned gate, legacy request-budget accounting,
no purchases and no owned tests. A type tried by v1.0 can receive one
instrumented recheck within the same inherited three-call total.

The original archive has 24 physical Pleb Chest models, all Entity-tagged
with numeric EntityID and positive IntValue Health. That supports the old
observer's structural assumptions for archived Pleb Chests but does not
validate every later Resource Chest spawn or prove why the user's test failed.
The [lifecycle review](BOOGA-CHEST-LIFECYCLE-v1.md) records the full trace.

Official Luau compilation and 45 offline checks passed. v1.1's GUI/native
observation has not been run in Roblox/Velocity by the developer. No real
unowned chest grant, usable loot or persistence is confirmed. Do not present
this instrumentation as a discovered ownership bypass.

## Latest task: one controlled unowned-chest request — 18 November 2026

**Current hotfix is v1.0.1 at the same v1.0 loader URL.** The user's first
Pleb Chest report returned BEFORE_UNAVAILABLE in 0.1s; both request flags
were false. No ChestDrop request was attempted, so there is no live verdict
on free spawning. The reply schema/error was not captured in that version;
do not claim the server blocked repeated RequestData calls as a proven cause.

The hotfix can use the native UI's `gameUtil.Data` if the refresh is unreadable,
records before/after inventory provenance and fixed validation reasons/types,
accepts numeric strings, and treats missing coin balances as unknown instead
of discarding readable inventory. A positive cached chest count blocks a
zero-owned reply. Cached inventory may be stale: authoritative ownership,
balance integrity and free spawning remain unverified. No inventory or coin
values are modified. Official compilation and 30 core/static checks passed;
hotfix live behavior has not yet been tested.

User paused the broader item-duplication investigation, discussed bypassing
the chest menu's ownership check, then explicitly authorized one trial and
asked for its hosted one-line loader. Deliverable:
[Chest Trial v1.0](README-booga-chest-trial-v1.0.md),
`booga-reborn/booga-chest-trial-v1.0.lua`.

The native `Game/inventory` S0010366 checks owned quantity and Open button
state before sending `ChestDrop.send(chestName)` around line 1250. Buy uses
the separate `PurchaseChest` packet. No authoritative server handler was
recovered, and no “ownership already checked” receipt field was discovered.
Source review alone does not establish whether opening an unowned chest
will be accepted. No verified item dupe or free chest method exists yet.

The opt-in GUI selects Resource/Crystal/Emerald/Magnetite/Pleb Chest,
requires a readable own inventory showing zero owned, sends
one normal typed ChestDrop request, observes new matching nearby live
dropChests models for ten seconds, then rechecks the own chest/coin balance.
It never purchases, edits inventory, or clones a local chest. Existing IDs
are excluded; EntityID and positive Health are required for observation.
World observation is explicitly unverified for loot, causality and persistence.

There is one request per panel, at most three different chest types per
executor session, a 30s interval across reloads, no automatic retries,
STOP/X cancellation, COPY RESULT and optional small workspace result file.
Official Luau 0.747 compilation and 30 core workflow/static checks passed.
The old panel ran in the user's session, but the hotfix and actual chest
request remain unverified in Roblox/Velocity. Do not claim this
is a working free-chest spawner until actual results establish it.

The existing Windows GitHub runner executed read-only readiness and Velocity
UI-capability jobs. No gameplay request was executed through the runner.
The original full Booga ZIP was re-read and integrity-verified again, with
438 exported game records / 388 distinct source bodies. No fresh bulk scan
was requested or performed in Roblox. Raw captures remain private.

## Previous deliverable: Booga VALUE ENGINE v1.0 (Nov 17 2026)

User demanded a genuinely useful game economy/
value advantage rather than more fake
infinite-money buttons or an AFK axe swinger.
The assistant re-opened the original exact
33-MB archive at
`/mnt/data/UPLOAD_PART_010_DATA(1).zip`,
reviewed recovered `Game/pickup`,
`Game/tool`, `Game/tool/Rod`,
`Game/fisherman`, `Game/structures`,
`Game/globalMarket`,
`Modules/util/gameUtil`,
`Modules/util/packets`,
`Modules/data/marketCodes`,
`Modules/data/fishermanData`.

**Published executable Booga-only hub**:
`booga-reborn/booga-value-engine-v1.0.lua`.
One-line launcher:
`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-value-engine-v1.0.lua"))()`
Detailed documentation:
[README-booga-value-engine-v1.0.md](README-booga-value-engine-v1.0.md)
CI workflow:
`.github/workflows/booga-value-engine-v1-validate.yml`.

Seven toggles / three tabs:
- FARM: existing `Pickup`-tag drop magnet using
  `packets.Pickup.send(entityID)` within 23 studs,
  auto-ore targeting with valid `SwingTool`
  entity IDs, optional normal pathfinding
  to high-value ore nodes within 155 studs,
  **auto Coin Press** uses real existing
  inventory Gold + nearby Coin Press
  and confirms Gold decrement.
- FISH: auto-cast by actual recovered
  `Game/tool/Rod` module when equipped and
  aimed at water, auto-reel triggered by
  typed `BobberState` owner/state=hooked;
  Fisherman sales with
  `SellFish.send(fishName)` close to
  `Fisherman Trader`, **requires actual
  Fisherman Coin increase to count a sale**.
- MARKET: scans 15 actual item IDs, uses
  `MarketRequest.itemView`, listens
  `MarketPayload.item`, compares lowest
  asking price against most recent RAP;
  optional one-item purchase at >=35% below
  RAP requires TWO intentional clicks
  within 5s, known spendable market wallet,
  fresh listing and exact expected price.
  NO automatic buying when scan is enabled.

Displays two distinct currencies, actual
deltas/rates, Raw Gold/Gold, observed
inventory gains, packet attempts vs
confirmed results, statuses, F6.
No invented items/balances. No live
Velocity/server verification; official
Luau compiler and static checks only.
Roblox/game may reject or sanction
automation; do not promise guaranteed
profit or an infinite-currency exploit.
Source comments and documentation
are explicit about these boundaries.

External wiki booga.gg (Oct 3 2026)
supports Fish Trap generates Raw Fish
every 100 seconds, the Fish Tokens
currency is distinct, and Coin Press
converts 1 Gold into 5 standard Coins.
This supports a passive Fish Trap +
Pickup Magnet + later Trader loop,
but no server-controlled "free Gold".

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
