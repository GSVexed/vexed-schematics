# Empire Clash NOVA — Combat Guide v0.8.0

Source: `roblox-tools/empire-clash-nova-combat-guide-v0.8.lua`  
Branch: `project-empire-clash-nova`  
Based on recovered November 23, 2026 Runespire client code and NOVA v0.7.

## Loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/project-empire-clash-nova/roblox-tools/empire-clash-nova-combat-guide-v0.8.lua"))()
```

## Features

- Weapon-aware **observational** guidance profiles for rifles/muskets, pistols/flintlocks, blunderbuss, swords/melee, thrown items, mounted cannon, bow, and unknown tools. Heuristic family detection; weapon-specific physical ballistics are not computed.
- Adaptive indicative point: torso for spread/melee/thrown classes, head when clear for other weapons; point alignment is **not** a guaranteed registered headshot or damage event.
- Faster selection refresh (75ms), selection expiry 260ms; early distance/screen-space culling before LOS raycasts to reduce load.
- Read-only optional subscription to already replicated `DamageService.SendHitmarker` and `ReportDamage` where available; counters are generic and are not proof of target/body-part-specific damage.
- Preserves v0.7 faction-colour name tags and outline-only highlights, selected-target card, disguise warning based on replicated information, Right Shift panel, saved settings, map transition loader, compact options, clean unload.
- No network request rewrites, shot direction interception, camera snapping, unsolicited fire requests, anti-cheat bypass, or stealth logic.
- This v0.8 release **removes** the failed experimental silent-aim interception from v0.7. Previous builds remain separate.
- Visual target feedback depends on client replication and is not proof of server-authoritative state.

## Limitations and verification

The recovered client code is an imperfect reconstruction and snapshot; current Empire Clash game/client behavior and all weapon types are not fully verified. This script is new source work, not a proven live combat advantage. The project cannot promise headshots, server damage, or account safety. Source and CI checks run offline and do not execute the Roblox runtime.

If the pinned workflow succeeds, it confirms syntax and selected source invariants only. Actual runtime feature support remains untested.

The game might prohibit such tools; follow the game's rules.
