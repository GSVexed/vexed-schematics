# FERAL HUB v1.0 — Potassium-ready offline release

**Game:** FERAL Animal Survival (PlaceId `108901361810209`)  
**Release file:** `roblox-tools/feral-hub-v1.0-potassium.lua`  
**Release intent:** A compatibility-hardened, fully self-contained presentation of the original v32 hub, not a claim of new server-authoritative gameplay.

## New name and continuity

The displayed name is **FERAL HUB**. Internally, the unchanged preserved v32 modules still use historical names (`FeralNovaPrimeV320`, `FERAL_NOVA_PRIME_ACTIVE`, and original report filenames). Do **not** rename these internals casually: the lifecycle and regression logic relies on them.

The new launcher is a single offline file and contains **all 19 v32 embedded modules byte-for-byte unchanged**. The startup wrapper adds compatibility checks and shows the first failed module or attachment. The old v32/v33/v34 releases remain available as rollback versions.

## Installing after obtaining an executor

1. Open FERAL Animal Survival in Roblox, and only use an executor you have independently verified and trust.
2. For the **most reliable offline startup**, open the complete `feral-hub-v1.0-potassium.lua` file in the executor's editor and execute it locally; it does not fetch any source via HTTP. Never disable Windows security protections to install an executor.
3. Inspect the **FERAL HUB** status panel. On success it says `READY` and then hides; press **Right Shift** for the main menu. On error the status panel remains visible.
4. Select **COPY STARTUP REPORT** to copy a structured report if `setclipboard` is available. If `writefile` is available, the same data is saved as `FERAL_HUB_STARTUP_v1.json`.
5. On rerun the existing v32 registry and shutdown logic closes the prior hub, preventing duplicate listeners.
6. Use the main UI's CLOSE/End controls to shut down normally.

If an HTTP loader is desired and supported, the verified hosted filename is:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v1.0-potassium.lua"))()
```

## What is preserved, not newly invented

- Endurance / local stamina configuration and guarded recovery logic.
- Existing one-button Active Recovery, native Rest coordination, status configuration and combat exclusion.
- ESP outlines, projected name/distance tags and adjustable viewing distance.
- Automatic hostile-grab escape and friendly same-species baby-carry exception.
- Quick Climb Q input buffering and native carrying.
- Agility, local combat/reach tuning, Clear View.
- Flight and underwater/surface coordination.
- Eagle Talon selected-target matching, one guarded drag attempt, replicated `FeralClamp` hold verification.
- Local cooldown-gate experiments and growth configuration experiments.
- Right Shift UI visibility and shutdown; periodic v32 session diagnostics.

See `README-feral-nova-prime-v32.0.md` for the old baseline's detailed limitations and full module inventory.

## Potassium compatibility improvements

- Check `loadstring` before trying to execute the embedded modules.
- Passively inspect optional executor APIs: `readfile`, `writefile`, `setclipboard`, `getgc`, `getconnections`, `hookfunction`, `decompile`, `getscriptbytecode`, and `Drawing`. Reporting support does **not** exercise intrusive capabilities or guarantee their correctness.
- Identify compilation failure by exact embedded module filename.
- Identify runtime failure and attachment stage separately.
- Save sanitized startup capability, module and timing records to `FERAL_HUB_STARTUP_v1.json` when possible.
- Keep the underlying v32 automatic `FERAL_NOVA_v32_session.json` report (approximately every 25 seconds where file writing works); the new wrapper does not send additional telemetry across the network.
- Preserve unmodified original 19 module strings for straightforward regression comparison.

## Actual limitations

**Faster server-accepted Elder growth, catching oversized animals, and reduced authoritative Talon cooldown have NOT been verified.** The baseline includes local growth configuration and local cooldown changes, but neither proves the game server accepted them. A displayed CATCH is not a proven carry; v32 only counts a matching replicated `FeralClamp` held target as an observed hold.

Passing Luau compilation and static preservation checks does not establish live Potassium execution, actual server acceptance, game-policy compliance or account safety.

The user has not yet purchased Potassium, and this release has not been runtime-tested there. Changes to the executor/Roblox client, account bans or unsafe installers remain risks.

## Regression and publication criteria

- [x] Publish a separately named release without overwriting historical versions.
- [x] Preserve all 19 original v32 module source strings exactly.
- [x] Provide a visible FERAL HUB-branded startup panel with failure details.
- [x] Preserve right Shift, original GUI identifiers, shutdown behavior and existing reports.
- [x] Provide optional local startup JSON and clipboard output.
- [ ] Confirm official Luau CI validation succeeds on the published file.
- [ ] Confirm successful startup in Potassium after it is obtained.
- [ ] Confirm each original feature in live gameplay rather than inferring server success.
- [ ] Verify the three primary gameplay goals on a live server.
