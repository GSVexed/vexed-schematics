# FERAL Renaissance 16.1.6 — sustained Left Alt held bite

The user reports that 16.1.5 held-Alt input works initially, then stops after some time. There is no live diagnostic trace; the following are **source-confirmed failure mechanisms and mitigations**, not a claimed unique cause.

1. The input backend rotated from a previously confirmed VirtualInputManager/mouse API to an unverified alternative after only *two* missing local bite markers. Cooldown/ability timing can generate missing markers even when input itself is functional. The new scheduler remembers the last backend that produced a local native bite marker, tolerates four misses and probes another API only on five consecutive misses, then returns to the proven backend if the probe does not produce a marker. A new backend can become proven only by another native marker.
2. An asynchronous mouse pulse might leave the owned syntheticM1 active forever if a scheduled release never ran. A heartbeat watchdog now releases pulse ownership at 0.5 seconds.
3. Roblox can report a generated M1 down as a held mouse button. That was treated as real human M1, permanently preventing Alt requests. The coordinator now distinguishes genuine physical M1 InputBegan from an Alt-generated mouse state, while still protecting real M1 already held before Alt.
4. A single transient false IsKeyDown(LeftAlt) poll revoked the Alt-held identity. With no matching InputEnded, the hold now pauses immediately and waits up to 0.18 seconds for the poll to recover, then releases on sustained false.
5. If an Alt-triggered Windows accessibility/overlay prompt briefly removes focus, inputSuspended stays latched on return. The hub now resumes an *existing, pre-focus-owned* Alt session only when the window is focused, Alt is still physically detected, the animal is available and no text/menu/hub control is focused. Real release or focus-absent sessions never restart automatically.

The 16.1.5 independently-held Alt method, normal left mouse gameplay, 16.1.4 adaptive faster request pacing, native hit/cooldown authority, prey/hunter minigame priority, UI, Territory, manual rest and unload remain unchanged. No undocumented hit/damage remote or fake server replies.

Validation: Add long-duration regression, validated backend retention/rollover, simulated synthetic mouse-held feedback, stale-pulse watchdog, transient Alt polling, release/focus and minigame cases. Run complete Renaissance and Territory suites and exact bundle provenance before providing a loader.

**Limitations**: local markers do not prove server-accepted damage; an OS-level accessibility popup may still interrupt keyboard state. No code in the hub can override Windows' keyboard shortcut settings or guarantee input delivery across actual app focus changes.
