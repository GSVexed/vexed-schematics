# FERAL Eagle — incoming damage resistance source investigation

**Date:** 2026-11-22  
**Game:** FERAL Animal Survival (archived client version 2411)  
**Scope:** Read-only review of 464 reconstructed, privacy-redacted client scripts. **No public-server damage reduction or shield exploit established.**

## User-defined requirements

- Bald Eagle takes very little damage in combat before dying: seek **actual reductions in incoming HP loss**, not fake HUD values.
- No automatic flight takeoff and no automatic attack.
- Negative-effect recovery stops working on movement **even when not attacking**; investigate independently. The v13.5.6 five-second mobile Rest cadence and effect-rate observer are an experiment, not proof of resolution.
- Preserve Renaissance 23-module hub and earlier Eagle Carry/Talon improvements unless a change is validated.

## Defensive and trust-boundary findings

### Snapping Turtle shell

`CombatConfig.SHELL.SnappingTurtle={TAKEN=0.3,AFTER=1}` and `CombatConfig.shellMult(model)` return the Turtle damage multiplier only when it has `WolfRest=true` and has been resting longer than one second according to `WolfRestAt`. Thus the intended damage reduction is 70% after one second. In 464 client modules, there was no recovered client caller of `shellMult()` applying real incoming HP loss, and no `SetAttribute("WolfRestAt",...)` writer. A client-local `SHELL.Eagle` entry or fake Turtle species would not establish a replicated protection state. The native recovery module intentionally excludes Turtle auto-Rest to avoid shell/pose conflicts.

### Spawn safety

`CombatConfig.SPAWN_SAFE=45`, `HIT_ENDS_SAFE=true`, `REJOIN_SAFE_WINDOW=600`. `FeralCombatClient.canPredict` refuses local prediction when prey has `FeralSafeUntil` in the future or contains a `ForceField`; `CarryConfig.canCarry` similarly checks `FeralSafeUntil`. This documents safety state as a recipient-side check but **does not prove that editing the victim attribute on their own client changes the server**. No client setter of `FeralSafeUntil` exists in the archived corpus. No reusable safe-window RPC identified.

### New-player onboarding shield

`OnboardingConfig.V8` includes `SHIELD=0.7,SHIELD_SECONDS=420,SHIELD_FADE=30` and `RESPAWN_SHIELD=0.7,RESPAWN_SHIELD_SECONDS=20,RESPAWN_SHIELD_FADE=5`. Live onboarding record is version 14.1 with `shield=true,respawnShield=true`. The exact interpretation of the 0.7 strength must not be assumed without the server's implementation. The client sends `FeralOnbEvent` progress/UI notifications, but no observed client-side grant or restart-shield call; eligibility and protection magnitude appear server-dependent. `FeralOnbAdmin` user interface does not establish unrestricted admin access.

### Mixpacking damage change is not Eagle resistance

`UpdateLogConfig` states “Mix-packing damage reduction from 40% to 60%,” and another entry explains the rule: “ganging up on someone as different species gets less damage, less amber and no elder kill”. This is an **offensive** damage penalty applied to attackers exploiting cross-species packs, not a general damage-resistance ability for a defending Eagle. No client-authoritative damage application was found.

### Growth and vulnerability

- `Species.List.Eagle.health=70`.
- `GrowthConfig.ELDER_STATS=0.1`, `ELDER_STAT_KEYS.health=true`, and `Species.scaled("Eagle","health", growth)` multiplies health by `1+0.1*GrowthConfig.elder(growth)`. At 200% Elder growth, nominal full-growth health is around **77**, if server MaxHealth uses that shared scaling. This is at most an additional 10%, *not* a transferable shell resistance effect.
- The newer tier system adds size, not a demonstrated additional health or damage-resistance bonus.
- `CombatConfig.FLANK_MULT=1.25` suggests flanking increases damage dealt. Source shows no consumer applying this in the victim client; turning to face attacks can be a tactical improvement, but no local modifier swap makes a guaranteed HP reduction.
- `CombatConfig.FALL` config describes fall damage with `PER_STUD=2.5`, `MAX=100`; if game/server trusts actual landing speed, legitimate manual slow-landing physics could reduce some fall injuries, not bite damage. This remains an untested follow-up, not an installed feature.

## Authority findings and development guardrails

- A full 464-script scan found no client `Humanoid:TakeDamage`, `Humanoid.Health=` setter, or client setter of `FeralSafeUntil`, `WolfRestAt`, or onboarding shield in recovered scripts.
- `FeralCombatClient` estimates hit and kill effects and may play blood/flinch animations; these are predictions, not health awards. `WolfController` sends `WolfActions("BiteHit", ...)` and related native input messages; server-side damage acceptance is not visible.
- Local `Species.health`, `CombatConfig.SHELL`, `ForceField` or `FeralSafeUntil` spoofing is **not** established as server-accepted defence. Do not ship as a feature advertised to reduce damage.
- This investigation does not assert invincibility or server-authoritative damage reduction.
- No live damage-altering experiment or game mutation was performed.

## High-value next actions

1. Treat negative-effect **moving while not attacking** recovery as a separate issue requiring measured server-replicated venom/bleed/injury changes, rather than assuming changing the refresh interval fixes it.
2. For Eagle, improve protection by reducing exposure to secondary hits while preserving manual controls: verify native air/landing velocity and fall/injury mechanics first, then implement opt-in smooth descent **without automatic takeoff** only if warranted.
3. For combat, investigate native Eagle air-hit response and knockback/flinch recovery, with no assumption that animation suppresses HP loss. Preserve manual Talon, and retain the reliable real-clamp verification from v13.5.5.
4. If an actual server-accepted defensive shield grant route becomes available, verify against real MaxHealth-stable damage intervals with protected vs unprotected states before implementation.

## Reproducible offline source reviews

- [Full Eagle damage path audit](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/45048820052) — passed.
- [Pack, shield and safe-window audit](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/45048992224) — passed.
- [Protection activation audit](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/45049128849) — source scan passed.
- [Earlier Turtle shell trust audit](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/45048059720) — passed.
- Current experimental hub [v13.5.6 Eagle + mobile recovery](./README-feral-nova-v13.5.6-eagle-mobile-recovery-experimental.md) — separate from stable v13.5.3; no defensive damage toggle added.
