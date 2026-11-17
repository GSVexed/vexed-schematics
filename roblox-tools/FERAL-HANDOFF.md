# FERAL project continuation

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
