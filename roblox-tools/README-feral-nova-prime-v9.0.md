# FERAL NOVA PRIME v9.0 — combat-first reconstruction

This release replaces three features that were demonstrably not helping in live FERAL: the prior grab-response assumptions, automatic Rest during combat, and locally enlarged enemy hitboxes. It preserves the compact one-screen interface, single Endurance toggle, outline ESP with close-range screen tags, agility and clear view.

## Paste into Velocity while inside FERAL

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-v9.0.lua"))()
```

PlaceId: **108901361810209**.

## What changed and why

### 1. Tiger-grab escape: source-guided native actions

A user report showed 14 native requests and eight Space pulses yet an unacceptably slow tiger-grab escape.

Re-reading the recovered `FeralLungeUI` (source S0003647, from the archived November 2026 client) and `AbilityConfig` (S0000056) identifies an omitted action binding:

- `SHAKE_MASH=false` in that captured config, so the prey's keyboard escape is **directional `FeralShakeTaps`**, not necessarily Space's `FeralShakeMash` action.
- `SHAKE_MIN_GAP=.15`, `TUG_MIN_GAP=.10`, and carry `getoff` uses a **0.40-second** minimum.
- The captured UI sends `FeralLunge:FireServer("shake")` on a correct prey shake/tug, `"slip"` after the wrong direction, and `"getoff"` during a carry.
- The v6 detector checked `FeralShakeMash` and `FeralTugTap` but **not `FeralShakeTaps`**. It used .23 seconds for both tug and shake, leaving some valid opportunities unused.

v9 uses `FeralShakeTaps` and `FeralTugTap` as native grab-state clues, reads own `FeralPinned`, `FeralCarried`, `FeralClampN/Game`, `FeralShakeNeed` and `FeralShakeHave`, and sends only the relevant `shake` or `getoff` action at bounded intervals. It subscribes to the character's relevant attribute changes, samples current action bindings quickly, tracks replicated progress changes and observed release transitions, and falls back to key input only if no supported native action was identified. **The game server may still rate-limit or reject requests; this is not a guaranteed instant escape.**

### 2. Recovery blocking attacks — critical correction

Recovered `WolfController` source S0003620's normal `doBite()` refuses to start a bite when `Character:GetAttribute("WolfRest")` is active. The v8 Smart Recovery feature was ON by default and could request Rest whenever stationary and injured. This could block attacks at the worst possible moment; it is a plausible cause of a previous report showing zero registered bites, but that exact game incident cannot be proved retrospectively.

v9 changes the sixth control to **SAFE REST**, OFF by default. Passive shell/HP monitoring continues. When explicitly enabled, the controller waits for a living animal with damaged HP, at least three seconds stationary, five seconds without movement/attack input, seven seconds since damage, no visible nearby animal within 62 studs, no recent combat flag and sufficient hunger/thirst. It never sets `WolfRest` or Humanoid.Health directly. Owned native Rest is canceled immediately on mouse attack or WASD/Space input (with confirmation still dependent on server replication), movement or damage. The combat module separately counts attempted bites while the observed Rest flag remains true.

### 3. Turtle shell

The November client capture defines `SnappingTurtle` shell reduction as a client `TAKEN=.30` rule only while `WolfRest=true` and one second after `WolfRestAt`. V9 observes the requirement and reports **SHELL CONDITION MET**, not guaranteed 70% reduced server damage. It does not silently request Rest during a fight or spam speculative moving-rest probes. Rest may block your own bites, so aggressive auto-rest and unrestricted attacking are not compatible without additional live server evidence.

### 4. Hitboxes replaced with bite guidance

The user saw at least three locally enlarged roots, but **no reliable improvement in actual combat**. v9 removes the HITBOX TEST button and no longer resizes other players or modifies cached CombatConfig attack reach.

Instead, **BITE GUIDE** is ON by default. It computes the nearest locally eligible replicated enemy using the actual recovered `CombatConfig.bodyGap`, `REACH`, `SLACK`, `HIT_SCALE`, `CONE` and `MAX_DY` conditions used in `WolfController.biteClaimTarget`. A small unboxed 2D dot marks a client-valid bite candidate. The quick strip says BITE READY or AIM / CLOSE. The module records actual own `WolfBiteAt` changes, near-time target HP decreases and attempted attacks while Rest was active. It **never sends `BiteHit` remotes, enlarges local parts or claims server-confirmed damage**. The server may reject a candidate even when the client guide marks it READY.

### 5. Existing features kept

- Outline-only ESP and small, screen-projected animal labels (including very close camera fallback), from v8.
- One Endurance switch with previously developed local 3× recovery/no-drain settings, not a guaranteed server infinite-stamina effect.
- One combined Agility setting, brighter reversible visibility, Right Shift hide/reopen and full close/reset.
- Copy Status now includes **escape episodes, directional binding state, shake progress and release events; Safe Rest cancellations; blocked bite attempts; and actual native bite records**.

## What offline tests verify

GitHub Actions compiles the complete dependency tree with official Luau 0.747 and verifies wiring, lack of inappropriate health/Amber writes, no enemy part resizing and no unverified BiteHit requests. Additional executable Luau tests check:

- Directional `FeralShakeTaps` and `FeralTugTap` selection vs carry `getoff`.
- Multiple fast shake attempts, progress changes, release events and a subsequent carry escape in a simulated state.
- Safe Rest OFF by default; no Rest request while disabled; owned Rest canceled on mouse attack input.
- Turtle shell rule evaluation.

**Limits:** These are offline tests and can't demonstrate that the Roblox server honours escape attempts, that the visual bite guide predicts server damage, or that Rest increases health. The GitHub connection does not provide access to the user's live Windows/Velocity session or server-only code.

Source: [v9 loader](feral-nova-prime-v9.0.lua), [v9 escape](feral-nova-escape-v9.0.lua), [v9 combat](feral-nova-combat-v9.0.lua), [v9 recovery](feral-nova-recovery-v9.0.lua), [v9 UI](feral-nova-prime-ui-v9.0.lua), [v9 validation](../.github/workflows/feral-nova-prime-v9-validate.yml).
