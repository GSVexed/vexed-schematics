# FERAL client project

## CURRENT — Aurora FORCE v3.1 (power-first)

**[Aurora FORCE v3.1 guide](README-feral-aurora-force-v3.1.md)** · New compact
**POWER / ESP / SURVIVAL / SETTINGS** interface, explicitly replacing the
waypoint and target-focus approach the user rejected. Stronger, reversible
client controller profiles based on actual prior Bear/Tiger stamina evidence:
3× recovery, aggressive Apex no-drain/high-regeneration settings, standalone
WolfDbgNoStamina, 1.15/1.30/1.50× speed, 1.15/1.35× leap, optional ALT-held
Space escape assist, injury movement input tuning and local player ESP.
All power controls OFF by default. Apex is **HIGH RISK** owing to unresolved
sudden deaths under prolonged Burst, and *no* profile proves server acceptance.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-aurora-force-v3.1.lua"))()
```

The previous `Aurora v3.0` radar/waypoint files remain for history but are
**not the recommended launcher**. The v2.1 core and all older hubs are
preserved; no fake infinite HP/food/thirst/Amber or unsupported permanent
status grant toggles.

---

## NEWEST — Aurora v2.1 (Survival, Effects and menu-aware Player Finder)

**[Upgrade guide](README-feral-aurora-v2.1.md)** · Eleven pages: adds practical
**SURVIVAL** food/water map searches and resource compass pins, **EFFECTS**
status/control centre, menu-aware ESP with explicit search origin and
replication counts, optional own-status local autosave, compact HUD,
Survival/Explorer presets, and no false "missing animal" error when copying
a status from the animal-selection menu. It also makes clear that GitHub
does **not** automatically receive gameplay snapshots just because the
client launcher lives in the repository.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-aurora-hub-v2.1.lua"))()
```

Food/thirst and Thriving/Grazing/Amber are game-controlled: this build helps
find resources and exposes actual observed effects, but does not spoof a
full needs bar, create spendable Amber, or grant server buffs. All client
gameplay switches remain opt-in and can be reverted.

---

## NEW — Aurora Command Center v2.0

**[Aurora guide](README-feral-aurora-v2.0.md)** · A visually rebuilt nine-page client
hub with live stats, native Recovery Assist, reversible local settings,
a 74-entry searchable mechanics atlas, Amber and Thriving/Grazing/Elder
research views, destination compass and a **name tag + outline Player Finder**.
Player Finder starts OFF, caps 24 nearest currently replicated characters, and
lets you choose visible-only or opt-in through-wall displays.
All local experiments start OFF; emergency Restore All and Right Shift
hide/reopen are supported.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-aurora-hub-v2.0.lua"))()
```

**What this is NOT:** permission to change server-held Amber, damage,
Thriving, elder progress or ownership, nor a fix for prolonged Burst deaths.
The old 3× stamina engine remains separate and is NOT auto-enabled.
The source compiles; live Roblox/Velocity compatibility is not yet verified.

---

For a new Chat or a local PC task, start with [the project handoff](FERAL-HANDOFF.md).

The earlier experimental stamina menu is **[Recovery Hub v1.3](README-recovery-hub-v1.3.md)**; it remains available separately.
One **3X STAMINA REGEN** switch combines the rate and internal-pool recovery
across movement modes, including Trot and climbing. Normal movement costs
and low-needs penalties remain. The earlier health/condition assist is a
separate switch. Both start OFF. **COPY STATUS** provides an optional short
clipboard report with the last failure; no scans or files are required.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-recovery-hub-v1.3.lua"))()
```

Earlier captures support roughly 2x HP recovery outside combat and faster
bleed/venom clearance. **Combat HP regeneration and reliable unlimited Burst
remain unresolved.** The latest old-tuning death capture returned only the
native cause `other`, with no reason or code. No exact anti-cheat cause or
safe Burst duration was established. The user confirmed v1.0's 3x walking
recovery and v1.1's recovery during sprinting, with a slight surplus. Burst
still decreased, Trot stayed flat, and Bear climbing still lost stamina.
v1.2 combined the two former stamina switches and removed those mode gaps,
but the user reported repeated native-match stops. v1.3 fixes a timing flaw
reproduced with deferred callbacks in simulation, briefly rechecks mismatches
before stopping, and preserves status details for copying. The latest user-run
v1.3 status showed zero mismatches/failure stops and 8,129 client pool writes,
with nearly full stamina and full HP in the last sampled Bear Burst frame.
The user still died. The capture did not record the death transition or a
cause, so server acceptance and the death trigger remain unresolved.

Official Luau compilation and [63 simulated checks](FERAL-RECOVERY-HUB-v1.3-CHECKS.json)
passed. This new menu has not been run in Roblox/Velocity by the developer.
Amber, restricted animal spawns, code menus and additional effects remain
parked; successful server grants are not established.

## Retained research and builds

| Material | Entry point |
|---|---|
| Current timing fix, copyable status, single 3x switch and climbing | [Recovery Hub v1.3 guide](README-recovery-hub-v1.3.md) |
| Combined 3x recovery design and movement coverage | [Recovery Hub v1.2 guide](README-recovery-hub-v1.2.md) |
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
