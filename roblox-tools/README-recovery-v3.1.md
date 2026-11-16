# FERAL Recovery Supplement v3.1

Two buttons collect a menu capture and an active-character capture into one
export folder. This supplements the previous complete v3.0.3 export; retain it.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-recovery-supplement-v3.1.lua"))()
```

1. Run the loader while in FERAL's animal menu. Click **1. MENU CAPTURE** and
   wait for **Menu saved**.
2. Spawn as a **Tiger**, close the animal menu, then click **2. IN-GAME CAPTURE**.
   Remain alive during its 30-second observation. No specific gameplay action
   is required. Wait for source recovery and the world inventory to finish too.
3. When the panel says **Both captures saved**, use **COPY FOLDER**. Locate that
   `FERAL_Recovery_v3_1_...` folder in Velocity's workspace. Right-click the
   **entire parent folder** in Windows 11, choose **Compress to ZIP file**, and
   upload the resulting ZIP. It contains both captures. No need to resend the
   previous full export.

If size limits require separate ZIPs, compress and upload every `UPLOAD_PART_*`
folder, including part 000 metadata. Each part has a session/part marker.

## Controls

| Control | Action |
|---|---|
| MENU CAPTURE | Two-second menu observation, targeted source recovery, then current game-root inventory |
| IN-GAME CAPTURE | Requires a living local character outside the menu; records 30 seconds, targeted sources, then current game-root inventory |
| PAUSE / RESUME | Pauses cooperative collection; native calls may finish first |
| STOP & SAVE | Stops the current capture, records unattempted targets, retains completed files |
| SAVE CHECKPOINT | Requests a checkpoint during collection; saves immediately while idle |
| COPY FOLDER | Copies the session's export-folder name |
| COPY STARTUP REPORT | Copies a short, privacy-safe capability/error report |
| HIDE / FERAL SHOW | Minimises/restores the panel; does not stop collection |

The panel has `ResetOnSpawn = false` and stays available between captures.
It does not close automatically. Repeating a capture adds another numbered
capture to the same session. Rerunning the loader creates a fresh session on
the next capture click; it does not resume an earlier session.

## What the source pass does

- Resolves all **64 previously syntax-failing file sets by path**. Old numeric
  IDs appear only as provenance, never as current instance addresses.
- Includes **seven passing but suspicious reconstructions**: RegrowConfig,
  FloodConfig, PerfConfig, WolfController, FlightConfig, SurvivalConfig and
  CoatMasks. This is 71 target paths per capture.
- Reads a Source property when legitimately readable; otherwise uses the
  available `decompile(instance)` capability. No alternative decompiler or
  undocumented Velocity option is assumed.
- If a working `loadstring` compiler is available, checks syntax **before and
  after privacy filtering**. Returned closures are discarded, never executed.
  Compiler errors are recorded by status and available numeric line/column;
  arbitrary error messages that could echo source are withheld.
- Makes at most two reads/decompilations per target per capture. A retry occurs
  for rejected filtered text or ordinary source API failures. Exact identical
  raw retry output ends further retries. Three consecutive timeouts end that
  source pass. One decompiler runs at a time.
- Stores filtered source chunks, both syntax results, a filter comparison,
  per-target final status, and baseline filtered checksum/length comparison.
  A baseline checksum match is explicitly not an exact-equality proof. Reuse
  of a current-session text requires exact equality with read-back verified
  data. Raw bytecode is not retrieved or exported by this supplement.
- A raw syntax pass followed by a filtered syntax rejection is marked
  `filter_regression`. Text already rejected before filtering is labelled
  separately. Passing syntax never establishes faithful reconstructed logic.

**This cannot guarantee repair of those 64 reconstructions.** A decompiler can
return the same invalid text twice. The export reports that result instead of
silently adding punctuation or inventing missing control flow. If no compiler
passes the capability self-check, sources are exported with checks explicitly
marked unavailable, ready for offline validation.

The privacy lexer inherited from v3.0.3 does not safely support Luau backtick
interpolation. Such a source, if newly returned, is explicitly not exported;
its status is retained. None of the 71 baseline target texts contain backticks.

## Inventory and observations

Each mode inventories accessible current roots: ReplicatedFirst,
ReplicatedStorage, Workspace, Lighting, SoundService, StarterPlayer, StarterGui,
StarterPack, Teams, and LocalPlayer's hierarchy. Ancestor context is included.
Other players and sensitive branches are excluded. UI text/input is omitted.
Properties use the explicit inherited v3.0.3 schema, recorded in coverage data.
Active animation-track metadata is included where accessible.

The observation records only LocalPlayer and the local character: sanitized
attributes, health/max health, movement-related Humanoid properties, actual
timestamps, menu/despawn flags and observed species. The requested polling
interval is 0.1 seconds, not a guaranteed frame rate. Death/respawn/context
changes during observation remain visible in the samples. Pausing can extend
wall-clock times and does not fabricate missing samples.

The previous export already preserves CorePackages/CoreGui sources. This tool
does not repeat their entire source pass. Non-target scripts encountered in
the new game-root inventory are explicitly listed as outside the targeted
source scope; newly encountered ones may need subsequent source collection.
Inventory counts are cumulative observations across captures, not distinct
instances. IDs are local to this supplement and can recur across captures.

## Export contract

All files are text data ending in `.txt`; no PowerShell/CMD/executable packaging
helper is written. Each session contains:

- `READ_FIRST.txt` and part 000 metadata: manifest, coverage, target plan,
  summaries, immutable checkpoints, and checksummed file catalogs.
- Numbered data parts containing `captures/C001_menu/...`,
  `captures/C002_ingame/...`, and any repeated captures.
- `observations/local_*.ndjson.txt`: local time-series samples.
- `recovery-attempts/game_*.ndjson.txt`: each source attempt, syntax comparison,
  sizes, checksums, privacy edits and source-file references.
- `target-results/game_*.ndjson.txt`: one terminal result for each of the 71
  paths per capture, including missing, cancelled and failed targets.
- `sources/game/T*_A*_part*.source.txt`: successfully filtered source chunks.
  Shared references can point to a previous attempt or capture; use `files[]`
  from the corresponding attempt/result rather than guessing filenames.
- Full selected-root objects, attributes, values, scripts, UI properties,
  asset references, remotes/bindables, exclusions and error records.

Files are verified by exact read-back when `readfile` is available. Missing
read-back support is counted as unverified. Catalog Adler-32 values and byte
lengths support offline integrity checks, not authentication. Limits, partial
captures and omitted content are explicit. After a write/verification error,
use the last intact checkpoint; later files may be unreferenced. A native
worker that cannot be cancelled blocks further captures in that panel to
avoid overlapping decompilers.

## Read-only scope and validation

Only this tool's own GUI and its export files are written. It does not modify
gameplay values, invoke gameplay remotes/bindables, intercept traffic, require
game modules, execute reconstructed code, inspect debug/getgc state, retrieve
server-only source, or collect authentication/session data. A snapshot cannot
retrieve streamed-out or unreplicated content or prove the server's rules.

Build reproducibly with `python3 roblox-tools/build-feral-recovery-v3.1.py`.
See [VALIDATION-recovery-v3.1.md](VALIDATION-recovery-v3.1.md) for checks and limits.
