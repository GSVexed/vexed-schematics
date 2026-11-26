# Territory 0.7.0 scenario evidence map

All 62 scenarios from the preparation are retained. **Every live acceptance result is unverified.** “Simulated” means the named suite exercises a bounded version of the scenario; it does not establish all terrain/species/native-server combinations or the full expected result. “Partial” and “incomplete” identify gaps even before live acceptance. The complete requirement and next dependency remain in the [execution ledger](PREPARATION_EXECUTION_LEDGER.md).

Exact source is pinned by [release.json](../../renaissance/release.json). Suites are under [tests](../tests). There are 263 Territory and 202 core passing cases; those test counts are not scenario-completion counts.

| ID | Prep scenario | Offline evidence | Scope / remaining gap | Live acceptance |
|---|---|---|---|---|
| S01 | Start with no living animal; then spawn | simulated — lifecycle/agent | Spawn/pack changes and no-input invalid identity fixtures. | Unverified |
| S02 | No pack, then join/change pack | simulated — lifecycle/agent | Spawn/pack changes and no-input invalid identity fixtures. | Unverified |
| S03 | Start from each map corner/region | simulated — planner/efficiency | Actual-position entry, eligible-set sweep, cost/value preference, slack and urgent ordering. | Unverified |
| S04 | Runtime eligible set differs from historical 71/69 | simulated — planner/efficiency | Actual-position entry, eligible-set sweep, cost/value preference, slack and urgent ordering. | Unverified |
| S05 | High-cost mountain target is Euclidean-near | simulated — planner/efficiency | Actual-position entry, eligible-set sweep, cost/value preference, slack and urgent ordering. | Unverified |
| S06 | High-value claim versus nearer low-value claim | simulated — planner/efficiency | Actual-position entry, eligible-set sweep, cost/value preference, slack and urgent ordering. | Unverified |
| S07 | Ordinary scent deadline becomes tight above .28 hold | simulated — planner/efficiency | Actual-position entry, eligible-set sweep, cost/value preference, slack and urgent ordering. | Unverified |
| S08 | Several urgent scent targets plus acquisition | simulated — planner/efficiency | Actual-position entry, eligible-set sweep, cost/value preference, slack and urgent ordering. | Unverified |
| S09 | Current claim nearly complete when routine care triggers | simulated — agent/care/lifecycle | Near-finish protection, critical care, occupied hex and stable remote completion. | Unverified |
| S10 | Critical needs while a claim is near completion | simulated — agent/care/lifecycle | Near-finish protection, critical care, occupied hex and stable remote completion. | Unverified |
| S11 | Target becomes occupied | simulated — agent/care/lifecycle | Near-finish protection, critical care, occupied hex and stable remote completion. | Unverified |
| S12 | Packmate finishes or progresses target | simulated — agent/care/lifecycle | Near-finish protection, critical care, occupied hex and stable remote completion. | Unverified |
| S13 | Distant eligible work behind repeated nearby work | simulated — efficiency | Aged feasible waiting target wins a fairness sweep. | Unverified |
| S14 | Maintenance workload exceeds one animal's capacity | partial — efficiency | Known due-job lateness and unknown data are reported; steady-state retention is absent. | Unverified |
| S15 | Claim progress arrives with realistic jitter/gaps | simulated — agent/lifecycle | Progress gaps, alternate access and precise arrival fixtures; live jitter/access geometry open. | Unverified |
| S16 | First interaction position is unreachable | simulated — agent/lifecycle | Progress gaps, alternate access and precise arrival fixtures; live jitter/access geometry open. | Unverified |
| S17 | Flat unobstructed long route | simulated — nav/driver | Checked direct travel, corners, late rejoin, stale epochs, overlap, full mesh and distinct detours. | Unverified |
| S18 | Long mesh route of tiny collinear waypoints | simulated — nav/driver | Checked direct travel, corners, late rejoin, stale epochs, overlap, full mesh and distinct detours. | Unverified |
| S19 | Sharp turn approached at Burst | simulated — nav/driver | Checked direct travel, corners, late rejoin, stale epochs, overlap, full mesh and distinct detours. | Unverified |
| S20 | Delayed path result after animal advances | simulated — nav/driver | Checked direct travel, corners, late rejoin, stale epochs, overlap, full mesh and distinct detours. | Unverified |
| S21 | New target then old async route completes | simulated — nav/driver | Checked direct travel, corners, late rejoin, stale epochs, overlap, full mesh and distinct detours. | Unverified |
| S22 | Initial root/body overlap with a tree | simulated — nav/driver | Checked direct travel, corners, late rejoin, stale epochs, overlap, full mesh and distinct detours. | Unverified |
| S23 | Off-center tree, narrow passage and large body | simulated — nav/driver | Checked direct travel, corners, late rejoin, stale epochs, overlap, full mesh and distinct detours. | Unverified |
| S24 | U-shaped obstacle/wide orbit | simulated — nav/driver | Checked direct travel, corners, late rejoin, stale epochs, overlap, full mesh and distinct detours. | Unverified |
| S25 | Slow valid hill ascent and switchback | partial — nav | Inclined clearance and useful slow-progress model; actual mountain/switchback matrix open. | Unverified |
| S26 | Vertical ledge/native climb transition required | incomplete — agent | Native climb flag yields movement; autonomous climb transition is unimplemented. | Unverified |
| S27 | Cliff, body shoulder drop and narrow trench | simulated — nav | Shoulder cliff, narrow trench, support/overhang and streamed safety fixtures. | Unverified |
| S28 | Bridge/rock overhang above lower terrain | simulated — nav | Shoulder cliff, narrow trench, support/overhang and streamed safety fixtures. | Unverified |
| S29 | Terrain streams out/in during movement | simulated — nav | Shoulder cliff, narrow trench, support/overhang and streamed safety fixtures. | Unverified |
| S30 | Server position correction versus legitimate fast motion | simulated — nav/driver/gait/lifecycle | Corrections, callback replacement, virtual rejection, gait booleans/denial and manual X. | Unverified |
| S31 | World reader unavailable/replaced | simulated — nav/driver/gait/lifecycle | Corrections, callback replacement, virtual rejection, gait booleans/denial and manual X. | Unverified |
| S32 | Virtual key call rejected, executor available | simulated — nav/driver/gait/lifecycle | Corrections, callback replacement, virtual rejection, gait booleans/denial and manual X. | Unverified |
| S33 | Raw gait false/nil/native denial/delayed acknowledgement | simulated — nav/driver/gait/lifecycle | Corrections, callback replacement, virtual rejection, gait booleans/denial and manual X. | Unverified |
| S34 | Manual X and same-direction key during automation | simulated — nav/driver/gait/lifecycle | Corrections, callback replacement, virtual rejection, gait booleans/denial and manual X. | Unverified |
| S35 | Land→surface water→land | partial — nav/bridge/lifecycle | Existing configured surface-water support; real bank/entry/exit routes unverified. | Unverified |
| S36 | Steep/blocked bank or missing exit | partial — nav/bridge/lifecycle | Existing configured surface-water support; real bank/entry/exit routes unverified. | Unverified |
| S37 | Nearby native drink offer, distant coarse lake | simulated — bridge/care/lifecycle | Native water preference, bounded discovery/refinement and opportunity guard. | Unverified |
| S38 | Water search spans multiple bounded scan slices | simulated — bridge/care/lifecycle | Native water preference, bounded discovery/refinement and opportunity guard. | Unverified |
| S39 | Repeated tiny thirst losses near water | simulated — bridge/care/lifecycle | Native water preference, bounded discovery/refinement and opportunity guard. | Unverified |
| S40 | Different native need maxima and malformed values | simulated — efficiency/lifecycle | Non-100/fractional maxima, malformed resource pause and feasible targets. | Unverified |
| S41 | Sparse resource drops, changing gait and long idle | partial — agent/care | Sparse depletion sampling and recent mode reserve estimates; no confidence calibration. | Unverified |
| S42 | Hungry/thirsty/low HP simultaneously | simulated — efficiency/care/lifecycle | Single arbiter, pending E ownership, virtual rejection/executor, no-gain repair and release. | Unverified |
| S43 | Native feeding pending before public active flag | simulated — efficiency/care/lifecycle | Single arbiter, pending E ownership, virtual rejection/executor, no-gain repair and release. | Unverified |
| S44 | Rejected virtual feeding E with executor available | simulated — efficiency/care/lifecycle | Single arbiter, pending E ownership, virtual rejection/executor, no-gain repair and release. | Unverified |
| S45 | Feed animation without resource gain | simulated — efficiency/care/lifecycle | Single arbiter, pending E ownership, virtual rejection/executor, no-gain repair and release. | Unverified |
| S46 | Native feeding ends below target or release fails | simulated — efficiency/care/lifecycle | Single arbiter, pending E ownership, virtual rejection/executor, no-gain repair and release. | Unverified |
| S47 | Edible food/forage/prey competing choices | partial — bridge/hunt/lifecycle | Food-versus-hunt heuristic and finite corpse nutrition sequence; yield/risk optimum absent. | Unverified |
| S48 | Stationary close prey while facing away | simulated — hunt/nav/lifecycle | Facing/contact, moving pursuit, late HP/markers, protection, corpse and shared core target cases. | Unverified |
| S49 | Moving prey, delayed attack result and changing distance | simulated — hunt/nav/lifecycle | Facing/contact, moving pursuit, late HP/markers, protection, corpse and shared core target cases. | Unverified |
| S50 | Prey faster/inaccessible/protected/near another player | simulated — hunt/nav/lifecycle | Facing/contact, moving pursuit, late HP/markers, protection, corpse and shared core target cases. | Unverified |
| S51 | Native marker advances but prey HP does not | simulated — hunt/nav/lifecycle | Facing/contact, moving pursuit, late HP/markers, protection, corpse and shared core target cases. | Unverified |
| S52 | HP declines due to another attacker/manual hit | simulated — hunt/nav/lifecycle | Facing/contact, moving pursuit, late HP/markers, protection, corpse and shared core target cases. | Unverified |
| S53 | Prey dies; corpse delayed/consumed/wrong diet | simulated — hunt/nav/lifecycle | Facing/contact, moving pursuit, late HP/markers, protection, corpse and shared core target cases. | Unverified |
| S54 | Core combat/reach target state differs from intended NPC | simulated — hunt/nav/lifecycle | Facing/contact, moving pursuit, late HP/markers, protection, corpse and shared core target cases. | Unverified |
| S55 | Low HP with recovery disabled/denied/no progress | simulated — agent/care/lifecycle/efficiency | Recovery ownership, bounded returns, pause clocks, STOP/unload, generations and currency windows. | Unverified |
| S56 | Urgent scent→water→food/another emergency interruption | simulated — agent/care/lifecycle/efficiency | Recovery ownership, bounded returns, pause clocks, STOP/unload, generations and currency windows. | Unverified |
| S57 | Manual/menu pause, long frame and resume | simulated — agent/care/lifecycle/efficiency | Recovery ownership, bounded returns, pause clocks, STOP/unload, generations and currency windows. | Unverified |
| S58 | STOP/unload during key pulse/path/feeding/bite request | simulated — agent/care/lifecycle/efficiency | Recovery ownership, bounded returns, pause clocks, STOP/unload, generations and currency windows. | Unverified |
| S59 | Repeated animal/map/body changes and reloads | simulated — agent/care/lifecycle/efficiency | Recovery ownership, bounded returns, pause clocks, STOP/unload, generations and currency windows. | Unverified |
| S60 | Amber gains, spending, disabled intervals and reset | simulated — agent/care/lifecycle/efficiency | Recovery ownership, bounded returns, pause clocks, STOP/unload, generations and currency windows. | Unverified |
| S61 | High NPC/food population and rapid streamed changes | partial — bridge/lifecycle | Twenty-four-candidate slices and bounded coverage/caches; native source-list creation remains opaque. | Unverified |
| S62 | Multi-hour combined cycle with repeated care/occupation | simulated — lifecycle | 7,200-second two-hex integrated unassisted native-callback simulation; no multi-hour live scene. | Unverified |
