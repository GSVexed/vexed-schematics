# FERAL Amber Autopilot 0.2 — all-animal strategic farming experiment

## Version 0.2 — movement and panel fixes

Version 0.1 could stay completely stationary: `territory` was both the live `ReplicatedStorage.FeralTerritory` instance and the per-hex read method. The method overwrote the data object, preventing the map's replicated `Hexes` from being read. The real object is now stored as `territoryInstance`, with a dedicated mocked-service regression.

Two additional movement blockers are addressed: an open Renaissance menu previously paused the planner, and distant hexes were rejected when their terrain had not streamed in. Version 0.2 continues when menus are visible and travels toward the replicated hex coordinates first, evaluating safe ground when nearby.

FERAL's custom animal controller may override `Humanoid:MoveTo`. Version 0.2 additionally uses native directional control (virtual/executor WASD where available), plus `Humanoid:Move`, releasing keys promptly on pause, death, manual input or shutdown. It remains **surface-only**, with no teleports, forced velocity, CFrame repositioning or direct gameplay remote calls. Game acceptance of movement remains unverified.

**Right Shift** follows Renaissance's panel visibility; when used standalone, it toggles Amber's own panel. **Drag the title bar** to move the panel, and use MIN for a small collapsed view. Position is retained in the current executor session. Hiding the UI does not stop the farming task. The COPY STATUS report now includes navigation input and faults.

The prior v0.1 bundle is preserved for rollback. All-species live farming, native sprint/burst and real Amber payments remain to be validated.

---

This is an **opt-in add-on** for Renaissance 15.4.3. It has its own small START/STOP panel and does **not** replace the existing hub, its controls or its saved settings. It stops any older Territory Rush v4 auto controller to prevent competing teleports, but does not call its movement functions.

## Intended gameplay

1. Spawn as **any animal** (the first intended usage is `Species="Bear"`, `Coat="Spirit Bear"`), join a pack, execute the add-on and press **START**.
2. Read only the existing `FeralTerritory.Hexes` list and its replicated `owner`, `hold`, `prog`, `by` and `neutral` attributes; derive physical claim spots from `TerritoryConfig` and `MapSpots`.
3. Prioritise urgent owned scent restoration and progressing claims; rank candidates by replicated Amber pay information *if present*, distance, nearby-player exposure, and lookahead into the next territory cluster. Missing pay data is treated uniformly and **not** invented.
4. Travel using **native Roblox PathfindingService + Humanoid:MoveTo** with segmented ground routes, raycast terrain checks, stuck/timeouts, and no `PivotTo`, underground hover, position snaps, or velocity writes.
5. When at the claim spot, wait for **replicated owner/progress/hold changes** before counting a claim or rescent. Timeout and cool down a failed destination instead of looping.
6. When thirst/hunger/health cross configurable thresholds, pause the territory objective. Move over ground to a named water source, press native E only when the game's `FeedCan` permits it, and watch for **actual attribute increases**. On low health, wait without forcing Rest.
7. For species with known carnivorous/omnivorous feeding patterns (Bear, Wolf, Tiger, etc.), select **NPC prey only** from `Workspace.FeralNPCs`. Avoid pack-owned NPCs, players and markedly stronger prey. Approach by ground, face naturally, and submit native mouse attack input within geometric range; require confirmed prey HP loss/death and normal `FeedCan` before treating the hunt as successful. Other species remain eligible for territory routes but will only feed when native food opportunities are observed; they are not forced to hunt.
8. Yield to manual movement, player proximity, the game's active abilities, flight, underwater travel, pinned states and the main hub's menu. Never claim to be invisible or undetectable. Nearby player detection is limited to replicated characters; distant players may be streamed out.
9. Show a compact status panel and a privacy-limited **COPY STATUS** button. No automatic upload, webhooks or player-name logging.

## Important limitations

- **Native sprint and burst gait activation are not yet automated.** Ground travel is pathfinding plus `Humanoid:MoveTo`. The game may choose its ordinary travel gait; the code does not spoof `WolfBurst` or send repeated `WolfActions Burst` remotes. No promise about the maximum speed or anti-cheat interpretation is made.
- Being underground, flying over a target or bypassing game movement authority is deliberately not attempted.
- Native claim eligibility depends on correct biome, pack, animal and actual zone. Claim progress must be observed, not assumed.
- NPC geometry and the native feeding prompt vary by animal. Hunting and feed results are *not* verified in live FERAL gameplay yet.
- For flying or underwater animals, the agent pauses while in flight/underwater mode rather than forcing a ground route; species-specific navigation can be developed only with reliable native evidence.
- Amber pay fields may not be replicated. Without real pay data, the planner optimises urgent scent, claim progress, proximity and route clustering, but cannot assert highest Amber per hour.
- Running unattended remains at your own risk and may violate the game's rules. The system does not guarantee it looks human or that a low-population server means nobody is nearby.

## Recommended combined launcher

This launches Renaissance only if it is not already active, then opens the Amber control panel. Amber automation stays **OFF** until START is clicked.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-amber.lua"))()
```

## Standalone Amber add-on


```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-amber-autopilot-v0.2.lua"))()
```

This remains an experimental client-side game addon, not a proven Amber-income bot. Official Luau tests exercise simulated client contracts rather than live FERAL gameplay.

## Test gate

```bash
python3 roblox-tools/feral-amber/run_tests.py --luau /path/to/luau --compiler /path/to/luau-compile
```

Published runs: see `.github/workflows/feral-amber-validate.yml`. Core tests simulate the client API but cannot validate multiplayer movement acceptance, actual NPC bite damage, game-side Amber payouts, or real prey/food availability.

## Existing hub

Use Renaissance 15.4.3 separately:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()
```
