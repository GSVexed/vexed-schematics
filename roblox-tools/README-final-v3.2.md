# FERAL Final Live Supplement v3.2

A small follow-up for the one known live client source not exported by the
71-path v3.1 recovery pass: `game/Workspace/LocalPlayer/Animate`.

**Completed:** the user's 16 November 2026 capture exported this live source,
passed both syntax checks and independent file verification, and closed the
identified gap. Its 265-byte filtered reconstruction exactly matches the
previous starter template. These instructions remain for optional reuse;
the completed diagnostic phase requires no repeat capture.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-final-gap-v3.2.lua"))()
```

1. Spawn as a **Tiger** and close the animal menu.
2. Click **CAPTURE LIVE SOURCE**. Wait for its five-second observation,
   source attempt and own-hierarchy inventory to finish.
3. Click **COPY FOLDER**. In Velocity's workspace, right-click the entire
   `FERAL_Final_v3_2_...` folder, compress it to ZIP, and upload that ZIP.

**MENU SNAPSHOT** is optional. It records the current own-player hierarchy
and defers live-source collection until spawned. It does not make an absent
character a completed live-source capture. Both buttons can use the same
session folder, but a second menu capture is unnecessary for the completed
v3.1 investigation.

Other controls retain their previous behaviour: PAUSE/RESUME, STOP & SAVE,
SAVE CHECKPOINT, COPY STARTUP REPORT, and HIDE/FERAL SHOW. The GUI has
`ResetOnSpawn = false` and does not close itself on completion.

## Scope

- One source target: the local character's live Animate LocalScript.
- Public hierarchy reads for LocalPlayer, the local character and ancestor
  context only. There is no repeat world traversal or CorePackages decompile.
- Logical `Workspace/LocalPlayer` resolves to `LocalPlayer.Character`, so the
  target works even when the character's actual Name is the username or
  another rig name. The current object is still checked against privacy and
  client-source eligibility rules.
- Other client script paths in the local hierarchy are inventoried with
  explicit outside-source-scope records. This is a supplement to the prior
  complete export, not a fresh copy of every changed client script.
- The previous StarterCharacterScripts Animate template is used only for a
  labelled checksum/length comparison. Live/template identity is not assumed.
- Raw/filtered syntax comparison, privacy filtering, bounded workers, exact
  file read-back, text-only files, source chunks, manifests, catalogs,
  checkpoints and explicit terminal target records are retained from v3.1.

The 64 previously rejected game reconstructions are **not retried or repaired**.
The earlier menu/Tiger test already returned identical invalid text. Syntax
acceptance also does not establish faithful reconstructed logic.

## Status meanings

| Status | Meaning |
|---|---|
| `live_supplement_saved` | Live source exported, syntax accepted, selected inventory finished and files verified |
| `finished_with_source_quality_gaps` | A source was exported but its syntax was rejected or could not be checked |
| `finished_with_source_gaps` | Live source was missing, unavailable, oversized, unsupported by the privacy lexer, or otherwise not fully exported |
| `finished_with_inventory_gaps` | Exported source retained; one or more selected inventory/property reads were incomplete |
| `finished_with_unverified_files` | Writes completed without available exact read-back verification |
| `menu_snapshot_saved` | Optional menu snapshot saved; no live-source claim |
| `stopped_partial` / `failed_partial` | Completed files retained; inspect explicit gaps and the last intact checkpoint |

All statuses retain the known limitations of the baseline decompiler.
The manifest separates `inventory_counts` from `source_counts`; eligible
scripts seen in the hierarchy are not all source targets in this small pass.
`all_original_game_sources_recovered` is always false. A recorded source body
is not a claim of original developer source or a runnable replacement.

The file layout uses part 000 metadata and numbered data folders. ZIP the
entire session folder. If split uploads are needed, include every part.
No executable Windows packaging helper is written.

The privacy lexer conservatively omits source containing unsupported backtick
interpolation; the omission is recorded. Raw source/bytecode, raw compiler
exceptions, chat/input text, credentials and other-player subtrees are not
exported. No reconstructed game code is executed, required or invoked.

Build with `python3 roblox-tools/build-feral-final-v3.2.py`.
The collector has offline validation and a successful user-run Roblox/Velocity
in-game capture. The assistant independently verified the uploaded result;
it did not operate that live client. See
[VALIDATION-final-v3.2.md](VALIDATION-final-v3.2.md).
