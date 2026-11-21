# FERAL NOVA v11.0 — Project Renaissance

**Release:** 2026-11-21  
**Status:** First integrated Renaissance build, automated checks passing; live multiplayer/server effects unverified.

## Launcher

Potassium, on the user's own Roblox client:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v11.0-renaissance-potassium.lua"))()
```

Press **End** to close the previous FERAL HUB version before loading. **Right Shift** shows/hides the hub. The earlier v10.3 file remains unchanged as a rollback.

## What was rebuilt in this release

The bundle still contains **23 self-contained modules**, with **six individually sourced revisions** and **17 legacy module bodies preserved**. The same single launcher validates its embedded module names before startup.

1. **Unified action core v11:** Recognizes `WolfFeed`, separates nearby `FeedCan` eligibility from actual feeding, grants short feed-priority leases for early game-native `FeralFeedTap` actions, and prevents the coordinator from scheduling recovery, carry, climb or survival AFK movement during a feed.
2. **Native recovery v11:** Yields hub-owned Rest on a native feed tap or the earliest `WolfFeed` transition. Keeps a short, bounded settling window after the last feed state, then automatically resumes Rest requests when eligible. Real player-owned stationary Rest is not cancelled, and combat retains priority.
3. **Late-pose reconciliation:** Own delayed `Rest(true)` attribute echoes are suppressed immediately during a bounded feeding handoff, with per-interaction count limits, rather than being misclassified as player Rest or leaving an apparent Resting pose. This local visual change does not guarantee what other players see.
4. **Active Recovery v11:** Adds an explicit `FEEDING_PAUSE` mode so recovery status agrees with the actual action guard. Previous manual Rest ownership and combat exclusions are retained.
5. **Config/regen v11:** Stops calling a locally available `REST_MULT=4` a verified server-awarded 4× status recovery benefit.
6. **Status evidence v11 and native observers:** Correctly count the full clearing of bleeding/venom/injury when the character's attribute is removed, not only when it reaches a numeric zero. Native status observations are now separated into own-automatic-Rest, manual-Rest and baseline samples. They measure changes; they never write conditions, needs, HP or combat attributes.
7. **UI v11:** Describes feeding priority and the unverified status multiplier accurately.

## What is *not* claimed as fixed

- **Four-times condition clearance in live Roblox:** The original recovered `StatusConfig` already contained `REST_MULT=4`. The game server controls whether this multiplier applies, under which conditions, and whether moving Rest receives it. This build improves arbitration and evidence; it does **not** override server rules or guarantee 4× bleeding, venom or fracture clearing.
- **Live eating and drinking:** Static code and simulated native events confirm the recovery controller releases its own Rest when native feeding starts. A simulated `WolfFeed` attribute is not proof that a live server accepts the next food/water transaction or increments the own animal's `Hunger`/`Thirst`.
- **Visibility to other clients:** `WolfRest` presentation masking is local and a late server echo may still be represented differently elsewhere.
- **Oversized Eagle carrying, real Talon cooldown shortening, guaranteed Grab V2 Perfect, endless server-owned needs or survival credit:** Not established by this release.

## Verification

GitHub Actions workflow: `.github/workflows/feral-nova-v11.0-renaissance-validate.yml`

Latest passing validation for this version:
https://github.com/GSVexed/vexed-schematics/actions/runs/44941488611

Checks:
- The 23-module source graph has no missing/duplicated embedded module names, and all internal `get("...")` calls resolve.
- Six revised modules match their standalone source files; 17 original game modules are unchanged from the v10.3 bundle.
- Official Luau compiler checks the full launcher and all 23 embedded modules.
- Runtime mocks exercise `WolfFeed` immediate Rest release, native feed-tap preemption, post-feed recovery resumption, delayed Rest-echo suppression, manual Rest ownership and complete effect-attribute clearance.
- Coordinator mock ensures feeding overrides recovery, survival walking, carry and climbing.

The mock tests are useful regression checks; they cannot validate game-server behavior.

## Architectural review / remaining Renaissance work

1. **Recovery consolidation:** The codebase still embeds older Safe Rest and Mobile A/B components for compatibility while Active Recovery disables them. A later architectural consolidation could retire those legacy implementations once their specific tests have been carried into the unified native supervisor.
2. **Action priority completeness:** Current source recognizes combat, grabs, flight, carrying, climbing, feeding, native and manual Rest, and AFK. Other species-specific abilities still require a source-guided interaction audit to avoid input preemption.
3. **Server outcome separation:** Bite/catch labels, local range or cooldown settings and synthetic request success must continue to be distinguished from accepted gameplay outcomes. This is especially important for Eagle abilities, health/condition effects and survival rewards.
4. **Long-session robustness:** There are multiple independently scheduled heartbeat modules. Profiling their actual runtime cost, reviewing lifecycle connections, repeated respawn behavior, and testing on live animal types remain worthwhile.
5. **Recovery effectiveness:** Baseline/manual/auto status rates need comparable real-game samples before an actual 4× claim can be made. If the game requires genuine server-owned stationary Rest, a hidden moving Rest request may not receive it.

**Release principle:** Preserve known working game interactions, prioritize actual player actions, test the compiled embedded bundle, and distinguish configured client behavior from authoritative server outcomes.
