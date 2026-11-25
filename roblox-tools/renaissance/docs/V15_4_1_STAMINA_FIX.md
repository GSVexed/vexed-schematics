# Renaissance 15.4.1 — rejected stamina plan

The user reported that Infinite Stamina did not work after 15.4.0. A passive, read-only check of the actual running hub in FERAL v2412 reproduced an implementation failure: stamina was requested but UNAVAILABLE, with reason `duplicate field`. No stamina lease or own no-drain flag was active. The own Hippo was moving in 60 of 61 samples, with 23 observed downward stamina steps over the six-second window. Validation issued no gameplay requests or attribute writes. Exact minimized evidence is live-v1541-stamina-before.json; private runner run 45646784705 returned the matching console result.

The lease manager deliberately rejects multiple entries for the same table/key. The extended stamina plan could reach a shared native profile through multiple paths. Equal requested changes were being treated as a malformed transaction, so the entire transaction was rejected before any field was changed. Flag activation depends on a successfully applied profile, explaining why it also remained off. The earlier plan-construction preflight did not attempt the lease and missed this failure.

15.4.1 normalizes only the stamina plan before the strict lease manager sees it. Equal target/key/value/kind entries become one entry. Different values or kinds still fail explicitly. Every unique field retains one original value for exact restoration. No resource value is filled, no cooldown is removed, and no native gameplay request is added.

Five added regressions cover aliased native climb levels, shared species sprint profiles, exact disable/close restoration, conflicting aliases, case-distinct fields and character replacement. The complete local suite and published source CI run 45647825543 pass 181 checks and 18 compile checks, including all existing minigame timing and input regressions. The complete 15.4.0 bundle joins the protected rollback hash set.

This fixes a reproduced configuration-application defect. Actual sustained stamina efficacy must be measured separately after applying the fix; it is not established by plan compatibility or a green toggle. The existing private bite-access limitation and all other release boundaries remain. No removed feature returns.

The exact candidate passes published source CI 45647825543. Active repair run 45648152224 and read-only late pickup 45648691978 were acknowledged without their matching result; live application and sustained efficacy remain unconfirmed. Further executor probes stopped.
