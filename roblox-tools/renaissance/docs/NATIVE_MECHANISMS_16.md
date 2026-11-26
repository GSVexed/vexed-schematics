# Native mechanisms reviewed for Renaissance 16.0.0

This note records the source evidence behind the native-adapter and shared-configuration changes. It describes captured client behaviour and automated validation. It does **not** certify server acceptance, current live-game behaviour, damage, healing, minigame grades, or resource restoration.

## Evidence and reproducibility

The available capture is game build **2412**, Luau bytecode format 14. The checked-in [source trace manifest](source-traces.json) identifies the original verified capture, program digests and inspection toolchain. The review used `inspect_capture.py` as a structural reader and the opcode definitions from official Luau commit `97b2f4bf9cd935bed666f3e643a3b749b4d22f38`. Captured programs were parsed and inspected, never executed. Raw captures, account identifiers and player data are not included in this release.

Prototype numbers below are zero-based indices from that reader. Instruction offsets are word offsets within a prototype; they are research references, not runtime offsets to write.

| Captured program | SHA-256 | Reviewed mechanism |
| --- | --- | --- |
| WolfController | `7ed422d081bac217084eda4fd6c3699a17973434dad31a52ee2688ed23903ccb` | Bite target selection, Rest and native callback timing, carry/swim/sprint/venom consumption, movement state |
| CombatConfig | `b81ca362867ad87bdd9763a5898c4e31c0dcec652ea800e7f89541257497501f` | Body-gap eligibility, species cone bonuses, shell condition, predicted hit presentation |
| NeedsConfig | `cdb9998b28dc121ced2b8956089267d0b89ebfb4c10eaa5cb9b74eaf5c16df31` | Native recovery, stamina and movement calculation inputs |
| StatusConfig | `327fca03aee58d60341f4aee63320037a9b527290adfad47dc0bcaae12209147` | Injury, bleeding, venom decay and stamina/slow inputs |
| PassiveConfig | `3bae7c3263be8b7e8dc774b168592fddf20c0ee8f67a358a99d55f002efc194a` | Climbing levels and species climb sprint profiles |
| VenomConfig | `99ce8a3dd278401e531098a386c5a804ad41878bd4731c584c17097f6528bb61` | Separate sprint, other movement and bite consumption |
| FeralFlight | `5f8cc157580b14f66165b8c9591d07d76a082ebc79f2bcc7f15f412ef298173c` | Flight suspension, native post-ability release, drop and relaunch |
| FeralTalonLockClient | `3f7330c43ea3dc5717d80da287fe2351f5cb5d12bce0306896fe6825881c20f6` | Native let-go input and release callback |
| FeralDiveBombClient | `e66090b723feee0efed5d19962abfa0055577920d8cd5e27f891b62c2b1ee363` | Native dive cancellation and legal phase/speed restrictions |
| FeralDive | `f71b839538cd3a5e42e7843661db94dd7f70978d51be35512f6712a10f138073` | Aquatic dive entry/exit and the actual player eligibility attribute |
| FeralClimb | `097659768ed1a27fc934a547052e27ef10bf090aaaf7d4a02512e78ca92d5d6b` | Mount eligibility, native dive priority, stamina modes and climb input |
| FeralCombatClient | `173738ad9a0e19f0aa99716a21f5468f75d28d59cad47e869cc448855beaf7df` | Local prediction versus native hit-response presentation |

Additional Hippo scalar research is preserved in [HIPPO_CRUSHER_SPEED_RESEARCH.md](HIPPO_CRUSHER_SPEED_RESEARCH.md). That capture's `FeralHippoClient` digest is `65290350eb0d9cb373049d9b3a23fed4bd9a10ef26be8b276c9c381e241d2f12`; the reviewed `Species` digest is `850dfabd0bbf3d14089cb1391e3751b66c2746ddd12b9acd0e054baaf7824aa0`.

## Combat geometry and feedback

`WolfController` prototype 13, `biteClaimTarget`, calculates client target eligibility using the target body gap, the attacker's hip/body dimensions, the native cone and species modifiers. The shared adapter keeps the strict comparisons used by that calculation:

```text
reach = (bodyLength / 2 + ownHipHeight * REACH + SLACK)
        * HIT_SCALE * reachMult(ownCharacter)
verticalLimit = (ownHipHeight + targetHipHeight) * MAX_DY * dyMult(ownCharacter)
eligible = bodyGap < reach
           and verticalDistance < verticalLimit
           and horizontalDot > cos(radians(coneFor(ownCharacter)))
score = bodyGap - 2 * horizontalDot
```

`Roblox.geometry` now rejects malformed numeric inputs, missing bodies and bodies reparented away from their recorded character. Its returned `height`, `vertical` and `cone` fields let Territory use the same formula while retaining its deliberately conservative approach margins. Recovery's approach guard also uses the native species vertical allowance instead of silently dropping `dyMult`.

`CombatConfig` prototype 1, `coneFor`, adds the `AnimProfile` bonus when present, otherwise the `Species` bonus from `BITE_CONE_ADD`, to `CONE`. The old stock-reference wrapper clamped the result to the original base cone after the hub changed the shared config; that erased legitimate native species bonuses. The 2412 stock reference now preserves this formula. The expanded client cone is capped at 180 degrees so an additive species bonus cannot wrap the cosine calculation into a narrower cone. An unknown game version uses the conservative fallback and does not claim this captured formula was reverified.

Target guidance prefers a clear eligible candidate over a closer obstructed one. Assistance and guidance share visibility results within a scan, with at most 12 visibility queries for selection. Exhausted or failed queries remain blocked/unknown instead of becoming a clear-hit claim. The independent imminent-contact pass already has a ten-candidate ceiling. No target raycasts are added to rendering.

Same-tree assistance retains the existing native aim path; it does not confer server-authoritative vertical reach. Expanded client geometry remains an extended prediction. Native `tryBite` returning normally proves only that the callback was invoked; the interaction coordinator separately observes `WolfBiteAt`, later native feedback and target HP. The existing suppression of `HIT2.PREDICT` remains scoped to premature local presentation; native `FeralHit` response effects are retained.

## Native action ownership and minigame input

The adapter discovers only the bounded callback chains already connected to the local input/feed/grab signals. It does not enumerate the Lua heap. The shared discovery queue now includes both current script and current remote identities, resumes across slices, and is not reset merely because the other consumer's script is absent. That last condition mattered: repeatedly resetting a shared queue could prevent a valid grab callback beyond an unrelated prefix from ever being reached.

Cached bite/feed handles are retired when their script, `WolfActions` remote or game version changes. Native minigame handles check their current script and `FeralGrabV2` remote before exposing session state or restoring input bindings. Legacy hot-reload handles without this check are adapted without mutating the previous controller's callback table. A new service cannot inherit an obsolete callback merely because its old closure remains readable.

The private bite/feed upvalue layouts are interpreted only for build 2412 and only after their required identities and value types match. Named native callbacks may still be discoverable on another build, but private state is reported unavailable. The fallback timing calculation uses the native species cooldown config and the own-character bite marker and explicitly retains the limitation that private state is unknown.

The temporary manual minigame binding now returns `Sink` only for an actual accepted `Begin` dispatch. It returns `Pass` for stale/ended/rejected input and for `End`/`Cancel`, so an obsolete session cannot consume ordinary jump or attack input until the next heartbeat. Optional annotation of a successfully dispatched strike is isolated from native state read/write failures; a UI-annotation failure is not grounds to resend an already submitted press.

Held gamepad `ButtonR2` is polled through `UserInputService.GetConnectedGamepads` and `IsGamepadButtonDown`, in addition to the existing mouse hold check. This closes the gap where a long held gamepad attack could outlast its initial input event's recovery exclusion. The loop is bounded to eight pads, and optional device-query failures preserve mouse behaviour. Public API references: [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService), [ContextActionResult](https://create.roblox.com/docs/reference/engine/enums/ContextActionResult), and [ContextActionService](https://create.roblox.com/docs/reference/engine/classes/ContextActionService).

## Aquatic and aerial transitions

### Aquatic dive

`FeralDive` prototype 26 (`startDive`) sets the character's `FeralDiving` attribute to true at words 49–53. Prototype 25 (`endDive`) clears it at words 12–16. `WolfController` prototype 186 also tests that exact boolean at words 2199–2207. An active dive can therefore exist before the independent underwater/depth observation catches up.

Previously the cheap hub snapshot ignored `FeralDiving`; automatic Rest could remain owned during that transition. Both snapshot paths now protect an active aquatic dive, and character attribute listeners release recovery immediately on the native state change. Ordinary surface swimming still uses the existing recovery policy. Cheap snapshots recognize native Humanoid swimming/water-floor state without introducing terrain rays.

`FeralDive` prototype 37 writes **`LocalPlayer.FeralDiveCan`**, not only the legacy character `DiveCan` field. Its enclosing prototype 44 captures `LocalPlayer` into the corresponding closure slot at word 423. The adapter now reads that canonical player attribute as well as the compatibility field. The existing climb-input priority check consequently yields to actual native dive eligibility. `FeralClimb` prototypes 26–28 retain ownership of climb eligibility and mounting; the hub does not force a climb or aquatic mode.

### Talon and dive-bomb handoff

`FeralFlight` prototype 30 treats `FeralTalonLock` and `FeralDiveLocal` as **non-nil locks**, including a false value. The hub preserves that exact contract. It does not turn false into nil or clear a lock to force flight. The native suspension path disables its own hold constraints around words 291–315; later native release consumes exit velocity/crash state. Native relaunch checks begin around word 628, while the `FeralFlyDrop` release branch is around words 1084–1104.

`FeralTalonLockClient` prototype 41 binds `FeralTalonLetGo` to Space/ButtonB; prototype 40 handles its actual release request. `FeralDiveBombClient` prototype 50 binds `FeralDiveBombCancel` to Space/ButtonA/ButtonB, and prototype 47 restricts cancellation by phase and speed. These are distinct actions. The interaction integration uses flight eligibility/native binding context and leaves the dive callback's own restrictions intact. It does not send a talon release to imitate a dive cancel, replace native constraints or clear ability attributes.

## Stamina, movement and shared configuration

`WolfController` prototype 186 reads `WolfDbgNoStamina` in the holding/carrying consumption branch around word 4105. Its sprint/swim paths around words 4224–4322 consume the existing sprint-drain base and species/Burst multipliers. Prototype 170 has additional venom-stage consumption paths; venom bite cost is separate. These are reasons to retain the existing recognized consumption profile across Needs, Flight, Passive, Venom and Status configs, rather than claiming one visible stamina number controls every path.

No new stamina/resource values or immunity flags are fabricated. The debug flag is owned only while the animal and feature are eligible. It is restored on death, character replacement, disable and unload. If the native game or another owner changes it, the hub reports partial support and does not repeatedly overwrite it; an explicit off/on retry can reacquire ownership.

The largest configuration reliability defect was nested replacement. The outer required module could remain the same while its injury, venom, climb, leap, hit-prediction or species sprint profile was replaced. A lease on the detached old table would still look valid. Reconciliation now tracks those nested identities, restores detached tables and applies the current recognized profile. Removed species profiles are retired too. Equal aliases in climb plans are coalesced, while conflicting writes remain errors.

The previous HP/effect profile code could lower ordinary base rates when a new native Rest multiplier exceeded an old display cap. That reduction is removed. Native base rates, native Rest multipliers and combat exclusions are retained exactly; the recovery controller's native Rest request supplies the mechanism. A local config acknowledgement is not evidence of actual healing or faster status clearance.

Hippo's existing captured gait adapter is preserved. Its cap profile now shares the build-2412 restriction and respects later native edits instead of repeatedly reapplying its value. Unknown versions report an unverified adapter state. Native ability activation, stamina eligibility and server movement correction remain outside a local cap acknowledgement.

## Damage mitigation: what the evidence actually establishes

`CombatConfig` prototype 10, `shellMult`, reads the character's species entry in `SHELL`. It returns the default factor unless `WolfRest == true` and the native elapsed Rest time reaches `AFTER`; after eligibility it returns that profile's `TAKEN` factor. Prototype 15's SnappingTurtle shell template has **`TAKEN = 0.3` and `AFTER = 1.0`**. These values were checked through the table template's key/value references, not inferred from an unrelated numeric constant.

This establishes a species-specific, time-gated native client calculation. It does not establish universal damage immunity, an ability to lower all received damage by editing a client config, or the server's acceptance of that factor. The captured server damage handler is unavailable. No universal defense toggle, automatic shell action, fake health repair or damage remote was introduced. Manual Rest and the native species action remain available.

## Module audit and automated coverage

`roblox.luau` was reviewed across service/config acquisition, action dispatch, callback discovery and inheritance, private timing validation, snapshot/input state, player/cub affiliation, candidate geometry, visibility, carry/water checks, AFK route checks and lifecycle attachment. Changes concentrate on observed identity, input, geometry and movement-state failures. Existing native remote names/argument contracts, affiliation logic, carry authorization, bounded AFK routing and ordinary unload mechanics were retained.

`features.luau` was reviewed across all eight shared-config plans (reach, stamina, recovery, effects, mobility, speed, leap and climb), native Hippo input/gait/cap handling, ownership reconciliation and cleanup. Existing speed/leap scaling, species eligibility and native combat exclusions were preserved; the fixes address ownership, genuine native calculation inputs and stale-profile failure modes.

`tests/overhaul_native.luau` contributes **32** regressions. They cover nested/aliased config replacement, native species cone bonuses, stale/malformed geometry, bounded clear-target selection, malformed protection, remote/script replacement, immediate rediscovery, unknown-build private state, held gamepad attacks, stamina ownership/death, aquatic transition priority, canonical dive eligibility, post-dispatch annotation failures, legacy handle migration, species vertical approach geometry, and Hippo conflict/version behaviour. The repository's official runner compiles and executes these with the original suite. Final integrated counts and deterministic build evidence belong to the release's test report; this note does not freeze a transient intermediate total.

## Remaining verification boundary

No new live Roblox run is certified by this note. The client capture can explain the mechanism and automated mocks can verify coordination and cleanup, but they cannot prove server damage acceptance, restored resources, improved minigame rewards, current moving-animal/same-tree hit success, flight outcomes under real network delay or device FPS. Those live acceptance items remain explicit in the candidate's acceptance report. The stable launcher is not replaced on the strength of these client-side checks alone.
