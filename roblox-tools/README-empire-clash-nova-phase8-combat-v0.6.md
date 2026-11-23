# Empire Clash NOVA — v0.6 True-Faction Nametags and Chams
**Date:** 2026-11-23  
**Status:** Original Luau code delivered, official Luau compiler and source invariant tests passed. Not live Roblox tested.

## Launch

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/project-empire-clash-nova/roblox-tools/empire-clash-nova-phase8-combat-v0.6.lua"))()
```

RightShift opens / closes the NOVA panel. This version supersedes v0.5, which remains intact on the development branch.

## New: Colour-coded actual faction (not disguise)

The game's recovered `DisguiseController` and `ChatController` establish that the Roblox `Player.Team` property and the visible disguise's `DisguisedTeam` player attribute are separately inspected. The game also reads `leaderstats.Class`, `ForgedName` and other presentation information. These sources are kept **private**; only original NOVA code is published here.

NOVA v0.6 now uses `player.Team.TeamColor.Color` for **both the text of the player's name and the Highlight.OutlineColor**. This colour does not change when a target is selected: a diamond prefix in the nametag indicates selection instead of replacing the faction hue with gold.

- An ally whose actual team matches the local player's `Team` displays the colour of that faction. The subtitle includes `ALLY`.
- Players on another real team display their own team's colour and name, independent of uniforms or forged names.
- If another-team player's `DisguisedTeam` says they are impersonating **your** team, the subtitle warns `DISGUISED AS YOUR TEAM | REAL: <faction>` and is coloured gold.
- If a disguise is for a different team, the subtitle shows `REAL: <actual> | MASK: <disguise>`.
- When the actual class is reported as `Thief` without a faction disguise, the subtitle can indicate `THIEF`; the colour still tracks the actual team.
- A player with no accessible `Team` shows `FACTION UNKNOWN` in grey, rather than guessing from clothing.
- The selected-target HUD also shows the player's actual faction colour and an identity/disguise subtitle.

Each player nametag is now **two lines**: a larger team-coloured name and a separate team/disguise summary. A black outline behind coloured text aids contrast. The outline chams stay **fill-transparent**, matching the original NOVA requirement.

## UI controls

Under `FACTION IDENTIFICATION`:

- `Actual faction beneath names`: ON by default. Toggles the secondary faction description. The name and outline remain faction-coloured even if this is OFF.
- `Thief disguise warnings`: ON by default. Enables the impersonation/forged identity warnings; when off, the secondary line still shows real faction and alliance relation.

Other Phase 8 options and the opt-in experimental shot-correction module are retained from v0.5. This change is visual identification only; no additional networking or bypass behaviour was added.

## Important limitations

The feature displays the **team and attributes replicated to the local client**, not secret server-side information. The recovered source suggests these are kept distinct from client-visible disguises, but if a future game update hides or overwrites the actual team, NOVA cannot guarantee revealing it. Disguise alerts appear only when the relevant replicated `DisguisedTeam` / `Class` / `ForgedName` attributes are present. `Player.Team` distinguishes factions but not necessarily temporary alliances between different factions.

The existing experimental shot correction remains OFF on startup. Server-recognised Silent Aim and anti-cheat bypass have not been established. No in-game diagnostics requested.

## QA

- Official offline Luau compiler PASS and new true-faction / name-versus-outline matching assertions: [GitHub Actions run 45280222113](https://github.com/GSVexed/vexed-schematics/actions/runs/45280222113)
- Script: `roblox-tools/empire-clash-nova-phase8-combat-v0.6.lua`, original file commit `b4741735386f5af50b447fac00f384dcf75d344a`.
- Test assertions confirm both `rec.highlight.OutlineColor = factionColor` and `rec.tagText.TextColor3 = factionColor` with `factionColor` derived from `identity.color` based on `player.Team`.
- Automated source tests are not a substitute for live display verification.
