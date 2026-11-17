# FERAL project continuation

## Most recent hub release: Aurora v2.1 (17 November 2026)

The user tried Aurora v2.0 in the animal-selection menu (confirmed in chat)
and pasted a status with Species/HP/Stamina/Hunger/Thirst/Growth all --,
Amber=8272, recovery ON, 4 Rest requests/2 local WolfRest echoes,
Player Finder ON at 900 range but count 0; mobility/speed/calm and
throughWalls also locally enabled. Missing own stats in menu is NORMAL.
v2.0 Player Finder incorrectly required own spawned HumanoidRootPart, so
it skipped other players when menu was active. Existing Windows GitHub
runner was inspected; **no automatic Velocity status-to-GitHub upload
bridge exists**. Script source/code and handoff are synced by assistant
GitHub commits, not live game telemetry.

Responding to strong user feedback ("upgrade everything", hunger/thirst
fill, enable effects, tons of missing features, no more diagnostics),
published full v2.1 hub:
- [v2.1 launcher](feral-aurora-hub-v2.1.lua)
- [v2.1 engine](feral-aurora-engine-v2.1.lua)
- [v2.1 UI](feral-aurora-ui-v2.1.lua)
- [v2.1 guide](README-feral-aurora-v2.1.md)
- 74-entry v2.0 atlas retained
- [Luau/static workflow](../.github/workflows/feral-aurora-v2.1-validate.yml)

Loader:
`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-aurora-hub-v2.1.lua"))()`

11 pages HOME, SURVIVAL, EFFECTS, RECOVERY, MOVEMENT, PLAYER FINDER,
AMBER, PROGRESSION, WORLD, ATLAS, SETTINGS. New Survival scans bounding
parts by replicated food/water names with explicit click, limit 1100 parts
within 500 studs, adds water POI candidates, seven pin-to-compass rows and
native guidance. Does NOT claim to actually fill Hunger/Thirst. Player
Finder now can use current camera position in animal menu, has explicit
search origin, total other players, replicated living characters and
in-range count with reason for zero. New Effects page shows nine
individual replicated ailments/bonuses and actual helpful available
Recovery Assist, reversible local injury movement inputs, warnings and
food/water shortcut; no faux Thriving or Grazing grant. Session state
now says ANIMAL MENU, IN GAME or SPAWNING in UI and clipboard export,
and no misleading unavailable values as zero.

Other v2.1 improvements: mini own-stat HUD, local-only JSON own-status
autosave every 120 seconds if enabled + writefile supported, up to 60
own-character records per session; opt-in OFF by default, no other-player
names, coords, chat, credentials or server sources. GitHub auto-sync
NOT configured: no secret/token passed to Velocity, no silent network
telemetry. Settings include Comfort/Survival/Explorer presets, Restore All,
and feature statuses ARMED/WAITING vs LOCAL CLIENT VALUES APPLIED.
Re-running launcher closes v2.0/v2.1 screens and known earlier FERAL hubs.
World selector clears a previously pinned food/water point.
Neither build has been live-tested by assistant in Velocity; official
Luau 0.747 compile and source static checks are the current validation.
Preserve prior script versions; don't claim all features affect server
authority or protect against long Burst deaths.

User doesn't want more diagnostics. Future changes should be code-first,
respond to concrete UI reports without requesting full live scans.
If auto GitHub report sync is desired, it needs an explicitly opted-in
local file collector plus private upload pipeline; do not claim runner
automatically transfers Velocity clipboard/file data.

## New active interface build: FERAL AURORA v2.0 (17 November 2026)

User asked for a major self-directed upgrade: LOTS of features, beautiful
cohesive Roblox UI, responsive toggles/interaction, no missed obvious QoL;
then specifically requested attractive player nametags and character outline
ESP to find other people. No more huge diagnostics are wanted.

Published **AURORA v2.0** as modular Lua under roblox-tools:
- [One-line launcher](feral-aurora-hub-v2.0.lua)
- [Engine and player finder](feral-aurora-engine-v2.0.lua)
- [Original nine-page UI](feral-aurora-ui-v2.0.lua)
- [74-entry mechanic atlas](feral-aurora-atlas-v2.0.lua)
- [Full guide](README-feral-aurora-v2.0.md)
- [Luau 0.747 compile + static check workflow](../.github/workflows/feral-aurora-validate.yml)

Velocity launcher:
`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-aurora-hub-v2.0.lua"))()`

Pages HOME, RECOVERY, MOVEMENT, PLAYER FINDER, AMBER, PROGRESSION,
WORLD, ATLAS, SETTINGS. Original dark-glass teal/violet/coral design,
header drag, Right Shift show/hide and floating reopen chip, responsive
scale and hover styling. Restore All and X cleanup. Favourite atlas entries,
search/categories/page navigation, optional local JSON preferences.
Compass to 18 known POIs in a compact 3-column selector; no teleport.

Player Finder: **disabled by default**, shows nearest 24 players whose
character, Humanoid and root are already replicated to current client;
BillboardGui dark nameplate shows display name/species/distance/HP bar.
Outline Highlights are placed in a client-local Workspace folder to avoid
inconsistent PlayerGui rendering. Teal/amber/coral distance colour, subtle
or bold; 150/300/600/900-stud range, optional through-wall (OFF by default,
visible-only via HighlightDepthMode.Occluded). Explicit individual tag and
outline switches, live nearby names in hub; destroying overlays on OFF,
character changes, out of range and X. No other-player server queries or
outbound copies.

Other actual opt-in controls: native Recovery Assist (as earlier), local
brightness, calm camera, native performance setting, client injury slow
cache patch, capped 1.10x speed and leap cache experiments, warnings,
native rewards/guide UI open. All gameplay-affecting switches default OFF;
older **3x stamina pool tweak is parked and NOT loaded** because of previous
unexplained Burst deaths. Atlas documents 74 relevant code-backed systems:
exhaustion, regeneration, Amber x1-x3, Thriving+50%, regrowth x2,
Elder, grazing/home turf, 10+% damage bonus config, anti-teaming,
passives, disabled quest/ability/litter flags, etc. These are informational
not automatic rewards or server grants.

Official Luau workflow validates all 4 modules and feature scope.
**No live in-game Aurora test has occurred**; compile/static test alone
does not establish executor compatibility, visual rendering or accepted
Rest/movement effects. Source is client-side only; server death causes and
benefit eligibility are not known. Avoid stating hub guarantees survival.

The old Recovery Hub v1.3 remains unchanged in its own file for historical
reference. On new Aurora load, its old screen is closed using HubShutdown so
concurrent scripts do not unknowingly conflict. Running old hubs afterward
can coexist, so don't encourage simultaneous untested modifications.

Next user step: run single Velocity launcher, use new PLAYER FINDER page to
enable visual outlines/nametags and other desired features. If they report
a concrete UI issue, fix source directly on GitHub without asking for another
full diagnostic.

## Latest Rest-Only v1.0 live report — 17 November 2026

User ran the conservative Rest-Only Lab v1.0 again: 116.47s, 227 own
samples, Rest switch ON at report time, 21 local Rest=true FireServer
calls with zero local sending failures; 9 WolfRest=true echoes
and 9 local pose-only masks. Last HP 245/245, stamina 56.10/56.10,
hunger 55.45, thirst 82.06 and HudRest=false.

Valid partial-stamina pairs: off_still +2.89/s (14), on_still +1.57/s
(54), on_moving -1.21/s (93). off_moving had only 1 interval and
ZERO valid stamina pairs. All health recovery groups had zero eligible
pairs because no measured below-max HP windows; no HP outcome inferred.
v1.0 combines different moving gaits and periods, so this is not
an apples-to-apples controlled comparison. Still rest ON visibly
lost stamina while moving on average; a packet echo is not a
server-maintained Rest/regen grant.

Interpretation: repeated native Rest requests did not demonstrate
permanent full Rest stamina benefits during movement. There is still
no evidence the client script can protect from unexplained deaths.
Do NOT assert successful continuous full Rest benefit, safe Burst or
server acceptance. Next steps should focus on analyzing existing
client Rest controller separation versus server-known Rest effects,
not another redundant huge diagnostic. Server-only Rest, health
and enforcement handlers were never recovered.

## New live findings — v1.2 and feasibility (17 Nov 2026)

Live report: 98.35s, 16 successful local Rest=true sends and 15 local
WolfRest echoes/masks. Latest 12.02s HudRest test completed; 23/23 probe
samples locally true, 2 writes, 1 reset. There were 3 HudRest tests this
session; latest on_hud gait groups reset per probe; OFF/ON gait groups
accumulate over the whole session. HP 164/164, so no health-rate evidence.

Stamina net/s by gait:
- off_Sprint -0.87 (2 valid pairs; speed 16.28), on_Sprint -0.65
  (19 pairs; speed 16.04)
- off_Burst -3.27 (12 pairs; speed 26.80), on_Burst -3.32
  (18 pairs; speed 26.49); no meaningful Burst benefit visible
- on_Moving +0.58 (7 pairs; speed 5.89); on_hud_Moving +0.27
  (13 pairs; speed 7.22), not same speed, so no proof of HUD uplift
- off_Moving has 0 valid stamina pairs (no meaningful moving control)
- on_Still +2.83 (12 pairs). Last hunger 18.88, below recovered
  LOW_NEED_AT 20, where client config may halve recovery.

User requested always-on Rest benefits without character deaths. Explicit
limit: recovered client code is not full server code. Client export lacks
server-only Rest eligibility, health/status effect writers, stamina authority,
kill triggers and enforcement handlers. Keeping HudRest true is only a local
flag; it did not produce an additional demonstrated improvement. Sending
Rest=true at intervals is an input request, not proof server accepts rest
while Sprint/Burst. Prior abrupt 107/107-to-zero death while Burst gave a
generic other cause, not anti-cheat proof. Cannot guarantee all Rest effects
always or no deaths using the client-only scripts.

Conservative available approach: use native Rest request only, e.g. existing
Rest-Only Lab v1.0 with no stamina pool writes or HudRest forcing, or Recovery
Hub v1.3 Recovery Assist alone, avoid prolonged Burst. Neither is proven
to keep every Rest bonus or prevent all deaths. Avoid new untested bypass
labelled safe, and do not claim server-only code was retrieved.

## Most recent live HUD result and corrected follow-up (17 November 2026)

User supplied **Rest-State Lab v1.1** live output, 66.29 sec:
- Rest request ON, eight sends / zero local send failures; WolfRest local true
  observed once and local pose masked once.
- Latest 12-second HudRest probe: one client write, no observed resets,
  23/23 HUD probe samples had HudRest=true; script did not report movement
  blocked; user had Sprint and Burst samples as well as ordinary movement.
- Reported client stamina net/s: off_moving -3.00 (15 pairs);
  on_moving -0.03 (20 pairs); on_hud_moving +0.19 (39 pairs).
  HP at max; no eligible health recovery measurement.
- **Important measurement bug/confound:** v1.1 resets the current HudRest
  probe sample counters on each probe start but *not* cumulative on_hud rate
  groups. 44 on_hud moving intervals versus only 23 samples in the latest
  12s probe strongly suggests >1 probe aggregate. Also the "moving" bucket
  merged ordinary walking, Sprint and Burst, which have different costs.
  DO NOT call +0.19 proof of Rest regeneration or server acceptance.
- Client HudRest remaining true alone is insufficient: the controller's private
  rest state and server eligibility are not directly read from that flag.

New correction **Rest-State Lab v1.2**:
- Source [feral-rest-state-lab-v1.2.lua](feral-rest-state-lab-v1.2.lua)
- Guide [README-rest-state-lab-v1.2.md](README-rest-state-lab-v1.2.md)
- Loader `loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-rest-state-lab-v1.2.lua"))()`
- Luau 0.747 compile-only + static checks PASS:
  https://github.com/GSVexed/vexed-schematics/actions/runs/44107710995
- No changes to stamina or HP. Existing native Rest request, pose mask and
  optional 12-second local HudRest test remain. Report now isolates Still,
  ordinary Moving, Sprint and Burst for each phase, captures mean horizontal
  movement speed, resets HUD rate counts **per HUD trial** and reports trial
  count and actual duration.
- Next user task: fresh load v1.2, partial stamina, **walking only** for
  ~10-15 sec Rest OFF, ~10-15 sec Rest ON, then 12-second HUD probe while
  continuing the same walk. COPY REPORT. Compare off_Moving, on_Moving and
  on_hud_Moving only if average speeds/stamina ranges comparable. Don't
  deliberately run Burst; earlier deaths remain unresolved.
- No live v1.2 Roblox test yet. v1.3 Recovery Hub remains intact.

## Follow-up — HudRest cancellation test (17 November 2026)

User tested Rest-Only Lab v1.0 (70.61 sec, 137 samples): eight successful
client sends of Rest=true and eight local WolfRest echoes; no server proof.
Their report had:
- off_moving: net -1.45 visible stamina/s (28 eligible pairs)
- on_moving: net -1.13 visible stamina/s (27 eligible pairs)
- on_still: +2.76 visible stamina/s (25 eligible pairs)
- No health-rate pairs because HP at full or otherwise ineligible.
- Some near-final still samples HudRest=true, later moving samples HudRest=false.
User clarified normal Rest locks movement; attempting to move cancels normal
rest state even with the pose animation masked. They hypothesize HudRest=true
might drive stamina rest benefits.

New **Rest-State Lab v1.1** is published, separate from intact v1.0 and
Recovery Hub v1.3:
- [Source](feral-rest-state-lab-v1.1.lua)
- [Guide](README-rest-state-lab-v1.1.md)
- Loader: `loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-rest-state-lab-v1.1.lua"))()`
- Official Luau 0.747 compile-only and static tests PASS:
  https://github.com/GSVexed/vexed-schematics/actions/runs/44106352715
- Keeps Rest ON native request/pose mask and adds explicit TEST HUDREST
  mode (OFF by default), which briefly asserts the CLIENT-LOCAL player's
  HudRest attribute true every 0.2s at most. It auto-stops within 12 sec,
  if movement appears blocked or the game cancels the attribute 36 times.
  Restores the original HudRest if still holding its own true. Reports
  on_moving vs on_hud_moving, actual flag samples and reset counts.
  **Unverified in live FERAL/Velocity; this is a hypothesis experiment,
  NOT a proven server bypass or durable Rest fix.**
- Next step: Test with partial stamina: Rest ON walking baseline ~10 sec,
  then walk so HudRest is false, click TEST HUDREST while attempting to
  keep walking ~12 sec. COPY REPORT and paste outcome. Avoid Burst, normal
  rest key, other overlays/config switches; only own-character data.
  If the flag is canceled, movement blocks, or no net uplift appears,
  reject HudRest-as-causal-switch; do not blindly force it indefinitely.

## New continuation checkpoint — 17 November 2026, normal Chat

After Work usage ran out, the user requested continuing this FERAL project
in normal Chat. Their newer decision supersedes the earlier pause on gameplay
changes: focus on whether the **normal server Rest request** has measurable
benefits while walking, even at **full health**, without the previous 3x
client-side stamina pool modification. Do not claim server acceptance yet.

Published **Rest-Only Lab v1.0**:
- Source: [feral-rest-only-lab-v1.0.lua](feral-rest-only-lab-v1.0.lua)
- Guide: [README-rest-only-lab-v1.0.md](README-rest-only-lab-v1.0.md)
- Loader: `loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-rest-only-lab-v1.0.lua"))()`
- Official Luau 0.747 compile-only and static scope checks passed:
  https://github.com/GSVexed/vexed-schematics/actions/runs/44103217850
- v1.3 Recovery Hub source and its 3x client regeneration remain unchanged.
- New lab: OFF on load, no health/stamina/config writes; it sends native
  `WolfActions("Rest", true)` no faster than once per five seconds while ON,
  including at full HP, and masks only local `WolfRest` pose. OFF tries a
  same-character `Rest=false` cleanup. Observations are bounded and own-only.
- Not yet run in live Roblox/Velocity; game-server acceptance still unknown.

**Next action:** user pastes the new loader into Velocity in FERAL, gets a
~10–15-second moving baseline with partial stamina while OFF, enables
CONTINUOUS REST for ~15–20 seconds at the same walking pace, then clicks COPY
REPORT and pastes output in Chat. Avoid prolonged Burst because prior unexplained
deaths remain unresolved. Compare OFF/ON moving stamina trends, visible Rest
echoes and health intervals only if HP was below maximum; do not infer
server-only stamina budgets or combat healing from a client sample.
No additional bulk diagnostic, server-source retrieval or PC-runner reboot
is needed for this immediate comparison.

Updated 17 November 2026. Read this and [README-FERAL.md](README-FERAL.md)
before continuing in a new Chat, Work or local desktop task.

## Current task and preferences

The user wants to connect their Windows 11 PC for local project work and may
switch to normal Chat because Work usage is running low. They prefer short
replies, ready-to-run hosted loaders and actual implementation. Preserve this
handoff as decisions change. Ordinary Chat may not have the same computer,
filesystem or GitHub tools; verify available access before claiming actions.

The immediate local task is to verify the computer connection, open the project
and locate the user-approved Velocity workspace and relevant Roblox logs.
Start with read-only checks. The user asked to discuss the unexplained deaths
before the next gameplay-script change or experiment. No fresh bulk diagnostic
is needed. Do not automatically execute game scripts or start Burst testing as
part of connecting the PC. Exclude credentials, browser profiles, private
messages and other players' data.

## Project and current build

- Repository: `GSVexed/vexed-schematics`, branch `main`, directory `roblox-tools/`.
- Roblox FERAL PlaceId: `108901361810209`; executor: Velocity.
- Current functional build: [feral-recovery-hub-v1.3.lua](feral-recovery-hub-v1.3.lua).
- Guide: [README-recovery-hub-v1.3.md](README-recovery-hub-v1.3.md).
- Verification: [FERAL-RECOVERY-HUB-v1.3-CHECKS.json](FERAL-RECOVERY-HUB-v1.3-CHECKS.json).
- Gameplay source last published in commit `155ebb8d23e15e24595a77e2ccdf0f37bb2e3e28`.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-recovery-hub-v1.3.lua"))()
```

One **3X STAMINA REGEN** switch applies 3x the original client recovery rate
and adds recovery to a matched internal client stamina pool during flat or
draining intervals, including climbing. Native positive recovery is not added
twice. Normal costs and low-needs penalties remain. Four changing native HUD
samples and a strict own-callback/config fingerprint are required before pool
writes. Both gameplay switches default OFF and remain armed across respawns.

**RECOVERY ASSIST** uses the normal Rest request and masks the own local rest
pose. Earlier captures support about 2x HP recovery outside combat and faster
bleeding/venom clearance. Combat HP regeneration remains unresolved. The old
direct HP writer failed and is retired. No combat-off bypass is established.

v1.3 fixes an attribute-callback timing flaw reproduced with actual v1.2 code
in a substitute engine. Matching now happens before the hub's own write.
Temporary mismatches pause writes in VERIFYING; persistent mismatch stops and
restores owned settings. **COPY STATUS** retains a bounded short summary and
the last failure, with clipboard/text-box fallbacks. Official Luau compilation
and 63 simulated checks passed; these are not developer-run Roblox tests.

## Latest live evidence and unresolved problem

The user's v1.3 status showed **0 mismatches, 0 failure stops and 8,129 accepted
client pool writes**. The last sampled Bear frame was in Burst with HP 99/99
and stamina pool 50.181 of 50.300; the final addition reached approximately
the configured 50.250 cap. The user still died. BINDING with no animal afterward
was standby after character removal, not a recorded match failure.

This supports sustained client recovery and the absence of guard failures in
that capture. It does not establish indefinite server-accepted Burst. The
report lacks the death transition, final needs values and a native death reason.
Earlier native death feedback said only `other`, with no reason/code. An earlier
60-second reported lifetime differed from about 48.8 seconds of observed Burst;
do not invent a 60-second Burst limit or a safe reset interval.

A separate server resource/movement check is a hypothesis. Damage, world rules
and other causes have not been fully excluded. The user has not yet answered
whether the latest death occurred on dry land without attackers, or supplied
the continuous Burst duration. Discuss before changing the working regen.

## Existing data and access boundaries

The client/platform diagnostic phase is complete within its recorded scope.
Public analysis covers 339 logical game exports / 221 distinct reconstructed
bodies. Reconstruction defects remain. Private original captures are in the
earlier conversation/user files; they are not all stored in this repository.
Do not publish raw captures or private game source bodies.

Server-only scripts were not retrieved. Public Roblox metadata checked on
17 November 2026 returned `copyingAllowed: false` for FERAL. The group's public
game list exposed no separate public FERAL test copy. Searches found no official
server-source release. Existing `ServerStorage` references in shared
AbilityConfig/ElderPaint do not expose private server contents. PC access does
not grant game-owner or server access.

Amber, restricted-animal spawning, owner tools, code menus and extra effects
remain parked. No spendable-currency grant, restricted spawn, owner permission
or permanent unlock has been established.
