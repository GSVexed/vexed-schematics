# Empire Clash NOVA v0.7 — Simple UI, all previous settings retained

**Date:** 2026-11-23  
**Source:** `roblox-tools/empire-clash-nova-phase8-simple-ui-v0.7.lua`  
**Development branch:** `project-empire-clash-nova`.

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/project-empire-clash-nova/roblox-tools/empire-clash-nova-phase8-simple-ui-v0.7.lua"))()
```

Open and close with RightShift. The build preserves faction-coloured names and outline chams, disguise warnings, target card, selection preview, all original settings, persistence and existing optional shot-correction experiment.

## Simple controls

NOVA now opens directly to five high-level toggles:
1. Faction-coloured outlines
2. Names + disguise warnings
3. Selected target card
4. Visual aim guide
5. Show targets through walls

A single **ADVANCED OPTIONS** button expands all original detailed controls (no feature is removed), including FOV, range, team filter, head/torso preference, visibility, prediction preview, faction subtitles, disguise alerts, chams, nametag control, target card, reticle display, teleport queue and legacy experimental shot correction. Advanced starts closed every execution. Quick controls and advanced controls which edit the same configuration field automatically refresh one another.

The old technical status is condensed to a short two-line version/weapon/readiness indicator; when Advanced is open the previous detailed status returns. The Copy Details capability remains available there. Unload is still directly accessible.

## Source verification

**Official Luau compiler and v0.7 UI regression assertions: passed** in [GitHub Actions 45282147263](https://github.com/GSVexed/vexed-schematics/actions/runs/45282147263).

- Source version v0.7 and raw launcher URL are checked.
- All Quick Controls plus the Advanced foldout exist, with original controls still present.
- Faction names and outline colours stay identical and use actual replicated Player.Team.
- Luau compilation passed without Roblox gameplay or executor execution.

## Important non-claims

The user reported the original Silent Aim does not work. This v0.7 release makes **no claim** to have fixed Silent Aim, altered server hit recognition or avoided anti-cheat. The existing experimental shot correction is retained but starts OFF. It has not been shown to register hits or avoid detection and may introduce account risk. V0.7 is a **UI/UX maintenance release** only, not a fix for the user's primary aim-assistance requirement.

No additional diagnostics have been requested. Prior versions v0.2–v0.6 remain preserved.
