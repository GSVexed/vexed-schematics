# Version 15.1.0 input and interaction review

The user reported minigame interruptions while a Rhino was attacked by several Honey Badgers and while trying to bite. The required behavior is for ordinary bite clicks and automatic minigame timing to coexist.

## Verified client contract

Baseline: FeralGrabV2UI capture 4659, SHA256 2259c18b15f7bd5d2b8fdc434924e2520a87349a9bbb92276c644aa80ec7df23. The parser reads instruction/control-flow evidence; raw game programs are neither executed nor published.

| Native evidence | Consequence |
|---|---|
| Prototype 71, serverPress | Uses current native S, actual SafeTime, original fight/strike IDs; checks ended, biteUntil, existing strike, pressed and start time; marks pressed before dispatch |
| Prototype 73, CAS callback | Begin invokes serverPress; every input state returns Sink |
| FeralGrabV2Press binding | Priority 3000; Space, ButtonA, ButtonR2 and MouseButton1 share that callback |
| Prototype 72 | Touch GUI button callback, not a second global mouse listener |
| begin / n | Multiple hunters belong to one native fight; n updates the hunter count |
| strike | Carries f, k, t0, spd, from, zc and zw; duration derives from PASSES/spd |
| res | Own result matches c == LocalPlayer.Character or mine; other hunters' results are separate |
| bite | Clears the strike and pauses input using the native local-clock BITE_PAUSE window |

The v15.0 hub separately cancelled its pending automatic press on attack clicks. Removing only that cancellation would still leave the native MouseButton1 action submitting mistimed manual minigame inputs and consuming the bite click.

## Implemented behavior

During an actual automatic session, a narrowly verified native serverPress closure supplies the genuine UI state and the manual key callback. The hub leases the native action, retains manual Space/gamepad input under its own binding and leaves MouseButton1 for the normal bite path. Rest and legacy escape yield to the minigame. Attack intention still releases recovery but does not cancel the scheduled minigame press.

Closure discovery requires getgc, debug.info and supported upvalue access. It checks the own UI script and actual FeralGrabV2 RemoteEvent. It scans at most 384 entries or approximately 12 ms per slice after pool enumeration, resumes from the saved position, and discards the pool after completion. Missing capability is displayed as PARTIAL for an active minigame. No arbitrary closure is patched or globally hooked.

Pending timing survives n updates and transient text focus. It can retry a later valid crossing of the same strike after a delayed frame. It never invents a new strike or predicted server grade. Native UI cancellation, expiry and respawn win over stale observer data. Disable/shutdown restore the original-equivalent native binding for the same live session without restarting the fight.

## Reach and recovery interaction

The reach profile broadens client range/height limits and uses one eligible nearby target for rear or same-tree direction. It does not rotate the character, edit opponents or issue additional hit claims. Same-pack and protected targets are excluded. A stock-reference guide remains separate from extended client eligibility.

Condition deficits can request native Rest during a known combat tag, while HP combat exclusion stays enabled. Held/recent attacks, minigames, capture, feeding, abilities and movement transitions still preempt Rest. Base and Rest factors remain coordinated to avoid local 16x compounding. The native post-Rest bite lock remains a possible first-bite blocker.

## Validation limits

73 service-boundary scenarios pass, including independent bite/minigame input, three hunters and repeated clicks, exact binding restoration, manual takeover, mid-session adoption, stale native cleanup, missed crossings, own-result matching, incremental discovery, condition/attack priority and rear/vertical geometry. These establish implementation behavior under the fixture contract.

The current live executor call is acknowledged without an exact console result. Actual accepted damage during a minigame, Perfect frequency, added accepted range and real 4x condition clearance are unverified. Native WolfController tryBite/doBite also enforce pin, cooldown, clamp, venom and post-Rest guards; input separation is not evidence those restrictions have been bypassed.
