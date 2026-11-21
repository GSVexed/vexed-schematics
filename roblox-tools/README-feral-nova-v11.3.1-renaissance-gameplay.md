# FERAL NOVA v11.3.1 — Project Renaissance: Gameplay Reliability

**Released:** 21 November 2026  
**Build:** 23 embedded Luau modules, compiled individually and bundled offline after the one-line GitHub fetch.  
**Validation:** [All v11.3.1 automated checks passed](https://github.com/GSVexed/vexed-schematics/actions/runs/44944795125).

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v11.3.1-renaissance-gameplay-potassium.lua"))()
```

Use **End** to close the previous hub before loading; Right Shift hides/shows the UI. v11.3, v11.2 and v11.0 are preserved as earlier versions.

## Changes from v11.2

Seven gameplay/interface modules are revised, sixteen module bodies unchanged. This release builds on the single automatic Rest writer and the native feeding guards implemented in earlier Renaissance revisions.

1. **Action Coordinator v11.3:** Leases now enforce the strict order **Grab minigame (100) > native feeding (88) > optional AFK walking (35)**. A lower-priority feature cannot overwrite a higher-priority active lease. Renewing a lease cannot shorten its existing term. Leases are tied to the current animal and expire on character change. Native flight permissions now refuse conflicting feeding, minigame, captive, AFK-walk and modal conditions while preserving legitimate combat escape or flight while carrying prey.
2. **Flight v11.3:** Checks shared action priority *before* altering the local water-takeoff configuration or sending `FeralFlyRequest`. Counts priority denials and errors independently. Earlier underwater-exit and clamp-restoration handling is otherwise preserved.
3. **Climb v11.3:** Does not buffer Q presses already consumed by another Roblox interface. Keeps the existing native climb/dive arbitration, one bounded retry and source-guided climb configuration.
4. **Grab V2 v11.3:** A delayed `end` for a different valid session ID cannot cancel a newer session. A new `start` session clears old pending strike data. Tracks stale session events, while native server-issued strike timing and server grading remain authoritative.
5. **Eagle v11.3.1:** The assistant binds a late-arriving `FeralLunge` remote and rebinds when it is replaced, disconnecting the old listener. Watches `FeralTalonTarget.Value` changes and target-object removal, preventing stale prey selection when the game reuses an ObjectValue. Before attempting a native follow-up drag request after an actual scratch reply, respects the same shared carry action priority as the normal carry controller. Client deadline changes and server pickup are not conflated.
6. **Carry Core v11.3:** Deferred native G action is tied to the original animal. If the player respawns or becomes captured during the native Rest-release delay, the queued action is cancelled instead of acting on a different animal or unsafe state. Reports those cancellations.
7. **UI v11.3.1:** Displays accurate current release/build information and updated controls/help. The previous GUI identity is cleaned up on reload.

## Verified regression checks

Workflow: [FERAL NOVA v11.3.1 - Deferred Carry and Gameplay Regression](https://github.com/GSVexed/vexed-schematics/actions/runs/44944795125)

- Official Luau compilation of the 23-module standalone bundle and each of the 23 individual modules.
- Source-to-bundle identity, no missing module dependencies, and consistent version and UI metadata.
- Exactly one automatic Rest request writer among all 23 modules; two old Rest compatibility modules cannot be re-enabled.
- Native `WolfFeed`, feed-eligible click and early feed signal preempt Rest; post-feed recovery resumes without overriding manual Rest; disappearing effect attributes count as cleared.
- Lower-priority AFK leases cannot overwrite feeding/minigame; respawn clears old leases; flight blocked while feeding/AFK/minigame.
- Late Grab session-end events do not terminate a new session.
- Eagle late remote binding, remote replacement, ObjectValue target update and native follow-up carry-policy denial.
- Deferred native G cancelled on respawn or new capture, while an eligible same-character action still calls the game helper.

## Remaining unknowns and limits

The recovered game client code and automated mocks are not a FERAL server. The changes above improve *client action coordination and outcome measurement*, but they do not prove:

- 4× reduction in bleeding, injury and venom while mobile; `REST_MULT=4` remains a client-side configuration value without authoritative confirmation.
- Every visual feeding/drinking animation yields actual Hunger/Thirst resources.
- Eagle carrying prohibited-size animals or reducing server-authoritative Talon cooldowns.
- A guaranteed server-ranked Perfect grab minigame result.
- Roblox anti-idle APIs or a conservative AFK walking step guarantee uninterrupted survival credit.
- That local Rest pose masking produces an identical pose visible to other players.

No game-server state is falsely presented as verified. Existing v11.2 recovery safeguards and older builds remain available for rollback.
