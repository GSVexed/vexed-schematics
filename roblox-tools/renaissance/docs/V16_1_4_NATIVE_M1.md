# FERAL 16.1.4 — native-only physical M1 repeat with adaptive request pacing

The user reports that Hold to Bite using synthetic mouse Up/Down edges stops after one or two bites. The experimental Left Alt 16.1.3 branch was closed without promotion because it changed the required user control.

**This candidate retains Left Mouse as the attack/hold control** and uses only FERAL's original, validated current-player WolfController.tryBite callback for repeats. It never intentionally replays synthetic M1 edges from the combat repeat scheduler. If the original closure is inaccessible, the hub reports WAITING rather than pretending generated clicks worked.

Adaptive Faster Bites' feedback multiplier (62% initial request interval, optionally down to 55% on corroborated positive hits or back towards 100% after clean missed contacts) now controls native repeat *request scheduling*. The unmodified native function's cooldown and server acceptance remain authoritative. This is not proof of increased server-confirmed attacks; the previous UI rate claimed a factor that was not connected to dispatch timing. Source-level private timing uncertainty cannot block a safely validated original callback from enforcing its own rules.

Left Mouse physical release, focus changes, menus, Rest, abilities, capture, concurrent hunter minigame separation, prey minigame priority, settings, cleanup, Territory and all prior stable release pins must remain intact.

No direct damage remote calls, synthetic hit replies or spoofed server confirmations. All changes should be validated in both Renaissance and Territory mock suites, with explicit native hold, speed factor ON/OFF and absence of synthetic fallback tests. The private native callback may be inaccessible on certain executors; that limitation cannot be solved by merely increasing synthetic clicks.
