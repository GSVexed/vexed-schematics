# Renaissance 15.4.0 — first-window minigames and coordinated native actions

Baseline: captured FERAL place version 2412. Exactly 21 retained feature records, permanent Bite Reach, four compact tabs, Right Shift and settings schema 15 remain. No deliberately removed feature returns. The source passes 176 service-boundary regressions and 18 compile checks locally; published and live results are recorded separately in release.json and LIVE_EVIDENCE.md.

## Minigame timing findings

The previous scheduler selected the centre of a native Perfect zone. Its 25 ms look-ahead rejected a centre that was closer than 25 ms unless the line was already inside a much smaller inner interval. For t0=100, speed=1, centre=0.5, width=0.215 and PERFECT=0.32, a packet arriving at 100.480 selected 101.500. That is a reproducible 1.020-second avoidable wait. The preserved 15.3 bundle is used directly in this comparison.

The new scheduler solves the earliest available native Perfect interval in the current or next triangle period. It targets an entry with a 12% inner margin, not the exact boundary. In the same ordinary zone, its scheduled opening is 30.272 ms before the centre. A packet already in that safe interval can dispatch immediately. This is a scheduling comparison, not a measured network or gameplay speedup.

Checks run on the native strike event, Heartbeat and the existing render callback. At most one deadline timer is outstanding; at most four wakes can be created for one strike. Disable, manual minigame input, native end, character change, shutdown and replacement cancel owned work. An early or delayed wake rechecks actual time and current state; it cannot spin or submit an anticipated timestamp. Without task scheduling, the frame callbacks remain available.

Each native strike permits at most one automated submission attempt. Session/strike IDs retain their original types. The actual current server clock is read immediately before sending. No future/backdated time, invented strike, changed PERFECT/SPEED/NEXT_GAP, extra press spam or fabricated grade is used. Later crossings remain eligible after a hitch. Genuine matching own res replies alone update P/G/M counters. Other hunters' results do not end the own pending strike.

A transient native upvalue read failure is now unknown state, rather than proof that the UI session ended. Readable native absence, bite cleanup and explicit end still cancel obsolete work. Submitted inputs are reflected in the matching native UI state when it becomes readable again. Validated native minigame handles can survive hot reload; script and remote identity are checked. The original-equivalent manual binding is restored on release without overwriting another binding owner.

The 72-case replay matrix covers both directions, three zone widths, four positions and 30/60/144 Hz ticks. It checks timestamps and independently evaluates the captured triangle/Perfect formula. These are native-contract simulations, not 72 observed game wins. Server strike issuance, native bite pauses, round cadence, latency and opponent mechanics remain outside this scheduler's control.

## Upgrade decisions and implementation

| Area | Concrete change | Evidence boundary |
|---|---|---|
| Recovery coordination | Native feeding, capture, talon/dive, climbing and flight attribute changes can release owned Rest immediately, before the next Heartbeat | Local action ownership; sustained HP benefit and visible/remote pose remain unverified |
| Recovery measurements | Existing recent HP/condition trends now include observed units per second | A measured slope does not establish a 2x/4x multiplier or causal benefit |
| Minigames while biting | Preserve LMB separation, multi-attacker sessions and native bite input while adding first-window dispatch and bounded deadlines | Native pin, cooldown and other bite restrictions remain |
| Ghost-hit evidence | A real outgoing FeralHit damage reply is displayed separately from an unconfirmed or correlated HP change | No claim interception, extra hit requests or guaranteed damage |
| Crowded/rear targeting | Small distance fluctuations retain the existing eligible assist target; materially better targets can replace it | Client target assistance; accepted extra range is unverified |
| Moving/vertical targets | Selected guide geometry is recalculated from current bodies between full scans; invalid/protected/dead targets cannot keep an active cue | Obstruction searches remain bounded; the marker is not a server predictor |
| Marker presentation | A changed target starts the small marker at that body instead of interpolating through unrelated bodies | Local visual behaviour |
| Flight handoff | Extend the observed airborne talon/dive completion episode to animals accepted by native canFly; keep the exact native mover, intent and stall guards | One normal restart request; live resolution is unverified |
| Vulture cancellation | Retain the same-session retry only for an actual native let-go intent | No generic release spam, anchor or mover edit |
| Climb stamina | Recognised native level drain profiles use the existing walk recovery mode; Python's native climb-sprint drain is covered without granting movement abilities | Changes native client consumption inputs, not server stamina |
| Swim/venom stamina | Cover known swim drain multipliers and venom stamina drain fields alongside land/jump/flap costs | No stamina, HP, venom, hunger or thirst values are overwritten |
| Species support | Use native flight eligibility and native climb levels/species profiles; record observed stamina by locomotion and species | No claimed universal server effect; no extra presets UI |
| Feeding | Lost FeedCan offers and active abilities prevent an inappropriate stalled-session restart | Existing one-restart cap and actual resource-progress observation remain |
| Cub rescue | Abilities/flight/climbing cannot start the helper; character identity is checked before observing a pickup | Native size, affiliation, water and pickup rules remain; no universal underwater carry |
| Player-only ESP | Losing actual Player.Character ownership hides outlines/tags on the next rendered frame | Only replicated real-player bodies; hollow health colours remain |
| Background work | Idle scans adapt from roughly 8 Hz toward 3 Hz as frame intervals rise; active combat keeps its existing scan cadence | Operation scheduling, not a promised game FPS increase |
| Survival Anti-AFK | Recheck the remaining ground route during an idle walk; stop for new holes, water, slopes or obstructions | Unattended safety and survival credit remain unverified |
| Compatibility | Replaced remotes and individual native climb-level tables invalidate old handles/leases | Schema-based compatibility; future updates still require review |
| Input/settings | Cancel timed work on explicit manual takeover; preserve validated handles across reload; retain all existing ON/OFF, backup and cleanup checks | Raw native Right Shift polling remains a limitation; settings format does not change |

## Major architecture work included

The existing central policy now exposes a common activity priority: native menu, minigame, capture, attack, ability, feeding/rescue, movement, manual Rest and recovery. Immediate native-state listeners complement the scheduled policy checks. Minigame deadlines stay with the single existing controller owner and never depend on target scans or the UI text refresh.

All shared config edits still use exclusive reversible leases. Added stamina dependencies include PassiveConfig, VenomConfig and the relevant StatusConfig fields. Replacement of a native level table releases its old edits before planning against the replacement. The native eligibility and resource calculations remain responsible for gameplay; feature state continues to distinguish request, local application, observation and outcome.

## Research targets not promoted into claimed exploits

- Accepted rear/vertical reach, universal stamina and moving Rest benefits still require actual gameplay evidence. This release strengthens their client paths and measurements; it does not prove those server-dependent outcomes.
- Extra damage, faster accepted bite cadence, invulnerability/status immunity and escape beyond native limits have no verified authoritative route in the available capture. Adding speculative requests or cooldown changes could worsen rejected actions; no such change is included.
- Oversized Eagle carry, Talon cooldown changes, forced/full resources and territory automation remain deliberately excluded.
- Settings migration, normal native climb buffering, permanent reach geometry and rollback already met their code-level checks; their working implementations are retained rather than given new feature labels.

## Preservation

CLEAN v14 and complete 15.0.0, 15.1.0, 15.2.0, 15.2.1 and 15.3.0 bundles remain byte-for-byte unchanged. The compiler gate checks their recorded hashes, deterministic packaging, embedded-source parity, no whole-heap scanning, no local HP/resource/status writes and no extra Bite/BiteHit requests. RELEASE_NOTES.md contains complete rollback loaders.
