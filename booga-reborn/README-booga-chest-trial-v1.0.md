# Booga Chest Trial v1.0.1

A bounded test of the normal chest-open request when a readable inventory
shows zero of the selected chest. **No free-chest method has been confirmed.**
The loader URL is unchanged by this hotfix.

The first user-run v1.0 report returned BEFORE_UNAVAILABLE in 0.1 seconds,
with no gameplay request attempted. That establishes a failed inventory
precondition, not rejection of ChestDrop. The report did not record the
RPC reply shape, so its exact runtime cause remains unknown.

v1.0.1 falls back to the native UI's already-loaded `gameUtil.Data` when
the separate RequestData refresh is unavailable or unreadable. The copied
result identifies `server_reply`, `live_game_cache`, or an unavailable source,
and includes only fixed validation reasons and field types. Numeric strings
are accepted. Missing coins no longer erase a readable inventory; a chest
observation without known balances receives an inconclusive verdict.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-chest-trial-v1.0.lua"))()
```

Spawn in Booga Booga Reborn, use the **CHEST** button to choose a type, then
click **TRY ONCE**. The default is Resource Chest. Crystal, Emerald,
Magnetite and Pleb Chests are also selectable. **COPY RESULT** supplies a
short result for the chat. **STOP** prevents further steps; an already-sent
request cannot be recalled. **X** stops and closes. Drag the title to move.

The tool tries the player's own inventory and coin count through the same
`Events.RequestData` RemoteFunction used by the recovered client initializer,
then uses the native UI's live game cache if necessary. A readable positive
cache count also blocks a zero-owned RPC reply. It sends nothing if neither
inventory is readable or the selected view shows any of that chest.
The live cache is client state and may be stale; it cannot independently
guarantee server-side ownership or a free result. The tool then sends
exactly one typed `ChestDrop.send(name)`.
It never calls the separate purchase packet or modifies inventory/balances.

For ten seconds it observes new matching models in `Workspace.dropChests`,
requiring a new numeric EntityID, positive Health value and horizontal
distance within 20 studs of the player's initial position. Existing IDs
are excluded. A second own-inventory response checks for balance changes.
Coin changes or a newly owned chest make the free-spawn inference inconclusive.
An observation timeout is not an explicit server rejection verdict.

Even a matching chest with unchanged balances is labelled **unverified**:
another nearby action could explain it, loot has not been collected, and
save persistence is not checked. Missing streaming content, changed hierarchy
or changed health representation can prevent observation of a real result.
This tool neither creates a local chest model nor intercepts network traffic.

There is one gameplay request per panel, at most three different chest types
per executor session, and a 30-second interval across reloads. Failed sends
are not automatically retried. These limits are client-side safeguards,
not a server-approved request rate or an enforcement bypass.

If `writefile` exists, a small result is saved as
`BOOGA_CHEST_TRIAL_v1_RESULT.json.txt` in the executor workspace. File output
is optional and does not upload anything. Clipboard fallbacks are supported.
No credentials, other-player data, usernames, positions, arbitrary attributes
or raw exception text are exported. Full own inventory responses are filtered
to the chosen chest count and coin balance before retention.

Evidence: original export `Game/inventory` S0010366 around 1224–1253;
client initializer S0010711 around 26; chest animation observer
`Game/worldEffects` S0010393 around 89–129. The server handler is not present.
The ordinary UI checks ownership before sending the name; purchase uses a
separate packet. This test does not invent a “check already passed” flag.

Official Luau 0.747 compilation, 30 core workflow cases and static request
boundary checks passed. The old GUI ran far enough to produce the user's
precondition-failure report. **The hotfix and actual chest request have not
been tested inside Roblox/Velocity by the developer.**

```sh
LUAU=/path/to/luau python booga-reborn/test-booga-chest-trial-v1.py
```
