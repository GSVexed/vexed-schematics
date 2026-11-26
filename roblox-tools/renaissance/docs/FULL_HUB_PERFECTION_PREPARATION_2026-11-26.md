# FERAL RENAISSANCE — FULL-HUB PERFECTION PREPARATION

**Preparation version:** 1.0 — 26 November 2026  
**Scope:** all 22 Renaissance feature records, all 14 Renaissance core modules, all 12 integrated Amber/Territory modules, UI, cross-feature arbitration, performance, settings, game-version compatibility, evidence, testing, release and rollback.  
**Status:** PREPARATION ONLY. No gameplay, loader, UI, settings or release source is changed by this document. No perfection milestone is declared complete.

## 1. Exact foundation and promise

- **Released baseline:** Renaissance 15.7.0 with integrated Territory 0.7.0; game capture baseline v2412; published source pin 3434396b4a9057bdba8c1f146325bd26f697d1ce. Its preserved release records 202/202 core and 263/263 Territory service-boundary regressions, not live gameplay acceptance.
- **In-flight candidate:** Renaissance 15.7.1 draft PR #13, head da2145a4903e04e365cbeb4387825658d1f65a35. Its sustained native Rest request repairs passed 206/206 core and 263/263 Territory code regressions, but are unmerged and not proven effective on the live server. Candidate is the *next potential baseline*, not a second stable release.
- **Prior work stays in scope:** existing Territory T01–T44 preparation/execution ledger and S01–S62 scenario map, including explicitly unfinished T21, T38 and live acceptance tasks, must be retained without claiming completion.
- **User preference:** Territory is currently not being used. Preserve it entirely and prepare its overhaul; do not auto-enable farming or use its behaviour as a prerequisite for improvements to the core hub.
- **Non-negotiable preservation:** all existing 22 feature records, their user-facing controls, ordinary player controls, saved explicit OFF states, one Right Shift menu, the current combined launcher contract, Clean v14 and every historical immutable versioned bundle. Do not silently remove abilities or convert experiments into unconditional claims.
- **No fake results:** a locally altered config, sent remote, visible UI value, client-only animation, synthetic input or simulated success is not server-accepted healing, damage, faster travel or credited Amber. Display proposed, requested, locally observed and server/currency/HP correlated outcomes separately.

### What “absolutely perfect” means for this project

The target is the highest independently verified, continuously dependable implementation that the current Roblox client/game interfaces permit. Every feature should have a defined purpose, explicit prerequisites, minimal input latency, safe coexistence with other features, truthful status, reversible ownership, bounded resource usage and an acceptance test under actual gameplay. **There is no honest guarantee of universal 2x/4x, reduced incoming damage, hit expansion, guaranteed Perfect results or full-map farming when the authoritative server does not accept the underlying mechanism.** Unavailable features must report WHY and degrade usefully rather than pretend to work.

**Completion is behaviour-first, not instrumentation-first.** An issue is not closed by adding counters, retries, badges or a passing mock test unless the stated behaviour is fixed and measured; when real-game proof is inaccessible the issue remains LIVE-UNVERIFIED. No more “monitoring” patches passed off as actual fixes.

## 2. Priority and acceptance hierarchy

**P0 — do first / correctness:** full-hub baseline and dependency graph; recovery and negative effects; first-bite/Rest interaction; damage-loss investigation; clean startup, shutdown, manual-input ownership and response to game version changes. Any regression here blocks every release.

**P1 — major gameplay value:** stamina across modes; normal/native combat feedback and ghost hits; minigame latency; speed/gait/turning, swimming, climb, flight/talon handoff; native feeding and rescue; visuals and threat awareness. Finish end-to-end user-facing scenarios, not isolated helper functions.

**P2 — sustained polish:** readable UI, default/persistent state correctness, ESP/name/finder clarity, zoom, AFK behaviour, performance and long-session stability.

**P3 — integrated Territory completion:** all existing 44 work items and 62 scenarios, especially native climb/flight/depth adapters, whole-map steady-state maintenance capacity, resource acquisition risk and live trials. Core changes must not break Territory while it is OFF.

## 3. Architecture overhaul: cross-cutting contracts

| Contract | Implementation design to prepare | How to know it is correct |
|---|---|---|
| One coordinated input owner | A central action arbiter explicitly leases user-input priority and synthesised/native actions. Define INPUT, REST, ATTACK, GRAB, FEED, CARRY, FLIGHT, CLIMB, GAIT, AFK, TERRITORY modes. Distinguish manual intent from game-generated and hub-generated transitions. | Exactly one responsible issuer for every transition. Manual input always wins. No stale held key, camera hijack or duplicate remote on cancel/unload. |
| One character/session generation | Every deferred task, event, native handle and route carries the active character generation, game-version signature, session ID and cancellation token. | Respawn, animal swap, lobby/match transition, reload and stream replacement cannot act upon a previous character/session. |
| Capability-based adapters | Runtime service adapter publishes supported native modes per game version, animal, diet, stage and platform. Missing callback/field is UNKNOWN or UNSUPPORTED, never “ON”. | Static compatibility fixture, runtime handshake and deliberate missing/replaced field tests. No guessed mode. |
| Owned reversible patches | Each config, attribute, animation, camera, input binding and object edit is owned by one lease with source identity and before/after checks. Never overwrite unrelated later edits. | Every partial-init, error, reload, OFF, death and unload returns only owned state to exact prior value. |
| Deadline-aware scheduler | Protected minigame deadlines first, input/action transitions second, safety and combat third, nonurgent tracking/resource work last. Cut off expensive work slices to keep frame/update deadlines. | Test 30/60/144 Hz, long frame hitches, overlapping attacks and pooled enemies without missing valid input windows. |
| Signal versus outcome separation | Feature state must distinguish requested / client applied / native acknowledgment / actual replicated change / repeatedly confirmed server-persistent result. | The UI cannot say 2x/4x, successful attack or reward merely because a request was sent. |
| Shared snapshot validity | One typed snapshot with freshness, units, identity and confidence for HP, maximum HP, combat, venom/injury/bleed, hunger/thirst, stamina, movement, holding and native state. | Invalid, absent or stale values never become “zero”, “cured”, “full”, “ready” or “completed”. |
| Scene-safe fallback | When private native introspection is missing, switch to a defined public/native-interface fallback and show PARTIAL; do not crash, spam, sweep a global heap or forge results. | No crash; diagnostics explain what changed and input still works normally. |
| Status/telemetry budget | Per-feature bounded rolling counters and optional user-triggered report. Track only own relevant local outcomes; avoid automatic upload, personally identifying dumps and giant unbounded scans. | Bounded memory/CPU, useful failure evidence, safe sharing, and no report generation in timing-critical callbacks. |
| Progressive release | Atomic stage → smoke test → canary → live comparison → immutable versioned bundle → pinned stable launcher; explicit rollback. | No silent launcher retarget, old version hash changes, client startup errors or nonreproducible build. |

### Global action priority

1. Native game safety, manual user input, menus/text and unload.
2. Capture/escape and active native minigame deadlines.
3. Attack/bite and ability release/cooldown transitions.
4. Feeding, drinking, carrying/rescue, manual Rest.
5. Automatic health/condition recovery when otherwise eligible.
6. Controlled movement, terrain traversal, hunt/route/territory work.
7. AFK and cosmetic/background scans.

The exact order is contextual, not a blind global mutex: **condition recovery can coexist with the game's combat tag where live evidence supports it, but must yield before native attack input**. The arbiter needs a formal compatibility matrix and transactional release/restore; a mere ordered sequence of if-statements in separate modules is insufficient.

## 4. All 22 visible Renaissance features — upgrade specification

| ID | Feature | Highest-value concrete preparation target | Primary acceptance |
|---|---|---|---|
| R01 | Infinite Stamina | Audit and reconcile each captured drain calculation: land walk/sprint/Burst, jumps, swim, climb tiers/species, flight flap, venom and ability movement. Keep native ability restrictions and avoid resource attribute overwrite races. | A controlled, sustained native action matrix shows expected stamina retention across eligible animals/modes without a later unexplained drain/snapback. |
| R02 | Active Recovery | Preserve genuine native Rest(true) ownership, original same-character provenance, anti-pose mask and first-attack handoff. Independently test moving, stationary, post-movement, out-of-combat and combat transitions; ensure desired continuous eligible uptime. | Same-max-HP matched rates and active signalling indicate actual change; zero unintended resting poses, missing first bites or restart oscillations. |
| R03 | Fast Negative-Effect Recovery | Decouple condition clearance from the HP combat rule. Preserve the native condition Rest path for injury/bleed/venom, including temporary replicated-value gaps, and avoid treating missing attributes as cured. | Each of all three numerical status variables falls faster than its matched OFF control when eligible, with proof shown per condition rather than grouped. |
| R04 | Roblox Anti-AFK | Confirm one owned idle listener/input backend, ability to restore, idle signalling and uninterrupted manual controls; distinguish platform prevention from game-specific session migration. | Measured uninterrupted session in a controlled unattended trial, no unintended movement or retained listeners after OFF. |
| R05 | Survival Bonus AFK | Use native survival-credit state, geometry-safe micro-walk, revalidated nearby danger, interruption and no looped false activity. | Replicated survival credit actually advances while safely idle; no unsafe step or false “bonus preserved” claim. |
| R06 | Automatic Minigames | Audit first safe Perfect window, server-clock uncertainty, callback discovery, matching own result, manual-input coexistence and deadline wakes. Optimise timing-critical path before decorative UI work. | Real strike grade distribution and submission delays compared with ordinary baseline; no fabricated grade, duplicate press or loss of ordinary bite controls. |
| R07 | Auto Escape | Use actual native tug/shake cadence and lock state, respect friendly baby carry, priority of grab minigames and native capture state. | Repeated live carry/pin/escape cases progress without sending wrong action or getting stuck. |
| R08 | Permanent Bite Reach | Review native geometry, body gap, rear/tree/vertical choice, affiliation/protection exclusions and whether any client-side extension is accepted. | Measured native-hit marker, actual game reply and target HP change separated; stock-range fallback when extended-only attempts fail. |
| R09 | Bite Range Helper | Keep the small smooth marker only; correct spatial sampling, motion smoothing, occlusion, Cobra range colouring and one selected target. No recurring large text square. | Correct stable cue at 30/60/144 Hz, even under player motion and crowded/tree combat, with no screen-blocking overlay. |
| R10 | Combat Core | Remove ghost-hit presentation; native attack is never counted as accepted damage without matching evidence. Repair post-Rest first bite, stationary and moving targets, multiple enemies and ability cancellation handoffs. | Source-grounded action timing and live feedback rates. No duplicate bite request, missed input due to hub-owned Rest or false damage acknowledgement. |
| R11 | Climb Assist | Coordinate Q, native climb-eligibility, same-tree bite geometry, species climb profiles and clean transitions across jump, attack and dismount. | Cross-species/tree traversal + combat scenarios; no stranded input or unexpected auto-climb. |
| R12 | Flight Assistance | Reconcile native launch eligibility, water surface exit, airborne controls and talon/dive cancellation; handle Vulture/Eagle episodes without changing physics movers directly. | Repeated ability cancellation and flying-resume trials with no frozen movement or unintended pose and reliable native-mode cleanup. |
| R13 | Movement Assistance | Audit injury slow inputs and server correction while leaving status amounts untouched. Restore exact config on state changes. | Observable legal movement improvement where accepted, correct recovery of native values after disable. |
| R14 | Speed Assistance | Separate native sprint/Burst/trot state, HUD requested versus observed, denial pulses, water mode, Hippo Crusher forced gait and physical displacement. | No false sprint/Burst claims, actual speed measurements and no gait oscillations. |
| R15 | Jump / Leap Assistance | Species-specific jump/leap configuration, zero/excluded bodies, timing during combat/climb/flight and exact rollback. | Real accepted leap displacement and collision safety across supported species. |
| R16 | Outline ESP | Keep hollow, real-player-only, streamed and ownership-checked highlights; manage target visibility and through-wall option without leaks or extra render cost. | No NPC outlines, stale outlines, fills, runaway Highlights or stale player bodies. |
| R17 | Faction / Health Colours | Pack affiliation remains distinct from health gradient; real replicated pack is used regardless of claimed/disguised names. Unknown affiliation is not guessed. | Controlled same/other/unknown cases with correct stable name and outline colours. |
| R18 | Name Tags | Compact name presentation, independent ON/OFF, occlusion/screen-edge handling, stable positioning and no visual text collision. | Legible player-only tags with smooth updates and no position/flicker regression. |
| R19 | Long-Range Player Finder | Efficient target candidate index, correct streamed counts, bounded nearest-first results and adjustable range. | Correct 300/600/900-stud views and stable sorted count with large populations. |
| R20 | Right Shift Menu | Preserve one open/close hotkey, focus guards, native sprint interaction, tab switching, drag/fit/scale and clickable controls. | Right Shift reliably opens/closes once, never leaks to the wrong native action when possible, and every toggle responds. |
| R21 | Saved Settings | Schema-validated true/false, previous format migration, backups, readback, hot-reload reconciliation and fresh-install defaults. | All controls restore deterministically; explicit OFF survives reload; no accidental enabling after corruption. |
| R22 | Zoom Unlock | Reversible camera min/max and mode lease that coexists with game's camera updates/first person and full unload. | Expected wheel zoom range in real camera use, exact external-value restoration and no GUI conflict. |

**Cross-feature goal not currently established as a working feature: REDUCED INCOMING DAMAGE.** Investigate only the *real incoming-damage calculation/replication path* and legitimate defensive states/abilities first. Current source proves neither a server-accepted damage multiplier nor a universal damage-negation method. Document target selection, controlled equal-damage incoming hits, same-species/growth baseline, own observed HP delta and server corrections. If no accepted client pathway exists, report unavailable; do not substitute a visual HP overwrite or claim success from a lower local number.

**Specific current integration defect:** the 15.7.1 candidate runtime/controller version is 15.7.1 but the current UI file still contains hard-coded “RENAISSANCE / 15.7.0”. Fix by binding displayed version to the active controller in the implementation phase, and add a packaged-bundle UI-version regression. This prep does not change it.

## 5. All 14 core implementation modules — mandatory owner review

| Module | Responsibility | Deep review / upgrade decision |
|---|---|---|
| core.luau | Feature registry, reversible leases, evidence ledger | Typed lifecycle/ownership, clear requester-vs-applied-vs-observed separation, conflict recovery policy and bounded ledger. |
| settings.luau | Schema/backup/save | Complete switch round-trip, corruption recovery, explicit OFF precedence, migration to future settings schema without surprising defaults. |
| policy.luau | Cross-feature priorities | Replace accidental interactions with explicit action compatibility and native eligibility; test unknown combat timing, manual provenance and cooldowns. |
| grab.luau | Native minigame state/timing | Prove earliest legal Perfect-window dispatch and packet/session identity under jitter, dropped frames and multiple attackers. |
| grab_input.luau | Native manual click isolation | Strong scoped lease and exact restoration; no softlock of basic combat during active minigames. |
| recovery.luau | Native Rest signal and pose | Separate continuous native eligibility from measured progress; unmask own pose only, zero rearm thrash, first-attack release. |
| feeding.luau | Manual feed ownership | Make actual resource gain the completion proof; protect approach, bound any repair, never mistake attack for feed input. |
| combat_input.luau | Post-Rest attack handoff | Race-free first bite retry bounded to one session and native cooldown; never duplicate or forge hits. |
| rescue.luau | Cub pickup, jump/water exit | Validate native carry restrictions, cancellation, species and target generation. |
| features.luau | Config plans, stamina/speed/reach/Hippo | Source-v2412 config identity contracts, exact lease restore, native gait constraints and no hidden overlapping writers. |
| roblox.luau | Service boundary and native introspection | Read freshness, narrow native discovery, input provenance, scoped event wiring, geometry/occlusion/candidate cost, version drift fingerprint. |
| zoom.luau | Camera state | External-change preservation, first-person interoperability, late camera replacement, exact release. |
| ui.luau | Five tabs, markers, ESP, info | Version from runtime; all rows clickable, status distinguishes outcome, tiny marker, smooth tracking, adaptive scale; preserve simple UX. |
| controller.luau | Scheduler, feature coordination and lifecycle | Split 816-line controller responsibilities behind interfaces without splitting ownership. Single predictable startup/stage/activate/unload and fault containment. |

## 6. All 12 integrated Territory modules — mandatory owner review

Territory remains **OFF unless manually started**. This is still an official part of the full-hub overhaul even when the user does not farm.

| Module | Concrete completion target | Evidence gate |
|---|---|---|
| ledger.luau | Real wall/active/pause/unknown clocks, mode distribution, objective completions, Amber inflow/outflow and cost p95/p99. | No double counting or outcome invention, including long frame gaps. |
| model.luau | Reusable actual-position route cost and traversal graph, measured directed costs, expiry, terrain identity and route-local learning. | Measured predicted-versus-observed route error and stable degradation for unknown passages. |
| planner.luau | Priority/time strategy, scent deadline slack, proper root ownership, fair distant work and steady-state full-map capacity/overload decision. | Known and unknown deadline scenarios, sustainable workload proof or honest impossibility. |
| gait.luau | Requested/observed native Sprint/Trot/Burst, denial, hysteresis and species locomotion switches. | No contradictory gait requests; actual displacement checked. |
| nav.luau | Body-safe forward routes, incline/overhang/shoulder support, streamed terrain, expensive path jobs, stuck loops, water banks and long routes. | Real terrain transition matrix and bounded recovery, with no continuous ping-pong or unattended falls in supported cases. |
| hunt.luau | Viable target commitment, intercept/turn/contact, native bite availability, target HP observations and corpse handoff. | No indefinite pursuit of faster/unreachable prey; no “kill” without strong observed completion. |
| care.luau | Native nutrition and hydration with validated maxima, missing-resource acquisition and resistant-stall handling. | Hunger/thirst actually rise to targets, not merely an input/animation. |
| agent.luau | Global objective arbiter, interruption/return chain, last-good goal and manual pause/resume. | Multi-hour simulated and repeated live goal continuity across care, threat and claims. |
| bridge.luau | Native world/survival/candidate profiles, movement/mode/care interfaces, shared core adapters and generation caches. | Known/partial/unsupported per species, actual native attack/feed interactions, no stale references. |
| driver.luau | PlayerModule/native move callback ownership with alternate digital backend. | Real input controls movement, restores exactly and does not override genuine user motion. |
| ui.luau | Compact integrated Territory page and useful honest progress/cost labels. | Correct START/STOP, no separate conflicting menu, no hidden background action after OFF. |
| runtime.luau | Construction, owner handoff, loop, status, STOP and unload. | One engine only; clean shutdown on partial init and all faults; no automatic startup of farming. |

**Open Territory requirements carried forward explicitly:** native climb/flight/underwater-depth route adapters; all-species real support matrix; steady-state whole-map coverage/overload; meal energy/risk economics; bank/shoreline and mountain calibration; live verified prey attack, drink, eat, claim and scent completion; actual Amber/hour and multi-hour survival; device p95/p99; live STOP/reload; selected opt-in status privacy. No “all animal automatic” claim before those gates pass.

## 7. Collision and regression matrix

| Simultaneous events | Required outcome | Blocking regression |
|---|---|---|
| Recovery while moving / entering surface water | Eligible Rest signal continues; local pose stays locomotion, not Rest. | Rest pose while moving; 2x/4x label without measured effect; unexpected restart. |
| Rest while first bite begins | Owned Rest is released early enough for native bite eligibility; no stolen manual input. | Native marker absent due to hub-owned Rest; repeated phantom bite retry. |
| Recovery plus venom during combat | Condition request remains possible where native rules allow; combat HP claim remains excluded. | Condition Rest cancelled solely by combat tag/unknown timestamp. |
| Minigame plus simultaneous attacks | Exact own session/strike matching; time-critical Perfect input and basic bite coexist. | One hunter's result ends another's strike; camera click becomes strike; bite inhibited. |
| Attack/ability while feeding | Native action has clear owner; feed approach is not misread as stopped; explicit cancellation is respected. | Hungry animal stuck at corpse/pond; feed restarted indefinitely. |
| Ability cancellation in flight | Native release observed; Vulture/eagle remains movable; no anchor/mover corruption. | Frozen gliding/hovering after talon or dive cancellation. |
| Hippo Crusher Bite plus Shift/X/Z/swim | Native forced gait scalar only when intended, Burst denial respected, restore on end. | Trot/Burst toggles fight or permanently alter speed. |
| Climbing plus tree combat | Same-tree eligible range/height aligns with native input, with no continuous Q spam. | Ghost hits/blocked attack/movement on a shared tree. |
| AFK plus active manual play | AFK movement immediately relinquishes ownership and never reclaims it during action. | User fights automatic movement; stamina or survival incorrectly attributed. |
| Core recovery plus Territory care | One Rest owner, no redundant Rest cancellation; urgent health and feed goals resolve deterministically. | Territory stuck waiting for unavailable HP regeneration or overwrites Rest. |
| ESP/guide while menus/low FPS | Cosmetic tasks yield to input and critical minigames; stale visuals removed. | Lost frames or unresponsive UI due to rendering. |
| Reload/respawn/unload during any action | All callbacks, inputs, attributes, camera values, synthetic pulses and GUI destroyed/restored once. | Ghost input, old GUI, held gait, stale chase or multiple control loops. |

## 8. Proposed execution phases (not work already completed)

**P00 — evidence freeze and reproducible build.** Enumerate exactly all 26 modules, 22 controls, native dependencies, release assets and game-v2412 fingerprints. Pin 15.7.0 rollback and candidate 15.7.1, prevent test drift, acquire baseline actual-play outcomes before any behaviour change. Output: versioned evidence ledger and overlap map; no gameplay patch.

**P01 — central compatibility/lifecycle correctness.** Introduce versioned snapshot contracts, single action/lease table, cancellation generations, deterministic restoration, recovery/manual/ability event order. This is a surgical architecture change with baseline parity tests; do not rewrite all modules in one unreviewable commit.

**P02 — genuine survival/defence.** Functional fixes to HP recovery, condition clearance, stamina/needs handling and incoming-damage pathway *only when a real native path exists*. Compare server-observed own values, distinguish battle from out-of-combat, preserve first-bite latency and animation. Include required safety fallbacks.

**P03 — combat and timing.** Native bite lifecycle, post-Rest first hit, tree/rear contact, target selection, ghost-hit removal, multi-hunter minigame timing, rescues and escape. Same native result ID and actual-time semantics retained.

**P04 — locomotion and every species mode.** Ground → burst → steep slope → climb → air → water surface → underwater/depth route transitions where native interface actually supports them. Vulture/other native flight handoff, Hippo Crusher, swim, dive and ability-specific exceptions. Unknown mode remains unavailable until validated.

**P05 — hunger, thirst and survival continuity.** Native feed/drink acquisition, approach, contact, resource gain, retry limits, no stuck stationary phases, idle-credit and Roblox anti-AFK. Build realistic resource-limited integrated scenes; feed results must be actual own needs increases.

**P06 — complete Territory.** Retain T01–T44 and S01–S62; close T21 steady-state whole-map capacity, T38 multi-mode traversal and the remaining live acceptance deficits. Do not conflate autonomous claimed goals with measured rewards.

**P07 — UI and graphics polish.** Make native hub version dynamic; no controls disappear, all controls clickable and scroll/focus safe, simple standard layout, calm truthful states, compact visual cues, independent labels and responsive menu. Preserve all existing options but reduce user configuration burden.

**P08 — performance/stress/soak.** Lower per-frame native scans and allocations where measured; calibrate actual reference-device p50/p95/p99, bound caches/listeners, test 30/60/144 FPS and 10/30/120-minute sessions. No blanket performance promise from microbenchmark alone.

**P09 — integration and release.** All suites green at pinned Luau revision, zero known critical cross-feature regressions, repeated paired live checks, rollback verified, candidate source/manifest parity, separate immutable release, then deliberate launcher promotion.

Each phase requires: (a) known failing reproduction or proof of a missing feature, (b) specific source-grounded mechanism, (c) changed behaviour, (d) automated regression and (e) live outcome or explicitly open live gate. Avoid speculative giant refactors with no measured benefit. Keep a checklist of every remaining preexisting issue.

## 9. Mandatory acceptance programme

### Automated engineering gates

- Official pinned Luau compilation of every new/changed module, complete combined bundle, loader, UI and test source.
- Preserve all 206 candidate core cases and 263 Territory cases as a minimum regression floor (after PR #13 is selected as the candidate foundation). Add tests, never delete a failed test solely to make the total green.
- Exact module source-to-bundle parity, deterministic manifest, immutable earlier hashes, branch protection/review, fresh-start smoke and stage-only no-gameplay-mutation checks.
- Fault injection: unavailable/replaced module and remote, bad snapshot values, delayed native echo, external config mutation, rejected input, mid-callback unload, async stale path, missing PlayerGui and camera replacement.
- Full local scenario matrix including long frame hitches, 30/60/144 Hz, 1/3/many enemies, multiple minigame participants, animals switching states, text focus, manual attack, game menu, movement, flight, carry, feed, swim and death/respawn.
- Evidence outputs must show failures and their first causal trace, not just cumulative PASS or high event counts.

### Live gameplay evidence (mandatory before describing an effect as working)

1. **Recovery 2x:** equal species/growth, unchanged MaxHealth, comparable hunger/thirst/combat, sufficiently large HP deficit, multiple time-window ON/OFF comparisons while standing and moving; calculate percentage-of-maximum HP per second; exclude growth, damage and full-cap saturation.
2. **Status recovery 4x:** injury, bleed and venom independently, capture numeric amount before/after, match conditions and combat windows, distinguish nil/removal from numeric decrease and note replenishment by new bites; do not infer fourfold speed from a displayed multiplier alone.
3. **Damage taken:** controlled equivalent incoming attacks on the same own animal/matched stats, separate raw own HP changes from growth and armour/ability modes; report whether observed damage is accepted/replicated rather than only locally rendered.
4. **Combat:** genuine native hit marker, game damage reply and target HP trend separately, multiple bites per animal, side/rear/tree targets, busy scenes and ability interruptions. A bite sound by itself is not a confirmed hit.
5. **Minigames:** known session ID and native start timestamp, actual own grades, dispatch latency and Perfect rate; test multi-attacker contention without invented extra strikes.
6. **Movement and stamina:** actual root displacement and native gait state, failed state transitions, ground/water/slope/climb/flight/depth, repeated Vulture talon end, Hippo ability; consider server rubber-banding/reverts.
7. **Survival/AFK:** resource trend with realistic needs, normal manual interaction, extended idle survival credit, no forced server-change assumptions.
8. **Territory:** valid claim/scent progress and server-side-visible completion, region boundary entry/exit, full-map workload, observed Amber delta, 10/30/120-minute sessions over representative native diets and body types with no manual interventions.
9. **Lifecycle/UI:** install/rejoin/hot reload, persisted OFF, initial lobby/spawn/match change, Right Shift focus, mouse/gamepad/mobile controls where supported, rollback and unload while every active feature owns some state.
10. **Device:** real FPS frametime and memory traces, detection of contention in high player/animal density, action latency at the critical percentile and reconciliation with sampled telemetry.

### Comparative quality scorecard

Use a baseline versus candidate ledger with build SHA, game PlaceVersion, species, location/biome, input platform, time window, hardware, ping where available, other active features, sample count, median/percentiles, success/fail count and causal failure notes. Suggested **release gates**, to be calibrated from a real baseline rather than asserted as today's achievements:

- **Correctness:** zero unresolved P0 regressions; no native input hijack, no incorrect status of successful healing/damage/reward, no stale callbacks after unload.
- **Reliability:** no repeatable unbounded retry, route oscillation, new lockup, native-state softlock or infinite wait in supported scenarios; exceptions surfaced and reversible.
- **Responsiveness:** a timing-critical event must not await nonurgent scans/UI; measure dispatch latency and input-to-effect timing instead of promising “instant”.
- **Progress:** a user-facing improvement must beat the prior candidate in repeated paired play, or remain an experiment; automated tests alone do not count as live improvement.
- **Performance:** no sustained reference-device FPS/frame-time regression beyond measured baseline variation, with bounded caches and no growth in live-owned listener/task count during repeated restarts.
- **Truth:** per-feature support is IMPLEMENTED, SIMULATED, LIVE-OBSERVED, UNVERIFIED, PARTIAL or UNAVAILABLE; these statuses have evidence, not marketing.

## 10. Research and tool boundaries

Existing captures reference v2412 and 943 verified catalog payloads. Verify current PlaceVersion before treating old offsets/native calculation prototypes as up to date. New capture should be **targeted to a concrete changed contract**, never a generic full dump or indefinite decompilation. Source outside local ownership, server-only code and other clients' hidden state cannot be assumed present. In-game code should avoid unsafe arbitrary remotes and treating a client HUD change as credited server state.

Roblox's official ContextActionService documents priority-based input routing; use it to validate native binding conflicts rather than guessing. Roblox's RunService documentation warns that render callbacks block visual updates and must be fast; use it to plan the animation/ESP budget. References:
- https://create.roblox.com/docs/reference/engine/classes/ContextActionService
- https://create.roblox.com/docs/reference/engine/classes/RunService
- https://create.roblox.com/docs/studio/optimization/memory-usage

No background task, external telemetry upload or real-game server interaction is part of this preparation. An authorised live Roblox/Potassium session would be a separate implementation/acceptance step. Any credentials, IDs and user-private runtime dumps should remain local unless explicitly shared for a concrete purpose.

## 11. Definition of complete and non-complete

**The complete-hub milestone is achieved only when** all 22 feature records and integrated Territory capabilities have individually passed their attainable functional gates; every known cross-system collision is resolved or explicitly unsupported; 26 modules and their user-facing interfaces are version-consistent; all regression suites, source hashes and rollback checks pass; all relevant server-visible claims have repeated live evidence; and a stable release is deliberately promoted.

**Do not call it complete** because tests are green, a config was applied, Rest(true) was sent, a pose was masked, a simulated two-hour run succeeded, a native attack fired, a path was computed, or the menu displays “ON”. Those are narrower engineering signals. If server authority prevents an effect, say so precisely and optimise permitted behaviour instead.

## 12. Explicit future-work handoff — execution contract

When implementation is authorised, read in this order:
1. This master document.
2. Renaissance release.json, docs/ARCHITECTURE.md, docs/FEATURE_AUDIT.md and docs/LIVE_EVIDENCE.md.
3. Territory docs/PREPARATION_EXECUTION_LEDGER.md and docs/V0_7_SCENARIOS.md.
4. Exact 15.7.1 PR #13 diff and passing CI; confirm whether it is merged before selecting the implementation baseline.
5. All 14 core + 12 Territory source files and both pinned test runners.

Then produce a fully enumerated issue ledger mapping every R01–R22 row and T01–T44 row to observed symptoms, native contract, owner, proposed patch, proof and acceptance. **Change code only after this preparation handoff**, keep branch-by-branch review, avoid side-effectful fake fixes and require actual user-visible functionality.

### Non-negotiable next implementation order

First fix lifecycle/version mismatch and recovery/combat interference with native proof. Next correct timing-critical minigame/combat and stamina/movement handling. Then complete feed/survival and each native locomotion mode. Finish all 44 Territory requirements, update the compact UI, profile under real load and ship only after a thorough release gate. Territory stays default OFF; main launcher stays pinned until an intentional promotion.

---

**Document status:** a research- and source-grounded execution preparation; deliberately no gameplay changes, no unverified guarantees, no new release.