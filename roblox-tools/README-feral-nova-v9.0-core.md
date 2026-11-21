# FERAL NOVA CORE v9.0 — Coordinated Gameplay Preview

**Released:** 21 November 2026  
**Status:** Official Luau compile and mocked regression suite **PASS**. **Live client/server outcome validation outstanding.**  
**Working rollback:** v7.5 (user-confirmed normal bite damage and enemy health bars), v8.1 (previous AFK and Auto Perfect preview).

## Loader — one paste in Potassium

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v9.0-core-preview-potassium.lua"))()
```

Do not stack old and new hub scripts manually. The active-hub registry shuts down the prior registered hub before a new one takes ownership. **Right Shift:** hub. **End:** shutdown. **HELP → COPY CORE AUDIT:** copy actual coordinator decisions and recovery/Grab/AFK statuses.

## What changed

The bundle still has **22 modules**: **8 refactored** and **14 byte-for-byte preserved** from v8.1.

| Rebuilt module | Improvement |
|---|---|
| [Action Core v9.0](feral-nova-action-core-v9.0.lua) | One shared read-only game-state snapshot and explicit action priorities for native Rest, attack, grab, carry, escape, climb and AFK walking. Timed leases expire automatically. |
| [Native Recovery v9.0](feral-nova-native-recovery-v9.0.lua) | Uses the shared safety policy to release Rest for higher-priority actions. Keeps original Mouse1/Mouse2 release, true native-bite preparation, combat-tag blocking, 3s moving/5s stationary wounded refresh, and same-max-HP healing observations. |
| [Grab V2 v9.0](feral-nova-grab-v9.0.lua) | Protects native server-issued timing sessions with an expiring high-priority lease and releases it on completion. Still uses the real server clock and original native press format. |
| [AFK v9.0](feral-nova-afk-v9.0.lua) | Optional safe ground movement reserves lower-priority action ownership; cancels and releases when combat, grab, user input or unsafe conditions intervene. Roblox idle heartbeat remains separate. |
| [Q Climb v9.0](feral-nova-climb-v9.0.lua) | The original 2.25s Q buffer and single guarded tap retry now obey minigame/action priority, avoiding stray climb taps during Grab V2. |
| [Auto Escape Core v9.0](feral-nova-escape-core-v9.0.lua) | Legacy shake/tug escape automation yields while a native Grab V2 minigame is active; it remains available for ordinary native captures. |
| [Carry Core v9.0](feral-nova-carry-core-v9.0.lua) | Hub G press respects Grab V2 action priority when first requested and again before a delayed action. Native manual G input remains untouched. |
| [UI v9.0](feral-nova-ui-v9.0.lua) | Built-in Core Audit readout, priorities, local moving-health evidence, native minigame press counts and explicit *server result unverified* labels. |

### Why the architecture matters

In v8.1, action modules could independently decide to send a Rest, G, climb or minigame request. The v9 Action Core now answers whether such a native action is appropriate. That reduces conflicts without assuming the client has authority over the game server.

A key regression fix retained from review: **holding already-captured prey does not automatically disable noncombat Rest recovery**. Starting a new G carry action still releases native Rest to protect interaction reliability.

### Startup settings

The eight refactors preserve v8.1 defaults: Endurance, Auto Escape, ESP, client Bite Reach, Climb, guarded Active Recovery, Baby Carry Protection, Flight Surface Assist, Roblox Anti Idle, and Grab V2 Auto Timing start ON. Experimental growth/carry/Talon, agility and **Survival AFK walking** remain OFF until selected. Saved visual preferences may alter tags/walls/range.

The UI distinguishes **local setting ON** from **actual observed gameplay outcome** and refuses to claim server healing or an accepted carry merely from a client toggle.

## Validation

**Public CI:** [FERAL NOVA Core v9.0 — 22-module validation](https://github.com/GSVexed/vexed-schematics/actions/runs/44929308607).

- All 22 embedded modules compiled with official Luau.
- 14 prior module bodies preserved exactly; 8 v9 module bodies matched their standalone source files.
- Native Rest lifecycle regression passed for attacking, combat tags, held attacks, native bite windows and pose retries.
- Shared action policy mocked test passed for actual native bite vs extended client hints, capture/combat, priority lease preemption and expiration.
- Integration test confirmed that coordinator denial actually **releases native Rest** and that Rest can later re-arm.
- Grab V2 mock confirmed one press at a local Perfect crossing, invalid practice session skip, manual input priority and no presses after shutdown.
- AFK mock confirmed virtual-input callbacks, no unsolicited survival movement, and clean shutdown.
- Holding prey was explicitly regression-tested to preserve noncombat recovery eligibility.

The single-file startup implements **49 interface/initialization checks**. These validate wiring, not server-authoritative success.

The private Potassium collector now supports the v9.0 schema and sanitizes action-priority counts, lease counts and moving/stationary healing results. No credentials, raw coordinates, player identities or arbitrary file contents are exported.

## Known limits and next verification gates

1. **Moving Rest**: the server may reject Rest while moving. A local active signal and faster refresh alone do not establish real increased regeneration. Observe health gains at unchanged maximum HP while stationary versus moving.
2. **Auto Perfect**: correct local timing does not guarantee server Perfect grades; actual game replies must be observed. Practices with negative session IDs do not issue real press requests.
3. **AFK**: no claim of 20+ minute retention or uninterrupted survival bonus until a real unattended session is observed. Survival movement can be risky and stays opt-in.
4. **Eagle and Talon**: larger prey carrying and shortened server cooldown remain unconfirmed. Local config edits or CATCH prompts cannot substitute for physical holds/actual cooldown acceptance.
5. **Hunger/thirst and growth**: values are observed, but server-owned needs are not made infinite, nor is accelerated server growth confirmed.
6. **Full overhaul**: legacy recovery, combat, Eagle, stamina and flight modules still need subsequent focused refactoring and live A/B tests; this is the first architecture milestone, **not a claim of a finished overhaul**.

See the [full 22-module architecture audit and overhaul acceptance contract](FERAL-NOVA-v9-ARCHITECTURE-AUDIT.md).

## Rollback if live combat or recovery regresses

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v7.5-potassium.lua"))()
```

Use **End** to close the current hub before manually switching if possible; one active instance per session is the intended design. Never continue on a build that disrupts native attacks or prevents normal movement.
