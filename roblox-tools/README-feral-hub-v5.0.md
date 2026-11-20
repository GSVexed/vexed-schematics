# FERAL HUB v5.0 — Live-Evidence Engineering Update

**Release:** `roblox-tools/feral-hub-v5.0-potassium.lua`  
**Official Luau + regression CI:** https://github.com/GSVexed/vexed-schematics/actions/runs/44728989690 — **SUCCESS**  
**Automated private Potassium collector:** `GSVexed/chatgpt-minecraft-testlab/.github/workflows/feral-potassium-v5-private-collector.yml` — Windows runner fixture tests **SUCCESS**.

## Execute

Enter FERAL Animal Survival (PlaceId 108901361810209) with Potassium active and execute:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v5.0-potassium.lua"))()
```

The shipped file is offline and contains all 19 compiled modules; only this optional one-line launcher fetches it. For executor versions without HttpGet support, open the whole `.lua` file directly.

## What the first live v4 Potassium session established

- 19/19 modules compiled/loaded, runtime self-check 24/24, no logged startup error.
- ~13 minutes 20 seconds of own Eagle snapshots; one native Clamp reply and a separate locally observed hold, but **zero matching assisted-hold observations**. Those findings are not contradictory once independent physical holds are distinguished from assisted matches.
- Growth-on about 0.066/min over 729 seconds vs growth-off about 0.050/min over only 16 seconds. The control period was far too short to infer acceleration.
- Active Recovery mode stayed `WAITING_FOR_SAFE_WINDOW`, including frequent flight/climb states; the older summary did not expose native pause reasons.
- Cooldown measurements frequently showed a local ~1.5 s total, while the session's Player-only deadline field was absent. Neither proves server acceptance of a 1.5 s Talon cooldown.

## v5 actual changes

1. **Eagle hold accounting.** Count all physical FeralClamp holds in a separate counter, whether or not the recent assisted-target window matches. Record locally computed prey-size ratio and classify only as a *client estimate*; match server Clamp event timing where possible. Preserve the exact-target requirement to attribute an assisted carry. Allow a bounded extension when the server Clamp reply precedes delayed replication. Never claim a local hold proves the server would accept oversized prey.
2. **Growth trial quality.** Partition the existing replicated Eagle Growth attribute into ON/OFF evidence, distinguishing young from elder stage and excluding across-respawn/negative jumps, invalid samples and mode transitions. Require **120 s and 60 samples in each same-stage group** before showing a balanced on/off comparison. No writing of Growth attribute and no claim of causal speedup.
3. **Recovery reasons.** Keep pre-existing movement/attack/flight/climb/carry safety. Report `NO_RECOVERY_NEEDED`, `PAUSED_FOR_ACTION`, `WAITING_FOR_SAFE_WINDOW`, `NATIVE_RECOVERY`, and guarded pose states separately, with the native reason and wounded-blocked time.
4. **Talon diagnostic source.** Session samples attempt to read FeralLungeReadyAt from Player or character and record which source was present, plus the displayed `FeralLungeCdTotal` if available. The local gate experiment is not presented as server-authoritative.
5. **New diagnostics.** Session sampling interval reduced to 10 s (max 360 samples, saving around every 20 s). The existing `FERAL_NOVA_v32_session.json` format remains compatible while including v5 physical-hold, stage-matched-growth and recovery metrics. A dedicated private runner collector handles the new v5 startup/session filenames and sanitises contents before upload.
6. **Interface.** Top Eagle status now distinguishes `PHYSICAL` vs `ASSISTED MATCH`; insufficient Growth control time appears as a warning; recovery button labels the action blocker; HELP includes the expanded three-goal report.

Exactly five embedded modules differ from v4: Eagle, Mechanics, Active Recovery, Diagnostics and UI. The other 14 embedded modules are unchanged.

## Verified engineering checks

- Full standalone source compiled with the official Luau compiler, as did each of its 19 embedded modules.
- Exactly five modified modules match their standalone GitHub sources. Fourteen other modules are identical to v4.
- Mocked Eagle test checked late target assignment, local ratio classification, immediate hold observation, delayed matching window, unrelated later hold separation, and cooldown restoration.
- Mocked Growth test checked young-Eagle ON/OFF sampling, insufficient control data, balanced controls after minimum exposures, and local config restoration.
- Mocked Active Recovery test checked full-health classification, action blocking, wounded waiting, native mode, and closure.
- The private collector test verifies synthetic reports are read/filtered without leaking fixture secrets; Windows GitHub runner execution succeeded.

CI success is not live game validation; v5 itself has not yet been executed in Potassium. The three server-controlled goals remain **UNVERIFIED**.

## Controls and rollback

**Right Shift** toggles UI. **HELP > RUN SELF-CHECK** should report **28/28** in v5; **COPY THREE GOALS** exports detailed outcomes. **RESET** requests local feature shutdown. **End / CLOSE** stops the hub and local monitoring.

Previous live-tested baseline: [FERAL HUB v4.0](feral-hub-v4.0-potassium.lua). If the v5 startup self-check fails, capture its `FERAL_HUB_STARTUP_v5.json` or COPY BOOT REPORT and return to v4 for comparison.

## Automatic private diagnostics

Potassium file APIs save `FERAL_HUB_STARTUP_v5.json`, `FERAL_HUB_SESSION_v5.json`, and `FERAL_NOVA_v32_session.json`. The private Windows GitHub Actions workflow checks the known workspace paths approximately every five minutes, validates report schemas, and publishes an allowlisted, sanitised summary to `diagnostics/feral-potassium/latest-v5.json` in the PRIVATE testlab repository.

The collector does not send credentials, licences, chat, identities, filesystem contents or game code. The assistant can **retrieve this file when prompted in a chat**, not monitor it autonomously without an explicit automation. Initially the collector correctly reports `NO_V5_REPORT_FOUND` until v5 is executed and files become available.

**Account notice:** Potassium is a third-party client-modifying executor. We cannot guarantee compliance with Roblox rules, detection avoidance, account safety or freedom from malicious software.