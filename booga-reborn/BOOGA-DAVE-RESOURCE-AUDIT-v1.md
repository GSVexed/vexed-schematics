# Dave — Booga Reborn rare Pie resource audit v1

**Investigated:** 17 Nov 2026. **Target game:** PlaceId `11729688377`, archived place version `32961`.
**Raw evidence:** User's previously uploaded, integrity-verified
`UPLOAD_PART_010_DATA(1).zip`. Read the actual recovered source
and saved `objects/game_00173.ndjson.txt` /`values/game_00004.ndjson.txt`.
This is a derived report, not a copy of the user archive.

## Bottom line

**Dave is a replicated resource model, not a player or animal boss.**
Two separate Dave models were present in `Workspace.Resources`.
Each has a server-updated `Health` IntValue and an `EntityID`.
Dave has roughly **23.9 million HP**, while public Booga Reborn
community wiki pages report it yields **25 Pie** on destruction.
Pie is reportedly exceptionally valuable and restores the hunger bar.
That specific **drop table was not recovered from private server source**;
its amount comes from community wiki material:
- https://booga-booga-reborn-wiki.fandom.com/wiki/Dave
- https://booga-booga-roblox.fandom.com/wiki/Dave
- https://booga-booga-reborn-wiki.fandom.com/wiki/Pie

## Dave models in actual captured game tree

| Entity ID | Observed Health value | Approx. position X / Y / Z |
|---|---:|---|
| `1462` | `23,899,202` | `-1314.25, 0.70, -1875.72` |
| `1463` | `23,900,822` | `1856.07, -29.18, 1330.07` |

Both are `Model` instances under `game/Workspace/Resources/Dave`,
both tagged `Entity`, and both have `Health` (`IntValue`),
`Leaves` (`Part`), `Stump` (`Part`), with the stump as
`PrimaryPart`. The recorded `EntityID` attributes identify
different actual live entities, not duplicated item-data entries.
Locations are **snapshot coordinates**, not a guarantee of every
server/spawn version. The exact Health values differ slightly
from the community wiki's `23,900,792` and should not be
mislabelled as two different maximum-health configurations.

## Attack path from recovered client code

1. `ReplicatedStorage/Game/tool` dispatches `Slash` / `Combat`
   through the local equipped tool and uses its `speed` and
   `Data.lastToolUse` for client swing scheduling.
2. `Game/tool/Slash` and `Game/tool/Combat` use
   `Workspace:GetPartBoundsInBox` with the
   `Modules/util/gameUtil.hitboxSwingSize` (6,11,5),
   collect model `EntityID` references and send typed
   `SwingTool` with `entityIDs`, `cframe`, `timestamp`
   and optional `playerStates`.
3. `Game/worldEffects` **receives** `ModelHit` and
   `ModelBroken` and runs local resource effects, including
   `Game/worldEffects/resources`'s health-reactive
   visual shrink/impact effects. These are incoming updates
   rather than local grant actions.
4. The `Dave/Health` IntValue is a replicated observation.
   Manually setting it to zero in an executor would, at most,
   affect the client's display/effects and **does not
   establish a server-authorised destruction or a Pie drop**.
5. The item-data final name table contains `Dave=t27`
   and `Pie=t27`, but the decompiler has reused/overwritten
   `t27` hundreds of times. **Do NOT interpret the final
   t27 alias as Dave's genuine item config, susceptibility,
   max HP or drops.** The decompiled client does not
   reliably establish the server loot recipe.

## Baseline damage and why Dave is a very long grind

The reconstructed original item data describes the God Axe with
`toolType="Axe"`, `useType="Slash"`, `speed=1/3`,
`damages={wood=50,lifeforms=30,woodStructure=50}`.
The community wiki likewise lists 50 wood damage and speed 1/3.
Assuming Dave actually accepts 50 damage each completed God Axe
hit (as the community wiki's Dave discussion suggests),
no recovery, no latency and that 1/3 seconds means one swing
every 0.333 s, then:
- 23,900,792 / 50 = **478,016** successful individual hits
- One attacker: **44.26 hours** nominal nonstop swing time
- Two attackers: **22.13 hours**
- Four attackers: **11.07 hours**
- Thirty attackers: **1.48 hours**

These are simplistic idealised estimates, **not** live
performance measurements or guaranteed server acceptance. The
wiki's 22-hour/two-player estimate follows the same arithmetic;
its "15,934 hits" full-server figure likely refers to 30 simultaneous
God-Axe waves (478,016 / 30 ≈ 15,934), not 15,934 individual hits.
The public Booga Reborn Wiki also lists **Rock** in Dave's
"Tool(s)" infobox, which could be a damage-type field. It
does not prove that Rock is optimal. Need live verification
of actual Dave damage before relying on Axe assumptions.

## Candidate acceleration paths and limitations

**Grounded, low-risk:**
- Equip highest damage **accepted** tool for Dave's resource type;
  God Axe is documented, but verify observed HP change from a hit.
- Use the native `holdToSwing` Booga game setting for automated
  sustained *normal* swings. It is actually referenced in the
  client GUI and defaulted ON in settings data.
- Haste potion/boost's descriptor says pickaxes/axes 10%
  faster; the client swing scheduler references
  `playerHasEffect("Haste")` for Axe/Pick. A reconstructed
  temporary is broken, so exact reduction is not fully trustworthy.
- Strength descriptor says tools deal 10% more damage,
  **but it is not confirmed from private source that resource
  damage to Dave specifically increases**.
- Cooperative players multiply accepted damage; competing
  hitters and lag may reduce effective gain.

**Investigate, NOT yet proven:**
- Which susceptibility/resource type `Dave` is recognised as
  by the server; Wiki Tool(s)=Rock vs God Axe discussion.
- Server hit cadence/position/distance checks; the client
  sends `SwingTool` requests but no private handler.
- Whether alternate genuine projectiles/splash effects
  can damage Dave and at what rate. Blacklisted
  developer-only explosive tools are **not proven obtainable**.
- Whether there is any exploitable difference between
  the client swing cadence and server acceptance. A flood
  of forged SwingTool requests would not itself demonstrate
  a valid/credited hit and could be throttled.

**NOT grounded as functional:**
- Locally setting `Dave.Health.Value=0` to receive Pie
- Editing client `itemData` damage values to change server damage
- Faking `ModelBroken` / deleting Dave locally for real drops
- Assuming a banned/blacklisted high-damage developer item
  can actually be equipped and used

The exported client item data contains some developer/banned
tools with `wood=300–5000` nominal attack entries; for example
a 5000-wood-damage tool at speed 0.1 is marked `banned=true`.
Those are **source definitions**, not accessible legitimate
equipment or confirmation of working remote authority.

## Haste and Boulder: direct source-level check after failed v2 test

A user tested Dave Fast Break v2 with a **Boulder** and observed
approximately **10 Dave HP/s in every stage**, including accelerated
typed-packet request rates. This is a user observation, not a
controlled server-acceptance benchmark for other equipment.

The archive's reconstructed `Game/tool` module checks
`statusEffects.playerHasEffect("Haste")` but only enters its
speed-reduction branch for `itemData.toolType=="Axe"` or
`itemData.toolType=="Pick"`. Its apparent adjustment is a
**hard-coded 10% of the tool's `speed` interval**, not a lookup
of the configurable `boosts/data.Haste.percent` value. The
decompiler produces an uninitialised temporary variable inside
the expression; treat the intended 10% as supported by the game
boost descriptor and the existence of the branch, not as a
perfectly reconstructed formula.

`Modules/data/settingsData` and the tool-category data group
`{"Rock","Boulder","Megalith","THE MOUNTAIN"}` separately from
Axe/Pick. Additionally the gamepass item `Boulder` is described
in the recovered `Modules/data/gamePasses` as dealing 4× rock
damage. Thus **normal Haste is not expected to accelerate
the user's Boulder**, and the user's 10 HP/s result is not
surprising. The exact server damage class is not recovered.

The Haste buff metadata `Game/boosts/data` sets
`percent=10` and description "Pickaxes and axes are 10% faster",
but `Game/boosts` uses that percentage to render its **boost UI**
and to display incoming `SetBoost`/`UpdateBoostPercent`
messages. Changing the display percentage to 500% does not
change the hard-coded tool timing branch or server validation.

Legitimate Haste: `Modules/data/cauldronRecipes` has
`definePotion("Haste",{Iron=2,Lemon=8})`; the actual inventory
item `Haste Potion` has `potionType="Haste"` and
`useType="Drink"`. The server is responsible for granting
a real effect; setting a player attribute only on the
local client is not proof of a server-accepted Haste buff.
Even if a client item `speed` field is edited, previously
observed 10 HP/s under extra outgoing packets means
we **cannot** claim this will accelerate Dave.

**Next evidence-based priority:** establish Dave's accepted
damage-type weakness and compare *actual* 10 HP/s Boulder
versus confirmed axe/pick+real Haste, using replicated HP
change. Do not build a user-facing "500% Haste" ON button
that only updates cosmetics or client animation speed.

## Best product direction

A Dave-focused module could offer:
1. **Instant proximity discovery** of two currently replicated
   `Workspace.Resources` models named `Dave`, by real
   `EntityID`, without misleading invisible-server tracking.
2. **Server-observed HP/damage-per-hit readout** based on
   incoming replicated Dave.Health changes, not spoofed
   local changes.
3. **Equipped-tool validation** using itemData damage types
   and normal combat distance.
4. **Hold-to-Swing / Haste / Strength assistance** using real
   owned effects and game's normal attack scheduling.
5. **Estimated time and Pie-per-hour** based on *observed*
   accepted damage, rather than theoretical claims.

This is more honest than an unverified "Instant Dave Breaker"
button. The actual **quick-break exploit remains unproven**.
Further targeted investigation can focus on game-accepted
damage scaling rather than repeat a full 11-part collector.
