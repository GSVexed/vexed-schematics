# Lightning Lab v2.1 — Hold V, live-result handoff

**Place:** Roblox Booga Booga Reborn, PlaceId `11729688377`.  
**Status:** published to `main`; official Luau 0.747 compile and 24 source checks passed on [GitHub Actions](https://github.com/GSVexed/vexed-schematics/actions/runs/44276720246). No live accepted extra strikes confirmed.

## One-line Velocity launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-lightning-lab-v2.1.lua"))()
```

This is a **new v2.1 tool**, not the old `v1.0` or `v2.0` hub.

## Exact input behavior

1. Select **Energy Bolt** (Lightning) in the game first.
2. Open the hub. It starts armed; V is **not** held by the script.
3. Hold physical **V**: the selected cast engine attempts repeatedly.
4. Release **V**: all queued attempts are cancelled, immediately.
5. **F6**: emergency disarm, click green/off arm button to re-arm.
6. Typing in chat stops holding the key.
7. Close/re-run replaces earlier versions and cleans up listeners.

The game's own initial V press may create a normal first cast; additional attempts come from the hub. There is no AFK casting.

## Engine choices and modifiers

- **DIRECT SPELL PACKETS:** Uses the client game's typed `VoodooSpell.send({targetPos,aimDirection})` API.
- **REPLAY GAME UI HANDLER:** Unlike old v2.0, this now fires the game's `Game/wrappedSignals.InputBegan:Fire(V-key, false)`, which calls the legitimate `Game/spells` V handler. It is not an exploit-specific UI button click.
- **ALTERNATE BOTH METHODS:** Alternates direct and native-signal calls.
- **DOUBLE PULSE / TRIPLE PULSE:** Queue 2 or 3 sends per cycle while V remains down (bounded 24 attempts per second).
- **AIM LOCK: DAVE:** Uses the nearest replicated, living Dave's stump for aiming.
- **AOE OFFSET SWEEP:** Alternates aim offsets around that Dave.
- **AIM DIRECTION: TARGET:** Aims direction toward target instead of camera orientation.
- **VOODOO ENERGY GUARD:** Skip requests if the cached Voodoo is below displayed spell cost.
- **REGEN SMART PACE:** Slows attempts when displayed Voodoo is low. Does NOT increase actual Voodoo.
- **TIMING VARIATION:** Adds small jitter; no guarantee of bypass.
- **SUSTAINED BURST REQUEUE:** Reuses double/triple pulse controls; not an independent damage method.

## Grounding in recovered client source

- `ReplicatedStorage/Game/spells` maps V to `VoodooSpell.send`, using the second value of `functions.cursorRay()` and the camera/movement derived aim direction.
- `Game/wrappedSignals` is a Signal module proxy around `UserInputService.InputBegan`, with `:Fire(...)` and `:Connect(...)`.
- The exact outgoing packet structure matches recovered `Game/spells`.
- `Game/stats` applies `UpdateStats` and `UpdateStatsUnreliable` to replicated `Data.voodoo`.
- `Game/boosts/data` contains visible Voodoo boost names `Voodoo Passive`, `Void Armor`, `Jelly Sandwich`. They are not fabricated server grants.

These observations do **not** expose the server's spell handler or guarantee accepted extra casts. Editing local Voodoo does not grant server-authorized energy; no such edit is performed.

## Automatic in-game telemetry and PC runner

The in-game v2.1 script attempts to update a bounded JSON report every five seconds using Velocity/executor `writefile`:

`booga_lightning_v21_latest.json`

It records mode, request counts, client Voodoo, incoming update counts, projectiles and nearby Dave HP. It never records tokens, chat, or usernames. Client requests and nearby HP changes **cannot by themselves establish server acceptance or exclusive attribution to Lightning**.

The separate private repository has a [read-only PC runner collector](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/workflows/booga-lightning-results-collector.yml). It is scheduled for 15-minute intervals and can also be triggered manually. It checks a fixed set of likely Velocity workspace paths, reads **only this specifically named report**, validates v2.1, outputs a scrubbed subset of numeric/status fields and refuses files over 20 KB.

[Initial runner job](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44276491892): **success**, `NO_LOCAL_LOG_FOUND`, run before the user executed v2.1. This result only proves runner connectivity and that the chosen paths had no matching file at that time. The exact executor workspace remains unconfirmed; if no report appears after actual use, adjust path detection before promising automatic observation.

I can re-read the collector's GitHub Actions results when the user returns to chat. The runner cannot send a message to this chat without an explicit automation integration.

## Limitation and next status logic

- Official Luau compile: **pass**.
- Source-check contracts: **pass**.
- Windows runner executes collector: **pass**.
- Exact Velocity workspace/report visibility: **pending**.
- Live Lightning frequency, Voodoo accounting and damage attributable to user: **unknown**.
