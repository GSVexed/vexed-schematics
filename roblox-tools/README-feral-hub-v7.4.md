# FERAL HUB v7.4 — current live release (21 November 2026)

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v7.4-potassium.lua"))()
```

Use only in FERAL Animal Survival (PlaceId 108901361810209) with your own authorised Potassium instance. The 19 gameplay/UI modules are included in the downloaded bundle and there are no further internal downloads. **Right Shift** toggles the hub; **End** closes it.

### What changed

v7.4 follows v7.3, which restored the older health experiment's Rest-signal sequence: install the local WolfRest pose mask **before** firing the game's native Rest request, run the mask ahead of game animation at priority 199, and refresh that request every five seconds while injured/affected. It retains strict combat-tag checks, safe native Rest cleanup, and 15/30/60/120-second backoff on repeated visible-pose echoes.

A live v7.3 read-only check showed Active Recovery enabled but paused when a mouse attack was held without a confirmed combat tag. v7.4 **removes that false pause**: a held mouse button or focused chat box by itself no longer interrupts recovery. Verified `FeralCombatUntil` and unsafe pinned/dragged situations still release the native Rest signal. This better matches the intended "benefits outside combat, no visible Rest" behavior.

The v7.3 climbing improvement is preserved: **2.25-second Q buffer** and **one guarded native mount-tap retry**. Existing stamina profiles (including the `WolfDbgNoStamina` flag), Eagle carrying, Talon local gate, native escape, flight, growth utilities and diagnostics remain intact. No new ability to force oversized holds, bypass server Talon cooldowns, or keep Hunger/Thirst full has been established.

### Validation

- [Official Luau compile, 19-bundled-module parity, and mock recovery lifecycle PASS](https://github.com/GSVexed/vexed-schematics/actions/runs/44922122297).
- [Pinned v7.4 deployed to current Potassium session](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44922206046), exact Git blob `230bb5c9cae0cd6bfaeaa0ed0dd3024520f45c14`. This workflow initially reported no fresh data because the collector did not yet recognise version 7.4.
- Updated private collector now verifies a **fresh, READY v7.4 startup**, 19/19 modules, 35/35 self-check, zero startup errors, and read-only session samples recording `NATIVE_RECOVERY` with no automatic forced visible Rest. The latest own-character sample showed full health, so faster healing has **not** been independently demonstrated in v7.4.
- Privacy: only sanitised own-character reports are synced to the private project repository. No licence credentials, usernames, exact positions or other players' identifiers are published by this collector.

### How to judge the pending outcomes

A successful local Rest request is not proof of higher server-side HP healing. Measure HP change at constant MaxHealth during ordinary wounded, out-of-combat movement and compare with resting/normal recovery; don't intentionally endanger a valuable animal merely for a test. Likewise, only replicated physical holds and real cooldown availability count for Eagle/Talon goals. Hunger and thirst remain server-owned resources in current recovered source and are monitored read-only, not spoofed.

### Rollback

The previous [v7.3 release](feral-hub-v7.3-potassium.lua) remains available if sustained attack input with the Rest signal causes game interactions to misbehave. Do not stack both versions: close the active hub before changing. v7.4 live deployment performs guarded shutdown of the previous registered hub.
