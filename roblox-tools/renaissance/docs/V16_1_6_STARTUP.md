# FERAL Renaissance 16.1.6 small startup loader

This launcher runs the **mouse-only M1 tap-to-hold** candidate. Physical left mouse is the only new hold trigger. **Left Alt has no attack binding.** The first click goes to the game's original WolfController handler; holding the same press uninterrupted for 0.28 seconds hands off follow-up bites to the hub. Quick taps and manual clicking remain unassisted. The native callback is preferred, with a bounded, executor-dependent ordinary mouse input fallback only for sustained holds. Releasing M1 cancels the repeat. Faster Bites still changes request pacing but cannot bypass native/server cooldown or guarantee accepted hits.

**Verified source:** 16.1.6 gameplay bundle at `629429926b14894f78c146723b26a80f0864a31a`, 569,486 bytes, SHA-256 `bb82168a72c1eca888a29df1d4a930a33c63e735c574659528260c61ce50d10f`. The compact launcher initially downloads that immutable file; if a large HTTP response fails or truncates, it concatenates seven immutable exact-source chunks from `fe4390cbdb0e1776fe1104720819c608d7a2c281`. It rejects wrong-size responses, checks the expected version header, compiles guardedly and displays clear download/executor/startup errors. CI independently validates byte-identical chunks, SHA and loader compilation.

**Integration tests:** 427 Renaissance and 305 Territory regressions passed. Neither test suite proves accepted server damage or physical hardware event identity in the user's live Roblox/executor build. Legacy 16.1.5 and all stable releases remain available and unchanged.

The intended launch string is pinned to the loader's commit, recorded with the release.
