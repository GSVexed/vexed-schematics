# Renaissance 15.6.1 / Territory 0.6.1 — close-prey attack and native gait corrections

Baseline: main `dad53c221c95b39d0c07d13d47c450224dbd5f93`, 25 November 2026. All existing features, complete documentation and prior versioned bundles are retained.

## Current gameplay context

The supplied Territory 0.6.0 report records zero automatic attacks and zero observed hunt HP declines. Its completed meal followed manual intervention, which the user explicitly confirmed. The hunger gain is an observed resource change, not evidence of successful autonomous hunting. The report also records no gait requests; missing Burst was separately reported during travel.

Three independent source reproductions failed on 0.6.0 before correction:

| Defect | Correction | New evidence |
|---|---|---|
| The bridge returned `ok and value or nil` for attributes, converting legitimate `false` values into `nil`. Native Burst-off, trot-off and sprint-off became unknown states. The gait controller intentionally refuses to toggle an unknown Burst state. | Preserve false values explicitly while retaining nil for missing/failed reads. | The actual bridge now reads false native gait flags and feeds the existing acknowledged sprint-to-Burst path. This replaces reliance on hand-authored gait fixture booleans. |
| A near-prey lateral parking point could already be reached while the animal faced away. Navigation then returned REACHED, so the animal never turned and the geometry gate never permitted a bite. | When range is valid but facing is wrong and the corridor is clear, steer toward prey until ordinary movement turns the animal into valid geometry. | A full-bundle physical simulation starts at the problematic parking position, uses actual Bridge geometry and Hunt/Nav/Driver, turns through movement and reaches the original native attack handler with simulated HP decline. No geometry-valid stub is used in that case. |
| When VirtualInputManager existed but its mouse method raised an error, `bite` returned immediately. Available executor mouse functions were never tried. | Fall through after rejected virtual input to one supported executor mouse path. Keep the cooldown, GUI checks, paired release and cursor restoration. An accepted virtual call does not emit an additional executor click. | Rejected/accepted virtual paths, executor click fallback, paired release and cursor restoration are tested. These are service simulations, not live executor efficacy evidence. |

Attack line-of-sight rays now respect collidable geometry, avoiding rejection by noncolliding trigger parts while retaining solid-obstruction checks. The box-size hint is validated before numeric geometry calculations. Prey selection also uses the existing combat eligibility policy so spawn-protected or otherwise excluded NPCs are not selected for a hunt the native client would reject.

The earlier native-handler fixture assumed valid geometry and did not cover these contact/input failures. The new tests exercise those boundaries directly. Passing them still does not establish a live server hit.

## Better retained evidence

Current and historical hunt status retain the last blocking reason and its time, geometry values/reason, selected attack backend, dispatch result, virtual-API rejection, and observed own-character bite-marker changes. Generic pursuit abandonment no longer erases the earlier attack blocker.

The marker is a native client signal, not accepted damage. Marker advancement is compared with the pre-request value on the same character and reported with age; it can still correlate with a subsequent manual action. Actual prey HP observations remain separate. Completed care also records whether manual intervention was observed. Absence of that flag is not proof that every possible brief manual action was detected.

## Validation and limits

Pinned official Luau compilation, **223/223 Territory cases**, **187/187 retained core cases**, exact embedded-source parity, writer guards and rollback checks pass. Eight new cases cover the three reproductions, accepted-virtual deduplication, paired executor cleanup, noncolliding versus solid occlusion, manual-care reporting, and protected-NPC selection.

No direct live Roblox/Potassium trial of this patch was performed here. The source defects are reproduced and corrected; the exact cause of every zero-hit moment in the supplied gameplay is not conclusively established by the partial report. Live accepted damage, automatic Burst acceptance, unattended all-species survival and farm yield remain unverified. Existing aerial/underwater routing limitations remain.

The normal combined launcher is unchanged in use and will pin the validated complete 15.6.1 bundle. Re-execution replaces the previous runtime through the existing shared lifecycle. No raw game code, extra Bite/BiteHit claims, forced rotations, resource writes or new user controls are introduced.

## Rollback

Previous complete 15.6.0 source remains protected:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/180eba2d914e3c089482ccf90947ac880439179d/roblox-tools/feral-renaissance-v15.6.0.lua"))()
```
