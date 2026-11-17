# FERAL AURORA FORCE v3.1 — high-impact control hub

Aurora FORCE supersedes the earlier waypoint-heavy `Aurora v3.0` design.
The user rejected the target waypoint/compass concept and asked for
**powerful, genuinely functional gameplay tools**, not research cards,
a long diagnostic suite, or cosmetic "unlimited" buttons that only modify
the displayed HUD. The prior `v3.0` code is preserved for history but is
**not** the current launcher.

## One-line Velocity launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-aurora-force-v3.1.lua"))()
```

Works only in PlaceId `108901361810209`.
Rerunning closes existing identified Aurora and FERAL client hubs with
shutdown hooks and cleans up their owned values.
All **power** settings start OFF.

## Real controls, not empty research cards

| Control | What it actually changes | What it cannot prove |
| --- | --- | --- |
| **3× RECOVER** | Changes loaded `NeedsConfig.STAMINA_REGEN` to 3× current value, `STAMINA_REST_MULT` to 1, `STAMINA_REGEN_DELAY` to 0 and `STAMINA_LOW_NEEDS` to 1. Reversible, runs only on toggle. | Does not grant 3× health recovery, server Rest or server-authoritative stamina |
| **APEX client stamina** | Uses recovered Field Hub v1.4 tuning: `STAMINA_SPRINT_DRAIN=0`, `STAMINA_JUMP_COST=0`, `STAMINA_REGEN=250`, `STAMINA_REGEN_DELAY=0`, `STAMINA_LOW_NEEDS=1`, and the own-character `WolfDbgNoStamina=true` flag. Existing flag value restored on toggle-off when still owned; reapplies to respawns. | Not immune to unknown stamina costs, server enforcement or sudden deaths |
| **Standalone no-drain flag** | Sets `WolfDbgNoStamina=true` on own character without changing config, optionally independent of APEX. | Not an accepted server resource grant |
| **Speed profiles** | Reversible cached `RUN_SPEED` and `SWIM_SPEED` input profiles: stock / 1.15× / 1.30× / 1.50×. | Server movement restrictions remain independent; extreme profiles might lead to correction/death |
| **Leap profiles** | Cached `JumpLeapConfig.DEFAULT`, `MAX_RUN_SHARE` and species `BODY_LENGTHS` values: stock / 1.15× / 1.35×. | No extra leap ability, flight, or server-granted free movement |
| **ALT-held rapid escape** | When key injection is available (`keypress`/`keyrelease` or a permitted `VirtualInputManager` fallback), holding ALT pulses Space roughly every 170ms, with chat text focus excluded. Optional and defaults OFF; it stops if the runtime rejects the injected input. | Executor support and the game's input acceptance are not verified; it may not work in Velocity |
| **Injury slowdown inputs** | Reuses v2.1 reversible client `HURT_SLOW`/`INJURY.SLOW_PER_POINT` changes. | No healing or status removal at the server |
| **Low-needs recovery factor** | Reuses v2.1 client `STAMINA_LOW_NEEDS=1` toggle when below hunger/thirst threshold. | Does not fill real hunger/thirst |
| **Recovery Assist** | Reuses the native `WolfActions("Rest",true)` own-character request path under missing HP/bleed/venom/injury, and local pose mask, with cleanup. | Moving Rest and healing still controlled by private server; other players may see a different pose |
| **ESP** | Reuses v2.1 local player finder with 3D Highlight outlines, nametags, visible-only/through-wall toggles, 150/300/600/900 studs, 24 nearest replicated characters, subtle/bold style, compact nearby list. | Cannot reveal players that Roblox hasn't replicated |
| **Comfort / visibility** | Native calm camera/performance flags, brighter game rendering, compact own-resource HUD. | No global weather or other-player effect |

The controls are not all equally reliable. The **strongest prior
user-reported evidence** is from earlier Field Hub testing:
- Bear: user reported unlimited-stamina behaviour with controller config
  tuning (not with a simple Stamina HUD attribute rewrite).
- Tiger v1.2: recorded tuned sprint/burst/swim segments with local stamina
  exceeding 99% and no observed exhaustion in those samples.
- **Important counterevidence:** a different Bear life ended abruptly
  with full HP during prolonged Burst. The reason was not identified.
  Apex is therefore **high risk** and cannot be called safe or
  permanently unlimited. The prior server checks remain unknown.

Aurora FORCE does NOT claim actual HP invulnerability, automatically full
food/thirst, arbitrary Amber, Thriving/Elder/Grazing grants or server
anti-cheat bypass: these are not established by the recovered client
source. We chose not to put fake toggles in the power UI.

## Designed for impact

The rebuilt `POWER / ESP / SURVIVAL / SETTINGS` interface has:
- A simple **STOCK / 3× RECOVER / APEX** selector with obvious active state.
- Separate speed/leap preset bars and standalone flag/ALT macro switches.
- A permanent right status rail with HP, stamina, hunger and thirst.
- Live profile checks stating whether the cached client settings still
  match the applied values.
- Dark/glass Aurora visuals, draggable header, scaled viewport,
  hover animations, teal/violet/coral themes.
- Right Shift hide/show with floating reopen chip.
- Fast reset and full cleanup on X or reload.
- Optional compact status overlay, session status copy, and local-only
  autosave. The actual live reports are NOT automatically sent to GitHub.

## Repository modules and verification

- [One-line entry](feral-aurora-force-v3.1.lua)
- [Power module](feral-aurora-power-v3.1.lua)
- [Redesigned impact-first UI](feral-aurora-force-ui-v3.1.lua)
- [Retained verified core](feral-aurora-engine-v2.1.lua)
- [Official Luau and source checks](../.github/workflows/feral-aurora-force-v3.1-validate.yml)

All modules **compile** with official Luau 0.747, and the static control/
cleanup checks pass. These tests do **not** execute inside Roblox/Velocity.
We have no actual in-game test of the new v3.1 build yet. The older
FERAL Recovery Hub v1.3 and all previous Aurora versions are preserved.

**Safety / transparency:** Power-profile cache changes are own-client only.
They can conflict with the live game's server state. Users should never
interpret locally consistent stamina or a green menu toggle as proof of
server acceptance, guaranteed survival or invisibility to other players.
