# FERAL NOVA v8.1 — Moving Recovery + Auto Perfect Preview

**Date:** 21 November 2026  
**Stage:** Compiled + automated regression tested; server outcomes still need live in-game verification.  
**Do not confuse this preview with the fully completed v8 overhaul.**  
**Stable rollback:** `feral-hub-v7.5-potassium.lua` (normal combat and health-bar rendering confirmed by user).

## Single-file Potassium launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v8.1-preview-potassium.lua"))()
```

**Right Shift:** show/hide hub. **End:** close all controllers and release their signals. Running the newer loader replaces an older registered hub; avoid manually stacking unrelated old scripts.

## 1) Why mobile recovery appeared to work only while standing still

The game has a native `WolfActions:FireServer("Rest",true)` request that can give a real Rest bonus, but the native pose and attack rules conflict. In v7.5/v8.0, the Rest module already attempted a hidden-pose native Rest while moving, and automatically released Rest when attacking or entering combat. However, a **broad local targeting hint** (`lab.ready`) also suppressed the Rest signal without requiring that the target be in the game's original native bite reach. As the player moved near animals, this could appear to shut off recovery.

This preview makes two careful changes:

- **Avoid false-positive bite pauses:** `lab.nativeReady` (original bite eligibility) still releases Rest in anticipation of combat. The broader `lab.ready` hint no longer causes idle recovery to be dropped. Actual Mouse1/Mouse2 inputs and native combat tags still release it. This keeps the v7.5 normal-damage fix.
- **Adapt when moving:** while injured or affected and in a safe out-of-combat window, the module refreshes its *original* native Rest request **at most every three seconds during motion** versus five seconds while stationary. A movement-start transition is permitted one bounded early refresh, with a minimum two-second gap between requests. No Health or combat attribute is forged, and no visible resting pose is forced.

**Important:** The server can still reject or stop native Rest while moving. The code cannot make a claim of guaranteed continuous heal based on its local `active` state. New diagnostics separately track **same-max-HP moving vs. stationary positive HP changes** and eligible seconds, as well as how often the native Rest request was refreshed during motion.

**Do not disable the real bite or combat guard to gain extra recovery.** The earlier v7.4 variant prevented normal damage/health bars.

## 2) Native Grab V2 Auto Perfect

The exposed `FeralGrabV2UI` receives a real server-issued `strike` event with timing parameters (`t0`, `spd`, `from`, `zc`, `zw`, `k`, `f`). Its own input function uses the native request:

```lua
FeralGrabV2:FireServer("press", sessionId, strikeId, workspace:GetServerTimeNow())
```

This preview includes a separate **AUTO PERFECT** switch in the in-hub experimental row. **It is enabled by default after opening the preview, and can be disabled.**

The controller:

1. Listens for the *game's actual* `FeralGrabV2.OnClientEvent("strike", payload)`; it does **not** fabricate strike offers.
2. Validates a genuine positive session ID and positive strike ID. Practice-mode `f=-1` is intentionally not sent to the server.
3. Computes the exact crossing of the moving triangular indicator through the zone's centre using the supplied timing and the native configuration.
4. On a Heartbeat frame within the local Perfect window, sends one native `press` request with the **current real synchronized server time**; never sends a future or falsified timestamp.
5. Respects the player's own manual minigame input and skips expired or malformed offers; it can be switched off instantly.
6. Releases any hub-owned native Rest state before a grab minigame, preventing recovery from interfering with timing interactions.

**Accuracy boundary:** A correctly calculated local crossing is **not** proof of a server-assigned Perfect. FPS/latency/server validation may reduce accuracy, the native UI may not update its local `pressed` flag from a direct request, and some minigames may use a different protocol. The result counters track native strike notices, sent presses and server grade messages where recognized. Do not treat the word Perfect on the hub as an actual win unless the game shows it.

## 3) Preserved features

- v7.5 ordinary bites/health bars, stamina, active out-of-combat recovery, safe release for combat and carry, climbing, flight, baby carry, Eagle native attempts, Talon local gate, ESP and diagnostic tools
- v8.0 separate **anti-idle** and optional **survival activity** (actual brief safe walks; remains opt-in and cannot guarantee server survival-bonus progression)
- Full controller lifecycle cleanup and one-file offline modules

## 4) QA and evidence

The code consists of **22 embedded modules**. The new version changes only native Rest, the UI and shared action policy, and adds a single Grab V2 controller; all other modules are unchanged from the v8.0 foundation.

- [Official Luau compile and exact module parity, attack/Rest regression, AFK regression and Grab V2 timing mock — v8.1](https://github.com/GSVexed/vexed-schematics/actions/runs/44926938009)
- The mocked minigame successfully triggered a single native press at an actual server-time crossing, ignored invalid practice ID, gave manual input priority and sent no requests after shutdown.
- All 22 modules passed independent compile tests and the original v7.5 bite-safety flow retained its regression suite.
- Startup self-checks now include four additional v8.1 checks for the Grab listener, motion-gain measurements and motion-refresh counters. **42 checks total** if all runtime module attachment succeeds.
- The private Potassium report collector supports the `8.1.0` startup/session schema and whitelists only own-character moving healing and auto-minigame counters; it never exports player identities or credentials.

**Still unverified:** real mobile Rest bonus while running, server-assigned Perfect frequency, survival bonus retention while AFK, oversized Eagle carrying, genuine Talon cooldown reduction, and server-authoritative infinite needs.

## Recovery debugging

Open the hub, use **RECOVERY STATUS** or **COPY STATUS**, and compare `moving_hp_gain` / `moving_eligible_hp_seconds` against the stationary equivalents. A legitimate HP gain rate requires observing the same MaxHealth at both ends and being outside combat; results may also reflect normal passive healing.

If you experience missing enemy health bars or bites after switching to this preview, turn **ACTIVE RECOVERY OFF**, check normal attacking, and revert to the proven v7.5 loader. Never force native Rest continuously through actual attack inputs.

## Fallback (v7.5)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v7.5-potassium.lua"))()
```
