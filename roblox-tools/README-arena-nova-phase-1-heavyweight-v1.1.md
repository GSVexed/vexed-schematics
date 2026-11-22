# ARENA NOVA v1.1 — Heavyweight full client archive, faster pipeline

**Target:** Roblox **[NEW MAPS!] Arena of Survival** (universe `7209131331`, root place `72238253016204`).

## Run this version instead of v1.0.0

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/arena-nova-client-diagnostic-v1.1.0-heavyweight.lua"))()
```

Wait for the diagnostic UI, ensure **MODE: LOBBY**, and click **SCAN LOBBY**. To record active gameplay, join a match, start a fresh instance of the same launcher, select **MODE: MATCH**, then click **SCAN MATCH**.

### Why the previous version felt slow

v1.0.0 calls the executor's optional `decompile(instance)` one script at a time, with a 12-second cooperative timeout per call. One difficult script therefore blocks useful source collection from later scripts. It also recalculates outstanding hierarchy items by walking the traversal stack repeatedly.

v1.1 keeps deep collection, but changes the pipeline:

1. **Immediate scene record**: up to 6,500 lobby/match object observations are captured first across Workspace, ReplicatedStorage, the user's backpack, PlayerGui, StarterPack and Lighting, with independent checkpoints after each section. This first pass is bounded and *does not claim a full scene census*. It does not read player chat content or other users' private objects.
2. **Full heavyweight client inventory**: follows the existing hierarchy and records objects, attributes, tags, explicit properties, values, remote names, scripts, assets, UI structure and failures. Outstanding-item tracking now increments/decrements in O(1), rather than resumming the stack for every object.
3. **Readable-source sweep**: for every eligible LocalScript/ModuleScript/Client Script in game AND accessible Roblox platform containers, attempt direct Source property capture first. Those successful source files and a complete queue inventory are checkpointed *before* invoking the slow decompiler.
4. **Bounded two-worker decompilation queue**: all remaining eligible sources are attempted through the executor's decompiler using two cooperative Luau workers, up to 9 seconds per worker. Earlier priority buckets preserve Arena-relevant game code first, then other game code, then platform. No source is skipped merely for low priority. Failed/empty/timed-out modules keep explicit records.
5. **Checkpoints and upload parts**: file read-back verification, manifests, per-file counts and checksums, source result status, and `UPLOAD_PART_*` ZIP-friendly directories remain in place. The old v1.0.0 archive is not overwritten.

The two-worker queue is a best-effort performance improvement. Actual speed depends on the executor's decompiler and scheduler; **some native blocking calls may not be interruptible**, and parallel decompilation can be less stable on some executors. If it freezes or fails, use **STOP & SAVE** if the interface responds, and send the **COPY STARTUP REPORT** output. If it crashes, existing checkpointed files may remain.

### Lobby versus match

**Lobby:** choose LOBBY while still at the initial menu/pre-match zone. This is the heavyweight code archive. Allow the source pipeline to run if the game remains responsive.

**Match:** choose MATCH after entering a live round. The tool prioritises an immediate saved gameplay snapshot before the full deep pass; the early section can survive if you die, provided the executor workspace is not cleared. If a teleport switches Roblox servers or place, the diagnostic may stop—this cannot be prevented by a client script.

The two scans write to separate time-stamped directories:

- `ARENA_NOVA_LOBBY_v1_1_0_<timestamp>_<guid>`
- `ARENA_NOVA_MATCH_v1_1_0_<timestamp>_<guid>`

To share an archive, **ZIP the whole output folder** from your executor's `workspace` or local files directory. If it is too big, ZIP each `UPLOAD_PART_*` folder separately and include every part, including metadata part 000. Upload those files to this conversation. The scripts save **locally**; they do **not** automatically transfer files to ChatGPT or GitHub.

### Coverage and limitations

- Data-only, read-only collection: no gameplay remote calls, `require()` execution of arbitrary game modules, UI-text/chat collection, hidden-identity changes, raw bytecode export or in-game attribute modification.
- The decompiler may produce a reconstructed rather than exact original source and can be unavailable. Restricted or server-only scripts are not accessible just because an executor is present.
- Other-player private subtrees are omitted; suspicious source literals and comments are redacted. Capped scene pass is explicitly separate from complete inventory. Source failures remain visible.
- If you stop the scan, `finished_with_gaps`, `stopped_partial` or `failed_partial` are meaningful outcomes, not complete extractions.
- **No cross-session resume yet**: restarting the Roblox client starts a new export, though earlier checkpoint files remain on disk if the executor persists them.

### Validation

[ARENA NOVA v1.1 heavyweight Luau compiler and source-safety workflow](https://github.com/GSVexed/vexed-schematics/actions/runs/45061779152) — passed.

Source: [arena-nova-client-diagnostic-v1.1.0-heavyweight.lua](./arena-nova-client-diagnostic-v1.1.0-heavyweight.lua).

Next task after receiving the lobby export: verify manifests and byte counts, read all available source results, build an Arena module dependency map, and identify game-specific missing modules before match investigation.
