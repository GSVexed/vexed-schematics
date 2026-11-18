# Unowned Chest Trial v1.1

**Zero-owned chests only. No purchases or owned-chest opening tests.
Free spawning remains unverified.**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-chest-trial-v1.1.lua"))()
```

Spawn, select a type with **CHEST**, then click **TRY ONCE**.
After about ten seconds, **COPY RESULT** provides the short result.
**STOP** cancels remaining work; **X** stops and closes. Drag the title.
The previous chest panel is closed when this version loads.

The existing inventory guards, numeric-string support and explicit
server-reply/live-cache provenance are retained from v1.0.1. A positive
selected-chest count prevents a request. The cache can be stale and does
not independently guarantee server-side ownership. Missing coin readings
cannot produce an unchanged-balance conclusion.

New evidence includes the native FallingChest dispatch, whether its existing
game callback reports being present, whether a selected entity can be
resolved, and fixed classes of incoming server Notify/Toast messages.
Raw messages, positions, entity IDs and other players' information are not
exported. Nearby signals and notices are correlations, not definitive
acknowledgments of this request.

The observer preserves the existing native callback and its arguments,
results and error behavior. It never calls FallingChest.listen, which would
replace the game's sole callback. Its temporary dispatch wrapper is restored
after the trial, including cancellation/failure paths. The new request is
blocked when the native observer cannot be installed.

There is one ChestDrop request per panel. The three-request total and
30-second interval from v1.0 are inherited, not reset. A type previously
tried without native observation can receive one instrumented recheck;
reloading v1.1 does not allow another instrumented attempt of the same type.
These are self-imposed bounds, not a guaranteed server-accepted rate.

The optional workspace result is `BOOGA_CHEST_TRIAL_v1_1_RESULT.json.txt`.
It does not upload automatically. Clipboard helpers are optional and a
selectable text fallback is included. No credentials, source bodies,
arbitrary attributes or raw API exceptions are retained.

Official Luau 0.747 compilation and 45 offline checks passed: the 30 retained
workflow cases plus 15 native-forwarding, restoration, notice-classification
and interpretation cases. **v1.1 has not been tested in Roblox/Velocity by
the developer.** The user's previous v1.0.1 unowned Resource Chest attempt
submitted a request but produced no observed chest.

The [lifecycle review](BOOGA-CHEST-LIFECYCLE-v1.md) records the source anchors,
24 archived physical chests, native dispatch behavior and remaining gaps.

```sh
LUAU=/path/to/luau python booga-reborn/test-booga-chest-trial-v1.1.py
```
