# FERAL NOVA v13.5.4 — Eagle Elder Talon experiment

**Status:** OFFLINE VALIDATED, LIVE SERVER ACCEPTANCE NOT PROVEN. This is a *separate experimental release*. Stable fallback remains v13.5.3. No automatic flight or auto-attack added.

## Launcher (Potassium)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v13.5.4-eagle-elder-experimental-potassium.lua"))()
```

## Why this exists

Read-only review of archived, privacy-redacted FERAL v2410 and v2411 client modules found:
- `AbilityConfigBase.Talon.CARRY_RATIO=1.45`, `NO_ELDER_LIFT=true`, `FLAT_COOLDOWN=60`.
- `NO_ELDER_LIFT` adjusts **attacker's own Elder size** in the Talon eligibility calculation; it is not itself a check of whether the *prey* is Elder.
- `FeralTalonView` labels CATCH/SCRATCH using a sexless-size ratio, while `WolfController` calls `AbilityConfig.grabMode`. These paths can disagree.
- Native UI sets several distinct deadlines via `SafeTime`; `FlightConfig.STOOP` contains `CD_EMPTY=10`, `CD_CANCEL=20`, `CD_PICK=60`. Rewriting local `FeralLungeReadyAt` can clash with native UI timing. The actual server cooldown may differ.
- `UpdateLogConfig` describes +2% size for each tier beyond 200% growth and up to +10% relative to a full Elder. Whether this is used by server Talon validation is unknown.
- The archived `Species.Eagle.health` base value is 70. The `CombatConfig.SHELL` defensive modifier is explicitly for Snapping Turtle; nothing reviewed establishes an Eagle-specific authoritative damage-reduction toggle.

## v13.5.4 changes (one module only)

Source: `feral-nova-eagle-actions-v13.5.4.lua` embedded under the inherited v12 Eagle module key, preserving all existing module references.

1. **Manual Elder prey follow-up:** After the user's own Talon action receives a native `bit` (scratch), the existing one-shot drag helper is now eligible for prey with `Growth>1`, including cases that the previous `ratio>1.45` filter would exclude. Still requires Eagle species, a native selected target, valid distance and local `AbilityConfig.grabMode("Talon",...)=="drag"`; no bypass of server eligibility is asserted.
2. **Bounded native request:** Retains existing no-spam delay (one attempt per at least five seconds), action priority, native attachment CFrame, and the original `FeralLunge` request shape.
3. **Observable real result:** Records Elder-target retries and counts an Elder-target success only when the own replicated `FeralClamp` matches the targeted prey; a generic `clamp` reply alone does not qualify.
4. **Cooldown conflict guard:** Stops repeated client deadline rewriting after two recent long native reassertions, preserves original deadlines for restoration, and resets the guard on toggle-off/respawn. This guards against one source of misleading grey HUD behaviour; it does **not** shorten server-controlled cooldown.
5. **Everything else preserved:** Recovery, stamina, Cobra combat and ESP, climb, escape, bite guidance, other animal features, UI and flight source are byte-for-byte unchanged from v13.5.3.

## Validation and limits

GitHub Actions: [v13.5.4 Luau compile and 23-module preservation checks](https://github.com/GSVexed/vexed-schematics/actions/runs/45047117201) — **passed**.

The Eagle request protocol and outcome correlation were inspected offline; actual public-server Elder catches and shorter cooldowns have **not** been demonstrated. A native `bit` or a local CATCH label is not proof of a carry. Test in a low-risk session with the Eagle's existing Carry Assist toggle on, noting actual `FeralClamp` and target retention. The cooldown gate toggle is optional and should be off if the game's long deadline reappears.

No automatic takeoff, no automatic attacks, no on-screen text overlay and no unverified invulnerability claim. If the experiment does not improve real carrying, return to v13.5.3 and treat the server validation as an unresolved barrier.
