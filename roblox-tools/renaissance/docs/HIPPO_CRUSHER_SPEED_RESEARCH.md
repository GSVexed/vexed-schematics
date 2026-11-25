# Hippo Crusher Bite movement slowdown — v2412 evidence

Date: 2026-11-25. Research only; no live movement mutation was attempted.

## Evidence recovered from the user's complete v2412 bytecode capture

- `game/ReplicatedStorage/FeralWorld/AbilityConfigBase` (capture script ID 15, Luau v14): a verified constant-table template for the `CrusherBite` definition contains `SPEED_CAP = "trot"`. The key and value are associated directly in the serialized template, not merely neighboring text strings. Other keys include `CHARGE_TIME`, `STAGES`, `OVERHOLD`, `LUNGE` and `FREEZE`.
- `game/Players/LocalPlayer/PlayerScripts/FeralHippoClient` (ID 4648) consumes `CrusherBite`, `FeralCrushAt`, `FeralCrushBiteAt` and the native charge/release/hit state; it does not contain a literal `SPEED_CAP` lookup.
- `game/Players/LocalPlayer/PlayerScripts/WolfController` (ID 4662) consumes `FeralCrushAt` and `FeralCrushBiteAt` and computes general locomotion, but its captured string table also lacks a literal `SPEED_CAP` lookup.
- The published AbilityConfig module (ID 101) refers to `CrusherBite`; the relevant config might also be used by server-side logic unavailable in the client capture. Editing its local copy would not necessarily change the server's rules.
- Existing Renaissance `mobility` changes `NeedsConfig.HURT_SLOW` and `StatusConfig.INJURY.SLOW_PER_POINT` only. The separate `speed` feature modifies `NeedsConfig.RUN_SPEED` and `SWIM_SPEED`. Neither feature has Hippo Crusher Bite-specific coverage.

## Meaning and limitations

The game's own Hippo config explicitly caps movement at the trot tier during Crusher Bite. It is a credible cause of the user's slowdown but *not* proof that a client-side rewrite will affect physical movement or be accepted by the server. The capture does not include the authoritative server movement/ability handler. A local animation or HUD speed change is not a successful movement-speed repair.

## Proposed safe experimental path (not implemented or released)

1. Establish the authoritative trigger and release window by observing `FeralCrushAt`, `FeralCrushBiteAt`, native movement mode, actual horizontal speed and server position correction during one legitimate Hippo ability. Measure normal walk/trot/run for comparison.
2. Only if the client uses a writable speed-tier input, test a **reversible, Hippo-only** faster native cap using the existing exclusive lease owner and original controller input; preserve the charge/release timing, damage rules, cooldowns and all other animals.
3. Reject unknown enum tiers and altered schemas. Never spam `WalkSpeed`, re-fire ability remotes, block the native state attribute, patch global species movement, or add a permanent render-loop tug-of-war.
4. Accept only if real horizontal travel improves through the full hold/release window *without* server correction, ability cancellation, pose regression or side effects after disable, respawn or hot reload. Otherwise revert and report unverified.

## Release decision

Do not silently add an untested speed patch to 15.4.1, especially when the user has emphasized zero regressions. The 15.4.1 stamina deduplication fix can proceed independently; Hippo speed remains a separate investigated goal.
