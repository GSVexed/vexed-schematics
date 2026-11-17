# Booga Booga Reborn — Complete Client Archive v1.0

**Target:** [Booga Booga](https://www.roblox.com/games/11729688377/Booga-Booga)
by Gang O' Fries Entertainment, PlaceId `11729688377`.
This project is independent of all FERAL Aurora scripts.

The aim is to **capture as much accessible client-side game structure and
code as possible, before building a new hub**. The primary collector is a
Booga-specific adaptation of the previously developed FERAL Complete
Diagnostic v3.0.3, retaining its advanced error-handling, checksums,
chunked source/text exports, checkpoints, source-result records and
privacy controls. The Booga version compiles successfully in CI.

## Paste this in Velocity

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-complete-client-archive-v1.0.lua"))()
```

Run it **inside Booga Booga**. Its dark `BOOGA / COMPLETE CLIENT ARCHIVE`
panel opens without starting an expensive scan. Click **START FULL SCAN**.
The tool checks working local `writefile`/`makefolder` capabilities before
collecting. It shows the current phase, objects discovered, scripts and
remotes, source attempts, failures and the output folder.

The interactive controls are:

- **START FULL SCAN** — inventory all currently visible client instances,
  then attempt accessible client-script/source reconstruction
- **PAUSE / RESUME** — cooperative interruption during the scan
- **STOP & SAVE** — seal a partial export with explicit partial coverage
- **SAVE CHECKPOINT** — request an additional current-file checkpoint
- **COPY SUMMARY** — compact summary of the scan and its limitations
- **COPY STARTUP REPORT** — errors/capabilities if file output or UI fails
- **COPY FOLDER NAME** — get the exact unique local export folder
- **_ / X** — minimise or stop-and-cleanly-close the collector

No routine source extraction starts before file output is checked.
If `writefile` or `makefolder` is unavailable, the collector refuses to
pretend that clipboard text is a complete export. It generates a unique
folder per run, for example
`BOOGA_REBORN_FULL_CLIENT_v1_0_20261117_173000_<session>`.

## What it captures

| Category | Coverage |
|---|---|
| **Instance hierarchy** | IDs, parent references, paths, classes and tree structure across game-visible services, including replicated storage, first-load content, starting GUIs/players, lighting, sound and currently loaded world |
| **Client code** | Every eligible visible LocalScript/ModuleScript and client-context Script recorded with a separate outcome; attempts `.Source` or optional executor `decompile`, with source bytes split into manageable files |
| **Network interfaces** | RemoteEvent, RemoteFunction, UnreliableRemoteEvent, BindableEvent/Function names and locations — **without invoking them or intercepting traffic** |
| **Data, config and attributes** | Attributes, CollectionService tags, ValueBase data, allowlisted properties and any readable JSON configuration fields with privacy filtering |
| **Visual/interface assets** | Mesh, texture, animation, image, sound and lighting references; GUI layouts/properties, but not chat or user-input text |
| **Movement and combat** | Humanoid properties, constraints, physics components and related client scripts |
| **World/resources** | Visible islands, caves, ore, items, structures, prompts, tools, NPC objects, effects and other current replicated content |
| **Additional source discovery** | Optionally supported `getscripts`, `getloadedmodules`, and bytecode-identity reuse when available. These do not grant access to server-only code |
| **Booga theme index** | 13 named/path keyword families: crafting, inventory, harvesting, combat, tribes, progression (rebirth/Mojo), construction, survival, creatures, geography, economy, interface and network |

The thematic index is **additional**. It never filters the general object
inventory to "relevant" paths. Odd/undocumented names and disabled client
branches still remain in the main recorded dataset if accessible.

## Completeness, in a meaningful sense

The scanner tracks:

- Objects visited vs limits and traversal completion
- Every recorded script's source status, including failed/missing/oversized
  reconstruction and skipped server/unknown-context scripts
- Which optional executor APIs were available
- Property, attribute, traversal and output write errors
- Source counts, deduplication statistics and number of files
- Checksums for saved payloads and read-back results, when `readfile` exists
- Source collection abort/timeout reasons
- Explicit inventory holes and all size/memory limits reached

The configured upper bounds are **600,000 objects**, **150,000 scripts**,
**2 GiB of export** and **8 MiB per reconstructed source**, alongside
bounded buffering and cooperative yields. These are safety ceilings, not
promises that the game contains that many objects. The tool outputs
a coverage manifest rather than falsely claiming 100% complete code.

**Things this cannot obtain:**

- Roblox's private server-only scripts and authoritative economy/combat
  handlers
- Objects that were not replicated/streamed to the client at that time
- Reliable original source from an imperfect decompiler
- Runtime closure/upvalue contents or full module return tables
- Proprietary backend databases, anti-cheat internals or secrets
- Raw chat, other players' private data, credentials or authentication tokens

No remote or arbitrary ModuleScript is invoked; no game mechanics or
remote requests are changed. Source code is reconstructed when permitted,
then filtered to suppress credentials and personal-data patterns. That
may deliberately omit some source text, which is recorded.

## Getting the export back to ChatGPT

When finished, **copy the folder name** shown in the panel. Find that
folder inside Velocity's local workspace on Windows.

1. Right-click the *entire export folder* and select **Compress to ZIP**
   (or **Send to → Compressed (zipped) folder**).
2. Upload that ZIP to this ChatGPT conversation. You do **not** need to
   paste thousands of lines or copy the status individually.
3. If the ZIP is too large, compress **each `UPLOAD_PART_*` folder** inside
   the export separately and upload **every part**, including
   `UPLOAD_PART_000_METADATA`. Keep folder names unchanged.

The metadata manifest describes all required parts. Each source is
split into `sources/game/S<id>_part...source.txt` files; the source
result stream explains their order and checksums. Plain text data
does not execute code when opened.

**Uploading is not automatic.** Hosting the collector on GitHub and
having a Windows GitHub Actions runner do not automatically upload
Velocity's local reports to the repository. The collector never
sends gameplay data to a remote endpoint or asks for a GitHub token.

## How to minimise missed content

One collection should be run while the client is fully loaded.
Because this is a streaming open-world game, **no single static snapshot
can contain unreplicated areas or future states**. If we want
broader coverage, keep each uniquely named export and collect additional
sessions in meaningfully different contexts:

- Spawned with the main game HUD and current inventory/crafting panels
- Different island/cave/underwater areas that stream different resources
- Building and tribe UI open, if relevant
- Rebirth/Mojo and other special progression interfaces visible, where
  you naturally have access

The collector does not require you to perform dangerous combat or
manipulate currency to scan. Each pass is an independent, labelled
snapshot, which we can compare and combine. There is no requirement
to send all passes at once; the first complete export gives us a strong
basis to decide what genuinely remains unknown.

## Integrity verifier (optional on Windows)

The repository includes a standard-library Python verifier:

```bash
python verify-booga-client-export.py "BoogaClientCapture.zip"
```

It verifies that the manifest, payload catalogs, source chunks, sizes and
checksums are internally consistent without executing any collected code.
For split exports provide all part ZIP files as arguments.

When you have two or more **whole-session ZIPs** taken from different
parts of the map, the optional comparator highlights previously unseen
client scripts and remote interfaces:

```bash
python compare-booga-snapshots.py first.zip second.zip
```

The comparison does not establish that a mechanic is live or that server
source was available. It helps ensure distinct streamed-in client systems
aren't overlooked in subsequent captures.

The source and verifier are both in this directory:

- [Complete client archive source](booga-complete-client-archive-v1.0.lua)
- [ZIP verifier](verify-booga-client-export.py)
- [Cross-session comparison](compare-booga-snapshots.py)
- [Validation workflow](../.github/workflows/booga-reborn-collector-validate.yml)

## Next phase

Once we have the Booga-specific export, we'll build a **grounded game
architecture inventory**: full modules, remote names/relationships,
inventory and crafting paths, movement/combat code, status systems,
server-controlled boundaries and potential hidden client features.
From that, we can build a genuinely useful hub instead of inventing
buttons before we know the game.
