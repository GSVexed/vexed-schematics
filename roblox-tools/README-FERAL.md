# FERAL client project

The current focused [Field Hub v1.4](README-field-hub-v1.4.md) targets three goals:
**amber, actual restricted-animal spawns and lasting recovery**. It adds self-only
gift/reward-replay trials, direct fresh-empty-slot spawn attempts, a normal Snow
Leopard amber purchase and server Rest-signal comparisons. **No new server grant
or recovery effect is established until an in-game run supplies evidence.**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-field-hub-v1.4.lua"))()
```

v1.4 includes the earlier client controls and Bear/Tiger-supported stamina path.
Its [133 offline checks](FERAL-FIELD-HUB-v1.4-CHECKS.json) are separate from Roblox
acceptance. See the [focused methods and limitations](FERAL-THREE-GOAL-METHODS-v1.4.md).
The [v1.3 guide](README-field-hub-v1.3.md) remains available for the earlier build.

The [whole-client-export review](FERAL-CLIENT-CODE-REVIEW-v1.3.md),
[per-file inventory](FERAL-CLIENT-FILES-v1.3.md) and
[surface index](FERAL-CLIENT-SURFACE-INDEX-v1.3.json) cover all 339 logical game
exports / 221 distinct bodies, plus the platform relevance check. No fresh full
scan is needed for these focused trials. The old local HP regeneration writer
failed and remains retired; server-only code was not retrieved.

## Completed diagnostic investigation

Read-only client collection and evidence-based analysis for PlaceId
`108901361810209`. The full dataset, menu/Tiger comparisons and main analysis
are complete within their recorded scope. Reconstruction defects remain
explicit limitations, not missing-file claims.

**The diagnostic phase is complete within its recorded client scope.** All
three supplied ZIP sets verify. The final v3.2 Tiger capture collected the live
`Character.Animate` source; its filtered reconstruction exactly matches the
previous starter template. No additional scans or uploads are needed for this
phase. The known decompiler/authority limitations remain documented.

See the [completion record](FERAL-COMPLETION-v3.2.json) and
[final findings](FERAL-FINAL-ANALYSIS.md). The following loader is retained for
optional future use; the completed investigation does not require rerunning it.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-final-gap-v3.2.lua"))()
```

Spawn as a Tiger, close the animal menu, and click **CAPTURE LIVE SOURCE**.
When it ends, use **COPY FOLDER**, find `FERAL_Final_v3_2_...` in Velocity's
workspace, and compress the **entire folder** to ZIP. Upload that small ZIP.
There is no requirement to repeat the menu capture. The observation lasts
five seconds; source and own-hierarchy collection follow.

The final collector is published, offline-tested and now backed by an actual
successful Roblox/Velocity in-game capture. All 60 payload files in that
supplement passed independent integrity checks.

## Project entry points

| Need | File |
|---|---|
| Current Field Hub, owner checks and focused report | [README-field-hub-v1.2.md](README-field-hub-v1.2.md) |
| Original goals, source evidence and owner-tool review | [FERAL-GOAL-REVIEW-v1.2.md](FERAL-GOAL-REVIEW-v1.2.md) |
| Final results, authority findings and remaining limits | [FERAL-FINAL-ANALYSIS.md](FERAL-FINAL-ANALYSIS.md) |
| Final runtime evidence and closure status | [FERAL-COMPLETION-v3.2.json](FERAL-COMPLETION-v3.2.json) |
| Small last-live-source collector | [README-final-v3.2.md](README-final-v3.2.md) |
| Original complete client/platform collector | [README-v3.0.3.md](README-v3.0.3.md) |
| Historical menu/Tiger recovery experiment | [README-recovery-v3.1.md](README-recovery-v3.1.md) |
| All-source syntax quality counts and rejected-body index | [FERAL-source-quality-v3.2.json](FERAL-source-quality-v3.2.json) |
| Optional offline ZIP integrity verifier | [verify-feral-export.py](verify-feral-export.py) |
| Final validation and runtime limits | [VALIDATION-final-v3.2.md](VALIDATION-final-v3.2.md) |

For a new full baseline, the existing full collector's hosted entry point is:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-complete-diagnostic-v3.0.3.lua"))()
```

The small v3.2 supplement deliberately does not replace that full collector.
The previous exports preserve both game and Roblox platform content.

Historical regeneration experiments in this repository are separate from
these read-only diagnostics. The diagnostics do not modify resource values,
invoke gameplay remotes or claim to recover server-only code.
