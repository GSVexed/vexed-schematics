# Empire Clash NOVA — Phase 8 v0.4 Reliability Overhaul

**Date:** 2026-11-23  
**Development branch:** `project-empire-clash-nova`  
**Status:** Source build and offline Luau compiler checks. **Not live-tested in Empire Clash.**  
**Silent Aim:** Experimental, manual opt-in; **server acceptance unverified.**  
**Anti-cheat:** No bypass implemented. Safety from bans **not established**.

## One-line launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/project-empire-clash-nova/roblox-tools/empire-clash-nova-phase8-combat-v0.4.lua"))()
```

This loader points to a real file on the development branch. **RightShift** toggles the NOVA panel. Experimental shot correction starts **OFF every run**, even if other preferences persist; the user may manually enable it knowing that its functionality and detection risks are unverified.

## Changes since v0.3

### 1. Less misleading target geometry
- Head / torso / adaptive-region selection uses actual, current body-part positions when determining local line of sight.
- When an optional movement-lead preview is enabled, the preview marker may show an estimated future position, but visibility is **not** checked against an unoccupied future point.
- The experimental shot-correction routine now explicitly uses **nonpredicted** body positions. We have not recovered the server's bullet speed or spread model, so a fixed 70ms lead is not evidence of accuracy.
- Target display says **LOCAL CLEAR** rather than suggesting the server has accepted a hit.

### 2. Fail-safe input and weapon rules
- A candidate correction is rejected if the local character has no living Humanoid, the Tool isn't equipped, the Tool isn't explicitly a firearm (`Melee == false`), the native UI reticle is missing or out of viewport bounds, the incoming Ray is invalid, or the selected target lacks a clear local line of sight.
- The existing FOV and maximum angle remain user configurable; the original native shot is forwarded when eligibility fails.
- Three consecutive **local calculation errors** disable the experimental callback, and the interface updates its switch. This is a reliability recovery measure, **not an anti-cheat bypass**.
- The underlying executor hook may remain as an inert wrapper after unload. Physical unhook restoration is not guaranteed on every executor.

### 3. ESP performance and lifecycle
- Lazy allocate overlay objects for in-range characters instead of all characters.
- Limit concurrent active outlines to 28 and nametags to 48, prioritising the selected enemy; remove out-of-range visuals.
- Preserve character generation invalidation on respawn, team filtering, RightShift panel control, file-based preferences where supported and manual unload.

### 4. Clearer status reporting
- Separate native request counts, **proposed** correction counts, generic hit feedback and local failure reasons.
- The mode remains labelled experimental and server-unverified.
- `silent_aim_server_verified=false` and `anti_cheat_safety_verified=false` remain explicit.
- No assertion that a forwarded modified Ray equals an accepted headshot, additional damage or a successful bypass.
- Startup output now correctly notes that experimental ray modification is present, rather than saying no ray modifications exist.

## What it actually does

If voluntarily enabled and the executor supports the required interception API, the build tries to monitor the game's native FireGun signal, choose one eligible target using the same target registry as the HUD, and replace only the direction component of a current shot's Ray. It preserves the native origin, ray magnitude and other native arguments. It **does not create extra shots**, fake damage, accelerate reloads or modify anti-cheat checks.

The game's server may ignore, reject or penalise a non-native shot direction. The available 2026-11-23 recovered **client** code does not tell us how the authoritative DamageService adjudicates such requests. A passing Luau compile test is proof of syntax only, not proof of gameplay efficacy.

## Verification performed

An official Luau compiler and static invariant checks run in the GitHub Actions workflow:
`.github/workflows/empire-clash-nova-phase8-v04-compile.yml`.
See the corresponding latest successful workflow run in GitHub Actions. This source was also checked against the recovered private Phase 7 constraints.

There has been **no** actual Roblox client run, live server accepted-hit measurement, anti-cheat bypass validation or moderation-safety test.

## Work-package disposition

| Phase 8 package | Status |
|---|---|
| Shared target registry / stability | Implemented in source, not live-verified |
| Head, torso, adaptive intent | Implemented in source, not live-verified |
| Physical obstruction checks | Implemented in source, not live-verified |
| Experimental shot-ray correction | Implemented as opt-in; **server acceptance unverified** |
| Outline-only ESP + nametags | Implemented in source, not live-verified |
| UX, persistence and cleanup | Implemented in source, not live-verified |
| Offline compiler + invariant checks | GitHub Actions |
| Proven silent aim and undetectability | **Not established** |

## No further diagnostic request

The user specifically instructed **no further in-game diagnostics**. No collector, screenshots, videos, client logs, error captures or test results are required to receive this code update. The absence of live test evidence is transparently retained as a limitation rather than used to demand repeated troubleshooting.

## Files retained

- v0.2 foundation and v0.3 experimental engine are preserved alongside this version.
- No captured third-party source code or hidden service keys were published to the public repository.
- Private Phase 6/7/8 research and progress files remain in `GSVexed/chatgpt-minecraft-testlab`.
