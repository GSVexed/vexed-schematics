# Amber Autopilot 0.4.0 — engineering and acceptance report

Date: 25 November 2026. Baseline main: `2874e8d5b29bd00f67ff62a5edcdef5f4c451170`. Recovered development branch: `renaissance/amber-v0.4-reliability`, head `20a94cdce04e6813f8c783b98a955cccce028af3`.

This release continues the existing project. It packages the completed source as `roblox-tools/feral-amber-autopilot-v0.4.lua` and updates the existing combined launcher. The previous versioned bundles and Renaissance 15.4.3 remain byte-for-byte unchanged.

## Ranked defects and resulting behavior

| Priority | Finding in the previous code | Change and practical limit |
|---|---|---|
| P0 | Steering was written on Heartbeat while native WolfMove samples MoveDirection at Input+1. Normal player controls can replace that direction before the sample. | Insert ordinary world-space direction in the detected PlayerModule move callback. Probe legacy and captured StarterPlayer layouts; preserve other callback owners and use keys when unavailable. Static timing and simulated ordering support this fix; live callback/input acceptance remains unverified. |
| P0 | Main coordinator unconditionally paused on swimming. The branch's water logic was therefore unreachable during a swim, and snapshot did not supply allowWater. | Carry a native capability profile into routing and keep surface swimming inside the shared travel state. Underwater and flight control remain manual. |
| P0 | Movement stopped at segment completion, and path computation cleared direction while yielding. Old computations could finish after STOP. | Prefetch local segments while a valid segment remains active. Compute asynchronously; use generation ownership to discard stale results. |
| P0 | Moving prey caused destination resets. Nearby prey caused the hunter to stop before a facing failure, and clicks had no damage verification. | Keep pursuit identity and watchdogs stable, predict a short interception, maintain speed against moving prey, use native geometry and line of sight, then observe target HP. Abandon escaping or ineffective prey. HP declines are reported with attribution unverified. |
| P1 | Sprint requests were treated like active modes; Burst release did not undo its native toggle. HudBurstNo was incorrectly read as a boolean. | Track requests versus native observations, acknowledge transitions, undo owned active toggles, recognise numeric denial pulses, and bound ineffective requests. An available executor-key provider gets a retry when virtual gait input has no acknowledgement. |
| P1 | Need arbitration cancelled care when it crossed the low trigger, before the completion target. Repeated E could cancel private approach state before WolfFeed appeared. | Latch care through actual resource gain and its target; let native feeding own approach; stop an owned private approach on STOP; resume the suspended territory objective. |
| P1 | Water selection depended on one landmark ring and could choose dry positions without finding an actual shore. | Search nearby actual water and native water offers; sample broader landmark rings; approach distant unstreamed water landmarks, then refine with streamed terrain. Failed accesses receive cooldowns. |
| P1 | Fallback direct travel exempted Terrain obstacles and used animal length as path radius. | Respect terrain walls, probe body-width corridors, use lateral width for path clearance and check sampled surface height changes. Narrow or streaming-dependent routes can still fail and are bounded. |
| P1 | Claim progress timeout could begin during travel; survival interruptions discarded the territory objective. | Begin interaction timing on arrival/progress, retain suspended territory, count ownership/hold changes, and try alternate positions within the same eligible hex. |
| P2 | CI had a misspelled workflow path and did not cover launcher/versioned bundle edits. | Correct workflow filters; compile all eight modules, launcher and distributable; execute package lifecycle tests and protect rollback hashes. |

## Native evidence

The original supplied archive was recovered and all **943 catalog payloads** passed their stored length/checksum checks. Selected bytecode fingerprints match the repository's v2412 trace index. Captured programs were parsed statically, never executed or included in the distribution. Exact fingerprints and instruction locations are recorded in [native-contracts.json](native-contracts.json).

Relevant findings include native X/Z/R bindings, Burst Begin-toggle behavior, the numeric HudBurstNo timestamp, character WolfRunIntent/WolfTrot, player Hud gait attributes, private toggleFeed approach state, native water-depth sprint gating, species diets and tagged food eligibility. TerritoryConfig's captured reference radius/time are read from current runtime config instead of being treated as a fixed live server rule. The whole current Hexes set supplies map coverage.

The capture indexes the platform script at `game/StarterPlayer/PlayerModule/ControlModule`; it does not supply that platform module's source as a game program. Runtime discovery therefore verifies the returned table and moveFunction instead of assuming a legacy API. Roblox's [official IAS release announcement](https://devforum.roblox.com/t/full-release-input-action-system-ias-newly-converted-player-scripts/4678416) also explains that legacy GetControls endpoints may disappear. Roblox's [published reference ControlModule](https://github.com/Roblox/avatar/blob/main/ReferenceBodyCreator/StarterPlayerScripts/PlayerModule/ControlModule/init.lua) supports the legacy moveFunction callback contract. A future incompatible layout falls back and is identified in COPY STATUS.

Client code, HUD flags and successful local function calls do not prove server authority. The report does not infer increased combat range, changed cooldowns, resource immunity or server acceptance from these sources.

## Architecture and integration

Agent owns one objective. A surviving territory objective is suspended during food/water/HP care, then revalidated and resumed. Native feeding owns its own approach after the addon requests it. Hunt uses the same navigator rather than a competing movement loop.

Nav samples actual root displacement, local waypoint progress, oscillation, correction size and route failures. Moving prey updates the destination without resetting its progress timer. Route jobs carry a generation token. A stopped or replaced controller cannot accept an old path result. Driver restores its callback only while it still owns that callback. Native-key steering and world-space steering are mutually exclusive.

Gait selection accounts for approach distance, turn angle, observed stamina, swimming and prey movement. Requests, observations, attempts and failures remain separate. Unknown stamina never becomes assumed infinite stamina. The user's confirmed stamina behavior is compatible with sustained routes, but the addon does not create or assume that behavior for other animals.

The bridge reads native Species/Forage/Needs/Combat/Territory configuration, current player/animal state, all eligible hexes, NPCs and food offers. Native Renaissance feeding and bite handlers are reused when available; ordinary input is the fallback. Existing recovery yields while Amber owns travel/care/hunting; normal low-HP recovery may proceed. Renaissance's anti-idle movement is postponed during Amber ownership. Native abilities, rescue, manual controls, player proximity and character/map/pack changes interrupt Amber.

No teleport, root transform, forced rotation, velocity edit, direct gameplay remote, resource attribute or territory ownership writer is added. No private state report is uploaded automatically. Reports omit other player names.

## Acceptance evidence

| Gate | Result type | Outcome |
|---|---|---|
| Amber component, care, driver, gait, hunting, simulated travel and packaged lifecycle suites | Deterministic simulations and service mocks | See current [test-results.json](../test-results.json); all cases pass. |
| Official Luau compilation | Official pinned compiler | Every owned module, test suite, bundle and launcher compiles. |
| Deterministic packaging | Exact source comparison | Generated bundle equals its module sources and bootstrap. |
| Rollbacks and Renaissance launcher/bundle | SHA-256 comparison | Five protected artifacts unchanged. |
| Renaissance 15.4.3 regressions | Existing separate service-boundary suite | **187/187 pass**, 18 compile targets; source and release artifacts unchanged. |
| Original FERAL capture | Static verification | 943 catalog payloads, zero checksum/length errors. |
| Live Roblox/Potassium | No tool available in this session | **Not performed.** No current-gameplay success or Amber/hour result is claimed. |

Tests reproduce sustained route progress, segment boundaries, waypoint overshoot, terrain obstruction, large-body clearance, moving destinations, bounded stationary recovery, water entry/crossing/exit, steep banks, ignored Sprint/Burst, native state acknowledgements, pending feed approach, need completion, suspended-objective resumption, ineffective attacks, observed prey HP changes/death, nearby players, pack/animal replacement, pending path cancellation, Right Shift, drag/minimise/hide, STOP, re-execution and Renaissance unload.

Travel traces are scripted from the static contracts and reported symptoms. They are **not recorded live movement traces**. The tests cannot establish native physics acceptance, multiplayer damage or rewards.

## Known limits and targeted gameplay acceptance

- Real path/physics behavior, gait activation, NPC damage, claim/scent rates and income must still be checked in the current game. The capture is v2412, not a guarantee that a later game update has identical internals.
- Shared strategy supports ground/surface-swimming animals with native profiles and compatible input. It does not implement aerial routing or underwater navigation. Unknown species use conservative territory/native-offer behavior and do not receive invented attack profiles.
- Native feeding cancellation is strongest when Renaissance exposes the validated private feed handler. Without that handler the fallback cannot safely infer or cancel every unreplicated approach state; ordinary native E may be needed. Resource success is still never assumed.
- Faster prey may remain uncatchable. Dynamic streaming, cliffs, narrow banks and nearby players may pause or reject objectives. Retries are limited, and the reason is visible.
- Player proximity uses the existing conservative exclusion policy. A crowded server may leave no safe objective. This is not an undetectability or anti-cheat guarantee.
- Amber earned means observed positive account balance changes during this session. Other reward sources can contribute; spending and server persistence cannot be reconstructed from a client observation alone.

Use the three short checks in the [README](../README.md): one minute of Bear/Spirit Bear travel, one naturally triggered care/hunt cycle, then STOP and Renaissance unload. If a stage fails, provide one COPY STATUS report. It includes requested/observed gait, control layout, distance and measured travel, most recent route failure, claim/hold evidence, attack/HP results, need gain, version and recent events.

## Release and rollback

The stable combined launcher now targets the separately versioned v0.4 bundle once this change is merged. v0.3/v0.2/v0.1 remain available and hash protected. The rollback launcher is in the README. Published CI and the pull request record provide the source-validation results; they must not be described as live gameplay validation.
