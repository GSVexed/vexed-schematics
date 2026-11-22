# ARENA NOVA — Phase 1 client snapshot diagnostic v1.0.0

**Game:** [NEW MAPS!] Arena of Survival  
**Universe ID:** `7209131331` · **Root place ID:** `72238253016204`  
**Published script:** [arena-nova-client-diagnostic-v1.0.0.lua](./arena-nova-client-diagnostic-v1.0.0.lua)

## Start in the game's lobby

Use Potassium, or a compatible Roblox Luau executor, with this one-line launcher:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/arena-nova-client-diagnostic-v1.0.0.lua"))()
```

1. Join Arena of Survival, remaining in the pre-match lobby.
2. Run the loader once. The **ARENA NOVA / CLIENT ARCHIVE** window opens.
3. Leave **MODE: LOBBY** selected and press **SCAN LOBBY**.
4. Let the inventory and decompiler finish. If a source API hangs or fails, **STOP & SAVE** safely finalizes whatever was captured; it does not claim full success.
5. Find the displayed `ARENA_NOVA_LOBBY_v1_0_0_<timestamp>_<unique>` folder in the executor workspace, compress **the entire folder** to ZIP and upload the ZIP to ChatGPT. Preserve all nested `UPLOAD_PART_*` directories.
6. For excessively large output, ZIP each `UPLOAD_PART_*` folder separately and upload all parts, including metadata part 000; send the root `READ_FIRST.txt` and all part archives as needed.

This archive is *not automatically available to ChatGPT* until uploaded or otherwise shared. The connected GitHub runner has no automatic access to executor workspace files.

## Take the match snapshot later

After completing the lobby export, **enter an active match**. Run the same loader again; click **MODE: LOBBY** once to switch it to **MODE: MATCH**, then **SCAN MATCH**. This creates a separate `ARENA_NOVA_MATCH_v1_0_0_...` folder, leaving the lobby archive intact.

**IMPORTANT:** The inventory is a time-window snapshot, not atomic. Running in the lobby does not load every map, weapon or effect. Match-specific items may only replicate while nearby or while the active map is streamed. A later third scan may be useful for unusual rounds or disasters.

## Data coverage

- Enumerates accessible game hierarchy and identifiable platform script roots.
- Records object classes, paths, parent IDs, tags, readable attributes, values and supported property sets.
- Lists remote events, remote functions and bindables by discovered path. **No remote is called or intercepted**.
- Captures asset references, UI structure **without UI text or chat contents**, and animations where observable.
- Collects eligible `LocalScript`, `ModuleScript` and client-context `Script` sources through readable `Source` or an optional executor decompiler.
- Attempts accessible `getscripts()` / `getloadedmodules()` inventory when APIs exist, without executing or requiring those modules.
- Decompilation is bounded; successful sources are chunked, labelled as reconstructed, and privacy-filtered.
- Writes numbered data-only part folders, manifests, checksums, file lists, failure logs, periodic checkpoints and export summaries.
- Distinguishes original content availability from reconstructed results, errors, incomplete coverage or truncated scans.
- The game-specific focus priority list includes loot, inventory, combat, blocking, weapons, maps, barrier, disasters, perks and survival mechanics; **non-focus scripts and objects are still inventoried**.

The export **does not** contain unreplicated server scripts, server-only inventories, arbitrary runtime memory, credentials, raw bytecode, chats, other players' private profiles or hidden identity data. It does not call `require()` on game modules or change gameplay data.

## How to interpret status

| Status / case | Meaning |
|---|---|
| **READY — LOBBY SNAPSHOT** | UI loaded; collection not started |
| **inventory** | Reading known accessible hierarchy and descriptions |
| **sources** | Attempting source capture for eligible client scripts |
| **finished** | Inventory and source pass ended without recorded gaps |
| **finished_with_gaps** | Export produced but some reads or sources failed; consult manifests |
| **stopped_partial / failed_partial** | Early stop or error; previous checkpoint files may still be usable |
| **COPY SUMMARY** | Basic counts and current output directory |
| **COPY STARTUP REPORT** | Use if UI or local file preflight fails |

A decompiler result is not a guarantee of exact original developer source. Even a complete client archive does not prove a server will accept a requested gameplay effect.

## Implementation / validation

This collector is an Arena-specific adaptation of the previously used, bounded FERAL Complete Diagnostic v3.0.3. It is not a gameplay hub. All scan activities are initiated by the user; output goes to the local executor filesystem only. Keep privacy filtering in place when preparing data for sharing.

- [Official Luau compile + read-only safety check](https://github.com/GSVexed/vexed-schematics/actions/runs/45060983005) — passed.
- Next stage after uploading lobby ZIP: completeness audit, subsystem index, then match snapshot and differential analysis.
