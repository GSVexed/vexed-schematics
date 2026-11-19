# FERAL NOVA PRIME v5.0

One-screen, high-impact FERAL hub. Built on the existing Aurora v2.1
client controller and Aurora FORCE v3.1 reversible power module.
The source is published in the user's existing GitHub repository.

## Copy/paste into Velocity (while inside FERAL)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-v5.0.lua"))()
```

PlaceId: **108901361810209**.

## Six switches (no tabs, no scrolling)

| Control | Real local action |
|---|---|
| **ENDURANCE** | One setting: native cached 3× stamina recovery, no recovery delay, no low-needs penalty, plus own-character WolfDbgNoStamina flag. No STOCK/3×/APEX selector |
| **AUTO ESCAPE** | Enabled on load. Detects local grabbed-state attributes, explicit escape UI prompts, or a replicated physical joint connecting your character to another player's. Presses/releases Space automatically ~8 times/second when triggered; pauses for chat |
| **OUTLINE ESP** | Enabled on load. Existing player tracker (up to 24 nearby replicated living players), true transparent fill and visible outlines. No body glow |
| **AGILITY** | Single 1.30× speed / 1.35× leap cached-input combination with rollback if either part isn't supported |
| **ANTI-SLOW** | Disables the two loaded client injury movement slowdown inputs when available; does not heal injury or remove server statuses |
| **CLEAR VIEW** | Local brighter vision and reversible local fog/atmosphere reduction |

The compact ESP strip has only **TAGS**, **WALLS** and **RANGE** (450/900).
By default: outlines ON, through-wall outlines ON, tags OFF, auto escape ON.
Endurance, agility, anti-slow, visibility start OFF. Turn on Endurance with one click.
Right Shift hides/reopens; X cleans up; RESET releases owned changes.

Live HP, stamina, hunger and thirst appear in the header. The footer gives
the actual auto-escape state and one nearby player.

## Difference from v4

- All three stamina profile buttons are gone. One **Endurance** switch
  combines 3× recovery and the local no-drain flag. **Apex 250 regen**
  is removed from the user-facing UI because unverified prolonged-Burst
  deaths were previously observed while aggressive stamina tuning ran.
- Three speed and three leap choices are replaced by one **Agility** switch.
- No redundant survival pages, setup presets, achievement panels,
  waypoint cards or decorative research tools.
- Escape detection is isolated in a bounded module with an ~650-node
  UI scan and maximum ~450 joint candidates per nearby character, rather than
  unbounded global scans.
- All player highlight fills are fully transparent: `FillTransparency=1`
  and `OutlineTransparency=0`. Name tags are unboxed and positioned
  above the head rather than a large plate over the body. The official
  Roblox Highlight docs confirm that setting `FillTransparency=1`
  hides the interior completely.

## Critical limits, not fake features

- **Automatic escape does not have a confirmed game-specific latch signal.**
  It is a best-effort watcher. If no recognized state, joint or prompt
  is replicated, it stays in WATCHING and does not send Space. If Velocity
  cannot emit usable keyboard events, it shows NO KEY INJECTION or
  KEY INPUT BLOCKED. An executor accepting a keypress function is not
  proof that FERAL's server counts the escape.
- Endurance and Agility change **local client configuration**, not a server
  inventory or stamina authority. Underlying client controls were previously
  user-observed working for some Bear/Tiger movement, but server acceptance,
  safety during prolonged Burst and every species remain unproven.
- The earlier extensive code/diagnostic review did not establish a
  working grant for arbitrary Amber, invulnerability, restricted animals,
  infinite health or server-control bypass. Those unverified buttons have
  **not** been added.
- GitHub Actions validates official Luau syntax and source invariants.
  This is **not** a live Roblox/Velocity test, and the GitHub runner is
  **not** a remote desktop into the user's computer.

## Modules

- `feral-nova-prime-v5.0.lua` — loader
- `feral-nova-prime-ui-v5.0.lua` — single-screen UI + ESP style
- `feral-nova-escape-v5.0.lua` — automatic grab detection & input
- `feral-aurora-engine-v2.1.lua` — existing own-status and player tracker
- `feral-aurora-power-v3.1.lua` — existing reversible client tuning
- `.github/workflows/feral-nova-prime-v5-validate.yml` — validation

No game exports are uploaded by this script. No direct user PC access or
game-server access is claimed.
