# FERAL diagnostic: final findings and completion status

Evidence as of 16 November 2026. This is a read-only client investigation.
It does not implement unlimited resources or alter game/server state.

**Diagnostic phase complete within the recorded client scope:** the last
identified live-source gap is closed by the verified v3.2 Tiger capture.
No additional scans are required for this phase. This does not resolve the
known reconstruction defects or the unobserved server implementation.

## Completion status

| Deliverable | Status and evidence |
|---|---|
| Comprehensive client inventory and game/platform sources | Published v3.0.3; actual uploaded run finished in 621 seconds with 37,987 eligible source exports |
| Complete uploadable dataset | Eight baseline, eleven recovery and two final-supplement parts supplied; all three ZIP sets pass the standalone integrity verifier |
| Menu and active Tiger capture buttons | Published v3.1; both modes actually ran and exported all 71 selected paths |
| Explanation of the 64 invalid game reconstructions | Raw text already rejected before filtering; both attempts and both modes unchanged |
| Health/stamina investigation | Client stamina overwrite mechanism identified; exact historical health writer remains unconfirmed |
| Broader systems investigation | Growth, elder progression, survival rewards, weather/ecology, territory, specialised movement, cosmetics and cinematics identified with evidence below |
| Entire preserved source set syntax-audited | All 22,511 canonical bodies checked without executing them; detailed counts below |
| Last identified live source gap | Closed by the actual v3.2 capture: live Animate exported, syntax accepted, independently verified and exactly equal to the filtered starter-template reconstruction |
| Original server source / perfect decompilation | Not retrieved; not claimed as complete |

## Dataset integrity

Baseline session: `20261116_042419_33AB9E25F8D1`.
The uploaded ZIP named `UPLOAD_PART_007_DATA.zip` actually contained all eight
part folders. It contained 22,845 catalogued payloads (156,090,020 bytes),
37,987 logical source exports and 22,511 canonical source bodies. Catalogued
payloads, source references, sizes and recorded Adler-32 values verify.
The baseline inventory contains 58,681 objects, 37,990 scripts, 77
remotes/bindables, 913 value records and 5,188 attribute records. [B-M]

Recovery session: `20261116_052501_0B08C69B24CD`.
The uploaded ZIP named `UPLOAD_PART_010_DATA.zip` contained all eleven parts.
It contained 1,037 payloads (236,938,231 bytes); every catalogued payload and
source reference verifies. It finished in a reported 184 seconds, including
startup and idle time between captures. [R-M]

Final live session: `20261116_111605_2F5D0A6CD78D`.
The ZIP named `UPLOAD_PART_000_METADATA.zip` contains both metadata part 000
and data part 001. All 60 payloads (12,661,699 bytes), three catalogs, five
manifest-listed controls and the whole-source references verify. The capture
ran from 11:16:05 to 11:16:15 UTC and reached `live_supplement_saved`, with
zero reported read/write/property/attribute failures and no limits hit. [F-M]

The verifier distinguishes file integrity from collection completeness and
source fidelity. It supports complete ZIPs, ZIPs wrapped in a parent folder,
and a set of individual part ZIPs. It never extracts or executes the contents.

## Source fidelity: full audit

Official Luau 0.747 was used for compile-only checks. Every stored canonical
body from the full baseline was checked; shared references were mapped back
to logical script exports.

| Category | Canonical bodies | Accepted | Rejected | Logical exports | Logical exports referencing rejected bodies |
|---|---:|---:|---:|---:|---:|
| Game heuristic | 228 | 164 | 64 | 339 | 80 |
| Roblox platform heuristic | 22,283 | 21,852 | 431 | 37,648 | 432 |
| Total | 22,511 | 22,016 | 495 | 37,987 | 512 |

There are 64 rejected **game file sets**, not just 64 logical script
instances: shared bodies mean 80 logical game exports refer to those sets.
The extra platform results extend the previous game-only syntax audit.
They are not newly missing files. Platform rejections may include compiler
version/compatibility effects; their raw pre-filter text was not exported.

[FERAL-source-quality-v3.2.json](FERAL-source-quality-v3.2.json) contains every
rejected canonical body's path, source-file references, logical-reference
count and numeric compiler locations. It contains no source bodies or player
attribute records. A syntax pass does not prove correct variable relationships
or control flow. Decompiled text must be read as evidence, not executed as a
replacement game implementation.

## The 64-file recovery result

Each of the 64 failing paths was tried twice in the menu and twice while
spawned. The seven suspicious passing files were tried once in each mode.
All 270 attempts used the exposed `decompile` function. [R-A]

The 256 failing-source attempts were rejected both before and after the
privacy filter. No raw-pass/filtered-reject regression was recorded. Each
second raw attempt was identical to its first attempt. All 142 final source
results are byte-for-byte equal to the earlier filtered baseline. [R-T]

This establishes that staying in the menu and uploading the ZIP were not the
cause of those syntax failures. The raw reconstruction was already invalid.
It does not prove every filtering edit semantically neutral, and does not
identify the decompiler's internal bug. Calling the same backend again has
no demonstrated recovery benefit. No alternative Velocity backend was found
or assumed. Original source from the developer or a genuinely improved
reconstruction method would be different evidence.

## Stamina: the important correction

The earlier +5-per-second experiment wrote the character's Stamina attribute.
WolfController maintains its own local working stamina accumulator and
publishes it back to Stamina, StaminaMax and StaminaOut with an approximately
0.1-second throttle. It clamps the internal amount against species/growth
scaling; ability/hold/venom/movement paths also affect it. The HUD reads the
published attributes. [B-C, B-H]

That provides a concrete client-side overwrite mechanism: an attribute can
rise after the experiment's write, then return to the controller's internally
calculated value on a later update. **The snapback is not sufficient proof
that the server rejected every stamina addition.** Server handling is not
fully visible in these exports.

The reconstructed NeedsConfig contains baseline STAMINA_REGEN 1.31,
STAMINA_REST_MULT 3, REGEN_DELAY 0.8, LOW_NEED_AT 20 and LOW_NEEDS 0.5.
These are named exported constants, not universally measured rates for every
animal/movement mode. AbilityConfig also applies a 0.75 multiplier to some
stamina-cost fields after constructing initial tables. [B-N, B-A]

## Health and the live Tiger trace

The in-game observation has 214 samples over approximately 30 seconds. All
samples show an active stationary juvenile Tiger. Health/MaxHealth rose from
102/102 to 105/105; Stamina/StaminaMax rose from 40.5/40.5 to 41/41. Growth
rose from 0.347716 to 0.367876. Both resources were full in every trace
sample, so these changes do not measure healing or stamina recovery from a
deficit. The growing caps are consistent with the growth-scaling code. [R-O]

Later inventory records, taken after the trace and source pass, catch movement
and a small stamina deficit (41.4/41.8). That is a separate observation, not
a recovery time series. The export is a time window, not an atomic state.

NeedsConfig contains HEALTH_REGEN 0.01, HEALTH_REST_MULT 2 and
HEALTH_NO_REGEN_IN_COMBAT true. Without the consuming server implementation,
0.01 cannot safely be called HP/second or percent/second. The exact writer
behind the earlier health corrections remains unconfirmed. A server/unknown
Health Script is inventoried; its source was deliberately not attempted.
The read-only project has not demonstrated durable extra health or stamina.

## Findings beyond resources

| System | Evidence and interesting implication | Confidence limit |
|---|---|---|
| Growth/elder | GrowthConfig extends elder growth to 2, with a 0.1 elder-stat factor for health/damage/stamina; Species.scaled applies growth/elder factors | Static design; no universal live rate claim |
| Survival rewards | SurvivalConfig formula gives +0.1 every 600 eligible seconds to x2, then every 900 seconds to x3; nominal caps at 100 and 250 minutes | Which seconds the server credits is not established |
| Drought/flood | Named pond/area geometry, drying/refilling and rising/falling stages, fish settings | Several returned tables are decompiler-aliased; not proof an event was active |
| Territory | Hex-cell helpers, claim radius/time, activity thresholds, pack/player caps and reward settings | Server awards/validation are not recovered |
| Movement | Dedicated flight, diving, climbing, talon, hippo, elephant and snake systems; flight species differ | Reading one WalkSpeed field does not describe all locomotion |
| Status/combat | Separate injury, bleed and venom settings; held-target costs and post-processing multipliers | Damaged reconstructions and absent server handlers limit exact balance claims |
| Cosmetics | CoatMasks has a 512x512 value/count buffer decoder; ElderScars modules contain stamp/site data | References/configuration are not every mesh/image binary |
| Cinematics | FilmConfig, FeralFilm and FeralCinematic contain staged actors, camera shots, prewarming and streaming preparation | Some shot tables are reconstructed incorrectly |
| Litter/siblings | LitterConfig contains grouping/catch-up fields and ENABLED=false | Presence is not a released-feature announcement |

These support future read-only reference tools, mechanics/balance studies,
map/ecology indexes and cinematic/cosmetic analysis. There is no need to
discard the Roblox platform material; it remains in the complete baseline.
CorePackages/CoreGui account for 98.95% of its script inventory.

## Final live-source gap: closed

The recovery inventory introduced two paths: own-character Health (server or
unknown context, correctly not reconstructed) and own-character Animate
(eligible client source, outside the 71-path experiment). [R-S]

The final [v3.2 collector](README-final-v3.2.md) resolved the actual character
object and collected live Animate in one decompile attempt. Its raw and
filtered runtime syntax checks both passed. The exported filtered body is
265 bytes with Adler-32 `d00a5361`. Independent byte comparison confirms it
is exactly equal to the prior StarterCharacterScripts Animate reconstruction;
this conclusion now uses collected live bytes rather than an assumption of
clone identity. Original bytecode/source identity is not established. [F-S]

The readable reconstruction waits for Humanoid/Animator, obtains currently
playing animation tracks, and stops each with `Stop(0)`. It contains no
health or stamina operations. The diagnostic did not execute that code.

The final capture also recorded 36 active Tiger samples over the requested
five-second observation. Health/MaxHealth stayed 118/118; stamina/max stamina
rose together from 42.7/42.7 to 42.8/42.8 while growth increased. These are
again full-resource observations, not a measurement of recovery from a
deficit. The exact historical health-correction writer remains unconfirmed.

All known eligible live-source gaps identified in the supplied snapshots
are now closed. Server/unknown-context Health remains intentionally outside
source collection. Streaming, explicit property/privacy scope, the 64 game
reconstruction defects and the compiler-specific platform quality results
remain recorded limitations. The dataset is not an original server project.

## Evidence references

Paths are inside the preserved ZIPs. Line numbers are exported reconstructed
text or NDJSON lines, not original developer source lines.

| Ref | Evidence |
|---|---|
| B-M | Baseline `UPLOAD_PART_000_METADATA/manifest.json.txt` and its catalogs |
| B-C | Baseline `UPLOAD_PART_002_DATA/sources/game/S0003620_part001.source.txt`, lines 5105-5108, 5490-5494, 5594-5598, 7233-7249, 7328-7334 |
| B-H | Baseline `UPLOAD_PART_002_DATA/sources/game/S0003626_part001.source.txt`, lines 9918-9925 and 11711-11717 |
| B-N | Baseline `UPLOAD_PART_002_DATA/sources/game/S0000033_part001.source.txt`, lines 121-136 and 165 |
| B-A | Baseline `UPLOAD_PART_002_DATA/sources/game/S0000056_part001.source.txt`, lines 1412-1427 |
| R-M | Recovery `UPLOAD_PART_000_METADATA/manifest.json.txt` |
| R-A | Recovery `captures/C001_menu/recovery-attempts/game_*` and `captures/C002_ingame/recovery-attempts/game_*` streams across numbered parts |
| R-T | Recovery corresponding `target-results/game_*` streams; follow each record's ordered `files[]` |
| R-O | Recovery `UPLOAD_PART_005_DATA/captures/C002_ingame/observations/local_00001.ndjson.txt`, line 1, through `local_00006.ndjson.txt`, line 32 |
| R-S | Recovery `UPLOAD_PART_010_DATA/captures/C002_ingame/scripts/game_00002.ndjson.txt`, lines 1-2 |
| F-M | Final supplement `UPLOAD_PART_000_METADATA/manifest.json.txt` and its catalogs |
| F-S | Final supplement `UPLOAD_PART_001_DATA/captures/C001_ingame/target-results/game_00001.ndjson.txt`, line 1; source `UPLOAD_PART_001_DATA/captures/C001_ingame/sources/game/L0001_A01_part001.source.txt` |

Broader-system entry points are the named modules under
`game/ReplicatedStorage/FeralWorld` and corresponding live PlayerScripts.
Source inventories and source-result references preserve their paths/types.

| Broader finding | Baseline exported source files |
|---|---|
| Growth/elder | `UPLOAD_PART_002_DATA/sources/game/S0000072_part001.source.txt`, `S0000035_part001.source.txt` |
| Survival rewards | `UPLOAD_PART_002_DATA/sources/game/S0000070_part001.source.txt` |
| Weather/ecology | `UPLOAD_PART_002_DATA/sources/game/S0000044_part001.source.txt`, `S0000100_part001.source.txt`, `S0000102_part001.source.txt` |
| Territory | `UPLOAD_PART_002_DATA/sources/game/S0000067_part001.source.txt` |
| Movement | `UPLOAD_PART_002_DATA/sources/game/S0000093_part001.source.txt`, `S0000066_part001.source.txt`, `S0000077_part001.source.txt` |
| Status/combat | `UPLOAD_PART_002_DATA/sources/game/S0000085_part001.source.txt`, `S0000103_part001.source.txt`, `S0000041_part001.source.txt` |
| Cosmetics | `UPLOAD_PART_002_DATA/sources/game/S0000110_part001.source.txt`, both `S0000111` source chunks, and `S0003033_part001.source.txt` |
| Cinematics | `UPLOAD_PART_002_DATA/sources/game/S0000116_part001.source.txt`; `UPLOAD_PART_003_DATA/sources/game/S0003676_part001.source.txt`, `S0003722_part001.source.txt` |
| Disabled litter configuration | `UPLOAD_PART_002_DATA/sources/game/S0000089_part001.source.txt` |

Where a row shortens subsequent filenames, they share the first filename's
directory. These are reconstructed, privacy-filtered texts with the quality
limits described above.

Raw pre-filter sources were not saved; those parse statuses are recorded
runtime evidence. The saved bytes and source-reference integrity were checked
independently. No reconstructed game code was executed in this analysis.
