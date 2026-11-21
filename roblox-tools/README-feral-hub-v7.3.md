# FERAL HUB v7.3 — restored native Rest signaling and reliable climbing

**Release:** 2026-11-21. **Game:** FERAL Animal Survival (PlaceId `108901361810209`). **Build:** `feral-hub-v7.3`.

## Quick launch for Potassium

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v7.3-potassium.lua"))()
```

This is a one-file, **19-module precompiled/offline hub**; no internal `game:HttpGet` is required after fetching the bundle. **Right Shift** toggles its UI and **End** closes it. Do not run older hub instances alongside it. Single-instance live deployment through the private Windows/Potassium bridge is preferred over stacking manual executions.

## Restored behavior and why

The previously observed FERAL Health Recovery **v1.1 Bear** trials had about **1% of max HP/s** without native Rest and about **2% of max HP/s** during certain out-of-combat mobile Rest-signal windows. Some venom/bleeding reductions were faster under the same experiment, but this was observational—not an unlimited server regeneration exploit. See `FERAL-HEALTH-FINDINGS-v1.1.md`.

v7.2 placed the native Rest request before installing its pose mask, stopped five-second Rest refresh requests, and permanently excluded the current character after repeated pose echoes. v7.3 restores the important older sequence:

1. Own-animal pose mask installed **before** the initial native `WolfActions:FireServer("Rest",true)`.
2. Event mask plus `BindToRenderStep` at priority **199** to run before the old observed game animation priority of approximately 202.
3. Native Rest request may be refreshed every **5 seconds** while the own animal is wounded or has supported positive status effects, instead of only twice after prolonged no-healing windows.
4. Out-of-combat-only request eligibility remains. Actual combat tags, held attack input, chat, carry escape and known unsafe states release the owned signal.
5. A repeatedly asserted visible pose triggers a bounded **15 / 30 / 60 / 120 second backoff** rather than permanent refusal until respawn. Stable operation for 90 seconds resets backoff escalation.
6. A synchronous Rest echo during `FireServer` cannot accidentally mark a cancelled signal active again. Disabling closes the owned request, render-step mask, and events.

**This is an implementation of a previously promising pathway, not a verified restoration of the old Eagle HP rate**. It has been compiled and regression-tested with a mocked Roblox runtime; actual game-server restoration still needs injured same-character observations. The source never writes actual `Humanoid.Health`, injury, venom, bleed, or Hunger/Thirst to fabricate gains.

## Other integrated improvements

- **Climbing:** Q input buffer length increased from 1.3 to **2.25 seconds**. The game’s native climb-tap pathway now allows **one guarded re-tap** when the first failed to mount while a climbable tree is ready. No fabricated server climbing remote or teleport.
- **Stamina:** Previous APEX / Endurance settings and `WolfDbgNoStamina` control retained. Source audit shows that both continuous flight stamina drain and burst `FeralFlyCost` check this same flag in `WolfController`. Client-side stamina behavior may work; server ability acceptance is a separate matter.
- **Eagle carrying and Talon cooldown:** Existing native event-aware bounded fallback and real hold/scratch/clamp accounting retained from v7.2. A local CATCH label, modified eligibility value or shortened local cooldown does **not** establish server approval of oversized prey or shorter real cooldown.
- **Flight / escape / growth / baby carry / anti-stuck:** Preserved from v7.2, without replacing these systems or stacking parallel managers.
- **Needs:** Added read-only Hunger and Thirst values to the existing private v7 session report. No bogus infinite needs or auto-feed feature has been added.

## Validation and live status (November 21, 2026)

- [Official Luau compile, all 19 embedded modules, source parity and mocked Rest lifecycle PASS](https://github.com/GSVexed/vexed-schematics/actions/runs/44921338015).
- [Pinned private Potassium deployment READY](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44921399627): reported 19/19 modules, **35/35 startup checks**, no startup errors, fresh local Potassium report.
- [Read-only post-deployment live observer PASS](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44921504844): exact active release `feral-hub-v7.3`, registered controller context, 16 closeable controllers, `WolfDbgNoStamina=true`. The character was at 935/935 HP at that time, so actual damaged healing could not be measured.
- Native server acceptance and gameplay outcomes were **not** inferred from compilation, client attribute changes, the startup UI, or successfully sending a RemoteEvent.

## Safe interpretation of results

Classify features separately as **source implemented**, **client startup confirmed**, **real own-character observation**, or **server-consistent gameplay effect observed**. Do not equate local edits with server-authoritative outcomes. Preserve the current live character and run no unnecessary forced-damage experiments. The existing private collector keeps reports sanitized to the user's own character and supports v7.3.

For original v7.1 multi-controller lifecycle details see the private `FERAL_V71_MCP_SINGLE_INSTANCE_HANDOFF.md`. All future updates should preserve the exact old-instance cleanup and 19 embedded modules unless a separate migration is justified.
