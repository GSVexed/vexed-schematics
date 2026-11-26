# Renaissance 15.8.0 candidate — shared combat and Hippo assistance

Date: 26 November 2026
Base commit: `7dcd03d78d7b3701e1cc9980f3ece6b510c21a2b`
Captured game baseline: v2412
Status: implementation candidate; live gameplay unverified.

## Scope

The user authorized implementation of the major-feature catalogue, with new animal-specific work limited to Hippo. This candidate accounts for all 25 applicable items. Fourteen other species-ability items and the Turtle-specific defense proposal are excluded.

The result is not a claim that every proposed exploit works. Several requested outcomes depend on private server behavior that is absent from the available evidence. Those limits remain explicit below.

No authenticated Roblox/Potassium execution tool is available in this environment. No live gameplay action was executed during this implementation. Test fixtures simulate client interfaces; they do not implement or prove FERAL's private server rules.

## Resulting behavior

- **Faster Bites:** a reversible wrapper reaches the native `Species.biteCooldown` calculation used by the captured WolfController. It requests 70% of the original client interval, with a delayed-contact floor, and never slows an already faster profile. It applies to the local animal's calculation on the supported baseline. Accepted attack rate remains unverified.
- **Held attack assistance:** holding an actual M1 or R2 input can schedule the original native `tryBite` at readiness boundaries. It stops on release, text/menu focus, capture, feeding, manual Rest and incompatible actions. The post-Rest input buffer is retained.
- **Auto Bite:** explicitly opt-in. It requires current target eligibility, current geometry and a fresh obstruction check. It yields to minigames and Territory ownership. It does not create Bite/BiteHit requests directly.
- **Moving-target assistance:** a four-stud maximum horizontal lead uses relative velocity and native hit delay. It changes the aiming calculation, not character positions. Same-tree affiliation no longer bypasses the assistant's obstruction check.
- **Hit feedback:** victim and timing replace newest-attack assignment. Close ties remain ambiguous. A zero-damage observation can be corrected by a unique later positive reply, while reported damage and HP attribution remain distinct.
- **Stamina:** the recognized native Burst DRAIN scalar joins the existing consumption plan. Replacement Burst tables invalidate and restore the old lease correctly.
- **Recovery:** small finite positive status values, including values below 0.1, still qualify for condition recovery. Nonfinite values do not create Rest demand. Native 2× HP / 4× condition factors and combat HP exclusion remain intact.
- **Hippo page:** separate movement and optional smart-release controls, plus captured charge/retention information in the hub. There is no new world-space text overlay.
- **Smart Crusher Release:** observes a manual charge and can invoke the validated original FeralHippoClient.finish after full charge and clear stock-reference contact. It supplies no timestamp or damage. It tries once per observed charge. Extended-only bite geometry does not automatically spend a charged ability.
- **Hippo release coordination:** the native Crusher bite marker preempts automatic Rest through the attack window. Disabling assistance or unloading never forces a manual charge to release.
- **Lifecycle:** original settings, permanent bite reach, outlines, movement features and built-in Territory remain present. Other species receive no new ability-specific changes.

## Controls and defaults

| Location | Control | Default |
|---|---|---|
| Combat | Faster Bites | ON for a missing saved preference; explicit OFF is preserved |
| Combat | Auto Bite | OFF |
| Hippo | Move During Charge | ON; exposes the previously implicit Hippo-only movement adapter |
| Hippo | Smart Crusher Release | OFF; manual long holds remain possible |
| Hippo | Charge information | Read-only in the hub |

There are 26 feature records and 27 embedded modules: fifteen core modules and twelve Territory modules. The stable launcher and stable release metadata still describe 15.7.0. Run the candidate's immutable bundle to test this version.

## Applicable catalogue items

“Implemented” describes the client code, not a verified private server effect.

| ID | Requested outcome | Candidate disposition |
|---|---|---|
| H01 | Uncapped overcharge damage | **Blocked / unproven.** The captured helper clamps charge; no authoritative cap bypass was established. No placebo multiplier patch is shipped. |
| H02 | Faster full-power charging | **Blocked / unproven.** A quicker local bar would not establish quicker accepted damage. Charge duration is preserved. |
| H03 | Store a charge longer | **Native behavior retained and observed.** The effective captured wrapper has 8 seconds of overhold; extending the server limit remains unproven. |
| H04 | Move faster while charging | **Extended.** The existing Hippo gait adapter gains an explicit independent control and exact OFF/restore behavior. Displacement remains live-unverified. |
| H05 | Shorter ability hit/miss cooldowns | **Blocked / unproven.** The authoritative readiness/cooldown handler was not captured. |
| H06 | Smart release | **Implemented.** Original native finish, full charge, clear stock-reference contact and one attempt per session. |
| H07 | Larger Crusher lunge/contact reach | **Partial.** Shared manual bite reach remains. An authoritative Crusher-specific lunge/range extension is unproven and not simulated. |
| H08 | More knockback/injury | **Blocked / unproven.** No authoritative impact or injury mutation was established. |
| H09 | Earlier grab breaking | **Blocked / unproven.** The field exists; the server consumer remains absent. |
| H10 | Cleaner release/cancellation | **Partial.** Native release supervision, attack-window recovery preemption and cleanup are implemented. Intentional native freeze is not bypassed. |
| C11 | Faster damaging bites | **Client mechanism implemented.** Native cooldown calculation and action attempts are connected; increased accepted DPS is unverified. |
| C12 | Efficient native attack cadence | **Implemented.** Readiness scheduling for held inputs and optional automatic attacks. |
| C13 | First attack after recovery | **Extended.** Bounded post-Rest retry remains, with readiness and held-input handling. No universal ghost-hit claim. |
| C14 | More accepted bite reach | **Existing client expansion retained.** Authoritative extra reach remains unverified. |
| C15 | Tree/rear/vertical contact | **Extended.** Existing geometry remains; an obstruction no longer becomes acceptable merely because a target shares a tree. |
| C16 | Moving-target prediction | **Implemented.** Bounded relative-velocity lead, with no movement/resource writes. |
| C17 | Conditional automatic attacks | **Implemented, opt-in.** Native action handle, current geometry, obstruction and eligibility are required. |
| C18 | Eliminate ghost hits / respawn workaround | **Partial.** Better correlation and attempt handling are implemented. A universal server/session repair is not established. |
| D33 | Continuous enhanced HP recovery | **Existing owner retained.** Actual always-on moving/combat recovery remains unproven; combat exclusion is preserved. |
| D34 | Continuous real 4× condition clearance | **Extended client eligibility.** Tiny residual effects no longer stop requesting recovery. Real sustained 4× rates remain unverified. |
| D36 | Reduce injury slowdown | **Existing reversible plan retained.** This is movement assistance, not damage reduction. |
| D37 | Sustainable stamina across modes | **Extended.** Explicit Burst consumption and nested replacement handling added; other mode plans retained. Universal server efficacy remains unproven. |
| D38 | Native escape/minigame response | **Existing deadline/cadence implementation retained.** No faster server-generated rounds or guaranteed wins are claimed. |
| M39 | Land/water pursuit and gait transitions | **Existing shared speed and Territory 0.7 retained.** Actual displacement/acceptance remains unverified. |
| M40 | Leap/climb/flight controls | **Existing assistance retained.** This does not complete the separate native climb/flight/depth routing backlog. |

Excluded at the user's instruction: S19–S32 and D35. Existing previously released behavior for those animals was not removed.

## Hippo source evidence

The read-only v2412 investigation identified:

- AbilityConfigBase script 15, main prototype 30, constant template 977: CHARGE_TIME=6, MULT_START=0.9, MULT_MAX=3.5, CURVE=2, SPEED_CAP=trot, and separate overhold/cooldown/impact fields.
- Prototype 17, multAt, words 0–26: normalized time is clamped to 0–1 before applying the curve.
- AbilityConfig script 101, main prototype 11, words 1066–1067: OVERHOLD is explicitly set to 8.
- FeralHippoClient script 4648, prototype 21, finish: the release path sends a release timestamp, without a requested multiplier/damage argument.
- The captured finish upvalues identify active state, own player, native clock, profile proxy and FeralHippo remote. The candidate validates the function's own script, name, player and remote before calling it.
- Discovery visits only bounded callback/upvalue chains from InputEnded, RenderStepped and the own-player touch-up signal. It does not enumerate the VM heap or execute captured bytecode.

The captured scale remains:

`0.9 + 2.6 * clamp(hold / 6, 0, 1)^2`

Six, ten and fourteen seconds all produce 3.5 in this helper. Retention time and increasing damage are different mechanisms. The helper is not a complete server damage formula.

## Validation

The pinned official Luau compiler/interpreter is commit `97b2f4bf9cd935bed666f3e643a3b749b4d22f38`.

- All 202 retained core regressions pass.
- The expanded core suite passes 243/243, including 41 added scenarios.
- 32 module, fixture, bundle and launcher files compile in the core gate.
- The integrated Territory suite targets this candidate using the current manifest, rather than the old hard-coded 15.7 bundle.
- Rollback hashes, module parity and forbidden-writer gates pass.
- No direct Bite/BiteHit request injection, local HP/status/resource writes, heap enumeration, or character position/velocity manipulation was added.
- Live accepted attack cadence, damage, range, movement, recovery rates and minigame results remain unverified.

Exact Territory results and source hashes are recorded in the candidate metadata and validation JSON.

## Runtime limits

- Faster Bites and smart release target the captured v2412 contracts. An unknown version or incompatible schema leaves those controls waiting.
- Native callback discovery can be unavailable across executor/VM boundaries. Automatic actions then remain unavailable; the hub does not substitute fabricated success or guessed remotes.
- The smart-release geometry is a conservative client eligibility estimate, not a server acceptance guarantee.
- A native damage reply is reported as such. Its correlation with a particular attack and with target health remains qualified.
- The private server implementation is still needed to establish overcharge, ability cooldown bypass, stronger impacts, universal damage reduction and sustained recovery claims.
- The separate Territory 0.7 backlog concerning native climb/flight/depth routes and live calibration is unchanged.
