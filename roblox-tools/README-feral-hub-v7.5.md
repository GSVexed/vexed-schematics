# FERAL Hub v7.5 — attack priority / missing health-bar regression fix

**Release date:** 21 November 2026  
**Game:** FERAL Animal Survival, PlaceId `108901361810209`  
**Current one-file Potassium bundle:** `feral-hub-v7.5-potassium.lua`

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v7.5-potassium.lua"))()
```

**Right Shift** opens/closes the UI. **End** shuts the current hub down. Do not stack versions.

## Why this patch was necessary

The preceding v7.4 active recovery kept `WolfActions:FireServer("Rest",true)` on through mouse attacks until a combat tag appeared. But the game's normal bite pathway can be blocked while in its native Rest state, even if the hub locally masks `WolfRest` false. That creates a deadlock: the server may reject the bite, so the combat tag the hub was awaiting might not appear. Missing enemy health bars could result from failed bites, but actual server damage and visibility are not conclusively measured by a client-side startup check.

## v7.5 fix

- Own Mouse1/Mouse2 attack input **immediately releases** any Rest signal owned by the recovery module with the game's native `Rest(false)` action, with a brief 1.3-second cooldown.
- A held attack button keeps recovery paused. Recovery resumes only once the input has ended and the short input cooldown expires.
- Existing local combat guide `nativeReady`/`ready` signals can **preemptively** release native Rest as an animal enters bite range. This reduces the chance of a first bite failing because the server has not yet received the release.
- Actual combat tags, grab/escape, and original pose safety continue to prevent native Rest during unsafe interactions.
- The v1.1-inspired mask-before-request recovery sequence, five-second refresh while injured, and bounded pose-safety backoff are retained for safe recovery periods.
- The current stamina settings, flight, Eagle carrying, Talon local gate, baby carrying, escape, climbing and other modules remain as in v7.4.

## Evidence and limitations

- [Release validation](https://github.com/GSVexed/vexed-schematics/actions/runs/44923440417): all 19 modules compiled and matched exact sources; mocked rest lifecycle tested Mouse1 release, held-button pauses, bite-window release, out-of-combat refresh, combat-tag pause, and pose backoff.
- [Pinned private Potassium deployment](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44923495480): exact Git blob `e654f6bbe77a9de90f76bd54835ebccea5d0cb4f` verified and staged for live execution.
- Updated private collector observed a fresh **v7.5 READY** startup, 19/19 modules, 35/35 self-checks, and zero startup errors on November 21, 2026.
- **Not yet verified:** actual server-accepted bites and enemy health bars after the patch. Confirm with ordinary gameplay rather than trusting the client status UI. This code only coordinates the game's own Rest event; it does not modify another player's health.
- If bite display is still not functioning, turn **Active Recovery OFF** using the in-game hub and retry a normal bite. That releases the hub-owned Rest signal without disabling stamina, Eagle or other modules. If disabling it does not resolve the issue, investigate other causes (local health-bar display settings, native bite input, action state, native target conditions).
