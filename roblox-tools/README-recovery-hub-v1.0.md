# FERAL Recovery Hub v1.0

A functional menu for the recovery behavior already supported by the supplied
captures, plus a smaller stamina option based on the game's rest multiplier.
There is no diagnostic capture, report upload, decompilation or filesystem setup.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-recovery-hub-v1.0.lua"))()
```

Paste the line into Velocity while in FERAL. Both controls start **OFF**.
The loader cooperatively shuts down the previous Field Hub / Health Recovery
menus, restoring changes those menus still own. An existing no-drain flag that
is not released is reported rather than silently taken over; rejoining resets
the old client session in that case.

| Control | Behavior |
|---|---|
| **RECOVERY ASSIST** | Uses the ordinary Rest request while your living animal has missing HP, bleeding, injury or venom. Masks the local rest-pose flag. Remains armed across respawns; waits in menus or while dead/downed. |
| **REST-RATE STAMINA** | Applies the configured rest recovery multiplier to the already-loaded client stamina recovery field. Current exported values are `1.31 × 3 = 3.93`. Retains stamina drain, jump cost, recovery delay, low-needs penalty and normal Burst controls. |
| **TURN EVERYTHING OFF** | Stops owned Rest requests and restores owned config changes. Leaves the menu open. |
| **− / +** | Minimizes / reopens the menu. Enabled controls keep running. |
| **X** | Stops controls, restores owned changes and closes. Drag the title to move the menu. |

The stamina option is faster recovery **where the normal controller regenerates
stamina**, including recovery between bursts. It does not add stamina during a
drain-only Burst branch. Stamina still runs out during sustained Burst. It does
not contain the previous zero-drain / 250-regen tuning or set `WolfDbgNoStamina`.
There is no Burst block in this build because that old tuning has been removed.

## Why Rest is not a direct infinite-stamina solution

The exported NeedsConfig has `HEALTH_REST_MULT = 2` and
`STAMINA_REST_MULT = 3`. Recovered WolfController code uses a private local rest
boolean in stamina regeneration. Movement clears that state. Sending the Rest
remote by itself does not set that private controller boolean; clearing the
visible `WolfRest` pose flag does not set it either. The exported controller
also separates stamina drain from recovery paths. Several reconstructed
branches are incomplete, so they are evidence of the client design rather
than a complete executable copy of the game.

The new option therefore changes two fields in the already-loaded config:
`STAMINA_REST_MULT` becomes `1`, then `STAMINA_REGEN` becomes the original base
rate times the original rest multiplier. This prevents ordinary rest from
stacking the same multiplier twice (9x). Restoration reverses that order.
Unrelated later config edits are preserved. If the cache API is missing, the
module is not already loaded, or the table is not writable, the option stays
off. It does not start new game modules or force tables writable.

Source references in the existing private client export:

| Export | Evidence |
|---|---|
| `S0000033`, NeedsConfig, lines 121–135 | Health/stamina recovery settings and delays. |
| `S0003620`, WolfController, lines 214–240, 5253–5271 | Private native rest state and its own debug-rest listener. |
| `S0003620`, lines 5569–5580 | A recovered stamina recovery path multiplies by the private rest state. |
| `S0003620`, lines 6205–6253 | Movement clears native rest; controller sends normal Rest requests on state changes. |
| `S0003620`, lines 7311–7315 | Burst-related stamina drain uses drain settings separately. |

## Evidence and limits

Earlier Bear captures support approximately **2% max HP per second outside
combat**, versus a baseline near 1%, with recovery assist active. Bleeding and
venom cleared faster during combat in those captures. Injury benefit,
full-HP condition-only gameplay effects, rendered pose and accepted attacks
remain unverified. Local pose masking does not establish what the server or
other clients render. **Combat HP regeneration remains unresolved.**

The latest supplied v1.3 capture recorded HP dropping from 101 to 0 while the
old stamina tuning and Burst were active. The native death message said
`other`, with no reason or code. Client stamina read 48.7 / 50.8. The reported
60-second lifetime differed from the roughly 48.8 seconds of observed
continuous Burst. This establishes neither an exact enforcement cause nor a
safe Burst duration. The new build does not claim that those deaths have been
fixed or that faster client recovery is accepted by a hidden server budget.

This hub uses only your current character, the already-loaded NeedsConfig and
the normal `WolfActions` Rest request. It does not write HP, stamina bars,
combat flags, harmful condition amounts, currency, permissions or spawn data.
It collects no reports, other players' information or credentials. Previous
diagnostic versions remain archived; no new diagnostic uploads are requested.

## Verification

Official Luau 0.747 compilation and **29 simulated lifecycle/fault checks**
passed, including an upgrade from the actual v1.3 source, restoration,
respawns, stale callbacks, frozen/partially writable config, missing APIs,
packet throttling and pose-mask failures. Static checks restrict the only
gameplay request to normal Rest and the only attribute write to `WolfRest`.
The standalone analyzer reports only expected missing Roblox/executor globals.

**This v1.0 build has not been executed in Roblox/Velocity by the developer.**
The prior recovery captures do not validate the new stamina option in game.
See [the check record](FERAL-RECOVERY-HUB-v1.0-CHECKS.json).

To reproduce the simulated tests:

```sh
LUAU=/path/to/luau python roblox-tools/tests/test-feral-recovery-hub-v1.0.py
```
