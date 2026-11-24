# Recovery correction — 15.2.1

This patch addresses automatic recovery stopping unexpectedly and a resting pose remaining during movement. HP recovery still yields to combat. Injury, bleed and venom are separate measurements; their native Rest factor is not the HP factor.

## Findings

1. The previous owner stopped recovery for 15 seconds after three Rest echoes within two seconds, even when each echo was masked successfully. Repeated echoes were treated as a pose failure without checking the rendered blend.
2. After release, a Rest echo more than 2.6 seconds later was classified as manual Rest based on elapsed time. That could disable automatic recovery and stop masking an automatic response. The new owner keeps same-character automatic provenance until explicit manual Rest or a character change. Hot reload transfers that provenance from an existing Renaissance owner.
3. Clearing WolfRest does not immediately clear the procedural animation. Current WolfAnimClient.stepRig retains sit, lie and hold blends while standing up. Words 3736–3760 accept WolfDbgRestP as a Vector3 that replaces those three blends. An automatic recovery session now owns a reversible zero override before making its Rest request. It is restored on manual Rest, character changes, shutdown and shortly after release. An unrelated replacement is preserved. Native downed poses are excluded.
4. Rest-key handling previously ran after the native action because those keys were absent from the hub's earlier priority binding. The binding now records manual intent before passing the keys through. Native Rest taps and touch Rest controls also hand ownership back to the player. A brief deferred native state is not immediately mistaken for the end of that manual intent.
5. The old client configuration flattened native Rest multipliers to one and moved their values into the base rate. The patch preserves native HP Rest=2 and condition Rest=4 with ordinary base rates. This retains native Rest semantics and avoids a cosmetic client calculation being presented as an actual health/status improvement. Larger unexpected client factors remain capped at the intended total reference.

## Evidence boundaries

The animation input is grounded in the supplied v2412 bytecode, not a guessed animation ID or a global animation hook. WolfAnimClient fingerprint: 2853919780696efd706e679a08d10a640b2cc00019c6fd4c7e106ce68528cb0f; 155 prototypes; 24-byte suffix. The captured animator binds WolfAnim at the native render priority plus two. The existing hub pose guard runs before that binding.

The regression fixture models the retained blend and supported override. It reproduces the old release leaving a cached Rest blend after WolfRest is false, the late-response ownership error and the unnecessary recurrence pause. It does not execute captured game bytecode or establish another player's view of the pose.

No HP, injury, bleed or venom attribute is overwritten. The row distinguishes watching HP, actual HP increase and a clean window without an observed increase. Damage, growth, combat, movement transitions, character changes and missing condition values do not become cures or multiplier confirmations. Each condition has an independent internal observed rate. Actual progress still leaves 2×/4× efficacy unverified without a comparable native baseline and gameplay evidence.

## Validation

All 111 service-boundary scenarios and 17 compiled files pass locally. Twelve added scenarios cover persistent native pose blends, late echoes, manual priority, Rest taps, exact restoration/external replacement, downed state, native factors, unchanged HP, actual HP progress, independent conditions, hot reload and setter failure. The existing simultaneous bite/minigame, feeding, carry, saved settings and lifecycle scenarios remain included.

Real sustained 2× HP recovery, 4× condition clearance and final rendered-pose behavior require a confirmed live result. The patch never treats a sent Rest request or a successful local mask as that result. Current native attack, feeding, movement and combat exclusions still apply; recovery cannot be described as uninterrupted across those actions.

## Release and rollback

Use the stable Renaissance launcher after promotion. The complete 15.2.0 bundle remains unchanged at source 21da4732f05897c7225fde2ffd6ea81d02be6b1b. CLEAN v14 and its loader, plus complete 15.0.0 and 15.1.0 bundles, remain hash protected. Settings schema 15 and all 21 feature records are unchanged. The 13 deliberately removed features remain absent.
