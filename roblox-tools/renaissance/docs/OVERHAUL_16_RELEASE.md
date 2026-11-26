# FERAL Renaissance 16.0.0 / Territory 0.8.0 — consolidated candidate

**Date:** 26 November 2026. **Release state:** implementation candidate; stable promotion withheld pending live acceptance.

This is a repository-wide implementation of the full-overhaul directive. All 26 modules were reviewed; 23 received targeted changes and three proven Territory components were retained after review. All 22 core feature records and the integrated Territory engine remain. The execution includes source, deterministic bundles, additional regressions, immutable rollback protection and a separate pinned candidate launcher.

It does **not** establish perfection or completion of all gameplay acceptance gates. No current live Roblox gameplay occurred. The [acceptance ledger](OVERHAUL_16_ACCEPTANCE.md) maps every H001–H070 requirement, issue and release gate to the available evidence and open work. The [native mechanism report](NATIVE_MECHANISMS_16.md) identifies captured mechanisms and their limits.

## Consolidated source and dependencies

| Input | Verified GitHub state | Integration |
|---|---|---|
| Stable main | `7dcd03d78d7b3701e1cc9980f3ece6b510c21a2b`; 15.7.0 | Stable launchers and release metadata unchanged |
| Recovery PR #13 | Open, draft, unmerged; `da2145a4903e04e365cbeb4387825658d1f65a35` | Already ancestral to the implementation base; sustained native Rest changes retained |
| Combat PR #15 | Open, draft, unmerged; `bcc9c3699b41b6a2bd74a2d91324a493ee48b2c2`; based on PR #13 | Exact implementation base; early bite readiness, stock-target preference and marker correlation retained |
| Preparation PR #14 | Open, draft, unmerged; `38169ffd31ca41724101333e5abbfdb684c382b7` | All four mandatory documents included unchanged |

Branch: `renaissance/ultimate-overhaul-2026-11-26`. The consolidated PR targets main so reviewers can inspect the full dependency chain at once; it does not silently merge or close the earlier PRs. The candidate's immutable source commit, hash, tests and stable rollback are recorded in [candidate.json](../candidate.json).

## Functional changes

### Recovery, negative effects and combat input

The native true-only Rest renewal from PR #13 remains: eligible deficits renew `Rest(true)` without artificial timed OFF cycles. Ground movement and surface swimming remain eligible; manual Rest, held attacks, native minigames, feeding, capture and incompatible movement retain priority. HP-only recovery still requires known out-of-combat state. Positive conditions can independently request native Rest even when HP recovery is ineligible.

The first-bite repair reserves the attack interval through the native stand-up delay instead of assuming every profile fits a fixed 1.1-second pause. The optional original-handler retry checks current native readiness, retains the original marker and generation, cancels after an already-observed bite or consumed UI click, and invokes the handler at most once. The native cooldown and private eligibility checks remain native. Missing private callbacks preserve ordinary input but cannot provide that optional retry.

Each condition now has its own bounded missing-attribute grace. Explicit zero ends that condition immediately; disappearance and negative sentinels cannot manufacture a cure. A failed Rest dispatch immediately unwinds its pose/provenance ownership. Native base regeneration and Rest factors are preserved, including unexpectedly larger valid profiles; the previous code could reduce a game's own base rate while trying to cap its multiplier.

Native shell defence was investigated rather than replaced with an invented universal modifier. The captured client has species-specific Rest/time-gated shell calculations; no universal accepted damage-reduction path or server handler was available. No local HP, injury, bleeding, venom or resource write is used to claim a benefit. Actual 2× HP and 4× condition improvements require matched current-server measurements.

### Targets, ghost hits and damage feedback

Native stock geometry now includes the original species cone bonus, validates target/root/Humanoid identity and protection, and ranks an unobstructed eligible target ahead of a blocked candidate. Territory hunting uses the same stock geometry with its existing conservative contact margins. Dense-scene visibility queries are bounded.

The controller preserves distinct input, native marker, local impact, game reply and same-MaxHP target observations. A delayed impact cannot attach to a newer bite whose claim is not yet due. Replies and HP observations can strengthen the original transaction for a bounded two-second post-claim window. A brief observed decline is retained even if the target later regenerates; growth or Humanoid replacement invalidates the comparison. Ambiguous overlapping same-target attacks remain unattributed. These fixes improve software coordination and evidence; they do not prove that extended client reach or a locally predicted impact is accepted by the server.

### Native minigames

Session polling/adoption and legal strike dispatch precede background Territory planning. A real issued strike can use a later valid interval if the final clock check misses its first interval; it never sends future or backdated timestamps. Temporary clock loss retains the pending native strike, while expiry and prolonged failures release ownership. A successful remote press remains successful if optional local UI annotation subsequently throws; ambiguous dispatch is not replayed.

Ended/replaced session IDs have a bounded retirement record. The no-pending-strike timeout now runs, stale UI reads are contained, and invalid/focused/ended manual callbacks pass input through. The ordinary attack path is preserved outside the actual native session. When Minigames is explicitly OFF, passive observation takes no input lease and sends no presses, but still tells recovery, AFK, flight, rescue and Territory to yield to a real native minigame. Native grades remain the only grade evidence.

### Movement, species abilities, stamina and survival

Config ownership now tracks nested tables as well as top-level ModuleScripts: replaced sprint, climb, leap, negative-effect and combat subprofiles cannot leave detached edits behind. Duplicate aliased targets are deduplicated. External changes to the stamina flag, Hippo cap or another owner's field are preserved when the hub releases its lease. Fixed-offset private callbacks and the captured Hippo scalar adapter require the verified capture version rather than silently assuming a later build matches.

Held gamepad attacks now inhibit Rest like mouse attacks. Canonical dive state and immediate dive transitions participate in mode priority. Talon release follows the actual native cancel binding and current flight capability, including eligible Eagle paths, and remains distinct from Dive. Surface-flight requests own and restore only their own temporary attribute; timeout, disable and unload cannot strand it. There are no forced velocity, anchor or opponent edits.

Feeding retries use a guarded native stop operation, not a toggle that might accidentally start a session that already ended. Cache, retry budget and callbacks follow the current character generation; a transient feed flag gap does not refill the repair budget. Native E/ButtonB approach protection, finite resource values and current maxima are respected. A completed cub pickup followed immediately by G reaches native drop handling. AFK declines to act on missing or invalid health/status/needs and yields to real input.

### Territory 0.8.0

The capacity estimator includes recurring work for all owned scent, including currently full bars. It uses observed decay/service costs, an estimated tour and observed care share. Missing lifetime evidence stays unknown. Expansion pauses under estimated overload; when service time alone exceeds available time, maintenance selects a feasible valuable subset instead of claiming that the whole map is sustainable. Expensive travel-helper calls are bounded to at most `3N + 1` for N considered hexes.

Asynchronous navigation uses isolated worker state until adoption. Old computations cannot mutate a replacement route; character/root/config generations invalidate obsolete work. Physical gamepad, touch and keyboard control win promptly, with native gait ownership preserved. Core minigame deadlines suspend background Territory work and release owned input. STOP, failure and unload release owned feeding exactly once.

Care and hunting require compatible resource maxima, target Humanoid and generation. Recycled prey or growth cannot fabricate a kill or nutrition gain. Blocked resource approaches can retry another legal source. Ground/surface routes keep their existing support and obstacle checks; native autonomous climb, flight and underwater-depth adapters remain **unsupported** and deliberately release ground steering. No teleport, local resource rewrite or fabricated Amber claim is introduced. Territory remains disabled at activation and is never persisted as an automatic START.

### Interface, settings, camera and lifecycle

The same compact five-tab hub retains all controls, a smooth small bite cue and separate health/pack colours. The window fits small viewports, supports scoped mouse/touch dragging and keeps its header onscreen. A hidden-menu reopen button works without a keyboard and is excluded from combat clicks. King Cobra range colours are species-specific; other species keep the neutral marker. Missing camera data hides stale overlays, names stay within screen edges, and their established independent through-wall visibility remains.

Saved explicit OFF values survive legacy migration and reload. Unrelated/invalid primary JSON cannot replace a good backup; backup acknowledgement is verified before primary replacement. Schema/path 15 intentionally remain the established settings identity. Partial camera-limit failure restores already-written fields. Configuration preflight/getter/setter failures roll back prior writes without stomping intervening external changes. Scope failures are collected while remaining cleanup proceeds. Stage failure preserves the old hub; activation failure cleans the partially active candidate and provides the stable reload instruction.

## Validation and repaired failures

The unchanged integrated 15.8.0 base was run locally first: **214/214 core and 263/263 Territory**. Final candidate counts and complete output are in [core results](../test-results.json) and [Territory results](../../feral-amber/test-results.json); these are compilation/service mocks and deterministic simulations, not live game outcomes.

The runner compiles all 26 modules, bundle, fixtures and launchers with official Luau commit `97b2f4bf9cd935bed666f3e643a3b749b4d22f38`. It checks exact source/manifest parity, deterministic rebuilds, immutable historical files and missing/tampered rollback rejection. The Territory integration runner now uses the candidate selected by the manifest instead of silently testing 15.7.0, while keeping a separate stable compatibility case. GitHub Actions uploads both suites' evidence.

Meaningful regressions found and repaired during this execution included shared discovery queue starvation without WolfController, feeding cancellation counted twice, initial-generation gait hysteresis delaying Burst, optional post-dispatch annotation hiding a successful press, and the no-strike native session timeout. Existing tests exposed these defects and were retained. One Territory assertion was intentionally strengthened: missing essential needs now requires WAIT rather than permission to acquire territory. A feeding fixture gained the guarded stop interface while retaining its original behavior assertions. No failure was hidden by deleting a scenario.

The integrated predecessor comparison uses the same 24-player/120-frame mock scene: both builds perform 2,880 projections, zero redundant highlight/label-position writes and zero background target scans during the tested pending-strike interval. The retained Territory lifecycle runs 7,200 **simulated** seconds with five prey-down sequences, 12 meals, 13 drinks, one claim and 37 scent completions. Neither result is a measured FPS improvement, live kill rate, real resource reward or unattended field trial.

## Remaining implementation and live gates

| Remaining item | Exact status |
|---|---|
| Autonomous Territory climb, flight/altitude and underwater-depth traversal | No verified adapter implemented; explicit unsupported/manual fallback retained (T38/H057) |
| Universal damage mitigation | No accepted universal pathway identified; captured species defence only; server handlers unavailable |
| Current game revision and native contract match | Capture remains PlaceVersion 2412; current live revision not observed in this execution |
| Recovery, condition clearance, attacks, minigame grades, abilities and native resources | Implemented coordination and regression coverage; repeated paired live outcomes still required |
| Whole-map sustained Territory and credited income | Recurring capacity implementation and simulations available; real map/species/deadline calibration and 10/30/120-minute runs remain |
| Device performance and visual field validation | Bounded work and operation comparisons checked; real frame-time/memory measurements and current-game visual inspection remain |
| Stable promotion | Withheld; no stable launcher, stable metadata or earlier bundle changed |

An external live-staging action was blocked by automatic approval review and was not executed. The repository work continued independently. No client action, local multiplier, simulation or documentation entry has been promoted to a claim of live server success.

## Rollback

1. Choose **Unload** in the candidate. STOP alone retires Territory but keeps core features active.
2. Run this immutable stable 15.7.0 bundle:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/3434396b4a9057bdba8c1f146325bd26f697d1ce/roblox-tools/feral-renaissance-v15.7.0.lua"))()
```

Stable SHA256: `d54b1b1e94849a5e4c41947a2ce659e35f6ddf22591aa75b3e4288a15e5ed8bb`.

For the exact integrated pre-overhaul candidate, use commit `bcc9c3699b41b6a2bd74a2d91324a493ee48b2c2`, file `roblox-tools/feral-renaissance-v15.8.0.lua`, SHA256 `ba69a1efae61f2241d370aec2f9d8564cd8b3317e40c5afef114d654061ddb30`. Earlier bundles remain untouched. Saved settings use the established schema, including explicit OFF choices; Territory requires a fresh manual START after loading.
