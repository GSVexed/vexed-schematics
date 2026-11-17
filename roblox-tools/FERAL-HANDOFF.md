# FERAL project continuation

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
