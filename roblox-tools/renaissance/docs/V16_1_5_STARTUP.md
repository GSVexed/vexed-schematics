# FERAL Renaissance 16.1.5 verified startup

**Gameplay control:** Hold physical LEFT ALT for repeat-bite requests. Left mouse button remains the game's regular attack. Right Shift toggles the hub. Faster Bites continues to govern repeat **request pacing**; native/game server cooldown still determines accepted attacks.

**Source identity:** exact validated 16.1.5 bundle source `ed149b0904dc4d9aacc1b00726e680b9ea90846e` (567,075 bytes, SHA-256 `5b65b0fc59fd6ba5ea70e2b6c84d1ed92f88993f4627e5ca97910765275dba7d`). The small loader downloads this immutable source first, then falls back to seven immutable parts from `7ec2f07a6559c54f22b37c3a438572f24342c3e0`. CI verifies byte-for-byte reconstruction, manifest/candidate SHA parity and Luau loader syntax.

**Safety and diagnostics:** It does not change any Windows accessibility shortcuts, forge damage, bypass native cooldown, or silently load older versions. An executor may lack functional input injection; the hub records INPUT requests and actual native markers separately. On failure, the loader displays a visible error describing download, executor, compilation, startup or activation failures. Actual bite acceptance and sustained repeating remain unverified until exercised in the target client.

Test results: 437/437 Renaissance and 305/305 Territory official offline checks. Previous 16.1.4 remains available and unchanged.

Load with the immutable URL provided in the final release response once the loader commit is available.
