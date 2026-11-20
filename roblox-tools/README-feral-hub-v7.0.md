# FERAL HUB v7.0 — Source-guided Mobile Recovery + Eagle Target Timing

**Game:** FERAL Animal Survival, Roblox PlaceId 108901361810209.
**Scope:** Client-only experiments and own-character observations. Original server-only Health/Lunge handlers were not available from the archived client reconstruction.

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v7.0-potassium.lua"))()
```

All 19 modules are bundled offline. The one-line launcher performs a single public GitHub raw fetch. The in-game HELP self-check should report **33/33** after startup (not yet live-confirmed). Use Right Shift to toggle UI, End to close.

## Why the previous direction was wrong

The user wants the Rest **benefits** while actively moving, with Rest suppressed during **combat**, and does not want automatic normal Rest/posture. v6 introduced a fallback that deliberately enabled normal visible Rest after a lack-of-healing sample. That was inappropriate for this use case and has been removed in v7.

## Source-backed findings

- Archived `FERAL-HEALTH-FINDINGS-v1.1.md`: In actual Bear gameplay, comparable noncombat HP observations changed from roughly 1%/sec to ~2%/sec of max HP after native `WolfActions:FireServer('Rest',true)`, while the client frequently reported `WolfRest=false`. Venom had observed steps of 1 before and 4 during the active Rest-signal observation, and bleed clearance was faster in selected intervals. These are observed associations, not perfect randomized proof.
- Archived `FERAL-CLIENT-CODE-REVIEW-v1.3.md`: The reconstructed client corpus covers 339 logical scripts / 221 distinct source bodies, but the game-server Health writer was not available. The `NeedsConfig` values `HEALTH_REGEN=0.01`, `HEALTH_REST_MULT=2`, `HEALTH_NO_REGEN_IN_COMBAT=true` are exported constants. Local edits alone do not establish server healing.
- Archived `FERAL-COMBAT-STATE-AUDIT-v1.2.md`: `FeralCombatUntil` is read on the Player and compared against `workspace:GetServerTimeNow()`. The game-server combat-tag writer was not recovered. This is a useful replicated indicator to avoid recovery in combat, not a combat-bypass grant.
- Existing `feral-hub-eagle-v6.0.lua`: Eagle target freshness uses `os.clock()` but the stale-target check compared to `FeralTalonPress`, whose timestamp domain was not proven identical. This may falsely reject a valid native selected prey if clock epochs differ.
- Roblox Creator Hub confirms that normal client property changes generally do not replicate to the server and that game servers validate world state. A locally modified CARRY_RATIO does not by itself force an oversized player pickup.

## v7 actual implementation

1. `feral-hub-mobile-recovery-v7.0.lua`: The masked native Rest signal stays armed outside combat while moving, flying, climbing, feeding or holding prey. A combat-tag deadline on Player or character suspends and releases the signal. Mouse-button attack input pauses it; pinned/dragged victim states and pose-loop protections remain safeguards. It no longer deactivates simply because HP is full.
2. The prior five-second repeated Rest refresh was a source of visible pose interruptions. v7 retains the original single Rest request but allows at most two additional reassertions per activation, spaced by at least 25 seconds and only after 18 seconds without observed HP gain while wounded. It does not send made-up remote verbs or write real HP/status attributes.
3. `feral-hub-active-recovery-v7.0.lua`: Always disables legacy automatic normal Rest. `autoRealRestFallback=false`, with explicit `COMBAT_BLOCKED` mode and observable combat-blocked seconds. Normal visible Rest is never started automatically by this coordinator.
4. `feral-hub-eagle-v7.0.lua`: Uses **local monotonic observation time** to measure target freshness. Only compares the native target's optional `At` timestamp with `FeralTalonPress` when the two are plausibly in the same clock domain. Records ignored incomparable timestamps and genuinely stale selected-target rejections; does not increase attack request rate or claim server permission.
5. `feral-hub-diagnostics-v7.0.lua` and `feral-hub-ui-v7.0.lua`: Show mobile signal state, combat pauses and Eagle selection timestamps. No credentials, account IDs, other users' positions or chats are included in the diagnostic exporter.

Exactly five embedded modules differ from v6 (Native Recovery, Unified Active Recovery, Eagle, Diagnostics, UI). The other 14 are byte-for-byte preserved, including the old manually-invoked Safe Rest module (which is now **never automatically activated** by Unified Active Recovery).

## Verified regression tests

- [FERAL HUB v7 official Luau build + tests](https://github.com/GSVexed/vexed-schematics/actions/runs/44737829372): **successful**.
- The standalone and all 19 embedded modules compile with official Luau; five changed source files exactly match their bundled versions.
- Mocked client verifies a present combat deadline stops the mobile signal; expired deadline allows activity even while the own character is flying, climbing or feeding; an explicit victim state still blocks.
- Mocked Unified Active Recovery verifies it never enables visible Safe Rest after 25 eligible seconds without healing.
- Mocked Eagle test verifies mismatched native timestamp epoch no longer rejects a fresh selected target; native Hold and remote-rebind tests pass.
- Windows private collector synthetic fixture + publishing: [successful](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44738107350).

## Automatic own-character diagnostics

The in-game module writes `FERAL_HUB_STARTUP_v7.json`, `FERAL_HUB_SESSION_v7.json` and `FERAL_NOVA_v32_session.json` when executor file APIs are present. The self-hosted Windows GitHub Actions collector is scheduled approximately every five minutes, uploads a **sanitized allowlisted summary only** to `GSVexed/chatgpt-minecraft-testlab/diagnostics/feral-potassium/latest-v7.json`, and does not upload licences, raw game files or player identities.

Before the first v7 Potassium execution the collector correctly returns `NO_V7_REPORT_FOUND`. ChatGPT can read the private summary on request during a conversation; it does not actively monitor your game without being asked.

## Honest limits

- v7 has **passed automated tests, not yet been live-tested with Potassium**. The earlier live mobile Rest-signal evidence came from separate older experiments, not v7 itself.
- The native Rest signal may be ignored, cleared or rate-limited by the server; mask recurrence safeguards may stop it if the local resting pose repeatedly returns. No guarantee of permanent server-accepted 2x HP or 4x status clearing.
- `FeralCombatUntil` is replicated client state, not a direct read of private server game logic. Combat detection can lag or differ from the authoritative server's decisions.
- Eagle's timeout fix improves client reliability but cannot force the server to carry a size-restricted player.
- Potassium is third-party client-modifying software; it may violate platform rules or introduce security/account risks.

## Rollback

The previous [v6](feral-hub-v6.0-potassium.lua) is preserved for regression comparison, but its automatic visible-Rest fallback does **not** match the current user preference. For baseline non-fallback comparison use [v5](feral-hub-v5.0-potassium.lua), which preserves the older mobile Rest approach without the new strict combat clock gate.