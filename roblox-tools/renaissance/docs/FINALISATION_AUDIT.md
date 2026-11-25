# Renaissance finalisation audit — 2026-11-25

**Decision: HOLD — do not label 15.4.1 or a new major release as gameplay-accepted.**

## Baseline and evidence checked

- Baseline branch: release/feral-15.4.1-pinned, commit 705fa4a514cb3b1cb737fce531e7b5809e31c22c.
- Source: 64c3487b111a7f3075004d645c9b18e23daa744e.
- [Published CI run 45647825543](https://github.com/GSVexed/vexed-schematics/actions/runs/45647825543): GitHub reports completed/success for the exact source commit.
- release.json and test-results.json agree on version 15.4.1 and recorded bundle digest 22903a4f0ea88fbfdc5965104d511c3c73251ae706b3aa0c3db7e2f1e00ea6c5. This compares stored values, not a fresh bundle hash.
- The test record reports 181 regressions, 18 compile checks, module parity, unchanged rollback hashes, runtime exit code zero and gameplay_success_claimed=false. Tests were not rerun in this audit.
- Prior 15.4.0 live staging cannot be transferred to 15.4.1. The attempted 15.4.1 repair lacks its matching runtime result. No new live executor session was established in this audit.
- Main remains at 15.4.0; the pinned branch is retained without modification.

## Acceptance gates

| Gate | Result | Evidence / boundary |
|---|---|---|
| Exact source CI | PASS (historical) | GitHub run above |
| Deterministic build, compile and rollback | PASS (recorded) | Existing test-results.json; no independent rebuild |
| Exact candidate live startup and teardown | OPEN | No matching 15.4.1 runtime result |
| UI open/close and focused input | OPEN | Historical simulated checks; current authorized runtime not observed |
| Settings roundtrip and character lifecycle | OPEN | Historical simulated checks; current authorized runtime not observed |
| Reported moving Rest animation / Vulture movement lock | OPEN | No final-version reproduction or resolution evidence |
| Extended-session resource/connection cleanup | OPEN | No final-version measured session |
| Gameplay acceptance | NOT ESTABLISHED | No inference from green toggles, simulated results or older versions |
| Distribution promotion | HOLD | Separate release branch; main unchanged |

## Scope of finalisation

Use a controlled, authorized Roblox Studio test environment for lifecycle and UI checks. Verify open/close, input focus, respawn, character replacement, configuration persistence, clean shutdown, and ordinary movement/animation behavior without modifying third-party game rules. Record exact version, environment, expected/observed behavior and pass/fail per case. Unsupported or unverified functionality must not be presented as guaranteed. No new gameplay manipulation, executor hooks, or competitive automation is included in this audit.

Do not overwrite rollback artifacts, promote the stable launcher, or claim a finished gameplay release on the basis of the existing mock suite alone.

## Change record

This audit branch adds release evidence and a hold decision only. It does not modify the runtime, build, existing tests, settings, or published bundle. The original pinned branch and main remain untouched.
