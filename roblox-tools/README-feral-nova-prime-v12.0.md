# FERAL NOVA PRIME v12 — native carry preserved, predator/victim separation

**Game:** FERAL Animal Survival · PlaceId `108901361810209`  
**Release:** November 19, 2026 · standalone, nine version-pinned modules.

## Recommended Velocity launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v12.0.lua"))()
```

The standalone launcher downloads once; the nine modules are bundled within the file and source-matched in CI. Previous v11 is preserved but no longer recommended.

## What's actually fixed

### FERAL has separate carry and capture states

Re-inspection of the archived **`FeralCarryClient` (source S0003938)** confirms:

- Native carry/drop binding is **G** (`ContextActionService:BindAction("FeralCarry", ... , CarryConfig.KEY)`).
- The game exposes `_G.FeralCarryCan()` and `_G.FeralCarryPress()` for its own carry prompt.
- When your animal is holding another animal, your character owns a **`FeralClamp` ObjectValue**. Its `Carry` flag identifies a carried target; its `Value` also denotes an active outgoing grapple. An attached carcass is marked by **`FeralCarcassCarry`**.
- The game's native press chooses `FeralWorld:FireServer("carry", target)`, `FeralWorld:FireServer("release")`, `FeralCarcassCarry:FireServer("pick", carcass)` or `FeralCarcassCarry:FireServer("drop")` depending on its current own state. These requests are produced by the **game's original client**, not fabricated by NOVA.
- Conversely, **`FeralCarried`**, **`FeralPinned`** and **`FeralDragged`** mark being carried/pinned/dragged **as a victim**. These are not the same as holding prey.

This distinction was missing from v9–v11's cross-feature decisions.

### New carry system

- A compact contextual **CARRY / PICK** or **DROP / RELEASE** control appears in the right-hand quick strip where the passive "TRACKED" count used to be.
- The button invokes the *native client carry helper* if accessible and currently eligible. Otherwise it attempts to send the normal G key using available executor input (or tells you to use **G** if injection is unavailable). It **never directly submits guessed or additional carry/drop remotes**.
- A **0.39-second cooldown** protects against double actions. The game itself enforces additional cooldowns and eligibility.
- Normal **G** continues to work; NOVA does not intercept, sink or override its Roblox key binding.
- The button automatically describes when your animal is holding another animal, holding a carcass or being held by an enemy. It cannot make an animal or carcass eligible for pickup if FERAL's server rejects it.

### Why other v11 features no longer obstruct carrying

- **Auto Escape v12** examines its **own outgoing** `FeralClamp` / carcass state before sending shake/getoff. If you are holding something and are not also pinned/carried, Auto Escape pauses, rather than confusing your grab with a victim escape.
- **Mobile Recovery v12** treats **G as native carry**, not an unknown attack. If it owns a `Rest=true` signal, it sends `Rest=false`, pauses its recovery comparison and **keeps the option enabled**; it can restart the baseline after the carry is released. The experimental recovery feature yields to your gameplay, not the reverse.
- **Safe Rest v12** won't start another Rest request while you're holding prey/carcass, and releases its own Rest request when you press G. A **user-clicked carry action** is delayed briefly after the Rest-off request before invoking the game's native carry helper.
- No module changes other players' `HumanoidRootPart.Size`, `CanCollide`, `CollisionGroup`, collision geometry, currency or health.

### Existing systems, without false claims

| Feature | v12 behaviour | Reality |
| --- | --- | --- |
| Auto Escape | Source-guided native shake, tug, carry-victim getoff, progress and release measurement | Does not promise instant escape against Tiger or every grab |
| Combat and bite guide | Read-only candidate targeting, nearby HP-change observations, and collision/raycast diagnostics | Never enlarges server hitboxes or guarantees extra reach |
| Mobile Recovery | Opt-in moving baseline vs Rest-signal vs after-signal comparison; stops or pauses on conflicting action | **Always-on 2× HP/4× effect recovery while fighting is not proven** |
| Safe Rest | Opt-in normal Rest under cautious conditions, including Turtle shell while stationary | Rest may inhibit bites; not a permanent buff |
| Endurance | One reversible local stamina profile switch | Server stamina authority is unverified |
| ESP | Outline-only visuals, close-camera projected nametags | Client visual changes |
| Agility and Clear View | Reversible local movement / display settings | Subject to server validation |

**Important:** The captured `WolfController` itself disallows ordinary bites while `WolfRest` is active and may restrict bites while you are actively carrying another animal. v12 can avoid fighting the native carry mechanic; it **cannot rewrite server-authoritative restrictions**. If the game forbids carrying and biting simultaneously, v12 does not bypass that rule.

## How to use v12

1. **Fully rejoin FERAL once** if you previously used v7/v8 HITBOX TEST. Their old local root-part enlargement may remain in an interrupted session.
2. Load the single-line v12 launcher above.
3. Approach a valid animal or carcass and press the game's **G**, or the new contextual **CARRY / PICK** control. If your carry is valid, the game decides whether to pick it up.
4. While holding prey, Auto Escape should report **CARRYING / ESCAPE NOT NEEDED** rather than sending `shake` or `getoff`. Mobile Recovery should report its carry-paused state rather than disabling carrying.
5. Press G or the **DROP / RELEASE** control when you want to release it.
6. Use **COPY STATUS** for the native carry state, helper/method, carry transitions, rest preemptions, capture-vs-predator classification and all other telemetry.

## Quality and regression verification

`.github/workflows/feral-nova-prime-v12-validate.yml` compiles the eleven dependent source files and validates the **single-download nine-module bundle** byte-for-byte. Official Luau tests cover:

- Holding prey vs holding carcass vs being carried/pinned/dragged.
- Game-native `_G.FeralCarryPress` dispatch, no duplicated helper call, input throttle, and proper shutdown.
- Owner's Rest-off request **before** invoking a native carry action.
- Mobile Rest-signal paused on G, kept enabled during carry, then restarted after release.
- Native escape requests suppressed while holding prey and allowed while the user is **actually pinned**.

All tests passed for the published revision. These are **simulations and source checks**, not live Roblox server validation. The GitHub connection does not provide direct access to the user's Windows desktop, Velocity executor or FERAL's private server.

## Source
- [v12 standalone bundle](feral-nova-prime-standalone-v12.0.lua)
- [v12 individual loader](feral-nova-prime-v12.0.lua)
- [native carry module](feral-nova-carry-v12.0.lua)
- [carry-aware escape](feral-nova-escape-v12.0.lua)
- [carry-safe mobile recovery](feral-nova-mobile-v12.0.lua)
- [carry-safe Rest controller](feral-nova-recovery-v12.0.lua)
- [v12 dashboard](feral-nova-prime-ui-v12.0.lua)
- [v12 tests](../.github/workflows/feral-nova-prime-v12-validate.yml)
