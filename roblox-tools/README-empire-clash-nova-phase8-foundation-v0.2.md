# Empire Clash NOVA — Phase 8 Combat Engine Foundation v0.2.0

**Commit:** `8a70b1d1db9a90957169c4472bdec96c0db07098`  
**State:** Phase 8A/B initial implementation, **not live-game tested** and **not yet the requested working Silent Aim**.  
**Source:** `roblox-tools/empire-clash-nova-phase8-foundation-v0.2.lua` on development branch `project-empire-clash-nova`.

## One-line launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/project-empire-clash-nova/roblox-tools/empire-clash-nova-phase8-foundation-v0.2.lua"))()
```

The raw URL above is a real GitHub project-branch path; the loader is not tested from inside the Roblox client. The repository's research and recovered third-party client code remain private.

## Delivered in this first Phase 8 increment

1. **Lifecycle-aware target registry:** listens for players joining/leaving and character respawns; invalidates a selected target when its character generation changes. Tracks R6 head/torso parts, health, position, and locally estimated smoothed velocity.
2. **One shared target selector:** screen-space distance from the captured/native *approximate* firearm reticle, configurable FOV and world range, team filtering and optional obstruction rejection. Retains the current target under moderate competition to reduce flickering.
3. **Silent Aim intent preview only:** head/torso/adaptive region mode, target aim-point marker and optional visual movement lead; **does not modify the firearm ray, send remote calls, guarantee hit registration or claim server acceptance**.
4. **Weapon-awareness foundation:** detects equipped Tool and displays its current local raw Accuracy stat when available. No fabricated server spread override or assumed exact weapon damage values.
5. **Cohesive visualization:** outline-only chams (transparent fill), nametags with distance, optional through-wall visual rendering, ring around the approximated native reticle, selected-target card with HP, region and CLEAR PATH / BLOCKED status.
6. **Performance:** target scan at around 10 Hz, visual object refresh at around 4 Hz, lightweight render-frame marker positioning; conservative highlight budget; no world descendant scans.
7. **Interface:** draggable control centre, RightShift show/hide, individual settings, optional file persistence, optional queue-on-teleport, clean unload and re-run.
8. **Diagnostics:** COP[Y] DIAGNOSTICS button produces a JSON summary (without player names or IDs), including version, scene IDs, weapon data, selected aim region, path state, FPS and explicit `client_ray_modified=false` / `silent_aim_server_verified=false`.

## What's next, not yet delivered

- **P8.2:** compare native reticle position and displayed aim marker on real gameplay resolutions; distinguish desktop and mobile input branches, confirm accurate screen-to-ray projection.
- **P8.3:** obtain authorised, controlled test results identifying whether any shot correction could be recognised by the server; never treat a local hitmarker as proof.
- **P8.4:** **only if P8.3 passes**, develop and integrate active silent aim into the same shared target system, with trustworthy evidence of intended target health changes. If server validation rejects it, mark blocked rather than mislabel visual targeting as silent aim.
- Expand weapon-specific profiles and validate headshot effectiveness. Current server headshot maths and detection rules remain unknown.
- Improve reliability after an actual Roblox session test; the present implementation has only been statically checked for paired delimiters/strings and basic source characteristics. It has **not been compiled with Luau** or runtime smoke-tested in Roblox.

## Specific in-game test checklist

1. **Load and panel:** Join Empire Clash and run the launcher. The panel should display `PHASE 8 • COMBAT ENGINE FOUNDATION`. RightShift hides/shows it; dragging the title area moves it. Controls should remain clickable.
2. **Overlay:** Point towards a living player. Their outline should have no fill; a nametag should follow. Selected enemies gain the separate golden accent and target card. Check same-team filtering with at least one teammate.
3. **Region:** Switch between ADAPTIVE / HEAD / TORSO. Verify intended marker moves to the corresponding region, and head obstruction may trigger the ADAPTIVE torso fallback. The marker is a preview only.
4. **FOV/range:** Select targets near and outside the radius, check stable target lock while strafing, and ensure distant players are excluded.
5. **Obstruction:** Test `Require clear sight`. A target behind a wall should be rejected if ON; with OFF, it may still be *visually selected*, but no wall penetration is implied.
6. **Reticle:** Aim a firearm and compare the green reticle marker with the visible game reticle, including after resolution/UI-scale changes. The native expression used has an unverified input-mode branch and a 1% viewport Y offset.
7. **Prediction:** Test marker movement with preview lead enabled; it is experimental visual prediction, not proof of accurate bullet ballistics.
8. **State changes:** Die/respawn, leave/rejoin the match, swap weapons, see if old highlights clean up and settings survive where available. The queue-on-teleport API is executor-dependent.
9. **Diagnostics:** Click `COPY DIAGNOSTICS` and paste its result back into the conversation; note whether the game actually opened the panel and whether any `latest_error` appears.
10. **Unload/restart:** Press UNLOAD, verify all generated visuals disappear, re-run the launcher, and check for no duplicate panels or markers.

**Do not use this as evidence of any anti-cheat bypass.** No such bypass or account-ban safety has been demonstrated. Avoid deploying unverified active shot modifications in public matches or on a valued main account.

## Previous prototype

`empire-clash-nova-combat-foundation-v0.1.lua` remains in the development branch for history. It is not overwritten by this new v0.2 file. v0.2 attempts to cleanly shut down either v0.1 or v0.2 when run again via the shared `ECNovaCombat` global.
