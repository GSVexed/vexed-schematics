# FERAL NOVA PRIME v7 — hitbox and high-value research

FERAL Roblox PlaceId: 108901361810209. Built from the user's November 2026 client archive and field reports. The game has received newer updates, and server-only handlers were not captured.

## One-line Velocity launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-v7.0.lua"))()
```

v7 preserves the v6 six-control layout (one Endurance switch, Auto Escape, ESP, Agility, Anti-Slow, Clear View). It adds just one opt-in button, **HITBOX TEST**, in the ESP quick-control row. The test is OFF by default every session.

## Hitbox source evidence

Recovered source S0003620 (WolfController) uses enemy HumanoidRootPart.Size and CombatConfig.bodyGap to calculate a bite's candidate distance. It also checks reach and cone and, after an approximately 0.27-second delay, transmits the native BiteHit claim with a timestamp and selected model. Recovered S0000041 CombatConfig gives HIT_SCALE=1.15, REACH=1.45, CONE=71 degrees, CLAIM=true, CLAIM_SLACK=1.5 and BODY_CAPSULE=true.

These are CLIENT target-selection rules, **not proof** the server trusts a larger hitbox. The server can independently validate reach, timestamps, damage and the original target geometry.

### The HITBOX TEST performs these real local edits

- On demand, locally expands X/Z of up to 28 nearby enemies' replicated HumanoidRootParts to 1.65× their starting size (absolute cap 16 studs), leaving Y unchanged.
- Only scans existing nearby characters/NPCs within 100 studs, on a bounded 0.40-second refresh. Skips your own animal and known same-pack animals.
- Locally adjusts the cached CombatConfig hit-selection window when writable: HIT_SCALE up to 1.55, REACH up to 2.1 and CONE up to 85 degrees. It **does not** modify base damage, attack cooldown, actual BiteHit traffic or server health.
- Restores previously owned changes when switched off, when targets leave range, upon death/respawn or hub close. Never deliberately fights a property changed by some other script.

The button does not guarantee hits. The game server may simply reject a client-selected target outside the real hit range. Local resizing can also have unintended rendering or physics side effects; turn it off if anything looks wrong.

### Result check

When the local WolfBiteAt attribute records a bite, the module checks the nearest eligible target ahead and watches for a replicated Humanoid.Health decrease within 1.15 seconds. It separates normal and boosted bite counts. **These are correlations, not proof of your damage**, because other attacks or status effects can lower target HP.

Compare similarly positioned bites with HITBOX TEST OFF then ON, and press **COPY STATUS**. That copies the escape, ESP, hitbox, Amber, growth and HP observations; no player names, chat, Roblox IDs or precise locations are exported. If your executor has no clipboard support, a report is written to its console.

## Findings on requested goals 20–25

| Goal | Evidence | Implementation decision |
|---|---|---|
| 20 Growth/Amber optimisation | Configured survival multiplier increases by +0.1 after eligible survival intervals to 2×, then slower to 3× after approximately 250 minutes; server payout unconfirmed | V7 records visible Amber increases/decreases and growth changes passively, no pretend extra money |
| 21 Truly unlimited stamina | Earlier Bear/Tiger locally observed near-full stamina with controller tuning; server guarantee absent. Aggressive APEX tuning was present during an unexplained 101-to-0 HP event after prolonged Burst | Retain simpler opt-in Endurance, do not add APEX or claim invulnerability |
| 22 Genuine faster healing | Moving Rest experiment sent two native requests before stopping; no verified health-regeneration improvement. Prior apparent gains often matched rising MaxHealth | V7 monitors HP increases only when MaxHealth is unchanged; no health writes |
| 23 Free Amber/duplicate rewards | Two 1,000-Amber self-gifts returned nil/unconfirmed with visible balance 7,141→7,141. Two repeat-reward attempts had no confirmed duplicate award | Do not automatically repeat failed gift/replay requests |
| 24 Restricted animal unlocks | Four Snow Leopard/Phantosuchus spawn attempts and two Snow Leopard buy attempts had no confirmed spawn/purchase/ownership | Do not invent a species-unlock control |
| 25 Invulnerability/server bypass | Local Health writer did not establish persistent healing; server handler and validation are inaccessible from client | No fake godmode or server-authoritative health override |

The November 17 v1.4 report contains 15 trials: 5 gifts, 2 reward replays, 4 spawn attempts, 2 unconfirmed purchases and 2 stopped Rest loops. No target goal achieved a confirmed server-side grant from those experiments.

## Testing/limits

The GitHub Actions workflow compiles the engine, power, v6 escape, v7 hitbox module, dashboard and launcher using official Luau. It also performs source checks and a standalone Luau lifecycle test. This verifies source syntax and cleanup, **not live Roblox or Velocity behaviour**.

GitHub Actions does not grant access to the user's Windows desktop or the game's server-only code.

Sources: [v7 launcher](feral-nova-prime-v7.0.lua), [combat module](feral-nova-combat-v7.0.lua), [v7 UI](feral-nova-prime-ui-v7.0.lua), [v7 validation](../.github/workflows/feral-nova-prime-v7-validate.yml), [earlier focused experiments](FERAL-THREE-GOAL-METHODS-v1.4.md).
