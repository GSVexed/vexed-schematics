# FERAL HUB v2.0 — Refined Offline Potassium Preparation

**Status:** Published, static preservation verified; **live Potassium and Roblox testing outstanding**.  
**Game:** FERAL Animal Survival, Roblox PlaceId `108901361810209`.  
**Distribution:** `roblox-tools/feral-hub-v2.0-potassium.lua`; self-contained offline Luau source.

## What's new compared with FERAL HUB v1

1. **Native interface revision:** `feral-hub-ui-v2.0.lua` replaces the bundled v32 UI. The 18 remaining module sources are unchanged byte-for-byte.
2. **FERAL HUB branding:** Original legacy internal GUI/registry identities remain for backwards-compatible shutdown and stale-instance management. Visible header, compact reopen control and subtitle now say FERAL HUB.
3. **Live in-hub guide:** HELP in the header opens a persistent guide explaining client-only settings, actual Eagle carry observation, cooldown/growth uncertainty and shortcuts. It also includes **COPY BOOT REPORT** and **COPY SESSION**; this remains usable after the boot overlay closes.
4. **Complete local reset:** RESET now explicitly disables Endurance, Agility and Clear View before the prior cleanup sequence. Previously it did not explicitly deactivate all three.
5. **Startup preflight:** A small compiled Luau function is executed as a smoke test; if both file read/write APIs exist, a startup JSON round-trip is attempted. Startup phases are saved as they change and error messages name the failing module.
6. **Automatic own-character sampling:** Every 20 seconds a bounded, opt-in-free passive report records own observed species, Growth, health, stamina, recovery mode, escape/climb/flight status and native Talon result counters. When supported, local storage is `FERAL_HUB_SESSION_v2.json`; a separate `FERAL_HUB_STARTUP_v2.json` captures startup and API availability. The existing `FERAL_NOVA_v32_session.json` report remains intact.
7. **Lifecycle:** Added a one-time cleanup guard and monitor disconnect on shutdown; the original v32 active-registry and module close behaviour remains.

## Verification

The source was checked against the published v1 bundle: all 19 embedded module slots remain, and the **only changed embedded source is the UI**. The revised embedded UI matches `feral-hub-ui-v2.0.lua` exactly.

GitHub Actions workflow: `.github/workflows/feral-hub-v2-validate.yml` checks official Luau compilation, exact 18-module preservation, full source inclusion, controls, reporting, and shutdown hooks. A workflow file being present does not mean CI completed: inspect Actions before claiming it passed.

## How to launch

Recommended **offline path:** open the entire raw contents of `feral-hub-v2.0-potassium.lua` locally in your trusted Luau executor and run, avoiding the Roblox `HttpGet` dependency.

Optional **short launcher** (requires supported outbound HTTP in the executor):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v2.0-potassium.lua"))()
```

After startup: **Right Shift** hides/shows; **HELP** opens the guide, including copyable startup/session reports; **CLOSE** or **End** initiates shutdown. **RESET** disables local features while keeping the UI running.

## Preserved feature list

- Endurance / local stamina tuning;
- unified guarded Active Recovery, healing/status configuration and safe action coordination;
- hostile-grab automatic escape with friendly baby-carry handling;
- native Q-buffered Quick Climb; native G carry and carry state;
- ESP outlines, projected nametags and distances, adjustable wall/range settings;
- local combat/reach and agility settings, clear-view fog changes;
- water surface flight coordination and underwater flight exit;
- Eagle native selected-prey carry assistant, actual matching replicated `FeralClamp` hold detection, local Talon gate experiments, growth configuration experiments;
- prior v32 automatic private diagnostics and lifecycle controls.

See `README-feral-nova-prime-v32.0.md` for limits and original implementation details.

## Limits, security, and follow-up

**Do not claim these are solved:** accelerated server-authoritative Elder progression, oversized Eagle carry acceptance, shorter server-enforced Talon cooldown. Changing client settings or sending a native request does not establish these outcomes. The output explicitly labels local observations and confirmed replicated matching holds.

No additional external telemetry endpoint is included; new reports are local only. The unchanged v32 diagnostic module retains its previously documented private runner sync behaviour when configured. The build does not attempt to evade Roblox detection or grant server authority. Using client-modifying executors carries ban and malware risks.

**Still to validate in Potassium:** Luau compilation/execution, startup and reload, GUI rendering/scaling and HELP panel, every gameplay toggle, respawn and session close, data export, and live three-goal outcomes. If Potassium identifies an incompatibility, use the startup JSON and FERAL HUB v1 or the original v32/v34 files as rollback choices.
