# Renaissance 16.1.6: physical left-click tap-to-hold handoff

The user rejected the Left Alt method. This is a new **normal left mouse only** experiment based on the validated 16.1.5 bundle. Alt is no longer a repeat control or listened to via ContextActionService.

### Intended controls

1. A real M1 InputBegan goes to the original game immediately, unchanged. Presses released in less than 0.28 seconds are ordinary manual clicks, even when tapped repeatedly.
2. If the SAME physical M1 InputObject is still held for >=0.28 seconds, the hub enters repeat mode. It prefers the validated original current-player WolfController.tryBite callback. If the closure remains private, it may issue bounded Up/Down/Up *native mouse input pulses* on behalf of the still-held genuine click, using the game's stock cooldown and current input backend. It does not send undocumented damage remotes.
3. A real matching M1 InputEnded cancels the repeat and releases any hub-owned synthetic press. Synthetic mouse echoes are ignored while the real world-originating physical input is owned. A separate tap after release starts an independent 0.28-second delay, so intentional quick spam is not amplified.
4. Normal game cooldown, Rest/ability locks, manual interactions, hunter/prey minigames, UI, focus loss, character change, unload and native bite/damage authority have priority. Native callback during hunter minigames is allowed only in the already validated separated lane; fallback pulses are never sent inside a minigame.

### Sustained hold recovery

- The backend that actually produced a local WolfBiteAt marker is retained; missing markers prompt slow bounded probe and return, not permanent loss after two timeouts.
- An abandoned input pulse is released after 0.5 seconds even if an executor timer fails.
- Held-mouse event identity, not the synthetic backend's logical IsMouseButtonPressed state, owns the hold after handoff.
- Adaptive Faster Bites continues using its 0.62 initial request interval factor (feedback can adjust 0.55-1.0), without changing the game's native/server acceptance.

### Limits

A synthetic bite sound or native marker does not guarantee server-accepted damage. Some executors route synthetic and hardware mouse events through indistinguishable InputObject identities; this cannot be proven safe across all clients by offline mocks. Clear gameplay confirmation is still required. Previous releases stay immutable.

CI must compile and run full Renaissance + Territory suites, then package a version-pinned small launcher with split HTTP download fallback and source fingerprint. The separate abandoned experimental Alt 16.1.6 branch must not be shipped.
