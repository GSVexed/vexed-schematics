# Live validation record

## Version 15.2.0 follow-up

The new source passes 99 local service-boundary regressions, compilation, embedded parity and rollback checks. Published CI and a scoped stage-only executor check are pending. Earlier executor results below do not establish compatibility or gameplay efficacy for 15.2.

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
