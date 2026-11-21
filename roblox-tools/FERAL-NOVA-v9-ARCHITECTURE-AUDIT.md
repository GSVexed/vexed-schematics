# FERAL NOVA — Core Rebuild v9.0: Architecture Audit and Acceptance Contract

**Audit date:** 21 November 2026  
**Code inspected:** [v8.1 preview](feral-nova-v8.1-preview-potassium.lua), a single embedded 22-module bundle (~9,400 module-source lines).  
**First replacement:** [v9.0 Core Preview](feral-nova-v9.0-core-preview-potassium.lua) — 22 modules, 8 deliberately rebuilt, 14 exact preserved module bodies.  
**Known gameplay fallback:** [v7.5](feral-hub-v7.5-potassium.lua), confirmed by the user to restore normal bites and visible damage bars.  
**DO NOT call this a finished full overhaul yet.** This is a functioning architectural first stage with automated tests and still-unverified live-game outcomes.

## 1. Executive findings

The v8.1 hub was functional but implemented features with separately-owned `RunService` and input subscriptions, amounting to ~19 recurring-update registrations and further input hooks among 22 modules. Several overlapping controllers were intentional experiments; the original action coordinator primarily read state and the modules often still made their own decisions.

**The main reliability problem:** normal damage, native Rest, G/carry, Q/climb, AFK movement, and Grab V2 perfect-input can interfere if they attempt different native actions during the same window.

**v9 architectural remedy:** one side-effect-free Action Core determines feature priority by actual native state, not by the number of enabled switches. The controller owners still send the game's original requests and own their cleanup. v9 does **not** centralize/synthesize all game remotes or claim to override server rules.

Main safety invariants:

1. Real Mouse1/Mouse2 attacks must immediately release hub-owned native Rest; current combat tags strictly block Rest, even while game animations are masked.
2. A `CombatGuide.ready` **extended local hint alone** must not suspend normal recovery. A true native bite window (`nativeReady`) may suspend it.
3. An active Grab V2 game session has priority over native Rest, AFK walking, and buffered climb taps. Only actual server-issued Grab V2 strikes can trigger automatic press requests.
4. AFK survival movement is **OFF by default**, operates on real walked short paths, and is cancelled for higher-priority actions. It cannot make claims about receiving server survival credit.
5. Existing captured prey being held is **not** automatically grounds for suspending Rest; attempting a new G action releases Rest separately.
6. When the coordinator cannot evaluate recovery safety, native Rest fails closed. No synthetic HP, needs, cooldowns, grab-win events or inventories are written.

## 2. Exact module inventory and dispositions

| # | Current v8.1 module key | Primary responsibility | v9 status |
|---:|---|---|---|
| 1 | `feral-aurora-engine-v13.0.lua` | Main character/tracker lifecycle, visuals, shared state | Preserved; future lifecycle refactor candidate |
| 2 | `feral-aurora-power-v14.0.lua` | Client stamina/no-drain, speed, jump profiles | Preserved; server-side endurance not claimed |
| 3 | `feral-nova-escape-v15.0.lua` | Native grab shake/tug/getoff attempts | **Rebuilt as `feral-nova-escape-core-v9.0.lua`**: old shake pauses while Grab V2 timing takes priority |
| 4 | `feral-nova-combat-v15.0.lua` | Local bite-readiness guide, target geometry and hit correlations | Preserved; true server bite range not assumed |
| 5 | `feral-nova-recovery-v15.0.lua` | Legacy visible Rest controller, normally inactive | Preserved for regression compatibility; eventual retirement candidate |
| 6 | `feral-nova-mobile-v15.0.lua` | Older experimental moving-Rest A/B testing, normally inactive | Preserved; eventually fold into one recovery test harness |
| 7 | `feral-nova-carry-v15.0.lua` | G carry/drop helper and captured/holding-state reader | **Rebuilt as `feral-nova-carry-core-v9.0.lua`**: both immediate and delayed G requests check action priority |
| 8 | `feral-nova-reach-v14.0.lua` | Local bite-target reach config lease | Preserved; server benefit unproven |
| 9 | `feral-nova-regen-v29.0.lua` | Client HP and status-decay config leases | Preserved; distinguish local settings from server benefit |
| 10 | `feral-nova-flight-v28.0.lua` | Surface takeoff, guarded flight and underwater exit | Preserved; validate with native outcomes |
| 11 | `feral-nova-native-recovery-v29.0.lua` | Combat-safe masked Rest, movement refresh and HP/status measurement | **Rebuilt as `feral-nova-native-recovery-v9.0.lua`** |
| 12 | `feral-nova-baby-v15.0.lua` | Same-species baby carry protection from auto escape | Preserved |
| 13 | `feral-nova-climb-v15.0.lua` | Buffered Q and one guarded native mount retry | **Rebuilt as `feral-nova-climb-v9.0.lua`** |
| 14 | `feral-nova-tags-v8.0.lua` | Camera-projected animal tags | Preserved |
| 15 | `feral-nova-prime-ui-v32.0.lua` | Onscreen controls and status interface | **Rebuilt as `feral-nova-ui-v9.0.lua`** |
| 16 | `feral-nova-mechanics-v28.0.lua` | Experimental growth/carry/cooldown config leases | Preserved; do not claim server acceptance |
| 17 | `feral-nova-diagnostics-v32.0.lua` | Private own-animal session evidence, periodic file writes | Preserved |
| 18 | `feral-nova-active-recovery-v29.0.lua` | Active native Rest/regeneration configuration supervisor | Preserved; major later consolidation candidate |
| 19 | `feral-nova-eagle-actions-v32.0.lua` | Eagle native lunge, Talon clock and clamp/carry observations | Preserved; server-recognized oversized carry unproven |
| 20 | `feral-nova-action-coordinator-v8.0.lua` | Mainly observational action snapshot and basic safety | **Rebuilt as `feral-nova-action-core-v9.0.lua`** |
| 21 | `feral-nova-afk-v8.0.lua` | Engine virtual idle heartbeat + opt-in safe real movement | **Rebuilt as `feral-nova-afk-v9.0.lua`** |
| 22 | `feral-nova-grab-autoperfect-v8.1.lua` | Actual Grab V2 strike timing, native press | **Rebuilt as `feral-nova-grab-v9.0.lua`** |

The 22 is *not* a target for future versions. Modules may eventually be merged if tests prove overlap is unnecessary.

## 3. Shared priority system: local policy, not a server exploit

The new `Action Core` provides:

- `snapshot(force)`: read-only animal and player state with a 60 ms optional reuse window; includes true native bite readiness separately from client-only extended targeting hints.
- `allowed("recovery"|"afk_walk"|"grab_press"|"climb"|"carry")`: grants or refuses a local action window with a concrete reason.
- `reserve("minigame"|"afk_walk", seconds)` and `release(owner)`: expiring priority leases; legitimate native minigame requests can preempt an earlier lower-priority AFK walk.
- `report()`: counts policy checks, denials, transitions and active leases. No player names, private coordinates or identifiers.

Effective local priority order: **Grab minigame > captured > live combat > attack input > actual native bite window > carry > climb > flight > visible Rest > opt-in AFK walking > idle**. This is a hub scheduling preference, **not a change to Roblox/server priority rules**.

Native recovery delegates additional denial checks to Action Core while retaining pre-existing combat-tag and actual input safeguards as fallback. Core failures trigger no new Rest request.

AFK movement requests a short-lived lease and explicitly releases it after completing/cancelling the safe walk; Grab V2 requests a stronger short-lived lease based on a real strike event; Q climbing checks action safety before buffering/retrying its native tap.

## 4. Current evidence versus claims we must not make

| Capability | Evidence available | Still not established |
|---|---|---|
| Bites and enemy health bars | User reported normal real damage and health-bar behaviour in **v7.5**; core attack regression mocks pass | End-to-end real-damage compatibility in v9 |
| Stamina/endurance | User reported near-infinite stamina in prior sessions; local consumption code is modified | All animal/ability paths and definitive server-endurance validation |
| Native Rest healing | Prior positive real HP observations coinciding with native Rest signal; same-max HP moving/still metrics added in v8.1 | Guaranteed continuous moving Rest bonus, exact percentage caused by hub |
| Fractures, bleed, venom | Native Rest config suggests 4× certain condition decay; some status observations | Unconfounded server-recognized status-clear rates for each injury |
| Grab V2 automatic timing | Mocked native `strike` and `press` timing succeeds, skips practice mode, no guesses outside window | 100% actual server Perfect grades in gameplay |
| AFK idle | VirtualUser callback and game `Player.Idled` fallback mock-tested | 20+ minute actual Roblox/FERAL retention |
| AFK survival bonus | Known FERAL `AFK_AFTER`, `AFK_MOVE` config and real `Humanoid:MoveTo` safe movement plan | That server counts travel for survival credit, or that route remains predator-safe |
| Oversized Eagle lift | Native `bit`, `clamp`, physical hold observers and client ratio logic | Real server-accepted oversized carry |
| Talon cooldown | Local deadline/config manipulations can be applied and inspected | Server-accepted shortened Talon cooldown |
| Growth | Client config edits and measured growth samples | Valid controlled accelerated server growth |
| Hunger and thirst | Real own-animal values can be observed | Genuine infinite server-owned needs, which cannot be assumed from local config |
| Flight and climbing | Native state-aware guidance, Q buffering, surface takeoff/exit attempts | Uniform success in every species/terrain/gameplay situation |

Never label the UI green/working solely because a client-side setting was assigned. Prefer **ON (client)**, **ACTION REQUEST SENT**, **GAMEPLAY OUTCOME OBSERVED**, **SERVER RESPONSE MATCHED**, or **UNVERIFIED**.

## 5. Automated validation contract

The v9 [CI workflow](https://github.com/GSVexed/vexed-schematics/actions/workflows/feral-nova-v9.0-validate.yml) enforces:

1. Exactly 22 embedded modules; exact source parity for the eight replacements; byte-for-byte preservation of the 14 untouched module bodies.
2. Compilation by the official Luau compiler for the single-file hub and all embedded modules.
3. The old attack-first native Rest mock: Mouse1 immediate release, held attacks, native bite-window preemption, strict combat tags, pose-echo backoff and re-arming.
4. Separate two-stage AFK mock: no unsolicited survival movement, native virtual input heartbeat and no actions after close.
5. Grab V2 mock: native server strike, one real-timestamp center-crossing press, no practice-mode press, manual input priority and shutdown cleanup.
6. Action Core mock: local extended hint is not native bite reach, capture/combat preempt recovery, timed priority leases, correct ownership/release and shutdown.
7. Integrated native-Rest mock: coordinator denial physically releases Rest; after denial clears, recovery can re-arm.
8. Regression: merely holding already-captured prey does not unnecessarily disable noncombat recovery. Native Grab V2 priority also prevents legacy shake spam and hub-initiated carry presses from interfering with the timing session.

Passing CI is necessary but not sufficient for a public fully validated gameplay release. The bundle now includes **49 startup self-checks** for module availability and supported interfaces. These check wiring, not claims that server behaviour changed.

## 6. Next overhaul work packages and acceptance gates

### Work package A — Consolidate survival/recovery

- Inventory and eliminate overlap between the five separate Rest/regeneration controllers **only after** reproducing their relevant existing tests in a unified supervisor.
- Demonstrate same-stage, same-max-health moving vs stationary healing where possible, with control intervals and exclusions for combat/damage/growth. Distinguish health regeneration from status clearance.
- Prove positive status reduction for injury, bleeding and venom independently.
- A release fails if attacks stop dealing damage or client posture gets locked in Rest.

### Work package B — Combat and grab/minigame reliability

- Measure true native hit initiation, actual enemy-health declines, missed bites and any impact of local reach config.
- Capture actual native Grab V2 server grades before tuning scheduling bias, jitter and frame windows.
- Protect live movement and input controls when user engages chat, climbing, carrying or native grab minigames.
- Reject any automatic repeated press after a session ends or a practice-only strike.

### Work package C — Eagle and Talon

- Require replicated `clamp` matching prey and sustained physical hold to call a carry real; a CATCH label or local ratio alone is insufficient.
- Measure native cooldown acceptance over multiple actual Talon presses. Do not claim server cooldown bypass from a local ready timestamp.
- Isolate the actual server-authoritative rule where client code provides only hints; avoid ungrounded retry floods.

### Work package D — Mobility and survival activity

- Preserve Q buffer and single retry; quantify successful tree-mount rates using comparable scenarios.
- Validate water-surface takeoff, underwater exit and user-cancelled inputs with animal-specific checks.
- AFK validation includes an uninterrupted 20+ minute session, no FERAL server hop, alive own animal, and actual incremental `FeralSurvival` observations. If no safe path exists, do **not** auto-move.

### Work package E — UI, reliability and final consolidation

- Move high-value functions into clear panels with their exact evidence label and reason for action suspension.
- Consolidate redundant `Heartbeat` watchers when tested; preserve cleanup on respawn and same-session reload.
- Add a one-click safe-recovery mode that disables risky automatic features without corrupting existing native state.
- Maintain verified fallback release and a full source-parity test for every release candidate.

## 7. Current default behaviour and deployment posture

v9 preserves v8.1 startup defaults: **ON** Endurance, Outline ESP, Auto Escape, client Bite Reach, Quick Climb, Baby Carry Protection, guarded Active Recovery, Flight Surface Assist, virtual-input Anti-Idle, and Grab V2 Auto Timing. **OFF** by default: automatic Survival AFK movement, experimental Growth, experimental Carry/Talon, and Agility. User display preferences for tags/range/walls may persist.

The latest private Potassium report available during the audit still identified a **v7.5 in-game startup**, not v9. The project maintains rollback loaders for v7.5 and v8.1. We do not automatically change a running user's game during a large experimental architecture rebuild.

### v9 optional preview launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v9.0-core-preview-potassium.lua"))()
```

The first v9 milestone is **built and CI-tested**. This file is a plan and evidence contract for the remaining overhaul work, not a certification of end-to-end perfection.
