# All 21 retained features — source trace and completion record

Baseline: v2412 bytecode, independently rechecked (943 payloads; 383 programs; 6,386 prototypes; 866,208 instruction words). Exact trace hashes and capture IDs are in source-traces.json. CLEAN v14 is unchanged.

“Implemented / regression passed” means the owned implementation and simulated service-boundary checks pass. It never means a private server rule changed. Live results are recorded separately.

| # | Function | Native dependency / old implementation | Final improvement | Status and unresolved result |
|---:|---|---|---|---|
| 1 | Infinite Stamina | NeedsConfig, WolfController, FlightConfig, VenomConfig; power | One drain/regen plan, sprint/jump inputs, flap drain, own debug flag; exact restore | Implemented / regression passed. Land/burst/flight/climb/venom gameplay results unverified; historic abrupt deaths have no established cause |
| 2 | Active Recovery | WolfActions Rest, WolfRest, NeedsConfig; native/regen/active/action | One deficit-driven owner; native feeding/approach protected; manual ownership and moving ground support; HP and condition eligibility separated | Implemented / regression passed. Added HP, remote pose visibility, flight/climb recovery and first-bite benefit unverified |
| 3 | Fast Negative-Effect Recovery | StatusConfig HEAL/CLOT/FADE/REST_MULT; regen/native | Linked recovery control; separate three-condition measurement; known combat tag alone no longer suppresses condition Rest; no local 4x-by-4x compounding | Implemented / regression passed. Continuous real 4x clearing not established |
| 4 | Roblox Anti-AFK | Player.Idled, VirtualUser; afk | One subscription, explicit input failure, inert shutdown | Implemented / regression passed. Long retention and FERAL migration prevention unverified |
| 5 | Survival-Bonus Anti-AFK | SurvivalConfig AFK_AFTER/AFK_MOVE, FeralSurvival; afk/action | Bounded walks, intermediate ground checks, cancellation for input/danger, separate credit observation | Implemented / regression passed. Credited survival progress and unattended safety unverified |
| 6 | Automatic Minigames | FeralGrabV2UI, GrabV2Config, FeralGrabV2; grab | Current begin/strike/**res**/bite/**n**/end; isolated bite clicks, original native manual presses, own-character grades, mid-session adoption and missed-crossing retry | Implemented / regression passed. 96-scenario suite includes three-attacker concurrent bite timing. Real Perfect frequency and live simultaneous damage unverified; introspection missing is PARTIAL |
| 7 | Auto Escape | FeralLunge, native shake/tug bindings; escape and missing baby dependency | Native cadence, minigame priority, explicit same-species baby/clamp guard | Implemented / regression passed. Universal escape success and speed unverified |
| 8 | Bite Reach — permanent | CombatConfig / WolfController; reach | Permanent range/height/angle lease; fresh geometry; friendly/protected target exclusion; shared rear/tree candidate; stock-reference cue | Implemented / regression passed. Authoritative extra range unverified; no part resize or extra BiteHit |
| 9 | Bite Range Helper | Geometry, targets, camera, raycasts; combat | One smoothed 15px hollow marker; no text square; stock-reference/extended/blocked cues | Implemented / regression passed. Server prediction and real FPS improvement unverified |
| 10 | Combat Core / Attack Hooks | WolfBiteAt, FeralHit, post-Rest gate; combat/native/action | Bounded original-tryBite retry after Rest; predictive impacts disabled; native target/reply observation; pre-claim HP baseline | Implemented / regression passed. Outgoing claims are not intercepted; damage attribution unverified |
| 11 | Climb Assist | PassiveConfig.CLIMBER, ClimbCan, FeralClimbTap; climb | Allow original Q first, then bounded tap buffer and one retry; Dive wins | Implemented / regression passed. Per-tree/species gameplay success unverified |
| 12 | Flight Assistance | FlightConfig.canFly/WATER, FeralFlyRequest/Drop; flight | Confirmed surface only; temporary permission lease; restore on timeout/action/submersion | Implemented / regression passed. Accepted surface takeoff and underwater exit not certified |
| 13 | Movement Assistance | HURT_SLOW, INJURY.SLOW_PER_POINT; engine | Independent slowdown lease; no status edits | Implemented / regression passed. Server penalties may remain |
| 14 | Speed Assistance | RUN_SPEED/SWIM_SPEED; power | One 1.15x plan; exact rollback and conflict reporting | Implemented / regression passed. Authoritative displacement/corrections unverified |
| 15 | Leap / Jump Assistance | JumpLeapConfig; power | One 1.15x plan, preserving zero/excluded species | Implemented / regression passed. Native/server leap outcomes unverified |
| 16 | Outline ESP | Replicated characters, Highlight; engine | Real-player ownership checked at tracking and rendering; FillTransparency always 1; OFF reconciliation and stream cleanup | Implemented / regression passed. Client replication bounds apply |
| 17 | Faction / Health Colours | FeralPack, Humanoid health; tracker | Green/yellow/red outline reflects current HP; pack hue stays on names; unknown HP is neutral | Implemented / regression passed. Client pack data cannot reveal secret affiliation |
| 18 | Name Tags | Characters/camera; tags plus old billboards | One real-player renderer; plain name with no health % or floating studs; independent toggle and lifecycle | Implemented / regression passed. Does not remove the game's native UI |
| 19 | Long-Range Player Finder | Replicated Players; engine | 300/600/900 presets, accurate counts, nearest 24 tracked | Implemented / regression passed. Streamed-out players unavailable |
| 20 | Right Shift Menu Toggle | CAS/UIS/native Shift polling; UI | One menu and binding, focused-text guard, complete unbind | Implemented / regression passed. Native polling may still sprint |
| 21 | Saved Settings | Own JSON; UI/engine | Schema validation, CLEAN migration, false/true reconciliation, backup/readback | Implemented / regression passed. Requires executor file capability |

## Root causes

1. v14 could display OFF while the bite helper or tags were active.
2. Its comprehensive cleanup wrapper was installed after multiple attaches.
3. v2412 minigame results use res; result/grade/scored listeners miss that reply.
4. Comparison normalization must not change native numeric session IDs on the wire.
5. Current doBite prototype 16 checks WolfRest and REST_UP_LOCK_OF before the marker and Bite request. The default 0.7-second lock is a possible first-bite blocker.
6. v14's local condition base multiplier and Rest multiplier can compound.
7. Missing conditions are not observed cures; HP decline after a marker is not damage attribution.
8. v15.0 attack clicks cancelled pending automatic minigame timing. Native FeralGrabV2Press also consumed MouseButton1 and submitted it as a manual minigame press. Both paths must be separated.
9. Multiple hunters update one native fight through n; another hunter's res must not be counted as the own result.
10. A dropped frame could abandon the first perfect crossing despite a later valid crossing in the same strike. Native bite/end cleanup must still cancel obsolete strikes.
11. v15.0 applied the HP combat exclusion to all native Rest requests, suppressing condition recovery during combat-tag linger.
12. Native feeding can approach for several seconds before WolfFeed becomes active. The old 1.3-second action pause could expire during that approach.
13. A click near FeedCan was incorrectly treated as feeding intent even though normal eating/drinking uses E or its native UI control.
14. Native FeralCombatClient may present an impact from FeralBiteLocal before the FeralHit reply. A client impact is not accepted damage.
15. Sampling HP after the delayed claim could miss a fast HP drop. Baselines now start at the native bite marker.
16. Native biteClaimTarget ranks by bodyGap minus facingDot times two. The guide previously used a different distance-based rank and cached position delta.

## Deliberately excluded

All thirteen removals remain excluded: hunger/thirst assistance; oversized Eagle carrying; Talon cooldown assistance; night vision; camera shake reduction; performance mode; territory rush; automatic claiming; automatic rescenting; hidden territory movement; automatic food/water; visible diagnostics/copy-status; animal/mechanics information.

## Explicitly requested interaction improvements in 15.2

Manual feeding sessions have approach protection, actual hunger/thirst progress observation and at most one native stop/start repair for a stationary stalled session. No threshold-based auto eating, food seeking, forced refill or resource writes were added.

The G-key cub rescue action keeps native CarryConfig age/size/diet/reach rules. It can request one ordinary jump and wait for water-exit eligibility before the normal FeralLunge carry request. A carry attachment is observed separately from dispatch. It does not enable universal underwater pickup or change WATER_OK; server water rules may still reject pickup. Ordinary G/drop behavior remains native. This is the requested cub interaction, not the removed oversized Eagle carry feature.

The final user instruction keeps ESP and tags restricted to real player characters. Litter/NPC metadata is used only for friendly-target filtering and rescue eligibility, never to create NPC overlays.

The user reports a Rhino fight with multiple Honey Badgers. The regression models three hunters using the captured native n protocol; this is not an independent live observation of that fight. Capture strings alone do not prove additional mechanics, and no extra ability feature has been introduced.
