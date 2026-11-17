# Health findings and next implementation — 2026-11-17

The useful next step is to keep the observed mobile recovery bonus and extend
its activation to active conditions. Repeating identical combat HP tests has
not produced a new healing path. Amber and restricted spawning remain parked.

## Supplied runtime observations

The three health reports are cumulative snapshots of the same v1.0 session,
not three independent trials. Each later event list exactly preserves the
earlier prefix. The latest supplied report contains 1,142 events over about
17.5 minutes, with zero reported errors and zero omitted events. It contains
20 true and five false Rest requests. Reports remain private; no raw capture
or reconstructed game source is included in this repository change.

| Observation | Interpretation and limit |
|---|---|
| Same-MaxHealth windows before/after enabling Rest requests changed from 1.016 HP/s at 101 maximum to 2.022 HP/s at 101 and 2.048 HP/s at 102 | Consistent with the native 2x rest bonus while moving; observational support from Bear, not a universal species/condition guarantee |
| Later out-of-combat recovery continued at about 2% max HP/s with the local combat-regen flag experiment off | That local flag change is unnecessary for the observed mobile bonus |
| During combat, HP remained flat or fell; positive increases coincided with MaxHealth growth | No demonstrated combat HP regeneration from the local flag or continuous Rest requests |
| In one combat interval with Rest active, bleed amount went 6 → 2 → absent; after Rest stopped, another combat interval went 3 → 2 → 1 → absent | Consistent with faster clotting while resting, including combat; shorter, non-randomized comparison with differing initial bleed amounts |
| Own local WolfRest remained false in the masked observations | Attribute suppression worked; actual rendered pose, other clients' view and server attack acceptance still need verification |

The bleeding comparison is visible near 1029–1031 and 1034–1037 seconds from
the original launch in the latest uploaded report. This is a condition benefit,
not evidence that HP rises during combat. Reported null/absent attributes are
not treated as measured numerical zero in the v1.1 export.

## Targeted source review

This review uses the existing reconstructed client export. It does not claim
server-only source, flawless reconstruction, or proof that no other server
mechanism exists. Earlier distinct-body review found no literal client Health
writer; the Health Script inventory entry remained server/unknown context.

| Exported source | Relevant evidence |
|---|---|
| `sources/game/S0000033_part001.source.txt` — NeedsConfig, lines 121–123 | Normal HP rate 0.01, rest multiplier 2 and combat-regeneration restriction true |
| `sources/game/S0000085_part001.source.txt` — StatusConfig, lines 23–29, 68–80, 88–105 | Reconstructed injury HEAL and rest multiplier; bleeding CLOT and REST_MULT; venom FADE and REST_MULT. These are configuration leads, not a recovered authoritative status updater |
| `sources/game/S0003681_part001.source.txt` — FeralStatusUI, around 605–651 | Reads own status amount and WolfRest for display; it does not grant an HP cure |
| `sources/game/S0003620_part001.source.txt` — WolfController, around 6205–6253 | Normal Rest state sends the boolean action. v1.1 reuses that action, without altering native private variables |
| `sources/game/S0000034_part001.source.txt` — FeedFinder | Food lookup; no separately recovered health-grant call identified |
| `sources/game/S0000065_part001.source.txt` — CoatConfig | No separate recovered combat-healing grant identified |
| `sources/game/S0000056_part001.source.txt` — AbilityConfig | Recovered HP-ratio references concern combat eligibility, not a discovered healing action |
| `sources/game/S0000077_part001.source.txt` — PassiveConfig, around 249–258 | HP=0.4 belongs to the Vulture Death Sense detection threshold, not recovery |
| `sources/game/S0000089_part001.source.txt` — LitterConfig | REGEN/REGEN_AFTER belong to the disabled litter/sibling configuration, not an established player-heal route |
| `sources/game/S0000055_part001.source.txt` and `S0003645_part001.source.txt` — DeathConfig/DeathUI | Revival/death flow, including credit/prompt paths; not continuous healing for a living animal. v1.1 does not invoke it |

These identifiers refer to the original uploaded export parts; this change
does not republish those bodies. Generic remote names or an unimplemented
client setting are not sufficient evidence to fabricate a server healing verb.

## v1.1 implementation boundary

One recovery toggle requests the existing Rest signal when a living own animal
has missing HP **or** positive bleeding, injury or venom. It stays enabled
through respawns and combat, masks only local WolfRest and ends its signal when
no recovery need remains. It never writes HP, MaxHealth, injuries, bleed,
venom or the combat flag. Only the optional earlier stamina method tunes its
specific cached stamina fields and own-character debug stamina flag.

Faster clotting has supplied runtime support. The subsequent v1.1 capture below
also supports faster venom clearance and demonstrates the new condition logging
in Roblox. Injury benefit remains unverified. Condition-only activation at full
HP was checked in a substitute and has no live example yet.

## First v1.1 live capture

A separate v1.1 Bear session adds 471 events over about 169.5 seconds, with
zero reported errors and zero omitted events. It contains 25 true and two
false Rest requests. Direct condition observers recorded:

- Venom: one numeric decrease of 1 before the signal was enabled, followed by
  18 numeric decreases of 4 with recovery active. All these decreases occurred
  during combat. Five positive venom attributes were subsequently removed.
- Bleeding: three numeric decreases of 4 and six positive-attribute removals
  with the recovery signal active during combat.
- Injury: no reported numeric value or change; its benefit remains untested.

For example, the first venom sequence was 20 → 19 before activation, then
19 → 15 → 11 afterward. Additional bites replenished venom, so the full
sequence is not a single uninterrupted clearance trial. Other recorded
sequences included 23 → 19 → 15 → 11 → 7 → 3 → absent. This is substantially
stronger evidence of accelerated venom fade than the earlier configuration
lead, while remaining observational rather than randomized causal proof.

Sixty selected regular out-of-combat positive HP intervals with unchanged
MaxHealth had median recovery 0.01996 of maximum HP per second. Selection
required the same character, active requests at both endpoints, 0.75–1.3
seconds between health events and no combat at either endpoint. This supports
the existing roughly 2% mobile recovery observation. Combat HP recovery still
was not established.

There were no full-HP-with-positive-condition observations, so the new
condition-only activation remains simulator-tested rather than live-verified.
Three local bite markers occurred while the signal was active; they are not
proof of server-accepted damage. Among 314 masked snapshots, two closely
spaced readings around the same incoming Rest echo saw WolfRest true. The
mask recorded two echo corrections across the run, and subsequent snapshots
returned false. These data do not establish the rendered pose or other clients'
view. No gameplay code change was made for this evidence update.

The remaining health goal is combat HP recovery. No additional recovered
client action currently establishes it. Visual pose suppression and attack
acceptance are also not established by these attribute/input observations.
