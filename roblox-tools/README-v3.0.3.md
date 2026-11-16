# FERAL Complete Diagnostic v3.0.3 — full collection with less repeated work

**All eligible game and Roblox platform sources remain in scope.** No category, inventory entry, remote, configuration or source queue is removed to improve speed. The source reconstruction still covers systems beyond health/stamina.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-complete-diagnostic-v3.0.3.lua"))()
```

## Switching from a running version

**This starts a fresh scan; it does not resume v3.0.2.** Click **STOP & SAVE** on the old run and wait for it to finish saving before loading this version. Existing export folders are retained. If the old run is nearly finished, letting it finish avoids repeating that work. A published script update cannot change the local functions already running in the old version.

Run the new loader, confirm **v3.0.3**, and click **START SCAN**. As before, ZIP the entire displayed export folder in Windows and upload it. Smaller native upload folders, text-only output, checksums and privacy rules from [v3.0.2](README-v3.0.2.md) remain in place. The new root name starts `FERAL_v3_0_3_`.

## Performance changes

- V3.0.2 forced a scheduler wait before each source and after each source chunk, plus a deferred worker for reconstruction. V3.0.3 yields according to the existing time budget and starts workers immediately where `task.spawn` works. Yielding calls remain timed/cancellable; an unavailable or failing immediate dispatcher falls back to `task.defer`.
- There remains **one active reconstruction call at a time**. The tool does not assume Velocity supports parallel decompiler requests.
- Exported privacy-filtered text is stored once when it exactly matches an earlier source in the same category. Adler-32 and length are only lookup hints; a byte-for-byte file comparison is mandatory before sharing text.
- Optional `getscriptbytecode` can avoid repeated reconstruction of identical compiled modules. It is used only on already-eligible client containers. Supported raw Luau headers are sanity-checked; bytecode must match an earlier candidate **byte for byte** and the canonical source files must pass read-back size/checksum verification. Missing, invalid or failing getters disable this optional cache and retain ordinary reconstruction. Unknown/compressed formats fall back as well.
- Raw bytecode is never exported. This in-memory cache is capped at **16 MiB**, with a **128 KiB** maximum individual entry. The exported-text reference cache is capped at **20,000 entries**, each at most **128 KiB**. Filling either cache affects reuse, not collection scope.
- Adler-32 processing handles eight bytes per inner iteration, and the single-chunk source hash is reused instead of recomputed for the same bytes.
- The summary shows source-phase duration, average processing rate, approximate time remaining, exact-text reuse and bytecode reconstruction reuse. Estimated time depends on the observed average and can change with script complexity.
- The summary is in a clipped scrolling area, so long reports stay inside the panel.

## What a shared reconstruction means

Every discovered script still has its own inventory and terminal outcome. Its hierarchy, path, category, metadata and eligibility remain independent. Different scripts can point to the same exported text file. Concatenate each record's `files` in the stated order to recover its complete exported source.

`source_storage: shared_exact_text` means both reconstructions produced exactly the same privacy-filtered bytes. `source_storage: shared_identical_bytecode_reconstruction` means the observed compiled bytes were exactly identical, and that record points to an earlier canonical reconstruction of those bytes. The latter is labelled `canonical_reconstruction` and `identical_bytecode_verified`, with `reused_from_id`. It does not pretend that the decompiler ran independently for every duplicate, or that original Studio source was retrieved. Per-script reconstruction-specific byte counts are omitted when they were not independently observed.

Code sharing does not imply identical runtime state or authorship. Inaccessible or server-only data remains unavailable. Source failures, limits, privacy exclusions and stopped work remain explicit.

## Verification and limits of the results

- Official **Luau 0.747** compilation passes.
- **38 simulated cases** check inventories, source outcomes, privacy, read-only behavior, file integrity, ZIP reconstruction, fallback scheduling, timeouts, source/code sharing, cache limits, unsupported bytecode APIs and intentional Adler-32 collisions.
- The **37,991-script** scale fixture preserves the eligible/exported script counts. No source-count cutoff or category omission is introduced.
- A scheduler model with 500 additional short unique scripts reports **24.52 simulated seconds for v3.0.2 versus 0.88 for v3.0.3**, with identical source outcomes and one reconstruction at a time. **This measures the model's scheduling overhead, not live Velocity throughput.**
- Twelve identical-module fixtures reduce actual mocked decompiler calls from twelve to one for that group while retaining all twelve source records. Unsupported getter/format fixtures retain ordinary reconstruction and the same successful sources.
- The binary sanity range is based on [Luau 0.747's Bytecode.h](https://github.com/luau-lang/luau/blob/0.747/Common/include/Luau/Bytecode.h). Sanity checks are not a standalone bytecode parser or a claim that Velocity exposes that API.

Actual speed inside Velocity has not been measured. Native decompilation time may dominate, and a native call that blocks the engine still cannot be forcibly interrupted. The existing object/source/disk/memory limits remain documented and reported. Access to the user's PC is not required to publish or run this code optimization.
