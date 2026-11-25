# Live validation record

## Version 15.4.1 stamina defect

Passive runner run 45646784705 returned the exact schema-1541 observation from the actual 15.4.0 hub in FERAL v2412. Stamina was requested but applied=false, state=UNAVAILABLE, reason=duplicate field, with no valid lease and no own no-drain flag. The own Hippo moved during 60/61 samples; 23 downward steps were observed in six seconds. The observation changed no attributes and sent no inputs/gameplay requests. Sanitized result: live-v1541-stamina-before.json.

Source 64c3487b111a7f3075004d645c9b18e23daa744e passes 181 checks, 18 compile checks, deterministic packaging and all protected rollback hashes in public CI 45647825543. Its stamina normalizer coalesces identical table/key/value/kind entries before the strict lease transaction. Conflicting values remain errors, and original values retain a single restore owner.

A guarded active repair using this exact normalizer was requested in private run 45648152224. The request was acknowledged, but no matching schema-1542 result was returned. One read-console-only late pickup, run 45648691978, also did not return that result. These are MCP_SCRIPT_ACCEPTED_CONSOLE_NOT_CONFIRMED. Active repair, flag activation and sustained stamina efficacy remain unconfirmed. No additional test movement was requested. Attempts to schedule a short alternate repair hit connector write errors; no success is inferred from those errors. Earlier 15.4.0 stage-only success is not final 15.4.1 efficacy evidence.

## Version 15.4.0 release

Exact source ef1544f25d37f071df90dd1da84b9fd5df60bdaf passes all 176 code-level scenarios, 18 compile checks, deterministic packaging and rollback gates in public source CI run 45643744396. The suite includes an independent 72-case native-formula timing matrix and a direct comparison against preserved 15.3.0: the late-packet example changes from a 1020 ms wait to immediate eligibility; ordinary safe entry is 30.272 ms before centre. No actual live speedup, Perfect rate or win rate is inferred from those simulations.

Private Windows runner run 45644187432 executed a pinned, reviewed stage-only validator for this exact source. The unique paired client matched the running Roblox process. Its exact schema-154/source-commit result was parsed from the console and returned MCP_SCRIPT_CONSOLE_CONFIRMED. Sanitized result: live-v154-stage.json.

| Check | Observed result |
|---|---|
| Game/capture | Correct FERAL place, actual version 2412, own animal available |
| Modules/registry | 13 modules, 21 retained records |
| Rapid timing model | Late-arrival pure simulation passed inside the actual executor; zero fabricated grades |
| Deadline API | Native task.delay present; no gameplay deadline scheduled by the inactive candidate |
| Native callback access | Minigame and feeding found; private bite handler not found |
| Stamina schema | 17 recognised consumption fields planned; no plan applied |
| Renderer | Hidden construction and render smoke check returned |
| Isolation | Running 15.3.0 retained; no activation or retirement |
| Gameplay writes/requests | Zero; validator blocked candidate gameplay requests and attribute writes |
| Shutdown | Candidate closed with zero cleanup errors |

This establishes exact-source executor compatibility and native interface access. It does not establish actual grade frequency, simultaneous accepted damage, server range, recovery multipliers, stamina sustainability, remote pose visibility or flight/cub/AFK success. No raw capture, credential, player identifier or unrelated console text was exported. The unrelated pre-existing v120 observer workflow failed on the private push; it was not changed and is not a Renaissance gate.

## Version 15.3.0 release

137 local regressions and 18 compile checks pass, including deterministic operation comparison against preserved 15.2.1. The earlier 128-scenario candidate at 79bb078 passed published source CI run 45514494808. Its exact live staging run 45514618046 found native feeding and minigame handlers but not the private bite handler, so it was not promoted. A bounded metadata check (45515551711) found 58 of 59 primary-input callbacks were foreign-state connections. The revised candidate preserves available validated handles and uses an explicitly limited native-config/own-marker guide when private state is inaccessible. Exact final source 1905fbe0eda6e3dd48b2ef32a16de8d02b5f6a3b passes all 137 scenarios and 18 compile checks in published CI run 45632821703. Private execution attempt 45633163610 returned MCP_SCRIPT_ACCEPTED_CONSOLE_NOT_CONFIRMED. A separate read-console-only pickup 45633541410 returned CONSOLE_MARKER_WITHOUT_VALID_RESULT; it did not execute another script. A matching final source result was not recovered. Final in-game behavior remains unconfirmed, including moving Rest pose correction and Vulture handoff. Further repeated probes stopped. A passive movement check through the existing Potassium runner (run 45512958870) returned the exact marker. The current hub was 15.2.1 in FERAL 2412; the user was moving normally as a Bison, not in the reported Vulture freeze. No attributes or gameplay inputs were changed. This does not establish the cause or resolution of that earlier freeze.

## Version 15.2.1 recovery correction

Exact source bdfd2fc913fcf70f2a71dee5a94d5cfbfdda8b17 passes all 113 service-boundary regressions and 17 compile checks locally. Published source gate: 45505688605. The supplied current WolfAnimClient bytecode supports the scoped native blend reset; its fingerprint and instruction range are recorded in V15_2_1_RECOVERY.md. These are implementation and static-contract results. Live sustained HP/condition multipliers and the final rendered pose are not confirmed.

Private runner run 45505057539 returned the exact validated passive-observer marker through Potassium. It observed the existing 15.2.0 hub in FERAL 2412 for thirteen samples, without inputs, attribute writes or native gameplay requests. Own HP equalled MaxHealth throughout, with both increasing together during growth; these changes are not regeneration evidence. The recovery reason remained attack priority, while manual Rest and automatic Rest ownership were false. The sample did not record mouse-button state, so it cannot identify which input caused that reason. Independent current-bytecode inspection found the incorrect right-mouse attack gate and grounded its correction.

This confirms the current runner-to-executor route works. A separate live staging run 45505790776 then loaded exact candidate bdfd2fc913fcf70f2a71dee5a94d5cfbfdda8b17 through Potassium. All 13 embedded modules and the inactive UI staged; the current WolfAnimClient was present. A scoped zero pose attribute passed write/readback and exact restoration across a render boundary. Candidate cleanup passed with the previous active hub retained. No Rest, bite, feed, carry or other native gameplay request was issued. The sanitized result is live-v1521-stage.json.

This validates local staging and attribute ownership, not the rendered pose under a real automatic Rest window, another player's view, sustained 2x/4x rates or server acceptance. No user-driven repeated diagnostic test was requested.

## Version 15.2.0 follow-up

Final source 21da4732f05897c7225fde2ffd6ea81d02be6b1b passes all 99 regressions, compilation, deterministic packaging and preserved rollback hashes in published source CI run 45494741846. This is automated service-boundary evidence, not private-server efficacy.

Earlier candidate dcb171443acd288d2f6801fc42dec00a045699a3 executed through Potassium in FERAL place version 2412 during private runner run 45491692470. All 13 modules loaded; hidden UI/rendering, green/yellow/red colour samples, player-only tracking checks, cleanup and preservation of the existing active handle passed. An own animal was available. Native function readiness did not pass. The exact sanitized result is live-v152-initial-stage.json.

Private run 45492217319 confirmed the inspection capabilities and target scripts were present. Its heap lists contained 944,824 to 2,306,709 entries, mostly not functions in the inspected prefix. The old budget had not reached the needed functions. This led to the shared function-only fallback and callback-first lookup. A further static check removed the dependency on the unretained cancelFeed prototype; guarded original-toggle cancellation is tested separately.

The final pinned source was requested in private run 45494910381. Potassium acknowledged the request but no exact result was returned. A final single-print transport check in run 45495900596 was also acknowledged without its marker. Current status is **MCP_SCRIPT_ACCEPTED_CONSOLE_NOT_CONFIRMED**. The intermediate helper's syntax error was corrected before that final transport run. Probes then stopped.

| Evidence | Boundary |
|---|---|
| 99 local and published source regressions | Final-source implementation passes the simulated native contract |
| Actual hidden staging/colours | Passed on earlier candidate dcb1714 only |
| Final native callback lookup, feed state and bite retry | Unconfirmed in the current live executor route |
| Hunger/thirst progress, reduced ghost-hit frequency and cub pickup | Unverified gameplay outcomes |
| Universal swimming/submerged pickup | Not established; native restrictions retained |
| Existing active hub during successful staging | Retained; validation issued no native gameplay requests |

live-v152-status.json and release.json distinguish these facts. Earlier 15.0/15.1 executor successes below do not validate the final 15.2 native lookup. No credential, unrelated console payload or private capture was exported.

## Version 15.1.0 follow-up

The following earlier executor results belong to 15.0.0, not the new input/reach/recovery changes.

For 15.1.0, the Windows runner and local Potassium MCP service were accessible. One uniquely listed paired client matched the running Roblox process. A fixed print-only execution call returned an acknowledgement, but its exact console marker was not recovered, including a bounded retry using the acknowledgement's console_cursor. The final attempt is private runner run 45455307175 (24 November 2026). No credential or unrelated console payload was exported.

This is **MCP_SCRIPT_ACCEPTED_CONSOLE_NOT_CONFIRMED**, not successful game-side execution. There is no new live confirmation of the native serverPress closure discovery, reversible input lease, simultaneous damage during a minigame, accepted extra range or condition recovery rate. Further repeated broad diagnostics were stopped. The updated source is validated by compilation, deterministic packaging and the 73-scenario service-boundary suite; published source CI run 45456403524 passes all 73 scenarios and the deterministic bundle gate. release.json records the exact pin.

The native input contract is independently grounded in the v2412 capture, as recorded in V15_1_INPUT_REVIEW.md. The fixtures simulate that verified contract; they are not server-authoritative tests.

## Earlier version 15.0.0 evidence

The Windows runner and existing local Potassium pairing were verified on 24 November 2026. A fixed print-only script was accepted and its exact console marker was returned in private runner run 45437390421.

Candidate 68aec605e46011b33b024102469aeac4a15528bd passed the published compile/regression gate in run 45441514764.

Private runner run 45441710135 executed that exact pinned source through Potassium in PlaceId 108901361810209, actual place version 2412. The parsed, privacy-minimized result is in live-stage-result.json.

| Check | Observed result |
|---|---|
| Actual executor compilation | All 9 embedded modules; 21 registry records |
| Hidden GUI and renderer | Staged successfully; rendering preflight returned |
| Config schemas | Reach, stamina, recovery, effects, mobility, speed, leap and climb all compatible |
| Client config write/readback | All eight plans accepted same-value leases and exact release; this did not apply their gameplay changes |
| Settings | Real executor-file roundtrip preserved true and false, including a false overwrite |
| Native interface presence | WolfActions, FeralGrabV2, FeralLunge and FeralHit present |
| Isolation | Existing active handle unchanged before and after staging |
| Native gameplay requests | Zero |
| Shutdown | GUI removed; zero owner cleanup errors |

## Running release

Final source 59e0a6d0db6d1a9e8c9f57f7a8368e858f8ec600 passed the published compile/regression gate in run 45442299264, including 54 regression scenarios.

Private runner run 45442549339 then validated that exact source through Potassium in FERAL version 2412. The machine-readable result is in live-runtime-result.json.

| Check | Observed result |
|---|---|
| Stage gate | Hidden construction, render and cleanup passed before retiring any active hub |
| Active runtime | 49 actual heartbeat ticks and 49 render frames observed; remained active |
| Permanent reach | Client geometry lease applied |
| Menu | Visibility changed and restored through its live owner method |
| Hot reload | Previous Renaissance instance closed and removed its GUI; replacement active |
| Shutdown | GUI removed, exact owned reach fields/functions restored, zero cleanup errors |
| Final activation | Version 15.0.0 active using migrated real saved settings; all 21 records requested |
| Validation gameplay requests | Zero from the all-OFF validation instance |
| Own-animal visual fixture | Unavailable: no active own animal during this live run |

The final saved-settings activation may arm the user's selected native features when an eligible animal/session exists. It is normal operation, not controlled efficacy evidence.

Actual live hollow outlines/tags on a spawned animal, native keyboard sprint interaction, accepted combat damage/range, sustained stamina, added HP, 4x condition clearance, survival credit, escape outcomes, surface takeoff and minigame grades remain unverified. No private server handler was obtained. Native interface presence and local write/readback do not establish those results.
