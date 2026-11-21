# FERAL NOVA v12.1 — Project Renaissance: Final Integrated Engineering Release

**Release:** 21 November 2026  
**Status:** **Engineering integration complete; automated Luau and interaction suite passed.**  
**Current validation:** [FERAL NOVA v12.1 — GitHub Actions run 44946355586](https://github.com/GSVexed/vexed-schematics/actions/runs/44946355586)

## Recommended Potassium launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v12.1-renaissance-final-potassium.lua"))()
```

Press **End** to close the previous FERAL HUB instance, then run the new loader. **Right Shift** toggles the hub's visibility. The previous v12.0 and v11.x releases remain available.

## Final architecture

The published script contains **23 embedded, precompiled Luau modules**. Only one module (`feral-nova-native-recovery-v12.1.lua`) can make the hub's automatic `WolfActions:FireServer("Rest", ...)` request. Earlier Safe Rest, Mobile A/B and Aurora Engine Rest senders have been retired, while compatibility interfaces remain available. The action coordinator arbitrates feeding, Grab V2, combat, flight, climbing, carry and AFK movement.

The release preserves the original mechanics/code for features not safely proven improvable, instead of injecting broad speculative game changes.

### Recovery, eating and drinking

- Automatic Rest yields to real native feeding, native `FeralFeedTap`, `WolfFeed` transitions and a real primary click when `FeedCan` is present.
- **New in v12.1:** The recovered game's `WolfController` binds `WolfFeed` to **E** through `ContextActionService`. Roblox may mark that E press as processed. The native recovery controller now releases its own Rest on E **before** the generic processed-input guard, unless the user is chatting, in a game menu or deliberately manually Resting. This targets the first-attempt eating/drinking race that was previously missed by the initial click-only guard.
- The feed action is still the game's own action; the hub does not fabricate food/water, own needs, server events or inventory changes.
- After a bounded native feeding window, recovery resumes automatically when safe. Only hub-owned Rest requests are cancelled; player-owned manual Rest remains untouched.
- Delayed Rest animation echoes are locally guarded, but other-player replication cannot be inferred.
- Venom, bleed and injury attribute removal is counted as complete clearance, and manual/automatic/baseline/feeding/combat intervals are separated for outcome observation.

### Eagle and Talon

- Native `FeralLunge` event connection recovers from late creation or replacement. Prey selection listens for `FeralTalonTarget.Value` changes and object removal. Replicated `FeralClamp` observations are distinguished from simply sending a drag request.
- A follow-up drag request respects the shared carry action policy.
- **New in v12.0:** A dedicated timestamp converter can safely compare a native press or selection timestamp using either `os.clock()` or `Workspace:GetServerTimeNow()` when its domain is recognizable. Otherwise the code skips the invalid cross-clock comparison and records it. This avoids falsely rejecting valid prey when clocks differ.
- **Source-specific qualification:** The recovered game snapshot writes **both** `FeralTalonPress` and the `FeralTalonTarget` **At** timestamp using `os.clock()`. Clock conversion therefore improves robustness to inconsistent/future snapshots; it is not evidence that the present game inherently uses mixed clocks.
- A client-side shortened `FeralLungeReadyAt` is not a demonstrated shorter server-authoritative Talon cooldown. Oversized target server acceptance remains unverified.

### Carry, Grab V2, climbing, flight and AFK

- The shared action coordinator grants exclusive priority leases in the order **Grab minigame > native feeding > optional AFK walk**. Leases do not carry across respawn, and short snapshot caching now invalidates immediately on changing animals.
- Deferred native carry commands are tied to the original animal and cancelled on respawn or capture.
- Grab V2 ignores a delayed native `end` and **new in v12** ignores a delayed `strike` event with an ID different from the currently active session. No fake native `start` or `strike` events are created; actual server-graded Perfect outcomes are not guaranteed.
- Flight takeoff respects the shared action policy while preserving the existing underwater return and carry handling. Climb ignores Q consumed by another Roblox interface.
- The two anti-AFK behaviors remain best-effort and conservative; uninterrupted Roblox session or survival credit is not guaranteed.

### UI, startup and lifecycle

- The published package verifies module syntax with the user's `loadstring` availability, creates the hub in a stable order, and mounts **FERAL NOVA v12.1** with prior-GUI cleanup.
- Includes **69 startup checks** that inspect actual current module interfaces; the prior v11.3.1 `62/65 DEGRADED` issue from obsolete Eagle counter names was fixed in v11.3.2.
- Full-controller shutdown and recovery of prior version state are retained; native input/carry/remote listeners are disconnected on close.
- A potential 4× status rate is **not** reported as server verified merely because a local config contains `REST_MULT=4`.

## Verification — what was actually tested

The [v12.1 CI run](https://github.com/GSVexed/vexed-schematics/actions/runs/44946355586) passed:

1. GitHub source-to-bundle identity, all **23** embedded module names/dependencies and preservation of **21** of the previous v12.0 module bodies.
2. Official Luau compilation of the full standalone launcher and **all 23 modules**.
3. Single native Rest writer, retired old Rest modules and no redundant engine Rest requests.
4. Simulated native `WolfFeed`, `FeedCan`, `FeralFeedTap`, **processed E-key feed input**, hub-owned Rest release and automatic resume, delayed Rest-echo handling, manual Rest ownership and status attribute clearing.
5. Action-lease hierarchy, flight conflict handling and respawn cache invalidation.
6. Grab V2 stale-session `end` and `strike` protection.
7. Eagle remote late-binding/replacement, reused prey ObjectValue, carry-policy denial and cross-clock timestamp normalization.
8. Deferred native G action cancellation on respawn/capture.
9. The **actual** v12.1 `H.selfCheck(ctx)` function returning `SELF-CHECK PASS 69/69` in a mock with all required interfaces, and correctly returning `INCOMPLETE 68/69` after a required Eagle counter was intentionally removed.

These are source and mock-runtime tests, not a live Roblox multiplayer field test. Runtime startup should be checked in Potassium before claiming a particular live session is READY.

## Original goals — acceptance boundaries

| Goal | Release status | Important qualification |
|---|---|---|
| Stable 23-module launcher | Implemented, compiled and regression-tested | Live Potassium result not observed for v12.1 |
| No duplicate Rest writers | Verified in the entire embedded source | No proof of perfect network replication |
| Eat/drink consistently with recovery enabled | Improved with game-native E, FeedTap and WolfFeed priority | Hunger/Thirst change must still be confirmed by FERAL's server |
| Automatic recovery without forced visible physical Rest | Native controller and local pose handling integrated | How other players see the pose is not proven |
| Genuine **4×** healing of negative effects | Better observation and no false claim | The game's server controls actual decay; live comparison required |
| Oversized Eagle pickup and reduced server Talon cooldown | Better request targeting and event handling | Server can still reject by size or authoritative cooldown |
| Grab V2 auto-perfect | Timed native strike coordination hardened | Server's Perfect grade not guaranteed |
| Anti-AFK and survival bonus | Source-guided client options retained | Roblox/FERAL server retention rules are authoritative |

### Why the in-game 4× display can mislead

The recovered `StatusController` client code (in `UPLOAD_PART_002_DATA.zip`, `S0003930_part001.source.txt`) uses the character's `WolfRest` attribute to determine the local displayed `REST_MULT`. The hub sometimes masks `WolfRest` locally to avoid visible Rest. Therefore **the local display may not be a valid proxy for actual server-awarded effect decay**. The best available evidence is the trend of actual status attributes in comparable conditions; neither the visible pose nor config value alone proves 4×.

## Closure

**Project Renaissance's engineering integration and code-level regression work are complete in v12.1.** A promise that every gameplay feature is “perfect” would overstate what can be established from local source code and simulated runtime. Server-owned gameplay outcomes and live player-to-player visuals remain explicit external verification items, not silently relabeled as successful features. Future game updates could change client protocols.

The previous v12.0, v11.3.2 and v10.3 releases remain untouched and available for rollback.
