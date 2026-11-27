# FERAL 16.2.0 native M1 hold

Initial real M1 attacks remain normal. After 0.28 seconds uninterrupted, a sustained hold requests native bites via the validated current WolfController.tryBite closure, or via the validated original WolfController.onInput callback with the real M1 InputObject if the inner callback is private.

The hub no longer calls tryHeldInputBite. No synthetic M1 Up/Down/Up pulses, disable of native game connections or direct damage remotes. This avoids the old physical/synthetic mouse conflict without claiming to hide the hardware button from Roblox.

Existing Adaptive Faster Bites feedback factor 0.62, potentially 0.55 to 1.0, is unchanged and now schedules both original native entrypoints. Native game/server cooldowns and accepted damage still control outcomes. Short taps, manual spam, release-to-stop, R2, hunter/prey minigames, ability locks, Rest, focus, UI, character change and unload stay protected.

Native onInput identification requires own WolfController debug source; named onInput preferred, anonymous only when uniquely matched to owner script by getfenv. Ambiguous or inaccessible callbacks fail closed, showing WAITING without synthetic fallback. Tests simulate closure isolation, ownership, callback invocation, game input release and cooldown, but cannot prove live executor availability or server-confirmed damage.
