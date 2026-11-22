# ARENA NOVA v1.2 — heavyweight, faster and failure-aware diagnostic

Target: **[NEW MAPS!] Arena of Survival**, Roblox universe ID `7209131331`.

## Run v1.2 instead of v1.1

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/arena-nova-client-diagnostic-v1.2.0-heavyweight-recovery.lua"))()
```

If **v1.1 is already scanning**, use **STOP & SAVE** first and preserve its completed output folder, including any `UPLOAD_PART_*` folders. Close the old diagnostic after its status has stopped and the files have checkpointed; then run the v1.2 loader. Running two heavyweight scans simultaneously is not recommended.

Choose **MODE: LOBBY** for the initial menu/pre-match session; choose **MODE: MATCH** in a real round. Both use the full heavyweight client inventory and source scan, but the first bounded scene snapshot is checkpointed before full decompilation starts.

## Source pipeline

1. **Early scene**: capture currently replicated game state and commit checkpoints.
2. **Complete client inventory**: write object paths, classes, explicit property coverage, attributes, remotes, values, scripts and assets, with failure logs and a manifest.
3. **Direct Source sweep**: iterate all eligible game + accessible platform scripts and export directly readable Source before slow decompilation begins.
4. **Native reconstruction**: attempt `decompile(scriptInstance)` in up to two bounded workers. Failed/blank/comment-only outputs and common failure placeholder strings do not count as successful source.
5. **Bytecode recovery**: for eligible native failures, attempt `getscriptbytecode(scriptInstance)` in memory and `decompile(bytecodeString)`. Both APIs are optional and executor-dependent. Up to two recovery workers can run concurrently.
6. **Deduplication**: where bytecode is rapidly available, verify exact byte equality before reusing a previously saved reconstructed source. Disable fast fingerprinting if the getter adds excessive latency.
7. **Diagnostics**: keep source attempt logs under `source-attempts/`, and terminal outcomes under `source-results/`. The summary separately reports native successes/failures, fallback recoveries, failure categories and unrelated property-read warnings.

Efficiency improvements relative to v1.1:
- Source bodies are not repeatedly requested through the native decompiler once the direct Source phase succeeds.
- Native and bytecode fallback workers have cooperative time limits; the fallback is not a one-at-a-time queue.
- Heavyweight manifest checkpoints are not rewritten while no meaningful state has changed; routine interval increased from 5 to 10 seconds, with explicit checkpoints still present.
- Slow native decompiler failures can trigger automatic downgrade to one worker for stability, rather than allowing repeated parallel contention.
- If identical bytecode matches a saved result exactly, redundant decompiler invocations can be avoided. This optimization disables itself if bytecode lookup is slow.

This does **not** promise a particular completion time or percentage of successful reconstructions. Some executor decompiler calls may block native threads, may be slow for lengthy scripts, or may not support the current Luau bytecode version. A script that fails a native attempt may also fail bytecode fallback; failure is recorded rather than counted as source.

## Export and reporting

Output folders:
- `ARENA_NOVA_LOBBY_v1_2_0_<timestamp>_<unique>`
- `ARENA_NOVA_MATCH_v1_2_0_<timestamp>_<unique>`

Local files are not uploaded automatically. ZIP the **whole output folder** from the Potassium workspace. If too large, ZIP the separate `UPLOAD_PART_*` folders, keeping metadata part 000 and every data part. Send the ZIP(s) in chat.

If the tool shows many failures, click **COPY SUMMARY** and share the report; if startup/export fails, use **COPY STARTUP REPORT**. Failure counts in the object/property inventory are not necessarily decompilation failures: they are tracked separately from `source-results/`.

Source reconstructions are privacy-filtered (comments and suspicious literals removed), may be inaccurate, and do not expose server-only source. No raw compiled bytecode is exported. The diagnostic does not invoke gameplay remotes or require game modules, send HTTP requests, or manipulate live gameplay objects (apart from its own diagnostic UI). It only writes local text files.

Validation: [v1.2 Luau compile and source safety workflow](https://github.com/GSVexed/vexed-schematics/actions/workflows/arena-nova-v120-heavyweight-recovery-validate.yml).

## After the lobby scan

Once we inspect the archive, compare source-results and failure classes, and map game-specific modules, we can design a narrower **match delta** diagnostic that preserves all unique client data while avoiding repeats from the lobby. That feature is not yet implemented in v1.2; do not assume automatic cross-session source reuse.
