# FERAL Field Hub v1.3

v1.3 adds usable client controls after a whole-export surface audit. It preserves
the stamina path reported working on Bear and observed on Tiger, adds bounded
speed/leap profiles, native Rest assistance, owned-coat equip requests, native
comfort settings and a larger, uploadable field journal. It does **not** finish
the requested server-grant goals: added HP regeneration, arbitrary spendable
amber, restricted-animal spawns and owner privileges remain unavailable.

## Run

Open FERAL, join normally, then paste this into Velocity:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-field-hub-v1.3.lua"))()
```

The panel opens ready; there is no scan or Start button. Gameplay controls are
off initially. Run the loader again to replace earlier hub versions and restore
their owned settings first. Right Shift or **_** hides the panel; **FERAL HUB**
reopens it. **X** stops the hub and restores owned local changes. Travel already
performed and requests already sent cannot be undone by closing a panel.

## Controls

| Tab | What to use |
|---|---|
| RESOURCES | **STAMINA TUNING**; 1.25x/1.5x/2x cached land/swim inputs; 1.5x/2x forward-leap inputs; separate resets; **REAPPLY STAMINA** if fields drift |
| RESOURCES | **REQUEST NATIVE REST NOW** or optional **IDLE RECOVERY ASSIST**; calm camera, native performance mode and brighter view |
| TRAVEL | Select from 23 destinations, enter X/Z, or bookmark your position. Guidance does not move you. Scout a landing, then explicitly **MOVE ONCE** if desired |
| ANIMALS | Browse script-stripped local portrait clones, including replicated restricted assets; optional native-card visibility only |
| COATS | Preview a coat locally, or explicitly **EQUIP SELECTED OWNED COAT** through the normal game protocol |
| LIVE | Visible resources/effects and amber ledger; optional batch claim of already-eligible game rewards |
| FINDINGS | Search the evidence-backed mechanics catalog, including disabled/debug features and the limits found during the full audit |
| ACCESS | Cached own gate checks and optional own-account look/list requests. These are an access audit; no owner grant, gift or save-restore control is implemented |
| REPORT | Save the focused JSON text report; optionally enable 60-second checkpoints or continue into numbered parts |

The new controls are client experiments pending testing in Roblox. Applying
configuration inputs is reported separately from observing a gameplay effect.
Reset or close restores fields still equal to the hub's writes and preserves
identifiable later external changes. No function force-unfreezes a module.

## Health and Rest

**The earlier HP regeneration trial failed.** v1.3 never assigns Health and does
not provide added healing or invulnerability. Your later reports show ordinary
game recovery; that is not credited to the hub.

Rest assistance requests the same native action as R. Automatic assistance waits
two idle seconds when health is below 95% or a supported ailment is present. It
rejects combat, movement, water, flight, grabs, carrying, feeding, menu use and
typing, requests once per recovery episode, and stops if no resting state is
observed within five seconds. Standing up does not cause repeated forcing in
the same episode. Turn the assist off/on to rearm deliberately. The game controls
healing, interruptions and eligibility; the helper does not clear ailments.

## Real coat requests and earned amber

For a coat equip, spawn the matching species, select its portrait and coat in
the hub, and obtain a fresh normal animal-guide sync. The hub accepts only a coat
listed owned, an active slot matching your living species, and a sync from the
current character no more than ten seconds old. It sends the normal wearCoat
request once and waits for a new matching inventory sync. Local appearance
alone never becomes a success message. Rejoin persistence is not established.
Your earlier report listed Bear Spirit and Elephant Desert; current ownership
is checked again. A free/default coat absent from the owned list can still be
equipped in the normal game UI.

The reward button reads fresh server reward state, claims an eligible tier,
waits for a matching paid/state notice, refreshes and continues. It uses reported
playtime without adding local elapsed time. At most 16 play tiers and one daily
reward are requested per click, with no automatic retry after eight seconds of
silence. Nothing is purchased, and no amount is sent. If you already claimed
everything, it sends no claim. Shared native UI notices do not independently
prove which interface caused a payment. The visible wallet ledger records
changes without attributing them to the hub.

There is no arbitrary amber generator, premium-coat entitlement grant, owner
permission grant or restricted-animal unlock in this release.

## Save and upload results

1. In **REPORT**, click **SAVE FOCUSED FIELD REPORT .JSON.TXT**. Optional
   **60s FILE CHECKPOINTS** saves the current part periodically and on a
   normal close; startup never depends on file access.
2. Click **COPY LAST FIELD REPORT FILENAME**. Find that file in Velocity's
   executor workspace. It is named
   `FERAL_Field_Report_v1_3_<session>_PART_001_SAVE_001.json.txt`.
3. Upload the text file directly to ChatGPT. No clipboard excerpt or ZIP is
   needed for an ordinary session. Keep the full file.

The journal keeps its first 6,000 events, rather than evicting the beginning.
The UI and export explicitly report any later omitted events. Before reaching
that limit, **SAVE PART & CONTINUE IN A NEW PART** saves and reads back the
current part before starting another. Upload **every numbered part** for that
session. If read-back is unavailable or fails, the hub retains the part in
memory and does not rotate. Missing intervals remain missing even after a
later successful save; the report does not claim complete coverage then.

Each part has a session ID, part number, time range, counts and truncation
metadata. Copies/checkpoints of the same part overlap; retain the newest valid
copy. Manual saves receive new revision filenames. Checkpoints alternate A/B
files, preserving the preceding verified generation while writing another.
Disk writes are serialized. A corrupt checkpoint disables further
autosaves while keeping collected history. Abrupt process termination can lose
events since the last successful checkpoint. File APIs are detected, not assumed.

Bookmarks are separate from gameplay settings. Loading validates up to 24 X/Z
points and never enables experiments. v1.3 can read the old v1.2 bookmark file
if a v1.3 file is absent.

## Evidence and verification

Read the [full review](FERAL-CLIENT-CODE-REVIEW-v1.3.md),
[complete source index](FERAL-CLIENT-SURFACE-INDEX-v1.3.json),
[per-file review inventory](FERAL-CLIENT-FILES-v1.3.md) and
[goal status](FERAL-GOAL-REVIEW-v1.3.md).

Official Luau 0.747 compiles the source. **100 offline checks pass: 25 core and
75 simulated runtime/upgrade cases.** Automated checks use an engine
substitute to exercise lifecycle, cancellation, drift, rollback, file failures,
native protocols, privacy and upgrades from actual v1.0/v1.1/v1.2 scripts.
These are source/simulation checks, **not a Roblox or Velocity test**. The new
speed, leap, Rest, equip and claim paths need an in-game run before their actual
effect can be confirmed. No fresh full diagnostic is required.

The hub records allowlisted own state and known own reply fields. It collects
no credentials, chat, usernames, other players' data, raw save payloads or source
code, and sends no purchases, privileged gifts or save restores.
