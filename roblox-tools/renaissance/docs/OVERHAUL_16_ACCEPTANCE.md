# Renaissance 16.0.0 / Territory 0.8.0 — acceptance and retained requirements

Date: 26 November 2026. This is the implementation evidence map for the single integrated overhaul candidate. It preserves the requirements in the [master directive](PRO_ONE_SHOT_FULL_OVERHAUL_HANDOFF_2026-11-26.md), [full preparation](FULL_HUB_PERFECTION_PREPARATION_2026-11-26.md), [H/U/G acceptance matrix](FULL_HUB_PERFECTION_ACCEPTANCE_MATRIX_2026-11-26.md), and [combat extension](P0_COMBAT_GHOST_HITS_AND_MISSING_BITES_PREPARATION_2026-11-26.md).

**No live Roblox scenario was executed or completed in this execution. All H001–H070 live acceptance remains open.** Source inspection, official Luau compilation and deterministic service-boundary regressions establish the narrower software behaviours described below. They do not establish accepted server damage, resource restoration, Perfect grades, rewards, current species support or real-device FPS.

The integrated baseline was Renaissance 15.8.0: 214 core and 263 Territory regressions. The frozen implementation adds 90 core regressions (37 interaction, 32 native-adapter, 21 UI/core) and 42 Territory regressions. The candidate suites passed **304/304 core and 305/305 Territory** in local official-Luau runs. Final artifact hashes, compiler identity, compile/parity results and exact run records belong to [core test-results.json](../test-results.json), [Territory test-results.json](../../feral-amber/test-results.json), [manifest.json](../manifest.json) and the release metadata. Test counts are not counts of completed gameplay scenarios.

## Reading the evidence

| Status | Meaning |
|---|---|
| **Automated coverage / live open** | Named fixtures exercise the stated software contract; the remaining native gameplay requirement has not been run. Coverage can be partial, as described in the row. |
| **Live open** | The mechanism or requirement is documented, but there is no new live outcome evidence. |
| **Unsupported / live open** | A requested capability is not implemented or an authoritative mechanism has not been established. A tested refusal/fallback is not implementation of that capability. |

Evidence follows the original ladder: source → compilation → mock regression → observed client runtime → replicated gameplay → repeated paired live comparison → verified release. No row skips a rung. A callback return is not a native bite marker; a local impact is not a server hit; an HP change does not establish this client's authorship; a config acknowledgement is not a measured multiplier.

The native mechanism reference is [NATIVE_MECHANISMS_16.md](NATIVE_MECHANISMS_16.md), grounded in the available build-2412 capture and [source-traces.json](source-traces.json). Current Roblox PlaceVersion was not rechecked live. Private captured offsets and the Hippo adapter are guarded accordingly. Historical live files remain historical; they do not certify this candidate.

### Test file key

| Key | Exact file / scope |
|---|---|
| C | [tests/suite.luau][C] — retained core integration/regression suite |
| I | [tests/overhaul_interactions.luau][I] — first-bite, recovery, minigame, feeding, carry and lifetime additions |
| N | [tests/overhaul_native.luau][N] — native adapter, geometry and shared-config additions |
| V | [tests/overhaul_ui.luau][V] — settings, leases, UI, camera and activation additions |
| TP | [Territory tests/suite.luau][TP] — planner requirements |
| TE | [Territory tests/efficiency_suite.luau][TE] — capacity, need arbitration, clocks and paired simulations |
| TA | [Territory tests/agent_suite.luau][TA] — objective ownership and agent state |
| TN | [Territory tests/nav_suite.luau][TN] — physical route, support, generation and stop contracts |
| TD | [Territory tests/driver_suite.luau][TD] — actual movement callback and manual handoff |
| TB | [Territory tests/bridge_suite.luau][TB] — resource/world adapter contracts |
| TC | [Territory tests/care_suite.luau][TC] — feeding, drinking, recovery and interrupted objectives |
| TH | [Territory tests/hunt_suite.luau][TH] — pursuit, attack evidence and corpse handoff |
| TG | [Territory tests/gait_suite.luau][TG] — observed gait, native denial and exact release |
| TL | [Territory tests/lifecycle_suite.luau][TL] — full compiled hub, native-service mocks and 7,200-second simulated cycle |

## Full-hub scenarios

Every ID from the mandatory H001–H070 inventory is retained individually. The code and test references identify what was actually implemented or retained, not full scenario completion.

| ID / scope | Status | Concrete source and automated evidence | Remaining live proof |
|---|---|---|---|
| H001 — fresh start, lobby and spawn | Automated coverage / live open | [controller], [settings], [ui]; C `hot reload closes old controller once and leaves one GUI and scheduler`; TL `Renaissance contains Territory by default with one window and scheduler`. | One visible 16.0.0 hub, defaults and Territory OFF in a real no-animal → spawn transition. Cross-place teleport reinjection is not implemented; same-place lobby/spawn guards must not be confused with cross-place continuity. |
| H002 — saved explicit OFF | Automated coverage / live open | [settings], [controller]; V `overhaul settings reject unrelated primary JSON and retain backup explicit OFFs`; C `boot reconciles every explicit false state and all features have statuses`. | Reload and animal change with each named feature OFF; inspect actual config, listeners and requests. |
| H003 — unload owned Rest | Automated coverage / live open | [recovery], [controller]; C `manual Rest survives recovery disable and shutdown`; I `overhaul failed first Rest dispatch restores pose and preserves later manual Rest`. | Native Rest(false) and pose cleanup on unload, including delayed echoes and concurrent manual Rest. |
| H004 — unload minigame lease | Automated coverage / live open | [grab], [grab_input], [roblox]; C `closing an active minigame owner restores working native manual input`; N `overhaul replacing a grab service never reinstalls its obsolete input callback`. | Inspect real CAS bindings, pending wakes and native manual input immediately after unload. |
| H005 — unload concurrent actions | Automated coverage / live open | [controller], [feeding], [rescue], [amber_nav]; I `overhaul surface-flight requests restore owned attributes and preserve later replacements`; TL `STOP releases all owned input immediately inside the shared hub`. | No retained native input, route, carry request, feed session or flight intent across the complete overlap matrix. |
| H006 — reload during recovery/combat | Automated coverage / live open | [controller], [recovery], [roblox]; C `hot reload carries automatic Rest provenance without inheriting manual Rest ownership` and `hot reload preserves validated native bite handles without a heap search`. | Same-character owner transfer, one active GUI/scheduler and an ordinary first bite under real timing. |
| H007 — species and character replacement | Automated coverage / live open | [controller], [features], [combat_input]; I `overhaul a new animal does not inherit prior attack pauses or feeding caches`; N replacement-profile tests. | Repeated real species swaps with old config/pose/target evidence fully retired. |
| H008 — replaced or malformed native config | Automated coverage / live open | [core], [features], [roblox]; N `overhaul replacement condition profiles receive current recovery and movement leases`, `overhaul unsupported combat schema removes stale guide config ownership`; V transactional lease tests. | Verify current native schemas, safe feature status and manual fallback when real modules change. |
| H009 — game-version drift | Automated coverage / live open | [roblox], [features]; N `overhaul new game builds do not interpret captured private feed offsets as verified` and `overhaul unverified game builds never apply the captured Hippo cap adapter`. | Record actual PlaceVersion and revalidate the capture-derived contracts on that exact build. |
| H010 — staging/storage/runtime failure | Automated coverage / live open | [controller], [core], [settings], [zoom]; V `overhaul activation failure unwinds camera GUI and input after successful staging`; C staging/fault tests; I scoped-cleanup failure test. | Executor/service failures, real listener cleanup and focus behaviour. Staging preserves the prior hub; a failure after the old hub is retired does not promise resurrection. |
| H011 — stationary HP recovery | Automated coverage / live open | [recovery], [core], [features]; C `unchanged actual HP never becomes a recovery success after native requests`; V immutable/invalid observation tests. | Paired ON/OFF HP timeseries with identical species, MaxHealth, reserves and combat state; native requests alone do not prove 2× healing. |
| H012 — recovery during continuous movement | Automated coverage / live open | [recovery], [controller]; C `moving recovery masks only its own echo and releases on first bite` and `the native procedural Rest blend is reset during automatic moving recovery`. | Continuous real displacement, no resting animation, sustained eligible Rest and measured same-MaxHealth gain. |
| H013 — walk/run/surface-swim transitions | Automated coverage / live open | [recovery], [policy], [roblox]; C sustained-Rest tests; N `overhaul native aquatic dive entry releases recovery before the next heartbeat` and cheap-swimming snapshot test. | HP/pose/mode trace through walk, run, surface swim and land. Aquatic diving is a protected native transition, not surface-swim recovery. |
| H014 — first bite after recovery | Automated coverage / live open | [combat_input], [recovery]; I `overhaul long native stand-up locks cannot rearm recovery ahead of the buffered bite` and delayed-native-Rest one-attempt test. | Original input, Rest lock, WolfBiteAt, actual target/reply and HP for the first eligible bite. |
| H015 — held attack versus camera | Automated coverage / live open | [policy], [roblox], [combat_input]; C held-LMB/RMB tests; N `overhaul held gamepad bite prevents automatic recovery between discrete input events`. | Successive native bites while held LMB/R2; RMB camera motion must leave eligible recovery intact. |
| H016 — manual Rest ownership | Automated coverage / live open | [recovery], [policy], [controller]; C manual R/ButtonY, touch-control discrimination and native tap-intent tests. | Mouse/keyboard, gamepad and supported touch manual Rest, including delayed native animation/state. |
| H017 — capture/downed/ability priority | Automated coverage / live open | [policy], [recovery], [roblox]; C `native abilities preempt owned Rest immediately before the next heartbeat`; I passive-minigame ownership tests even when automation is OFF. | Real native lock/pose transitions with safe rearming after each lock ends. |
| H018 — combat HP restriction | Automated coverage / live open | [policy], [core], [features]; C `condition recovery can request native Rest during a combat tag while HP stays excluded`; V incompatible-mode observation test. | Same-MaxHealth combat trace; no combat HP regeneration claim unless independently observed. No local HP writer was added. |
| H019 — venom at full HP/in combat | Automated coverage / live open | [policy], [recovery], [core]; I `overhaul condition grace is independent for injury bleeding and venom`; C condition-only combat eligibility. | Numeric venom ON/OFF decay with full HP, combat tag and attack yields. |
| H020 — bleeding at full HP/in combat | Automated coverage / live open | [policy], [recovery], [core]; I independent condition grace and explicit-zero tests; C independent HP/condition trends. | Separate numeric bleeding decay; do not infer it from venom or from a config multiplier. |
| H021 — injury at full HP | Automated coverage / live open | [policy], [recovery], [features]; I independent condition grace; N replacement condition-profile test. | Separate injury amount/clearance comparison while eligible and while moving. |
| H022 — disappearing status amount | Automated coverage / live open | [recovery], [core]; I `overhaul explicit healed zero releases condition Rest immediately while missing amounts retain grace` and negative-amount test. | Presence/absence/zero timeline under real replication; bounded unknown grace must not become a reported cure. |
| H023 — replenished venom | Automated coverage / live open | [core], [recovery]; C `condition progress is measured independently and missing amounts are not cures`; V observation validity tests. | Matched decay windows excluding incoming replenishment, growth and incompatible modes; no aggregate 4× claim from mixed windows. |
| H024 — incoming damage mitigation | Unsupported / live open | [Native mechanisms](NATIVE_MECHANISMS_16.md#damage-mitigation-what-the-evidence-actually-establishes): captured SnappingTurtle shell uses TAKEN = 0.3 after 1.0 second of native Rest. No universal defensive writer/action was added. | Server handler/accepted paired own-HP damage evidence is unavailable. Species-specific client calculation does not establish universal damage reduction or accepted server mitigation. |
| H025 — sprint/Burst/trot/stamina | Automated coverage / live open | [features], [roblox], [amber_gait]; C per-consumption stamina/Hippo tests; N nested-profile, debug ownership and death-release tests; TG native denial/acknowledgement cases. | Actual displacement, gait and stamina across eligible species and modes, including later correction/drain. |
| H026 — jump/leap/climb | Automated coverage / live open | [features], [policy], [controller]; N aliased/replaced climb and leap-profile tests plus canonical Player.FeralDiveCan priority; C bounded Q mounting retries. | Native mount/jump/leap, stamina and safe dismount on supported bodies; no forced climb or invented eligibility. |
| H027 — swimming and bank exit | Automated coverage / live open | [roblox], [policy], [amber_nav], [amber_bridge]; N dive/swimming snapshot tests; TN land/water/steep-shore tests. | Real bank alternatives and movement-mode continuity for aquatic/semi-aquatic species. Existing surface routing is not a depth adapter. |
| H028 — flap/surface launch/water exit | Automated coverage / live open | [controller], [policy], [features]; I surface-flight ownership test; C surface takeoff/deep-water exclusion and restart-timeout tests. | Native takeoff, actual velocity/stamina and reversible water-exit intent under current species rules. |
| H029 — Vulture/Eagle ability cancellation | Automated coverage / live open | [controller], [roblox]; I `overhaul the native talon release binding also works for an eligible Eagle`; C guarded Vulture/dive restart tests; captured distinct talon/dive bindings documented. | Repeated real talon/dive cancellation and resumed flight. Native commit-speed/phase limits remain authoritative; no lock clearing or physics manipulation. |
| H030 — Hippo Crusher gait | Automated coverage / live open | [features]; C native land/water scalar, Burst denial, trot and cleanup tests; N Hippo external-edit and unknown-version tests. | Physical speed/gait on land/water under Shift/X/Z and ability exit, with denied Burst preserved. |
| H031 — overlapping movement leases | Automated coverage / live open | [core], [features]; V transactional/finite-value lease tests; N nested identity/alias retirement tests; C external conflict/exact restoration tests. | Sustained real movement session, conflict recovery and exact native values after species change/OFF/unload. |
| H032 — moving prey combat | Automated coverage / live open | [roblox], [combat_input], [amber_hunt], [amber_bridge]; N stock geometry/clear-target tests; TH pursuit and delayed-result cases; TL shared stock-formula test. | Paired native accepted-hit rate and prey HP during movement; predictive geometry alone is insufficient. |
| H033 — close rear/above target | Automated coverage / live open | [roblox], [features], [amber_bridge]; C exactly-rear and current-position geometry tests; N species cone/vertical approach tests; TL stationary-prey facing test. | Real body gap, facing, elevation, turn/contact and native damage outcome. |
| H034 — same-tree combat | Automated coverage / live open | [roblox], [features]; retained native aim path and stock vertical formula; C expanded targeting/rollback; N species-specific geometry tests. | Both animals climbing at different heights; actual native reply and target HP. No server-authoritative vertical reach is established. |
| H035 — rapid/high-latency bites | Automated coverage / live open | [controller], [combat_input]; I marker-deduplication, delayed local impact, overlapping reply and delayed-HP tests; C original native cooldown cases. | Real latency distribution, no duplicate first bite, no local-only impact labelled confirmed damage. |
| H036 — enemies/friendlies/protection | Automated coverage / live open | [roblox], [features]; C affiliation/protection/player-ownership cases; N malformed protection, stale body and clear-candidate selection tests. | Crowded live affiliation/protection changes and actual native selected target. |
| H037 — minigame timing/frame rates | Automated coverage / live open | [grab], [grab_input], [controller]; C `replayed native zones produce valid actual-time presses across frame rates and hunter widths`; I final-clock-slip and unavailable-clock tests. | Native own grade distribution and dispatch latency at 30/60/144 Hz with hitches; no fabricated Perfect result. |
| H038 — multiple hunters/sessions/bite | Automated coverage / live open | [grab], [grab_input], [controller]; C own-result/session/multi-attacker cases; I retired-ID, replacement and ambiguous-dispatch tests. | Independent own native session/result IDs, real attack markers and ordinary LMB coexistence. |
| H039 — mid-session/manual/early end | Automated coverage / live open | [grab_input], [roblox]; C mid-session adoption/manual takeover/deadline cancellation; I stale manual binding fallthrough, practice takeover and lost-end timeout. | Real binding restoration and actual session handoff after activation, manual input and native end. |
| H040 — escape and friendly cub carry | Automated coverage / live open | [policy], [controller], [rescue]; C native escape/friendly carry/water pickup tests; I between-frame pickup and competing carry tests. | Genuine clamp, getoff/tug outcome, permitted water rescue and preserved manual drop. |
| H041 — native feeding approach/gain | Automated coverage / live open | [feeding], [policy], [roblox]; I ButtonB approach protection and repair-budget flicker tests; C guarded cancellation/no-resource-write tests; TC pending approach/gain tests. | Approach before WolfFeed, actual Hunger gain, bounded repair and no restart after native no-food completion. |
| H042 — delayed or blocked drink bank | Automated coverage / live open | [amber_bridge], [amber_nav], [amber_care]; TB water index and TL ongoing scan/native-offer cases; TN steep-bank tests. | Real bank accessibility, delayed offers, actual Thirst increase and nonoscillating alternative selection. |
| H043 — finite food/prey/forage | Automated coverage / live open | [amber_hunt], [amber_care], [amber_bridge]; TH corpse cases; TL `two-hour full bundle simulation completes repeated unassisted hunts meals drinks and maintenance`. | Current-server diet, FoodLeft depletion, new prey/forage and real completed nutrition. Meal yield/danger optimisation remains partial. |
| H044 — platform AFK/survival credit | Automated coverage / live open | [controller], [policy], [roblox]; C idle API failure, safe route and manual mouse tests; I invalid AFK-needs test. | Actual platform retention and separately observed native survival credit; idle signalling alone proves neither. |
| H045 — AFK route changes | Automated coverage / live open | [roblox], [policy], [controller]; C `an idle walk stops when its previously safe route develops a hole` and intermediate-ground checks. | Native physical stop when danger/obstacles enter; no clipping/underground technique is implemented. |
| H046 — streamed player overlays/finder | Automated coverage / live open | [roblox], [ui]; C real-player ownership and 24-record bound; V crowded no-render-raycast and missing-camera tests. | 24+ live players, streamed replacements, truthful finder count and no stale highlight/tag. |
| H047 — affiliation/health colours | Automated coverage / live open | [roblox], [ui]; C distinct pack hue versus HP outline and copied-name/NPC exclusions. | Real team changes and unknown affiliation with independent name/HP colour behaviour. |
| H048 — small species-correct bite cue | Automated coverage / live open | [ui], [roblox]; V `overhaul marker range colours are exclusive to King Cobra`; C target-change marker and current-geometry tests. | Smooth cue under actual 30/60/144 Hz movement/tree combat without a large text overlay. |
| H049 — menu/input/control responsiveness | Automated coverage / live open | [ui], [controller], [settings]; V all-controls, viewport/clamped-drag and keyboard-free reopen tests; C Right Shift/focus/click exclusion. | Real chat, scroll, Right Shift/native sprint polling, touch/gamepad where supported and every visible control. |
| H050 — camera ownership | Automated coverage / live open | [zoom]; V `overhaul zoom rejection unwinds a partially applied camera lease`; C external native camera update, reload and exact restore cases. | Actual wheel/first-person camera limits and another script's replacement through unload; no camera pose/subject writer. |
| H051 — extended core performance | Automated coverage / live open | [core], [controller], [ui], [grab]; I bounded retired sessions; V predecessor render-budget comparison; C listener cleanup and deferred scans. | 10/30/120-minute hardware memory/FPS p95/p99. Equal mocked projection/write counts are not device FPS or a real-client soak. |
| H052 — crowded scene during strike | Automated coverage / live open | [controller], [grab_input], [amber_runtime]; I native/newly-recovered strike before Territory tests; V critical-scan isolation; TL one-time critical-window yield test. | Actual native grade and callback timing under a dense live scene; critical-path ordering alone is not reward evidence. |
| H053 — Territory OFF isolation | Automated coverage / live open | [amber_runtime], [amber_agent], [controller]; TA `disabled autopilot makes no movement or hunts`; TL default-OFF integration. | Confirm no autonomous Territory action/recovery override while OFF and using all core features. |
| H054 — Territory START/STOP/unload | Automated coverage / live open | [amber_runtime], [amber_agent], [amber_nav], [amber_care]; TE idempotent START; TA owned feed cancellation; TL immediate STOP/unload and stale-action tests. | Native water/feed/combat overlap, exact held-input release and one agent after reload. |
| H055 — sustained scent capacity | Automated coverage / live open | [amber_planner], [amber_bridge], [amber_agent]; TE `full scent bars remain in future maintenance workload`, recurring capacity, overload subset and linear travel-call tests; TL observed decay. | Whole-map repeated maintenance including travel/care overhead, retention and misses. Unknown lifetimes remain unknown; estimated sustainable is not a live guarantee. |
| H056 — Territory physical routes | Automated coverage / live open | [amber_nav], [amber_driver], [amber_model]; TN support/cliff/tree/forward-rejoin and stale-worker tests; TD native callback/manual takeover. | Actual long streamed routes, slope/switchback/body envelopes and bank quality; finite support sampling is not universal fall prevention. |
| H057 — autonomous climb/flight/depth | Unsupported / live open | [amber_nav], [amber_agent]; TN `native air climb and depth modes explicitly refuse ground steering`. Existing core assistance remains separate. | Native autonomous transition adapters are absent. The deliberate stop/manual fallback is covered; all-animal unattended route completion is not supported. |
| H058 — competing survival/territory work | Automated coverage / live open | [amber_planner], [amber_agent], [amber_care], [feeding]; TE normalized emergency priority/maxima tests; TL core-feed ownership; TC suspended return chains. | Actual needs, native healing, meals/drinks and resumed root goal without conflicting owners. |
| H059 — multi-hour Territory outcomes | Automated coverage / live open | [amber_ledger], [amber_runtime]; TL 7,200-second finite-resource integrated simulation; TE currency/clock and paired planner fixtures. | Repeated real 10/30/120-minute species/diet/world runs, full-map retention, Amber/time and intervention counts. |
| H060 — integrated release and rollback | Automated coverage / live open | [build.py](../build.py), [run_tests.py](../run_tests.py), protected artifacts and both suites; TL protected-stable compatibility test. | Exact published-tree CI/hashes plus a real canary and rollback. Stable promotion is withheld while material live gates remain open. |
| H061 — ordinary eligible click | Automated coverage / live open | [combat_input], [roblox]; C native marker/claim/damage distinction and original-input cases; N held-gamepad and replaced-action-remote tests. | Original eligible close-range input produces a native marker, actual target/reply and HP outcome without Rest. |
| H062 — bite around Rest release | Automated coverage / live open | [combat_input], [recovery]; I long stand-up, delayed private Rest, marker cancellation and consumed-UI-input tests. | Repeated 0/100/300/700/1000 ms before/after release with native timing; quantify hub-induced loss against baseline. |
| H063 — local impact without damage | Automated coverage / live open | [controller], [combat_input], [features]; C `prediction is disabled while genuine hit replies and pre-claim HP changes remain observable`; I delayed-local-impact test. | Capture SFX/local impact separately from accepted reply and stable HP; cosmetic suppression is not improved damage. |
| H064 — bite marker without hit | Automated coverage / live open | [roblox], [combat_input]; N stock geometry, stale body, occlusion and unknown-schema cases; C cooldown/private-Rest guidance. | Exact current target, body gap, cone, elevation, occlusion, cooldown and authoritative denial. |
| H065 — reply without matching HP | Automated coverage / live open | [controller], [combat_input], [core]; I late reply/HP window and transient HP/growth tests; TH MaxHealth/Humanoid replacement cases. | Growth, replication lag and real target identity; preserve server feedback versus replicated HP as separate observations. |
| H066 — moving/fleeing/turning target | Automated coverage / live open | [roblox], [amber_hunt], [combat_input]; N clear stock-candidate preference; C live-position geometry; TH pursuit/late-window fixtures. | Repeated matched baseline/candidate accepted-hit ratio during motion and rapid turns. No such ratio was measured here. |
| H067 — different heights on one tree | Automated coverage / live open | [roblox], [features]; N species cone/vertical formulas; C native aim and reversible extended geometry. | Actual native elevation eligibility and reply/HP at several tree heights; extended client range remains a prediction. |
| H068 — overlapping targets/attackers | Automated coverage / live open | [controller], [combat_input], [amber_hunt]; I `overhaul same-target overlapping replies remain ambiguous without a unique attack ID`; C actual-hit-target and frozen-marker attribution. | Simultaneous real attackers/targets. Ambiguous observations remain unattributed; no unique server transaction ID is invented. |
| H069 — minigame/LMB/private callback loss | Automated coverage / live open | [grab_input], [roblox], [combat_input]; I stale binding Pass, optional introspection fault and automation-OFF ownership; N obsolete-controller replacement tests. | Ordinary native attacks and manual minigame controls on the actual executor when optional introspection is unavailable. |
| H070 — manual versus Territory hunt | Automated coverage / live open | [controller], [combat_input], [amber_hunt], [amber_bridge]; TH generation/HP identity; TL original native bite, stock geometry and finite meal loop. | Same scene under both control paths: actual prey damage/down state, edible corpse and observed nutrition. |

## Original unresolved-item ledger

The U identifiers remain open at the gameplay boundary unless explicitly limited to a software defect. References to H rows carry their source/test links and required measurements.

| ID | Status | Implemented response and remaining scope |
|---|---|---|
| U001 | Automated coverage / live open | Dynamic controller title retained and coherent 16.0.0 candidate metadata; C actual-version test, V all-control UI. Real rendered package is still part of H001/H049/H060. |
| U002 | Automated coverage / live open | Sustained native Rest, independent condition grace and honest observations retained/improved, H011–H023. No new 2× HP or 4× condition live result. |
| U003 | Unsupported / live open | Species-specific shell calculation documented under H024; universal accepted damage reduction is not established. No universal toggle or health overwrite was added. |
| U004 | Automated coverage / live open | Bounded first-bite handoff, marker deduplication, long-lock attack priority, pose/provenance rollback; I and H014/H062. Native repeated comparison remains open. |
| U005 | Automated coverage / live open | [policy] priorities, passive native minigame ownership, feed/carry/flight exclusions and early strike dispatch; I, TL and H017/H038/H052/H058. Real overlap matrix still required. |
| U006 | Automated coverage / live open | Earliest legal actual-time window, final clock-slip reschedule, no ambiguous resend, bounded session retirement; C/I, H037–H039. Actual grade/reward distribution unmeasured. |
| U007 | Automated coverage / live open | Current nested profiles, native gait/cooldown boundaries, held input and exact leases; N/TG, H025/H030/H031. Accepted physical speed and stamina remain unmeasured. |
| U008 | Automated coverage / live open | Native eligibility/binding-based Eagle/Vulture handoff and reversible surface intent; I/C, H028–H029. Frozen-flight resolution under real timing is not certified. |
| U009 | Automated coverage / live open | Actual input/Rest/geometry repairs plus separate marker/reply/HP evidence, H061–H070. No measured increase in accepted live bites is claimed. |
| U010 | Automated coverage / live open; autonomous depth/climb/flight unsupported | Aquatic state and dive-input corrections plus retained surface routing, N/TN, H026–H028/H056–H057. Real banks and native route adapters remain incomplete. |
| U011 | Automated coverage / live open | Guarded native feed cancellation, pending approach protection, retained retry budget, normalized need targets and finite-source simulation; I/TC/TL, H041–H043/H058. Actual nutrition remains open. |
| U012 | Automated coverage / live open | Responsive/clamped layout, all visible controls, reopen affordance, Cobra-only colour, camera loss and independent tag visibility; V, H046–H050. Device visual/input acceptance open. |
| U013 | Automated coverage / live open | Bounded discovery/rays/session memory, critical work isolation and matched predecessor operation counters; C/I/N/V/TL. Hardware FPS, memory and extended profiling not performed. |
| U014 | Automated coverage / live open | Full owned-scent recurrence, bounded horizon, maintenance-only pressure and valuable retention subset now implemented; TE/TA/TL, H055/T21/S14. Optimality and sustained real retention remain open. |
| U015 | Unsupported / live open for autonomous native modes | Ground/surface routing and generation guards improved; TN/TL, H056–H057. All-animal autonomous climb/flight/depth traversal remains unavailable. |
| U016 | Automated coverage / live open | All 44 T and 62 S rows retained below. New implementation evidence is additive; historical partial/unsupported/live gaps are not relabelled complete. |
| U017 | Automated coverage / live open | Native input fallthrough, marker cancellation, optional-state fault containment and service/script identity guards; I/N, H014/H061/H062/H069. Executor/native acceptance still open. |
| U018 | Automated coverage / live open | Native actual-target priority, unique-match-only replies, delayed observation window, same-Humanoid/MaxHealth constraints; I/TH, H063–H065/H068. Shared damage remains unattributed. |
| U019 | Automated coverage / live open | Stock species cone/elevation preservation, clear eligible target preference, live-position checks and shared Territory stock formula; N/TL, H032–H036/H066–H067. Tree/motion accepted-hit outcomes unverified. |

## Release gates

These are candidate eligibility records, not permission to promote the stable launcher. A passed software component does not close a combined software-and-live gate.

| Gate | Status | Evidence / disposition |
|---|---|---|
| G01 | Automated coverage / live open | Source/manifest/module parity and version guards are checked by both official runners. Captured game build is 2412; the current server fingerprint is not live verified. |
| G02 | Automated coverage / source review recorded | All 26 module reviews and 22 retained features are enumerated below; C retains the explicit 22-feature inventory assertion. Review is not full native acceptance. |
| G03 | Automated coverage / live open | Known repaired P0 races have regression coverage in I/N/V/TL. No assertion of zero undiscovered critical native regressions is justified without H001–H024/H061–H070 live execution. |
| G04 | Automated coverage / live open | Priority, manual OFF, passive grab, feed/carry, held controls and Territory handoff tests cover overlapping owners; real input/native timing remains open. |
| G05 | Live open | Recovery/each condition remain explicitly unverified at the gameplay outcome level. H011–H023 require matched numeric windows. |
| G06 | Live open | First attack and true feedback software contracts covered, but H014/H061–H068 native trials have not run. |
| G07 | Live open | Legal-time simulations pass; no measured native grade distribution or reward comparison. |
| G08 | Automated coverage / live open; unsupported autonomous modes | Core native assistance is reviewed; Territory autonomous climb/flight/depth is explicitly unavailable. Physical species acceptance remains open. |
| G09 | Live open | Native requests and simulated progress are covered; current replicated nutrition/survival credit not measured. |
| G10 | Automated coverage / retained map | T01–T44 and S01–S62 are all reproduced by ID below with source/suite links and residual scope. No historical incomplete row was deleted. |
| G11 | Live open | No reference hardware 10/30/120-minute FPS/memory calibration. Mock operation counters and simulated duration cannot close this gate. |
| G12 | Automated coverage / live open | Version/default/OFF, backup handling, rendered mock controls, layout and reopen checks pass. Real camera/input/rendering still requires H001/H049/H050. |
| G13 | Automated coverage / live open | Ownership-aware rollback, old-value restoration, stale-generation rejection and cleanup fault reporting are tested. Exact live native session/input rollback is unverified. |
| G14 | Automated coverage | Official Luau compilation, both regression suites, deterministic bundle generation and source/manifest parity are the required packaging checks. Use the final published test reports/CI for exact artifact identity; a transient run does not certify a different tree. |
| G15 | Live open | No new repeated native paired runs support healing, accepted damage, minigame, movement, nutrition or Amber benefit claims. Release notes must retain that boundary. |
| G16 | Automated coverage / promotion withheld | Historical launchers/bundles remain rollback points. This candidate is separate; stable must not be promoted on mock evidence alone. |
| G17 | Live open | No repeated native accepted-bite improvement measurement; fixed input/geometry defects and honest labels do not substitute for it. |
| G18 | Automated coverage / live open | All H061–H070 have individual source/test mapping above. Current authoritative hit/eligibility limits and native input outcome remain open. |

## All 26 modules reviewed

“Changed” identifies a substantive implementation edit in this execution. “Reviewed, retained” means the complete module was inspected and its working behaviour kept; it does not mean it was skipped. The 14 core and 12 Territory modules remain in the bundle.

| Module | Review result | Concrete scope / evidence |
|---|---|---|
| [core] | Changed | Transactional config rollback across getter/setter races; finite values; external edits; immutable valid observation windows; complete cleanup-error accounting. C/V. |
| [settings] | Changed | Recognized primary schema, backup fallback/acknowledgement, explicit false and legacy walls migration. C/V. |
| [policy] | Changed | Native/manual priority; finite unknown values; feed/carry/flight/AFK exclusions. C/I/N. |
| [grab] | Changed | Real-session retirement, bounded history, legal window/clock recovery, unknown-clock timeout and no ambiguous retry. C/I. |
| [grab_input] | Changed | Safe optional introspection, current-session binding handoff and wake/session cleanup. C/I/N. |
| [recovery] | Changed | Sustained native Rest ownership, failed dispatch/pose rollback, held/first attack handoff and independent condition eligibility. C/I. |
| [feeding] | Changed | Guarded native stop, generation reset, approach ownership and retained bounded repair budget across flag flicker. C/I/TL. |
| [combat_input] | Changed | One buffered first bite, native marker cancellation, processed-input exclusion and bounded native readiness retry; controller owns reply/HP correlation. C/I. |
| [rescue] | Changed | Actual carry observation, competing carry yield, between-frame pickup/drop and no mobility conflict. C/I. |
| [features] | Changed | All eight shared-config plans reviewed; nested/aliased profile replacement, exact restore, native rates preserved, stamina and Hippo ownership/version guards. C/N. |
| [roblox] | Changed | Native identity/discovery/version contracts, input pass-through, held gamepad, aquatic state, actual species geometry, bounded visibility and stale-target rejection. C/N. |
| [zoom] | Changed | Camera lease rollback after partial setter failure; retained external native defaults, observer cleanup and no pose/subject edits. C/V. |
| [ui] | Changed | Responsive bounds, all-control/reopen input, species-correct cue, tag/wall/camera handling and bounded redraw work. C/V. |
| [controller] | Changed | Version 16.0.0; bounded native reply/HP correlation with explicit ambiguity; native grab polling/pump before background work; passive native-session priority even OFF; lifecycle resets, flight intent ownership and cleanup failures. C/I/V/TL. |
| [amber_ledger] | Reviewed, retained | Bounded outcome/cost totals; exclusive active/pause/unobserved clocks; currency inflow/outflow without invented reward attribution. TE/TL. |
| [amber_model] | Reviewed, retained | Directed travel-cost feedback, identity-bound observations and bounded passage knowledge. TP/TE/TN. |
| [amber_planner] | Changed | Recurring owned-scent capacity, bounded cost work, maintenance overload subset, normalized need priority and unknown-needs WAIT. TP/TE/TA. |
| [amber_gait] | Reviewed, retained | Native eligibility/acknowledgement, false versus unknown, denial/hysteresis, manual toggle preservation and release contracts. TG/TN/TL. |
| [amber_nav] | Changed | Stale async worker isolation, current root/generation validation, exact stale-body stop and explicit unsupported native route modes. TN/TL. |
| [amber_hunt] | Changed | Same-Humanoid/MaxHealth evidence, generation/manual-pause invalidation and bounded expired exclusions; retained pursuit/corpse pipeline. TH/TL. |
| [amber_care] | Changed | Valid maxima and changing-capacity baseline reset; no nutrition from incompatible measurements; retained pending native-session semantics. TC/TE/TL. |
| [amber_agent] | Changed | Owned feed cancellation even after pending flag clears, unknown native combat wait, idempotent start and consistent overload resumption. TA/TE/TL. |
| [amber_bridge] | Changed | Replaced/removed/schema-mutated configs, old-animal action rejection, actual need/decay observations, held manual input and shared stock attack geometry. TB/TL. |
| [amber_driver] | Changed | Native touch/stick direction ownership, same-frame replacement yield and replacement PlayerModule recovery without overwriting another owner. TD/TL. |
| [amber_ui] | Changed | Territory 0.8.0 and truthful recurring-workload/retention status within the existing single window. TL and source review. |
| [amber_runtime] | Changed | Critical native strike yields once without scans, preserves paused objective time and resumes; native minigame owns input even with automation OFF. TL/I. |

## All 22 existing features retained

Feature identity, default/explicit OFF and permanent-feature semantics remain covered by C `22 features retain the original set and permanent reach`. The feature names below reproduce the preparation inventory. Gameplay claims remain subject to their linked H requirements.

| ID | Retained feature | Current implementation/evidence and remaining acceptance |
|---|---|---|
| R01 | Infinite Stamina | Native recognized consumption profiles and scoped debug ownership; C/N. H025–H031 still require real stamina/displacement, including correction. |
| R02 | Active Recovery | Sustained native Rest, moving pose mask and first-bite yield; C/I/N. H011–H018/H062 remain live open. |
| R03 | Fast Negative-Effect Recovery | Injury/bleeding/venom independently observed, missing amounts unknown; C/I/V. H019–H023 remain live open. |
| R04 | Roblox Anti-AFK | Retained owned idle API/backend and failure/OFF cleanup; C. H044 requires actual session retention. |
| R05 | Survival Bonus AFK | Safe micro-route and danger/manual checks; C/I. H044–H045 require real credit and safe motion. |
| R06 | Automatic Minigames | Legal actual-time scheduler and native input/session identity; C/I/N. H037–H039/H052/H069 require real grades. |
| R07 | Auto Escape | Retained native cadence and friendly baby/capture priority; C/I. H040 requires real escape/carry result. |
| R08 | Permanent Bite Reach | Reversible client geometry and stock eligibility preference; C/N. H032–H036/H064/H067 require accepted server reach. |
| R09 | Bite Range Helper | Small smooth cue; current target geometry, Cobra-only colour and camera cleanup; C/N/V. H048 live open. |
| R10 | Combat Core | Native first-bite/input repair plus honest actual-target/reply/HP evidence; C/I/N/TL. H061–H070 remain live open. |
| R11 | Climb Assist | Native Q mount buffer, Dive priority and current species profiles; C/N. H026/H034 remain live open. |
| R12 | Flight Assistance | Native eligibility, reversible surface intent and distinct talon/dive cancellation; C/I/N. H028–H029 remain live open. |
| R13 | Movement Assistance | Current injury-slow profile lease, no status-amount overwrite; C/N/V. H025/H031 require actual movement. |
| R14 | Speed Assistance | Native gait/scalar coordination and guarded Hippo adapter; C/N/TG. H025/H027/H030 remain live open. |
| R15 | Jump / Leap Assistance | Current species leap profile, exclusions and exact restore; C/N. H026/H031 remain live open. |
| R16 | Outline ESP | Hollow real-player-only ownership and bounded updates; C/V. H046 live streaming/visibility open. |
| R17 | Faction / Health Colours | Independent pack-name hue and HP outline gradient; C/V. H047 live affiliation changes open. |
| R18 | Name Tags | Independent toggle/through-wall visibility, compact positioning and screen bounds; C/V. H046–H047/H049 open. |
| R19 | Long-Range Player Finder | Retained adjustable range, sorted real-player candidates and 24-record cap; C. H046 live population/count open. |
| R20 | Right Shift Menu | One menu binding, focused-text guards, responsive controls and reopen button; C/V. H049 real input/visual acceptance open. |
| R21 | Saved Settings | Validated migration, explicit OFF, backup/readback and hot-reload reconciliation; C/V. H002/H010/H049 live persistence open. |
| R22 | Zoom Unlock | Default ON with saved OFF honored; exact external-value ownership and failure rollback; C/V. H050 real camera acceptance open. |

Territory is the integrated, independently controlled page with **default OFF**. It does not replace an original feature or claim completion of unavailable native route modes.

## Territory preparation items

All **T01–T44** are retained from [PREPARATION_EXECUTION_LEDGER.md](../../feral-amber/docs/PREPARATION_EXECUTION_LEDGER.md). That historical document remains unchanged, including its original limitations. This table adds the 0.8.0 evidence. Each row is **automated coverage / live open** unless explicitly unsupported; source review and simulations do not satisfy its entire original requirement. T21 is the principal newly implemented previously unavailable policy; T38 remains unavailable.

| ID | Original requirement | Current source/test mapping | Remaining scope; live acceptance open |
|---|---|---|---|
| T01 | Freeze baseline artifacts, support claims and replay cases | Both build/test runners; protected bundle hashes; [TL] stable compatibility. | Current server behaviour and current game fingerprint remain live open. |
| T02 | Validated snapshot schema and identity/freshness contracts | [amber_bridge], [amber_agent]; [TL] replaced/schema-mutated config and old-animal action cases. | Native values without timestamps can still be stale; unknown input fails closed. |
| T03 | One survival and interruption arbitration function | [amber_planner], [amber_agent]; [TE] normalized emergency, unknown-needs and stalled-recovery cases. | Real risk thresholds, care availability and resource progress need calibration. |
| T04 | Explicit action/input ownership and manual provenance | [amber_driver], [amber_bridge]; [TD]/[TL] held gamepad, touch and native minigame ownership. | Physical/synthetic provenance can remain ambiguous within the synthetic timestamp window. |
| T05 | Reconciled wall/active/pause/phase clocks | [amber_ledger], [amber_runtime]; [TE]/[TC] pause/goal clocks; [TL] critical-window yield. | Unobserved gaps are classified, not reconstructed; real pause timing remains open. |
| T06 | Run ledger, cost counters and outcome attribution | [amber_ledger]; [TE]/[TL] bounded metrics, currency and unchanged simulated outcome accounting. | Currency and shared HP changes do not identify their native cause or reward source. |
| T07 | Integrated deterministic replay harness | [TL] full bundled 7,200-second native-callback simulation retained. | Two-hex simulated physics/resources are not the full live world or server. |
| T08 | Actual movement-reader and fallback validation | [amber_driver]; [TD] replacement module, touch/stick and same-frame generation handoff. | Current executor/native movement-reader acknowledgements remain unobserved live. |
| T09 | Body, support, turn and stopping profile | [amber_nav]; [TN] width, shoulders, support rails, stopping and body clearance. | Root/body proxies and species turn/fall envelopes lack live calibration. |
| T10 | Shared travel-time/cost estimate and feedback | [amber_model]; [TP]/[TE] directed travel observations and cost-based ranking. | Unobserved travel and care-to-site costs remain estimates, not an optimal route model. |
| T11 | Coarse connectivity and reusable passage knowledge | [amber_model], [amber_nav]; [TN] full mesh, bounded passage graph and detour cases. | No persistent global topology or proof every usable passage is discoverable. |
| T12 | Safe asynchronous route adoption and continuity | [amber_nav]; [TN] forward rejoin, stale worker isolation and root/generation invalidation. | Current streaming/server path latency and real route continuity remain open. |
| T13 | Curvature/speed lookahead and direct-corridor preference | [amber_nav], [amber_gait]; [TN]/[TG] collinear steering, direct corridor and corner braking. | The proposed live 1.10 direct-distance threshold is unmeasured. |
| T14 | Mountain slope, traverse and switchback routing | [amber_nav]; [TN] slow uphill progress and rejection of unsupported vertical modes. | Real mountain/switchback matrix open; autonomous native climb unsupported. |
| T15 | Full-corridor support and descent safety | [amber_nav]; [TN] full-width support, shoulder cliff and trench fixtures. | Finite support samples are not continuous terrain proof or universal fall prevention. |
| T16 | Cause-based recovery and spatial failure memory | [amber_nav], [amber_model]; [TN] distinct expiring recovery cells and bounded detours. | Real tree/basin geometry and recurrence thresholds need calibration. |
| T17 | Gait eligibility, hysteresis and release refinement | [amber_gait], [amber_nav]; [TG]/[TL] denial, false/unknown, manual X and owned release. | Real animal gait, Burst utilization and exact native release need observation. |
| T18 | Land/surface-water transition routing | [amber_nav], [amber_bridge]; [TN]/[TB] checked surface routes, steep-bank rejection. | Real alternate steep-bank exits partial; autonomous underwater/depth routing unsupported. |
| T19 | Strategic starting region and orientation | [amber_planner]; [TP]/[TE] start corners, useful region and retained sweep orientation. | Useful-region/sweep policy is a heuristic, not a globally optimal tour. |
| T20 | Scent deadline and service-time estimation | [amber_bridge], [amber_planner]; [TL] clean falling scent windows and missing-sample bootstrap. | Needs clean numeric falling samples. Native refillTime is configured with a 60-second fallback, not measured service duration. |
| T21 | Workload feasibility and overload policy | [amber_planner], [amber_agent]; [TE]/[TA] full bars, recurrence, overload subset and resumption. | New recurring estimate covers all owned scent, including full bars, and defers claims under pressure. Sustained live capacity and optimal subset are unproved; even the best retained job may remain infeasible. |
| T22 | Stable short itinerary with meaningful priority | [amber_planner]; [TP]/[TE] bounded itinerary, value/time and retained route fixtures. | No complete policy comparison or global optimality claim. |
| T23 | Ranked legal claim/scent entry and exit positions | [amber_bridge], [amber_agent]; [TB]/[TL] ranked precise native access and alternate positions. | Joint departure-aware entry/exit optimization and current native spots remain incomplete. |
| T24 | Progress, latency and completion semantics | [amber_agent], [amber_bridge]; [TA]/[TC] replicated ownership/hold and progress gaps. | Pack progress/ownership can be observed without proving which animal caused it. |
| T25 | Fairness, deferral and intelligent resumption | [amber_agent], [amber_planner]; [TE]/[TC] fairness, suspended return chains and overload revalidation. | Short-horizon comparison cannot guarantee service of unreachable/distant work. |
| T26 | Validated hunger/thirst maxima and care targets | [amber_care], [amber_planner], [amber_bridge]; [TE]/[TL] normalized maxima and capacity-change reset. | Changing maxima now resets nutrition evidence; untimestamped native values can still be stale. |
| T27 | Mode-aware need forecasts and route/care margin | [amber_agent], [amber_care]; [TE]/[TC] recent mode reserves and sparse-drop handling. | Sparse gait changes mix samples; no calibrated per-route resource model/confidence interval. |
| T28 | Bounded food/water/prey candidate index | [amber_bridge]; [TB]/[TL] bounded candidate slices, source refresh and fresh-target checks. | Native source-list creation/helpers remain opaque work despite bounded local slices. |
| T29 | Water discovery, bank refinement and opportunity policy | [amber_bridge], [amber_care]; [TL]/[TC] continuing water rings, current offers and opportunity guard. | Real shoreline offer/blocked-bank quality remains unverified. |
| T30 | Feeding dispatch, ownership and repair | [feeding], [amber_agent], [amber_bridge]; [I]/[TA]/[TC]/[TL] guarded stop, owned feed failure/STOP. | Native/API success is not proof of actual Hunger or Thirst gain. |
| T31 | Whole meal-acquisition ranking | [amber_bridge], [amber_hunt]; [TB]/[TH]/[TL] food versus committed prey and finite meals. | Yield, danger and whole-meal optimality remain incomplete. |
| T32 | Committed prey with feasibility and escape policy | [amber_hunt]; [TH]/[TL] protected/faster prey, useful pursuit and corpse handoff. | Live escape, protection and inaccessible geometry remain open. |
| T33 | Contact geometry and pursuit refinement | [amber_bridge], [amber_hunt]; [TL] shared stock formula and missing-corridor refusal; [TH] pursuit. | Real slope/body extremes and accepted bite geometry remain open. |
| T34 | Attack timing/evidence and shared-combat integration | [combat_input], [amber_hunt]; [I]/[TH] same-Humanoid/MaxHealth, generation and manual-pause evidence. | No current accepted bite observation; an HP decline remains noncausal evidence. |
| T35 | Prey-down to edible-food to completed meal | [amber_hunt], [amber_care]; [TH]/[TL] delayed/depleted corpse and finite multi-meal loop. | Current corpse replication, diet and yield remain unverified. |
| T36 | Productive health recovery dependency | [amber_agent], [recovery]; [TE]/[TC]/[TL] temporary owner, progress, stall and exact release. | Native healing eligibility/rate and denied-recovery outcomes remain open. |
| T37 | Capability coverage registry | [amber_bridge]; [TL] bounded encountered capability registry without live-support upgrade. | Configuration encounters remain PARTIAL/UNKNOWN, never live-verified support. |
| T38 — **Unsupported** | Native climb/flight/depth mode investigation and adapters | [amber_nav]; [TN] `native air climb and depth modes explicitly refuse ground steering`. | Autonomous native climb, flight and underwater/depth transitions are unimplemented. Tested stopping is the fallback, not support. |
| T39 | Bridge cache and exclusion generation/pruning | [amber_bridge], [amber_hunt]; [TL]/[TH] config identity/schema drift, generations and weak expiry. | Known contract drift is checked; arbitrary future schema changes still require revalidation. |
| T40 | Measured work slicing, caching and UI cost | [amber_runtime], [amber_planner], [ui]; [TE]/[TL]/[V] helper bounds, critical skip and redraw counts. | No device callback/FPS budget. Recurrence tests bound expensive travel-cost calls to 4N+1; this does not bound opaque native helper internals. |
| T41 | Lifetime and fault/soak hardening | [amber_runtime], [amber_agent], [controller]; [TL]/[I] construction/cleanup faults and retained soak. | No multi-hour real client memory/performance or native fault-injection acceptance. |
| T42 | Compact truthful Territory presentation | [amber_ui]; [TL] integrated single page/COPY STATUS; recurring pressure source reviewed. | Status remains an estimate; actual device cost/legibility open. |
| T43 | Paired benchmarks and repeated live acceptance | [TE] fixed paired planner benchmarks; [TL] integrated 7,200-second simulation. | Repeated paired live species, full-map retention, intervention and Amber/hour results absent. |
| T44 | Complete release, support table and rollback | Both runners/protected artifacts; [TL] current Territory on protected stable hub; release records. | Published exact-tree CI and live release gates remain separate; packaging does not close missing modes. |

## Territory scenarios

All **S01–S62** below come from [V0_7_SCENARIOS.md](../../feral-amber/docs/V0_7_SCENARIOS.md). The inherited offline scope is reproduced so that partial and incomplete cases remain visible. Linked suites contain the retained fixtures and new regressions. **Every row remains live open.** “Simulated” is automated coverage of a bounded model, not native gameplay completion.

| ID | Original scenario | Inherited offline scope and exact suite mapping | Current addition / remaining requirement |
|---|---|---|---|
| S01 | Start with no living animal; then spawn | simulated; [TL]/[TA] | Old-animal action guards extended; native spawn still live open. |
| S02 | No pack, then join/change pack | simulated; [TL]/[TA] | Removed/replaced config and pack identities invalidate stale work. |
| S03 | Start from each map corner/region | simulated; [TP]/[TE] | Current native starting regions and optimality remain unverified. |
| S04 | Runtime eligible set differs from historical 71/69 | simulated; [TP]/[TE] | No fixed historical territory count is assumed. |
| S05 | High-cost mountain target is Euclidean-near | simulated; [TP]/[TE] | Real mountain cost and route availability remain open. |
| S06 | High-value claim versus nearer low-value claim | simulated; [TP]/[TE] | Policy optimum and current rewards remain unverified. |
| S07 | Ordinary scent deadline becomes tight above .28 hold | simulated; [TP]/[TE] | Clean observed decay is required; recurrence now includes full bars. |
| S08 | Several urgent scent targets plus acquisition | simulated; [TP]/[TE] | Overload decisions now constrain both selection and resumption. |
| S09 | Current claim nearly complete when routine care triggers | simulated; [TA]/[TC]/[TL] | Native near-completion and resource urgency still need live observation. |
| S10 | Critical needs while a claim is near completion | simulated; [TA]/[TC]/[TL] | Most critical normalized known need wins; missing data pauses. |
| S11 | Target becomes occupied | simulated; [TA]/[TC]/[TL] | Actual contested ownership/availability still live open. |
| S12 | Packmate finishes or progresses target | simulated; [TA]/[TC]/[TL] | Observed pack progress is not individual authorship. |
| S13 | Distant eligible work behind repeated nearby work | simulated; [TE] | Fairness cannot make unreachable work feasible. |
| S14 | Maintenance workload exceeds one animal's capacity | partial; [TE] | New all-owned recurrence/maintenance subset tests in TE/TA. Real sustained retention and optimality remain open; historical partial scope is not erased. |
| S15 | Claim progress arrives with realistic jitter/gaps | simulated; [TA]/[TL] | Real progress latency/jitter remains open. |
| S16 | First interaction position is unreachable | simulated; [TA]/[TL] | Native valid alternate positions and actual accessibility remain open. |
| S17 | Flat unobstructed long route | simulated; [TN]/[TD] | Physical live direct-distance/time gate unmeasured. |
| S18 | Long mesh route of tiny collinear waypoints | simulated; [TN]/[TD] | Retained collinear lookahead; actual frame-time/motion unmeasured. |
| S19 | Sharp turn approached at Burst | simulated; [TN]/[TD] | Native gait/corner speed and fall safety need live calibration. |
| S20 | Delayed path result after animal advances | simulated; [TN]/[TD] | New isolated async worker cannot mutate current route caches. |
| S21 | New target then old async route completes | simulated; [TN]/[TD] | Root/character generation additionally invalidates stale work. |
| S22 | Initial root/body overlap with a tree | simulated; [TN]/[TD] | Live body collision/overlap recovery remains open. |
| S23 | Off-center tree, narrow passage and large body | simulated; [TN]/[TD] | Body envelope extremes are not calibrated across species. |
| S24 | U-shaped obstacle/wide orbit | simulated; [TN]/[TD] | No proof the bounded planner finds every passage. |
| S25 | Slow valid hill ascent and switchback | partial; [TN] | Actual slope/switchback matrix remains partial; no autonomous climb adapter. |
| S26 — **Unsupported** | Vertical ledge/native climb transition required | incomplete; [TA] | Unsupported autonomous native climb. Ground steering explicitly yields; manual/native handoff is the fallback. |
| S27 | Cliff, body shoulder drop and narrow trench | simulated; [TN] | Finite support sampling is not a universal fall guarantee. |
| S28 | Bridge/rock overhang above lower terrain | simulated; [TN] | Current terrain/support classification remains live open. |
| S29 | Terrain streams out/in during movement | simulated; [TN] | New stale-worker/root guards; real streaming route availability open. |
| S30 | Server position correction versus legitimate fast motion | simulated; [TN]/[TD]/[TG]/[TL] | Native correction magnitude and real acceptable speed unmeasured. |
| S31 | World reader unavailable/replaced | simulated; [TN]/[TD]/[TG]/[TL] | Replacement control modules now recover without overwriting another callback owner. |
| S32 | Virtual key call rejected, executor available | simulated; [TN]/[TD]/[TG]/[TL] | Actual executor fallback acknowledgements remain live open. |
| S33 | Raw gait false/nil/native denial/delayed acknowledgement | simulated; [TN]/[TD]/[TG]/[TL] | Retained native denial/unknown safeguards; real gait acceptance open. |
| S34 | Manual X and same-direction key during automation | simulated; [TN]/[TD]/[TG]/[TL] | Held gamepad/stick and same-frame touch now yield; disconnect clears ownership. |
| S35 | Land→surface water→land | partial; [TN]/[TB]/[TL] | Surface-route fixture retained; real species bank transitions remain partial. No depth adapter. |
| S36 | Steep/blocked bank or missing exit | partial; [TN]/[TB]/[TL] | Steep/blocked real-bank alternatives remain partial. |
| S37 | Nearby native drink offer, distant coarse lake | simulated; [TB]/[TC]/[TL] | Actual native water offers and resource gain unverified. |
| S38 | Water search spans multiple bounded scan slices | simulated; [TB]/[TC]/[TL] | Native source query cost is still opaque despite bounded local slices. |
| S39 | Repeated tiny thirst losses near water | simulated; [TB]/[TC]/[TL] | Actual drink opportunity effectiveness remains unverified. |
| S40 | Different native need maxima and malformed values | simulated; [TE]/[TL] | New malformed/out-of-range WAIT and changed-maximum reset cases; actual native data may be stale. |
| S41 | Sparse resource drops, changing gait and long idle | partial; [TA]/[TC] | Mode/resource confidence calibration remains partial. |
| S42 | Hungry/thirsty/low HP simultaneously | simulated; [TE]/[TC]/[TL] | Normalized urgency, unknown WAIT and same-maximum nutrition evidence strengthened. |
| S43 | Native feeding pending before public active flag | simulated; [TE]/[TC]/[TL] | Core/native feed ownership and ButtonB approach tested; real progress unverified. |
| S44 | Rejected virtual feeding E with executor available | simulated; [TE]/[TC]/[TL] | Native/executor acceptance and actual gain remain unverified. |
| S45 | Feed animation without resource gain | simulated; [TE]/[TC]/[TL] | Bounded retry budget now survives replicated-flag flicker. |
| S46 | Native feeding ends below target or release fails | simulated; [TE]/[TC]/[TL] | Owned active feed cancellation now also runs after pending clears; real native end/release open. |
| S47 | Edible food/forage/prey competing choices | partial; [TB]/[TH]/[TL] | Yield/danger/whole-meal optimum remains partial. |
| S48 | Stationary close prey while facing away | simulated; [TH]/[TN]/[TL] | Shared core stock geometry retained with conservative Territory margins. |
| S49 | Moving prey, delayed attack result and changing distance | simulated; [TH]/[TN]/[TL] | MaxHealth/Humanoid/generation checks invalidate incompatible delayed evidence. |
| S50 | Prey faster/inaccessible/protected/near another player | simulated; [TH]/[TN]/[TL] | Current protection/escape/native-body behaviour requires live trials. |
| S51 | Native marker advances but prey HP does not | simulated; [TH]/[TN]/[TL] | Marker and HP remain separate; no successful-damage inference from a marker. |
| S52 | HP declines due to another attacker/manual hit | simulated; [TH]/[TN]/[TL] | Manual pause clears stale attribution; other-attacker HP remains unattributed. |
| S53 | Prey dies; corpse delayed/consumed/wrong diet | simulated; [TH]/[TN]/[TL] | Current diet/replication/yield remains live open. |
| S54 | Core combat/reach target state differs from intended NPC | simulated; [TH]/[TN]/[TL] | Shared stock formula and native target ownership tested; real selected target unverified. |
| S55 | Low HP with recovery disabled/denied/no progress | simulated; [TA]/[TC]/[TL]/[TE] | Recovery owner/progress bounds retained; actual healing unverified. |
| S56 | Urgent scent→water→food/another emergency interruption | simulated; [TA]/[TC]/[TL]/[TE] | Overload retention is revalidated on suspended return; real survival outcomes open. |
| S57 | Manual/menu pause, long frame and resume | simulated; [TA]/[TC]/[TL]/[TE] | Critical minigame pauses without scans and preserves goal; real timing open. |
| S58 | STOP/unload during key pulse/path/feeding/bite request | simulated; [TA]/[TC]/[TL]/[TE] | New stale-body/action and owned-feed cleanup cases; actual keys/sessions need live proof. |
| S59 | Repeated animal/map/body changes and reloads | simulated; [TA]/[TC]/[TL]/[TE] | Config schema/root/Humanoid generations guarded; real repeated transition soak absent. |
| S60 | Amber gains, spending, disabled intervals and reset | simulated; [TA]/[TC]/[TL]/[TE] | Currency delta is not attributed native territory income; real Amber/time open. |
| S61 | High NPC/food population and rapid streamed changes | partial; [TB]/[TL] | Bounded slices/caches/critical scan skip improved; native helper internals and hardware budget remain partial. |
| S62 | Multi-hour combined cycle with repeated care/occupation | simulated; [TL] | Existing 7,200-second two-hex simulation retained. No multi-hour native-server/world run occurred. |

## Evidence needed before a full-completion claim

The remaining work is concrete native acceptance, plus the explicitly unavailable capabilities. A minimum review record must pin the candidate source/bundle, game PlaceVersion, species/body, input method, frame-rate/latency conditions and baseline. Preserve the first failure as well as repeated outcomes.

1. **Recovery and conditions:** paired same-MaxHealth HP and separate injury/bleed/venom windows; exclude incoming damage, replenishment, growth and unknown amounts. Include moving/surface-swimming pose and first-bite handoff.
2. **Combat and minigames:** record original input, native Rest/cooldown, WolfBiteAt, actual target/reply and independent HP. Repeat moving/rear/same-tree/multi-attacker cases and record actual own minigame grades. A local cue or callback success cannot close these gates.
3. **Movement and survival:** verify eligible species' actual motion, stamina, talon/dive release, shoreline access, completed meals/drinks and separate survival credit. Universal defense remains unestablished; autonomous Territory climb/flight/depth remains unimplemented.
4. **Territory and performance:** progress from short real routes to repeated 10/30/120-minute cycles with full-map retention, observed needs, Amber deltas, intervention counts and device frame/memory distributions. The two-hour simulation is retained evidence of the coordinator, not a replacement for this test.
5. **Release:** run exact-published-tree compilation/regressions/parity, review the candidate live canary and verify native rollback before any stable-launcher promotion. Historical versioned launchers and bundles remain the rollback path.

The existing cases were retained. Two Territory fixtures were adjusted to strengthen the actual contract: unknown needs now require WAIT instead of optional territory work, and the core-feed conflict fixture exercises guarded `stopNativeFeed` instead of an unsafe start/stop toggle. Neither treats an unobserved gameplay outcome as success.

[C]: ../tests/suite.luau
[I]: ../tests/overhaul_interactions.luau
[N]: ../tests/overhaul_native.luau
[V]: ../tests/overhaul_ui.luau
[TP]: ../../feral-amber/tests/suite.luau
[TE]: ../../feral-amber/tests/efficiency_suite.luau
[TA]: ../../feral-amber/tests/agent_suite.luau
[TN]: ../../feral-amber/tests/nav_suite.luau
[TD]: ../../feral-amber/tests/driver_suite.luau
[TB]: ../../feral-amber/tests/bridge_suite.luau
[TC]: ../../feral-amber/tests/care_suite.luau
[TH]: ../../feral-amber/tests/hunt_suite.luau
[TG]: ../../feral-amber/tests/gait_suite.luau
[TL]: ../../feral-amber/tests/lifecycle_suite.luau
[core]: ../src/core.luau
[settings]: ../src/settings.luau
[policy]: ../src/policy.luau
[grab]: ../src/grab.luau
[grab_input]: ../src/grab_input.luau
[recovery]: ../src/recovery.luau
[feeding]: ../src/feeding.luau
[combat_input]: ../src/combat_input.luau
[rescue]: ../src/rescue.luau
[features]: ../src/features.luau
[roblox]: ../src/roblox.luau
[zoom]: ../src/zoom.luau
[ui]: ../src/ui.luau
[controller]: ../src/controller.luau
[amber_ledger]: ../../feral-amber/src/ledger.luau
[amber_model]: ../../feral-amber/src/model.luau
[amber_planner]: ../../feral-amber/src/planner.luau
[amber_gait]: ../../feral-amber/src/gait.luau
[amber_nav]: ../../feral-amber/src/nav.luau
[amber_hunt]: ../../feral-amber/src/hunt.luau
[amber_care]: ../../feral-amber/src/care.luau
[amber_agent]: ../../feral-amber/src/agent.luau
[amber_bridge]: ../../feral-amber/src/bridge.luau
[amber_driver]: ../../feral-amber/src/driver.luau
[amber_ui]: ../../feral-amber/src/ui.luau
[amber_runtime]: ../../feral-amber/src/runtime.luau
