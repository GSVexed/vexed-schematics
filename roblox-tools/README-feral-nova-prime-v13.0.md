# FERAL NOVA PRIME v13.0 — full integration audit and consolidated release

**Date:** 19 November 2026  
**Game:** FERAL Animal Survival · Roblox place `108901361810209`  
**Delivery:** One self-contained file containing nine pinned Luau modules; official Luau validation plus native-action simulations.

## Recommended one-line launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v13.0.lua"))()
```

**Only one v13 loader is recommended.** The standalone release includes all nine modules without per-module network downloads. If v7/v8 HITBOX TEST ever enlarged nearby animals in the current session, **fully rejoin Roblox before testing v13**; there is no safe way to reconstruct arbitrary original target part sizes after an interrupted cleanup.

## Why this version exists

The earlier versions were released incrementally as individual defects appeared, which repeatedly broke combinations of otherwise plausible features. After user feedback about carrying, combat, ineffective recovery and inconsistent UI, v13 audits **the interaction between all active systems**, not just the latest one. The code now distinguishes *local configuration applied*, *game-controlled native action requested*, and *server-authoritative outcome observed*. A clickable toggle is not treated as evidence of a gameplay advantage.

### Verified defects fixed in v13

1. **Mobile Recovery terminated itself when carrying slowed the character.** V12 checked velocity *before* detecting that the predator was holding prey. V13 checks carrying first. The trial pauses instead of turning itself off, tolerates native G/drop latency and restarts its baseline after release.
2. **Safe Rest could miss an active carry because it returned early on WolfRest or Turtle shell conditions.** V13 prioritises outgoing carry and incoming victim states *before* those branches, and cancels its **own** Rest request before an attempted carry action. Does not modify the prey's physics.
3. **The older engine contained a legacy Rest-mask controller which forcibly set local WolfRest=false.** This could interfere with Turtle and contaminate Rest observations. V13's engine has no local WolfRest=false write and refuses to turn on that deprecated recovery path. The dedicated Safe Rest and Mobile Recovery modules are the only normal Rest-request owners.
4. **The new UI started with nametags OFF**, despite the name-tag fix. V13 uses a new names-ON default preferences file; tags can still be manually switched OFF.
5. **The G carry/drop transition could briefly be mistaken for a victim escape.** Escape now recognises a short native G-action grace interval, except when the character is genuinely pinned/carried/dragged. It never sends `shake/getoff` merely because the predator holds prey/carcass.
6. **The native carry helper was treated as unusable when pickup was blocked, even if the predator was already holding prey and wanted to release it.** V13 lets the game-owned carry helper handle the release branch while holding prey, instead of blindly switching to simulated keypresses.
7. **Combat, stamina and recovery status were visually overclaimed.** The main display labels Endurance and Agility as **CLIENT** modifications, the mobile recovery option as a **TEST**, and Copy Status reports actual local cached stamina/speed/leap lease matches, status indicators, native requests and observed outcomes. The combat guide reports when the game's normal `WolfController` may reject bites while the predator is holding prey; the hub does **not** intercept attacks.
8. **Unnecessary high-frequency work:** native carry-capability polling is capped at around 8 Hz, idle ContextActionService escape-binding scans are avoided, and read-only collision audits are reduced to around 2 Hz. Bite guide responsiveness remains about seven updates/second.
9. **Previous physical hitbox experiments created unwanted collision.** V13 neither enlarges enemies nor writes enemy part Size, CanCollide, CollisionGroup, health or position. Bite guidance and collision inspection are read-only.

### Complete feature-by-feature status

| User-facing feature | v13 behaviour | Verification status |
| --- | --- | --- |
| **Endurance** | Single 3× local stamina recovery/no-drain configuration switch; copies actual lease and local flag status | Local config application measurable; **server unlimited stamina unproven** |
| **Auto Escape** | Own victim-state detection, directional shake/tug, carry-getoff, minimum-safe native intervals, monitored progress, ignores outgoing carry | Input code passes simulated tests; **instant Tiger escape unproven** |
| **Carry / Drop** | Native FERAL `G` action or `_G.FeralCarryPress` helper with eligibility/cooldown, no invented remotes | Native-action simulation passes; **server pickup/drop acceptance must be observed in-game** |
| **Outline ESP and Tags** | Outline-only Highlights and unboxed screen-positioned text; names ON on first v13 load | Render/projection tests inherited from v8; close camera implementation is client-visible |
| **Agility** | Reversible local speed/leap and injury-slow cached inputs; actual lease status copied | Local lease matches measurable; server movement validation unverified |
| **Mobile Recovery** | Opt-in moving normal / native Rest signal / after comparison, with automatic cancellation on Rest interference, grabs, attack and carry pause | A/B state machine simulated; **permanent 2× HP / 4× injury/bleed/venom while moving and fighting not proven** |
| **Safe Rest** | Small separate opt-in action; normal cautious Rest assistance and Turtle shell observation; carry and combat take priority | Ordinary game-defined Rest rule; not an always-on advantage |
| **Bite Guide and Range** | Read-only CombatConfig target geometry, observed own bite starts and nearby target HP decreases | **Not an increased server hitbox or server-accepted reach** |
| **Clear View** | Reversible local fog, atmosphere and lighting changes | Client visual only |
| **COPY STATUS / RESET / CLOSE** | Reports native/cached status honestly and restores the hub's owned toggles and leases | Tests verify module close and native cleanup where simulated |

### Recovery: important distinction

Archived `NeedsConfig.HEALTH_REST_MULT=2` and `StatusConfig.*.REST_MULT=4` are the **game's resting multipliers**. They are not an always-on upgrade. A prior report measured approximately 2.19 HP/s while resting versus 1.04 HP/s normally, evidence consistent with the game’s native 2× Rest bonus. It did not demonstrate permanent regeneration while fighting.

The v13 Mobile Recovery experiment requests a game-native Rest signal **while the player is moving** and measures changes in actual HP and injury/bleed/venom attributes, rather than treating a local flag/remote request as success. It stops if the client enters true Rest and bites might be blocked, or when attacking or captured. It pauses during carrying. Even if an uplift is observed, the cause and server-side persistence remain uncertain.

**FERAL server source is unavailable**, and client scripts/config cannot simply grant server-authoritative health, 4× effect recovery, infinite stamina, damage or longer accepted hitboxes.

### Native carry vs being captured

Client-source findings were reconciled against previously recovered scripts:
- Outgoing hunter grapple: `FeralClamp` ObjectValue, and `Carry` flag. Carcass holding: `FeralCarcassCarry`.
- Being captured: `FeralCarried`, `FeralPinned`, `FeralDragged`.
- Game’s carry key is **G**. The game-owned `_G.FeralCarryCan` and `_G.FeralCarryPress` are preferred when available, otherwise the hub attempts the ordinary G key through supported executor input.

If FERAL itself refuses to attack while you hold prey, that server/game rule remains. The hub will not drop prey automatically in an attempt to bypass it.

### Tests / reproducibility

GitHub workflow `.github/workflows/feral-nova-prime-v13-validate.yml` validates:
- Official Luau compilation of **all eleven source and entrypoint files**, including full standalone;
- exactly **nine bundled modules**, checked byte-for-byte against repo sources, avoiding independent download drift;
- native outgoing prey versus incoming victim classification (prey, carcass, carried, pinned, dragged);
- G helper/keypress routing, double-input throttle, Rest-off-before-native-carry sequencing;
- Mobile Recovery pausing when carry slows movement to zero, staying enabled while carrying, and restarting after native carry completion;
- captured-victim escape still engaging, while holding prey doesn't trigger false escape;
- Safe Rest sending its owned `Rest=false` even if `WolfRest` was observed active while an outgoing carry begins;
- static invariants forbidding enemy root-size edits, legacy `WolfRest=false` writes, unsolicited gift/damage remotes, and misleading default ESP settings.

**The available runner cannot execute a real Roblox/Velocity game session on the user's PC.** These tests give strong evidence of code wiring and state transitions but **cannot certify that the private game server allows a desired gameplay advantage**.

## Source
- [v13 single-file launcher](feral-nova-prime-standalone-v13.0.lua)
- [v13 modular loader](feral-nova-prime-v13.0.lua)
- [v13 core](feral-aurora-engine-v13.0.lua)
- [v13 native carry](feral-nova-carry-v13.0.lua)
- [v13 Auto Escape](feral-nova-escape-v13.0.lua)
- [v13 Mobile Recovery](feral-nova-mobile-v13.0.lua)
- [v13 Safe Rest](feral-nova-recovery-v13.0.lua)
- [v13 combat guide](feral-nova-combat-v13.0.lua)
- [v13 UI](feral-nova-prime-ui-v13.0.lua)
- [v13 CI](../.github/workflows/feral-nova-prime-v13-validate.yml)
