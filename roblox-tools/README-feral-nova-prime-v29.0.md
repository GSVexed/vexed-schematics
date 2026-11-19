# FERAL NOVA PRIME v29 — Unified Active Recovery

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v29.0.lua"))()
```

## What changed

The public standalone has **18 Luau modules**. It is based on v28 and retains **13 byte-for-byte unchanged v15 systems**, including Endurance, ESP, Q climbing, hostile auto-escape, same-species baby carrying, native G carry and bite reach. It retains v28 water-surface takeoff, native underwater flight-drop checks, and experimental Elder Growth/Eagle carry/Talon cooldown controls.

### ONE Active Recovery switch

The v28 UI exposed competing controls: **ACTIVE RECOVERY**, **SAFE REST**, an additional **REGEN 2x/4x** toggle, and A/B Mobile trials. This confused which mechanism was actually healing and could cause conflicts. v29 has **one user-facing ACTIVE RECOVERY** switch plus a read-only **RECOVERY STATUS** button. It coordinates:

- The existing native Rest signal that was previously associated with useful health gain while moving outside combat.
- The cached 2× health and 4× HEAL/CLOT/FADE status-effect configuration.
- Safe action handoff during carrying, climbing, flying, attacks and combat.

The legacy Safe Rest and Mobile trial module source is preserved for rollback and diagnostics but not exposed as additional recovery toggles.

### Rest-pose safety

The v15 native recovery module requested `WolfActions:FireServer("Rest", true)` and resent this every five seconds while masking `WolfRest`. v29 **removes periodic repeat requests**. If the game continues forcing `WolfRest=true`, it pauses native recovery for ten seconds; repeated pose conflicts suppress further native Rest for that character until respawn. When suppressed, the health/status local configuration remains on, but the native Rest health benefit may be reduced. This is a safety tradeoff rather than an assertion that visible resting will never occur.

### Bleed/venom/injury ×4

The recovered client StatusConfig already uses `REST_MULT=4` for these effects; v29 preserves this rather than indiscriminately increasing it again. The locally cached `HEAL`, `CLOT`, and `FADE` inputs are still changed where available. Whether the public game server actually uses these changes for active effects is *unverified*. No direct changes are made to player effect attributes.

### Combat healing priority

The prior Regen module changed `NeedsConfig.HEALTH_NO_REGEN_IN_COMBAT` to `false`, which was contrary to the requirement to stop boosted healing during combat. v29 preserves the game-provided value instead.

### Eagle features

Growth, larger Talon catches and shortened cooldown remain experimental local config adjustments. The v26 private diagnostics recorded both approximately 1.5-second and 60-second cooldowns, showing that the local adjustment does **not** by itself prove that an earlier server-accepted Catch is possible. v29 adds diagnostics of own `FeralTalonPress`, `FeralTalonPending` and outgoing `FeralClamp` events, keeping button state separate from gameplay results. No false server-authority claim is made.

## Controls

- Right Shift to toggle hub visibility.
- CLOSE or End to shut down, restoring locally modified configurations and releasing owned Rest signals.
- One ACTIVE RECOVERY toggle, one RECOVERY STATUS readout.
- SURFACE FLY, ESP, Q Quick Climb, BABY CARRY, ENDURANCE and other previously preserved controls.
- Three separately controlled Eagle experiments and presets.
- Autosave/COPY DIAG/SAVE DIAG report tools.

## Automatically collected private reports

The local Velocity report is `FERAL_NOVA_v29_session.json`, saved approximately every 25 seconds where `writefile` is supported. The established Windows self-hosted runner's private collector supports `FERAL_NOVA_DIAG_V29` and synchronizes the validated JSON into `GSVexed/chatgpt-minecraft-testlab/diagnostics/feral-nova/latest.json`. The collector does not send data to the public hub repository or automatically post messages into ChatGPT.

v29 adds recovery pose safety state and native Talon press/pending observables to the existing growth, stamina, HP, status, flight and cooldown rollups.

## Tests

GitHub Actions run [44635404893](https://github.com/GSVexed/vexed-schematics/actions/runs/44635404893) passed official Luau compilation, 18-module integrity, 29-feature manifest preservation, simulated native water behavior, diagnostics, Eagle local-field rollback, unified Active Recovery coordination and preservation of the combat-healing exclusion. These are **offline tests**, not live public-server evidence.

### Known limitations

- Native Rest may still briefly show a pose before the guard reacts; suppressing the native request entirely may also remove the observed moving-health benefit.
- The client-configured status decay multiplier is not guaranteed to change replicated injury, bleeding or venom.
- The game server may reject larger catches, early cooldowns and accelerated Elder growth despite the local Eagle experiment toggles.
- Rejoin once when upgrading from pre-v28 scripts that might have leftover old background loops.
