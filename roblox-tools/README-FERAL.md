# FERAL client project

The current menu is **[Recovery Hub v1.2](README-recovery-hub-v1.2.md)**.
One **3X STAMINA REGEN** switch combines the rate and internal-pool recovery
across movement modes, including Trot and climbing. Normal movement costs
and low-needs penalties remain. The earlier health/condition assist is a
separate switch. Both start OFF. There are no diagnostic reports to upload.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-recovery-hub-v1.2.lua"))()
```

Earlier captures support roughly 2x HP recovery outside combat and faster
bleed/venom clearance. **Combat HP regeneration and reliable unlimited Burst
remain unresolved.** The latest old-tuning death capture returned only the
native cause `other`, with no reason or code. No exact anti-cheat cause or
safe Burst duration was established. The user confirmed v1.0's 3x walking
recovery and v1.1's recovery during sprinting, with a slight surplus. Burst
still decreased, Trot stayed flat, and Bear climbing still lost stamina.
v1.2 combines the two former stamina switches and removes those mode gaps.
Its new unified/climbing behavior and server acceptance remain unverified.

Official Luau compilation and [48 simulated checks](FERAL-RECOVERY-HUB-v1.2-CHECKS.json)
passed. This new menu has not been run in Roblox/Velocity by the developer.
Amber, restricted animal spawns, code menus and additional effects remain
parked; successful server grants are not established.

## Retained research and builds

| Material | Entry point |
|---|---|
| Current single 3x stamina switch, climbing and limits | [Recovery Hub v1.2 guide](README-recovery-hub-v1.2.md) |
| Earlier separate stamina controls with user-confirmed sprint recovery | [Recovery Hub v1.1 guide](README-recovery-hub-v1.1.md) |
| Earlier menu with user-confirmed 3x walking recovery | [Recovery Hub v1.0 guide](README-recovery-hub-v1.0.md) |
| Earlier HP/bleed/venom capture findings | [Health findings](FERAL-HEALTH-FINDINGS-v1.1.md) |
| Earlier native death/stamina trace tool | [Health Recovery v1.3](README-health-recovery-v1.3.md) |
| Recovered combat state and sudden-death investigation | [Combat-state audit](FERAL-COMBAT-STATE-AUDIT-v1.2.md) |
| Death-message protocol and collection limits | [Death protocol](FERAL-DEATH-PROTOCOL-v1.3.md) |
| Broader earlier menu with owner/reward/spawn trials | [Field Hub v1.4](README-field-hub-v1.4.md) |
| Broader three-goal methods and limitations | [Focused methods](FERAL-THREE-GOAL-METHODS-v1.4.md) |
| All 339 logical game exports / 221 distinct reconstructed bodies reviewed | [Whole-client-export review](FERAL-CLIENT-CODE-REVIEW-v1.3.md) |
| Per-file coverage and game/platform surface index | [File inventory](FERAL-CLIENT-FILES-v1.3.md), [surface index](FERAL-CLIENT-SURFACE-INDEX-v1.3.json) |
| Completed menu/Tiger diagnostic investigation | [Final analysis](FERAL-FINAL-ANALYSIS.md), [completion record](FERAL-COMPLETION-v3.2.json) |
| Reconstruction quality and explicit defects | [Source-quality record](FERAL-source-quality-v3.2.json) |
| Archived full read-only client/platform collector | [v3.0.3 guide](README-v3.0.3.md) |
| Offline ZIP integrity verifier | [verify-feral-export.py](verify-feral-export.py) |

The full diagnostic investigation is complete within its recorded client
scope. All supplied ZIP sets verified, including the final live Animate
supplement. Existing exports preserve both game and Roblox platform content.
Server-only code was not retrieved, and reconstruction defects remain explicit
limitations. No fresh full scan is needed for the current recovery work.

The historical local HP writer failed and remains retired. Read-only
diagnostics are separate from the functional menus that intentionally use
the ordinary Rest request or change cached client settings.
