# Live validation record

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

The running-release lifecycle check is pending in this commit. No fresh combat, HP, condition-clearance, survival-credit, escape, minigame-grade or authoritative movement outcome is claimed.
