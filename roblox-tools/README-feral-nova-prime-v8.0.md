# FERAL NOVA PRIME v8.0 — close-range ESP, native recovery, Turtle shell

**Recommended launcher** for FERAL Animal Survival, PlaceId `108901361810209`.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-v8.0.lua"))()
```

## What is different from v7

The **same six large controls**, no scrolling, and no stamina profile picker:

| Control | Actual capability |
| --- | --- |
| **Endurance** | One opt-in cached 3× client recovery + local no-drain input. This is not server-authoritative infinite stamina. |
| **Auto Escape** | Existing native carry/shake requests plus bounded Space fallback; success depends on server/game state. |
| **Outline ESP** | Outlines without opaque fill, with screen-projected nametags that do not disappear when the camera is very close. |
| **Agility** | Single speed/leap combination, now also enables reversible local injury-movement assistance. |
| **Smart Recovery** | NEW, ON by default. Sends native Rest requests under grounded, safe conditions, monitors the real replicated Rest state and HP changes. Also watches the Turtle shell requirement. |
| **Clear View** | Reversible local brightness/fog improvements. |

The compact strip still offers TAGS, WALLS, RANGE and the opt-in HITBOX TEST. Hitbox mode stays **OFF by default** because server-side enlarged damage reach was not confirmed.

### 1. Close-range nametag fix

Old v7 BillboardGui names could clip or disappear when camera distance became very small. v8 has a separate `feral-nova-tags-v8.0.lua` ScreenGui layer. The names are projected from the replicated model's bounding-box top using the current camera, updated at a bounded rate (~15 Hz), and individually cleaned up when a player leaves or streams out. A tiny top-of-screen fallback is used for genuinely close models that project behind the camera. The original BillboardGui labels are disabled to avoid duplicates. We do not modify other players' data.

### 2. Health recovery correction

The earlier optional Aurora core `Recovery Assist` implementation forcibly cleared the **local WolfRest flag** on receiving it, despite this attribute being needed by Turtle shell protection. v8 does **not enable that old recovery system**. Its independent recovery controller NEVER writes WolfRest or WolfRestAt. It requests `WolfActions:FireServer("Rest", true)` only with an actual living animal, when stationary long enough, with suitable food/water and outside the reported combat timer. Ordinary species need a health deficit; a Turtle can try resting for shell defense even at full HP. Native rest requests are throttled (~5.5 seconds) and stopped when the user disables the feature, the animal changes, or the hub closes.

The UI distinguishes REST REQUESTED from REST REPLICATED. HP samples measure increases only at unchanged MaxHealth; **this does not prove the requests caused healing**. Non-Turtle moving characters have previously initiated own Rest requests released when they move. If the server rejects Rest, the UI reports it as unconfirmed rather than calling it working health regeneration.

### 3. Turtle damage reduction: direct archived source finding

Recovered **`S0000456` / CombatConfig (18 November capture)** explicitly defines:

```lua
SHELL = {SnappingTurtle = {TAKEN = 0.3, AFTER = 1}}
```

Its `shellMult(character)` checks the target species, `WolfRest == true`, and, when `WolfRestAt` is provided, at least **one second** elapsed using `workspace:GetServerTimeNow()`. Only then does its client function return `0.30` (a nominal **70% damage reduction**).

This is the recovered **client's rule**, not a discovered private server rule. The game may have additional restrictions or changed code.

#### Can it remain active while moving?

**Unproven.** v8 automatically tries to keep the Turtle resting when stationary. While moving, it makes **one bounded native Rest compatibility probe per Turtle life**, not a continuous request loop. It then reads back whether the Rest state and one-second age are still present. A status such as SHELL CONDITION MET WHILE MOVING is **evidence of replicated state**, not direct measurement of server damage reduction. MOVING / SHELL NOT CONFIRMED means no such result can be claimed. A server that ends Rest on movement cannot be overridden merely by changing a local attribute.

The controller never fakes `WolfRest`, `WolfRestAt` or `Humanoid.Health` and does not claim permanent invulnerability.

### 4. Hitbox issue: clearer verdict and reapplication fix

The previous copy report had `root_parts_expanded=0` while the session phase was WAITING FOR ANIMAL and HP/Stamina were both unavailable. That zero count only establishes **there were no currently expanded roots during the report**. It is not evidence either way about the preceding fight.

v8's `feral-nova-combat-v8.0.lua` now records current expanded roots, peak count, how many live targets were seen, why the active count is zero, and number of actual local part writes. When game replication restores a leased part to its original size, the local test re-applies the intended client size instead of silently counting a stale lease. All owned changes restore on OFF/close. The lab remains bounded and **OFF by default**.

**Very important:** a locally expanded root and enlarged local bite-claim window are not authoritative server hitboxes. If controlled on/off tests do not show improvements to server-confirmed hits, the correct conclusion is that this experiment isn't an effective damage advantage—not that it should be labelled as working.

### 5. Copy Status for reproducible observations

The clipboard now includes the v6 escape report, v8 hitbox results (including peak), v8 recovery/shell verdicts and screen-tag rendering diagnostics. Visible Amber/growth changes remain passive observations, not fabricated grants.

### 6. Stability and validation

Official Luau 0.747 compilation is run for the existing engine, power and escape modules and all **four new v8 files** (combat, recovery, tags, UI) plus the launcher. Static checks verify wiring, cleanup, no fake health/Amber writes and no unauthorized combat remote requests. A separate Luau unit test checks Turtle shell's 1-second threshold and species filter; simulated tests exercise hitbox restoration and module shutdown.

These tests **do not execute inside a real Roblox session**. The connected GitHub runner cannot reach the player's Windows client or verify actual server damage. All findings from live FERAL are still subject to real in-game confirmation.

## Source and validation
- [v8 launcher](feral-nova-prime-v8.0.lua)
- [v8 interface](feral-nova-prime-ui-v8.0.lua)
- [v8 screen-tag overlay](feral-nova-tags-v8.0.lua)
- [v8 native recovery + Turtle shell](feral-nova-recovery-v8.0.lua)
- [v8 bounded hitbox experiment](feral-nova-combat-v8.0.lua)
- [v8 GitHub validation](../.github/workflows/feral-nova-prime-v8-validate.yml)
