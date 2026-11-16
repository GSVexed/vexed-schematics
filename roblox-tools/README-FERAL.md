# FERAL diagnostic project

Read-only client collection and evidence-based analysis for PlaceId
`108901361810209`. The full dataset, menu/Tiger comparisons and main analysis
are complete within their recorded scope. Reconstruction defects remain
explicit limitations, not missing-file claims.

**Already supplied the v3.0.3 and v3.1 ZIPs? Do not repeat either scan.**
The only newly identified live client-source gap is `Character.Animate`.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-final-gap-v3.2.lua"))()
```

Spawn as a Tiger, close the animal menu, and click **CAPTURE LIVE SOURCE**.
When it ends, use **COPY FOLDER**, find `FERAL_Final_v3_2_...` in Velocity's
workspace, and compress the **entire folder** to ZIP. Upload that small ZIP.
There is no requirement to repeat the menu capture. The observation lasts
five seconds; source and own-hierarchy collection follow.

This final collector is published and offline-tested. Its actual live-source
capture still requires the user's Roblox/Velocity session. It cannot obtain
that file from a previous ZIP where it was never collected.

## Project entry points

| Need | File |
|---|---|
| Final results, authority findings and remaining limits | [FERAL-FINAL-ANALYSIS.md](FERAL-FINAL-ANALYSIS.md) |
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
