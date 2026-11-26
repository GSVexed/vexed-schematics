# FERAL Renaissance — One-Shot Pro Full-Hub Overhaul Execution Directive

**Prepared:** 26 November 2026  
**Status:** execution handoff; preparation only; not an implemented feature or live-game validation.  
**Objective:** maximize the entire repository-wide FERAL overhaul in **one substantial execution**, not one PR or conversational reply per phase. Do not stop after planning, a diagnostic, an isolated fix, a successful compile, or the first completed workstream. Carry out research, implementation, testing, iterative debugging, integration and delivery in the same response to the extent available tools and execution capacity permit.

## A. Source of truth and project state

Repository: **GSVexed/vexed-schematics** (default branch main).  
Game: Roblox **FERAL Animal Survival**; latest known source-capture baseline v2412, **which must be rechecked** before assuming native interfaces still match.

Project state at preparation time:

- **Stable:** Renaissance 15.7.0 with integrated Territory 0.7.0, on main. Stable launcher must not be silently overwritten.
- **PR #13:** https://github.com/GSVexed/vexed-schematics/pull/13  
  Branch renaissance/v15.7.1-recovery-stall-repair, HEAD da2145a4903e04e365cbeb4387825658d1f65a35. Native Rest signaling, condition clearance arbitration and recovery default. Unmerged draft; reported CI: 206/206 core, 263/263 Territory. **Not proven live 2x/4x.**
- **PR #14:** https://github.com/GSVexed/vexed-schematics/pull/14  
  Branch renaissance/whole-hub-perfection-prep-2026-11-26, HEAD aa825b243fe63179e4a58c35a9fb1e1d881217db prior to this handoff. Preparation only. Three crucial documents:
  1. roblox-tools/renaissance/docs/FULL_HUB_PERFECTION_PREPARATION_2026-11-26.md
  2. roblox-tools/renaissance/docs/FULL_HUB_PERFECTION_ACCEPTANCE_MATRIX_2026-11-26.md
  3. roblox-tools/renaissance/docs/P0_COMBAT_GHOST_HITS_AND_MISSING_BITES_PREPARATION_2026-11-26.md
  These cover all 22 controls, 14 core modules, 12 Territory modules, H001–H070 scenarios, U001–U019 issues, G01–G18 release gates, historical Territory T01–T44 and S01–S62. **Treat as mandatory specifications, not completed work.**
- **PR #15:** https://github.com/GSVexed/vexed-schematics/pull/15  
  Branch renaissance/phase1-combat-recovery-integration-2026-11-26, HEAD bcc9c3699b41b6a2bd74a2d91324a493ee48b2c2. Draft; base is PR #13 branch rather than main. Integrated 15.8.0 candidate:
  roblox-tools/feral-renaissance-v15.8.0.lua
  SHA256 ba69a1efae61f2241d370aec2f9d8564cd8b3317e40c5afef114d654061ddb30
  Official Luau/Renaissance 214/214 and Amber/Territory 263/263 service-boundary tests passed, including deterministic bundle parity. CI workflow references:
  https://github.com/GSVexed/vexed-schematics/actions/runs/45746210964
  https://github.com/GSVexed/vexed-schematics/actions/runs/45746210958
  Improvements: advance release of owned Rest near native-stock bite contact, stock-valid target priority, marker-time target freeze, better hit feedback matching and dynamic UI version. **In-game attack hit-rate improvement remains unverified.**

**Before making changes, re-read actual GitHub state.** Verify whether PRs have merged or branches moved. Do not accidentally base the next candidate on main and drop #13/#15 work. Use an independent feature branch based on the newest validated integrated candidate and consider the preparation docs from #14 even though that PR is not merged. Do not destroy the stable loader, old history or user files. The required output is **one consolidated final candidate**, built through any number of internal commits and retries.

## B. What the user means by "perfect"

The user wants **every possible substantive improvement** to a long-running FERAL hub: rapid, dependable, robust, cohesive, minimal UI complexity, consistent animal movement and combat, no regressions, full integration, sensible default operation, and accurate live results. This is **not** a request for another diagnostic-only pass or a parade of small version releases.

Core user pain points:

1. **Active HP recovery:** automatic recovery should stay eligible and function when expected even during ordinary walking/running and swimming; **no physical Rest animation while moving**. Keep manual Rest independent. Combat HP regen exclusions must follow proven native rules; do not claim or fake combat healing.
2. **4x negative effects:** independent venom, bleeding, injury clearance; where accepted, continuously request the actual native effect path, including combat if supported. Never equate nil with a cured zero or a local status/config edit with accepted healing.
3. **Ghost hits and missed bites:** actual eligible primary attacks and first bite after Rest fail or produce sound/animation without accepted target damage; moving prey, stationary prey, rear/side geometry, high latency and animals on the same tree are important. Repair native input/Rest conflicts, real target selection and feedback; do not merely remove misleading hit indicators.
4. **Minigames:** fast native legal Perfect-window reaction, in dense multiplayer and variable FPS; preserve real native grades and normal manual input. A mock Perfect isn't a result.
5. **Stamina and movement:** stamina behavior in land sprint, jump, climb, swim, flight and venom; native sprint/trot/Burst changes, Hippo charge/Crusher, animal abilities, jump/leap, terrain navigation, flight, water entry/exit and Vulture/Eagle talon/dive early cancellation and freezing.
6. **Feeding and survival:** approach, hunt, bite, harvest/eat, drink, hunger/thirst gain, rescue, carry, anti-AFK and survival bonus under realistic native conditions. No endless pose/feeding/route loops.
7. **Territory:** preserve full integrated Territory automation including claim/scent, hunting, drinking, navigation and return continuity, but **default OFF** because user is not currently using it. Complete incomplete T01–T44 / S01–S62 work instead of wiping it.
8. **UI/ESP:** Right Shift one-menu toggle, fully clickable controls, persisted settings, streamlined interface without feature removal, small smooth bite-range cue, no large obstructive text overlay, Cobra colours only on Cobra and correct affiliations/health/name/outline/finder, camera zoom.
9. **Performance and lifecycle:** frame-sensitive input, bounded scans, no duplicate loops or excessive allocations; exact cleanup, respawn, game lobby/match transfer, native/manual precedence, reload, game-version drift, service gaps, reconnect and recovery.
10. **Reduced damage taken:** investigate actual inbound damage/defense and status pathways. Only implement an improvement if the game accepts it; do not substitute a client HP repaint or assert invulnerability without durable evidence.

Potential server-side constraints are real. A polished client signal isn't proof of 2x/4x healing, guaranteed damage, hitbox expansion or faster validated minigame results. Investigate authoritative game behavior honestly, improve legal/native input timing and functional outcomes wherever possible, and label unsupported/unverified paths precisely.

## C. Scope — none may be silently dropped

**All 14 Renaissance modules:** core, settings, policy, grab, grab_input, recovery, feeding, combat_input, rescue, features, roblox, zoom, ui, controller.  
**All 12 Territory modules:** ledger, model, planner, gait, nav, hunt, care, agent, bridge, driver, ui, runtime.  
**All 22 feature records and settings/UI behaviors:** stamina, recovery, negative-effect status, Roblox anti-AFK, survival AFK, minigames, escape, bite reach, bite guide, combat, climb, flight, movement, speed, leap, ESP, pack/health colour, nametags, finder, menu, settings, zoom.  
**Historic project dependencies:** native FERAL v2412 captures and traces, scripts and evidence files in roblox-tools, integrated Amber/Territory ledger, tests, runner, protected rollback bundles and manifests.

Read every module before declaring it "reviewed"; construct a feature → owner → native state → shared callbacks → risk → tests crosswalk. Use this as an execution checklist, not an excuse to spend the entire message compiling another research report.

## D. The single-run implementation method

Carry out the following *internal workstreams* in **one continuation**. Do not stop to seek approval between them. Stop only if a truly essential missing input/permission prevents all further useful work; otherwise move to the next independent task and record the blocker for the final handoff.

### Workstream 0 — Verify and stage

- Check repo, PRs, branch commits, signed/immutable releases, CI baseline, test runners and game captures.
- Read all three PR #14 docs and the code in #13/#15 (their branch dependencies matter).
- Create one fresh isolated implementation branch. Preserve main 15.7.0 and all rollback sources. Resolve branch drift explicitly.
- Run or confirm baseline tests, verify provenance, build/source parity and compiler availability.
- Establish an objective ledger of 22 features + Territory items, with current status and no invented "PASS" flags.

### Workstream 1 — Fix cross-module control ownership

- Ensure one predictable owner for automatic native Rest, manual Rest, bite input, grab minigame presses, feeding, carrying, flight, climb, gait, AFK and Territory movement.
- Add or improve explicit priority, cancellation token/generation, input provenance, timestamps, scene snapshots, unknown-state handling, reversibility and resource lease conflict arbitration.
- Preserve native manual interaction: keyboard/mouse/gamepad, Right Shift, LMB/camera, abilities, normal feeding and handoff. No handler should steal unrelated input.
- Guarantee clean OFF/unload/hot reload/respawn: restore exactly owned values, no stale queues, no old animal actions, no frozen movement, no duplicate signal listeners.
- Surgical changes with tests; do not replace a working engine with a speculative giant rewrite.

### Workstream 2 — Repair survival and recovery mechanisms

- Prove why an eligible native Rest signal does/doesn't persist. Ensure no unwanted Rest pose while moving; manual resting must remain truly native; first bite/ability transition must not be blocked.
- Optimize genuine native 2x HP and 4x injury/bleed/venom paths, independently and across combat eligibility, idle, walking, surface water and character changes.
- Confirm actual resource consumption and status math; avoid pointless periodic local overwrites or silent UI promises. Reconcile stamina and movement mode drains, feeding/drink needs and survival bonus.
- Investigate actual incoming damage calculation and native defensive abilities. Implement only provable paths; fail gracefully if authoritative limitation.
- Add before/after objective telemetry that can be replayed without causing frame-time regressions or claiming observed values from a mock.

### Workstream 3 — Fix missing bites, ghost hits and minigames

- Native action pipeline: user's intended input → actual game's attack callback → cooldown, Rest/ability/capture/feeding gates → WolfBiteAt and native candidate → game hit reply → replicated target HP/MaxHealth.
- Eliminate hub-induced lost clicks (especially immediately after recovery), duplicates and misplaced delayed native retries. Prefer stock-eligible targets to purely speculative client range. Preserve native player controls.
- Correct target choice for moving, rear, side, same-tree/vertical and high-latency cases; distinguish local SFX from actual acceptance; never fake damage.
- Complete H061–H070 and carry forward all older bite tests. Preserve other-player/protection exclusions.
- Audit genuine minigame legal input windows, native strike/session IDs and results; optimize deadline scheduling, multi-attacker contention and input arbitration. Do not claim 100% Perfect absent live evidence.
- Native abilities, flight attack cancel, Vulture frozen-glide, cub rescue/carry, tree bite and swimming interaction must be jointly stress-tested.

### Workstream 4 — Movement, hunt, care, Territory

- Fix all animal locomotion transitions with native mode/physics authority: sprint/trot/Burst, surface swimming, getting in/out of water, altitude, climb/trees, leaps, flying, flaps, talon/dive cancellation, terrain, slopes and root support; handle species limitations explicitly.
- For automated hunt, prioritize viable prey and actual native hit/HP, intercept rather than endless trailing, animal body dimensions, finite resources, corpse pickup/feed, true hunger gain and water acquisition; no false hunt success.
- Complete missing Territory navigation/climb/flight/depth mode support or explicit supported fallback; full-map steady-state claim/scent maintenance capacity, cost/priority scheduler, return-to-work continuity, stop/unload cleanly, realistic multi-hour survival.
- Territory stays OFF by default; regular core features must work independently. No underground/fake claim, server-only state assumption or forced teleport that cannot be validated.
- Coordinate recovery, combat, feed, minigames and motion without ping-pong or stuck pose.

### Workstream 5 — Polish performance, settings, UI

- Improve modular architecture, CPU/GC and signal-cost hotspots; avoid render callbacks that block the engine or broad repeated native scans. Optimize actual critical-path input first.
- Make the UI cohesive, compact, stable, accessible, correctly versioned; keep every control and default state, preserve existing user settings and an explicit OFF, one Right Shift action and unobstructed game controls.
- Correct ESP classifications, chams outline colours, player tags, health gradients, Cobra-only guide colouring, no giant text overlay, fluid 30/60/144Hz cue, zoom and finder behavior.
- Make failure states truthful, not an unreadable flood of diagnostics.

### Workstream 6 — Independent validation, fix loops and one final package

- For every changed function: add direct regression(s), compile under pinned official Luau, run all Renaissance and Territory tests (>=214 + >=263 baseline if newer suite count has not changed), plus stage/reload/unload, old-bundle preservation, deterministic source/bundle SHA256 and restored settings contract.
- When CI fails, read actual failed test/job logs, fix root cause, rerun; do not delete, weaken or rewrite a valid failing test just to make green.
- Test missing modules/remotes, unknown game schema, manual Rest, click after Rest, concurrent bite feedback, Minigame input, water/climb/flight, hot reload and late callbacks, older settings.
- Where a native live game session is connected and authorized, run controlled **paired** real trials with unchanged-max HP and status amounts, native hit replies, actual target HP, stamina consumption, motion displacement, animal-specific state and survival credit. If live session isn't accessible, **do not invent results or claim perfection**: mark precise LIVE-UNVERIFIED items and prepare a minimal focused acceptance test, while finishing everything else.
- Produce **one consolidated versioned final candidate** (suggest a single major 16.x-style release identifier if appropriate), source/manifest, exact pinned one-line launcher for the candidate, release changelog, proof grid and rollback. Never silently change stable main launcher when live claims remain unverified.
- Commit and present a new draft PR. If safe, fully validated and authorized by existing repo workflow, complete the ready-to-merge state; retain stable rollback. Do not bury the output under a lengthy research narrative or lose the actual release artifact.

## E. Quality priorities and hard stop conditions

**P0:** hub freezes/ghost inputs/Rest pose while moving, attack doesn't initiate, wrongly attributed hit, first bite blocked, recovery and effects ineligible without reason, persisted OFF ignored, crash, broken rollback, stale character/loop or feature conflicts.  
**P1:** native 2x/4x behavior, minigame timing/accuracy, stamina, flight/swim/climb/ability handoff, hunting, real resource gain.  
**P2:** fully functioning UX/ESP, AFK, device performance, rare concurrency.  
**P3:** Territory live capacity and unsupported native traversal modes.  
Territory is in scope even while default OFF.

**Do not**:
- Close issues solely by adding metrics, retries, one more toggle or a higher displayed multiplier.
- Treat a client-only local HP/venom value as server-authoritative.
- Invent test passes, tool actions, compile results or live game outcomes.
- Ignore user-observed regressions because a mock passes.
- Overwrite older stable packages, drop feature settings, bypass acceptance gates or assume game PlaceVersion has not changed.
- Ask for new prompts after every workstream. Do as much as possible now.

**Meaning of "finish":** all applicable modules integrated and reliably tested; no unresolved code-level P0; one final coherent candidate; clear distinction between verified behaviour and constraints requiring live validation. A remaining untestable server-side effect should be explicitly labelled and should not prevent completion of unrelated components.

## F. Tooling and autonomy

Use available connected GitHub repository tools first; available execution/testing tools and official GitHub Actions as appropriate. Inspect schemas and workflow names. Do not imply that GitHub access equals access to the Roblox process, game server, arbitrary user PC files, or previous Work/cloud computer. Avoid doing nothing merely because direct local repository access is unavailable: exploit GitHub file read/write, PRs, CI, targeted commands, patches and documented evidence. If essential tools are missing, continue with the best available approach, deliver actual reproducible changes/patches and disclose the precise boundary.

No background work or promised future delivery. All deliverables must be in this single execution. Budget time for writing code and fixing CI rather than only producing investigations, dashboards and summaries.

## G. The final user-facing deliverable (must be concrete)

1. **Single release candidate:** exact GitHub branch, PR, commit SHA, bundle, manifest hash, loader and instructions; if build fails, explicit failure and valid fallback.
2. **Functional changes completed:** grouped by recovery, combat, minigame, movement, survival, automation, UI/performance, integration; link diff or source.
3. **Verification grid:** test counts actually run, CI URLs, successful cases, unverified live cases and P0 failures remaining.
4. **Evidence:** actual native-game observations where accessible; separate gameplay acceptance from mock/service-boundary tests.
5. **Rollback:** historical stable version and how to return safely.
6. **Truthful completeness assessment:** what is completed, partially complete, unsupported or blocked; no blanket "perfect" claim if server authority or missing live access prevents it.

### One-paragraph execution directive

**Execute the entire FERAL Renaissance perfection overhaul now, within this single substantial response. Read the full preparation and code, integrate and upgrade all 26 modules and every existing feature, solve the known recovery, combat, minigame, movement, survival, Territory and UI problems through genuine working changes, run repeated compiler/CI/regression repairs, and deliver one cohesive final candidate with an immutable rollback. Do not stop at a plan or Phase 1; proceed through internal workstreams without asking for further prompts. Do not fabricate unsupported server-side results or silently merge unverified gameplay changes into stable. If execution constraints leave work incomplete, maximize verified implementation and enumerate exact remaining blockers instead of claiming the project finished.**

---

*This is a task specification prepared for one high-effort Pro execution. It is not evidence that one message can guarantee all live-game and server-authoritative acceptance tests.*
