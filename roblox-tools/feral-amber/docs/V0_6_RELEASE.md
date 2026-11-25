# Renaissance 15.6.0 / Territory 0.6.0 — committed hunting and continuous terrain-aware travel

Prepared against main `87e036c846342e7b288f0a4977b9d69c565251b4` on 25 November 2026. This implementation addresses reported prey switching, zero-damage hunts, circles, slow mountain progress, missed automatic Burst, repeated route failures and survival handoffs. The complete existing hub and its 21 core records remain integrated.

## Evidence and concrete causes

The user supplied a Tiger report from Territory 0.5.1 / FERAL v2412. It records two claims, thirst +55.9 and hunger +31.8, an EAT objective lasting 103.6 seconds, route failures after 12.0 and 8.3 seconds, repeated obstacle recovery, zero attack requests with a retained ‘native cooldown’ result, and sprint without gait requests. This is partial gameplay evidence, not a controlled trace of the precise failing source path. Publication of these gameplay examples and the complete technical documentation was explicitly authorized.

Independent source review and deterministic reproductions identified the following controller behaviors. These cases establish implementation defects and desired transitions; they do not prove the cause of any particular live gameplay incident.

| Source behavior | Resulting change |
|---|---|
| Hunter starts a seven-second no-damage timer before an attack is dispatched, and a thirty-second lifetime limit can drop productive prey | Separate blocked native input from ineffective attempts; retain productive prey while closing or HP declines; bounded failure and escape handling remain |
| Manual-pause recovery blacklists the prey | Resume the same still-valid prey and adjust elapsed timers; no blacklist merely for manual assistance |
| One route failure immediately drops the prey or territory objective | Retry committed approaches before deferring; reset prey retry budget after useful progress |
| Advisory readiness from the previous core snapshot can suppress the original native bite handler | Dispatch through the original native handler, which retains its own cooldown, Rest and capture guards. Requests are still distinct from actual HP changes |
| Synthetic fallback clicks use the mouse position, potentially over the hub | Look for a GUI-clear attack point before fallback mouse submission when GUI hit testing is available |
| Sub-0.45-stud navigation samples are treated as no progress | Use a time-aware lower threshold so slow useful ascent is recognized |
| Short detours use a broad normal-waypoint radius | Give detours a precise arrival radius and a stable interval; avoid immediately reselecting a detour before meaningful travel |
| Old indirect routes can survive after the straight corridor becomes clear | Periodically prefer a checked direct surface segment; do not blindly cut mountain bends |
| A successful navigation mesh path is accepted without terrain-edge validation | Validate its walking edges, sample support more closely, and recheck the immediate steering corridor for changed terrain |
| Unknown stamina forbids Burst even with a readable native mode | Permit a bounded native Burst attempt only with a known mode and eligible clear route; native denials and retry limits still apply |
| One suspended objective slot is overwritten by urgent scent followed by care | Preserve a bounded return chain, revalidate each objective and discard completed/ineligible work |
| Resource scouting changes targets after eight seconds even while progressing | Retain a useful distant search target with progress and total-time limits; move on after genuine non-progress |
| Core manual feeding repair and Territory care can both repair the same session | Core continues observing/protecting native feeding but leaves owned farming repairs to Care |
| Low-health hungry animals wait in place without searching | Seek available edible resources while retaining the exclusion on risky hunts |
| Latched feeding can ignore a different critical resource | Release only the owned feed session, verify release, then handle the critical need |
| Positive-only per-tick consumption estimates exaggerate sparse updates | Forecast from multi-second windows, including unchanged samples; bring care forward when measured reserve is short |
| STOP/restart can include gains made while disabled | Reset the currency observation baseline at START |
| A historical hunt appears active during a different objective | Separate current hunt from timestamped retained history; add route-local and care-phase evidence |

## Behavioral details

Hunting remains NPC-only and native-eligible. The hunter retains viable prey instead of selecting a nearer candidate on each tick, continues moving during pending attacks, observes HP decline independently, and waits for real edible food after a death. Delayed HP decline clears accumulated ineffective-attempt state. An unavailable native attack is reported and bounded; no extra Bite/BiteHit claim, resource rewrite or opponent part edit is added.

Terrain checks use body clearance, supported ground, slope limits and conservative step/drop limits. Path success alone does not authorize a cliff descent. These checks reduce unsafe route selection; they are not fall-damage immunity and cannot undo a fall already in progress. Arbitrarily steep mountains, unstreamed terrain and inaccessible ledges can remain unreachable.

Survival care uses measured depletion to start earlier when necessary, a larger native eating target in the live bridge, current diet/forage rules and stable resource targets. A critical other need can interrupt an owned meal after release is confirmed. Resource scarcity, native denial and inaccessible interactions remain real constraints.

Runtime claim radius is read from validated native configuration, and the current animal must be in the target hex before a nearby approach is treated as valid. All eligible territory discovery, region sweeps, scent priorities, native completion and contested deferrals remain. Nested return contexts are invalidated on STOP, death and identity changes.

## Validation

The pinned official Luau toolchain passes **215/215 Territory cases** and **187/187 retained core cases**. Compilation, deterministic embedded-source parity, writer guards and protected rollback hashes pass. There are 27 additional Territory cases, including a complete-bundle fixture where stale advisory cooldown cannot suppress an original native attack and simulated HP damage. That fixture is a deterministic service simulation, not live server damage evidence.

New tests include long productive hunts, close cooldown blocking, manual-assisted resumption, target commitment, late HP decline, slow progress, clear straight recovery, precise detours, cliff/path rejection, newly unsafe ground, guarded Burst with absent stamina, nested scent/care return, repeated route recovery, income restart baselines, earlier/critical care, sparse resource updates, stable resource scouting and competing feed repairs. Selected new scenarios were also executed against the preserved previous source and failed on the corresponding old behavior.

Previous complete 15.5.1 and Amber 0.5.1 bundles are added to rollback protection. No previous versioned executable is overwritten. The normal compact Territory page, one scheduler, optional local COPY STATUS and shared unload remain.

## Evidence limits and remaining programme

No direct current Roblox/Potassium execution route was exposed in this session. No live 0.6.0 travel, accepted damage, completed water crossing, full-map retention, Amber/hour or long unattended survival has been certified. Earlier gameplay observations do not validate this exact candidate.

Shared strategy works from native profiles; there is no claim of newly completed autonomous aerial or underwater navigation. Those native states still require their supported/manual handling. Ground and surface-swimming support does not establish unattended success on every species. Resource starvation or damage immunity is not claimed.

This is a substantive Territory milestone within the whole-hub master preparation, not completion of all 52 work items. Next live evidence should focus on actual NPC HP change, route-local progress after feeding, automatic Burst on eligible clear travel, and a natural ground/water/survival loop. Use the existing local report; no broad new collection is required.

## Rollback

Previous complete integrated hub:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/e6f2bccf72efb75d736b64996e05bed1a95cefd3/roblox-tools/feral-renaissance-v15.5.1.lua"))()
```

The normal combined launcher is retained and will point to the exact validated release after source checks pass.
