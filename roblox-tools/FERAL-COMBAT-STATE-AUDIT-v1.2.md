# Combat-state investigation — 2026-11-17

**No working way to remove the combat tag while preserving effective combat
has been established.** The collected client code contains a timer observation,
UI restrictions, normal attack requests and protection checks. It does not
provide the authoritative combat/health handler or an identified clear-tag
request. v1.2 therefore adds a passive measurement path, not a combat-off switch.

## Review coverage

The saved game-source folder contains 339 texts / 221 distinct SHA-256 bodies.
A deduplicated literal API search found 24 GetAttribute reads and three
GetAttributeChangedSignal subscriptions for FeralCombatUntil across 10 bodies,
with zero literal SetAttribute writes to that key. This is a scoped source
finding: indirect access, reconstruction failures and server-only code remain
outside that claim. The baseline surface index was also checked for native
combat, tutorial, AFK, settings and test-mode request sites.

| Candidate | Recovered implementation | Assessment |
|---|---|---|
| FeralCombatUntil | Clients compare the player attribute against GetServerTimeNow | Observation of a deadline; changing a local copy does not itself establish a server-side clear |
| FeralCombatNope | FeralMenu writes a timestamp; CombatTag reacts with a shake and “can't switch animals in a fight” notice | Denial notification, not a combat-disable flag |
| COMBAT_TIME=10 / COMBAT_LINGER=15 | CombatConfig values; actual deadline-setting implementation absent | A local cached value is not the server's separate cache or its current deadline |
| SAFE_WORD=false | Controls whether a hit-feedback popup displays SAFE | Presentation; it does not grant protection or clear combat |
| FeralAfk / hop | Native idle flow requests transfer to another server; UI handles a “later / in a fight” result | Does not meet the requirement to remain fighting in the same encounter |
| Settings / set | Recovered settings concern audio, camera, performance and display choices | No combat-clear setting identified |
| Tutorial safety, ForceField, FeralSafeUntil | Client hit-prediction code declines prediction for protected targets and when either player has tutorial state | A protection-related lead; prediction suppression is not proof of accepted outgoing damage or server protection |
| New-player test mode | FeralTestNewUI checks DevConfig.OWNERS, then offers start(version)/stop | Owner-gated new-player variants, not a discovered clear-tag protocol; no request submitted |
| Bite / BiteHit | Native controller sends attack start and a delayed target/time claim | Actual damage acceptance and combat bookkeeping are outside the recovered handler; removing attack requests can break combat rather than remove its tag |

No new gameplay request, admin/test-mode request, server transfer, malformed
packet, or local combat/protection edit was performed for this investigation.

## Source anchors in the original export

| Exported source | Relevant locations |
|---|---|
| S0000041 — CombatConfig | SAFE_WORD around 246; tutorial protection around 437; combat timing around 451–453 |
| S0003620 — WolfController | Bite/BiteHit around 481–499; combat read around 3934 |
| S0003625 — FeralMenu | FeralCombatNope write after combat check around 7875–7878; equivalent checks later in the menu |
| S0003634 — FeralCombatTag | Timer reads/listeners around 456–507 and denial notice around 481–501 |
| S0003630 — FeralCombatClient | Protection/prediction around 3246–3280; native FeralHit subscription around 3526; SAFE feedback around 3560 |
| S0000060 / S0003652 — SettingsConfig / SettingsUI | Defined settings list and native set calls |
| S0000063 / S0003657 — AfkConfig / Afk UI | Idle transfer settings; hop call around 393 and combat-delay text around 300 |
| S0000061 — OnboardingConfig | Shield/respawn-shield constants around 77–82 and test-variant selection around 188–208 |
| S0003670 — FeralTestNewUI | Owner gate around 12–14; start/stop around 674–680 |

These identifiers refer to the existing uploaded client export, normally named
`sources/game/<ID>_part001.source.txt`. Bodies are not republished here.

## Why v1.2 records native hit feedback

Previous reports captured local WolfBiteAt markers. Those establish input-side
attempts, not whether the game reported damage. The recovered combat client
listens to FeralHit with a hit packet containing actor, victim, damage and a
safety flag. v1.2 observes the same event but filters to packets involving your
current character, and saves only damage amount, direction and broad actor
classification. Raw actor references, identities, positions and target HP are
discarded. Unrelated actor traffic is ignored before export/counters.

For a positive outgoing damage report, the tool records the observed combat
timer immediately and again after at least one second. This accommodates the
ordinary ordering difference between feedback and attribute replication.
There are at most 32 pending followups; omitted/cancelled work is counted.
Closing or changing character prevents old followups from being attributed to
a replacement animal. Missing/replaced native remotes are handled without
issuing gameplay requests.

The report also records own safety-timer observations, own ForceField presence
and tutorial-flag presence. It does not set any of them. These values may be
affected by other local code; they are not represented as direct access to the
server's private combat state.

An untagged NPC hit, a safety-blocked hit, a brief replication gap, or a local
timer edit would not establish the requested “effective combat without the
combat tag.” Even a native positive-damage report is not an independent
measurement of the victim's authoritative HP. Those limits remain explicit.

## Verification and current outcome

The existing recovery method remains opt-in. The new trace is passive and
starts with the panel. The only gameplay request in v1.2 remains the existing
Rest boolean action; the only attribute writes remain local WolfRest masking
and the optional earlier stamina flag. No combat, tutorial or safety field is
modified.

Official Luau compilation and 50 offline simulated cases pass, including the
37 existing recovery cases plus hit filtering/privacy, unsupported damage fields, safety blocks, delayed
timer refresh, NPC interpretation, pending-work limits, remote replacement,
invalid clocks, cancellation and the actual v1.1 upgrade. These do not
establish a combat bypass. No new full-source scan is required.

## First v1.2 runtime result and stamina failure

The first supplied v1.2 capture contains 351 events in about 297.9 seconds,
with zero reported runtime errors and no omitted events. All 15 native hit
reports were incoming: four reported safety blocks with zero damage and no
combat tag, followed later by 11 positive-damage reports with combat deadline
refreshes around ten seconds. The first death followed those hits and bleed
damage. This validates incoming hit classification and tag observation within
that capture; no outgoing hit or local bite marker was recorded. It therefore
does not establish whether effective outgoing attacks coexist with protection
or without the combat tag.

A later Bear life ended abruptly while Burst was active: 107/107 HP in the
last regular sample, followed about 0.675 seconds later by a Health=0 event.
That life had no combat tag, incoming native hit feedback or recorded harmful
condition. Hunger and thirst were about 61.93 and 54.62 at the final event.
The configured stamina lease remained applied; the recovery request was
inactive throughout this life. The source's stamina tuning/flag blocks are
identical between v1.1 and v1.2; the new trace only observes native feedback.

The user reports stamina continued working and attributes the death to
anti-cheat after prolonged Burst. The capture supports an abrupt unexplained
kill/reset, but does not contain an explicit anti-cheat decision, the server
handler, actual stamina pool values or a cause-of-death field. It cannot
distinguish a server enforcement action from other unreported reset/kill
paths. Full client stamina does not establish server acceptance of sustained
Burst. Reliability of that usage is now unresolved.

The later life lasted about 192 seconds and included swimming and multiple
Burst segments. The final uninterrupted observed Burst segment was about
25 seconds. These timings do not establish a reproducible sixty-second
threshold or a safe cooldown. No arbitrary duration is labelled a bypass.
No gameplay code was changed for this evidence update.
