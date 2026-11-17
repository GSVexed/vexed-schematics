# FERAL AURORA v2.1 — Survival & Effects Overhaul

Aurora v2.1 upgrades the v2.0 command center rather than making users run
another diagnostic. The major changes respond to the first real user report:

- The report was copied **while in the animal-selection menu**. v2.0 printed
  `--` for own character data and gave zero ESP results. Those values were
  normal for the menu, not necessarily failed features.
- The user wanted **food/thirst**, **effects controls**, a more useful Player
  Finder, and automatic status history without pasting full diagnostics.
- The GitHub-hosted **script code was synced**, but neither v2.0 nor the
  Windows self-hosted runner had any automatic status-upload pipeline.
  v2.1 does **not** pretend that local autosave is GitHub sync.

## One-line launcher for Velocity

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-aurora-hub-v2.1.lua"))()
```

Run in FERAL Animal Survival (PlaceId `108901361810209`).
This script closes previous Aurora v2.0/v2.1 screens and known FERAL hub
panels using their shutdown hooks. The v2.0 files remain on GitHub and are
not modified. Gameplay controls start OFF, except the local alert preference
which is initially ON. Right Shift hides the menu; the floating Aurora chip
reopens it. X safely tears down all Aurora-owned overlays and settings.

## Eleven pages

| Page | Live functions and controls |
|---|---|
| HOME | Menu-aware character state, real own HP/stamina/needs/Amber, active conditions, enabled feature state, player finder status, compact shortcuts |
| **SURVIVAL** | Live hunger/thirst guidance, bounded native-map **food finder** and **water finder**, closest candidate buttons and pin-to-compass actions |
| **EFFECTS** | Nine individual replicated ailment/buff status cards, actual native Recovery Assist request switch, local injury slowdown inputs, survival warnings |
| RECOVERY | Recovery Assist and requests/echo counts, condition display, Rest/config explanation |
| MOVEMENT | Calm Camera, Bright World, native performance request, optional reversible 1.10x local speed/leap inputs |
| **PLAYER FINDER** | Existing aesthetic player nametags and outline ESP; works from current animal root or **menu camera**, with reasons for no sightings |
| AMBER | Survival multiplier estimator and native earned-rewards/guide shortcuts; grazing/home-turf notes |
| PROGRESSION | Growth stage, Thriving expiry, Regrowth allowance, Elder code findings |
| WORLD | Territory state and a compact 18-destination compass; pinned food/water leads override the destination |
| ATLAS | 74 curated, searchable, filterable, favouriteable mechanic/source entries |
| **SETTINGS** | Compact status overlay, optional **local** autosave, export, restore, colour/scale preferences, Comfort/Survival/Explorer presets |

### Food and thirst — what actually works

Press **SCAN FOR FOOD** or **SCAN FOR WATER** on SURVIVAL. Aurora performs a
**bounded, user-initiated** search of nearby already-replicated 3D parts
(`GetPartBoundsInRadius`, 500 studs, maximum 1,100 parts searched).
It matches *names* such as grass, carcass, fish, berries, water, pond, lake
and spring. Water results also include established map-point leads.
Select one of up to seven candidates to point the WORLD compass to it.
This uses the current living animal's position and only current client data.

A candidate is **not guaranteed to be edible or drinkable**, especially if
the current animal species cannot use it or the terrain/object was not
streamed. The finder does not move, teleport or feed the character.
The server-held Hunger and Thirst values cannot be reliably filled just by
setting local attributes, and no verified safe direct fill protocol was
recovered. v2.1 deliberately does not fake a "FULL HUNGER" button.

### Effects — watch and use real available controls

The EFFECTS page now displays each status independently:
`FeralInjury`, `FeralBleed`, `FeralVenomAmt`, `StaminaOut`,
`FeralHobbledUntil`, `FeralThriveUntil`, `FeralRegrowLeft`,
`FeralHomeTurf` and `FeralGrazing`.

Active controls:
- **Recovery Assist**: normal `WolfActions("Rest", true)` when injured,
  bleeding, venom-affected or below full health, with local pose mask and
  owned `Rest=false` cleanup.
- **Local injury slowdown inputs**: reversible edits to already-loaded
  client movement config, not injury removal.
- **Needs/exhaustion alerts**: client notifications.
- **Food/water shortcut**: move to the resource finder.

**Not server-grantable from this export**: perpetual Thriving, x2 Regrowth,
free 3x Amber, permanent Elder, grazing/home damage, immunity to injury,
actual venom removal, permanent full food/water or all disabled abilities.
An "ENABLED" control means the **local switch** is armed, not that the server
has awarded its named gameplay benefit. Aurora lists feature statuses so
that "ARMED/WAITING" and "CLIENT VALUES APPLIED" are distinguishable.

### Player Finder in the menu

v2.1 no longer requires a spawned animal for basic player tracking. It
uses the **own animal's root** when available, or the **current camera
position** when in the animal-selection menu. The updated page reports:
- Search origin (ANIMAL or MENU CAMERA)
- Other players in the server
- Replicated living characters with roots
- Players actually within the selected range
- A human-readable reason for zero displayed players

The old 24-character cap, 150/300/600/900-stud range, nametags with species,
distance and HP bars, coloured Highlight outlines, subtle/bold styles,
visible-only/through-wall option and cleanup are retained. In menu mode,
other players may simply not be streamed, so zero is possible and explained.
All ESP is local visual rendering; no other-player information is uploaded.

### Compact HUD and presets

The optional compact status HUD shows current own HP, stamina, hunger and
thirst without opening the main menu. When in the animal menu it explicitly
says no active animal.

The settings page now provides:
- **Comfort**: Calm Camera + Bright World + native Performance
- **Survival**: Needs warnings + compact status HUD
- **Explorer**: Visible-only Player Finder, nametags, outlines, warnings and
  compact HUD; through-wall mode is explicitly left OFF

Restore All disables hub-owned gameplay effects, overlay and autosave toggles.
No preset enables the experimental old 3× stamina-pool modification.

### Local report history versus GitHub

v2.1 has an **opt-in** `AUTO-SAVE OWN STATUS LOCALLY` switch and a manual
`SAVE LOCAL FILE` control. Every two minutes (if enabled and supported),
Aurora writes the latest **up to sixty own-character snapshots in the
current session** to `FERAL_Aurora_Status_v2_1.json.txt` in the executor's
working directory. The file contains your own resources, status flags,
bounded overlay counts/reasons and basic session facts. It **excludes
other-player names, coordinates, chat, account IDs, source bodies and
credentials**. Disabling autosave stops further writes.

**This is not GitHub synchronisation.** A GitHub repo hosting a Luau script
doesn't give the script permission to push reports. The existing Windows
self-hosted GitHub Actions runner is available but has no wired file
collector or automatic authorised private upload channel. Connecting one
would require a deliberate local collector and consent to upload the
chosen personal-game data; v2.1 does not do that silently. Until then
we can inspect reports you choose to share, not live gameplay automatically.

## Modules

- [Launcher](feral-aurora-hub-v2.1.lua)
- [Engine](feral-aurora-engine-v2.1.lua)
- [UI](feral-aurora-ui-v2.1.lua)
- [Mechanics atlas](feral-aurora-atlas-v2.0.lua) (retained)
- [GitHub CI](../.github/workflows/feral-aurora-v2.1-validate.yml)

## Verification

The code is validated using official Luau 0.747 compile-only checks and
source-level assertions for menu-aware tracking, non-spoofed needs,
local-only reports and the new UI controls. This does **not** establish
the runtime availability of every Roblox attribute, UI hook, console action,
food/water source or external Velocity API. No live Velocity test has
occurred in this release.

**FERAL's private server code was not recovered.** Native requests and
local cache changes cannot prove server-accepted status effects or immunity.
The earlier prolonged Burst deaths remain unresolved.
