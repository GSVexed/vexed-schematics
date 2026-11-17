# Booga Booga Reborn — research & hub project

**Game:** [Booga Booga](https://www.roblox.com/games/11729688377/Booga-Booga),
PlaceId `11729688377`, by Gang O' Fries Entertainment.

This is a **new standalone project**. FERAL Aurora work is preserved under
`roblox-tools/`, and none of its client-controller assumptions should be
carried into Booga without evidence.

## First full archive received — integrity verified

The first uploaded ZIP turned out to contain **all 11 parts**. The
collector logged **97,686 objects**, **451 game-classified scripts**
(**438 reconstructed**), **203 remotes/bindables**, and **230 named
typed packet definitions** in the client network schema. All **23,296
saved payloads** and **38,111 reconstructed source references** passed
file-length and checksum verification.

**[Read the full code-backed first-export findings](BOOGA-FIRST-ARCHIVE-FINDINGS.md)**

The archive is saved in the ChatGPT conversation, **not** uploaded raw to
GitHub. The project findings are saved here for continuity. No additional
full diagnostic is necessary to begin technical analysis.

---

## Phase 1 — Complete visible-client collection

**[Start here: v1.0 collector instructions](README-booga-reborn-collector-v1.0.md)**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-complete-client-archive-v1.0.lua"))()
```

The collector inventories **all currently accessible game/client objects**
and reconstructs eligible client scripts where the executor permits it,
without modifying gameplay or calling game remotes. Output is a unique local
folder with completeness/gap manifests and upload-sized parts.

### Files

- [One-paste full client collector](booga-complete-client-archive-v1.0.lua)
- [Collector instructions / archive format](README-booga-reborn-collector-v1.0.md)
- [ZIP integrity verifier](verify-booga-client-export.py)
- [Two-or-more-capture comparison](compare-booga-snapshots.py)
- [Booga project handoff](BOOGA-HANDOFF.md)
- [CI validation](../.github/workflows/booga-reborn-collector-validate.yml)

The offline comparator identifies newly visible game scripts, remote
interfaces, named system categories and other paths when players scan
different areas/states of the map. It does not assert missing server content.

## Phases after first export

1. Analyze accessible source bodies and establish how Booga's client
   is arranged: inventory, crafting, combat, resource collection, equipment,
   movement, survivability, tribes, buildings, rebirth and Mojo.
2. Separate local/client effects from server-validated mechanics.
3. Prioritize worthwhile gameplay functions based on real code, not
   invented settings.
4. Build the polished Booga-only hub with reversible controls and proven
   feature explanations.

**No silent GitHub upload:** exports remain in the Velocity workspace
until explicitly shared. GitHub merely hosts the code and documentation.
