# Renaissance 15.2.0 — release record

Released source: [21da4732f05897c7225fde2ffd6ea81d02be6b1b](https://github.com/GSVexed/vexed-schematics/blob/21da4732f05897c7225fde2ffd6ea81d02be6b1b/roblox-tools/feral-renaissance-v15.2.0.lua). The launcher pins that immutable source. Compilation, all 99 service-boundary regressions, deterministic packaging and rollback checks pass locally and in [published source CI](https://github.com/GSVexed/vexed-schematics/actions/runs/45494741846). The finalized loader was also locally checked before promotion.

## Changes

- ESP and hub name tags remain restricted to real players, checked against actual player-character ownership. Pack NPCs receive no hub overlays.
- Hollow outline colour follows current health from green through yellow to red. Floating health percentages and distances are removed. Plain names retain pack colour.
- Recovery yields during the native approach to food/water, not only after the feeding animation starts.
- A user-started stationary feeding session with no observed resource increase can receive one native stop/start repair. Actual hunger/thirst increases are tracked; values are never overwritten.
- Clicking near a feeding offer remains an attack input. Attacks can cancel the original native feeding state before the ordinary bite callback.
- A bite blocked by the recent Rest exit can retry once through the original native tryBite after the native lock. Capture/cooldown/other native guards remain.
- Known friendly/protected targets are excluded from the modified client bite geometry; current positions and the native target score replace stale/different guide calculations.
- Premature predicted hit impacts are disabled while genuine game hit replies remain. HP baselines start at the native marker so a quick decline is not missed.
- G can select an eligible friendly cub in water, request one ordinary jump if needed, wait for actual water-exit eligibility, and submit one native pickup. A native carry attachment is observed separately. Ordinary carry/drop remains native.

The 21 retained feature records, four tabs, Right Shift, saved settings and permanent reach remain. CLEAN v14 and complete 15.0.0/15.1.0 source bundles are unchanged. No removed full-resource, automatic food-seeking or oversized-carry feature is restored.

## Validation

| Gate | Result |
|---|---|
| Local compile | 13 modules, 2 fixtures, versioned bundle and launcher pass |
| Local regressions | 99/99 pass |
| Embedded source parity / rollback hashes | Pass |
| Published source CI | 99/99 pass; deterministic bundle passes |
| Actual executor staging | Earlier candidate passed; final native lookup remains unconfirmed |
| New gameplay efficacy | Unverified |

The fixtures follow the captured native client contract. They are not a private-server test. Earlier candidate dcb1714 passed actual Potassium hidden staging and colour checks while retaining the active hub. A later native-function investigation exposed mixed heap enumeration and led to the callback-first lookup fix. The final pinned source request and a print-only transport request received acknowledgements without exact console results. No further broad diagnostics or manual test request was made. Earlier-version results do not establish final-source native compatibility; LIVE_EVIDENCE.md preserves the exact boundaries.

## Use

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()

Use E/native controls to eat or drink. The hub protects that session and watches real progress. G keeps normal carry/drop; near an eligible friendly cub in water it can make a bounded rescue attempt. Right Shift controls the same compact window.

## Limits

Reduced live ghost-hit frequency, repaired hunger/thirst progress, water-cub pickup, extra accepted reach and real continuous 4x condition recovery remain unverified. The cub action preserves native eligibility and cannot certify universal pickup while swimming/submerged. Species water rules or other server checks can reject it; move or jump to the bank when shown. A request is not reported as an observed pickup without the matching native carry attachment.

Native-function access requires supported executor inspection. Without it, feeding intent still protects the approach, but native restart and post-Rest bite retry may be unavailable. Existing pin, clamp, cooldown, venom and post-Rest rules still apply. Right Shift may still overlap native raw sprint polling. Only locally replicated player characters can be rendered.

## Rollback

Previous Renaissance 15.1.0:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/552995031659c52e36bf8bda436d0d07d348abd6/roblox-tools/feral-renaissance-v15.1.0.lua"))()

Original CLEAN v14:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/158474ba80c0d613c3427399f24059341369acc8/roblox-tools/feral-nova-v14.0-clean-reach-core.lua"))()

These loaders retire the active Renaissance owner before activation. The older complete 15.0.0 bundle remains available at source 59e0a6d0db6d1a9e8c9f57f7a8368e858f8ec600. Avoid stacking independent legacy hubs manually.

## Records

release.json identifies the released source/hash and source CI run. test-results.json contains every scenario result. FEATURE_AUDIT.md, ARCHITECTURE.md, V15_2_INTERACTIONS.md and LIVE_EVIDENCE.md distinguish local behavior, native responses and gameplay outcomes.
