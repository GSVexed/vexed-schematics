# FERAL Complete Diagnostic v3.0

Read-only collection for **[COBRA] FERAL Animal Survival**, PlaceId `108901361810209`. The diagnostic saves a complete set of its collected records to Velocity's local workspace. A concise clipboard summary is supplementary.

## Run and upload

Paste this into Velocity while fully joined to FERAL:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-complete-diagnostic-v3.0.lua"))()
```

1. The panel starts the instance inventory automatically, saves it, then processes game sources followed by Roblox platform sources. No Rest, sprint, damage, or remote tests are required.
2. Wait for a finished status, or click **STOP & SAVE** and wait for the stopped status. A source failure does not invalidate a successful inventory.
3. Open the folder shown in the panel inside **Velocity's workspace folder**. The name starts `FERAL_Complete_Diagnostic_v3_0_`. The installation path depends on Velocity; this diagnostic does not assume one.
4. Double-click **Pack-FERAL.cmd** inside that folder. It verifies every catalogued file and creates numbered ZIPs with a 48 MiB target, then opens their output folder on Windows.
5. Upload **every ZIP** and **UPLOAD_INDEX.json** to ChatGPT. Send all parts before asking for the analysis. The clipboard summary alone is insufficient.

If scripts are blocked by Windows, right-click the export folder and choose **Compress to ZIP file**. For smaller verified parts, run the included PowerShell script with `-PartMiB 16`. The command file uses only local PowerShell/.NET; it makes no network requests.

Close earlier regeneration/snapshot panels yourself before starting if you want a snapshot unaffected by those tools. V3.0 detects known old panels and records a warning, but does not stop them or undo their changes.

## Controls

| Control | Result |
| --- | --- |
| **PAUSE / RESUME** | Pauses collection between cooperative steps; resumes within this session. An in-flight native call may finish first. |
| **SAVE CHECKPOINT** | Flushes the pending records and saves a new immutable manifest. Automatic saves also occur at five-second cooperative checkpoints. |
| **STOP & SAVE** | Stops starting new work, preserves completed files, and records an explicit status for every discovered script. The result is labelled partial. |
| **COPY SUMMARY** | Copies counts, limits, failures, and leading script roots. Available during collection. |
| **COPY FOLDER NAME** | Copies the relative export folder name. |
| **_ / +** | Minimizes or restores the panel. Drag the title to move it. |
| **X** | Saves and stops before closing, or closes an already finished panel. |

Inventory progress displays visited objects and the currently discovered pending objects. The final total is unknown until traversal finishes, so it is never presented as a predicted fixed total. Source progress uses the known eligible-script count and shows the current worker's elapsed time.

## Export contract

| Path | Contents |
| --- | --- |
| `manifest.json` | Latest master manifest: phase, counters, capabilities, root/class counts, limits, stream counts, source outcomes, controls, and catalog checksums. |
| `checkpoints/manifest_*.json` | Immutable manifests for interrupted-write recovery. |
| `checkpoints/SUMMARY_*.txt` | Immutable summary referenced by each manifest. `SUMMARY.txt` is a convenient latest copy. |
| `catalog/files_*.ndjson` | Every payload filename, byte length, Adler-32 checksum, and executor read-back status. |
| `objects/game_*.ndjson`, `objects/platform_*.ndjson` | Discovered hierarchy, stable session IDs, parent IDs, escaped paths, class, attributes, tags, covered properties, unavailable fields, and observation times. |
| `scripts/*` | Full discovered script inventory and source eligibility, saved before reconstruction. |
| `source-results/*` | One terminal outcome per discovered script, joined to the script inventory by ID. Contains source chunk descriptors or the reason no source was exported. |
| `sources/{game,platform}/S*_part*.lua` | All successful source exports, with privacy edits. Concatenate chunks in the exact order in the source-result record, without inserted separators. |
| `attributes/*`, `values/*` | Cross-references for attribute and value records, including permitted strings and sanitized JSON configuration values. |
| `remotes/*` | RemoteEvent, RemoteFunction, UnreliableRemoteEvent, BindableEvent, and BindableFunction metadata. No invocation, interception, arguments, or connection inspection. |
| `ui/*` | UI structure and covered presentation/component properties. Text contents are omitted. |
| `assets/*` | Asset references plus active Animator-track metadata where readable. Binary asset downloads are not performed. |
| `focus/*` | Additional cross-references for mechanics/configuration names and attributed objects. This never replaces the full inventories. |
| `logs/errors_*`, `logs/exclusions_*` | Structured errors and deliberate subtree exclusions. Arbitrary raw exception strings are withheld. |
| `coverage.json` | Full property allowlist, caps, source rules, privacy rules, capability flags, and explicit non-goals. |
| `FAILURE.json` | Best-effort failure report if the pipeline fails after creating the folder. A write failure can prevent even this file being saved. |
| `Pack-FERAL.cmd`, `Pack-FERAL.ps1`, `README.txt` | Self-contained local packaging tools and instructions. |

NDJSON is newline-delimited JSON. Data files are streamed in roughly 256 KiB chunks; a single record can exceed that size. Sources use 512 KiB chunks. Chunk boundaries can split UTF-8 characters; reconstruct the bytes first. Accepted string values are not silently shortened. Invalid UTF-8 names/paths use explicit base64 representations.

The packer checks catalog checksums, sizes and checksums for **all recorded payloads**, and the byte counts/checksums inside each resulting ZIP. It writes SHA-256 hashes and per-part file membership to `UPLOAD_INDEX.json`. Adler-32 detects accidental corruption; it is not a cryptographic authenticity guarantee.

ZIPs are independent numbered archives, each containing the same master manifest and a different `UPLOAD_PART.json`. Upload all volumes with their original names. A damaged latest manifest can fall back to an intact immutable manifest. Fallback use, active checkpoint phases, and pipeline failure reports are explicitly labelled. Later files absent from that checkpoint are not claimed as included. Earlier historical manifests and unreferenced convenience copies are retained locally; upload archives include the selected authoritative manifest and every file it describes.

## Collection and privacy scope

The tree traversal uses exposed `GetChildren` results, attributes, tags, and normal readable properties. It never calls hidden-property APIs or changes security identity. Optional `getloadedmodules` and `getscripts` supplement newly visible, parented instances; they are checked before use. Detached/nil-parented or executor-specific state is excluded and counted when observed. Game modules are never required or evaluated.

Eligible source containers are LocalScripts, ModuleScripts, and Scripts with readable `RunContext.Client`. The collector tries readable `Source` first, then optional `decompile(instance)`. Server/unknown-context Scripts get inventory records and explicit ineligible outcomes. Decompiled text is a reconstruction and can be inaccurate. Comment-only responses are reported as unsuccessful.

Platform/game classification is a **location/name heuristic**. CorePackages, CoreGui, Roblox platform storage roots, and standard PlayerModule/ChatScript ancestry are classified as platform; other roots as game. This does not prove who authored a module. Both categories remain in the export. Root counts provide actual evidence about whether CorePackages/CoreGui dominate the script count.

The diagnostic intentionally excludes:

- Other Player/character roots, known other-player identity branches, profiles/player-data branches, and private-message/authentication-data branches.
- UI `Text`, `ContentText`, TextBox input, chat contents, user-visible messages, and dynamic chat-node names.
- Credential-like values and sensitive field values. Unknown runtime prose/opaque strings can be omitted with a recorded reason. Config/Settings/Definition JSON is decoded and field-sanitized with explicit depth, node, and byte limits.
- All source comments and suspicious credential/context-sensitive/escaped source literals. Privacy edits are counted before any source is saved. Unfiltered source is never written.
- Authentication/session APIs, cookies, browser data, debug/getgc memory, arbitrary module returns, remote traffic, and server-only or unreplicated information.

Roblox does not expose a universal safe runtime property enumerator. V3.0 uses the broad explicit schema in `coverage.json`; classes without specialized coverage still get base metadata, attributes, tags, and children. Inaccessible properties are counted and recorded. Terrain voxels, mesh/audio binaries, function closures, localization text entries, and data outside this schema are not claimed as collected.

This is a **time-window client snapshot**, not an atomic data model or an original Studio project. Objects may stream, disappear, or change during traversal and source reconstruction. A snapshot cannot prove unavailable server logic. Relevant official documentation: [client/server runtime](https://create.roblox.com/docs/projects/client-server), [instance streaming](https://create.roblox.com/docs/workspace/streaming), and [task cancellation](https://create.roblox.com/docs/reference/engine/libraries/task).

## Reliability and limits

Sources are processed sequentially, with at most one worker. There is no 5,000-source export cap. Inventory success does not depend on any source succeeding. Instance references are visited once; output buffers are flushed to disk rather than retained as an entire in-memory report.

| Default limit | Value and outcome |
| --- | --- |
| Objects | 600,000; stops with a partial status and a recorded limit. |
| Discovered scripts | 150,000; stops with a partial status and a recorded limit. |
| Hierarchy depth | 512; records the unenumerated subtree boundary. |
| Source body | 8 MiB each; larger bodies are explicitly not exported, with observed size. No prefix is presented as a complete source. |
| Payload disk budget | 2 GiB; reserves room for known terminal source records, stops source work on budget pressure, and records gaps. A hard write/budget failure preserves the last valid checkpoint. |
| Pending encoded buffers | About 2 MiB plus the current record/source/native API allocations. This is a soft buffer budget, not a promise about total process memory. |
| Observed Lua memory growth | 256 MiB over launch where `gcinfo` is available; cooperatively stops and records the limit. Other game scripts can affect this measurement. |
| JSON configuration | 1 MiB per raw string; depth 32 and 100,000 decoded nodes. Exclusions carry explicit reasons. |
| Decompiler worker | 12-second cooperative timeout; three consecutive timeouts stop the remaining source pass. An uncancellable worker immediately aborts further source calls. |

Luau cannot forcibly preempt an executor API that blocks the engine in native code. A yielding call can be timed out/cancelled; a native stall can still freeze the UI until it returns. No executor-independent tool can guarantee otherwise. Checkpoints protect completed exports.

Pause/resume works within the current session. Stop produces a sealed partial export. Starting again creates a fresh unique folder; cross-session resume is not implemented. After a crash, the packer can package the latest intact checkpoint as an explicitly unfinished snapshot.

Working `writefile` and `makefolder` are required. `readfile` is used for immediate byte-for-byte read-back when available. Without it, the manifest marks files unverified and the Windows packer checks them later. Missing file APIs refuse collection instead of substituting an incomplete clipboard report. No collected data is uploaded automatically.

## Development and verification

`build-feral-v3.py` embeds the standalone `Pack-FERAL.ps1` into the Lua source. End users only run the one-line loader; the packer is generated into their export automatically.

```sh
python3 roblox-tools/build-feral-v3.py
python3 roblox-tools/tests/test-feral-v3.py
python3 roblox-tools/tests/test-packer-v3.py /path/to/pwsh
luau-compile --null roblox-tools/feral-complete-diagnostic-v3.0.lua
```

See [VALIDATION-v3.0.md](VALIDATION-v3.0.md) for exact checks and limits. The mocks do not constitute an in-game Velocity test.
