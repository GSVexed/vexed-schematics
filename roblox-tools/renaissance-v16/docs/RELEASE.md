# FERAL Renaissance 16.4.1-exp1

This isolated build tests **Endurance Movement** for game build 2415. It retains the complete 16.4.0-rc1 hub and installed desktop Hold-to-Bite helper. It changes no floating production loader.

The source and pinned loader pass **235/235 local Luau checks** and the [hosted regression gate](https://github.com/GSVexed/vexed-schematics/actions/runs/46084891842), including six loader failure and chunk cases. The hosted helper check and retained v15/Amber baseline gates also pass. The published raw source, loader and seven fallback chunks match the local hashes. Live gameplay and the view from another client are not verified. The previous candidate passed 230 offline checks; its [verification record](verification.json) remains historical evidence, not evidence for this experiment.

## What the two stamina controls do

| Control | Behavior | Limit |
|---|---|---|
| Local Stamina Conservation | Retains the old reversible client drain and regeneration settings. | Server fatigue and ability costs can still apply; this is not infinite stamina. |
| Endurance Movement (experimental) | On audited build 2415, observes that animal's healthy native sprint speed. While Left Shift is held on the ground during fatigue, requests that speed through its own Humanoid WalkSpeed. | Local speed request only. Server acceptance and what other players see are unverified. |

The movement request pauses while feeding, resting, carrying, using an ability, in a menu, out of focus, airborne, swimming, climbing or subject to a separate native `FeralNoSprint` restriction without the server fatigue flag. When `FeralSrvTired` itself is reported, the experiment can attempt the local pace even if `FeralNoSprint` is also set. It pauses for eight seconds after a large position jump or ineffective local movement. Turning it off, unloading the hub or respawning restores a speed only if this module still owns it. The control starts on by default and has its own Movement switch.

The server's `FeralSrvTired` flag and stamina values are not changed. Build 2415 only recognizes the old no-stamina debug attribute in Studio; no genuine unlimited resource or persistent sprint acceptance has been established.

## Launcher and rollback

Pinned experimental launcher:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/cf2ce27d18696db159de7f302484fb472bcb1585/roblox-tools/feral-renaissance-v16.4.1-exp1-loader.lua"))()
```

The loader pins its source to commit `d39828746fff0fdfc709ece15b4c0097b3f35c8c`; its full fetch and seven fallback chunks reconstruct the same verified bundle. It enables desktop left-mouse Hold-to-Bite through the previously installed helper. Execute the launcher inside FERAL on build 2415. The endurance switch is in Movement and starts on for this experiment. It pauses on an unaudited game build.

Previous pinned candidate:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/60e703742efdec8950f69f9ce715f720604f35d3/roblox-tools/feral-renaissance-v16.4.0-rc1-loader.lua"))()
```

Right Shift opens the hub. Turn off **Endurance Movement (experimental)** in Movement to return to native movement immediately. The helper pause shortcut remains Ctrl+Alt+F12. The existing `%LOCALAPPDATA%\FERALInputBridge\rollback.ps1` is available if the desktop helper itself needs restoring; this build makes no helper change.

A live comparison needs another observer to confirm visible movement and actual distance while fatigue is active. An offline test, a local HUD value or a speed property reading cannot prove this behavior.
