# FERAL Recovery Hub v1.2

One **3X STAMINA REGEN** switch now applies both the recovery rate and the
shared-pool recovery path together. It covers standing, walking, Trot,
sprinting, Burst and climbing, with the same path available during the other
shared-pool movement states. There is no separate 1x movement setting.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-recovery-hub-v1.2.lua"))()
```

Run the loader in Velocity, spawn, and enable **3X STAMINA REGEN**. The button
shows **CHECKING**, then **BINDING**, then **ON** after matching the native
stamina pool. If the bar is full and unchanged, run briefly to provide the
four changing readings used by the matcher. Once matched, changing movement
modes does not require another switch. The mode stays armed across respawns,
matching each new character automatically. Both feature switches start OFF.

| Control | Behavior |
|---|---|
| **3X STAMINA REGEN** | Applies three times the original base recovery rate and adds it when the native pool stays flat or drains. Ordinary positive native recovery is not added twice. Includes climbing, which v1.1 explicitly paused. |
| **RECOVERY ASSIST** | Keeps the earlier normal Rest request and local pose mask for missing HP or active conditions. Captures support about 2x HP recovery outside combat and faster bleed/venom clearance. |
| **TURN EVERYTHING OFF** | Stops both features, releases the owned Rest request and restores owned config fields. |
| **− / +** | Minimizes/reopens the menu without stopping enabled features. |
| **X** | Stops features, restores owned settings and closes. Drag the title to move the menu. |

No diagnostic files or uploads are involved. The new switch replaces the
previous independent **REST-RATE STAMINA** and **MOVING STAMINA REGEN** buttons.
The loader shuts down the earlier hub before opening this one.

## What 3x means

The original exported base recovery is `1.31` stamina per second. This mode
sets it to `1.31 × 3 = 3.93`, before the normal low-hunger/thirst penalty.
It sets the extra native rest multiplier to `1`, so actual rest does not
multiply that rate again to 9x. The original values are restored on stop.

**Normal movement and ability costs still run.** Recovery is added alongside
those costs. The result is recovery minus cost; a cost greater than the
effective recovery can still lower stamina. A low-needs penalty also lowers
the resulting recovery. Three times the recovery rate does not mean three
times the net bar increase, zero stamina cost, or guaranteed unlimited Burst.

For illustration, the exported default ground settings give a sprint cost
of `0.94 × 0.9 = 0.846` and a Burst cost of
`0.94 × 0.9 × 3.9 = 3.2994` stamina per second, before animal/condition
modifiers. With 3.93 recovery, those examples have positive net rates.
These examples are not measurements of the user's current animal or evidence
that hidden server activity checks accept sustained use.

## Movement behavior

| Native behavior | Added recovery |
|---|---|
| Walking/standing already regenerates | Uses the patched 3x native rate; adds no duplicate gain. |
| Trot or a native recovery-delay interval holds the pool flat | Adds the 3x rate to the matched internal pool. |
| Sprint/Burst/climbing/flight/swimming drains the same pool | Adds the 3x rate after the native cost. |
| Venom or a held/burrow state affects the matched pool | Does not turn off this requested recovery path; condition amounts and native costs are unchanged. |
| Menu, downed state or death | Pauses extra increments; does not revive or erase downed state. |

Climbing uses the same shared pool in the recovered WolfController, including
the `climbStamina` path around lines 5482–5600 of `S0003620`. `flyStamina`
around lines 5602–5743 and the main movement loop around lines 5920 and
7234–7334 also use that pool. This version removes v1.1's special-mode
exclusions instead of requiring another per-mode toggle.

The mode does not force the full native rest state or change the combat
switch. It does not change oxygen, hunger, thirst, venom amounts, HP or
movement/jump/Burst cost settings. It does not establish combat HP healing,
invulnerability or protection from drowning.

## Matching, stopping and limits

The matcher still targets only the current Humanoid's native StateChanged
callback. It requires the exact local WolfController, expected constants,
the actual loaded NeedsConfig table, a current-character reference, and one
numeric pool matching four changing native HUD readings. It does not search
the garbage collector or inspect other players' signals.

Required APIs are checked before enabling the feature. Missing/incompatible
APIs, failed writes, ambiguous matches, changed config, stale mismatched HUD
readings or a replaced/stopped controller stop the whole stamina feature and
restore its owned rate settings. It does not silently leave a walking-only
3x mode labelled as fully ON. The normal native callback is never disabled,
replaced or invoked by the hub.

Each write is read back. Increments use at most 0.1 seconds per frame and are
clamped below the rounded native maximum. Flat bars can resume after a long
unchanged interval when the displayed value still matches the current pool;
continued recovery requires the native HUD publisher to follow those gains.
Turning off stops future increments without rewinding already spent or
recovered stamina.

## Verification and current evidence

The user reported that v1.1's new recovery worked during sprinting with a
slight surplus. Burst still decreased stamina; the user did not establish
whether its loss was slower. Trot stayed flat, and Bear climbing still lost
stamina. Exact rates and the two old switch states were not supplied. These
observations support the live sprint path and explain the gaps addressed here;
they do not establish the new version's effects in every mode.

Official Luau 0.747 compilation, static boundaries and **48 simulated checks**
passed. They cover the combined switch, exact 3x rate, no double recovery,
flat intervals, Bear climbing with a simulated cost, other shared-pool states,
low-needs penalties, caps, matching before writes, failures restoring both
parts, respawns, cancellation, an actual v1.1 upgrade and the retained health
request lifecycle. The standalone analyzer has only expected missing
Roblox/executor global definitions.

**v1.2 has not been run in Roblox/Velocity by the developer.** The new unified
behavior and climbing/shared-mode changes remain unverified in game. The
earlier unexplained Burst death cause remains unresolved; no safe duration
or enforcement bypass is established. See [the check record](FERAL-RECOVERY-HUB-v1.2-CHECKS.json).

```sh
LUAU=/path/to/luau python roblox-tools/tests/test-feral-recovery-hub-v1.2.py
```
