# Empire Clash NOVA — Combat Foundation v0.1

**Status:** First implementation created on 23 November 2026. Source archive and technical research remain private. This release is an unverified client-side visual assistant, **not a silent-aim exploit** and **not proven safe from game moderation/anti-cheat**.

## Recovered research

- Universe `3569141441`; entry `9588998913`; captured Runespire `15211108051`.
- 1,050 bytecode exports, 724 distinct hashes reconstructed. Third-party code is retained only in the private analysis repository.
- `WeaponController` uses hold-to-aim/release-to-fire. Native firing ray originates at `Reticle.Main.Position` in scale coordinates, with an extra `+0.01` of viewport height on Y, via `ViewportPointToRay`.
- The native client sends `DamageService.FireGun:Fire(weapon, Ray, ...)`, but server hit validation, aim-cone checks and anti-cheat rules remain unknown.
- `FirearmAccuracy.Get` reads an accuracy stat, skills and regiment bonuses.
- Cannon controller has native range/aim-helper state and projectile predictor; no separately validated ballistic solver has yet been integrated.

## Implemented

- Dedicated independent Empire Clash GUI; Right Shift toggles the panel.
- Outline-only chams for player characters, friend/enemy distinctions, selected-target accent.
- Nametags with distance and selected-target emphasis.
- Selection inside adjustable pixel FOV and maximum distance; hysteresis to reduce flicker.
- Actual game reticle-origin point (when the Reticle UI is available), target aim marker and adjustable FOV circle.
- Target card showing display name, health, studs away and aligned / pixel offset / blocked state.
- Local cannon-seated status and native range multiplier display.
- Visual settings saved via executor file APIs if available; optional auto-reinject on map teleports if executor supports `queue_on_teleport`.
- Shutdown/re-execution cleanup. Game-universe gate.

## Deliberately not implemented

- Silent aim, fire-ray rewriting, hitbox enlargement, server-damage modifications, auto-block/reload, camera snapping, and anti-cheat manipulation.
- Cannon trajectory solution, obstruction prediction and confirmed hit association; these need additional implementation and controlled validation.
- Any claim that an executor hub is undetectable.

## Test checklist

1. Start in Empire Clash Runespire with one or more players visible. Run the script and use Right Shift to show/hide panel.
2. Check that outlines show no interior fill, nametags follow respawns, and friendlies are not selected with filtering on.
3. Hold a firearm in native aiming mode and compare the green firing-point dot against the actual crosshair. The captured native client uses a 1% Y offset; live changes could alter this.
4. Move across FOV boundaries; target selection should remain reasonably stable and release on death/leave.
5. Verify alignment and BLOCKED labels in the open and behind obstacles. These are local estimates, **not guaranteed server hits**.
6. Sit in a cannon to confirm status/range. Impact prediction is not included yet.
7. Test manual unload, respawn and re-execution. Check for duplicate highlights or panels.
8. If available, move from lobby into a match and verify reload/persistence. Queue-on-teleport support varies by executor.

## Open questions / priorities

1. Is the reconstructed Y-offset still identical in the latest live game deployment?
2. How does `FireGun` validate a shot on the server, and does the game independently compare camera/weapon origins? The private capture cannot answer this.
3. Does target-aligned native UI compensate for the player's reported misses? Is spread the larger remaining factor?
4. Upgrade cannon module with native predictor observation and target association without modifying live cannon state.
5. Implement target-specific confirmed hits only if native responses actually include target identity.

**Source:** `roblox-tools/empire-clash-nova-combat-foundation-v0.1.lua` on public branch `project-empire-clash-nova` of `GSVexed/vexed-schematics`. Never publish reconstructed third-party code to this public repository.
