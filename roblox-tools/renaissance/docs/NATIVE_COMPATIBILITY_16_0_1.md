# Renaissance 16.0.1 — native combat compatibility

The user reported both continued recovery/condition-clearance failures and ghost hits in the 16.0.0 integrated overhaul. The previous passing tests establish coordination under mocked services, not live server acceptance. This candidate deliberately reduces interference with normal game actions rather than making stronger unsupported gameplay claims.

## Implemented changes

- Expanded client bite range, cone, slack, body-gap and vertical/aim changes are no longer forced. The existing experimental reach record is an explicit optional setting, default OFF for a new or migrated configuration. No new combat expansion is introduced.
- With reach OFF the guide uses the unmodified native CombatConfig. No combat geometry lease is installed. A failed or retired experimental lease falls back to a read-only profile if available. Switching OFF restores owned fields immediately and invalidates the old guide.
- The Combat page exposes the existing reach setting and explains why the normal native geometry is the compatibility default. The small bite guide remains available.
- A failed Rest renewal no longer leaves the recovery owner/pose mask active or reports the failed session as continuing. The failure releases ownership, restores the owned pose, clears old trend data and enters a bounded pause. This addresses a local failure-handling defect, not a guarantee of faster healing or condition decay.
- Five core modules receive changes; all 22 feature records and 26 embedded modules remain. Integrated Territory code is unchanged and remains disabled by default. Historic versioned packages and stable launchers are preserved.

## Acceptance

Existing expanded-range-specific fixtures now select that historical optional mode explicitly; their original assertions remain. New tests exercise the native profile default, immediate geometry restoration after OFF with the guide retained, and a failed Rest renewal. Current hosted test results belong to this candidate's own CI run, not to the prior 16.0.0 report.

**Open live defects:** real recovery/4x negative-effect clearance, actual attack registration and ghost hits. Native Rest still has combat/ability/attack eligibility and a native stand-up interval; a local request or altered field cannot guarantee the intended benefit on a live server. The new normal combat default removes one hub-side cause of hit eligibility disagreement, but does not alter the server or certify its acceptance. Verify ordinary gameplay independently of injected modifications. No current Roblox session has been accessed in this change.

Implementation pin: `45c6a24e2d396ac3a5956c225c70c59451838b90`; bundle: `roblox-tools/feral-renaissance-v16.0.1.lua`; SHA256 `776cc09a7f3c14e60d40a367aee8c408dbcf8f2787b30817daed498e18672211`.

The prior 16.0.0 and 15.7.0 rollback packages remain unchanged. Do not promote this branch to stable without actual validation.
