# FERAL Field Hub v1.2

Implements the client improvements and focused investigation tools from the
completion checklist, including the owner-tool follow-up. Health regeneration,
arbitrary amber, permanent unlocks and restricted spawning remain unresolved.

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-field-hub-v1.2.lua"))()

The loader closes v1.0/v1.1/v1.2 and attempts to restore their owned settings.
Mutating experiments start off. Right Shift or _ hides the panel; the floating
button reopens/recentres it. X stops it and disconnects its observers.

## Controls

| Tab | New or retained behaviour |
|---|---|
| LIVE | Own resources, movement, status effects, visible wallet, native rewards shortcut and small status report. |
| RESOURCES | Same stamina path reported working on Bear; drift/module checks and explicit reapply. New reversible low-health/injury movement-input experiment. |
| TRAVEL | Existing landing checks and one-shot movement; custom X/Z, up to 24 bookmarks and optional save/load. |
| ANIMALS | Script-stripped local portraits and an explicitly visibility-only native-card toggle. |
| COATS | Local preview/trial, better Template-key matching and replacement detection. Ownership remains unchanged. |
| FINDINGS | Previous discoveries plus explicit goal status. |
| OWNER | Cached own-account predicates; optional self-only native look/list reads; conditional visibility for existing launchers. |
| REPORT | Focused own-state history, filtered ownership and a single uploadable JSON text file. |

## Stamina, movement and health

The stamina fields and character flag are the same ones the user reported
working on Bear. Reapply is separate: external edits are detected rather than
silently overwritten. Cached module identity is checked. One module job can
serve separate feature consumers without losing a callback.

The movement experiment validates both NeedsConfig.HURT_SLOW and
StatusConfig.INJURY.SLOW_PER_POINT, then sets those cached inputs to zero.
If the second write fails, the first is rolled back. It does not change
health, injury points, bleeding, venom, damage or growth. Actual movement
effect and server acceptance have not been tested in Roblox.

The failed HP-writing loop remains retired. Read-only health/maxima property
observations record growth, needs, rest, combat and supported status context.
Gain-then-drop timing does not identify a server or script writer.

## Owner gift/save tools

The recovered gift UI includes positive/negative amber adjustments,
individual/all-animal gifts, coats, revives, pending deliveries and cancellation.
The save UI lists versions, restores one and undoes a restore. Its text says
restoring can kick the target and replace progress. Their server handlers
were not recovered.

In OWNER:

1. CHECK MY CACHED OWNER TOOL GATES reads already-loaded GiftConfig,
   OnboardingConfig and DevConfig. It checks only the current account's client
   predicates. No role data is changed, and neither account IDs nor owner lists
   are retained.
2. CHECK SERVER GIFT LOOKUP optionally sends the native FeralGive look request.
3. CHECK SERVER SAVE-VERSION LIST optionally sends the native FeralSaveAdmin
   list request.
4. SHOW EXISTING LAUNCHERS changes only visibility for a native gift/save UI
   that already exists and whose corresponding cached predicate matched.
   It creates no admin panel and invokes no native button handler.

The two requests are explicit button actions, always targeting the current
account. There is no arbitrary recipient input. Neither runs at startup.
One request per tool may remain pending; there is no automatic retry, and
an eight-second soft waiting notice keeps the other controls usable.
Stopping/closing invalidates late results.

A returned target must match the current account before metadata is kept.
The gift result may retain an own-save amber snapshot; the save-list result
may retain only version count and undo availability. Names, IDs, raw saves,
version contents/IDs and raw errors are discarded. Saved amber can be stale
and is not a purchasing-power test.

**A matched client predicate or an accepted read does not establish gift,
restore or other write permission.** The hub submits no gift, cancellation,
restore, undo, reset, kick, grant, role change or other-account query.
Existing native UI behaviour remains the game's responsibility.

## Uploading focused evidence

1. Run the hub and play normally, using stamina tuning if wanted.
2. Optionally use OWNER's self-only checks. The normal animal/reward UI can
   produce the ordinary replies observed by the hub.
3. In REPORT, click SAVE FOCUSED FIELD REPORT .JSON.TXT, then COPY LAST FIELD
   REPORT FILENAME.
4. Find that file in Velocity's workspace and upload it directly to ChatGPT.
   A ZIP or another comprehensive scan is unnecessary.

The filename is FERAL_Field_Report_v1_2_<timestamp>.json.txt and the schema is
feral-field-report/1.2. Exact read-back is checked when readfile is available.
Failed/corrupt read-back does not mark a report verified. The small COPY HUB
STATUS control remains in LIVE.

History is bounded to 600 timeline events; discarded events and truncation are
explicitly counted. Bounded summaries separate known species, activity and
tuning states. Requested tuning is distinguished from matching cached inputs
and the character flag. Sampling is approximately once per second and depends
on scheduling. This is a rolling observation, not a complete lifetime history.

Known species/coat boolean fields are copied from natural own-client inventory
syncs. Missing fields are unknown/not reported. Ownership does not establish
restricted-spawn permission. No names, IDs, chat, other players' data, raw
reply payloads, credentials, arbitrary attributes or reconstructed sources
are exported. Own health, position/speed, visible wallet and limited own
ownership/read metadata are included.

## Places, travel and restoration

Custom coordinates must be finite and within +/-8192 studs. Selection never
moves the character. Scout and Move Once remain separate and revalidate
loaded geometry. The oasis is labelled as a normal POI.

Save/load uses FERAL_Hub_Places_v1_2.json.txt and accepts only a dense array of
at most 24 valid coordinate pairs. Malformed files preserve the current list.
Loading never enables experiments. File APIs are optional and not required
for startup.

Travel still cannot guarantee safety, all hazards or server acceptance.
Position observations now compare body centres rather than offset root parts.
Local coats remain local. STOP EXPERIMENTS restores owned tuning, lighting,
menu/launcher visibility and coat settings; prior movement is not reversed.

## Verification

The official Luau compiler accepts v1.2. **19 core and 52 simulated runtime,
fault and upgrade checks pass.** Coverage includes actual v1.0/v1.1 upgrades,
cache races, rollback, external edits, late results, privacy, self-only
read verbs/targets, launcher predicates, rolling budgets, saved places,
corrupt read-back and observer cleanup.

An API fallback defect affecting global readfile was found and corrected
before publication. The engine substitute is not Roblox: the full v1.2 UI,
owner reads, movement adjustment, travel and appearance effects have not been
independently tested in Roblox/Velocity. The existing stamina path has the
user's Bear field report.

Run:

    python roblox-tools/tests/test-feral-field-hub-v1.2.py

FERAL_LUAU can point to the official Luau CLI. See
[the goal review](FERAL-GOAL-REVIEW-v1.2.md) for the remaining server-dependent
goals and source evidence.
