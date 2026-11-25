# Renaissance 15.6.2 — normal camera zoom unlock

Adds one saved **Movement → Zoom Unlock** control, enabled by default while respecting saved OFF. Expands Player camera limits to 0.5–100,000 studs and Classic mode. Native default changes are observed; OFF/unload restores the latest values still owned by this feature. Does not replace CameraType, CFrame, subject, FOV or the camera controller. Cinematics/custom camera code may still impose their own behavior; the limit range is not a live-tested universal camera guarantee.

193 retained-core and 223 Territory regressions pass, including camera staging, restore, native default changes, reload ownership, scripted pose preservation and failed observer cleanup. Official compilation, parity and rollback checks pass. Territory code remains 0.6.1; the dedicated Territory efficiency preparation is a separate deliverable.

Official property reference: https://create.roblox.com/docs/reference/engine/classes/Player#CameraMaxZoomDistance and https://create.roblox.com/docs/reference/engine/classes/Player#CameraMinZoomDistance.

# Renaissance 15.6.1 — close-prey attacks and Burst state

Preserve false native gait attributes, approach prey to correct close-range facing, and use supported executor mouse input when virtual mouse dispatch is rejected. Keep attack-blocker, native marker and manual-care evidence distinct from accepted damage. Validate colliding occlusion and paired input cleanup. All retained features and prior bundles remain.

Official Luau: 223/223 Territory and 187/187 retained core cases, compilation, source parity and rollback checks. No direct live gameplay trial. See [patch report](../../feral-amber/docs/V0_6_1_RELEASE.md).

---

# Renaissance 15.6.0 — Territory autonomy overhaul

Committed prey pursuit, original native attack dispatch without an advisory cooldown veto, slow-progress recognition, checked straight shortcuts, precise detours, terrain/drop checks, guarded Burst without stamina telemetry, stable resource searches, nested returns and coordinated survival care. All 21 core records remain.

Validation: 215/215 Territory and 187/187 retained core cases with official Luau, source parity and protected previous bundles. New gameplay remains live-unverified; autonomous aerial/underwater routing and universal unattended survival are not claimed. See [complete report](../../feral-amber/docs/V0_6_RELEASE.md).

---

# Renaissance 15.5.1 — farming flow corrections

Preserve active claim positions across replication gaps, bound incremental water searches, repair low-throttle digital pursuit, release owned automatic recovery at its farming handoff, revalidate suspended objectives and return after urgent scent maintenance. A failing Territory cleanup remains inside its fault boundary. Manual Rest, full drinking, the built-in page and all original features remain.

Validation: 188/188 Territory and 187/187 retained hub cases, official Luau compilation, deterministic parity and protected 15.5.0/0.5.0 rollback bundles. Live gameplay remains unverified. See the [patch report](../../feral-amber/docs/V0_5_1_RELEASE.md).

---

# Renaissance 15.5.0 — integrated Territory farming

Amber 0.5.0 now runs inside the native Territory tab, with one main window and scheduler. Existing 21 feature records and earlier versioned bundles are retained. This release adds region completion sweeps, non-pack occupied-hex deferral, stable claim verification, near-finish protection, interrupted/full drinking, body-sized tree recovery, immediate eligible Burst upgrades and trailing NPC hunts.

Validation: 187/187 retained Renaissance and 170/170 Amber scenarios pass locally with official Luau. All 23 embedded modules have source parity; 28 Renaissance and 21 Amber compilation targets pass. No current live gameplay or yield measurement was performed. See the [complete report](../../feral-amber/docs/V0_5_RELEASE.md), release.json and published PR checks.

---

# Renaissance 15.4.3 — highest native Hippo Crusher Bite cap

Pinned candidate: [immutable source](https://github.com/GSVexed/vexed-schematics/blob/60b8218912f8ff4b9bebec4e0a91bdc104f78b46/roblox-tools/feral-renaissance-v15.4.3.lua).
[Official Luau validation](https://github.com/GSVexed/vexed-schematics/actions/runs/45679132920) passed **187/187 regressions**, all **18 compilation checks**, deterministic packaging and preserved rollback hashes.

- Hippo `CrusherBite.SPEED_CAP` is set to `"burst"` when an exactly compatible native client profile originally requests `"trot"`. This replaces 15.4.2's `"sprint"` client cap.
- `BURST` and `WolfBurst` are distinct native locomotion signals in the captured v2412 client. No synthetic movement input or burst attribute is issued. Other animals' profiles and normal ability timing remain unchanged.
- This client ceiling does not establish burst access or server-accepted running speed during Crusher Bite. Unknown or conflicting schemas remain untouched; native server constraints may still force trot.
- The 15.4.1 alias-safe stamina application correction and 15.4.2 rollback protection, minigame scheduler and 21-feature hub remain.
- The controller and UI both report the real `15.4.3` version.

Run after release:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()
```

Rollback to 15.4.2:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/cbd9e84740538895f0f4c766b39604e10c014214/roblox-tools/feral-renaissance-v15.4.2.lua"))()
```

---

# Renaissance 15.4.2 — Hippo Crusher Bite and stamina-plan repair

Source: [immutable 15.4.2 bundle](https://github.com/GSVexed/vexed-schematics/blob/cbd9e84740538895f0f4c766b39604e10c014214/roblox-tools/feral-renaissance-v15.4.2.lua).
The official [Luau compile and regression gate](https://github.com/GSVexed/vexed-schematics/actions/runs/45677068683) passes **185/185 scenarios**, all **18 compile checks**, module parity, reproducible packaging and unchanged historic rollback hashes.

- **Hippo Crusher Bite movement:** the v2412 captured `AbilityConfigBase` contains a native `CrusherBite.SPEED_CAP = "trot"` restriction. When your own animal is Hippo and the game exposes an exact supported client-side Crusher Bite profile, Renaissance uses a separate, reversible owner to set that field to `"sprint"`. The patch does not affect other animals, force Humanoid speed every frame, send additional ability requests, or change charge, damage and cooldown values. It restores the original field upon animal change, external conflict, or shutdown. A changed/incompatible schema is left untouched.
- **Stamina-plan fix:** preserve 15.4.1's correction of aliased fields that caused the reproduced `duplicate field` error in the actual v2412 Hippo session. The fix restores normal lease application in the simulated native contract; sustained live no-drain behavior remains separately unverified.
- **No-regression packaging:** the build now refuses to write a candidate bundle or manifest when a known-good rollback source is missing or altered. Tampering and missing-file cases are exercised in CI.
- **Retained:** all 21 existing features, first-safe-Perfect-window automatic minigame scheduling, native Rest provenance and pose cleanup, compact four-tab UI, Right Shift, hollow player-only health-coloured outlines, saved settings and permanent Bite Reach.

**Evidence boundary:** code compilation and simulated client contracts are verified, but server-accepted Hippo travel speed, stamina across gaits, 2×/4× condition recovery, Vulture flight handoff and live minigame outcomes have not been observed for this new bundle. No private server handler was obtained.

Launch the released version from the standard loader:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()
```

Direct rollback to full 15.4.0:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/ef1544f25d37f071df90dd1da84b9fd5df60bdaf/roblox-tools/feral-renaissance-v15.4.0.lua"))()
```

CLEAN v14 and earlier complete Renaissance bundle hashes remain unchanged.

---

# Renaissance 15.4.0 — rapid minigames and coordinated upgrades

Immutable source: [ef1544f](https://github.com/GSVexed/vexed-schematics/blob/ef1544f25d37f071df90dd1da84b9fd5df60bdaf/roblox-tools/feral-renaissance-v15.4.0.lua). [Published source CI 45643744396](https://github.com/GSVexed/vexed-schematics/actions/runs/45643744396) passes all 176 regressions, 18 compile checks, deterministic packaging and rollback checks. The exact source also passed Potassium staging in FERAL v2412, preserving the active hub and issuing zero gameplay requests or attribute writes.

- Minigames target the first safe Perfect interval, with immediate event checks, frame callbacks and one bounded deadline timer. A reproduced late-packet case avoids a 1.020-second extra wait; the ordinary captured zone is scheduled 30.272 ms before its centre. These are deterministic timing measurements, not live win-rate measurements.
- Temporary native-state read failures retain a genuine pending strike. Native end/bite cleanup still wins. Real own replies alone update grades; bite clicks remain separate. No future/backdated timestamps, artificial strikes or extra press spam are used.
- Native action changes preempt owned Rest immediately. Recovery displays recent observed rates; the stamina plan covers native swim, climb and venom drain inputs with exact restoration and per-locomotion observations.
- The selected bite guide follows current body geometry between scans. Small target-distance fluctuations do not flip rear assistance, and a newly selected body's marker starts at that body. Real game-reported damage and HP correlation stay distinct.
- Guarded post-attack flight recovery covers native-eligible airborne talon/dive episodes. Active locks, capture, water, anchored bodies and deliberate stationary flight remain excluded; physics is not overwritten.
- Feeding checks the current native food/water offer before a stalled-session restart. Cub rescue yields to abilities and validates the current animal. Idle walks recheck their route; player overlays hide immediately when real-player ownership ends. Idle background scans adapt to slower frames.

The [full upgrade decisions](V15_4_UPGRADES.md) explain the useful improvements, retained implementations and unproven exploit targets. All 21 records, compact tabs, Right Shift, saved settings, player-only hollow health-coloured ESP and permanent Bite Reach remain. No deliberately removed feature returns.

## Confirmed checks and live boundaries

Potassium staging run 45644187432 confirmed all 13 modules, the timing model, native minigame and feeding handler access, a compatible 17-field stamina plan, renderer construction and cleanup. The existing active hub was 15.3.0 and was retained. The private bite handler remained inaccessible; ordinary native bites remain available, while the scripted post-Rest retry may be unavailable. Sanitized exact-source evidence is in live-v154-stage.json.

Actual Perfect frequency/wins, simultaneous accepted bite damage, extra accepted reach, sustained stamina across species, real 2x HP/4x condition recovery, visible/remote moving Rest pose, original Vulture-freeze resolution and water-cub success remain unverified. Native strike cadence, pauses and game eligibility still apply. Staging did not install the replacement into the active session.

## Apply

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()

Run the complete loader once to apply 15.4.0 using the saved settings. Avoid stacking separate legacy modules.

## Rollback

Complete 15.3.0:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/1905fbe0eda6e3dd48b2ef32a16de8d02b5f6a3b/roblox-tools/feral-renaissance-v15.3.0.lua"))()

Original CLEAN v14:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/158474ba80c0d613c3427399f24059341369acc8/roblox-tools/feral-nova-v14.0-clean-reach-core.lua"))()

All complete prior bundles remain byte-for-byte unchanged. Re-running a complete Renaissance loader retires its prior owner, including pending minigame deadlines, before activating the replacement.

---

# Renaissance 15.3.0 — timing and moving Rest corrections

Immutable source: [1905fbe](https://github.com/GSVexed/vexed-schematics/blob/1905fbe0eda6e3dd48b2ef32a16de8d02b5f6a3b/roblox-tools/feral-renaissance-v15.3.0.lua). Published source [CI 45632821703](https://github.com/GSVexed/vexed-schematics/actions/runs/45632821703) passes all 137 scenarios, 18 compile checks, deterministic packaging and rollback gates.

- Correct native Rest controls to R/gamepad Y. Z/X no longer surrender automatic pose ownership; exact control labels avoid the Forest substring error.
- Keep the owned pose reset through the next native animation frame, including long hitches. Actual walking can end stationary manual Rest once before ordinary recovery resumes; mere sliding does not.
- Use independent recent six-second HP/injury/bleed/venom measurements so an earlier gain cannot remain labelled as current progress forever.
- Combine range guidance with native-visible cooldown and action restrictions. If private callbacks are isolated, use the game's own cooldown calculation and bite marker, with private state explicitly unverified. Preserve available validated handles across reload.
- Remove whole-heap discovery. Bound callback inspection, skip unchanged ESP writes and protect pending minigame strikes from target/config/terrain work. Normal bites and actual server grade rules remain.
- Recognise native talon/dive session IDs. Add one bounded retry of a real Vulture let-go intent and a guarded native flight restart after an observed session ends and movement stalls. Native anchoring, capture, positions, velocities and movers are not overwritten.

The deterministic 24-player/120-frame comparison reduces repeated highlight writes from 11,520 to zero, stationary label-position writes from 2,880 to zero, idle upvalue reads from 240 to 96, pending-strike target scans from 15 to zero and binding queries from 120 to 20. These are operation counts, not measured game FPS.

## Live boundaries

The exact final execution request (private run 45633163610) was acknowledged without its validated result. A read-only late pickup (45633541410) found a marker without a matching source result. No additional game script was executed by that pickup. Final-source in-game compatibility, the rendered moving pose, Vulture-freeze resolution and sustained 2× HP/4× condition rates remain unconfirmed. The earlier candidate exposed the native-input VM-isolation limit; it was not promoted. Details and exact evidence are in LIVE_EVIDENCE.md and V15_3_IMPROVEMENTS.md.

All 21 feature records, compact tabs, Right Shift, schema-15 settings, hollow health-coloured player-only ESP and permanent Bite Reach remain. CLEAN v14 and complete 15.0.0/15.1.0/15.2.0/15.2.1 bundles remain unchanged. No removed feature or extra visible diagnostics control returns.

## Apply

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()

Re-run the complete loader to apply this release. Hidden validation did not replace the running hub.

## Rollback

Complete 15.2.1:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/bdfd2fc913fcf70f2a71dee5a94d5cfbfdda8b17/roblox-tools/feral-renaissance-v15.2.1.lua"))()

Original CLEAN v14:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/158474ba80c0d613c3427399f24059341369acc8/roblox-tools/feral-nova-v14.0-clean-reach-core.lua"))()

A complete loader retires the existing Renaissance owner. Avoid stacking separate legacy modules. Earlier release records follow.

---

# Renaissance 15.2.1 — recovery correction

Pinned source: [bdfd2fc](https://github.com/GSVexed/vexed-schematics/blob/bdfd2fc913fcf70f2a71dee5a94d5cfbfdda8b17/roblox-tools/feral-renaissance-v15.2.1.lua). The complete 15.2.0 bundle and CLEAN v14 remain unchanged.

- Camera right-mouse input no longer counts as an attack or blocks recovery. Native left-mouse/gamepad R2 attacks still release Rest first.
- Successfully masked echoes no longer cause a 15-second recovery pause. Delayed automatic responses keep their provenance rather than becoming manual Rest after a timeout; hot reload preserves this distinction.
- The native persistent Rest blend receives an owner-scoped reset, with exact restoration for manual Rest, character changes, downed state, external replacements and shutdown.
- Rest controls hand over ownership before native input. Deferred native Rest taps do not immediately restart automatic recovery.
- Native HP Rest=2 and injury/bleed/venom Rest=4 are retained with ordinary base rates. The former cosmetic base-rate compensation is removed.
- The recovery row distinguishes an actual HP increase from a request or a window without observed progress. Each condition is observed independently; missing values and growth do not become recovery evidence.

Validation: 113/113 regressions and 17 compile checks pass locally. Candidate live staging in private runner run 45505790776 confirmed all 13 modules, current native animator presence, pose-attribute write/readback/exact restoration, cleanup and preservation of the existing hub. It issued zero native gameplay requests. The published source gate is [run 45505688605](https://github.com/GSVexed/vexed-schematics/actions/runs/45505688605). Details: V15_2_1_RECOVERY.md and LIVE_EVIDENCE.md.

Sustained real 2× HP recovery, 4× condition clearing and the final visible pose while moving remain live-unverified. The successful attribute test is local evidence. A passive sample of the preceding hub had full HP throughout and cannot establish a healing rate. HP recovery continues to yield to combat and native actions. All 21 feature records, saved settings, hollow player-only ESP, Right Shift and permanent Bite Reach remain.

Use:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()

Rollback to complete 15.2.0:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/21da4732f05897c7225fde2ffd6ea81d02be6b1b/roblox-tools/feral-renaissance-v15.2.0.lua"))()

Original CLEAN v14 rollback remains below. Re-running a complete loader retires the active Renaissance owner; avoid stacking separate legacy modules.

---

# Renaissance 15.2.0 — release record

Released source: [21da4732f05897c7225fde2ffd6ea81d02be6b1b](https://github.com/GSVexed/vexed-schematics/blob/21da4732f05897c7225fde2ffd6ea81d02be6b1b/roblox-tools/feral-renaissance-v15.2.0.lua). The launcher pins that immutable source. Compilation, all 99 service-boundary regressions, deterministic packaging and rollback checks pass locally and in [published source CI](https://github.com/GSVexed/vexed-schematics/actions/runs/45494741846). The finalized loader was also locally checked before promotion.

## Changes

- ESP and hub name tags remain restricted to real players, checked against actual player-character ownership. Pack NPCs receive no hub overlays.
- Hollow outline colour follows current health from green through yellow to red. Floating health percentages and distances are removed. Plain names retain pack colour.
- Recovery yields during the native approach to food/water, not only after the feeding animation starts.
- A user-started stationary feeding session with no observed resource increase can receive one native stop/start repair. Actual hunger/thirst increases are tracked; values are never overwritten.
- Clicking near a feeding offer remains an attack input. Attacks can cancel the original native feeding state before the ordinary bite callback.
- A bite blocked by the recent Rest exit can retry once through the original native tryBite after the native lock. Capture/cooldown/other native guards remain.
- Known friendly/protected targets are excluded from the modified client bite geometry; current positions and the native target score replace stale/different guide calculations.
- Premature predicted hit impacts are disabled while genuine game hit replies remain. HP baselines start at the native marker so a quick decline is not missed.
- G can select an eligible friendly cub in water, request one ordinary jump if needed, wait for actual water-exit eligibility, and submit one native pickup. A native carry attachment is observed separately. Ordinary carry/drop remains native.

The 21 retained feature records, four tabs, Right Shift, saved settings and permanent reach remain. CLEAN v14 and complete 15.0.0/15.1.0 source bundles are unchanged. No removed full-resource, automatic food-seeking or oversized-carry feature is restored.

## Validation

| Gate | Result |
|---|---|
| Local compile | 13 modules, 2 fixtures, versioned bundle and launcher pass |
| Local regressions | 99/99 pass |
| Embedded source parity / rollback hashes | Pass |
| Published source CI | 99/99 pass; deterministic bundle passes |
| Actual executor staging | Earlier candidate passed; final native lookup remains unconfirmed |
| New gameplay efficacy | Unverified |

The fixtures follow the captured native client contract. They are not a private-server test. Earlier candidate dcb1714 passed actual Potassium hidden staging and colour checks while retaining the active hub. A later native-function investigation exposed mixed heap enumeration and led to the callback-first lookup fix. The final pinned source request and a print-only transport request received acknowledgements without exact console results. No further broad diagnostics or manual test request was made. Earlier-version results do not establish final-source native compatibility; LIVE_EVIDENCE.md preserves the exact boundaries.

## Use

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()

Use E/native controls to eat or drink. The hub protects that session and watches real progress. G keeps normal carry/drop; near an eligible friendly cub in water it can make a bounded rescue attempt. Right Shift controls the same compact window.

## Limits

Reduced live ghost-hit frequency, repaired hunger/thirst progress, water-cub pickup, extra accepted reach and real continuous 4x condition recovery remain unverified. The cub action preserves native eligibility and cannot certify universal pickup while swimming/submerged. Species water rules or other server checks can reject it; move or jump to the bank when shown. A request is not reported as an observed pickup without the matching native carry attachment.

Native-function access requires supported executor inspection. Without it, feeding intent still protects the approach, but native restart and post-Rest bite retry may be unavailable. Existing pin, clamp, cooldown, venom and post-Rest rules still apply. Right Shift may still overlap native raw sprint polling. Only locally replicated player characters can be rendered.

## Rollback

Previous Renaissance 15.1.0:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/552965031659c52e36bf8bda436d0d07d348abd6/roblox-tools/feral-renaissance-v15.1.0.lua"))()

Original CLEAN v14:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/158474ba80c0d613c3427399f24059341369acc8/roblox-tools/feral-nova-v14.0-clean-reach-core.lua"))()

These loaders retire the active Renaissance owner before activation. The older complete 15.0.0 bundle remains available at source 59e0a6d0db6d1a9e8c9f57f7a8368e858f8ec600. Avoid stacking independent legacy hubs manually.

## Records

release.json identifies the released source/hash and source CI run. test-results.json contains every scenario result. FEATURE_AUDIT.md, ARCHITECTURE.md, V15_2_INTERACTIONS.md and LIVE_EVIDENCE.md distinguish local behavior, native responses and gameplay outcomes.
