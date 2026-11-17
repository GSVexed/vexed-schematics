# FERAL Recovery + Combat Trace v1.2

**A combat-off bypass has not been established.** This update keeps the
existing recovery assist and adds a passive trace of your own native hit
feedback, combat timer and protection indicators. It helps distinguish local
attack attempts, game-reported damage, safety blocks and combat-tag refreshes.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-health-recovery-v1.2.lua"))()
```

Load it while normally spawned. The previous health/Field Hub panel is stopped
and its owned settings restored first. The combat trace starts automatically;
enable **RECOVERY ASSIST** and **STAMINA TUNING** separately if wanted.
Use normal gameplay, then click **SAVE HEALTH REPORT .JSON** and upload the
small `.json.txt` file from Velocity's workspace. Files begin
`FERAL_Health_Report_v1_2_...`. No full diagnostic or ZIP is needed.

## What changed

- The panel shows the observed combat timer and counts of your outgoing hit
  reports, positive-damage reports and safety-blocked reports.
- Native FeralHit traffic is filtered to your own current character. Only the
  direction, numeric reported damage, safety flag and broad player/NPC class
  are saved. No other actors' names, IDs, HP, positions or raw packets are saved.
- Positive outgoing reports get a followup timer observation after at least
  one second, so an event arriving before the timer update is not prematurely
  labelled untagged. NPC hits and missing tags are never labelled a bypass.
- Your own FeralSafeUntil, ForceField presence and tutorial-flag presence are
  observed without modification. The local combat timer is also never edited.

The source review found no identified combat-clear request. CombatNope is a
menu-denial notice, SAFE_WORD is popup presentation, AFK requests a server
transfer, and new-player testing is owner-gated. See the detailed
[combat-state audit](FERAL-COMBAT-STATE-AUDIT-v1.2.md).

## Recovery and controls

The existing recovery behaviour is retained: one Rest=true request at most
every five seconds while HP is missing or bleed/injury/venom is positive.
It stays armed across respawns, waits when no recovery need exists, and
attempts to suppress your local rest pose. Prior Bear captures support about
2% maximum HP/s outside combat and faster bleed/venom clearance during combat.
Combat HP regeneration, injury benefit, full-HP condition-only activation,
rendered pose and server-accepted attack damage remain unestablished.

**STOP & SAVE** stops recovery and saves; the passive trace continues.
**X** stops recovery, optional stamina tuning and all trace listeners, cancels
pending followups, saves and closes. The title is draggable; `-`/`+` collapses
the panel. Avoid starting native Rest/R while recovery masking is active.

Automatic checkpoints, exact-readback attempts and the explicit 6,000-event
budget remain. The first events are preserved, and all later event omissions
are counted. At most 32 hit followups can be pending; additional omitted
followups and cancellations are recorded separately. No file access is
required to open the panel. The standard Roblox event listener needs no new
executor API; cached stamina tuning retains its optional API checks.

## Interpreting results

Native feedback reports what the game announced about a hit. It is stronger
evidence than a local bite animation, but not an independent measurement of
another animal's authoritative HP. The observed combat deadline can lag a
packet or be modified by unrelated local code. An NPC hit without a tag,
blocked attack or one missing deadline is not evidence that effective PvP can
continue without combat state. The tool does not claim otherwise.

Official Luau compilation and **50 simulated checks** pass. The checks include
the previous recovery lifecycle and actual older-panel upgrades, plus native
packet filtering/privacy, delayed timer updates, safety blocks, NPC cases,
invalid timers, remote replacement and bounded/cancelled followups.
See [the check record](FERAL-HEALTH-RECOVERY-v1.2-CHECKS.json) and
[reproducible test](tests/test-feral-health-recovery-v1.2.py).
**v1.2 has not been run inside Roblox/Velocity by the developer.** Its new
correlation behaviour and the requested combat bypass remain unverified.
