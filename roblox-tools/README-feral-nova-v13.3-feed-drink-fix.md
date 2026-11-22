# FERAL NOVA v13.3 — Eating / drinking input reliability update

## Loader (Potassium)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v13.3-renaissance-feed-drink-fix-potassium.lua"))()
```

## Scope

This is a **targeted compatibility fix** to Project Renaissance v13.2. All 23 bundled module entries remain present. The sole revised gameplay module is `feral-nova-native-recovery-v13.3.lua`; previous v13.2 logic for Death Roll, recovery and other modules is preserved. The updated bundle is still self-contained and does not fetch game modules over HTTP.

## Why E sometimes failed

Saved FERAL v2411 WolfController source shows that:
- The native E / ButtonB feed control calls `toggleFeed` from `ContextActionService`.
- The native mobile feed HUD calls `FeralFeedTap`, also handled by `toggleFeed`.
- `toggleFeed` sets an approach intention before `WolfFeed` becomes true. Native `NeedsConfig.FEED_WALK_MAX` defaults to 4 seconds, and drinking has additional water-depth and target-proximity checks.
- Hub v13.2 automatically requested a Rest signal and only gave feeding `feedGraceSeconds=1.25` seconds after an initial E or UI tap. If the approach lasted longer than 1.25 seconds with `WolfFeed` not yet active, auto Rest could restart during the approach.

## v13.3 changes

1. Bind a **high-priority pass-through** E/ButtonB listener at priority 3000, yielding hub-owned Rest before the game's feed ContextActionService handler. This handler returns `Enum.ContextActionResult.Pass`, so it does not consume or duplicate native feed input.
2. Preempt auto Rest on a detected native HUD GuiButton press while `FeedCan` is available.
3. Keep a bounded **4.8-second approach hold** after an attempted native feed. When `WolfFeed` actually begins, clear the approach hold and fall back to the original 1.25-second feeding-settle grace. No automatic replay/toggle of feed requests occurs.
4. Reset the hold on animal change or disable, unbind the priority input listener on shutdown, and expose feed guard counters in DATA.
5. Add startup self-checks for the feed priority hook and approach state.

## Verification and limitations

- Static verified: all **23 unique embedded module entries**, new module matches separately published source, native priority actions are pass-through, and no other gameplay module bodies were changed relative to v13.2.
- An in-game feed/drink success **has not yet been measured** after this release. Server interaction eligibility, water-depth constraints, food reach, combat/clamp restrictions and Native game source can still prevent eating or drinking.
- A real, manually initiated Rest session remains player-owned; this fix never forces a manual Rest session to end.
- The feed fix will only be active if the user has enabled the native/active recovery feature. If eating/drinking fails with all recovery features off, look first at the game's own `FeedCan`, target reach and environmental limitations.
- If the new version introduces a new issue, the prior loader can be used: `feral-nova-v13.2-renaissance-death-roll-guard-potassium.lua`.

## Useful diagnostic fields

`native_E_priority_guard_bound`, `native_E_priority_preemptions`,
`native_HUD_feed_preemptions`, `native_feed_approach_remaining`,
`feed_interactions_seen`, `feed_interactions_completed`,
`last_activity_block` and `last_error`.
