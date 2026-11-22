# ARENA NOVA Smart Heavy Collector v2.0

**Target:** Roblox Arena of Survival, universe `7209131331`, root place ID `72238253016204`.

## Run in Potassium

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/arena-nova-smart-collector-v2.0.lua"))()
```

In the UI, leave **MODE: LOBBY** selected and click **START SMART SCAN**. The same loader also supports **MODE: MATCH** after you join a live round. Mode is selectable before starting the scan.

**Stop the v1.1/v1.2 diagnostic first.** Use its **STOP & SAVE** button if responsive; allow it to finish writing, preserve its existing output folder, and close it. Do not run two collectors simultaneously.

## What this redesign changes

The FERAL-derived v1.2 diagnostic attempted a very large amount of repeated object/property work and slow decompilation without cross-session reuse. v2 is a new, smaller, Arena-specific implementation, not a simple copy of the v1.2 script. It gives the complete *accessible hierarchy* priority, then reconstructs game-relevant client code within a cooperative time budget.

1. **Early scene snapshot.** Samples up to 1,200 observed objects per initial area (Workspace, ReplicatedStorage, Backpack, PlayerGui), then checkpoints files before the full scan. It is a bounded early sample and does not claim to be a full scene census.
2. **Accessible full hierarchy inventory.** Traverses up to 200,000 client-visible instances, recording path, parent, class and category, plus separate script and remote indexes. Relevant gameplay elements have selected properties and attributes recorded; value nodes are recorded. **It is not a dump of every possible property of every Roblox object.** An object/time safety cap may yield a partial inventory, explicitly flagged in the manifest. Other players' private subtrees and private profile/auth branches are excluded.
3. **Priority-ordered client scripts.** Arena-relevant module and client scripts go first, other game scripts next, Roblox platform scripts later. All accessible eligible scripts are indexed, even if they are not reached by the decompiler budget. Server-only scripts are not accessible.
4. **Direct source, then bounded decompile.** Every queued eligible script is first checked for readable `Source`; otherwise one executor `decompile(instance)` attempt is allowed a cooperative ~4-second limit, with a bounded optional `getscriptbytecode` / `decompile(bytecodeString)` recovery attempt for failing *game* scripts. Native executor calls may ignore cooperative scheduling and block; precise timing cannot be guaranteed by script code.
5. **Persistent cache and session-independent captures.** Successfully saved source is stored in a local cache indexed by path and `game.PlaceVersion`. On subsequent captures of the same place version, sources can be reused without another native decompile call. Cache reuse is labelled **unverified same-place-version/path** unless independently matched by bytecode; it is not proof of exact bytecode identity. The exported capture ZIP includes its own copy of the referenced source, so it is self-contained.
6. **Failure backoff and circuit breaker.** Failed sources are not retried for 15 minutes in subsequent runs of the same place version, but can be retried later; they are never silently counted as successes. Three native timeouts with no successful reconstruction, or ten consecutive initial unsuccessful attempts with no usable source, stop the expensive source stage and save evidence. Failure categories are recorded.
7. **Checkpoints and completion flags.** Streams are chunked to NDJSON text files, sources to separate text files, and `manifest.json.txt` describes the exported files, byte lengths, checksums and completeness. The collector never labels a time-budgeted or stopped scan as a complete source archive.

## Time budgets

- **Lobby:** 110 seconds of *cooperative* collection time.
- **Match:** 38 seconds of *cooperative* collection time.
- These budgets include the early scene and inventory stages. A large scene could consume most of the budget and leave fewer scripts decompiled. The exact timing is not guaranteed: a non-yielding native executor call can delay Lua.
- Source caching is the way to accumulate deeper coverage across repeated sessions; it does **not** automatically reuse v1.1/v1.2 data because those archives have a different format.

If the source phase finishes before the time budget, the scan ends early. To continue incomplete coverage in a later session, run the same loader again and allow it to use the local cache. The **COPY SUMMARY** button provides the counts, failure categories and capture directory.

## Local files and upload

The collector writes under the executor's workspace:

```text
ARENA_NOVA_SMART_V2/
  cache_index.json.txt
  sources/
    S000001.source.txt
    ...
  captures/
    LOBBY_20261122_.../
      README.txt
      manifest.json.txt
      rapid_0001.ndjson.txt
      objects_0001.ndjson.txt
      scripts_0001.ndjson.txt
      remotes_0001.ndjson.txt
      details_0001.ndjson.txt
      values_0001.ndjson.txt
      source_results_0001.ndjson.txt
      sources/
        S00001.source.txt
        ...
```

**ZIP the entire timestamped capture folder** (the one displayed in the panel/footer), not necessarily the whole cache root, and upload that ZIP here. Each capture includes copies of cached source used for that scan.

The tool does **not** automatically send files to ChatGPT or GitHub, access server-only code, invoke gameplay remotes, require game modules, hook remotes, modify gameplay attributes, collect chat messages, or write raw bytecode. Source filtering excludes comments and attempts to redact credential-like literals, but filtering is heuristic, so inspect files before sharing if privacy matters.

## QA

[Luau compilation and static safety workflow](https://github.com/GSVexed/vexed-schematics/actions/workflows/arena-nova-smart-v2-validate.yml). Passing compilation checks Luau syntax, **not** whether Potassium implements every API, how quickly a decompiler operates in-game, or whether reconstructed sources are accurate.

**Next milestone:** Upload the first v2 lobby archive, inspect source errors and game modules, and use those results to decide whether to improve the source backend or build a targeted match-delta collector.
