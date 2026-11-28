# FERAL Renaissance 16.4.2-rc1

Isolated build-2415 hub candidate focused on the reported failure: **sprint slows or stops when stamina runs out**. It retains the 29 feature switches, integrated Territory module and the installed desktop Hold-to-Bite helper. Floating production loaders are unchanged.

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/1aa4cc2f49b5090078e80aa68cdb809aa6ad5e94/roblox-tools/feral-renaissance-v16.4.2-rc1-loader.lua"))()
```

The loader pins the source to `85085dfc27c33f54692ea5c1628d90861a6eb016`. Its full source, loader and seven fallback chunks match the local hashes. Right Shift opens the hub. The existing Windows helper is reused; Ctrl+Alt+F12 pauses that helper.

## Stamina and movement

| Control | Behavior | Limit |
|---|---|---|
| Local Stamina Conservation | Reversible local drain and regeneration settings; ON by default for new settings. | Server fatigue and ability costs remain native. Saved OFF settings are respected. |
| Endurance Movement (experimental) | Learns the animal's healthy native sprint pace. While fatigued on land and physically holding Left Shift plus W/A/S/D, requests that pace and replays the keyboard movement direction after the game's own movement update. | The server and another player's view have not been verified. It cannot give unlimited server stamina or restore blocked abilities. |

FERAL's captured `WolfMove` path writes `Humanoid.WalkSpeed` and `Humanoid:Move()` each frame. When it sets its movement intent to zero, changing WalkSpeed alone cannot help. This candidate attempts both local inputs after that native update. It does not change stamina attributes, server remotes, position or root velocity. It yields during feeding, rest, carrying, abilities, menus, focus loss, airborne movement, swimming and climbing. A separate native sprint ban is respected unless server fatigue is reported. Sustained slow local movement or abrupt displacement causes an eight-second pause; the hub shows ARMED, PARTIAL, PAUSED or N/A. A new Humanoid or healthy gait change invalidates the old speed sample. Turning the switch off restores only a WalkSpeed value still owned by the hub.

**Live sprint continuity and peer-visible movement are unverified.** The earlier 16.4.1 attempt changed only WalkSpeed and did not solve the reported slowdown. Offline simulation can check request order, cleanup and guards; it cannot establish the game's server acceptance. The mode is restricted to audited build 2415 and will report N/A on a different build.

## Checks and rollback

The local official-Luau suite passes **239/239 cases**, including the prior combat, recovery, helper interaction and Territory regressions, plus the new zero-intent, sustained-speed, interruption and cleanup cases. The [hosted v16 run](https://github.com/GSVexed/vexed-schematics/actions/runs/46090397327) passes its client and Windows helper jobs; the [Amber](https://github.com/GSVexed/vexed-schematics/actions/runs/46090397346) and [v15](https://github.com/GSVexed/vexed-schematics/actions/runs/46090397375) validation runs also pass. See [the verification record](POLISH_VERIFICATION.json) for limits.

Previous pinned experiment:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/cf2ce27d18696db159de7f302484fb472bcb1585/roblox-tools/feral-renaissance-v16.4.1-exp1-loader.lua"))()
```

Disable **Endurance Movement (experimental)** in Movement to return immediately to native speed control. The previously installed `%LOCALAPPDATA%\FERALInputBridge\rollback.ps1` remains available for the desktop helper; this release does not change it.
