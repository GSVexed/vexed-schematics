# FERAL NOVA PRIME v26 — Full Restored Hub + Automatic Diagnostics

**Release:** v26.0 · FERAL Animal Survival · Roblox place `108901361810209`

## One-line Velocity launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v26.0.lua"))()
```

**Deployment:** A single, self-contained Luau file with **17 embedded modules**. No additional module downloads are needed.

## Why v26 was built this way

v16–v24 lost major functions because they were reconstructed from a partial overlay. V25 restored the verified V15 implementation. V26 **retains 14 v15 feature modules byte-for-byte**, includes the v25 experimental mechanics module unchanged, and adds a standalone, always-on own-client diagnostics collector. Its UI is an extension of v25, not a wholesale replacement.

### Preserved features

| Feature | Source |
|---|---|
| Endurance (stamina no-drain attribute and client costs) | `feral-aurora-power-v14.0.lua` |
| Native guarded recovery / Rest signal | `feral-nova-native-recovery-v15.0.lua` |
| 2× health + 4× bleeding/venom/injury status config | `feral-nova-regen-v15.0.lua` |
| Player ESP outlines and nametags | `feral-aurora-engine-v13.0.lua` + `feral-nova-tags-v8.0.lua` |
| Hostile capture escape, friendly baby exceptions | `feral-nova-escape-v15.0.lua` + `feral-nova-baby-v15.0.lua` |
| Quick Climb Q buffering and carry / dive priority | `feral-nova-climb-v15.0.lua` |
| Water takeoff and carried prey flight cooperation | `feral-nova-flight-v15.0.lua` |
| Native G carry/drop | `feral-nova-carry-v15.0.lua` |
| Local bite reach and combat observations | `feral-nova-reach-v14.0.lua` + `feral-nova-combat-v15.0.lua` |
| Agility, Clear View and optional Safe Rest / Mobile A/B | Previously recovered core and v15 UI |
| Optional local Eagle growth/carry/cooldown trials | `feral-nova-mechanics-v25.0.lua` |
| **Automatic own-client telemetry** | **`feral-nova-diagnostics-v26.0.lua`** |
| Main UI with verified Right Shift and End buttons | `feral-nova-prime-ui-v26.0.lua` |

## Diagnostic collection: automatic, not automatic network transfer

From the moment the hub starts, the recorder samples local data approximately **twice per second**. The recorder records:

- Own character's species, health/max health, stamina/max, growth, exhaustion and no-drain state.
- Bleeding, venom and injury values, and their observed declines.
- Native Rest state, independent regen-config applied state, and observed health recovery in each mode.
- Enemy capture on own character, active outgoing `FeralClamp`, and transition counts.
- Numeric native `FeralClimbTap` writes and Q/G/Mouse1/Space input counts.
- Talon cooldown deadlines, total duration and remaining locally observed seconds.
- Your existing Endurance, ESP, Quick Climb, baby-carry and three optional mechanic toggle states.
- Aggregated health/stamina/growth changes and observed health/status rates per mode.

The rolling report retains up to **720 recent samples** (approximately six minutes) and **180 recent state changes**. Lifetime aggregates persist in memory until the hub is shut down.

**Privacy:** The recorder does not include names, UserIds, chat content, coordinates, server invite links, passwords, executor identity or other users' details. **It does not send HTTP requests to upload reports.**

### Automatic local save

When the executor exposes the `writefile` API, v26 automatically saves an updated JSON report around every **25 seconds** to:

`FERAL_NOVA_v26_session.json`

This is a file in your executor's workspace (its exact Windows folder varies by executor). The file is also updated during a normal hub shutdown. Re-running the hub overwrites the same session filename; upload it before starting a new run if you want to keep the previous session.

If `writefile` is unsupported, in-memory diagnostics still run and **COPY DIAG** works where the executor supports clipboard copying.

### How to give ChatGPT the results

After testing, attach the generated `FERAL_NOVA_v26_session.json` file to this chat. Alternatively click **COPY DIAG** and paste the copied text here.

The ChatGPT assistant cannot automatically open a file in the executor's local Windows directory. A secure, explicitly configured sync destination would be required for direct autonomous delivery; none is installed by this script. Do not paste a GitHub personal access token into Roblox or Velocity.

### UI and shutdown

- **Right Shift:** hide/show menu.
- **CLOSE:** full shutdown with module cleanup and diagnostics export.
- **End:** full shutdown shortcut.
- **✦ NOVA:** reveal a hidden menu.
- **AUTO FILE:** enable/disable periodic JSON saving, where supported.
- **SAVE DIAG:** immediately export full JSON report to the executor file.
- **COPY DIAG:** copy a bounded human-readable diagnostic summary.
- **COPY STATUS:** old combined v15 module status, plus the new diagnostic summary.

## A/B evidence plan

For the three **newest experimental features** (Growth, Eagle carry and Talon cooldown), use a controlled baseline with all three off, then enable only one at a time. Measure actual gameplay results rather than merely whether the toggle or locally edited table shows ON.

- **Growth:** compare progress over equal play time and check after a respawn; don't equate a cosmetic size or local number with server-recognized Elder age.
- **Talon carry:** compare actual outgoing clamp/carry behavior, not merely the label CATCH/SCRATCH.
- **Cooldown:** compare observed lunge deadlines and genuinely permitted subsequent actions; a shortened display is not proof of server accepted combat.
- **Endurance / regen:** compare actual health/stamina changes during similar movement and recoveries with Native Rest and Regen configurations independently toggled. The recorder classifies `neither`, `config_only`, `native_only`, `native_plus_config`.

The original v15 state remains available as a rollback at `feral-nova-prime-standalone-v15.0.lua`.

## Validation and limitations

The source preservation audit confirmed:

- 17 modules embedded.
- 14 pre-existing v15 non-UI modules identical to original v15.
- v25 mechanics source embedded unchanged.
- New UI/diagnostic sources match their corresponding standalone bundles.
- Key reporting, menu shortcut and module-cleanup source paths present.

The workflow `.github/workflows/feral-nova-prime-v26-validate.yml` adds official Luau 0.747 compilation, source equality checks, privacy invariants and mocked own-character autosave/copy tests. **GitHub Actions confirmed PASS:** run [#1 (44617114632)](https://github.com/GSVexed/vexed-schematics/actions/runs/44617114632) completed successfully on 19 November 2026, including official Luau compilation, exact module preservation/privacy checks, and mocked telemetry sampling, export and cleanup. **This is not a live FERAL gameplay test.** The actual public game's server acceptance of altered growth, catches, cooldowns and extended bite damage has not been verified.
