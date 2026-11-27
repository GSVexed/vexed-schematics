# FERAL Renaissance 16.4.0-rc1

Published 27 November 2026 on `renaissance/v2415-16.4.0-rc1`. This candidate repairs build-2415 compatibility and the desktop Hold-to-Bite protocol while retaining the complete 16.3.2 feature set. The Windows helper is installed and running in the existing interactive session, with its previous executable saved for rollback.

The published candidate passes **230/230 Luau tests**, Windows compilation, input ABI checks and **10,000 helper interruption/recovery cycles**. These establish compilation and simulated behavior. The passive live-client probes returned no confirmed executor receipt, so real combat, server stamina and other live gameplay outcomes remain unverified. The candidate has not been activated automatically in Roblox.

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/60e703742efdec8950f69f9ce715f720604f35d3/roblox-tools/feral-renaissance-v16.4.0-rc1-loader.lua"))()
```

Execute this in FERAL using the existing executor. The launcher enables the desktop left-mouse Hold-to-Bite route. Right Shift opens or closes the hub and linked Territory panel. The helper pause shortcut is Ctrl+Alt+F12.

A long left-mouse hold uses the existing .18-second threshold. After a hard interruption such as focus loss, a menu, death or respawn, release the button and press again. Temporary protected interactions pause repetition and require a fresh ready sample before resuming. Generated combat clicks remain guarded against recognized Eat/Drink controls. If the current executor cannot supply a safe paired-input backend, the route pauses and reports the limitation.

The helper has no boot/logon trigger. After a Windows restart, its existing on-demand task can be started in PowerShell:

```powershell
Start-ScheduledTask -TaskName 'FERAL Left Hold Bridge (on demand)'
```

Existing settings and earlier pinned releases remain available. This launcher explicitly enables Hold to Repeat Bites; the feature can still be disabled in the hub.

## Changes

| Area | Result |
|---|---|
| Source recovery | Recovered all 29 modules from the complete 16.3.2 bundle rather than the older editable 15.7 tree. Preserved all 28 registered features and 12 integrated Territory modules. |
| Build checks | Accounted for all 19 legacy checks. Added centralized capabilities; compiler-specific layouts remain limited to audited 2412/2415 builds with current runtime identity/type checks. |
| Desktop Hold-to-Bite | Added separate input-session epochs, hard revocation at lifecycle boundaries, helper-instance restart handling and replayed-sequence rejection. A restarted helper no longer remains permanently below the previous sequence. |
| Protected interactions | Added native wrestling and actual open nest/stronghold panel ownership. A persistent nest/stronghold phase with its panel closed cannot block combat. Title/map menus revoke the captured press. Existing GrabV2 arbitration and Eat/Drink click guards remain. |
| Temporary recovery | Requires stable readiness and a newer positive helper sample after an interruption. The Lua and Windows sides both exercise their real state logic in tests. |
| Bite timing | Admits audited 2415 native bite/feed interfaces and removes double application of adaptive cadence scaling. Preserves native positive-damage feedback requirements and governor limits. |
| Hippo | Re-enables checked native finish, movement and profile paths on 2415. Retains server fatigue, native sprint denial and current ability restrictions. |
| Stamina | Preserves existing local consumption leases and exact native restoration. Skips the ineffective live debug flag on 2415 and reports partial support explicitly. |
| Territory | Retains the integrated modules and restores the checked current gait interface. No claim of completed live journeys. |
| Windows helper | Uses the same hold-state implementation in production and self-tests, adds instance IDs and verifies foreground HWND/PID. Installer saves and hashes the previous executable; rollback checks the saved hash and task path. |
| Diagnostics | Handles an unavailable diagnostic task-spawn facility without crashing. Adds complete feature, compatibility, release and verification reports. |
| Packaging | Adds deterministic source/manifest/chunks, immutable loader pins and six full/chunk/network/integrity failure cases. Existing production and pinned loaders were preserved. |

Twenty-two recovered modules are byte-for-byte unchanged. Seven receive focused repairs, and one compatibility module is added. Module hashes and recovery evidence are in [source-recovery.json](source-recovery.json) and [the manifest](../manifest.json).

## Stamina finding

`NeedsConfig` is unchanged from build 2412. The significant update is in `WolfController`: `WolfDbgNoStamina` is now honored only in Studio, while live movement reads `FeralSrvTired`. Additional Lion/pride ability consumption also exists.

The candidate retains local sprint, jump, swim, climb, flight and venom drain controls. It does not write current stamina, maximum stamina, server fatigue or ability-cost attributes. **Unlimited server-recognized stamina has not been demonstrated**, and the hub labels the feature as partial client support. The release does not present local drain edits as proof that the server accepts unlimited resources.

The game also changes VenomConfig balance and flight tuning. Those native timing, immunity, recovery, drag and turn-rate values are retained. The detailed evidence is in [INVESTIGATION.md](INVESTIGATION.md); all 29 priority modules, 505 normalized paths and 19 guard decisions are in [compatibility.json](compatibility.json).

## Preserved behavior and scope

The complete feature list is in [FEATURE_MATRIX.md](FEATURE_MATRIX.md). Active Recovery, fast negative-effect recovery, Bite Reach, existing GrabV2 automation, camera/zoom, outlines/names, voice rolloff extension, movement assistance, saved settings, Territory and cleanup remain present. Their presence and offline checks do not establish current live effectiveness.

New wrestling interactions remain manual and protected from repeat bites. No Elder credit-cap experiment, fabricated damage confirmation, extra Bite/BiteHit traffic, new bytecode collection or private server-code access was added. The earlier experimental one-shot path remains disabled on 2415. Unknown future builds do not automatically gain admission to the audited private layouts.

## Verification

| Check | Observed result | Receipt |
|---|---|---|
| Candidate Linux gate | 230 passed, 0 failed; all modules, bundle and loader compile; deterministic bundle/manifest/chunks | [Run 46062065173](https://github.com/GSVexed/vexed-schematics/actions/runs/46062065173) |
| Candidate Windows gate | Actual helper compiles; ABI, tap/hold, pause, revocation and 10,000 transitions pass; installer/rollback parse | [Same run, helper job](https://github.com/GSVexed/vexed-schematics/actions/runs/46062065173/job/140718449944) |
| Retained Renaissance 15.7 gate | Original 202 cases pass unchanged | [Run 46062065218](https://github.com/GSVexed/vexed-schematics/actions/runs/46062065218) |
| Existing Amber baseline gate | 263 planner cases and retained Renaissance regressions pass; this is a separate baseline | [Run 46062065281](https://github.com/GSVexed/vexed-schematics/actions/runs/46062065281) |
| Public download integrity | Immutable loader and source match local; all seven raw chunks match their hashes and reconstruct the exact 620,644-byte bundle | [Manifest](../manifest.json) |
| Authorized PC readiness | One Roblox process; existing runner reached | [Private run 46058719369](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/46058719369) |
| Helper installation | `RUNNING_INTERACTIVE` at 20:09:30 UTC, rollback available, no autostart, no gameplay actions | [Private run 46061642489](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/46061642489) |
| Passive client observation | Console receipt incomplete/absent; bounded file check returned `NO_FRESH_EXECUTOR_FILE` despite accepted dispatch | [Private run 46062384685](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/46062384685) |

The 230 candidate cases comprise 202 inherited scenarios, 22 input/compatibility scenarios and six loader scenarios. They include a simulated 60-second continuous hold, physical-release stopping, menus, minigames, offers, config replacement, helper restarts, stale files, respawns, repeated toggles and unload. They do not substitute for a physical long-duration live combat session.

The failed initial PowerShell probe was fixed before game contact. The readiness retry used the already-established process-scoped invocation without changing global execution policy. An unrelated existing `v120-native-observer-pickup` workflow also fails on research pushes; it is recorded separately and was not modified. Complete successful and failed receipts are in [verification.json](verification.json), and individual test results are in [test-results.json](../test-results.json).

Still missing: confirmed current live interface observations, real damage acceptance and sustained physical holds in combat, continuous stamina/ability behavior, actual minigame grades, HP/effect recovery rates, Hippo gameplay, voice range and complete Territory journeys. The latest independently verified game artifact remains the supplied build-2415 capture. No newer live build was confirmed by the failed probes. These limits are why this release remains `rc1`.

## Immutable artifacts

| Artifact | Commit | SHA-256 |
|---|---|---|
| Full source, modules, helper | `d4e3697728b9b6a2727d610a3f440d5b5f2dd81b` | Bundle: `4a25b0a6970bf0f0bf0114a70aa186bd7d11f1f276e2e81b596f7832ddda5a15` |
| Launcher and final tests | `60e703742efdec8950f69f9ce715f720604f35d3` | Loader: `90c85df32266b1f1733193015ed48e8d67150be4df5f693fc2e56635949b5867` |
| Installed helper source | Source commit above | `55d09b90bedba7dd5a561363d419c0c727e650eee8bf03a05adfad8f7a34c63d` |
| Installed helper executable | Compiled on the authorized PC | `f28f20c42e80c69046e2a1c637ffeff0a6c9f7804cc355399e1904bf40770d86` |

The loader checks the pinned source length, release markers and fingerprint, and checks SHA-256 when the executor exposes a usable hashing backend. It falls back to pinned chunks for failed or truncated full downloads. Failed download/integrity checks leave the existing active hub intact in the covered tests.

## Rollback

The recommended previous stable loader is preserved at its original commit:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/c134f883c4464bcac9f2a9e41c1821acc037f685/roblox-tools/feral-renaissance-v16.3.1-loader.lua"))()
```

The immediate previous 16.3.2 loader is also preserved:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/0ee8a27f671686c72f3fe3e5407488ddb8900074/roblox-tools/feral-renaissance-v16.3.2-loader.lua"))()
```

Release the mouse button, unload the candidate through the hub, then execute the selected previous launcher. Keep the saved settings files; no reset or deletion is required. Older releases can still have their original build-2415 limitations.

To restore the previous Windows helper as well, run this in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\FERALInputBridge\rollback.ps1"
```

This process-scoped invocation uses the installed rollback script. The script verifies `%LOCALAPPDATA%\FERALInputBridge\rollback\manifest.json`, the saved executable hash and the existing scheduled task's executable path before stopping/replacing the helper. It restores the saved helper source when available and starts the existing on-demand task. The installation receipt confirms a rollback executable was available. Rollback was not executed during release validation because the candidate helper installation succeeded.

The unchanged 16.3.2 bundle and loader hashes are independently checked by the build tooling and recorded in [manifest.json](../manifest.json). The 16.3.1 raw launcher was fetched successfully during final verification. No existing loader was repointed to this candidate.
