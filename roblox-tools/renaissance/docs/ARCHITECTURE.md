# Renaissance 15.0.0 architecture

The v14 rollback is commit 158474ba80c0d613c3427399f24059341369acc8, with its existing clean loader unchanged. This replaces fourteen embedded legacy modules with nine original, independently compiled modules. No raw game bytecode or reconstructed game source is bundled.

| Owner | Responsibility | Lifecycle |
|---|---|---|
| core.luau | Exactly 21 feature records; requested/applied/observed/outcome fields; exclusive patch leases; bounded evidence ledger | One registry, lease map and ledger |
| settings.luau | Schema 15 validation, CLEAN migration, false values, backup and verified writeback | Reads at stage; writes on user changes |
| policy.luau | Local priorities, manual Rest sovereignty, attack windows, AFK eligibility | Shared by every controller |
| grab.luau | Native begin/strike/res/bite/end sessions; deduplication, actual time, own grades | One session per character generation |
| recovery.luau | Native Rest, owned pose mask, deficit and recurrence handling | One Rest owner; no HP/status writes |
| features.luau | All shared client-config edits and own stamina flag | One reversible lease manager |
| roblox.luau | Services, snapshots, module identity, native observers, terrain queries | One heartbeat, one render binding, one small PreAnimation guard |
| ui.luau | Four-tab menu, hollow outlines, separate pack/health cues, tags and guide | One GUI and renderer; at most 24 player records |
| controller.luau | Coordination, preemption, evidence, lifecycle and persistence acknowledgement | Inactive stage, activate, idempotent close |

## Activation and rollback

Every embedded source and interface is validated before accessing the old hub. All new GUI construction and listener attachment happens with the candidate inactive and its GUI disabled. Attach failure unwinds new resources and leaves the previous hub untouched. Stage-only validation never retires the old hub or applies gameplay config.

After all attaches succeed, the bootstrap closes the old hub and activates the candidate. First-frame errors close the candidate and restore owned fields. A legacy hub exposes only close(), so it cannot be resumed after successful retirement; re-execute pinned CLEAN v14 to roll back. This does not promise to resurrect arbitrary closed legacy closures after a later error.

## State and outcomes

Saved settings contain user intent, including true and false. The registry separately acknowledges local application. A requested feature with unavailable config displays WAIT. Linked recovery/effects records use one visible control.

Reach remains permanently requested, even when a compatibility conflict prevents application, and has no disable toggle. Config replacement releases the old table and patches the new one. External writes are preserved and reported.

Combat records intention, WolfBiteAt, a candidate near the expected claim window, native FeralHit feedback and later target HP. In v2412 the marker precedes the native Bite request. The hub does not observe actual outgoing Bite/BiteHit calls and never fabricates them. HP decline is a correlation.

Recovery does not keep Rest primed at full health. Real input releases owned Rest; held attacks prevent rearming. The native post-Rest lock is preserved and reported as a possible blocker. Recovery yields to combat, abilities, climb/flight, capture, minigames and feeding; ground movement alone does not block it. Genuine manual Rest is never masked or cancelled. A pose mask establishes only local presentation.

The local HP reference is capped at 2x total; injury/bleed/venom references at 4x total. Base rates and Rest multipliers are coordinated to avoid 4x-by-4x local compounding. Private server calculations may ignore all client values.

## Work and data bounds

One heartbeat drives timing and slower tasks. Target selection runs at most about eight times per second. The renderer projects up to 24 players and a small guide. Terrain safety checks run only for requested idle walks. Pose guards read only the current own Rest attribute.

The ledger retains 160 events and aggregate rate buckets; transaction history retains 32 entries. Rates exclude character, maximum HP, combat, movement and Rest-mode transitions. Missing condition attributes never count as cures. The hub includes no console dump, private capture payload, credential or automatic GitHub upload.

## Right Shift

A single high-priority ContextActionService binding passes through when text is focused. It can consume event-driven sprint bindings. WolfController also polls IsKeyDown(RightShift), which an ordinary CAS sink cannot hide. Native sprint overlap remains a compatibility limitation.
