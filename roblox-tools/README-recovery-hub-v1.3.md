# FERAL Recovery Hub v1.3

Fixes a timing flaw that can falsely stop stamina recovery with
`Native stamina no longer matches`, and adds **COPY STATUS** for a short
report you can paste into the chat. The single 3x stamina switch, climbing
support and health/condition assist are retained.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-recovery-hub-v1.3.lua"))()
```

Spawn, enable **3X STAMINA REGEN**, and move briefly if it shows **BINDING**.
Both gameplay switches start OFF. The loader closes the previous hub and
restores its owned settings before opening this version.

| Control | Behavior |
|---|---|
| **3X STAMINA REGEN** | One combined 3x recovery mode for the matched client stamina pool across movement modes, including climbing. Normal costs and needs penalties remain. |
| **COPY STATUS** | Copies the current phase, your own resource readings, recent matching samples and the last failure. Paste the text into the chat if needed. Works after stamina stops. |
| **RECOVERY ASSIST** | Retains the normal Rest request and local pose mask. Earlier captures support about 2x HP recovery outside combat and faster bleed/venom clearing. |
| **TURN EVERYTHING OFF** | Stops gameplay changes and restores owned settings. Leaves the menu and status button available. |
| **− / +** | Minimizes/reopens the menu. Enabled features continue. |
| **X** | Stops features, restores owned settings and closes. Drag the title to move the menu. |

There are no scans or report files. If `setclipboard` is unavailable or fails,
the button tries `toclipboard`. If neither works, a selectable text box appears:
click it, press **Ctrl+A**, then **Ctrl+C**. Clipboard contents are never read.

## Why the old check could stop

v1.2 compared the HUD attribute with the internal stamina pool inside the
attribute-change callback. If that callback ran after the hub added recovery,
the pool could legitimately be ahead of the earlier HUD reading by more than
the 0.051 rounding tolerance. The check then treated the hub's own gain as a
broken match and stopped the feature.

The tests reproduce this with the actual v1.2 source under deferred
attribute callbacks, 60 Hz frames and 10 Hz native HUD publication. The new
version stays enabled under the same simulated timing. This establishes a
code-level timing defect; the screenshot alone does not prove it was the only
cause in the user's Roblox session.

v1.3 samples the native HUD and pool together immediately after native
movement, **before its own recovery write**. It no longer validates stamina
inside an attribute-change callback. The original matching tolerance is
unchanged, and the initial four changing readings are still required.

An unexplained mismatch now shows **VERIFYING** and pauses extra pool writes.
Recovery resumes after either two fresh matching HUD updates or three
matching render samples spanning at least 0.1 seconds. A mismatch that does
not settle within 1.5 seconds stops the stamina feature, restores the owned
config fields and retains its failure details. The implementation does not
ignore persistent mismatches or repeatedly force-enable failed access.

## What COPY STATUS contains

The report includes the version, elapsed session time, current phase, species
from a fixed whitelist, own HP/stamina/hunger/thirst, fixed status messages,
matching/write counters and the last available numeric frame at failure.
It retains the latest **16 HUD/matching samples** and explicitly counts older
omitted samples. This is a bounded troubleshooting summary, not a complete
game diagnostic. Large numbers use short scientific notation.

The last failure survives a manual off or another attempt in the same hub
session. Closing/rerunning the hub starts a new status history. Reports do
not include usernames, positions, other players' information, arbitrary
attributes, source bodies, function values, raw API error text or credentials.
Copying status does not send gameplay requests or change gameplay settings.

## Recovery behavior and limits

The stamina mode sets the original exported base rate from `1.31` to
`3.93` stamina per second, before the normal low-needs penalty. It avoids
stacking actual rest to 9x. If the native pool is already rising, no duplicate
recovery is added. Flat/draining intervals receive the extra recovery path.
The same matched pool is used during climbing and other movement states.
Menus, downed state and death pause extra increments; the mode stays armed
across respawns and matches the new character before writing.

Movement/ability costs remain active, so the net bar change depends on cost
and conditions. It does not force the native rest state, change combat flags,
write the HUD stamina attribute, modify HP or oxygen, or establish unlimited
Burst. Combat HP recovery and the earlier unexplained Burst deaths remain
unresolved. A client mismatch report is not a server enforcement verdict.

The own-callback fingerprint, exact loaded config reference, current-character
checks, maximum/frame-time limits and per-write readback remain. Changed
config, invalid pool values, unavailable APIs or a stopped/replaced native
controller can still stop the feature. See the [v1.2 guide](README-recovery-hub-v1.2.md)
for the underlying recovery design.

## Verification

Official Luau 0.747 compilation and **63 simulated checks** passed: 47 retained
health/stamina regressions and 16 timing/status checks. Coverage includes the
actual old-code false-stop reproduction, deferred timing during sprint and
climbing, transient/persistent mismatches, safe pause/resume, restored config,
clipboard API failures, selectable fallback, bounded history, privacy filtering
and an upgrade from the actual v1.2 source.

**This version has not been run in Roblox/Velocity by the developer.** The
user's screenshot confirms the old guard stopped; it does not expose the
numeric mismatch or prove a server correction. COPY STATUS supplies those
client readings if another issue occurs. See [the check record](FERAL-RECOVERY-HUB-v1.3-CHECKS.json).

```sh
LUAU=/path/to/luau python roblox-tools/tests/test-feral-recovery-hub-v1.3.py
```
