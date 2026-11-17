# FERAL Health Recovery v1.1

One health recovery switch for PlaceId `108901361810209`. This revision keeps
the useful native Rest-signal method, removes the ineffective local combat-regen
flag experiment, and handles active conditions even at full HP.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-health-recovery-v1.1.lua"))()
```

Spawn normally, click **RECOVERY ASSIST: OFF** to enable it, and play normally.
The old Field Hub or health panel is stopped and its owned settings restored
first. All new toggles start off; re-enable stamina tuning if you want it too.
No new full diagnostic is needed.

## What the supplied in-game evidence supports

The earlier v1.0 Bear capture showed about 1.02 HP/s before Rest requests and
2.02–2.05 HP/s after enabling them, while sprinting/bursting. A later interval
with the local combat-regen flag off again showed about 2% maximum HP/s outside
combat. The request uses the game's normal 2x rest-recovery bonus without
writing HP. This is observational support, not invulnerability or a guarantee
for every species, update or condition.

The same cumulative capture contains a useful combat-condition comparison:
bleed amount fell **6 → 2 → attribute absent** with recovery requests active,
and **3 → 2 → 1 → attribute absent** after requests stopped. Both happened
during combat. This matches the reconstructed status configuration's 4x
rest-clotting multiplier, though the comparison is short and not randomized.

A subsequent **v1.1 Bear capture** supplies direct condition observations:
venom dropped by one point on a tick before recovery was enabled, then by
four points on 18 subsequent ticks with recovery active, all during combat.
Five venom-attribute removals and six bleed-attribute removals were recorded.
Sixty selected regular, unchanged-MaxHealth recovery intervals outside combat
had a median rate of about 2% maximum HP/s.

**Combat HP regeneration remains unresolved.** Continuing the requests did not
produce demonstrated combat healing. Injury recovery and condition-only
activation at full HP still lack an in-game example. Faster venom clearance
now has repeated live observational support; it is not venom immunity.

See [the evidence and remaining paths](FERAL-HEALTH-FINDINGS-v1.1.md).

## Controls

| Control | Effect |
|---|---|
| Recovery Assist | Stay armed across respawns; request native recovery for missing HP or positive bleed, injury or venom |
| Stamina tuning | Optional earlier cached stamina tuning, independent of recovery |
| Stop & Save | Stop recovery, release the local pose mask, request Rest=false for the owned current-character signal, and save |
| Save Health Report .JSON | Save a new small report revision |
| Copy Report Filename | Copy the last successfully written filename |
| `-` / `+` | Collapse/expand while keeping enabled features active |
| `X` | Stop recovery and stamina, restore owned settings, save, close |

Drag the title to move the panel. Scroll inside it for lower controls.

Recovery requests are limited to one true packet per five seconds. Combat and
ordinary movement do not pause the attempt. At full HP with no positive
condition, it waits without sending true packets; death, downing and the menu
also put it on standby. It resumes when a living spawned animal needs recovery.
There is no extra condition-grant request: the native Rest signal is reused.

The tool masks **only your own local `WolfRest` attribute** before the recovered
native animation callback runs. Visual pose suppression still needs your
confirmation; server/other-client appearance and attack acceptance are unknown.
Avoid starting native Rest/R during this mode, since the native controller's
private rest variables are not changed. An animal already resting is left alone
until you stand it up normally. Downed/death state and input bindings are untouched.

The status readout displays `--` for an absent/unavailable condition value.
Condition changes are observed directly through own-character attribute signals.
Reports distinguish numeric decreases from an attribute being removed; removal
is not exported as a measured numeric zero.

## Saving and verification

Click **Save Health Report .JSON**, then copy the filename and find it in
Velocity's workspace. Upload the `.json.txt` file directly; a ZIP is unnecessary.
Files begin `FERAL_Health_Report_v1_1_...`. Automatic checkpoints are attempted
every 30 seconds. The status distinguishes successful writes from exact
readback verification. Closing queues a final save if another write is running.
File access is optional and never blocks startup.

Reports contain only own HP/MaxHealth, needs, conditions, movement mode,
experiment events and sanitized errors. No other-player data, identity,
credentials, chat, purchases or source dumps are collected. The first 6,000
events are preserved; later omissions are explicitly counted and displayed.

Official Luau compilation, static checks and **37 simulated cases** pass.
These cover condition-only activation, independent logging, removal semantics,
invalid values, no HP/condition writes, respawns, stopping, file faults, and
actual v1.0/v1.4 cleanup, plus the earlier recovery lifecycle checks.
See [the check record](FERAL-HEALTH-RECOVERY-v1.1-CHECKS.json) and
[reproducible test](tests/test-feral-health-recovery-v1.1.py).

**v1.1 now has a user-supplied Roblox/Velocity capture:** 471 events over about
169.5 seconds, with zero reported errors and zero omitted events. Recovery
requests, direct condition logging, venom clearance, full-recovery standby,
subsequent resumption and menu cleanup operated within that recorded scope.
No injury or full-HP-with-active-condition case occurred.

Two snapshots around one incoming Rest echo briefly observed local WolfRest
true while masking was enabled; subsequent observations returned false. A
false attribute is not proof of a visually normal pose. Three native bite
markers occurred while the signal was active, establishing local attempts,
not server-accepted hits. Rendered pose, attack acceptance and combat HP
recovery remain unverified. No additional source change is required for this
documentation update.
