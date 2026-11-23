# Empire Clash NOVA — research collector v1.0

This is the read-only client collection step for PROJECT EMPIRE CLASH NOVA,
not the eventual hub.

In Potassium **inside the official Empire Clash entry/menu place**, paste:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/project-empire-clash-nova/roblox-tools/empire-clash-nova-collector-v1.0.lua"))()
```

The capture starts automatically. Wait until the panel says **COMPLETE** or
**PARTIAL - SAVED** (up to about 110 seconds). Enter a normal live match/map
and paste the **same one line once more**. Tell ChatGPT when both finishes
appear; the connected private Windows runner will pick up the captures.

If the entry place immediately teleports before the panel finishes, collect
the live map first. The completion panel and saved files survive character
respawns within one place; a place transition needs the same paste again.
Use **STOP & SAVE** to preserve a partial capture if necessary.

The collector records current universe/place/version, client-visible
LocalScripts/ModuleScripts, readable object names and a bounded set of safe
attributes/values. With Potassium's getscriptbytecode available it saves
raw script bytecode for **offline** reconstruction. It does not call game
remotes, record traffic, inspect other players' characters, decompile code
inside Roblox, or upload files. It cannot access server-only scripts.

Raw bytecode is not privacy-redacted and is processed only in the separate
private research repository. Status counts are evidence of a successful
collection step, not proof that any client proposal would be accepted by
the game server.
