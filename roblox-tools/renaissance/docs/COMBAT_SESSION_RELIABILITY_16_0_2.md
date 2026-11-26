# Renaissance 16.0.2 — combat-session reliability candidate

User report: existing Bite Reach can work, but ghost hits can persist until returning to the menu and respawning. That symptom motivates a session-lifecycle repair; it does not by itself prove whether the original cause is client-side or server-side.

## Implemented

- Retain the exact existing reach configuration. Default to ON when the preference is absent; preserve explicitly saved OFF and the normal native compatibility mode. No increase to the reach, cone or vertical factors.
- Failed native Rest exit dispatch is no longer treated as a successful exit. Restore owned pose state, retain a truthful failure, stop additional automated recovery on that character, and do not schedule the optional delayed attack after a failed exit. Ordinary native input is preserved. Manual Rest or a fresh animal clears the failed-exit guard. This is a failure-handling change, not a guarantee of recovery or native hit acceptance.
- Reject stale opponent body/root/Humanoid and player-character references. Retire the stale guide and cached target references, including tree references, and clear the prior animal's combat targets/transaction snapshot at a character change. Existing range settings are retained.
- Reconnect disconnected native feedback listeners and ignore events from superseded remote objects. This restores observation, not damage.
- Preserve all 26 embedded modules and all 22 core feature records, Territory OFF by default and the earlier versioned packages. No server changes.

## Automated checks

Four regressions cover failed Rest exit without deferred attack or misleading pose masking, character-change cache invalidation, replacement opponent body invalidation without an own-character respawn, and native feedback listener reconnection. Native compatibility fixtures still explicitly test OFF. Validation results belong to the exact candidate's own CI, not the 16.0.1 baseline.

## Remaining live acceptance

The user reports ghost hits, active recovery and condition clearance failures. These repairs address concrete local lifecycle defects; they have not been confirmed as the cause of the persistent live ghost-hit problem. No live game session or current server implementation was inspected. Native damage acceptance, actual healing/status rates and whether respawn is no longer necessary remain unverified.

Implementation pin: `0bba0831449d8b7743bc9b36facada407168e68e`
Bundle: `roblox-tools/feral-renaissance-v16.0.2.lua`
SHA-256: `06a07fb509bbd217b059c5e282cd4bfaaf7a90595e13873b955953a8cea19f5c`

Do not silently promote this candidate to stable. The immutable 16.0.1, 16.0.0 and 15.7.0 packages remain available.
