# Booga Booga Reborn — continuation handoff

## Identifiers and project ownership
- Target game: https://www.roblox.com/games/11729688377/Booga-Booga
- PlaceId: `11729688377`
- Developer/publisher: Gang O' Fries Entertainment
- Separate from FERAL (PlaceId `108901361810209`)
- Repo: `GSVexed/vexed-schematics`
- Directory: `booga-reborn/`

## User request
The user explicitly wants the fullest possible accessible game code/data
collection **before** building another hub, and is dissatisfied when
collectors miss obvious categories. They strongly prefer a single
Velocity paste with a real hosted raw URL and simple controls. The
user previously believed a GitHub-hosted Lua script automatically
uploaded game reports; clarify that it does **NOT** do so.

## Published first step
Read-only Booga Complete Client Archive v1.0:
`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-complete-client-archive-v1.0.lua"))()`

Based on FERAL's tested 1705-line diagnostic architecture rather than
a thin new script; updated target, privacy, source-indexing rules and
export instructions. Captures broad currently accessible instance
tree, scripts/LocalScripts/ModuleScripts, optional permitted reconstruction,
remotes and bindables (names, not invocation), attributes, ValueBase,
CollectionService tags, allowlisted property/visual/physics/GUI metadata,
world resource and structure objects, game vs Roblox-platform classes,
asset references and animated tracks. Themes: crafting, inventory,
harvesting, combat, tribes, rebirth/Mojo, construction, survival, NPC,
world geography, economy, interface, networking.

Many optional APIs: `writefile`, `makefolder`, `readfile`,
`decompile`, `getloadedmodules`, `getscripts`, and
`getscriptbytecode` for exact bytecode identity reuse only; raw bytecode
not exported. Does NOT require arbitrary modules or call remotes, inspect
getgc, dump credentials, chat, or other private player data. Reconstructed
source may be inaccurate and intentionally redacted.

Progress UI: click START FULL SCAN, PAUSE/RESUME, STOP & SAVE, SAVE
CHECKPOINT, COPY SUMMARY, COPY STARTUP REPORT, COPY FOLDER NAME.
Exports into a uniquely named workspace folder:
`BOOGA_REBORN_FULL_CLIENT_v1_0_<session>`.
Produces up-to-24MiB `UPLOAD_PART_*_DATA` folders plus metadata,
chunked text and per-source checksums, manifest and coverage gaps. ZIP
folder manually in Windows and upload to ChatGPT. Split parts supported.
No automatic Github upload or screenshot/personal data collection.
No scanning without working output file APIs.

Supporting tools:
- `verify-booga-client-export.py` validates archive integrity
- `compare-booga-snapshots.py` compares two or more full-session ZIPs
  and reports newly discovered script/remote/path categories.
- `.github/workflows/booga-reborn-collector-validate.yml` performs
  official Luau compilation, safety scope assertions, Python syntax
  and synthetic two-snapshot diff test. **All passed** as of
  17 November 2026. No live Velocity test has been performed.

## Completeness boundaries
- Only what is replicated to the player and visible/accessible in
  the current session; no private server scripts or authoritative grants
- Streaming means a second run in a different cave/island or with
  a special UI open can reveal additional data, but it's not a
  requirement for a first report.
- Source status per known script, error counts, caps and reasons recorded
- Never promise 100% source or no missed server data
- Do not claim code dump automatically syncs to GitHub
- No need to request long pasted diagnostics: ask for the ZIP export,
  or split UPLOAD_PART zip files with metadata part

## Next response workflow
Once the user supplies a ZIP, read it fully (files.read/pages for
semantic, container for archive/manifest and programmatic inspection)
and first verify completeness/integrity with verifier. Then catalog
game vs platform sources, modules, remotes, Booga domains, and identify
strongest working client-controlled features for eventual hub.
Preserve an architecture summary in this directory.
