# Renaissance 15.1.0 — release record

The candidate has passed local compilation and 73 service-boundary regressions. Published CI is pending. The stable launcher still pins 15.0.0 until promotion; release.json records that currently released pin.

All 21 retained functions remain present. The compact interface, Right Shift, permanent reach, hollow ESP, simple controls and schema-15 saved settings are preserved. No deliberately removed feature has returned. CLEAN v14, its launcher and the complete 15.0.0 source are unchanged.

## Changes

- Health percentage and studs render above the name, with both lines raised above the animal.
- Ordinary bite clicks no longer cancel scheduled minigame presses. During a verified native session, the native minigame mouse binding is temporarily separated from the bite path; Space/gamepad retain native manual control.
- Multiple hunters update one fight without clearing its pending strike. Own-character results, enabling mid-session, missed crossings and native bite/end cleanup are handled explicitly.
- Native closure discovery resumes across bounded slices, including large GC pools. Missing introspection is reported as PARTIAL during an active minigame.
- Permanent client reach has wider range, cone and height limits, plus a shared eligible rear/same-tree direction. It does not rotate the character or add Bite/BiteHit requests.
- Injury, bleed and venom deficits may request native Rest during a known combat tag; the HP combat exclusion remains. Attacks and minigames still preempt recovery, and local factors do not compound to 16x.

## Validation

| Gate | Result |
|---|---|
| 21 retained functions / 13 exclusions | Preserved |
| Compile | 10 modules, 2 fixtures, versioned bundle and launcher pass |
| Local regressions | 73/73 pass |
| Embedded source parity / deterministic bundle | Pass |
| CLEAN v14 / 15.0.0 rollback hashes | Unchanged |
| Published CI | Pending |
| New actual executor execution | Unconfirmed; MCP acknowledged a fixed script but its marker was not returned |
| New gameplay results | Unverified |

The minigame fixture follows the captured v2412 native CAS and serverPress contract. It verifies repeated clicks during a three-hunter session without cancelling timing or duplicating presses. It does not establish accepted live damage or Perfect frequency. The prior 15.0.0 executor checks are kept in LIVE_EVIDENCE.md and do not validate the new code.

## Use and limits

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()

Right Shift toggles the single compact window. Recovery and fast effects share one control. The small optional range marker separates stock-reference and extended client eligibility.

Extra accepted bite range, bites during native capture, sustained infinite stamina, real continuous 4x condition recovery and other server-dependent benefits remain unverified. Native pin, clamp, cooldown, venom and post-Rest restrictions can still prohibit biting. Native Rest's default post-exit lock remains a possible first-bite blocker. A local pose mask does not prove remote invisibility of Rest.

Mouse/minigame separation requires getgc, debug.info and supported upvalue access in the executor. Unsupported introspection leaves the native binding intact and displays PARTIAL. Right Shift can still overlap native raw sprint polling. ESP/finder depend on replicated characters and track up to 24 players at the selected 900-stud maximum.

## Rollback

Re-executing either pinned source closes the active Renaissance owner before activation. Avoid manually stacking independent legacy hubs.

Previous Renaissance 15.0.0:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/59e0a6d0db6d1a9e8c9f57f7a8368e858f8ec600/roblox-tools/feral-renaissance-v15.0.0.lua"))()

Original CLEAN v14:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/158474ba80c0d613c3427399f24059341369acc8/roblox-tools/feral-nova-v14.0-clean-reach-core.lua"))()

## Records

The released source commit, source hash and CI run are recorded in release.json. FEATURE_AUDIT.md lists all 21 feature statuses. ARCHITECTURE.md, V15_1_INPUT_REVIEW.md, LIVE_EVIDENCE.md and test-results.json retain the implementation and evidence detail.
