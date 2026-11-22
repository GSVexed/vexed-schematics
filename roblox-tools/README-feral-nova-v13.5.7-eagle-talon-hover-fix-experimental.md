# FERAL NOVA v13.5.7 — Eagle Talon contact-hover prevention

**Status:** Experimental; source inspection plus all 23 modules compiled and regression-checked; real-server hover resolution not yet confirmed. Stable fallback v13.5.3 and prior experiment v13.5.6 remain unchanged.

## Potassium launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v13.5.7-eagle-talon-hover-fix-experimental-potassium.lua"))()
```

## Reconstructed native findings

Review of the archived v2411 client scripts:
- `FeralDiveBombClient` owns native dive-bomb movement controllers, removes them in `finish()`, and records `FeralTalonOutVel` unless a native `FeralTalonLock` is active.
- `FeralTalonLockClient` watches the replicated `Workspace.FeralTalonLocks` entities. During the lock it sees anchored character roots and follows the native `TalonLockMath` release velocity; the lock's `EndAt` and `Done` values are owned by the game.
- Native `FeralTalonLetGo` binds Space / ButtonB and sends `FeralLunge:FireServer("release")` while the corresponding Talon lock release control is active.
- The Renaissance native recovery module preempted Rest for Cobra Kings Strike, crocodile Death Roll and regular bite inputs, but had no analogous dedicated Eagle Talon F / `FeralTalonPress` preemption. It could therefore issue/maintain `Rest(true)` during Eagle Talon contact. This is a credible hub-side conflict, **not** a demonstrated sole cause of every hover.
- The v13.5.5 Eagle catch assistant could issue an extra `FeralLunge("latch",...,"drag")` following a scratch, even during a native Talon lock. The cooldown helper also could write `FeralLungeReadyAt` during a live lock.
- The native lock may be server-controlled, and no local script can guarantee clearing a genuine server-side anchored/lock state.

## What changed in v13.5.7

Exactly two embedded modules changed compared to v13.5.6; other 21 modules are byte-for-byte identical.

1. **Native recovery** (`feral-nova-native-recovery-v13.5.7.lua`):
   - F-key Eagle Talon input releases **only hub-owned** Rest and passes through the native input at high priority.
   - Backup listener for native `FeralTalonPress`, covering HUD/controller activation.
   - Suppresses automatic Rest while Eagle `FeralTalonView`, `FeralTalonLock` or `FeralDiveLocal` is active, with a brief post-input hold.
   - Keeps the ordinary moving Rest signal/condition-rate measurements and five-second cadence, without suppressing recovery just because the Eagle is flying or walking.
   - Does not interfere with genuine manual Rest or force animation/physics changes.
2. **Eagle action assistant** (`feral-nova-eagle-actions-v13.5.7.lua`):
   - Does not send an extra scratch-to-drag `latch` request while the game's native TalonLock, TalonView or dive movement are active, or when a replicated clamp already exists.
   - Does not rewrite the local cooldown deadline while a native lock, dive or clamp exists.
   - Preserves the previously tested manual Elder/ordinary-prey catch assistance outside native locks and server response/replicated-hold verification.
   - Adds DATA report counters for native lock retry suppression, deadline suppression and prevention of duplicate latch while holding.

No automatic takeoff, no local root unanchoring, no teleport, no invented flight animation, no extra on-screen text.

## When stuck in the game

During a real server-backed Talon lock with the native release action available, tapping **Space** is the game's own `FeralTalonLetGo` binding. It may request release of a hold; that is not guaranteed to clear a broken server lock when no active native clamp exists. If you deliberately want to keep the target, be aware that Space can release it.

## Test interpretation

Use a normal Eagle in a low-risk scenario to compare whether the after-contact hovering recurs. Record whether there is an actual `FeralTalonLock`, `FeralClamp` or unresponsive flight after the target is reached. Success in GitHub CI does **not** establish game-server fixes. If the stuck behaviour continues without hub auto recovery enabled, the native Talon lock/flight state may be the underlying issue. Do not claim that the native server accepts modified cooldown, damage, or oversized catch merely because the script loads.

## Validation

[FERAL v13.5.7 compile and module preservation run](https://github.com/GSVexed/vexed-schematics/actions/runs/45049769781) — success. All 23 embedded modules compiled, only the two approved source modules differ.

Earlier native mechanics source review:
- [Eagle hover lock audit](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/45049362231)
- [Detailed TalonLock and DiveBomb audit](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/45049538102)
