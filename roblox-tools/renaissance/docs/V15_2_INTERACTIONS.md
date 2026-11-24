# Version 15.2 interaction review

The final user scope is real-player ESP only, health conveyed by outline colour without floating percentages/distances, improved native feeding and combat reliability, and a way to attempt rescue of cubs in water. NPC outlines/tags were explicitly declined.

## Verified v2412 client evidence

The source-traces index records the exact capture fingerprints. Raw game programs were inspected as instructions and constants, not executed or published.

| Evidence | Finding and implementation consequence |
|---|---|
| FeralPackMarkers 4588, mates prototype 5 | Pack NPCs have ReplicatedStorage.FeralLitter records with Pack, Alive, Name and Body references. Actual Players service ownership still identifies a player-controlled cub. Litter metadata informs friendly-target filtering and rescue; it creates no overlays. |
| Captured NPC models | FeralNPC, FeralSibling, FeralName and FeralPack distinguish replicated NPC bodies. Names alone do not establish player identity. |
| WolfController 4662, toggleFeed prototype 22 | Native feeding mode can be pending before WolfFeed becomes active. The mode and started flag are the first two upvalues; player and WolfActions anchors are checked before reading that layout. |
| WolfController prototype 186 | Native approach can last several seconds. Once stationary, the controller publishes WolfFeed and dispatches Feed. The hub's old shorter action pause could expire during approach. |
| WolfController prototypes 21/22/24 | Original cancelFeed/toggleFeed own native feeding state. Native FeedStop eaten/nofood ends the session. Repairs must preserve those owners and respect completion. |
| WolfController prototypes 16/19 | The post-Rest guard can reject the initial click. A bounded retry through original tryBite retains native cooldown, capture and other restrictions. |
| WolfController prototype 13 | Native target score is bodyGap minus two times facingDot, using current positions. The guide now matches that score, and known friendly/protected targets are excluded from the modified client geometry. |
| FeralCombatClient 4564, prototypes 113/118/119 | HIT2.PREDICT can turn FeralBiteLocal into an immediate local impact. FeralHit replies are a separate path. The prediction flag is reversibly disabled; native replies remain intact. |
| WolfController prototypes 15/16 | The native bite marker precedes the delayed claim. Sampling HP only at claim time could miss an early decline. Baselines now start at the marker; native local target signals, replies and HP correlations remain separate observations. |
| CarryConfig 98 and FeralCarryClient 4622 | Ordinary cub pickup uses native canCarry and FeralLunge carry. Native age, size, species/diet and range rules are retained. CarryConfig has a species WATER_OK table, but the captured client scan/press path does not read it. Editing that local table would not establish a server-side water fix. |

## Resulting behavior

The tracker and renderer both require actual player-character ownership. The existing 24-player and 300/600/900-stud tracking limits stay intact. Outlines remain hollow and use current health: green at full health, yellow at half, red near zero, neutral when HP is unknown. Names remain plain and pack-coloured. Floating HP percentages and distances are removed.

E and the native feeding UI protect both approach and active feeding from Rest. Hunger/thirst increases are observed, never written. A stationary session with no increase for 4.5 seconds can receive one original-toggleFeed stop/start repair. Movement, attacks, completion/no-food replies, respawn and shutdown cancel pending repair. This does not initiate eating from a low-resource threshold or search for food/water.

Clicks near a feeding offer remain attack inputs. An actual attack can call the original native feeding cancellation before the ordinary bite callback. A bite blocked by the hub's recent Rest exit can wait through the native profile's lock and retry once through original tryBite. It does not issue extra BiteHit claims or bypass pin/cooldown rules. The minigame input separation is preserved.

G keeps normal carry/drop behavior unless an eligible friendly cub in water is selected. Rescue can request one ordinary jump and wait for actual water-exit eligibility, then dispatch the ordinary carry request once. It never changes positions, swim flags, water permission, age/size limits or the cub. The result is recorded as observed only when the own native Carry clamp references that cub. A request without a clamp times out as unconfirmed.

## Validation and limits

96 service-boundary scenarios pass locally, including player/NPC identity, real-player-only rendering, live health-colour updates, protected/friendly selection, fresh geometry, post-Rest native retry, long feeding approaches, one stall repair, actual progress, cancellation, water-exit rescue, unconfirmed pickup timeout, native feedback and concurrent minigame timing.

These fixtures simulate the verified client contract. Live reduced ghost-hit frequency, repaired hunger/thirst progress, water-cub pickup, extra accepted reach and continuous 4x condition clearance require actual gameplay evidence. Private server handlers were not captured. Universal pickup while swimming or submerged is not established. New executor validation is recorded separately in LIVE_EVIDENCE.md; earlier-version results do not validate the new source.
