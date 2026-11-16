# FERAL client project

The current [Field Hub v1.3](README-field-hub-v1.3.md) follows a
[whole-client-export review](FERAL-CLIENT-CODE-REVIEW-v1.3.md): all 339 logical
game exports indexed, 221 distinct bodies read, and all 22,283 preserved Roblox
platform source sets checked for FERAL markers. The [complete per-file inventory](FERAL-CLIENT-FILES-v1.3.md)
and [surface index](FERAL-CLIENT-SURFACE-INDEX-v1.3.json) record the scope.

v1.3 preserves the Bear/Tiger stamina path and adds reversible speed/leap
profiles, native Rest assistance, owned-coat equips, eligible earned-reward
claims, comfort settings, a broader travel atlas and checkpointed field reports.
**Added HP regen failed in the user's test. Arbitrary amber, restricted spawns
and owner grants are not implemented.** See the [goal review](FERAL-GOAL-REVIEW-v1.3.md).
New v1.3 gameplay effects require Roblox testing; source/simulation checks are
reported separately.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-field-hub-v1.3.lua"))()
```

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
