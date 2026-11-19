# FERAL project continuation

## Latest — 19 November 2026: FERAL NOVA PRIME v15 published (Recovery & Movement Overhaul)

User agreed “ok go on” after discussing v15 priorities: preserve successful infinite stamina; restore the earlier observed native Rest-signal recovery without breaking combat; allow eligible same-species adults to pick up the user's baby; make tree climbing from a sprint much easier; investigate rather than fabricate effective bite-range server acceptance; preserve v14 water/flight/carry, ESP and Turtle. Growth should NOT be modified.

**Recommended launcher:** `loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v15.0.lua"))()`

**Published files:** [15-module standalone](feral-nova-prime-standalone-v15.0.lua), [modular launcher](feral-nova-prime-v15.0.lua), [Native Recovery](feral-nova-native-recovery-v15.0.lua), [Baby Friendly Carry](feral-nova-baby-v15.0.lua), [Integrated Quick Climb](feral-nova-climb-v15.0.lua), [Baby-aware Escape](feral-nova-escape-v15.0.lua), [Combat guide](feral-nova-combat-v15.0.lua), [Clean Regen observations](feral-nova-regen-v15.0.lua), [Safe Rest](feral-nova-recovery-v15.0.lua), [Mobile A/B Rest](feral-nova-mobile-v15.0.lua), [G carry handoff](feral-nova-carry-v15.0.lua), [Flight handoff](feral-nova-flight-v15.0.lua), [UI](feral-nova-prime-ui-v15.0.lua), [documentation](README-feral-nova-prime-v15.0.md), [CI](../.github/workflows/feral-nova-prime-v15-validate.yml).

**Primary v15 changes:**
- Native Recovery reuses the observed v1.3 `WolfActions:FireServer("Rest",true)` with local guarded `WolfRest=false` masking; sends bounded reassert requests only when HP deficit or injury/bleed/venom present; tracked own Rest=false cleanup on attack (including sustained held Mouse1/2), G carry, Q climb, jump/flight, active flight/dive, capture, chat, Turtle species and character change. Default ON but separate toggle; observations report masked Rest HP/status rates without falsely attributing them to v14 config-only non-Rest regen. Main goal of **server-accepted always-on 2× HP/4× condition clearing during combat remains UNPROVEN**, since activity pauses may be necessary.
- Baby same-species pickup: `Growth<=.34`, adult same species `Growth>=.67`; suppress `getoff` with verified other adult outgoing FeralClamp.Value pointing to own infant, or bounded 12-second same-species-nearby fallback (proximity cannot prove friendliness); `FeralPinned/FeralDragged` always override. Default BABY CARRY ON; optionally OFF if hostile same-species grab concerns.
- Integrated Quick Climb: from v1.0 standalone, Q buffered 1.3s; native `FeralClimbTap` exactly once upon `ClimbCan`; reversible client grab distance/facing/mount settings and sprintGrab levels 1/2; preserves DiveCan and G carry. Main hub Q CLIMB ON/OFF, no secondary overlay.
- Combat guide: v14 cached nonphysical Reach remains; now records Mouse1 attack attempts in extended-only windows and native `WolfBiteAt` started afterward. User's v14 100 eligible windows and 0 bites, so no server-side bite-range success claim.
- Identical `feral-aurora-power-v14.0.lua` Endurance, protecting user-reported Bear ~417s activity, 244s burst with 0 lost stamina; no Growth edits. v14 Water Flight, native G carry, Turtle Safe Rest, ESP etc retained with Native handoff.
- The 15 source modules are embedded into one standalone snapshot; one paste and no per-module network dependencies.

**Tests:** Official Luau and all previous v14 regressions plus new tests for masked Rest/observed HP/injury updates, carry/Mouse1/held attack release, same-species infant/outgoing clamp plus pinned/dragged override, integrated Q-buffer/native ClimbCan/Dive safety/config restoration all passed in [final run 44581329632](https://github.com/GSVexed/vexed-schematics/actions/runs/44581329632). Earlier v15 runs failed only from temporarily stale standalone embedded modules while making updates, then final exact rebuild passed.

**Limits:** GitHub runner does not have live Windows/Roblox Velocity access. The 2×/4× non-rest recovery, friendly pickup acceptance, server-accepted extra bite range and tree mounting during a chase still need live FERAL evidence. Be clear about the difference between local config, native request and actual server-accepted effects. If issues appear, use v15 COPY STATUS, especially Native Recovery, Baby Carry, Quick Climb, Extended Mouse1/Bite and Endurance. If old v7/v8 root expansions persist, rejoin FERAL fresh.

---

## 19 November 2026: pre-v15 discussion; v14 remains unchanged, standalone Quick Climb tested

**New user concerns:** Explain what was changed for successful infinite stamina; why older health/bleed/venom recovery appeared to work and v14's non-Rest recovery does not; infant same-species pickup fails (possible Auto Escape); virtual bite reach seems useless; Q tree climbing during a sprint/chase requires getting very close or multiple presses; growth appears fine. User previously asked to **discuss before making v15**. Respect that: do not silently promote or replace v14.

**Verified v14 Endurance method:** [power-v14](feral-aurora-power-v14.0.lua) sets own `WolfDbgNoStamina=true`, reasserts it, and leases local NeedsConfig `STAMINA_REGEN*3`, `STAMINA_REST_MULT=1`, `STAMINA_REGEN_DELAY=0`, `STAMINA_LOW_NEEDS=1`, `STAMINA_SPRINT_DRAIN=0`, `STAMINA_JUMP_COST=0`. User's Bear report: 417.13 s land tracked, 243.61 s burst, 0 stamina losses and 0 StaminaOut transitions, stamina 52.8/52.8, no-drain flag true. Strong observed effective infinite stamina; server policy still private.

**Why recovery regressed:** older [Recovery Hub v1.3](feral-recovery-hub-v1.3.lua) sent native `WolfActions:FireServer("Rest",true)` and locally masked `WolfRest=false`; recorded ~2% max HP/sec outside combat, venom fade 4 points/tick versus 1 before, bleeding 4 point declines even in combat. [Health findings](FERAL-HEALTH-FINDINGS-v1.1.md) affirm: combat HP regen was NOT established, injury remained untested. V9–V14 eliminated/restricted this native Rest-mask strategy because forced WolfRest edits conflicted with bites and Turtle shell. v14 main [regen](feral-nova-regen-v14.0.lua) changes local HEALTH_REGEN*2, HEALTH_NO_REGEN_IN_COMBAT=false and status HEAL/CLOT/FADE*4 without native Rest. Latest v14 report shows no verified non-Rest regen enhancement. Prior observed feature did exist, so goal is to restore the *useful server native Rest request* safely, conditional on carry/climb/flight/combat, not just display local config edits.

**Baby pickup:** recovered `S0000505` CarryConfig constraints MIN_CARRIER_GROWTH=.67, MAX_BABY_GROWTH=.34, SAME_SPECIES=true, MAX_SIZE_RATIO=.55, DIETS carnivore/omnivore, NEVER Python, range/facing/pack/safe/fitness checks. `S0003938` FeralCarryClient scans actual native eligible nearby baby and uses G. `feral-nova-escape-v14.0.lua` always chooses `getoff` when *own baby has FeralCarried=true*, regardless of whether the carrier is a friendly same-species adult. User's recent v14 capture had 2 getoff requests, 2 grab episodes and 0.22 s longest, consistent with auto-escape preempting friendly carry (not proof of server release cause). Proposed next release: explicit friendly-baby carry permission that suppresses getoff ONLY if own Growth <.34 and another eligible **same-species adult actually has outgoing FeralClamp.Value pointing to own character**. Preserve hostile grab escape; no blanket exclusion for same species. Meanwhile, disabling Auto Escape temporarily is a diagnostic/workaround for agreed friendly pickup.

**Bite reach:** v14 client CombatConfig claim-window REACH=1.769 vs1.45, HIT_SCALE1.38 vs1.15, CONE79 vs71. Latest report: 100 client extended-only eligible samples but **zero extended-only bite starts or HP drops**; no proof of extra server-accepted range. Never advertise working extra damage from local config alone. Current nonphysical patch avoids v7/v8 root-collision trouble. Further research needed against live actual attack threshold and server acceptance.

**Climbing source:** archived `S0003916` FeralClimbController binds native **Q**; native UI uses `LocalPlayer:SetAttribute("FeralClimbTap",time)`; `ClimbCan`, `FeralClimbLocal` indicate ready/mounted. `S0000492` PassiveConfig.CLIMBER: GRAB_REACH=.9, GRAB_FACING=.55, E_REACH=1.6, MOUNT_TIME=.32, HINT_RANGE=14, sprintGrab absent for levels 1/2; low-level climbers cannot grab trunks at sprint speed according to reconstructed client. Q isn't buffered and overlaps Dive on Q, so one early press may fail.

**Shipped independent OPTIONAL add-on, v14 unchanged:** [Quick Climb v1.0](feral-quick-climb-v1.0.lua), [instructions](README-feral-quick-climb-v1.0.md). One-line launcher after v14: `loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-quick-climb-v1.0.lua"))()`. Q intent buffers 1.3s, triggers native `FeralClimbTap` once when ClimbCan is true, modest reversible climb grip/reach/facing/mount config, level1/2 sprintGrab, protects Dive, carrying, resting, captured, already climbing. Has a small status overlay and Copy Status. [Official Luau + simulated Q buffering/mount/Dive/restoration PASS](https://github.com/GSVexed/vexed-schematics/actions/runs/44575239585). No live server climbing test, game may still reject extended reach/mount. v14 source not overwritten and no v15 promotion.

---
## Latest — 19 November 2026: NOVA PRIME v14 integrated feature upgrade

**User asks:** Stop piecemeal releases and deliver meaningful upgrades. Specifically: Kali Hub reportedly has increased hitboxes, so reproduce useful extra FERAL bite reach **without the physical collision trap from v7/v8**; 2× actual HP regen and 4× injury/bleed/venom clearing **outside of Rest and in combat**; Bald Eagle can sustain burst/sprint without land-animal sudden-death events; birds become trapped in water and cannot fly away after picking up prey; enhance water takeoff and air carry without disabling native G/drop; Auto Escape should be **good and reliable, not suspiciously instant**. User shared v13 status confirming Endurance true but \`own_no_drain_flag=false\`, last grab 2.67 s with 18 progress changes, combat candidate config (REACH 1.45, HIT_SCALE 1.15, CONE 71, SLACK 1.2, MAX_DY 2.5), many native carry transitions and no physical edits. **Do not ask the user to repeat these requirements.**

**v14 now published:** [recommended standalone](feral-nova-prime-standalone-v14.0.lua), [full release document](README-feral-nova-prime-v14.0.md), [modular loader](feral-nova-prime-v14.0.lua), [CI tests](../.github/workflows/feral-nova-prime-v14-validate.yml). Exact 12-module single-file bundle. [Latest full validation run passed](https://github.com/GSVexed/vexed-schematics/actions/runs/44565612406) with official Luau compilation, source equality, simulated Endurance attribute reassert, reversible nonphysical bite reach and health/status config, water flight/prey carry cleanup, and all prior G/escape/safe-rest regression tests. **No live Velocity test.**

**Source-verified game mechanics from archived source ZIP** (located in container at \`/mnt/data/files/UPLOAD_PART_002_DATA.zip\`, \`UPLOAD_PART_003_DATA/sources/game\`):
1. \`S0000508\` FlightConfig: \`WATER={NO_TAKEOFF=true,GRACE=1.2,HINT="CAN'T FLY FROM THE WATER!"}\`; \`canFly(character)\` function checks eligible species and growth. \`S0003941\` FeralFlight watches \`FeralFlyRequest\` (own char attribute), uses \`FeralFlyLocal\`, \`FeralFlyDrain\`, and \`FeralClamp.Mode=="drag"\` for airborne talon carry. \`S0003869\` WolfController writes \`FeralFlyRequest=os.clock()\` on native flight action.
2. \`S0000448\` NeedsConfig: \`HEALTH_REGEN=.01, HEALTH_REST_MULT=2, HEALTH_NO_REGEN_IN_COMBAT=true\`; separate stamina fields \`STAMINA_REGEN=1.31\`, \`STAMINA_SPRINT_DRAIN=.94\`, \`STAMINA_JUMP_COST=6\`, and its rest/regen delay fields. \`S0000500\` StatusConfig recovered individual \`INJURY.HEAL=.45\`, \`BLEED.CLOT=1\`, \`VENOM.FADE=1\`, each \`REST_MULT=4\`. However decompiler reused variables incorrectly in that file: runtime module may be different, so v14 requires real matching config fields to patch them.
3. \`S0003869\` WolfController normal \`BiteHit\` claims use cached shared \`CombatConfig\` with \`REACH\`, \`HIT_SCALE\`, \`CONE\`, \`SLACK\`, \`MAX_DY\` and \`bodyGap\`. Client-only virtual body gap can affect *claim selection* without setting enemy root size. **Server can still reject extended claims.**
4. Flight and land have distinct client stamina drain paths, flight checks \`WolfDbgNoStamina\`. In v13 user's Endurance was ON but flag false. [v14 power](feral-aurora-power-v14.0.lua) now applies land sprint/jump cost zeros and rechecks the own no-drain flag every ~0.75 s even for the same character; reports reassert attempts and flight/land stamina gains/losses and large burst HP losses.

**v14 concrete code:**
- [Reach](feral-nova-reach-v14.0.lua): own cached \`CombatConfig.REACH\` ×1.22, \`HIT_SCALE\` ×1.20, \`CONE\` +8°, \`SLACK\` +.35, wrapped \`bodyGap\` -0.72 studs. Does **not** change opponent sizes/physics. Tracks owned reversible original values, restores on OFF/CLOSE. [Combat guide](feral-nova-combat-v14.0.lua) separates native window vs extended-only candidate, bite counts and HP declines correlated with the extended window (never claims server proof).
- [Regen](feral-nova-regen-v14.0.lua): tries cached \`NeedsConfig.HEALTH_REGEN\` ×2 and \`HEALTH_NO_REGEN_IN_COMBAT=false\`, plus \`StatusConfig.INJURY.HEAL\`, \`BLEED.CLOT\`, \`VENOM.FADE\` ×4. Keeps separate non-rest HP/condition-rate measurements under combat/peace/unclassified labels and no direct writes to own HP or status. **Server-side permanent effect remains UNPROVEN**; if actual cached StatusConfig missing fields, report partial.
- [Water/flight](feral-nova-flight-v14.0.lua): patches \`FlightConfig.WATER.NO_TAKEOFF=false\`, \`GRACE=0\`, honors canFly(species/growth), checks water locally and calls native \`char:SetAttribute("FeralFlyRequest",os.clock())\` on jump. For an outgoing \`FeralClamp\` during water takeoff or mid-air pickup, temporarily writes \`Mode="drag"\` locally, restoring original before G, when flight/attempt ends, on death/character change or close. G always has priority. **Actual flight and prey retention are game/server controlled.**
- [Carry](feral-nova-carry-v14.0.lua) preserves native helper/drop when pickup Can=false and coordinates flight's \`beforeCarry\` cleanup.
- [Escape](feral-nova-escape-v14.0.lua) controlled getoff .435s, tug .12s, shake .17s, outgoing carry/G grace and true victim priority. User prefers believable reliable release not instant.
- [UI](feral-nova-prime-ui-v14.0.lua) clean six cards, one Endurance, NON-REST REGEN card, small optional A/B TEST on card (temporarily releases baseline non-rest regen before mobile Rest comparison, auto-restores afterward), quick REACH, WATER FLY, SAFE REST, native CARRY G; auto enables Endurance, Regen, Reach, Flight and existing ESP/Agility/Clear View on launch. SAFE REST and mobile Rest trial remain OFF by default to avoid blocking attacks.
- Dedicated v13 core disabled old unsafe \`WolfRest=false\` mask. Reused v13 recovery/mobile, v8 near-camera tags.

**Limitations/next evidence:** GitHub CI demonstrates source edits and state-machine correctness, *not* private Roblox server acceptance. Still unverified: damage truly accepted outside native range; server-controlled health/negative-effect regen during combat; water flight takeoff with another animal actually retained; whether Eagle has a different server anti-exploit threshold. If user returns live v14 reports, compare \`observed_combat_hp_per_second\`, \`injury/bleed/venom_*_per_second\`, \`boosted_only_hp_drops_near_bite\`, \`water_prey_takeoffs\`, \`flight_with_prey_seconds_local\` and \`WolfDbgNoStamina\` flag and land/flight trace. Do not present local patches as validated server results or accuse users for failed feature acceptance. If previous physical hitbox v7/v8 remained loaded, require a fresh Roblox join before v14 to clear local geometry.

**v14 launcher:**
\`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v14.0.lua"))()\`

---

## Latest — 19 November 2026: NOVA PRIME v13 full-system audit (single recommended release)

**What the user repeatedly requested:** A FERAL hub whose features genuinely work together; reliable automatic escape from Tiger and other grabs, natural carrying and dropping without interference, all-the-time useful health/negative-effect recovery rather than simply the game’s normal Rest, beneficial attack range without physically obstructing other animals, compact outline-only ESP with names at close range, one Endurance switch, real agility, Turtle shell support, and honest server-side impact. They are frustrated by incomplete single-feature releases. **Do not repeatedly ask them to restate goals.**

**Published latest:** [single-file v13](feral-nova-prime-standalone-v13.0.lua), [v13 guide and feature status matrix](README-feral-nova-prime-v13.0.md), [modular v13](feral-nova-prime-v13.0.lua), [regression workflow](../.github/workflows/feral-nova-prime-v13-validate.yml).

**Recommended loader** (Velocity, after fresh join if previous v7/v8 hitboxes modified client geometry):
`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v13.0.lua"))()`

**Root causes fixed and code:**
1. [Mobile v13](feral-nova-mobile-v13.0.lua) moved predator/victim carry classification ahead of `AssemblyLinearVelocity<1.6` early termination. A predator holding prey no longer disables the experiment when slowed to zero; pauses and auto-resumes after dropping, with >.85s G input grace.
2. [Recovery v13](feral-nova-recovery-v13.0.lua) moved carrying/capture recognition before `WolfRest` and Turtle shell early returns. Cancels its owned native Rest request while carrying; preserves game G action.
3. [Engine v13](feral-aurora-engine-v13.0.lua) disabled unsafe legacy `startRestMask` code which used `char:SetAttribute("WolfRest",false)` and refused to turn on the deprecated third recovery path. Safe Rest/Mobile are the two coordinated owners.
4. [Carry v13](feral-nova-carry-v13.0.lua) allows game-owned `_G.FeralCarryPress` drop path even when `_G.FeralCarryCan` says a new pickup is unavailable. Exposes actual native-helper availability, tracks last G intent and throttles expensive helper polling ~8Hz. Still never sends guessed native server carry remotes.
5. [Escape v13](feral-nova-escape-v13.0.lua) suppresses speculative predator-side escape during ~.58s own G transition, **without** blocking true pinned/carried victims. Reads bindings only while there is an own grab cue, and uses captured min-gap-compatible getoff (.405), tug (.105), shake (.153/.155). Server instant release still not proven.
6. [Combat v13](feral-nova-combat-v13.0.lua) explicitly reports carry-related normal bite restriction from WolfController rather than pretending attacks while carrying are valid; reports active client CombatConfig inputs to investigate perceived range. Only reads other animals; collision scan throttled to ~2Hz.
7. [UI v13](feral-nova-prime-ui-v13.0.lua) defaults close-camera screen name tags ON on first v13 use (`FERAL_NovaPrime_Display_v13.json`); clean outline ESP stays. Prior default was OFF. Mobile displays TEST, Endurance/Agility show CLIENT (not server-verified) and Copy Status includes Power.status lease matches and precise statuses. Compact six-card layout and contextual Carry/Drop G quick control remain; no scrolling.
8. Standalone v13 bundles nine modules byte-for-byte, reducing inconsistent multi-HTTP fetch startup failures. Proper close/reset calls continue to restore reversible owned patches and key inputs.

**Final CI passed:** [GitHub v13 comprehensive workflow run 44555521453](https://github.com/GSVexed/vexed-schematics/actions/runs/44555521453). Checks official Luau compile of all dependencies and standalone, bundle file equality, native carry predator/victim distinctions, helper drop when pickup Can=false, G action cooldown and Rest-off-before-carry ordering, mobile pause while stationary carrying and auto-resume, true victim escape despite G grace, and Safe Rest cancellation while the Rest attribute remains active; static source checks prevent fake HP/Amber, enemy part-size modifications, and unsafe legacy WolfRest edits. **These are offline/mock tests, not a Roblox server.**

**Server-dependent unresolved goals (do not misrepresent them as fixed or cheat boosts):**
- Permanently active server-authoritative **2× health regeneration / 4× injury, bleed, venom clearing while running, carrying and attacking**. Archived config exposes multipliers for **native Rest only**. V13 Mobile A/B moving trial remains **experimental, OFF by default**; a local Rest attribute or remote request alone never proves server-authoritative effect. User's prior report measured ~2.19 HP/s resting vs ~1.04 HP/s not resting (only ordinary Rest effect). Client source exports did not include private server handlers.
- Instant Tiger grab escape. Prior v9 log had 47 shake native requests, 44 shake progress changes and ~5.83s grab. Input cadence and cue fixes do not bypass game/server thresholds.
- Server-accepted extra bite range / hitboxes. V7/v8 enlarged local target HumanoidRootPart and caused physical obstruction; v9+ removed it. Bite Guide reports client range only, not server-accepted damage.
- Unlimited stamina, invulnerability, free Amber, restricted species: local config/client remote attempts cannot simply grant server authority. Avoid fake numerical labels.
- Native carry/drop press can be attempted through native `_G.FeralCarryPress` or G injection; successful server pickup **not yet live verified**.

**PC access:** Connected GitHub code runner is available for repo changes/tests, but there is NO direct live Windows/Velocity desktop access in this chat. Do not claim a new version is fully live-tested, do not promise background completion. Future work should prioritize reliable source-backed features over making unsupported server-influence promises.

---

## Latest — 19 November 2026: NOVA PRIME v12 carry-critical repair

**User feedback:** "if im trying to carry something then why would i want it to not work? and tons of these features arent at the level need, please fix this." This followed v11's non-specific "stop on grabs/ability keys" logic in Mobile Recovery and prior escape misclassification. The user expects native carrying prey/carcasses not to be blocked by Auto Escape or recovery. Do not treat ordinary carrying as an incoming victim capture.

**New client-source verification** from attached archive `UPLOAD_PART_002_DATA.zip`:
- **S0003938 FeralCarryClient**: the game natively binds `FeralCarry` on `CarryConfig.KEY` (G in relevant game code), exports `_G.FeralCarryPress` and `_G.FeralCarryCan`, checks own `FeralClamp` ObjectValue with `Carry` to choose drop, `FeralCarcassCarry` to drop carcass, and chooses target `carry` or carcass `pick`. Native remotes include `FeralWorld("carry", target)`, `FeralWorld("release")`, and `FeralCarcassCarry("pick"/"drop")`; nova does not fabricate these.
- **S0003896 FeralLungeUI**: `FeralCarried` on own character is being carried by another animal, with separate `FeralCarryEscape` binding. Own `FeralClamp` with prey is the hunter's outgoing grapple; the UI includes a `PREY/YOU` tug distinction.
- **S0003869 WolfController**: `tryBite` returns when own `FeralClamp` exists, a native combat restriction, not introduced by NOVA.
- `FeralPinned`/`FeralDragged` are capture/victim states distinct from carrying. No current client evidence proves a bypass of the server's forbidden carry+attack combination.

**Published v12 files**: [single-file launcher](feral-nova-prime-standalone-v12.0.lua), [modular loader](feral-nova-prime-v12.0.lua), [native Carry](feral-nova-carry-v12.0.lua), [Carry-aware Escape](feral-nova-escape-v12.0.lua), [Carry-aware Mobile Recovery](feral-nova-mobile-v12.0.lua), [Carry-aware Safe Rest](feral-nova-recovery-v12.0.lua), [UI](feral-nova-prime-ui-v12.0.lua), [guide](README-feral-nova-prime-v12.0.md), [CI](../.github/workflows/feral-nova-prime-v12-validate.yml).

**Changes:**
- A contextual `CARRY / PICK` or `DROP / RELEASE` quick-strip button invokes the game's native helper when accessible, otherwise sends normal G via executor key injection if supported; manual G always remains usable. Native capability and pickup eligibility remain game/server-dependent. .39s accidental double-action cooldown.
- Escape ignores outgoing prey/carcass carries, but retains protection when own character is actually pinned or carried; prints `CARRYING / ESCAPE NOT NEEDED` and no escape packets while hunting.
- Mobile Rest compatibility experiment pauses and cancels **only its own Rest signal** on G or while holding prey. It **remains enabled and resumes baseline** after release, without requesting Rest that might block carrying.
- Safe Rest refuses to request Rest while holding prey/carcass and sends its own Rest=false before a deliberate carry. The carry button schedules native helper ~0.17s after Rest release if preemption was necessary.
- No enemy RootPart edits, no fake rewards, no claim of always-on 2× HP/4× negative-effect recovery or guaranteed instant escapes.

**CI results:** official Luau compilation all modules+standalone, nine source modules embedded byte-for-byte, pure carry predator-victim classification tests (prey, carcass, dragged/pinned/carried), native helper/keypress path and throttling, Rest-off-before-native-carry ordering, mobile G pause + resume, and escape suppression while carrying but shake when captured. Last successful run: https://github.com/GSVexed/vexed-schematics/actions/runs/44550415231 . Offline tests cannot prove server carry success.

**Recommended one-line launcher:**
`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v12.0.lua"))()`

**Caveats:** Fresh join is still advisable after old v7/v8 physical hitbox edits. Do not claim successful server carry or persistent server regeneration until measured in live session. GitHub runner is not a PC runner or access to live Roblox.

---

## Latest — 19 November 2026: NOVA PRIME v10, clean physical geometry and honest 2×/4× Rest tracking

**User feedback after v9 (November 19):** User could not physically approach other animals; requested health regen boost and 4× clearance of injury/bleed/venom. Latest v9 copied report: Auto Escape observed 22 shake requests, 19 shake progress changes, one release in 3.34s; attack guide 22 own bite starts, 16 nearby HP decreases, no verified longer hitbox effect; v9 Safe Rest enabled but 0 Rest requests and 118 old danger blocks, while normal-state healing showed 80 positive intervals. This was actionable.

**Root cause/limits:** V7/V8 locally resized enemy HumanoidRootPart X/Z to 1.65×. Interrupted shutdown may leave client-local geometry enlarged until rejoin. Never guess another model's original size or blindly change CanCollide: fresh FERAL session is the proper reset. V9 already stopped resizing; V10 adds read-only nearest-root X/Y/Z, CanCollide, CollisionGroup and throttled ray obstruction category diagnostics, with `physical_part_edits_by_v10=0` guaranteed by code. User must fully leave/rejoin once before loading V10, then compare collision without hub.

**Archived game config evidence:** S0000033 NeedsConfig HEALTH_REGEN=.01, HEALTH_REST_MULT=2; S0000085 StatusConfig INJURY.HEAL=.45, INJURY.REST_MULT=4, BLEED.REST_MULT=4, VENOM.REST_MULT=4. These are **Rest-mode game rules**, not an always-on local multiplier. Reconstructed StatusConfig has known decompiler anomalies; live server handlers are inaccessible. Also S0003620 WolfController locally sets WolfRest and sends Rest bool; reading WolfRest alone cannot establish server acceptance.

**V10 recovery:** Keeps Safe Rest explicitly OFF at startup. Opt-in REST RECOVERY can request native Rest at full health when own FeralInjury/FeralBleed/FeralVenomAmt positive; or when SnappingTurtle wants protective shell while safely stationary. Proximity block reduced from 62 to 32 studs, idle/movement/combat guards preserved. Own Rest requests end on movement/attack/damage and do not spoof server Health/Rest attributes. Measures observed HP and status rates during/resting vs normal, only within unchanged-max and stable Rest-mode intervals; explicitly reports server-acceptance limitation. Continuous 2×/4× while moving/fighting is **not demonstrated**.

**Published:** [v10 launcher](feral-nova-prime-v10.0.lua), [guide](README-feral-nova-prime-v10.0.md), [collision/bite module](feral-nova-combat-v10.0.lua), [recovery module](feral-nova-recovery-v10.0.lua), [UI](feral-nova-prime-ui-v10.0.lua), [CI](../.github/workflows/feral-nova-prime-v10-validate.yml). Reuses v9 native escape module (source-guided directional shake/tug/getoff) and v8 near-camera screen names. Six main controls, one Endurance choice, Bite Guide, no fake hitbox changes.

**Validation:** official Luau 0.747 compile for complete module set, native escape/carry simulation, native bite geometry + read-only collision ray classification, full-health injury Rest request / actual injury decline, auto-rest OFF + combat cancellation, opt-in full-health Turtle shell Rest. All are offline CI tests; they cannot attest that server-approved recovery increased 2×/4× or that close-approach collision is fixed in live FERAL. Linked GitHub runner has no direct Windows desktop control.

**V10 launcher:** `loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-v10.0.lua"))()`

---

## Latest — 19 November 2026: NOVA PRIME v9 combat-first repair after user live failures

**User reports:** v8 combat was ineffective; Tiger grabs remained lethal and escapes were far too slow. V8 generated 14 native escape requests and 8 key pulses while the last grab was FeralPinned, Hitbox Test peaked at 3 locally expanded enemy roots and 6 local part writes but there were **0 native bite starts recorded**, and health/rest telemetry recorded 5 transitions with no attribution to actual healing. The final copy report was from the animal menu, so live HP/Stamina were both unavailable. All claims of guaranteed hit/escape/server health should be avoided.

**Critical recovered client causes:**
1. **S0000056 AbilityConfig** has `SHAKE_MASH=false`, `SHAKE_MIN_GAP=.15`, `TUG_MIN_GAP=.10`; S0003647 FeralLungeUI enables `FeralShakeTaps` A/D (directional) or `FeralTugTap` while tugging, and uses `FeralCarryEscape` getoff with .4s gap. Old v6 escape checked FeralShakeMash/FeralTugTap **but omitted FeralShakeTaps** and sent shake at .23s regardless of tug state. More frequent input is still not guaranteed to escape because server validation is private.
2. **S0003620 WolfController** `doBite` immediately refuses an attack while `WolfRest` true. V8 auto Rest (ON by default) could block bites at critical times. The exact attribution for user's loss remains unproven, but this is a real code conflict.
3. Enemy RootPart local size changes in v7/v8 had no demonstrated server-accepted hit benefit despite peak three local resized parts, so no honest "working hitbox expander" claim.

**Published v9:** [launcher](feral-nova-prime-v9.0.lua), [guide](README-feral-nova-prime-v9.0.md), [escape](feral-nova-escape-v9.0.lua), [safe recovery](feral-nova-recovery-v9.0.lua), [read-only bite guide](feral-nova-combat-v9.0.lua), [UI](feral-nova-prime-ui-v9.0.lua), [CI](../.github/workflows/feral-nova-prime-v9-validate.yml). Reuses stable v8 near-camera ScreenGui names, old v2.1 core and v3.1 reversible movement/power.

- **ESCAPE:** Reads FeralPinned / FeralCarried / FeralClampN / FeralClampGame / FeralShakeNeed, monitors active directional/tug/mash/carry bindings, sends relevant native action at bounded .112/.163/.415s intervals, tracks FeralShakeHave progress and observed release. Space input is a fallthrough, not asserted working. No ALT needed. This is not proven fast escape against live Tiger yet.
- **SAFE REST:** Defaults OFF. Purely observes native Turtle shell state until explicitly enabled, then only tries Rest after 3s idle, no close living player in 62 studs, 5s without input, 7s without damage, no combat status, and health deficit. On attack/WASD/Space, it immediately sends owned Rest=false, avoids damage-state combat conflicts. Does not write WolfRest or Health.
- **BITE GUIDE:** replaces fake HITBOX TEST with actually computed client target eligibility using `CombatConfig.bodyGap/REACH/SLACK/HIT_SCALE/CONE/MAX_DY`; small projected dot and Bite Ready / Move Closer status. Absolutely no enemy root resize or external BiteHit emission. Counts own WolfBiteAt, observed adjacent HP losses, and attempted attacks during WolfRest. Underlying server still validates.
- Six large controls remain: Endurance, Auto Escape, Outline ESP, Agility, Safe Rest, Clear View. One stamina switch and no scrolling. On-screen name tags and ESP unaffected. UI reports state honestly. Re-running v9 triggers v8 cleanup and restorations when possible.
- **Offline CI** official Luau compile, static wiring, native escape decision tests, simulated multiple shake/getoff requests with progress, safe Rest OFF test and combat cancel, native bite guide geometry and Rest blockage. **No live Velocity/FERAL session test**, and no direct PC access from GitHub Actions.
- The prior v8 Turtle shell client rule was `SnappingTurtle`, `WolfRest=true`, `WolfRestAt` elapsed >1s, returning nominal .30 for client-side shell. Server damage may differ; permanent moving protection remains unverified. Turtle resting may block bites, so do not re-enable forced auto-rest without careful reasons.

**V9 launcher:** `loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-v9.0.lua"))()`

---

## Latest: TURTLE update and server-source access check — 18 November 2026

User switched back from Booga and is loading FERAL. They report updates and want to know whether the server code can be obtained; prior client internals must be treated as historical until refreshed.

Read the official public game metadata at https://games.roblox.com/v1/games?universeIds=10771881861 on 18 November 2026. It identifies root PlaceId `108901361810209`, universe `10771881861`, creator Elasmonian Games (group `109771238`), current title `[TURTLE🐢] FERAL 🐺 Animal Survival`, updated `2026-11-18T04:50:09.536Z`, and **`copyingAllowed: false`**. The official game page independently shows the TURTLE title. The public metadata check used no Roblox credentials and did not download a place file.

Public searches for the exact game/creator, source releases and uncopylocked copies, including GitHub repository searches for Elasmonian and the exact game name, found **no verified creator-published server-source release**. This is a bounded negative search result, not proof that no private or unindexed repository exists. The community page required JavaScript and did not expose readable announcements, so its contents were not verified.

Roblox's [access-control documentation](https://create.roblox.com/docs/scripting/security/access-control) states that server-only scripts/modules in ServerScriptService or ServerStorage do not replicate to clients. A client executor or decompiler therefore cannot recover their absent bytecode merely by scanning the PC or requesting normal gameplay data. Shared ModuleScripts in replicated containers can include both client and server branches; inspecting those may reveal partial shared logic but must not be described as retrieving the complete server implementation. No new FERAL shared-module exposure has been established in this turn.

Documented full-project access routes are developer-granted Studio Edit access, an owner-supplied project/source copy, or an owner-enabled public place copy/source release; see [allow copying](https://create.roblox.com/docs/projects/configure-games#allow-copying). Public copying is disabled for the current game according to the metadata above. Do not claim a private-server purchase grants Studio/source access or advertise a server-code extractor.

The existing full client dataset is dated **16 November 2026**. It contains 339 logical game-source exports and 37,648 platform-source exports; it does not contain private FERAL server scripts. Historical recovery captures did not fix 64 reconstruction failures. **No post-TURTLE in-game client capture has been taken yet.** A refresh should compare game-source paths/content and remote definitions against that baseline, include newly replicated/shared modules, and keep reconstruction defects explicit. No need to re-export the large Roblox platform corpus solely to establish whether FERAL changed. Existing Aurora FORCE v3.1 has not been verified against this update; do not represent the web metadata check as compatibility testing.

---

## Most recent: Aurora FORCE v3.1 — power-first pivot (17 Nov 2026)

The user explicitly rejected Aurora v3.0's target selection/waypoints,
saying they are useless and that they want "gamebreaking" high-impact game
features. A long list of informational research cards and weak controls
wasn't meeting this goal. The just-created waypoint-oriented v3.0 repo
files should **NOT** be linked as the recommended build.

Built Aurora FORCE v3.1:
- [launcher](feral-aurora-force-v3.1.lua)
- [own-client power module](feral-aurora-power-v3.1.lua)
- [POWER/ESP/SURVIVAL/SETTINGS UI](feral-aurora-force-ui-v3.1.lua)
- [guide](README-feral-aurora-force-v3.1.md)
- [Official Luau CI](../.github/workflows/feral-aurora-force-v3.1-validate.yml)
- Reuses existing v2.1 engine for status, ESP, Rest requests, low-needs,
  injury slowdown, comfort/settings and optional local status storage.

One-line Velocity paste:
`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-aurora-force-v3.1.lua"))()`

Actual meaningful controls:
1. Stamina STOCK / RECOVER / APEX. RECOVER patches client
   STAMINA_REGEN 3x + STAMINA_REST_MULT 1, regen delay 0, low-needs
   factor 1. APEX uses recovered earlier Field Hub v1.4 combination
   STAMINA_SPRINT_DRAIN=0, STAMINA_JUMP_COST=0, STAMINA_REGEN=250,
   STAMINA_REGEN_DELAY=0, STAMINA_LOW_NEEDS=1, and own
   WolfDbgNoStamina=true. As tested previously on Bear and Tiger client
   samples: user-reported near-full local stamina during movement; **NOT**
   proven server-approved, universal or safe; previous 107/107 HP ->0
   death during Burst remains unresolved. Aggressive power OFF by default.
2. Standalone WolfDbgNoStamina client flag toggle, owned restoration
   including respawns, with notice if APEX still owns flag.
3. Bounded 1.15/1.30/1.50 cached RUN_SPEED and SWIM_SPEED profiles;
   1.15/1.35 cached forward-leap profiles; reversible restoring original
   module values where still owned.
4. Optional ALT-held rapid Space (170ms pulses) using executor
   keypress/keyrelease if available, stops when chat textbox focused;
   in-game acceptance unverified.
5. Reuses local injury slow inputs, low-needs recovery factor, optional
   native Rest Request Assist, colour-coded locally rendered ESP
   150/300/600/900 range, tags, health, through-wall display, comfort,
   compact own-resource HUD and optional local autosave.
6. New status panel visibly separates applied client config from
   server-held buffs; no bogus health/food/water/Amber toggles.
The standalone low-needs setting is disabled before enabling a stamina
profile so the same config field isn't leased twice; UI prevents
standalone toggle while profile already includes it.

All power features start OFF and Restore All/close attempt owned
reversion; full CI runs official Luau compile + source-based checks.
**No assistant live Velocity test.** Only one-line launcher needed;
user explicitly doesn't want another diagnostic.

Project source updated on GitHub. Live game reports still are NOT
automatically sent to GitHub; PC runner lacks a wired Velocity collector.

## Most recent hub release: Aurora v2.1 (17 November 2026)

The user tried Aurora v2.0 in the animal-selection menu (confirmed in chat)
and pasted a status with Species/HP/Stamina/Hunger/Thirst/Growth all --,
Amber=8272, recovery ON, 4 Rest requests/2 local WolfRest echoes,
Player Finder ON at 900 range but count 0; mobility/speed/calm and
throughWalls also locally enabled. Missing own stats in menu is NORMAL.
v2.0 Player Finder incorrectly required own spawned HumanoidRootPart, so
it skipped other players when menu was active. Existing Windows GitHub
runner was inspected; **no automatic Velocity status-to-GitHub upload
bridge exists**. Script source/code and handoff are synced by assistant
GitHub commits, not live game telemetry.

Responding to strong user feedback ("upgrade everything", hunger/thirst
fill, enable effects, tons of missing features, no more diagnostics),
published full v2.1 hub:
- [v2.1 launcher](feral-aurora-hub-v2.1.lua)
- [v2.1 engine](feral-aurora-engine-v2.1.lua)
- [v2.1 UI](feral-aurora-ui-v2.1.lua)
- [v2.1 guide](README-feral-aurora-v2.1.md)
- 74-entry v2.0 atlas retained
- [Luau/static workflow](../.github/workflows/feral-aurora-v2.1-validate.yml)

Loader:
`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-aurora-hub-v2.1.lua"))()`

11 pages HOME, SURVIVAL, EFFECTS, RECOVERY, MOVEMENT, PLAYER FINDER,
AMBER, PROGRESSION, WORLD, ATLAS, SETTINGS. New Survival scans bounding
parts by replicated food/water names with explicit click, limit 1100 parts
within 500 studs, adds water POI candidates, seven pin-to-compass rows and
native guidance. Does NOT claim to actually fill Hunger/Thirst.
Also adds an opt-in reversible client NeedsConfig.STAMINA_LOW_NEEDS
0.5-to-1 multiplier switch for the *local* low-needs stamina recovery
penalty. This is NOT actual hunger/thirst restoration or survival protection. Player
Finder now can use current camera position in animal menu, has explicit
search origin, total other players, replicated living characters and
in-range count with reason for zero. New Effects page shows nine
individual replicated ailments/bonuses and actual helpful available
Recovery Assist, reversible local injury movement inputs, warnings and
food/water shortcut; no faux Thriving or Grazing grant. Session state
now says ANIMAL MENU, IN GAME or SPAWNING in UI and clipboard export,
and no misleading unavailable values as zero.

Other v2.1 improvements: mini own-stat HUD, local-only JSON own-status
autosave every 120 seconds if enabled + writefile supported, up to 60
own-character records per session; opt-in OFF by default, no other-player
names, coords, chat, credentials or server sources. GitHub auto-sync
NOT configured: no secret/token passed to Velocity, no silent network
telemetry. Settings include Comfort/Survival/Explorer presets, Restore All,
and feature statuses ARMED/WAITING vs LOCAL CLIENT VALUES APPLIED.
Re-running launcher closes v2.0/v2.1 screens and known earlier FERAL hubs.
World selector clears a previously pinned food/water point.
Neither build has been live-tested by assistant in Velocity; official
Luau 0.747 compile and source static checks are the current validation.
Preserve prior script versions; don't claim all features affect server
authority or protect against long Burst deaths.

User doesn't want more diagnostics. Future changes should be code-first,
respond to concrete UI reports without requesting full live scans.
If auto GitHub report sync is desired, it needs an explicitly opted-in
local file collector plus private upload pipeline; do not claim runner
automatically transfers Velocity clipboard/file data.

## New active interface build: FERAL AURORA v2.0 (17 November 2026)

User asked for a major self-directed upgrade: LOTS of features, beautiful
cohesive Roblox UI, responsive toggles/interaction, no missed obvious QoL;
then specifically requested attractive player nametags and character outline
ESP to find other people. No more huge diagnostics are wanted.

Published **AURORA v2.0** as modular Lua under roblox-tools:
- [One-line launcher](feral-aurora-hub-v2.0.lua)
- [Engine and player finder](feral-aurora-engine-v2.0.lua)
- [Original nine-page UI](feral-aurora-ui-v2.0.lua)
- [74-entry mechanic atlas](feral-aurora-atlas-v2.0.lua)
- [Full guide](README-feral-aurora-v2.0.md)
- [Luau 0.747 compile + static check workflow](../.github/workflows/feral-aurora-validate.yml)

Velocity launcher:
`loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-aurora-hub-v2.0.lua"))()`

Pages HOME, RECOVERY, MOVEMENT, PLAYER FINDER, AMBER, PROGRESSION,
WORLD, ATLAS, SETTINGS. Original dark-glass teal/violet/coral design,
header drag, Right Shift show/hide and floating reopen chip, responsive
scale and hover styling. Restore All and X cleanup. Favourite atlas entries,
search/categories/page navigation, optional local JSON preferences.
Compass to 18 known POIs in a compact 3-column selector; no teleport.

Player Finder: **disabled by default**, shows nearest 24 players whose
character, Humanoid and root are already replicated to current client;
BillboardGui dark nameplate shows display name/species/distance/HP bar.
Outline Highlights are placed in a client-local Workspace folder to avoid
inconsistent PlayerGui rendering. Teal/amber/coral distance colour, subtle
or bold; 150/300/600/900-stud range, optional through-wall (OFF by default,
visible-only via HighlightDepthMode.Occluded). Explicit individual tag and
outline switches, live nearby names in hub; destroying overlays on OFF,
character changes, out of range and X. No other-player server queries or
outbound copies.

Other actual opt-in controls: native Recovery Assist (as earlier), local
brightness, calm camera, native performance setting, client injury slow
cache patch, capped 1.10x speed and leap cache experiments, warnings,
native rewards/guide UI open. All gameplay-affecting switches default OFF;
older **3x stamina pool tweak is parked and NOT loaded** because of previous
unexplained Burst deaths. Atlas documents 74 relevant code-backed systems:
exhaustion, regeneration, Amber x1-x3, Thriving+50%, regrowth x2,
Elder, grazing/home turf, 10+% damage bonus config, anti-teaming,
passives, disabled quest/ability/litter flags, etc. These are informational
not automatic rewards or server grants.

Official Luau workflow validates all 4 modules and feature scope.
**No live in-game Aurora test has occurred**; compile/static test alone
does not establish executor compatibility, visual rendering or accepted
Rest/movement effects. Source is client-side only; server death causes and
benefit eligibility are not known. Avoid stating hub guarantees survival.

The old Recovery Hub v1.3 remains unchanged in its own file for historical
reference. On new Aurora load, its old screen is closed using HubShutdown so
concurrent scripts do not unknowingly conflict. Running old hubs afterward
can coexist, so don't encourage simultaneous untested modifications.

Next user step: run single Velocity launcher, use new PLAYER FINDER page to
enable visual outlines/nametags and other desired features. If they report
a concrete UI issue, fix source directly on GitHub without asking for another
full diagnostic.

## Latest Rest-Only v1.0 live report — 17 November 2026

User ran the conservative Rest-Only Lab v1.0 again: 116.47s, 227 own
samples, Rest switch ON at report time, 21 local Rest=true FireServer
calls with zero local sending failures; 9 WolfRest=true echoes
and 9 local pose-only masks. Last HP 245/245, stamina 56.10/56.10,
hunger 55.45, thirst 82.06 and HudRest=false.

Valid partial-stamina pairs: off_still +2.89/s (14), on_still +1.57/s
(54), on_moving -1.21/s (93). off_moving had only 1 interval and
ZERO valid stamina pairs. All health recovery groups had zero eligible
pairs because no measured below-max HP windows; no HP outcome inferred.
v1.0 combines different moving gaits and periods, so this is not
an apples-to-apples controlled comparison. Still rest ON visibly
lost stamina while moving on average; a packet echo is not a
server-maintained Rest/regen grant.

Interpretation: repeated native Rest requests did not demonstrate
permanent full Rest stamina benefits during movement. There is still
no evidence the client script can protect from unexplained deaths.
Do NOT assert successful continuous full Rest benefit, safe Burst or
server acceptance. Next steps should focus on analyzing existing
client Rest controller separation versus server-known Rest effects,
not another redundant huge diagnostic. Server-only Rest, health
and enforcement handlers were never recovered.

## New live findings — v1.2 and feasibility (17 Nov 2026)

Live report: 98.35s, 16 successful local Rest=true sends and 15 local
WolfRest echoes/masks. Latest 12.02s HudRest test completed; 23/23 probe
samples locally true, 2 writes, 1 reset. There were 3 HudRest tests this
session; latest on_hud gait groups reset per probe; OFF/ON gait groups
accumulate over the whole session. HP 164/164, so no health-rate evidence.

Stamina net/s by gait:
- off_Sprint -0.87 (2 valid pairs; speed 16.28), on_Sprint -0.65
  (19 pairs; speed 16.04)
- off_Burst -3.27 (12 pairs; speed 26.80), on_Burst -3.32
  (18 pairs; speed 26.49); no meaningful Burst benefit visible
- on_Moving +0.58 (7 pairs; speed 5.89); on_hud_Moving +0.27
  (13 pairs; speed 7.22), not same speed, so no proof of HUD uplift
- off_Moving has 0 valid stamina pairs (no meaningful moving control)
- on_Still +2.83 (12 pairs). Last hunger 18.88, below recovered
  LOW_NEED_AT 20, where client config may halve recovery.

User requested always-on Rest benefits without character deaths. Explicit
limit: recovered client code is not full server code. Client export lacks
server-only Rest eligibility, health/status effect writers, stamina authority,
kill triggers and enforcement handlers. Keeping HudRest true is only a local
flag; it did not produce an additional demonstrated improvement. Sending
Rest=true at intervals is an input request, not proof server accepts rest
while Sprint/Burst. Prior abrupt 107/107-to-zero death while Burst gave a
generic other cause, not anti-cheat proof. Cannot guarantee all Rest effects
always or no deaths using the client-only scripts.

Conservative available approach: use native Rest request only, e.g. existing
Rest-Only Lab v1.0 with no stamina pool writes or HudRest forcing, or Recovery
Hub v1.3 Recovery Assist alone, avoid prolonged Burst. Neither is proven
to keep every Rest bonus or prevent all deaths. Avoid new untested bypass
labelled safe, and do not claim server-only code was retrieved.

## Most recent live HUD result and corrected follow-up (17 November 2026)

User supplied **Rest-State Lab v1.1** live output, 66.29 sec:
- Rest request ON, eight sends / zero local send failures; WolfRest local true
  observed once and local pose masked once.
- Latest 12-second HudRest probe: one client write, no observed resets,
  23/23 HUD probe samples had HudRest=true; script did not report movement
  blocked; user had Sprint and Burst samples as well as ordinary movement.
- Reported client stamina net/s: off_moving -3.00 (15 pairs);
  on_moving -0.03 (20 pairs); on_hud_moving +0.19 (39 pairs).
  HP at max; no eligible health recovery measurement.
- **Important measurement bug/confound:** v1.1 resets the current HudRest
  probe sample counters on each probe start but *not* cumulative on_hud rate
  groups. 44 on_hud moving intervals versus only 23 samples in the latest
  12s probe strongly suggests >1 probe aggregate. Also the "moving" bucket
  merged ordinary walking, Sprint and Burst, which have different costs.
  DO NOT call +0.19 proof of Rest regeneration or server acceptance.
- Client HudRest remaining true alone is insufficient: the controller's private
  rest state and server eligibility are not directly read from that flag.

New correction **Rest-State Lab v1.2**:
- Source [feral-rest-state-lab-v1.2.lua](feral-rest-state-lab-v1.2.lua)
- Guide [README-rest-state-lab-v1.2.md](README-rest-state-lab-v1.2.md)
- Loader `loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-rest-state-lab-v1.2.lua"))()`
- Luau 0.747 compile-only + static checks PASS:
  https://github.com/GSVexed/vexed-schematics/actions/runs/44107710995
- No changes to stamina or HP. Existing native Rest request, pose mask and
  optional 12-second local HudRest test remain. Report now isolates Still,
  ordinary Moving, Sprint and Burst for each phase, captures mean horizontal
  movement speed, resets HUD rate counts **per HUD trial** and reports trial
  count and actual duration.
- Next user task: fresh load v1.2, partial stamina, **walking only** for
  ~10-15 sec Rest OFF, ~10-15 sec Rest ON, then 12-second HUD probe while
  continuing the same walk. COPY REPORT. Compare off_Moving, on_Moving and
  on_hud_Moving only if average speeds/stamina ranges comparable. Don't
  deliberately run Burst; earlier deaths remain unresolved.
- No live v1.2 Roblox test yet. v1.3 Recovery Hub remains intact.

## Follow-up — HudRest cancellation test (17 November 2026)

User tested Rest-Only Lab v1.0 (70.61 sec, 137 samples): eight successful
client sends of Rest=true and eight local WolfRest echoes; no server proof.
Their report had:
- off_moving: net -1.45 visible stamina/s (28 eligible pairs)
- on_moving: net -1.13 visible stamina/s (27 eligible pairs)
- on_still: +2.76 visible stamina/s (25 eligible pairs)
- No health-rate pairs because HP at full or otherwise ineligible.
- Some near-final still samples HudRest=true, later moving samples HudRest=false.
User clarified normal Rest locks movement; attempting to move cancels normal
rest state even with the pose animation masked. They hypothesize HudRest=true
might drive stamina rest benefits.

New **Rest-State Lab v1.1** is published, separate from intact v1.0 and
Recovery Hub v1.3:
- [Source](feral-rest-state-lab-v1.1.lua)
- [Guide](README-rest-state-lab-v1.1.md)
- Loader: `loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-rest-state-lab-v1.1.lua"))()`
- Official Luau 0.747 compile-only and static tests PASS:
  https://github.com/GSVexed/vexed-schematics/actions/runs/44106352715
- Keeps Rest ON native request/pose mask and adds explicit TEST HUDREST
  mode (OFF by default), which briefly asserts the CLIENT-LOCAL player's
  HudRest attribute true every 0.2s at most. It auto-stops within 12 sec,
  if movement appears blocked or the game cancels the attribute 36 times.
  Restores the original HudRest if still holding its own true. Reports
  on_moving vs on_hud_moving, actual flag samples and reset counts.
  **Unverified in live FERAL/Velocity; this is a hypothesis experiment,
  NOT a proven server bypass or durable Rest fix.**
- Next step: Test with partial stamina: Rest ON walking baseline ~10 sec,
  then walk so HudRest is false, click TEST HUDREST while attempting to
  keep walking ~12 sec. COPY REPORT and paste outcome. Avoid Burst, normal
  rest key, other overlays/config switches; only own-character data.
  If the flag is canceled, movement blocks, or no net uplift appears,
  reject HudRest-as-causal-switch; do not blindly force it indefinitely.

## New continuation checkpoint — 17 November 2026, normal Chat

After Work usage ran out, the user requested continuing this FERAL project
in normal Chat. Their newer decision supersedes the earlier pause on gameplay
changes: focus on whether the **normal server Rest request** has measurable
benefits while walking, even at **full health**, without the previous 3x
client-side stamina pool modification. Do not claim server acceptance yet.

Published **Rest-Only Lab v1.0**:
- Source: [feral-rest-only-lab-v1.0.lua](feral-rest-only-lab-v1.0.lua)
- Guide: [README-rest-only-lab-v1.0.md](README-rest-only-lab-v1.0.md)
- Loader: `loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-rest-only-lab-v1.0.lua"))()`
- Official Luau 0.747 compile-only and static scope checks passed:
  https://github.com/GSVexed/vexed-schematics/actions/runs/44103217850
- v1.3 Recovery Hub source and its 3x client regeneration remain unchanged.
- New lab: OFF on load, no health/stamina/config writes; it sends native
  `WolfActions("Rest", true)` no faster than once per five seconds while ON,
  including at full HP, and masks only local `WolfRest` pose. OFF tries a
  same-character `Rest=false` cleanup. Observations are bounded and own-only.
- Not yet run in live Roblox/Velocity; game-server acceptance still unknown.

**Next action:** user pastes the new loader into Velocity in FERAL, gets a
~10–15-second moving baseline with partial stamina while OFF, enables
CONTINUOUS REST for ~15–20 seconds at the same walking pace, then clicks COPY
REPORT and pastes output in Chat. Avoid prolonged Burst because prior unexplained
deaths remain unresolved. Compare OFF/ON moving stamina trends, visible Rest
echoes and health intervals only if HP was below maximum; do not infer
server-only stamina budgets or combat healing from a client sample.
No additional bulk diagnostic, server-source retrieval or PC-runner reboot
is needed for this immediate comparison.

Updated 17 November 2026. Read this and [README-FERAL.md](README-FERAL.md)
before continuing in a new Chat, Work or local desktop task.

## Current task and preferences

The user wants to connect their Windows 11 PC for local project work and may
switch to normal Chat because Work usage is running low. They prefer short
replies, ready-to-run hosted loaders and actual implementation. Preserve this
handoff as decisions change. Ordinary Chat may not have the same computer,
filesystem or GitHub tools; verify available access before claiming actions.

The immediate local task is to verify the computer connection, open the project
and locate the user-approved Velocity workspace and relevant Roblox logs.
Start with read-only checks. The user asked to discuss the unexplained deaths
before the next gameplay-script change or experiment. No fresh bulk diagnostic
is needed. Do not automatically execute game scripts or start Burst testing as
part of connecting the PC. Exclude credentials, browser profiles, private
messages and other players' data.

## Project and current build

- Repository: `GSVexed/vexed-schematics`, branch `main`, directory `roblox-tools/`.
- Roblox FERAL PlaceId: `108901361810209`; executor: Velocity.
- Current functional build: [feral-recovery-hub-v1.3.lua](feral-recovery-hub-v1.3.lua).
- Guide: [README-recovery-hub-v1.3.md](README-recovery-hub-v1.3.md).
- Verification: [FERAL-RECOVERY-HUB-v1.3-CHECKS.json](FERAL-RECOVERY-HUB-v1.3-CHECKS.json).
- Gameplay source last published in commit `155ebb8d23e15e24595a77e2ccdf0f37bb2e3e28`.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-recovery-hub-v1.3.lua"))()
```

One **3X STAMINA REGEN** switch applies 3x the original client recovery rate
and adds recovery to a matched internal client stamina pool during flat or
draining intervals, including climbing. Native positive recovery is not added
twice. Normal costs and low-needs penalties remain. Four changing native HUD
samples and a strict own-callback/config fingerprint are required before pool
writes. Both gameplay switches default OFF and remain armed across respawns.

**RECOVERY ASSIST** uses the normal Rest request and masks the own local rest
pose. Earlier captures support about 2x HP recovery outside combat and faster
bleeding/venom clearance. Combat HP regeneration remains unresolved. The old
direct HP writer failed and is retired. No combat-off bypass is established.

v1.3 fixes an attribute-callback timing flaw reproduced with actual v1.2 code
in a substitute engine. Matching now happens before the hub's own write.
Temporary mismatches pause writes in VERIFYING; persistent mismatch stops and
restores owned settings. **COPY STATUS** retains a bounded short summary and
the last failure, with clipboard/text-box fallbacks. Official Luau compilation
and 63 simulated checks passed; these are not developer-run Roblox tests.

## Latest live evidence and unresolved problem

The user's v1.3 status showed **0 mismatches, 0 failure stops and 8,129 accepted
client pool writes**. The last sampled Bear frame was in Burst with HP 99/99
and stamina pool 50.181 of 50.300; the final addition reached approximately
the configured 50.250 cap. The user still died. BINDING with no animal afterward
was standby after character removal, not a recorded match failure.

This supports sustained client recovery and the absence of guard failures in
that capture. It does not establish indefinite server-accepted Burst. The
report lacks the death transition, final needs values and a native death reason.
Earlier native death feedback said only `other`, with no reason/code. An earlier
60-second reported lifetime differed from about 48.8 seconds of observed Burst;
do not invent a 60-second Burst limit or a safe reset interval.

A separate server resource/movement check is a hypothesis. Damage, world rules
and other causes have not been fully excluded. The user has not yet answered
whether the latest death occurred on dry land without attackers, or supplied
the continuous Burst duration. Discuss before changing the working regen.

## Existing data and access boundaries

The client/platform diagnostic phase is complete within its recorded scope.
Public analysis covers 339 logical game exports / 221 distinct reconstructed
bodies. Reconstruction defects remain. Private original captures are in the
earlier conversation/user files; they are not all stored in this repository.
Do not publish raw captures or private game source bodies.

Server-only scripts were not retrieved. Public Roblox metadata checked on
17 November 2026 returned `copyingAllowed: false` for FERAL. The group's public
game list exposed no separate public FERAL test copy. Searches found no official
server-source release. Existing `ServerStorage` references in shared
AbilityConfig/ElderPaint do not expose private server contents. PC access does
not grant game-owner or server access.

Amber, restricted-animal spawning, owner tools, code menus and extra effects
remain parked. No spendable-currency grant, restricted spawn, owner permission
or permanent unlock has been established.
