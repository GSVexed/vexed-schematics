# FERAL whole-client-export review — v1.3

Reviewed 16 November 2026. This is an automated full-corpus surface audit with
manual source-guided review of feature candidates, their consumers, native
request protocols and gates. It is **not** a claim that every reconstructed
line has been manually proved correct or tested. No exported game source was
executed. The hub uses its own code and original already-loaded game modules.

## Coverage and method

Every available game analysis body was read, SHA-256 deduplicated and scanned
line by line. The index links every logical script entry to its preserved source
files and line locations for literal attribute signals/writes and network call
sites. All 59 configuration surfaces and all 107 client controller/UI surfaces
were surveyed, followed by deeper reads of the relevant control branches.

| Coverage | Count |
|---|---:|
| Logical game source exports mapped | 339 |
| Distinct reconstructed text bodies read | 221 |
| Distinct bytes read | 9,261,120 |
| Distinct lines processed | 235,378 |
| Configuration bodies | 59 |
| Client controller/UI bodies | 107 |
| Shared logic/visual bodies | 25 |
| Data/asset bodies | 30 |
| Literal remote call sites indexed | 222 |
| Literal attribute change-signal sites indexed | 230 |
| Candidate module-name lookups indexed | 374 |

The 228 game canonical file sets in the earlier integrity/syntax report become
221 distinct byte bodies because some different file sets contain identical
text. The logical count remains 339. These are different counting units, not
lost scripts. Of these distinct byte bodies, 161 have accepted baseline syntax
and 60 have rejected syntax; 80 logical game exports reference rejected bodies.
The earlier 64 rejected game file sets include identical byte bodies.

All 22,283 preserved Roblox platform canonical file sets were also read for
unambiguous FERAL identifiers, WolfController, Phantosuchus and the exact
PlaceId: **79,683,153 bytes, zero missing payload files, zero matching file
sets**. This reduces the chance that the game/platform heuristic hid obvious
game files. It is not a semantic proof of classification. The earlier compile
audit of all 22,511 game/platform file sets remains applicable; platform content
stays preserved in the original complete export.

The [machine-readable index](FERAL-CLIENT-SURFACE-INDEX-v1.3.json) and
[every-file inventory](FERAL-CLIENT-FILES-v1.3.md) make scope inspectable.
Literal scanning misses computed keys, calls through functions and multiline
expressions. A lookup is only a candidate dependency. False flags can be
decorative values or damaged reconstructed aliases. Presence does not establish
live eligibility or server validation.

## What changes the implementation decision

| Finding | Evidence in the exported source | Result |
|---|---|---|
| Stamina has a private client accumulator | S0003620 WolfController; S0000033 NeedsConfig | Keep working cached tuning; do not return to attribute-only refill loops |
| Health configuration has no recovered literal client consumer | HEALTH_REGEN and HEALTH_REST_MULT occur only in S0000033 across the distinct game bodies; no literal .Health assignment or TakeDamage call was found in them | The actual health writer is still outside the recovered implementation; no added healing claimed |
| Speed inputs are consumed by the controller | S0003620: RUN_SPEED at 1939, 6857, 6928 and related paths; SWIM_SPEED at 6949 | Add bounded reversible cached-input profiles, with actual effect pending runtime testing |
| Leap distance has its own cap | S0000117 JumpLeapConfig; S0003620:5145–5186 | Tune body lengths and forward-speed cap together; preserve zero snake entries and native exclusions |
| Rest has a native client action entry point | S0003620:3808–3876, FeralRestTap listener and WolfRest binding | Request native Rest with guards, deduplication and an acknowledgment timeout; no HP writes |
| Owned coat equip has a normal protocol | S0003659:388, wearCoat(slot, coatId); S0003625 sync uses slots/active | Equip only freshly reported owned coats on a matching current active slot; wait for a new matching sync |
| Rewards use reported state and normal claims | S0003658 state/paid handling; S0000064 RewardConfig | Claim already-eligible rewards only; no amount parameter or extra local playtime |
| Calm camera/performance have native client settings | S0000060 SettingsConfig; S0003641 FeralRunCamera; S0003717 FeralPerfMode | Reversible local setting controls, without reimplementing entire camera or draw systems |
| Restricted assets do not imply playable eligibility | S0000088 AccessConfig, S0003625 menu, user's failed spawn/buy attempts | Keep previews and access explanations separate from accepted spawns |
| Apparent unlock hook is a Studio visual | S0003625:20746–20753, FeralDbgUnlock inside IsStudio(), calling unlockFx() | Do not add a misleading unlock-all button |
| Debug shop price is presentation | S0003644:239 onward, FeralDbgShopPrice adjusts displayed product information | Do not present this as a cheaper real purchase or spendable money |
| Soundboard/debug tools have early gates | S0003632:15 owner predicate; S0003651 IsStudio() | A missing panel may never have been constructed. Changing visibility cannot create an owner role |
| Film/cinematic playback is coordinated | S0003676 and S0003722: FeralCine/FeralCineMode plus beat/focus/done calls | Avoid forcing lifecycle fields and presenting that as accepted growth or normal gameplay |
| Owner mutations cannot be validated from this client export | S0003719 gift UI; S0003699 save UI; no recovered server handlers | No fabricated grant success or destructive save operation |

Locations refer to the baseline filtered source bodies indexed here. Several
have known reconstruction errors. They are evidence for interfaces and design,
not runnable replacement game scripts. The absence of a literal writer does
not rule out indirection, omitted code or reconstruction defects.

## Interesting systems retained for future work

| Area | Evidence / interesting detail | Practical boundary |
|---|---|---|
| Species and scale | S0000035 Species, growth/sex/body scales, stages and stats | Client definitions are reference values; do not establish server stat grants |
| Elder progression | S0000072 GrowthConfig, S0000107 ElderConfig, ElderPaint/Icons/Scars | Elder mechanics and cosmetic scar/fade data exist; local appearance is not real elder progress |
| Thriving/regrowth | StatusConfig and S0000112 RegrowConfig, FeralThriveUI/GrowUI | Separate needs, growth boosts and post-death regrowth; eligibility is game controlled |
| Territory/grazing | S0000067 and TerritoryHUD/TurfSight | Hex claims, activity thresholds, home/grazing effects and payouts; server grants absent |
| Survival amber | S0000070, FeralSurvivalUI | x1→x2 in nominal ten-minute steps, then fifteen-minute steps toward x3; credited time remains server controlled |
| Other amber sources | S0000045 AmberConfig, QuestConfig, PlacesConfig, PackConfig | Survival, quests, discovery, pack/PvP-related settings; balance changes need causal evidence |
| Quests and goals | S0000053, S0000081, QuestsUI/GoalUI | Disabled templates coexist with active mechanics; alias defects prevent treating every reconstructed table literally |
| Status interactions | S0000085, S0000103, StatusUI, VenomClient | Injury, bleed, venom, resting and slowing have separate inputs; status spoofing is not a confirmed cure |
| Grab/escape | CombatConfig, AbilityConfig, FeralLungeUI | Tug, mash and directional timing differ; faster Space spam is not a universal solution |
| Special movement | FlightConfig, DiveConfig, PassiveConfig, Flight/Dive/Climb clients | Species-specific flying, diving, climbing, oxygen/stamina and crash rules; not one universal movement switch |
| Fox dens | DenDiveClient, PassiveConfig | Digging, materials, holes and underground oxygen budget; not unlimited protection |
| Bird combat | TalonView/LockClient, DiveBombClient | Talon struggles, locks, phase reporting and high-speed impacts; server outcomes unobserved |
| Cobra combat | KingsClient, VenomClient, AbilityConfig | King Cobra strike/throw/spit/hiss branches; VARIANTS=false is a lead, not permission to grant every branch |
| Carrying/hippo/elephant/bison | CarryClient, HippoClient, ElephantClient, BisonFX | Dedicated state machines, target requirements, events and visuals rather than generic buffs |
| Scent and resource guidance | S0000079, FeedFinder, Forage, Sniff/GoalUI | Food/water/grass/animal categories, budgets and range/cooldown settings; forage availability may be server synchronized |
| Vulture Death Sense | PassiveConfig and FeralDeathSense | Low-health target outline mechanic belongs to the native species system |
| Weather/ecology | WeatherConfig, Drought/FloodConfig, SkyCycle, WaterLooks, Atmosphere | Season/weather and pond/flood phases; admin buttons do not establish event control |
| NPC ecology | NPCConfig, CritterConfig, FishConfig, ScavengerConfig and clients | Herd/ambient/fish/scavenger behavior; configuration presence is not a live population census |
| Littermates | S0000089, OnboardingConfig, PacksUI | ENABLED=false with sibling/group/catch-up definitions; no proof of release plans or a working client-only activation |
| Cosmetics | S0000065, CoatRecolor/Masks, ElderScars | Texture/mask decoding, recolor metadata and coat variants; original binary assets and ownership are separate |
| Calls/sounds | AnimalCalls, SoundboardList, CallMixConfig, CallsInput/CallMix | Growth-dependent voice/pitch and audio tooling; owner soundboard availability is gated |
| UI/platform integration | HUD, UIKit, mouse/joystick, overview, settings, text fitting, chat/title/news | Useful controls and presentation systems; private player/chat data is not collected by the hub |
| Performance | PerfConfig, PerfMode, clutter/water LOD, animation budgeting | Existing native culling and comfort controls are preferable to scanning the world every frame |
| Admin/debug | AdminUI, TestNew, WolfB, PerfTest, gift/save tools | Owner/Studio gates and server interfaces are distinct; none is reported as unlocked |

## What the two v1.2 reports actually show

The reports named FERAL_Field_Report_v1_2_1794848654.json.txt and
FERAL_Field_Report_v1_2_1794849299.json.txt appear to be two snapshots of the same
run: the lookup timestamps match and uptime advances by about 645 seconds.
There was no explicit session ID in v1.2, so this is an inference.

The later report retained only 600 of 1,071 events; **471 earlier events were
dropped**. Combining the two files cannot restore the missing middle interval.
That directly motivated the preserve-first journal, session IDs, checkpoints
and verified numbered parts in v1.3.

| Observation | Evidence | Interpretation |
|---|---|---|
| Tiger tuned sprint | 59 samples; minimum stamina fraction 0.99814 | Supports stamina retention in those observed conditions |
| Tiger tuned burst | 63 samples; minimum 0.99037 | Supports observed retention; not a promise for every cost/species |
| Tiger tuned swim | 17 samples; minimum 0.99818 | Same scope; zero exhausted samples across these groups |
| Mobility tuning | Fields applied; only two untuned sprint samples | Insufficient comparable control data for a speed-benefit claim |
| Ordinary non-rest healing | 11 / 75 selected regular non-combat, unchanged-max gain intervals; median about 1.0% max HP per second | Existing game recovery, with no hub HP writer running |
| Ordinary resting healing | 23 selected regular non-combat, unchanged-max gain intervals; median about 2.0% max HP per second | Consistent with the native rest multiplier; **not** added hub regen |
| Three retained HP drops | All in combat; one followed a gain within one second | Gain-then-drop timing alone does not prove a rollback |
| Gift/save access | Cached gift/saves/developer predicates not matched; both lookup summaries unexpected_reply | No usable own-save result or privileged access established; old classifier hid reply shape |
| Coats listed owned | Bear Spirit, Elephant Desert | Useful input for an equip feature; a fresh current reply is still required |
| Amber 5,816→6,273 | +457 visible balance across snapshots; paid notices zero | Normal balance growth observed, without proof of a hub-caused award |

Healing interval selection required a positive delta, unchanged maximum,
same generation, no combat, and 0.75–1.3 seconds since the preceding retained
health event. It is an observational subset, not a controlled regen test.
The user reports that the added regen trial failed; this remains the project
result. We do not relabel ordinary healing as a successful experiment.

## What remains unknown

The server-only Health implementation, entitlement/currency handlers, grant
validation and private server save logic were not retrieved. Previously found
raw decompilation defects remain unresolved. Some runtime code may be indirect,
streamed, inaccessible or changed after the captured window. A complete export
within recorded scope does not mean all original game code was obtained.

No additional blind full scan is needed to use this work. The next useful test
is the new client controls in Roblox, with the focused report if something
fails. The [goal review](FERAL-GOAL-REVIEW-v1.3.md) separates implemented controls,
observed effects and still-unmet gameplay goals.
