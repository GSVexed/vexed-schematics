# Renaissance 15.8.1: Hippo gait display and Turtle shell investigation

Date: 26 November 2026. FERAL capture: v2412. Candidate is local and has not been tested in a live match. The [15.8 combat ledger](V15_8_HIPPO_COMBAT.md) covers the preceding shared and Hippo changes.

## Hippo gait display

FERAL's WolfController client script 4662, prototype 186, words 2394–2402, suppresses its native run selection while `FeralCrushAt` is active. Its gait calculation still calls `Species.scaled`, which the existing Hippo movement adapter adjusts for a requested sprint or Burst. The controller writes `HudTrot`, `HudSprint` and `HudBurst` to the player in words 4494–4543. FeralHUD script 4556, prototype 136, reads those attributes to style its gait keycaps; prototype 93 builds a `FeralHUD` ScreenGui containing a `Cluster` and named `trot`, `sprint` and `burst` keycaps. Thus native HUD state could stay on Trot when the adapter requested higher speed.

The 15.8.1 adapter shares one eligibility decision between its Hippo-only speed calculation and the game's existing three gait keycaps. During an eligible charge, a held Left Shift selects Sprint and a valid X Burst intent selects Burst. Native Burst denial, stamina exhaustion, hobbled/capture/Rest states, menu focus, missing speed configuration, charge release and disabling movement end the visual override. The selected keycap receives the native active color/opacity; the others receive the native inactive style. It restores styles that it still owns on change, respawn, HUD replacement and unload. It leaves `HudTrot`, `HudSprint`, `HudBurst`, `WolfBurst` and server requests alone. An absent or changed HUD structure leaves the game's UI intact.

This is a **client display of the speed adapter's selected tier**. The archive and local tests cannot establish accepted server displacement. If FERAL changes its HUD hierarchy, the display adapter will stop applying until its captured signature is updated.

## Turtle shell proposal

- AbilityConfigBase script 15, main prototype 30, constants 1513–1514, describes Snapping Turtle's Shell Up: Rest to tuck in and take 70% less damage.
- CombatConfig script 47, main prototype 15, words 1625–1634, defines `SHELL.SnappingTurtle = {TAKEN=0.3, AFTER=1.0}` and its `shellMult` helper.
- `shellMult` prototype 10, words 0–47, reads a character's `Species`, `WolfRest` and `WolfRestAt` to return either 1 or the configured `TAKEN` multiplier after the rest delay.
- A read-only scan of all 383 distinct captured client programs found `shellMult` and `SHELL` only in CombatConfig. The private server code and any authoritative incoming-damage consumer are absent from this capture.

Changing a local Hippo's `Species`, `WolfRest` or `WolfRestAt`, or inserting Hippo into the local `SHELL` table, cannot establish server recognition or reduced incoming damage. Roblox documents that ordinary client-side changes do not replicate as authoritative server attributes and that game-changing client requests must be validated on the server: [networking guidance](https://create.roblox.com/docs/onboarding/developers), [client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary). There is no evidence-backed Turtle disguise feature to ship. A real outcome would require live incoming-damage measurements or a validated server-side path; the present candidate makes no defense claim.

## Verification

The pinned Luau compiler/interpreter compiled 32 core files and passed **246/246** Renaissance regression scenarios, including native gait-keycap switching, denial, disable, respawn, absent/rebuilt HUD and unload restoration. The integrated Territory harness compiled 24 files and passed **263/263** scenarios against the exact 15.8.1 bundle. The protected 15.8.0 candidate and 15.7.0 stable files retain their hashes. No live Roblox executor or private server was available to verify displacement or damage.
