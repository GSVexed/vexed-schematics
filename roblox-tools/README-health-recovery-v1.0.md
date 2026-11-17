# FERAL Health Recovery v1.0

Focused health experiments for FERAL PlaceId `108901361810209`. **Working extra
health regeneration, including during combat, has not been established.** This
build separates two plausible tests instead of disguising local HP writes as healing.
It replaces the old Field Hub panel and restores its owned settings first.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-health-recovery-v1.0.lua"))()
```

## Try the simplest change first

1. Spawn as your animal and stand normally. No new diagnostic scan is needed.
2. Click **LOCAL COMBAT REGEN FLAG: OFF** to enable the first experiment.
   Leave **CONTINUOUS RECOVERY REQUEST** off for this first comparison.
3. Play normally. A period with missing HP and the panel showing `combat: true`
   is needed to measure combat healing. Full HP cannot establish success.
4. Click **SAVE HEALTH REPORT .JSON** after an informative period. Copy the
   filename, find it in Velocity's workspace, and upload that `.json.txt` file.

The first switch sets only the **already-loaded client NeedsConfig table's**
`HEALTH_NO_REGEN_IN_COMBAT` to `false`. It does not modify HP, fire gameplay
remotes, or set the server's separate configuration. Missing APIs, a frozen
table or an unexpected module prevent the change and are reported.

The recovered client configuration has `HEALTH_REGEN = 0.01`,
`HEALTH_REST_MULT = 2` and `HEALTH_NO_REGEN_IN_COMBAT = true`.
The recovered WolfController consumes the stamina tuning fields locally, but
no equivalent client HP updater or client consumer of those health constants
was found in the supplied reconstruction. That makes client-cache tuning a
testable hypothesis, not an established health solution. Server-only health
code was not recovered. Roblox's documented [client/server model](https://create.roblox.com/docs/projects/client-server)
and [replication rules](https://create.roblox.com/docs/onboarding/developers)
explain why a local flag change does not change a separate server module cache.

## Optional second experiment

**CONTINUOUS RECOVERY REQUEST** remains armed across respawns. While a living,
spawned animal has missing HP, it sends the existing `WolfActions("Rest", true)`
request at most once per five seconds. **Combat, biting and burst movement do
not pause it.** Full HP, the menu, death or downing puts it on standby; it resumes
when eligible again. This does not imply healing in those states is accepted.

Before sending, the tool installs an attribute-change listener and a render
callback at priority 199, ahead of the recovered native WolfAnim callback at
202. These keep **your own local `WolfRest` attribute false** to attempt to
prevent the unwanted rest pose. Downed/death attributes and animation tracks
are untouched. There are no input hooks, swallowed attack inputs, forced R
presses, animation replacements, damage calls or HP assignments.

The pose suppression is **local**. The server and other clients may still
treat your animal as resting. Actual healing, server attack acceptance and
pose suppression in the live engine need verification. If normal actions stop
registering, turn the request experiment off. Avoid pressing native Rest/R
during it: the native controller's private rest state is not controlled here.
The tool will not take over a character already visibly resting when enabled.

## Controls and export

| Control | Effect |
|---|---|
| Local combat regen flag | Toggle only the cached client combat-regeneration flag; no recovery request |
| Continuous recovery request | Independent, optional Rest-signal experiment including combat |
| Stamina tuning | Optional earlier five-field stamina method and own-character flag; independent of health |
| Stop health experiments | Restore the owned local health flag, send Rest=false for the current owned signal, release the mask, save a report |
| Save health report | Save a new manual revision; exact file readback is attempted when available |
| Copy report filename | Copy the last successfully written filename |
| `-` / `+` | Collapse/expand the panel without stopping the experiments |
| `X` | Stop health and stamina, restore owned settings, save, close |

Drag the title to move the panel; scroll inside it to reach lower controls.
All experiments start off. A later identifiable change made by the game or
another script to a leased config field is preserved when restoring settings.
Rerunning the loader stops the previous panel first.

Automatic checkpoints are attempted every 30 seconds when `writefile` is
available. Files begin `FERAL_Health_Report_v1_0_...`; use the latest manual
`_SAVE_...json.txt` file, or a recent `_CHECKPOINT_A/B.json.txt` if the panel
disappears. Files are plain text, so no ZIP or Windows packer is needed.
The status distinguishes written files from exact-readback-verified files.
Saving never has to succeed before the panel opens or a test starts.

The report contains self-only HP/MaxHealth, needs, injuries, movement mode,
combat flag, experiment states, request counts and sanitized errors. No other
players, account identity, credentials, chat, currency or source dumps are
included. There is a 6,000-event memory budget: the beginning is preserved,
and every subsequent omitted event is counted and displayed. Save and restart
if the log fills. It does not present that capture as complete.

HP increases must survive at least three seconds with stable MaxHealth to be
counted as retained observations. Cap growth and reversals are excluded where
detected. The separate combat counter requires combat observed throughout that
window. These are client observations: natural recovery, delayed replication,
damage and other effects can confound them. They are **not causal proof** that
either experiment provides extra or server-accepted healing. The last supplied
v1.4 capture had full HP throughout, so it did not test recovery from a deficit.

## Verification

See [the check record](FERAL-HEALTH-RECOVERY-v1.0-CHECKS.json) and
[the reproducible test](tests/test-feral-health-recovery-v1.0.py). Official Luau
compilation and 34 simulated lifecycle/fault/evidence cases pass. These include
real v1.4-to-focused-panel cleanup, independent flags, combat requests, local
mask echo handling, respawns, cancellation, growth/reversal exclusion, logging
limits, file errors and readback corruption. The simulator does not execute
the reconstructed game scripts or provide Roblox physics, networking or animation.

**No execution in Roblox/Velocity or successful new healing is claimed.**
