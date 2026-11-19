# FERAL NOVA PRIME v25.0 — Full v15 Restoration + Mechanics Lab

**Game:** FERAL Animal Survival · **Place ID:** `108901361810209`
**Source:** `roblox-tools/feral-nova-prime-standalone-v25.0.lua`

## Single-line launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v25.0.lua"))()
```

This is a self-contained 16-module Luau release. It is based on the complete, previously validated v15 standalone source, **not** the incomplete v16–v24 rebuilds.

## Preserved v15 source components

The first 14 original non-UI modules are preserved **byte-for-byte** in the v25 standalone bundle:

| Feature | Source module | Default |
| --- | --- | --- |
| Core state, player discovery, ESP outlines and display manager | `feral-aurora-engine-v13.0.lua` | On (ESP) |
| Endurance: stamina no-drain flag and cached stamina profile | `feral-aurora-power-v14.0.lua` | On |
| Automatic victim escape with friendly baby handling | `feral-nova-escape-v15.0.lua` | On |
| Attack-input and bite reach validation | `feral-nova-combat-v15.0.lua` | Diagnostic monitoring |
| Native Safe Rest (separate from active Rest-signal recovery) | `feral-nova-recovery-v15.0.lua` | Off |
| Mobile A/B recovery trial | `feral-nova-mobile-v15.0.lua` | Off |
| Native G carrying (victim versus holder states) | `feral-nova-carry-v15.0.lua` | Available |
| Reversible nonphysical bite reach configuration | `feral-nova-reach-v14.0.lua` | On |
| 2× cached health configuration and 4× status HEAL/CLOT/FADE | `feral-nova-regen-v15.0.lua` | On |
| Bald Eagle water takeoff and prey retention coordination | `feral-nova-flight-v15.0.lua` | On |
| Native Rest-signal recovery, masked pose and action handoff | `feral-nova-native-recovery-v15.0.lua` | On |
| Same-species friendly baby carrying protection | `feral-nova-baby-v15.0.lua` | On |
| Native Q-buffered Quick Climb | `feral-nova-climb-v15.0.lua` | On |
| Screen-projected ESP nametags, distance tracking | `feral-nova-tags-v8.0.lua` | On |

The v15 UI was extended as `feral-nova-prime-ui-v25.0.lua` to expose **REGEN 2×/4×** and mechanics controls. The additional module `feral-nova-mechanics-v25.0.lua` is new.

## v25 interface

- **Right Shift:** hide/show main hub.
- **X:** fully close hub and request local lease restoration.
- **End:** alternate complete shutdown.
- **✦ NOVA:** reopen a hidden menu.
- ESP controls: TAGS, WALLS, RANGE.
- Existing control cards: ENDURANCE, AUTO ESCAPE, OUTLINE ESP, AGILITY, ACTIVE RECOVERY, CLEAR VIEW.
- Existing quick actions: REACH, WATER FLY, SAFE REST, native G carrying, QUICK CLIMB, BABY CARRY, COPY STATUS, RESET.
- Added settings row: REGEN 2×/4×, GROWTH (LOCAL), EAGLE CARRY (LOCAL), TALON CD (LOCAL), PRESET.

The HUD resizes with the game viewport, and the experiment controls are off by default.

## Experimental Eagle mechanics — local-only

The new mechanic module changes locally loaded configuration values, with original values tracked and restored on disable/reset/close **when they have not been modified again by another controller**.

- **Growth:** Eagle `Species.ADULT_MINUTES`, `GrowthConfig.ELDER_RATE` and `CUB_BOOST`.
- **Carry:** `AbilityConfig.Talon.CARRY_RATIO` and `NO_ELDER_LIFT`.
- **Cooldown:** `AbilityConfig.Talon.FLAT_COOLDOWN` and `FlightConfig.STOOP.CD_PICK/CD_CANCEL/CD_EMPTY`, plus other owned numerical Talon cooldown fields.
- **Presets:** conservative (2× growth, carry ratio 2, 5 s cooldown), balanced (3×, 3, 1.5 s) and aggressive (6×, 5, 0.5 s).
- **All three off by default**. Turning them on does **not** prove the live server accepts different growth, carry or cooldown rules.

The original v15 standalone makes no physical enemy Part.Size edits. The v24 optional local hitbox expander was deliberately **not** incorporated: its effect was not established as server-accepted hit reach, and it could cause local collision/geometry regressions. The maintained v15 nonphysical reach source remains available.

## Integration and preservation tests

The `feral-nova-prime-v25-validate.yml` workflow performs:

1. Official Luau 0.747 compilation for the standalone and each module.
2. An exact 16-module source-to-bundle comparison.
3. A byte-for-byte regression comparison against the 14 untouched v15 core modules.
4. Static checks for Endurance, 2×/4× regeneration, native Rest, ESP, baby carrying, quick climbing, Right Shift, End, and shutdown paths.
5. Mocked Luau checks for the experimental mechanics toggles, presets and local state rollback.

The previously validated v15 workflows remain in the repo unchanged. The original v15 source is preserved as a rollback at `roblox-tools/feral-nova-prime-standalone-v15.0.lua`.

### Important evidence distinction

Source checks and offline Luau simulations are **not live FERAL server tests**. Earlier Endurance, health recovery and status results were observations from earlier sessions; current server acceptance is unverified. No live growth acceleration, larger Eagle pickup, shorter server Catch cooldown, or extended server damage has been proven by this release.

## Known issues / future verification

- Stamina/endurance and 2×/4× regeneration are the recovered implementations, not a new claim of current server behavior.
- Recovery needs native player state and may pause during carrying, climbing, attacks or other priority actions.
- Growth/carry/cooldown controls only patch client-visible configuration and may be ignored by already-cached client or authoritative server logic.
- No browser/container run can replace testing within a live Roblox session.
- Avoid running multiple independent legacy hubs at the same time; v25 attempts to shut down previous v21–v24 rebuilds on startup.

**Do not remove previous features or silently replace modules in future releases.** Compare any new release against this manifest and the unchanged v15 source.