# Renaissance 15.5.0 / Amber 0.5.0

Date: 25 November 2026. Base main: `4dbf0780ca10aad757dd64631293b823cd4e7eed`.

This release integrates Territory into the actual Renaissance hub and addresses the reported interrupted drinking, proximity pauses, erratic region routes, premature claim departure, ineffective Bear hunts, idle stalls, tree collisions and delayed Burst use. Existing 21 feature records are retained. Thirteen Renaissance modules and ten Amber modules are embedded in one complete bundle.

## Changes and bounds

| Reported problem | Resulting behavior | Verification / practical limit |
|---|---|---|
| Moving mid-drink leaves a stale request | Distinguish requested approach, active feeding, interruption and observed idle. Clear interrupted intent and restart below full. Drink to native maximum rather than the old 72 care target; take convenient native drink offers. | Resource gain is required. Repeated E cannot cancel pending approach. Owned release and no-progress waits are bounded. Native feeding or a server rejection can still prevent progress. |
| Someone nearby pauses the bot | Use whole-hex non-pack occupancy to defer only contested territory. Select the next available hex in the same tick; exclude packmates. | Locally replicated positions are required. Native combat, manual controls and abilities still own movement when active. |
| Erratic map coverage misses region bonus | Use live `regionCell`/`REGIONS.GRID`, complete available area claims, then sweep top-left → top-middle → top-right → middle-right → centre → middle-left → bottom-left → bottom-middle → bottom-right. Local tours use nearest-neighbor candidates, short lookahead and bounded uncrossing. | Captured client config defines a 3×3 grid and pay multiplier 2. Actual server reward is unverified. Blocked hexes are deferred, never falsely counted complete. Critical scent can interrupt. |
| Leaves nearly finished territory | Protect observed progress at or above 72% from routine care, within a bounded native-time estimate. Require two stable completion samples separated by at least 0.45 s. | Critical needs, native interruptions and contest override protection. Ownership with in-flight progress below completion is not counted. |
| Sprint/Burst flickers or starts late | Share checked straight waypoint horizons, permit eligible medium-distance Burst, immediately upgrade an observed sprint, brake at turns, match native following gait. Long hunting routes may also Burst. | Actual stamina, native availability, denial pulses and acknowledgement remain required. No forced speed or stamina write. |
| Stuck against trees | Sweep a body-sized volume, query initial root overlap, allow outward recovery, and try local detours after about 0.9 s without progress. Prefer terrain below canopy. | Sweeps alone omit initial overlap. Cliffs, streaming and physics can still reject routes. Ordinary stationary travel reaches bounded fallback within seconds; native path computations time out at 4 s with at most two pending jobs. |
| Hunts run past or cannot catch prey | Aim behind velocity/facing, maintain chase speed, match close approach with ordinary input magnitude, and stop to bite stationary valid prey. Use native cooldown and geometry. | Damage requires observed HP decline; three misses, lack of closing or ineffective near pursuit triggers prompt reselection. Faster prey or server rejection cannot be guaranteed away. |
| No visible food/water leaves it idle | Search another eligible nearby area while rescanning when available. Failed food and water positions receive cooldowns. | Unstreamed/absent resources can still leave no route. Low HP and genuine native state are surfaced as specific reasons. |
| Separate menu and cleanup | Native Territory tab, one hub window and Heartbeat; existing Right Shift; immediate STOP/unload, callback restoration and stale-job invalidation. Hide/tab switches leave farming active. | Built-in engine starts disabled. No companion menu, new global visibility key or independent scheduler. |

## Validation

- Official Luau commit `97b2f4bf9cd935bed666f3e643a3b749b4d22f38`.
- Amber: **170/170 cases**, 21 compilation targets, source parity, five protected release artifacts.
- Renaissance: **187/187 retained cases**, 28 compilation targets, 23 embedded module parity checks, all earlier known-good rollback hashes.
- Full native-page tests execute the actual combined bundle in service mocks: one window/Heartbeat, controls, re-execution, settings, tab/hide behavior, Right Shift, fault isolation and unload.
- Navigation mocks explicitly install their fake Vector3 environment before loading Nav, so real waypoint filtering and horizon behavior are exercised. They are scripted physical scenarios, not recorded gameplay.
- All 943 original capture payloads previously verified against catalog lengths/checksums; no raw captured program is executed or distributed.

The published pull request and Actions checks identify the exact tested head. Release metadata pins the complete bundle to its immutable source commit. Historical versioned files are preserved.

## Evidence and remaining limits

The capture's `TerritoryConfig` provides one-based row-major region IDs, `GRID=3`, `PAY_MULT=2`, and native refill timing. Runtime reads the actual config. Roblox's [WorldRoot reference](https://create.roblox.com/docs/reference/engine/classes/WorldRoot) specifies that Blockcast/Shapecast omit initial intersections; `GetPartsInPart` supplies the separate root-overlap check. [RaycastParams](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams) provides collision-aware filtering. Exact static contracts remain in [native-contracts.json](native-contracts.json).

**No current live Roblox/Potassium connection is available in this work session.** Travel speed, prey damage, claim rates, server persistence, full-map retention and Amber/hour have not been measured for 15.5.0/0.5.0. Passing mocks and client flags are not live acceptance. Surface swimming is supported; aerial and underwater routing are not implemented. Native combat, Rest, capture, ability, menu and manual-input guards remain.

Observed positive Amber balance changes are session totals and may include other rewards. No player names or report uploads are added. Existing recovery, combat, minigame, stamina, ESP and other core feature implementations are retained; their earlier live limitations still apply.

Use the existing combined launcher from the [README](../README.md), then Territory → START FARMING. Re-executing the launcher reuses the current integrated engine. Rollback instructions load the preserved 15.4.3/0.4 pair.
