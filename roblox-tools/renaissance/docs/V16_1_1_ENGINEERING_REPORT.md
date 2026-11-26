# FERAL Renaissance 16.1.1 engineering report

## Outcome and scope

This candidate combines the later input/Hippo/voice branch with reliability work that was left behind in the older 16.0.2 line. The integrated release contains 17 Renaissance modules and 12 Territory modules. The 28 core feature records, additional Territory page, original stable launchers and historical versioned bundles are retained.

The source defects described below are implemented and covered by the required automatic verification gate. **Current live Roblox input behavior and server-accepted outcomes remain unverified.** The exact final test counts, compiled files, bundle hash, source fingerprint and source commit belong to [candidate.json](../candidate.json), not to an old version's test report.

The authorization in the engineering handoff was sufficient for repository investigation, local implementation, testing and publication of a reviewable candidate. No additional permission request or user-run diagnostic collector was required. Runtime availability is a separate technical constraint.

## 1. What was wrong with Hold to Bite

There was more than one fault, so changing a repeat delay alone could not establish a reliable repair.

### Callback availability and stale ownership

The preferred path invokes the original native attack function. Earlier versions could not consistently obtain that function, and the 16.1.0 fallback lookup assumed exact numeric positions for captured values. Reordering an otherwise compatible callback's captured values caused validation to fail. Cached callbacks also needed to expire when their current script or action remote changed.

The bridge now checks relationships between the current own script, local player, current remote and original functions. Calling the original validated function is separated from reading its private timing layout; unsupported timing layouts are not guessed. Discovery is bounded, only requested for held input, and cancelled scans release retained work. Interrupting an unfinished scan no longer imposes the completed-failure retry delay.

See [combat_input.luau](../src/combat_input.luau), [roblox.luau](../src/roblox.luau), and [combat_regressions.luau](../tests/combat_regressions.luau).

### The scheduler did not own the whole synthetic pulse

A repeat fallback schedules an Up → Down → Up sequence. Previously, clearing the hold scheduler did not necessarily cancel its already scheduled Down. Releasing the real button, disabling the option or changing context could therefore leave a delayed action alive.

Cancellation now reaches the actual pulse and its timer. The delayed Down validates current character and input/action ownership again immediately before dispatch. Preparation failures and throwing ownership callbacks cancel the attempt. Synchronous synthetic release events are excluded before optional input-object identity checks.

### Focus and interface input could resurrect an old hold

Roblox input events depend on client focus. A release while unfocused cannot be assumed to arrive normally. The prior implementation could clear a hold and immediately reacquire it from polling, or start repeating after dragging a consumed UI click outside the hub.

Window focus loss, text input, consumed input and hub controls now suspend held ownership. Returning focus or leaving a control does not recreate an attack. A fresh gameplay input establishes ownership again. This behavior is tested through the same input-event and timer boundaries used by the controller.

Reference: [Roblox UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService), including InputEnded, WindowFocusReleased and WindowFocused. [InputObject](https://create.roblox.com/docs/reference/engine/classes/InputObject) is useful input metadata; the implementation does not assume undocumented hardware-versus-synthetic identity guarantees.

### A loader could select an entirely older implementation

The usual stable `feral-renaissance.lua` launcher intentionally remained pinned to 15.7.0. Reusing it would never execute the later hold changes, even if a newer version existed in another branch. This is a verified repository fact; it does not establish which URL the user most recently ran.

The candidate now has explicit versioned instructions, a separate pinned candidate launcher, an injected visible version and a deterministic source fingerprint in the automatic local report. Stable and candidate identities are separately recorded.

## 2. Why fixes reappeared as regressions

The previous “unified” release inherited 15.8.7 and selectively copied Territory 0.8 plus feeding. It did not merge the full earlier reliability line. Three complete overhaul suites, containing 90 behavioral scenarios, disappeared. Later passing totals therefore did not cover many previously fixed failures.

| Historical line | Verified source reference | Role in this reconciliation |
|---|---|---|
| 16.0.2 | `cca41a88928b8737208236cfefd39c605ac2f493` | Recovery, lease, native ownership, state, UI and test restoration |
| 15.8.7 | `de450baa94ed465e2ffb7fe10fdcfe687385c401` | Later held-input, feedback, Hippo and voice work |
| 16.1.0 | `0b4183de81a530bbcbb15e660ecad14f7d84dce3` | Starting candidate, already containing Territory 0.8 |
| Common earlier ancestor | `7dcd03d78d7b3701e1cc9980f3ece6b510c21a2b` | Three-way source reconciliation |

Both prior branches are candidates; neither is treated as live-proven merely because it was newer. Source changes were reconciled by ownership and behavior. Later controls and modules were retained, and older tests were restored with conflicts resolved against the user's current requirements.

One intentional exception is proximity-based recovery cancellation. The user explicitly wanted recovery usable around mixed groups. Nearby bodies alone therefore do not disable recovery. Actual attack input, native combat/ability restrictions and input ownership still take priority.

## 3. Ghost-hit feedback and attack timing

The candidate distinguishes four observations:

1. An input was attempted.
2. A native bite marker or local effect occurred.
3. The game sent a real hit reply.
4. A target's replicated HP decreased during a relevant observation window.

These are different evidence levels. A local sound, successful callback or sent input is not accepted damage. Even a nearby HP decline can have another cause.

Earlier classified transactions now remain eligible for bounded late evidence. HP samples start from the native marker, transient decreases are remembered, and comparisons become invalid if the observed Humanoid or maximum HP changes. A later guide selection does not replace the target associated with an earlier marker. Equal plausible reply candidates remain ambiguous rather than assigning every reply to the most recent bite.

A real but unassigned positive game reply remains visible as a real observation. Ability damage overlapping ordinary bites is not credited as proof that ordinary bite cadence succeeded, and ambiguous periods do not train the cadence governor in either direction. Optional automatic extended contacts retain conservative pacing after complete unconfirmed windows, without claiming those windows prove rejection.

The existing attack-speed option remains separate from Hold to Bite. Its client timing request is not a measured server rate. No new damage acceptance, cooldown bypass, server reach or “ghost hits eliminated” claim is made.

## 4. State, lifecycle and usability repairs

**Recovery:** Failed Rest entry, renewal and exit now retain truthful ownership and visible native state. An unsuccessful exit cannot schedule an assisted follow-up as though release succeeded. Negative conditions have independent, bounded grace for missing replication; an explicit zero terminates that condition, while tiny positive residuals remain eligible. Native base health/condition rates are preserved instead of being reduced to fit a presumed multiplier.

**Minigames:** Passive native ownership remains observed with automation OFF. Retired session IDs cannot resurrect an ended fight. Optional callback errors are contained. Temporary server-clock loss preserves an issued strike without inventing timestamps; extended loss releases ownership. Real strike work runs before Territory discovery/routing in the same frame. Hunter-bite compatibility remains conditional on verified separated native bindings, while unsafe or unsupported contexts yield to the minigame.

**Configuration:** Multi-field leases validate before writes, recheck ownership, roll back partial application, and preserve later external edits. Replaced nested configuration tables retire old ownership. Settings reject unrelated JSON, preserve explicit OFFs and verify the backup before overwriting the primary file.

**UI:** The current controls fit or scroll on smaller viewports; dragging stays bounded; touch users have a reopen control. Overlays hide when their camera or tracked body disappears. Cobra-specific range coloring does not replace every animal's normal colors. These are layout/behavior checks in mocks, not a live frame-rate benchmark.

**Shutdown and audio:** Cleanup proceeds across independent owners even if one release fails; errors remain available. Camera and voice changes roll back after a setter partially mutates then fails. Temporarily detached voice emitters are restored so reattachment does not compound an attenuation scale. Local attenuation operates only on exposed audio already available to the client; it does not create missing voice streams or change platform proximity permissions. Reference: [Roblox AudioEmitter](https://create.roblox.com/docs/reference/engine/classes/AudioEmitter).

## 5. Module inventory and disposition

“Retained” means the module remained at the established source while its relevant integration suite was rerun. It does not imply new live validation or a new algorithmic rewrite.

| Module | Responsibility | Disposition |
|---|---|---|
| core | Scopes, feature registry, leases, bounded observations | Restored transactions, cleanup aggregation, immutable samples and configurable defaults |
| settings | Settings migration, persistence and backup | Restored schema recognition, explicit false handling and backup readback |
| policy | Action priority and eligibility | Restored numeric/unknown-state guards and rescue priority; kept mixpacking preference |
| grab | Native session/strike model | Restored retirement, clock-slip and reentrancy handling |
| grab_input | Native minigame binding ownership | Restored guarded introspection, manual returns and release behavior |
| recovery | Rest ownership, condition/HP observations | Restored failed dispatch handling and independent condition grace |
| feeding | Native feed approach, progress and bounded repair | Retained; already matched 16.0.2; integration cases restored |
| combat_input | Held/buffered scheduler and cadence observations | Fixed pulse cancellation, preparation failures and ownership/discovery lifetime |
| rescue | Native carry interaction coordination | Restored pickup/drop ownership and intervening carry cancellation |
| hippo | Existing native Hippo ability coordination | Retained; isolated overlapping ability feedback from normal bite attribution |
| features | Reversible configuration adaptations | Restored nested identity tracking, conflict/death cleanup and preserved native rates |
| roblox | Native services, schemas, callbacks, targets and input | Reconciled old guards with later bounded native/replay paths |
| zoom | Owned camera bounds | Restored partial-write rollback |
| voice | Local compatible voice attenuation | Added failure rollback and detached-emitter restoration |
| test_features | Bounded own-character local evidence | Actual version/fingerprint; unknown combat retained; existing automatic local saving |
| ui | Main window, controls and overlays | Restored sizing/scroll/drag/reopen and stale-data protections |
| controller | Cross-module ownership and scheduler | Restored state resets, minigame ordering, late observations and independent cleanup |
| amber_ledger | Territory run clocks, outcomes and profiling | Retained 0.8 source and suite coverage |
| amber_model | Generation-specific travel/passages | Retained 0.8 source and suite coverage |
| amber_planner | Priority, capacity and overload scheduling | Retained 0.8 source and suite coverage |
| amber_gait | Requested and observed native gaits | Retained 0.8 source and suite coverage |
| amber_nav | Terrain/support routes and progress | Retained 0.8 source and suite coverage |
| amber_hunt | NPC pursuit and attack evidence | Retained 0.8 source and suite coverage |
| amber_care | Feed/drink observations and retries | Retained 0.8 source and suite coverage |
| amber_agent | Exclusive objectives and resumable work | Retained 0.8 source and suite coverage |
| amber_bridge | Native configuration/resources and input | Retained 0.8 source and suite coverage |
| amber_driver | Owned movement callback | Retained 0.8 source and suite coverage |
| amber_ui | Integrated Territory page | Retained 0.8 source and suite coverage |
| amber_runtime | Hub attachment, scheduler and shutdown | Retained 0.8 source and integration coverage |

The older NOVA/AURORA bundles remain historical artifacts, not alternate runtime module providers for this build. The current bundle embeds all 29 modules; no runtime cross-branch Territory download is required.

## 6. Verification and release discipline

The mandatory core suite inventory is the main suite, three restored overhaul suites, and the focused combat/lifecycle/review suites. Removing any required file fails verification. Territory retains all 305 scenarios from its 0.8 suite. Tests cover failures, replacement objects, cancellation and repeated lifecycle transitions, not only compilation.

New cancellation/discovery scenarios were also run against the immutable 16.1.0 bundle: 11 of 12 failed there and all 12 passed with the corrections. The two initial new lifecycle cases likewise failed before and passed after. The final combined run in candidate.json supersedes intermediate working-tree test totals.

The release gate also checks:

- Official pinned Luau compilation of source modules, fixtures, complete bundle and launcher.
- Exact parity between embedded sources and repository source.
- A byte-identical rebuild of the bundle and manifest.
- Hash protection for historical Renaissance and Territory artifacts.
- Both current test reports, exact tested-input fingerprints and integrated-version agreement.
- A pinned commit containing the exact tested source, tests, manifest and distributable.

The source fingerprint hashes the version configuration plus ordered module hashes; it is deliberately independent of the bundle's own hash, avoiding a self-reference. Runtime reports carry that fingerprint and the actual controller version. The local report's saved timestamp is not proof a private synchronization service retrieved it.

CI runs the same verification with read-only repository permission and uploads evidence. It does not automatically replace stable launchers or commit regenerated artifacts. Candidate metadata records the distinction between implemented/mock-verified behavior and unverified live outcomes.

## 7. Remaining limits and acceptance status

The available automatic runtime report belonged to an earlier candidate and came from saved-file fallback after live execution failed. It cannot establish the current loaded build, input behavior or server results. Private report contents are not included in this public release.

| Requirement area | Current result | Remaining evidence or capability |
|---|---|---|
| Release baseline/version consistency | Reconciled source, single candidate config, pinned bundle and paired reports | None for repository identity |
| Hold-to-bite logic | Corrected ownership, discovery and pulse lifecycle; behavioral tests | Actual executor callback availability and real mouse hold/release in Roblox |
| Ghost-hit handling | Better provenance, late evidence and ambiguous-reply handling | Accepted attacks/damage on the actual server; no promise to repair inaccessible server rules |
| Combat/minigame coexistence | Verified conditional native lane, priority, clock/session isolation | Live accepted bite and minigame results together |
| Recovery and movement state | Restored failure/ownership/transitions; native behavior retained | Sustained HP/status effects and animal-specific live movement |
| UI and configuration | Layout/interaction mocks, schema/backup and lease tests | Device rendering/performance confirmation |
| Voice accessibility | Reversible compatible local attenuation; failure/detachment tests | Availability of transmitted streams and actual audibility |
| Unload/reinitialize | Owned resources, timers, scopes, listeners and errors covered | Native executor teardown behavior outside mocked services |
| Territory engine | 0.8 retained; all deterministic scenarios rerun | Full-map retention/yield; native autonomous climb/flight/depth routes remain unsupported |
| Performance | Bounded discovery, target/raycast work and lifecycle checks restored | Long-session CPU/memory/FPS measurements on the user's device |

This is a tested engineering candidate, not a claim that every live gameplay goal is complete. The remaining runtime limitation does not block delivery of the source fixes, versioned bundle, regression protection, reviewable changes or exact release instructions.
