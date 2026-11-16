# FERAL Complete Diagnostic v3.0.2

**[V3.0.3](README-v3.0.3.md) optimises source collection while keeping the full game/platform scope.** It removes unnecessary waits and reuses exactly matching code. Switching versions starts a new run; Stop & Save the current export first.

The reported v3.0.1 run passed its small text-file check, then failed while writing `Pack-FERAL.ps1`, before inventory began. That is consistent with an executable-file restriction, although the native error did not identify the exact rule. Packaging helpers should not have been required to start a read-only inventory.

V3.0.2 exports **plain text data only**. It does not write, rename, encode for later execution, or run packaging programs. Windows creates the ZIP after collection.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-complete-diagnostic-v3.0.2.lua"))()
```

## Start and upload

1. Run the replacement loader while joined to FERAL. It replaces previous diagnostic panels without deleting their export files.
2. Confirm the title says **v3.0.2**, then click the green **START SCAN** button.
3. Wait for a finished status, or click **STOP & SAVE** and wait for it to finish saving.
4. Open the displayed **FERAL_v3_0_2_...** folder inside Velocity's workspace.
5. In Windows, right-click that **entire folder**, then choose **Show more options > Send to > Compressed (zipped) folder**. If your menu offers **Compress to > ZIP file**, that also works.
6. Upload the resulting ZIP to ChatGPT. The summary alone is insufficient.

If the whole ZIP is too large, open the export folder and compress **each `UPLOAD_PART_*` folder separately**. Upload **every resulting ZIP**, including **UPLOAD_PART_000_METADATA**. The collector groups payload files into data folders with a 24 MiB accounting target, including a per-file overhead charge. This is a soft target; metadata and a single oversized record can exceed it and are explicitly described.

If startup still fails, use **COPY STARTUP REPORT**. It contains controlled failure information and API capability flags, not arbitrary exception text or game source.

Microsoft's [ZIP instructions](https://support.microsoft.com/en-gb/windows/experience/storage-filemanagement/zip-and-unzip-files) describe the built-in Windows compression operation. No new compression software is required.

## Data layout

Every generated filename ends in `.txt`, including JSON and source data. Text source chunks are stored as `.source.txt`; they are never executed.

| Location | Contents |
| --- | --- |
| `READ_FIRST.txt` | Convenient ZIP/upload instructions. |
| `UPLOAD_PART_000_METADATA/manifest.json.txt` | Latest authoritative master manifest with schema `feral-diagnostic/3.0.2`. |
| `UPLOAD_PART_000_METADATA/checkpoints/manifest_*.json.txt` | Immutable prior manifests. |
| `UPLOAD_PART_000_METADATA/catalog/files_*.ndjson.txt` | Complete payload file catalogues with root-relative paths, byte lengths, Adler-32 checksums and executor read-back status. |
| `UPLOAD_PART_000_METADATA/coverage.json.txt` | Collection schema, limits, capabilities, deliberate exclusions and privacy policy. |
| `UPLOAD_PART_000_METADATA/checkpoints/SUMMARY_*.txt` | Immutable summaries referenced by their manifests. |
| `UPLOAD_PART_NNN_DATA/objects`, `scripts`, `source-results` | Full inventories and known script outcomes. |
| `UPLOAD_PART_NNN_DATA/sources` | All successful privacy-filtered source chunks, in the order listed in each source-result record. |
| Other data subfolders | Attributes, values/configurations, remotes, UI, assets/playing animations, focus references and structured errors. |
| Each `UPLOAD_PART_*/UPLOAD_PART.json.txt` | Session identity, part number, total parts and root-relative prefix for reconstructing separately uploaded folder ZIPs. |

Each payload occurs in exactly one data folder. The master catalogue preserves its complete root-relative path even when related records span folders. After extracting an individual folder ZIP, prepend the `root_relative_prefix` from its part marker to its internal filenames. All parts belong to the same session. Missing parts can be detected by comparing against `upload_parts` in the master.

Accepted file bytes are read back and compared when `readfile` works. Checksums and byte counts allow a complete post-upload check. Windows compression itself is separate from this verification; no claim is made that the executor creates a ZIP.

Part markers, the latest manifest, latest summary and root instructions are mutable/advisory index copies. Payload files, catalogues, authoritative control versions, and prior manifests are immutable. Prior manifests do not hash overwritten advisory markers. A crashed or stopped collection remains explicitly partial, and later uncheckpointed files are not claimed by an earlier manifest.

## Collection scope

The full game/platform inventories, source eligibility, privacy filtering, property coverage and resource caps from [v3.0](README-v3.0.md) remain in effect. Both game and Roblox platform content are kept. Source success does not gate inventory success. No gameplay values, attributes, remotes, modules or server security checks are modified or invoked. Other-player/profile data, UI/chat text, credentials, authentication APIs and debug/getgc memory remain excluded.

This is a time-window client snapshot. Server-only, unreplicated, streamed-out and inaccessible data are unavailable. Source reconstruction is optional and imperfect. Native executor calls that block the engine cannot be forcibly preempted.

## Verification

- The official Luau 0.747 compiler checks the standalone source.
- The integration suite reproduces the old `Pack-FERAL.ps1` failure under an executable-extension restriction, then verifies v3.0.2 succeeds with that restriction and with a strict text-only file writer.
- Thirty simulated cases cover the previous startup/export checks, the 37,991-script fixture, native upload folders and byte-for-byte reconstruction from both a whole export ZIP and separately compressed part folders.
- Every referenced catalogue, control and payload checksum/size is checked, source chunks reassembled, known script outcomes counted, and immutable prior manifests revalidated.
- The old PowerShell packer remains in the repository for legacy v3.0/v3.0.1 exports. Its regression test explicitly uses a legacy fixture; it is not generated or required by v3.0.2.

Actual execution of v3.0.2 inside Velocity and Windows 11 remains unverified. The supplied runtime report establishes the earlier failed operation; the extension restriction is a testable explanation, not a confirmed internal Velocity rule.
