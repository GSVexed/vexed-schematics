# Renaissance 15.3.0 — timing, feedback and flight handoff

All 21 feature records and settings schema 15 remain. No removed feature or extra control is added. Bite Reach remains permanently requested; ESP and tags remain hollow, health-coloured and real-player-only.

## Recovery observations

HP, injury, bleed and venom each use their own trailing six-second window, sampled at most four times per second and capped at 32 segments. An earlier gain expires; it cannot keep the row saying HP is rising indefinitely. Incoming damage, worsening conditions, growth, combat/movement changes, character changes and missing values reset or exclude the affected windows. HP is reported even when condition recovery is also requested. Condition records distinguish easing, watching, no recent decrease and unmeasured.

This measures recent values. It does not establish 2× HP or 4× condition efficacy, causal attribution or private-server authority. The native factors retained in 15.2.1 remain intact.

## Native bite guidance

The small marker is grey for known capture/carry, Rest/stand-up, feeding, ability and timed bite/recoil restrictions, native cooldown, unknown native timing or stale range geometry. Current WolfController prototypes 16, 17 and 19 ground these checks. The original pure biteCooldown calculation is read through the own-script callback chain only after its function identity and player/remote/upvalue layout are validated. No attack is invoked by the guide. Missing or changed layouts remain unknown.

Teal and amber still distinguish stock-reference and extended client geometry. A clear client check is not accepted server range or confirmed damage. Native attacks, their cooldown and the existing bounded post-Rest bite buffer retain their normal guards.

## Work bounds and minigames

Whole-heap enumeration is removed from the runtime, including the old fallback. The compiler gate rejects a getgc call in the bundle. Discovery walks the existing InputBegan, FeralFeedTap and FeralGrabV2 callbacks, restricted to the own WolfController/FeralGrabV2UI scripts. The shared resumable queue examines at most 32 entries in a roughly 2 ms slice, with 96 connections per signal, depth four, 256 accepted functions and 512 queued entries. A single executor API call itself cannot be pre-empted. Missing capability is reported; it never triggers an unbounded heap search.

An active pending strike suspends native discovery, target rebuilding, terrain-heavy flight/AFK work, config reconciliation and nonurgent combat classification. Native timing, genuine input, pose ownership, action cleanup and the actual press remain responsive. A strike recovered from native UI state protects that same frame. Background work resumes after the press/window; missed centres can still use a later genuine crossing. Actual timestamps, session/strike IDs, own-character grade rules and simultaneous ordinary bites are preserved.

Idle native state probes run at four per second. Active minigame state stays per-frame, while unchanged binding checks run at most ten times per second and are refreshed immediately for native begin/strike events. The ESP avoids unchanged property writes, caches head references during tracker refresh and skips projections when tags are off. Moving names and the small guide retain per-frame projection. Candidate eligibility is calculated once for nearby selection, before its later passes; the real bite geometry still rechecks native target guards.

## Operation comparison

Same mock services, 24 real players, fixed camera/health and 120 frames after warm-up. This compares the preserved 15.2.1 bundle against this candidate. It measures operations, not game FPS.

| Operation | 15.2.1 | 15.3.0 |
|---|---:|---:|
| Repeated highlight property writes | 11,520 | 0 |
| Unchanged name-position writes | 2,880 | 0 |
| Idle native upvalue reads | 240 | 96 |
| Target rebuilds during a pending strike | 15 | 0 |
| Binding-info queries during that strike | 120 | 20 |

Real movement, camera motion and HP changes still require updates. Actual FPS improvement is not claimed.

## Vulture early-release handling

Current FeralFlight suspends its movers for a non-nil FeralTalonLock/FeralDiveLocal, including native session IDs. The hub previously checked TalonLock only against boolean true and did not include DiveLocal. Those states now preempt automatic recovery, bite readiness and automatic underwater flight exit.

With Flight Assistance enabled, an observed own Vulture talon session has a bounded release/resume owner. Space/ButtonB are passed to the original FeralTalonLetGo binding. If that actual intent remains unresolved, at most one ordinary FeralLunge release retry is sent for the same session. It does not clear server lock flags or unanchor anything.

After the session clears, a narrowly identified stall can request one normal FeralFlyDrop/FeralFlyRelaunch sequence. Requirements include an airborne, unanchored Vulture, the exact native flight mover pair, actual movement intent and near-zero motion for 0.75 seconds. Active abilities, capture, minigames, menus, water, climbing, held attacks and deliberate stationary flight block this attempt. The episode expires after four seconds; owned request attributes expire after 1.5 seconds and are restored on disable, respawn or shutdown without overwriting unrelated input. No position, velocity, anchor or native mover property is edited by this repair. Native eligibility still decides whether the requests succeed.

The reported freeze itself was not captured: the passive live check found the user moving normally as a Bison, with no hub flight/recovery owner. The new Vulture paths pass simulated native-response, no-response, active-lock and cleanup scenarios. Their effect on the original live freeze remains unverified. A motion observation is recorded separately from a request and does not prove causality.

## Validation and rollback

128 service-boundary scenarios and 18 compile checks pass locally, including eight overlapping-attacker strikes with frame hitches and concurrent native bites. The operation comparison is a regression gate. Module/bundle parity and exact hashes protect CLEAN v14 and complete 15.0.0, 15.1.0, 15.2.0 and 15.2.1 bundles. The current loader is promoted only after the published source gate and exact candidate validation.

Prior 15.2.1 source: bdfd2fc913fcf70f2a71dee5a94d5cfbfdda8b17. Its bundle SHA256 is d1aa528c9b3ec3dfa7aaf69991786cbfbaa75f75703e39408eaf11be3f8c59b9. CLEAN v14 rollback remains 158474ba80c0d613c3427399f24059341369acc8.
