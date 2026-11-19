# FERAL NOVA PRIME v27 — Surface-Only Water Takeoff and Private Diagnostics

**PlaceId:** `108901361810209` (FERAL Animal Survival)

## Launch

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v27.0.lua"))()
```

The standalone bundles **17 Luau modules**. All v15 core modules except Flight and UI remain identical. The Flight module was intentionally upgraded to solve underwater flying. v25 Eagle experimental mechanics remains unchanged and OFF by default; v27 has its own UI and private diagnostic recorder. The v15 and v26 releases are preserved for rollback.

## What was wrong with underwater flying

The original v15 water flight module changed `FlightConfig.WATER.NO_TAKEOFF=false` and `WATER.GRACE=0` globally whenever WATER FLY was enabled. The FERAL FlightController applies `NO_TAKEOFF` to the swimming restriction, so this could allow takeoff under the surface.

The client snapshot (FlightConfig `S0000093`, WolfController `S0003620`, FeralFlight `S0003692`) shows:

- `FlightConfig.WATER.NO_TAKEOFF=true`, `GRACE=1.2` originally.
- Native water level is found by terrain-water raycasting from above and comparing the surface to the character's `HumanoidRootPart` and `HipHeight`.
- Native flight can accept `FeralFlyRequest` as a local request to take off.
- While flying, the native controller consumes **`FeralFlyDrop`**, ends its own flight hold, and clears its local flying state.

## v27 water behavior

The **SURFACE FLY** control preserves takeoff when your bird is *floating at the water surface*. It deliberately does **not** unlock flight everywhere in water:

1. Use the game's terrain-water raycast approach to locate the surface dynamically.
2. Require the local swimming state and that the root is near the water surface. Treat `FeralUnderwater` and `FeralDiving` as disqualifying signals.
3. Only on a valid JumpRequest temporarily set `WATER.NO_TAKEOFF=false` and submit the native `FeralFlyRequest` attribute.
4. Restore the original `WATER.NO_TAKEOFF` after flight begins, the takeoff window expires, the character changes, or the feature shuts down. Never change `WATER.GRACE`.
5. If the bird is detected submerged while still flying, set `FeralFlyDrop=true` to ask the game's own flight controller to release. Release any owned local air-carry clamp configuration.
6. Keep normal flying, flight with carried prey, recovery hand-offs, baby carrying and stamina features separate.

**Limit:** The hub requests the native flight exit when it detects submersion. The official client/server's subsequent movement is not proven from offline testing. Surface raycasting may fail in locations without confirmed Terrain Water; then the hub conservatively blocks its supplemental water takeoff rather than risking underwater flight.

## Feature preservation

The release continues to include:
- Endurance with the original `WolfDbgNoStamina` and cached sprint/jump tuning.
- Native guarded recovery and 2× health / 4× negative-effect configuration.
- Automatic hostile grab escape and friendly baby-carry exceptions.
- Q Quick Climb; ESP outlines, labels, and distance; Clear View; Agility.
- Air-carry coordination, nonphysical Reach, combat observations and flight.
- Optional experimental local Growth, Eagle Talon carry and cooldown inputs (server effects unverified).

## Automatic diagnostics and private Windows collector

v27 records own-character HP, stamina, growth, effects, flight state, takeoff and native drop requests, and relative depth (not geographic coordinates). File `FERAL_NOVA_v27_session.json` saves through Velocity's `writefile` API approximately every 25 seconds when available.

The private GitHub self-hosted Windows collector workflow at:

`GSVexed/chatgpt-minecraft-testlab/.github/workflows/feral-v26-private-diagnostics-collector.yml`

reads only either `FERAL_NOVA_v27_session.json` or `FERAL_NOVA_v26_session.json`, validates their respective schemas and uploads a validated copy as `diagnostics/feral-nova/latest.json` in the **private** repository. It runs on workflow changes and on an approximately 15-minute cron schedule (GitHub schedules may be delayed). **It does not post reports automatically into a ChatGPT conversation or guarantee proactive response without an ongoing agent/automation.** A follow-up chat can fetch and analyse the private report through the connected GitHub plugin.

No account credentials are stored in Velocity scripts. No gameplay values are transmitted to the public `vexed-schematics` repository. The collector runs on an authorized Windows self-hosted runner.

## Validation

The v27 GitHub Actions workflow `.github/workflows/feral-nova-prime-v27-validate.yml` checks:
1. Official Luau 0.747 compilation of all 17 sources and standalone.
2. Preservation of the 13 original v15 core modules not intentionally upgraded.
3. Exact embedded modules matching their standalone files.
4. Endurance, recovery, ESP, UI, report/cleanup and private report schema checks.
5. Mocked Luau diagnostic autosave/copy/cleanup.
6. Mocked Luau **floating takeoff, water override restoration, submerged takeoff blocking, and native flight drop request**.

These are offline tests; the user's live FERAL water interactions and server acceptance must still be observed.

## Important interpretation from first automatic private report

The previously recorded `FeralLungeCdTotal` changed between **1.5** and **59.999** seconds while local experimental Talon settings were enabled. This suggests some cooldown values may still come from the game's authoritative logic. The report did not record a `FeralLungeReadyAt` deadline, so no accepted server cooldown reduction is established.

The new water telemetry will help determine whether any residual underwater flight is due to takeoff eligibility, lingering native flight state, or a different controller.
