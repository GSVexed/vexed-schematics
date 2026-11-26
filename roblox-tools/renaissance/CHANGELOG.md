# Changelog

## 16.1.1 — reliability candidate

### Input and combat coordination

- Cancel delayed synthetic Down and owned Up callbacks when physical input ends, Hold to Bite is disabled, input context changes, or the character changes.
- Revalidate native action state before a delayed synthetic press; exceptions or failed preparation cancel dispatch.
- Suspend held polling after window focus loss, text entry and consumed UI input. Regaining focus or dragging out of a control does not resurrect an old click; a fresh gameplay press establishes ownership.
- Discover the current original attack callback from verified script/player/remote/function relationships without assuming fixed captured-value positions. Private timing inspection remains separately restricted to its validated layout.
- Invalidate stale callback owners on script/remote replacement. Bound heap traversal to one slice per timestamp and allow cancellation of an unfinished scan to restart promptly.
- Restore passive minigame observation even while automation is OFF, retired-session tracking, exception-safe callbacks, bounded lost-clock handling and priority over Territory work.
- Keep native hunter-bite and minigame paths separated where their original bindings are proven compatible; preserve blocking for unsafe or unsupported contexts.

### Feedback and state

- Keep native bite markers, local effects, real server replies and correlated target HP changes separate.
- Retain and update bounded earlier transactions when delayed evidence arrives. Preserve transient HP loss, reject comparisons across changed bodies/max HP, and do not attribute ambiguous overlapping replies by time alone.
- Treat overlapping ability damage as unassigned real feedback instead of training ordinary-bite cadence with it.
- Restore failed Rest entry, renewal and exit handling. Failure does not claim a successful release or hide an outstanding native state.
- Preserve tiny residual negative effects through short replication gaps; explicit zero clears the relevant condition immediately.
- Preserve recovery while merely near other players, as requested for mixpacking. Actual input, capture, minigames, abilities and native eligibility still govern activity.
- Restore character resets, feeding/carry ownership and post-ability movement cleanup.

### Configuration, UI and lifecycle

- Restore transactional config leases, numeric validation, identity checks for replacement nested profiles and external-edit preservation.
- Preserve native base healing/condition rates, saved OFF preferences and configurable reach.
- Reject unrelated primary settings objects; read back and compare backups before replacing primary settings.
- Restore scrolling/fitting on smaller viewports, drag clamping, touch reopen, stale-overlay hiding and Cobra-specific indicator colors.
- Restore partial camera/audio write rollback. Detached voice emitters are restored without repeatedly multiplying attenuation when reattached.
- Continue independent cleanup after a release fails and retain the cleanup errors.

### Packaging and evidence

- Reconcile the latest feature branch with omitted 16.0.2 reliability changes while retaining Territory 0.8.0.
- Restore all three omitted overhaul suites plus distinct behavioral cases, and add focused input/lifecycle/review regressions.
- Require the complete suite inventory so future branches cannot silently drop regression coverage.
- Use version.json for candidate version, Territory version, game baseline and Luau toolchain pin.
- Inject a deterministic source fingerprint into the hub and own-character report. Reports use the actual controller version and preserve unknown combat state.
- Verify source parity, deterministic rebuild, protected rollbacks, both test reports and exact commit content before producing a pinned candidate record.
- Keep the stable launcher and all earlier versioned bundles unchanged.

### Validation limits

All automatic verification results belong to the exact code identified in candidate.json. The candidate is not represented as live-verified: server-accepted repeat attacks, damage, recovery multipliers, Territory yield, voice audibility and long-session device performance remain unverified.
