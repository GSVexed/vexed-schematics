# FERAL HUB v3.0 — Pre-Potassium Engineering Release

**Game:** FERAL Animal Survival (Roblox PlaceId 108901361810209)  
**Main file:** `roblox-tools/feral-hub-v3.0-potassium.lua`  
**UI source:** `roblox-tools/feral-hub-ui-v3.0.lua`  
**Status:** Published, source-level regression checks executed; live Potassium validation outstanding.

## What v3 actually improves

1. **All-module preflight before teardown.** The script compiles each of its 19 bundled modules *before* closing an earlier hub or removing an older interface. If compilation fails, the startup overlay displays the offending module and the previous hub is not deliberately shut down by this release.
2. **Zero module drift.** The 18 original v32 gameplay module strings remain exactly equal to the published v2/v32 baselines. Only the FERAL HUB UI module is revised.
3. **Mandatory runtime health check.** Startup runs 24 read-only checks: 19 compiled, 19 executed, basic Luau execution, UI presence, session monitor, shutdown and UI refresh functions, and 17 controller objects. A failure is reported as `DEGRADED`, never silently marked READY.
4. **User-triggered self-check.** Open HELP and select RUN SELF-CHECK to repeat the same check and view its pass/fail count.
5. **Safer UI interaction.** UI button handlers are protected so an individual callback error is logged to the console instead of silently stopping unrelated UI work.
6. **Lower inactive overhead.** The original UI stops refreshing decorative and data labels when the full menu is hidden, and refreshes immediately when shown.
7. **Complete local RESET.** Retains v2 corrections that disable Endurance, Agility and Clear View in addition to original feature controllers.
8. **Report continuity.** Structured startup information is kept in `FERAL_HUB_STARTUP_v3.json` where file writing works. A bounded passive own-animal report (`FERAL_HUB_SESSION_v3.json`, 20-second sampling, max 180 samples) tracks observable health, stamina, Growth, recovery/escape/climb/flight and Eagle result counters. The older v32 session recorder remains intact.
9. **Preserved lifecycle.** Close/End cleans up previous module connections and stops the new session monitor. Original internal GUI and registry identifiers intentionally remain unchanged.

## Short launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v3.0-potassium.lua"))()
```

For the most reliable startup when Potassium is acquired, open the entire `feral-hub-v3.0-potassium.lua` file locally in its editor. This avoids a dependency on executor HTTP support.

## Controls

- **Right Shift:** show or hide FERAL HUB.
- **HELP:** read feature limitations and access startup/session reports and RUN SELF-CHECK.
- **RESET:** request all local feature switches off and reset local controls; rejoin the game if old Roblox state persists.
- **CLOSE** or **End:** shutdown and stop session reporting.
- **SAVE DIAG / COPY DIAG / COPY STATUS:** preserved v32 reporting functionality.

## Preserved subsystems

Endurance and local stamina settings; active recovery and guarded native Rest coordination; ESP and player tags; automatic hostile-grab escape and friendly baby-carry safeguards; native Q-buffered Quick Climb and G carry; agility and client reach settings; local Clear View; water-surface flight and underwater exit coordination; Eagle target selection, one bounded native drag request, replicated matching FeralClamp hold observation; Talon cooldown local gate experiment; local growth configuration experiment; v32 diagnostics and legacy rollback versions.

## Verification matrix

| Test | Status |
|---|---|
| 19 embedded module names and source presence | Independently source-checked |
| 18 gameplay modules unchanged | Independently byte-for-byte source-checked |
| v3 UI exactly matches embedded UI | Independently source-checked |
| Precompilation before existing-hub shutdown | Source-checked |
| Default UI controls and local RESET | Source-checked |
| Offline build has no `game:HttpGet` call | Source-checked |
| Official Luau compilation of release + each module | GitHub Actions workflow prepared; passing run not independently confirmed |
| Mocked Luau 24/24 self-check pass and 23/24 failure cases | GitHub Actions workflow prepared; passing run not independently confirmed |
| Actual Potassium compatibility / module performance | Not yet tested |
| Gameplay outcomes on a live FERAL server | Not yet tested |

CI workflow: `.github/workflows/feral-hub-v3-validate.yml`. Do not claim a successful CI run merely because the workflow file exists.

## Important limits

Faster *server-recognised* Eagle Elder growth, carrying targets prohibited by the server, and shorter authoritative Talon cooldowns are **not proven**. A local CATCH indicator or edited attributes are not sufficient evidence. The earlier v32 module only marks an observed carry when a matching replicated `FeralClamp` actually holds the selected prey; even that is evidence of what the client observed, not a copy of private server logic.

Potassium is third-party client-modifying software. We have not tested it on this PC and cannot promise account safety, security, detection avoidance, or uninterrupted operation. Do not disable Windows security protections to install it.

## Live acceptance protocol

1. Confirm the standalone displays `READY` and 24/24 self-check; if not, copy the startup report.
2. Test Right Shift, HELP, RESET, CLOSE, and a single reload, then verify no duplicate menu remains.
3. Test features one at a time after respawning and note any conflicts between recovery, escape, climbing, flying and carrying.
4. Observe actual growth and health/stamina attributes, successful sustained replicated Eagle holds, and whether a second Talon action is genuinely accepted.
5. If any test fails, preserve the error report and roll back to v2 or offline v34 while the code is corrected.

**Engineering definition of 'ready':** Published and statically verified preparation is not the same thing as a live-tested working Potassium release. Never mark the latter without direct evidence.