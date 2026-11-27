# FERAL Renaissance 16.4.0-rc1: build 2415 investigation

27 November 2026. Release candidate; live gameplay acceptance remains unverified.

## What was established

The supplied current capture is complete: 625 script instances, 503 unique programs, zero export failures and no in-game decompilation. The archive SHA-256 matches `833a905becc3ebf7f7f07667c08aeecc0dc8ed6f25e1e9c3c4b19e3708030026`. All 503 programs parsed, and every decoded prototype passed instruction-reference validation in the private offline job. Captured programs were never executed during analysis.

The original v2412 archive was also recovered, CRC-checked and parsed locally: 383 unique programs. Its fingerprint index and current inventory were normalized across PlayerScripts/StarterPlayer copies. The resulting comparison has **307 identical bytecode paths, 78 changed bytecode paths and 120 paths newly present in the inventory**. The old own-character `Animate` path is absent. New inventory entries include platform code, animation clips and capture-scope differences; those counts are not a claim of 120 new game features.

Reconstructed v2411 source was recovered for 23 relevant modules, alongside the complete v2411 inventory comparison in the private analysis job. Reconstructed text and compiled bytecode are different representations, so their hashes were not compared as if equivalent. The machine-readable report separates whole-program equality, prototype equality, identifier candidates and inferred compatibility.

The editable public project tree was still at 15.7. Rebuilding from it would have discarded later functionality. This candidate instead recovers all **29 modules directly from the verified 16.3.2 bundle**. Twenty-two recovered modules remain byte-for-byte unchanged; seven receive focused repairs, and one new compatibility module centralizes admission rules. All 28 existing feature registry entries and all 12 integrated Territory modules remain present.

## Changes in the game that matter

### Stamina

`NeedsConfig` is byte-for-byte identical to v2412. The significant change is in `WolfController`: the old `WolfDbgNoStamina` checks now sit behind `RunService:IsStudio()`. The normal movement loop also reads `FeralSrvTired` and applies a tired-state constraint; the new Lion/pride paths introduce additional consumption. Thus a locally written debug flag no longer establishes unlimited stamina in ordinary live play.

The existing sprint, jump, swim, climb, flight and venom consumption leases are preserved, with their original native values restored on disable/unload. On build 2415 the ineffective debug attribute is skipped, and the UI explicitly reports partial client support and native server fatigue/ability costs. The hub does not change `Stamina`, `StaminaMax`, the server fatigue flag, ability cost attributes or server state. Continuous server-recognized unlimited stamina has **not** been demonstrated. Respawn, nested config replacement and restoration are covered offline; live sprint/swim/ability acceptance still needs gameplay evidence.

`VenomConfig` has real balance changes: WINDOW 16.8→20.94, SPRINT_DRAIN .15→.11538, OTHER_DRAIN .06→.04615, IMMUNE 33.2→29.06, BITE_TIME 3→3.9 and BITE_DRAIN .025→.01923. The hub continues leasing recognized consumption inputs and preserves current native timing, immunity and condition-recovery values.

### Combat and Hippo

`FeralHippoClient`, `FeralHUD`, `FeralSurvivalUI` and `GrowthConfig` are byte-for-byte identical to their v2412 counterparts. Hippo's native `finish` function and five-upvalue layout therefore have unusually strong compatibility evidence. The old version gates were preventing recognized behavior from running on 2415.

`WolfController.tryBite`, its native cooldown calculation and `toggleFeed` have unchanged instruction streams. `doBite` instructions also match after excluding prototype metadata; its child identifiers move. The candidate admits private timing layouts only for audited 2412/2415 builds, then still checks current script, player, remote, callable relationships and expected value types. Unknown future builds retain conservative visible-state fallbacks.

`Species` adds Lion/sex-related data and helpers, while `scaled` and `biteCooldown` retain their prototypes. `PassiveConfig.biteCdMult`, `CombatConfig.hitDelay` and the cone calculation remain compatible. The core directly initialized combat geometry scalars remain unchanged. These facts support checked interface admission, not guaranteed server hit acceptance.

A separate hub bug multiplied the adaptive cadence factor twice: once inside the leased species cooldown, then again in the scheduler. The second multiplication is removed. For example, an effective native interval of .62 seconds now schedules .62 seconds, not .3844. This reduces redundant attempts while retaining the existing damage-feedback governor and its native limits.

Local bite markers, predictive effects and damage replies remain separate evidence. Only uniquely attributable, positive native damage feedback can accelerate the governor; ambiguous overlapping attacks cannot train it. No additional Bite/BiteHit requests or fabricated confirmations are introduced.

### Minigames and other client changes

`FeralGrabV2UI` adds wrestling outcome/state presentation; `serverPress` remains identical while the strike presentation changes. `GrabV2Config.SHARE` changes .9→1, with PERFECT .32 and PASSES 2.5 retained. Existing automation reads current session/strike data and retains its native grade accounting.

The new wrestling client/config and clash config are present; Lunge UI also observes wrestling outcomes. Combat repetition now pauses for native wrestling and open native nest/stronghold panels. The actual FeralPanelHold open/close signal is used; a persistent nest/stronghold phase alone cannot block combat. These new interactions remain manual. Existing GrabV2 automation is preserved; this release does not claim new wrestling automation. Title and map menus now revoke desktop input ownership like other native menus.

Flight tuning changes include DRAG .6→.5 and TURN_RATE 1.9→2.28. Those native values are retained. Lion-specific content is mapped rather than treated as evidence that every animal ability has been tested.

## Hold-to-Bite repair

The previous Lua/Windows protocol reused a single hub token through hard lifecycle boundaries. The helper could retain a captured physical press across an unarmed period, and a restarted helper could reset its sequence below the Lua reader's last accepted value indefinitely.

Hard revocation now increments a separate desktop-input epoch without altering the hub's other ownership tokens. Both the existing and updated helpers discard a captured press when that token changes. Focus loss, menus/text entry, death, capture, respawn, feature disable and unload require fresh ownership. Temporary minigame/GUI/heartbeat interruptions pause dispatch instead.

After a temporary protected pause, Lua requires a later positive sample after a .20-second readiness interval. The helper separately requires .18 seconds of stable readiness before resuming the same captured press. A replayed sequence does not refresh liveness. A new helper instance, or a legacy negative sample with a reset sequence, renews the session without accepting the old press.

The Windows helper now uses the same explicit hold-state implementation in production and its self-tests. Normal short clicks retain the existing replay-on-release behavior; long holds retain the .18-second threshold. Injected input always passes through the hook. The helper stays scoped to a fresh hub heartbeat and the foreground Roblox process. It has no driver, network service or boot/logon trigger.

Recognized Eat/Drink buttons remain temporarily non-interactable for each generated paired combat pulse and are restored afterward. Unrecognized GUI controls or an unavailable safe input backend cause a pause. This protects UI ownership; it cannot guarantee every executor exposes a usable paired-input backend.

## Compatibility guard decisions

Every one of the 19 reported legacy checks is accounted for individually in `compatibility.json`, with its original bundle line and replacement/retention rationale. Public table interfaces use actual capabilities. Compiler-specific private layouts retain explicit audited-build admission and runtime identity/type checks. The old experimental one-shot trial stays restricted to 2412 and remains disabled on 2415. Metadata now distinguishes the original source baseline from the newer capture. The warning attributed to `amber_runtime` by the earlier scan was in the bundle bootstrap tail.

## Verification and remaining evidence

The candidate passes **230 automated Luau scenarios**: the 202 inherited cases, migrated only for the current registry/version and established surface-swimming behavior, plus 22 input/compatibility cases and six loader cases. These cover native feedback, leases, configuration replacement, input ownership, long holds, replay/restart behavior, offers, interruption/resumption, respawns, repeated enable/disable and cleanup. Loader cases cover full and chunked fetches, missing chunks, same-size wrong-version data, digest mismatch and network failure while preserving the current hub. A 60-second simulated desktop hold produces repeated native markers and stops on release. The helper additionally exercises 10,000 deterministic interruption/recovery cycles and its Windows input ABI. This is simulation, not server damage evidence.

The unchanged 15.7 project separately passes its original 202-case suite, preserving its baseline. The new build checks module/bundle parity and immutable 16.3.2 rollback hashes. The published loader commit passes the hosted Linux and Windows candidate gates: 230/230 Luau cases and 10,000 helper state transitions. All seven public raw chunks were independently fetched, hash-checked and reconstructed to the exact source bundle. The existing Amber baseline gate also passes its 263 planner cases. These are separately scoped checks, not live Territory acceptance.

The user's existing Windows runner was reached, with one Roblox process and one existing helper. The first readiness attempt failed because the machine's normal PowerShell script invocation is restricted; the retry used the runner's previously established process-scoped invocation and passed. The pinned candidate helper was compiled and installed successfully at 20:09:30 UTC, with a `RUNNING_INTERACTIVE` receipt, a hashed rollback executable and no autostart trigger or gameplay actions. An unrelated existing `v120-native-observer-pickup` workflow has also failed on research-branch pushes; its failure is recorded separately and is not counted as a passing candidate check.

Passive own-client observation did not return a confirmed result. An initial wrapper parse error was corrected before game contact. Subsequent console pickup returned incomplete or absent receipts. The bounded file-output attempt was accepted by the local MCP transport but produced no fresh executor file. Neither transport acceptance nor an exit-zero pickup job counts as live validation. The latest independently verified game artifact remains the supplied 2415 capture; no newer live build or current runtime interface set was confirmed. Full successful and failed run links, installation hashes and evidence boundaries are in [verification.json](verification.json). The actual launcher, complete changelog and exact rollback instructions are in [RELEASE.md](RELEASE.md).

No automated attacks, movement, combat with other players, fresh captures, server-code extraction or Elder-cap experiments are part of this release validation. Long-duration live combat, server fatigue behavior under continuous play, real minigame grades, voice distance and full Territory journeys remain unverified. The release therefore stays explicitly marked **release candidate**.
