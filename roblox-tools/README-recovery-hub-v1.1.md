# FERAL Recovery Hub v1.1

Adds optional stamina recovery alongside normal **ground sprint/Burst drain**.
The earlier rest-rate option remains separate. The user confirmed v1.0 made
ordinary walking recovery 3x faster, with no recovery during sprint/running;
this new mode addresses that separate drain branch.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-recovery-hub-v1.1.lua"))()
```

Run the loader in Velocity while in FERAL. It replaces the earlier hub and
restores its owned settings. All three switches start **OFF**.

1. Spawn as your animal and close the game menu.
2. Enable **MOVING STAMINA REGEN** and run briefly. It automatically waits for
   four changing native stamina readings to identify the internal pool.
3. **BINDING** becomes **ON** after that match. The status reports when recovery
   is being added. With only this control enabled, it uses the normal recovery
   rate; Burst can still have a net stamina cost.
4. Enable **REST-RATE STAMINA** as well to use the configured 3x recovery rate.
   This also keeps the walking recovery behavior confirmed in v1.0.

No scan, report file or upload is involved. If a required Velocity capability
is unavailable, or matching fails, the status explains it and the new mode
does not write stamina. It never substitutes an unrelated numeric value.

| Control | Effect |
|---|---|
| **MOVING STAMINA REGEN** | Adds the current configured recovery rate after observed native ground sprint/Burst drain. Regular movement costs still run. Walking recovery stays native. |
| **REST-RATE STAMINA** | Sets the loaded client base recovery rate to its original value times the rest multiplier (currently `1.31 × 3 = 3.93`). Avoids stacking the multiplier twice during actual rest. |
| **RECOVERY ASSIST** | Retains the normal Rest request for missing HP or active conditions, with the local rest-pose mask. Earlier captures support ~2x HP recovery outside combat and faster bleed/venom clearance. |
| **TURN EVERYTHING OFF** | Stops added recovery and Rest requests, restoring owned config changes. |
| **− / +** | Minimizes/reopens the menu; enabled controls continue. |
| **X** | Stops controls, restores owned settings and closes. Drag the title to move. |

## What changed

Changing a recovery multiplier does not make the native recovery branch run
during sprint drain. The new mode therefore reaches the **existing internal
client stamina pool** and adds bounded recovery alongside the normal cost.
It does not force the full native rest state, write the HUD stamina attribute,
change jump/sprint/Burst costs, set the no-drain flag, or replace the controller.
The additional movement recovery deliberately operates while the ordinary
recovery delay is being refreshed by sprinting; the native delay value and
timer are not changed.

Each step is effectively:

`native pool after movement cost + configured recovery × elapsed frame time`

The low-hunger/thirst recovery penalty remains in the added rate. Native
exhaustion state is untouched. Extra recovery pauses for menus, death/downed
state, swimming, flight, climbing, burrowing, grabs and venom. Those special
modes and penalties are left to the normal controller. Ordinary walking or
a pool that did not actually drain receives no extra recovery from this mode.
After a long frame, at most 0.1 seconds of recovery is added. Added recovery
is clamped below the rounded native stamina maximum.

The mode remains armed across respawns. It waits for the new character's
native callback and requires a fresh pool match. Turning it off stops future
increments; it does not rewind stamina already gained or costs already paid.

## Matching and capability checks

This mode targets only your current Humanoid's `StateChanged` connections.
It requires exposed `getconnections`, `getconstants`, `getupvalues`,
`setupvalue` and `getfenv` functions. Supported global/environment/debug-table
locations are checked; presence alone is not treated as proof of working
access. The already-loaded NeedsConfig is obtained through the same guarded
cache path as the previous hub. Missing/incompatible APIs leave the mode off.

A candidate callback must belong to the exact local PlayerScripts
`WolfController`, have the expected native jump-cost constants, capture the
exact loaded NeedsConfig table, and reference the current character/Humanoid
or root. There must be exactly one matching function. Four changing native
HUD updates, spanning at least 0.25 stamina, must then identify one numeric
upvalue. No upvalue is written before that match. A second matching numeric
cell causes the attempt to stop.

New-character callback startup can take time, so missing callbacks get a
bounded ten-second matching window with retries at most every two seconds.
An unchanged stamina bar keeps waiting for normal activity. Native updates
are checked again after binding; mismatch, API errors, no-op writes or a
replaced controller stop the mode. The native movement callback runs at
Input+1; added recovery runs immediately afterward. No native connections
are disabled or invoked by the hub.

The implementation does not enumerate the garbage collector, inspect other
players' signals, collect source, dump function values, hook functions, or
change server code. Callback/constant/upvalue matching has explicit limits.
Only the selected stamina cell is written, and each write is read back.

## Evidence and limitations

The recovered `S0003620` WolfController has a shared stamina pool around lines
5105–5142. Its native Humanoid state callback subtracts jump cost from that
pool. The main movement callback starts around line 5920 and uses the same
pool for movement drain and HUD output around lines 7234–7334. The native
private rest state and its movement cancellation are around lines 6205–6253.
These are references into the existing private reconstructed export; the
hub does not execute reconstructed game code.

**This v1.1 moving-recovery path has not yet been run in Roblox/Velocity by the
developer.** The runtime matcher may reject APIs or function layouts that
the synthetic tests cannot reproduce. The user-confirmed walking multiplier
does not validate this new path.

The pool is client-side. Seeing it recover does not establish that hidden
server-side activity/enforcement checks accept sustained running or Burst.
The prior unexplained death message reported only `other`; its exact cause,
a safe Burst duration and a bypass remain unresolved. Combat HP recovery
also remains unresolved. This build makes no currency, unlock or spawn grants.

## Verification

Official Luau 0.747 compilation, static boundary checks and **56 simulated
checks** passed: 29 previous recovery/rate cases and 27 new integration/fault
cases. The synthetic controller charges movement cost, publishes its own HUD
readings and shares a fake internal pool with the targeted callback. Tests
check net rates, no walking double-count, matching before writes, ambiguous
cells, foreign callbacks, low needs, special-mode pauses, death, API failures,
stale echoes, frame-gap limits, respawn matching, cancellation and upgrades.

These simulations do not execute the actual game or establish server
acceptance. See [the check record](FERAL-RECOVERY-HUB-v1.1-CHECKS.json).

```sh
LUAU=/path/to/luau python roblox-tools/tests/test-feral-recovery-hub-v1.1.py
```
