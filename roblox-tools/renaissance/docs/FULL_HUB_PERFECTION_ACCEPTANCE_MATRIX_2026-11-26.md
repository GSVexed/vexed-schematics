# FERAL FULL-HUB OVERHAUL — ACCEPTANCE, BENCHMARK AND REGRESSION MATRIX

**Preparation artifact only · 26 November 2026.** Companion to FULL_HUB_PERFECTION_PREPARATION_2026-11-26.md. It defines what later implementation must prove. It does **not** assert that any listed gameplay acceptance has already passed.

## A. Immutable references and baseline ledger

| Baseline | State | What is known |
|---|---|---|
| Renaissance 15.7.0 + Territory 0.7.0 | released, stable source pin 3434396b4a9057bdba8c1f146325bd26f697d1ce | 202/202 Renaissance and 263/263 Territory service-boundary cases; native gameplay effects still unverified |
| Renaissance 15.7.1 candidate, draft PR #13 | unmerged, head da2145a4903e04e365cbeb4387825658d1f65a35 | 206/206 Renaissance and 263/263 Territory checks passed; recovery changes not yet live proven |
| Historical mobile recovery data | experimental field evidence from earlier Bear sessions | Out-of-combat HP rate roughly 1%→2% maximum HP/s and venom increments 1→4 during Rest requests in selected observations; not an assertion about the present game server |
| Territory preparation/execution T01–T44 | tracked in PREPARATION_EXECUTION_LEDGER.md | Native climb/flight/depth, full-map workload feasibility and repeated live acceptance remain open |
| Territory scenario S01–S62 | tracked in V0_7_SCENARIOS.md | Mixed simulated/partial coverage; zero new live-completion claims from this prep |

**Evidence ladder:** CODE_STATIC → COMPILATION → REGRESSION_MOCK → RUNTIME_CLIENT_OBSERVED → GAMEPLAY_REPLICATED → REPEATED_PAIRED_LIVE → VERIFIED_RELEASE. Never silently promote an item to a stronger category. A native action request is not a server reply. A server reply is not necessarily persistent benefit. A target HP decline is not necessarily damage caused by this client.

**Issue ledger schema for implementation:** ID, priority, feature, state, baseline version, game PlaceVersion, species/body, triggering conditions, observed symptom, relevant native path/source hash, hypothesised root cause, reproduction, proposed smallest fix, module owner, conflict/risk, tests added, actual paired before/after outcome, rollback, residual blockers and verification level.

## B. New full-hub scenario inventory (H001–H070)

The seventy scenarios below extend rather than replace the existing Territory S01–S62. Cases H061–H070 are the P0 combat-reliability extension documented in P0_COMBAT_GHOST_HITS_AND_MISSING_BITES_PREPARATION_2026-11-26.md. In each, the test record must contain both expected and observed outcomes; a scenario remains OPEN if no real gameplay execution happened. Terms like “should” are acceptance targets, not promises.

| ID | Priority | Scenario / deliberate stimulus | Acceptance outcome | Required proof |
|---|---|---|---|---|
| H001 | P0 | Fresh client and new settings file; start in lobby, then animal spawn | One GUI, correct version, chosen defaults applied once; Territory remains OFF | Active UI, controller version, hooks and persisted state |
| H002 | P0 | Existing saved explicit OFF for Recovery, stamina, ESP, AFK or Zoom | OFF remains OFF through reload and spawn; no hidden owner running | Save/restore and no owned patch/remote |
| H003 | P0 | Unload while active native Rest request | Own Rest(false), owned animation override cleared, manual Rest preserved | Outgoing native signal plus owned attribute state |
| H004 | P0 | Unload during minigame/input lease | Exact native manual binding restored, no strike wake or leaked callback | Bound action snapshot and task count |
| H005 | P0 | Unload during flight, climb, feeding, attack and Territory input | No stuck input, saved physical property, old route or duplicate agent | Input event log and current owner state |
| H006 | P0 | Hot reload during active recovery and combat | One new owner; automatic Rest provenance retained, manual Rest not stolen | Own-character generation and native actions |
| H007 | P0 | Respawn, swap to a different species and return | Old species config/animation/scans removed; correct new profile applied | Before/after config equality and current animal |
| H008 | P0 | Native config ModuleScript replaced/field removed or changed kind | Feature reports WAIT/PARTIAL/UNAVAILABLE with safe fallback; no invalid partial writer | Schema-change fixture and in-game recovery |
| H009 | P0 | Game PlaceVersion changes from captured v2412 | Version-gated assumptions require revalidation, especially Hippo/native callbacks; no silent success claim | Runtime game version and contract digest |
| H010 | P0 | Partial GUI failure, bad storage, chat focus and runtime exception | Restore original state, preserve prior working hub on staging failure | Fault-injection and full listener snapshot |
| H011 | P0 | Missing HP, standing still, out of combat, medium hunger/thirst | Compare full deficit healing ON vs OFF with stable MaxHealth; no growth confound | Matched per-second HP percentage timeseries |
| H012 | P0 | Missing HP, continuously moving | No Rest animation/immobility; native Rest request remains eligible, actual rate measured | Video/pose, own HP and request trace |
| H013 | P0 | Walk→run→surface swim→land while hurt | No unrequested native Rest release except legitimate game lock; mode returns correctly | Rest state, mode, real displacement and HP |
| H014 | P0 | First bite immediately after recovery | Native attack gets a fair first attempt; no hub Rest rearm until eligible | Input timestamp, native bite marker and reply |
| H015 | P0 | Held LMB for successive bites; Right Mouse camera rotates | Recovery must not steal LMB or treat camera movement as attack | Native action and Rest release timing |
| H016 | P0 | Manual Rest R/ButtonY/touch while recovery armed | Manual animation and control win; no automatic false/off fight | Manual intent, owned state and pose |
| H017 | P0 | Downed/held/captured/ability lock during recovery | Native status wins, pose override releases and rearming is safe | Status attributes and owner transitions |
| H018 | P0 | Combat-only HP deficit (no effects) | Do not claim combat HP regeneration unless genuinely observed; no forbidden local overwrite | Same-max-HP combat timeseries |
| H019 | P0 | Positive venom with full HP, including combat tag | Rest may remain eligible for condition recovery with correct attack yields | Numeric venom and native Rest trace |
| H020 | P0 | Positive bleed with full HP, including combat tag | Clearance measured; no false combat HP claim | Numeric bleed, combat and Rest windows |
| H021 | P0 | Positive injury with full HP | Injury independently evaluated; no assumption from bleed/venom | Numeric injury windows |
| H022 | P0 | Status attribute briefly disappears and later returns | Missing amount is UNKNOWN; no forged cure or unnecessary short release | Attribute presence timeline |
| H023 | P0 | Consecutive incoming venom bites replenish amount | Separate replenishment from decay; valid fourfold comparison windows only | Normalized numeric delta events |
| H024 | P0 | Equal incoming attacks with and without any investigated defence | Damage reduction requires real persistent own HP delta and identical known constraints | Controlled matched paired own HP changes |
| H025 | P1 | Sprint/Burst/trot/ordinary walking on each configured species | Actual gait, physical speed and stamina outcome not confused with HUD intent | Mode and root-displacement trace |
| H026 | P1 | Repeated jump/leap/climb on a climbing species | Correct stamina and eligible native movement, safe input restore | Stamina, actual displacement and climb flag |
| H027 | P1 | Swim, surface sprint and bank exit on aquatic/semi-aquatic species | No permanent mode mismatch or unwanted stoppage near shore | Water, movement and real root trajectory |
| H028 | P1 | Flight flap, surface launch and water exit on flight-eligible species | Real takeoff and continued control where native rules permit | Native eligibility, motion and stamina |
| H029 | P1 | Vulture talon/dive released early during nearby threat | Flying continues; no frozen gliding pose or anchor manipulation | Ability/session release and motion trace |
| H030 | P1 | Hippo Crusher active during Shift/X/Z, land and water, Burst denied | Forced-gait scalar restored when ability ends and doesn't bypass native denial | Actual gait/speed, attributes and config restore |
| H031 | P1 | Long session with speed, mobility, leap and stamina all enabled | No overlapping config writers, instability or release drift | Owner lease records and real values |
| H032 | P0 | Bite toward moving prey, open terrain | Correct face/contact strategy, no spam, hit evidence separated | Native marker, reply and prey HP |
| H033 | P0 | Stationary prey/target close but behind or above | Assistance picks physically eligible target; no stuck motion | Facing geometry and actual attack |
| H034 | P0 | Two animals on same climb/tree | Tree/vertical geometry supports genuine eligible bites | Native hit and target HP evidence |
| H035 | P0 | Rapid repeated attacks and high ping | No ghost hit labels, false damage or duplicate buffered bites | Correlated native feedback and own inputs |
| H036 | P0 | Several enemies and one protected/friendly player | Friendly/protection checks correct and target selection stable | Candidate list, affiliation, actual hit |
| H037 | P1 | Minigame 30/60/144 Hz with frame hitches | Earliest legal safe Perfect-window dispatch; no illegal future/backdated time | Own input timestamp, native grade, CPU cost |
| H038 | P1 | Multiple hunters, simultaneous sessions and native bite | Independent own session result, no opponent result counted, LMB retains intended purpose | Native IDs/result stream and attack marker |
| H039 | P1 | Mid-session minigame activation, manual override, early end | Graceful handoff, no old strike wake, correct manual keys | Session binding and exact results |
| H040 | P1 | Capture/auto escape plus friendly baby carry or cub rescue | No wrong getoff/tug or blocked legitimate pickup | Native carry attachment and escape replies |
| H041 | P1 | Feed input before active WolfFeed, then movement to corpse | Real approach protected until native feeding and actual need gain | Feed state, E/input and hunger |
| H042 | P1 | Drink beside shoreline, water offer delayed or blocked | Alternate legal bank, no oscillatory approach or fake refill | Thirst and path position |
| H043 | P1 | Finite edible corpse consumed, then new prey/forage required | Source depletes, new food acquired, nutrition target genuinely met | Hunger and FoodLeft/corpse state |
| H044 | P2 | Roblox AFK idle input and game-specific survival bonus simultaneously | Neither mechanism hijacks manual input; attributed credit is explicit | Platform retention plus survival value |
| H045 | P2 | AFK route recheck while player/obstacle suddenly enters | Safe bounded stop without unsupported underground/clipping technique | Route support and actual movement |
| H046 | P2 | 24+ players entering/leaving tracking range, some streamed out | True real-player ownership, no stale outline/tag, accurate finder counts | Player.Character mapping and GUI records |
| H047 | P2 | Team change/unknown affiliation and varying HP | Pack name colours and HP outline gradient remain distinct | Replicated pack/HP and rendered colour |
| H048 | P2 | Cobra bite helper while other species active | Species-correct range colours, no large text overlay, tiny smooth marker | Video frame and selected target |
| H049 | P2 | Right Shift, native sprint poll, chat focus, scrolling and toggles | One responsive menu without unintended gameplay input | Bound native actions and UI interaction |
| H050 | P2 | Camera zoom and another script changes limits; unload | No conflicting camera lock; restore external replacement | Camera values before/after |
| H051 | P2 | 10/30/120-minute ordinary gameplay, all core features ON where safe | No unbounded allocations, duplicate listeners, timing stalls or increasing work | Reference PC memory, FPS p95/p99, owner counts |
| H052 | P2 | Crowded high-density NPC/player scene during Perfect strike | Timing-critical action not delayed by background target scans or UI | Callback execution cost and actual grade |
| H053 | P3 | Territory tab OFF while using all core features | Absolutely no hidden territory movement, inputs or recovery override | Agent phase, native inputs and UI state |
| H054 | P3 | Territory manual START/STOP/UNLOAD in water, during feeding and combat | One owner; exact input release; no duplicate agent or stranded character | Native mode, input and agent log |
| H055 | P3 | Large map territory claim+rescent workload with deadlines | Feasibility/overload decision based on sustained capacity, not only currently due jobs | Full horizon, jobs/services and deadline misses |
| H056 | P3 | Territory ground, slope, tight tree, bank, cliff, long streamed route | Path continuity, body support and progressive progress; not repeated teleport/backtrack | Physical trace, support and replanning |
| H057 | P3 | Territory requires climb, flight or underwater/depth | Native adapter proves actual transition, else truthful UNSUPPORTED and deliberate fallback | Mode state, transform and native eligibility |
| H058 | P3 | Territory feeding, drinking, hunting and recovery compete | Single survival arbiter, finite corpse/pond, correct priority and resumed root goal | Resource values, attack/care and return chain |
| H059 | P3 | Territory multi-hour realistic species/diet/world scene | Live sustained coverage/retention and valid Amber delta, no manual workaround | Multi-run 10/30/120m native outcomes |
| H060 | P3 | Full combined upgrade release, rollback and hot patch | Bundle source parity, previous stable launch safe, zero known critical regressions | CI, hashes, live canary and rollback |

### P0 combat repair extension — H061–H070

These extend the original sixty and are blockers for claiming combat reliability. See [focused combat root-cause preparation](P0_COMBAT_GHOST_HITS_AND_MISSING_BITES_PREPARATION_2026-11-26.md) for source paths, causal pipeline, hypotheses, instrumentation boundaries and detailed paired-live criteria.

| ID | Priority | Reproduction | Functional acceptance | Evidence |
|---|---|---|---|---|
| H061 | P0 | Eligible close-range normal click without Rest | Native attack initiates and outcome tracked | Original input, WolfBiteAt, hit reply, target HP |
| H062 | P0 | Bite at 0/100/300/700/1000 ms around Rest release | No extra hub-induced lost first bites | Native Rest lock and subsequent marker/reply |
| H063 | P0 | Bite SFX/local impact without damage | Classified as local-only without claim of hit success | Effect, reply and stable HP separated |
| H064 | P0 | Marker but no accepted hit/HP decline | Exact native eligibility and denial isolated | Target, occlusion, cooldown and reply |
| H065 | P0 | Hit reply but no matching target HP decline | Wrong target, growth, lag and replication windows checked | Native target plus delayed same-MaxHP trend |
| H066 | P0 | Moving/fleeing target and rapid turns | Better native accepted-hit rate, not merely closer cue | Matched baseline/candidate replies |
| H067 | P0 | Two animals climbing same tree at different heights | Valid attacks register without false guide | Native elevation, actual reply and HP |
| H068 | P0 | Multi-target and simultaneous other attacker | Correct own-target attribution | Generation, marker, reply and target identity |
| H069 | P0 | Minigame and manual LMB with missing native callback | Hub never steals normal eligible attack | Native handler ownership and real marker |
| H070 | P0 | Same hunting scene under manual and Territory attack | Both paths use real damage evidence, not sound | Prey reply, HP, claimed kill and meal |

## C. Representative species/platform matrix (to expand from observed native profiles)

Use this matrix to plan eligible cases, NOT to assume each capability exists or works:

| Species or body archetype | Important modes/interaction | Core scenarios |
|---|---|---|
| Wolf / ordinary quadruped | Walking, sprint, attacks, recovery, survival | H011–H016, H025, H032, H041 |
| Bear / Tiger | Historical recovery comparison, stamina, combat, body turning | H011–H024, H025, H032–H036 |
| Hippo | Crusher Bite, water gait, large body, slope/body clearance | H027, H030, H031, H056 |
| Crocodile / semi-aquatic predator | Swimming, bank transitions, diet and hunting | H027, H042, H043, H058 |
| King Cobra / Python | Venom, bite range/guide, climbing, climb sprint | H019, H023, H026, H034, H048 |
| Vulture / Eagle | Talon/dive release, flight controls and stamina | H028–H029 |
| Turtle / other native defensive species | Shell/ability state and interaction priority | H017, H024, H025 |
| Unknown or newly updated species | Native profile schema check and conservative fallback | H007–H009, H057 |

**Input/device cross-product:** mouse/keyboard, gamepad and touch where the current UI/native control contract supports them; 30, 60 and 144 frames per second; low/ordinary/high latency; solo, one target, crowded enemies; lobby, match, animal change, death and hot reload. Avoid pretending the full Cartesian product was executed: use pairwise risk coverage, then repeat high-risk combinations.

## D. Before/after measurement protocol

### Per scenario

- Capture exactly the bundle commit, source manifest hash and current PlaceVersion.
- Record what the player intentionally did versus what automation generated.
- Record health and MaxHealth separately; compute HP growth only across same-max, same-character windows.
- Record presence/absence as a state distinct from numeric zero for venom, bleed and injury.
- Record actual target/native server feedback rather than an inferred successful hit.
- For motion, record desired route and physically observed position, velocity and mode, including corrections.
- Preserve first failure and repeated outcome counts; avoid excessive sampling that changes performance.

### Comparison

- Run repeated paired baseline/candidate sessions under comparable species, growth, resource reserve, enemy input and game version.
- For HP compare normalized rate = (HP_after - HP_before) / MaxHealth / seconds, excluding damage/growth episodes. A native Rest multiplier value of 2 is a *hypothesis* until matched live rate is consistent.
- For statuses compare equal initial positive amounts over equal windows, log replenishing attacks and missing attributes. Faster native fade can occur during combat without proving combat HP heal.
- For attacks use independent native marker, game reply and target HP windows; never infer authorship of shared damage.
- For performance compare frame time and latency distributions, not only average FPS or source-line count.
- For Territory compare deadline misses, survival failure, manual intervention, physical travel and credited Amber/time, not mere claimed attempts.

## E. Pass/fail severity taxonomy

| Severity | Release implication | Example |
|---|---|---|
| CRITICAL | Block entire stable promotion | Hub prevents manual play; stuck held input/Rest pose; stale script attacks old character; protected rollback damaged |
| HIGH | Block affected feature and full perfection claim | Recovery stops despite eligible conditions, first bite blocked, minigame falsely consumes LMB, Vulture stuck in flight, Territory never feeds |
| MEDIUM | Fix before final full-hub milestone; may ship isolated safe improvements | Wrong UI version, range guide jitter, poor gait change, missing status explanation |
| LOW | Polish after functional gates without jeopardizing them | Footer wording, visual alignment or minor diagnostic presentation |

A mitigation that merely disables a feature can be acceptable as a temporary safe fallback, but **is not a completed functional fix**. A recovery-monitor event without actual healing improvement remains diagnostic. Passing a mock service boundary proves the software implementation under that test, not live game authority.

## F. Explicit work ledger / release checklist

| Gate | Required before marking COMPLETE |
|---|---|
| G01 | Source, manifest and game-version fingerprint match selected branch |
| G02 | Full 22-feature inventory and 26-module owner dependency graph reviewed |
| G03 | Every P0 feature has no unresolved high-severity interaction |
| G04 | Automatic/manual/native action arbitration passes overlap matrix |
| G05 | Recovery and each condition have reproducible native outcome or remain explicitly UNVERIFIED |
| G06 | First attack after Rest and real bite feedback pass live checks |
| G07 | Minigame result distribution and native timing measured under realistic scene |
| G08 | Every advertised native movement mode has real acceptance, else explicit UNSUPPORTED |
| G09 | Feeding/drinking/survival actions raise actual replicated needs/credit |
| G10 | Territory T01–T44/S01–S62 all mapped; incomplete items not erased |
| G11 | Real hardware performance and memory under extended use are measured |
| G12 | Settings, UI, menu and version render agree with actual bundle |
| G13 | Full exact rollback and off/unload lifecycle return to original game state |
| G14 | All official compilation, integrated regression and deterministic parity checks pass |
| G15 | Repeated native paired tests support the specific benefit claims in release notes |
| G16 | Stable launcher promoted only after review; prior version remains usable |
| G17 | Repeated native-game trials demonstrate improvement in accepted eligible bite outcomes; no merely cosmetic ghost-hit suppression counts as success |
| G18 | First bite after Rest, moving targets, same-tree attacks and native-minigame input collisions pass P0 H061–H070 or have explicitly documented authoritative limitations |

## G. Initial issue queue, not implementation

| ID | Priority | Why it exists | First concrete future action |
|---|---|---|---|
| U001 | P0 | 15.7.1 candidate UI title hard-codes 15.7.0 | Bind visible title to hub.version; test rendered label from full packaged candidate |
| U002 | P0 | 15.7.1 Rest(true) is code-validated but actual 2x/4x current-server benefit is unproved | Run matched recovery/venom/bleed/injury ON/OFF gameplay, preserve numeric data |
| U003 | P0 | No accepted universal damage-reduction path is identified | Trace native incoming-damage/defence pathways and distinguish server from local state |
| U004 | P0 | Rest/attack/pose compete at first native bite | Repeat actual moving recovery then first-bite native marker/reply sequence |
| U005 | P0 | Cross-module priorities are implicit in several owners | Build central action compatibility table and race tests |
| U006 | P1 | High-value minigame success still unverified under real latency/crowds | Replay first-window scheduler under real native minigame replies |
| U007 | P1 | Speed/gait and stamina are client input/config paths, not measured accepted motion | Per-mode species traces with actual displacement/stamina |
| U008 | P1 | Vulture/Eagle cancellation can leave native flight state stuck | Controlled talon/dive end and motion acceptance matrix |
| U009 | P0 | **Ghost hits and attacks failing to initiate/register**; bite sound/marker and accepted server damage are different outcomes | Diagnose native input, Rest lock, target geometry, game reply and actual target HP using H061–H070; fix behaviour rather than only labels |
| U010 | P1 | Water/shoreline, animal climb and depth routes are not complete | Native-capability adapters with conservative unsupported fallback |
| U011 | P1 | Feeding completion depends on native gain and source availability | Repeated resource-limited live meals/drinks |
| U012 | P2 | Current UI has hard-coded layouts and status presentation gaps | All-control click/focus/scale audit and truthful status model |
| U013 | P2 | No real reference device memory/frame budget is calibrated | Profile active/off/loaded/crowded scenes and 10/30/120m sessions |
| U014 | P3 | Territory workload estimator covers due work only | Model full steady-state capacity and overload policy |
| U015 | P3 | Territory 0.7.0 has partial all-animal route support | Implement/validate native mode transitions incrementally |
| U016 | P3 | 44 Territory prep items / 62 scenarios retain live gaps | Run and link each missing acceptance, not rephrase it as done |
| U017 | P0 | Native input-to-bite path may be blocked by Rest, minigames, bindings or unavailable optional callback | Verify the original native bite path and provide reliable, nonduplicating handoff |
| U018 | P0 | Bite-target and feedback transactions may be misassociated; client guide may disagree with actual game target | Correlate each real native target, hit reply and replicated HP with generation/timing; correct false-positive hit feedback |
| U019 | P0 | Tree/vertical, rear, moving-target and species-specific bite acceptance remains inconsistent | Reproduce and close high-risk eligibility/geometry cases using real-game matched hit outcomes |

## H. Closeout rule

This document is a test plan and gate list. It is deliberately not a stable release, performance result, new feature, completed damage reduction mechanism, or proof that all effects work. The user requested preparation *before* making gameplay changes. Next implementation must preserve this exact distinction and drive U001–U019 plus H001–H070 to evidence-backed outcomes.

**Documentation-only change. No source code, settings or launchers are altered by this preparation.**