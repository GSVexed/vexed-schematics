# Renaissance 16.1.5 — independent Left Alt held bite

The user changed the desired control after 16.1.4 native-only physical M1 held-repeat still failed in live play.

**New repeated-attack trigger:** hold physical LEFT ALT. Regular left-click still uses the game's normal original M1 attack and is not hijacked. The hub tracks Alt through both keyboard InputBegan/InputEnded and IsKeyDown; internally generated M1 up/down events can no longer revoke the Alt hold. Releasing Alt, focus loss, menus, disabling the toggle, a changed character or hub unload cancels the pending synthetic pulse.

**Attack selection:** First try the validated own-player native WolfController bite callback. If private callbacks are inaccessible, fall back only for physical Alt and only when the game's visible native timing/action checks pass, by sending normal game mouse input through an available executor/VirtualInputManager backend. Never send undocumented direct hit/damage remotes. The prior 16.1.4 native-only M1 route is preserved when callback access works. If both inputs are physically held, never synthesize a release of real M1.

**Adaptive faster bite:** retain existing 16.1.4 0.62→0.55 adaptive request factor with backoff to 1.0 and the existing client Species cooldown lease, while preserving the game's own cooldown and server authority. Accepted attacks and damage are unverified until live observation; attempting faster is not proof of extra server damage.

**Minigames:** When prey or an unrecognized game-grab state, do not synthesize any normal M1 attacks. A validated native callback can run during known, separately owned hunter sessions only outside perfect timing windows. Minigame automation has priority. Ensure held Alt resumes after a recognized minigame ends if not released.

**Diagnostics:** accurately distinguish native callback vs Alt fallback in Combat status, and never mark an input pcall as server-accepted hit. Auto Bite remains native-only.

**Validation:** include regression tests for private and native callback paths, fast rate ON/OFF, Alt release during pending input pulse, delayed processed M1 echo, manual M1 without Alt, UI/menus/focus, minigames and high-level 16.1.4 feature compatibility. Run full Renaissance and Territory suites in CI, then publish a pinned small loader with chunked download fallback. Prior stable, 16.1.2 and 16.1.4 releases stay immutable.

**Limitation:** Mock tests cannot prove executor input compatibility or server-accepted hit rate. Left Alt can interact with OS or other overlay hotkeys; this script does not change Windows settings.
