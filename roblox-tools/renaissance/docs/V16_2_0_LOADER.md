# FERAL Renaissance 16.2.0 compact loader

This immutable launcher starts the completed source-verified FERAL 16.2.0 candidate. Physical left-click remains normal on the first bite, and an uninterrupted 0.28-second hold permits repeat requests through the game's original WolfController tryBite or verified onInput handler with the original InputObject. Synthetic mouse-up/down/down replay from the repeat engine has been removed. The existing Adaptive Faster Bites feedback/scheduling factor remains intact, without bypassing the native game/server cooldown.

Validated gameplay source commit: bcc52f080cd7a56fc7fecf9f6d55a63d3cb2e1f0. Bundle: 575,316 bytes, SHA-256 7a9c8e956e5d2867ca6a5815fab00619e769e39542f4bd968198d8bc447ef73a. Compact loader first fetches that immutable source, then reconstructs the same bytes from seven newline-preserving parts at b1ba9d92bb730f15823e2e96fd47f70b905c7c5a if an executor truncates large downloads.

Renaissance: 433/433 service-boundary tests passed. Territory: 305/305 integration tests passed. The separate loader CI compiles this small source and verifies exact chunk parity and official SHA provenance.

Live server-accepted bite rate, physical InputObject reuse, and executor access to original callback functions are not guaranteed by mocked tests. If the original callbacks are unavailable, the hub reports WAITING instead of injecting conflicting fake M1 events. Ordinary manual attack still operates. Historical stable launchers and 16.1.6 remain unchanged.
