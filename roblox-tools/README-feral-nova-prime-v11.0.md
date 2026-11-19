# FERAL NOVA PRIME v11 — consolidated, single-download release

**Game:** FERAL Animal Survival — PlaceId `108901361810209`  
**Version:** v11.0, November 19, 2026  
**Status:** Luau-compiled and mock-tested. **Not** live-tested inside the user's Roblox/Velocity session; server-side permanent regeneration has **not** been established.

## Recommended short Velocity launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v11.0.lua"))()
```

This is the **single-file build**: one download loads eight bundled, version-pinned modules without making separate HTTP requests for dependencies. The standalone file is checked byte-for-byte against its source modules in CI.

The older multi-download [v11 loader](feral-nova-prime-v11.0.lua) remains a fallback, but the standalone version is the recommended release.

**Before first use:** If you loaded v7 or v8's HITBOX TEST, fully quit the old FERAL Roblox session and rejoin once. Those versions locally enlarged other animals' root parts. If old cleanup was interrupted, their local collision geometry may persist in that session. No later script can safely guess an unknown original target size.

## What was fixed, what is still conditional

| Area | Implementation in v11 | Is the desired server advantage proven? |
| --- | --- | --- |
| Local collision and hitboxes | No other animal part Size/CanCollide/CollisionGroup edits; read-only geometry and ray-obstruction diagnostics | Physical safety code validated offline; a fresh live-session comparison is still needed |
| Auto Escape | v9 directional `FeralShakeTaps`, tug, carry action selection based on own character state and native intervals; records progress/release | Native requests observed previously; faster guaranteed release against Tiger **not** established |
| Bite damage/range | Client-only target marker and attack observations; no fabricated BiteHit or root-size hacks | **No** server damage/reach extension claimed |
| Endurance | Single opt-in local stamina recovery/no-drain configuration | Server-authoritative unlimited stamina **not** established |
| Recovery while moving | **NEW MOBILE RECOVERY** performs a bounded moving A/B test, checks real health/status decline, and attempts to maintain the native Rest signal only after a measured uplift | **Unconfirmed** until a real FERAL test demonstrates one |
| Normal safe Rest | Separate small **SAFE REST** button for ordinary native Rest: health below max, or injury/bleed/venom, or stationary Turtle shell | The game's normal resting bonuses are supported; this is not always-on recovery |
| Turtle defense | Reads native `WolfRest` and `WolfRestAt`; displays the archived 0.30 damage-rule condition | No verified permanent protection while moving or fighting |
| ESP | 3D outline-only highlights, tiny screen-projected nametags with close-range fallback | A client-visual function; server-side effects not relevant |
| Agility / Clear View | Reversible local speed/leap/injury-slowdown settings and visibility edits | Local changes are not guaranteed to pass server movement validation |

## The actual moving-recovery experiment

We previously conflated the game’s built-in Rest bonus with the feature the user requested. That was incorrect. From the archived client:

- `NeedsConfig.HEALTH_REGEN=0.01`, `HEALTH_REST_MULT=2`
- `StatusConfig` nominal `INJURY.REST_MULT=4`, `BLEED.REST_MULT=4`, `VENOM.REST_MULT=4`
- `WolfController` sends `WolfActions:FireServer("Rest", boolean)` but also writes a **local** `WolfRest` attribute and **refuses bites** when it considers itself resting.
- Server validation and its recovery timers are absent from the exported client. Simply changing `NeedsConfig` or `StatusConfig` locally does not prove server-authoritative healing.

The earlier v1.4 experiment sent two Rest requests in each of two stopped loops and reported `effectiveness=not_established`. It did **not** prove a working always-on bonus. The subsequent v10 report measured about 2.19 HP/s while resting and 1.04 HP/s outside Rest — consistent with the ordinary built-in 2× effect, not an always-on advantage.

### Mobile Recovery v11

**OFF at startup** to avoid surprise combat penalties.

When the player deliberately enables **MOBILE RECOVERY** with a living animal:

1. It waits for movement and some recoverable deficit (missing HP, active injury, bleeding or venom). It does not fabricate damage or status effects.
2. Collects around **4 seconds of moving recovery baseline**, while normal Rest is disabled.
3. Sends **one native `Rest=true` signal** (does not locally set the `WolfRest` attribute) and measures around **7 seconds of moving recovery**.
4. Sends `Rest=false` and observes around **3.5 seconds afterward**.
5. Requires a large enough observed health or status-decay uplift against the baseline and, where possible, the post-signal period.
6. If an uplift is observed, it enters **bounded-interval mobile signal sustain** (one native Rest=true per five seconds while the test is active). An observed uplift is a **candidate**, not guaranteed server acceptance.
7. If no improvement is observed, or if gameplay conflicts occur, it stops and releases its owned signal.

Safety controls: if actual local `WolfRest` becomes true, it immediately releases its signal because normal bites may be blocked. It also stops on Mouse1/Mouse2 or other ability keys, grabs, death, character change, loss of movement, input errors, or game shutdown. The module never writes health, status values, other players' parts, or currency.

This is the strongest defensible client-side attempt available from the captured protocol; it may show **no measurable benefit**, and if so the hub reports **NOT SUPPORTED BY MEASUREMENT**, rather than declaring success.

### SAFE REST fallback

The small quick-strip **SAFE REST** toggle uses v10's stationary Rest assist. It can activate at damaged HP, active injury/bleed/venom even with full health, or for a safely stationary SnappingTurtle wanting the shell condition. If you turn it ON, Mobile Recovery is turned OFF and its signal cleaned up; if you turn Mobile Recovery ON, SAFE REST is turned OFF.

The game may block bites while actual Rest is active, so this is not meant for use while chasing or attacking.

## Copy Status and testing

**COPY STATUS** includes:

- Escape requests, time-grabbed, actual `FeralShakeHave` progress, observed release events;
- Bite starts, HP changes, read-only nearest root collision, optional ray obstruction category;
- Passive HP, injury, bleed and venom recovery rates, status configuration if available, local Rest transitions;
- **Mobile** baseline, signal and post-signal HP rates, status decline rates, attack/grab safety stops and evidence classification;
- ESP tag counts; Endurance/Agility states.

No other player identities, chat logs or precise positions are exported. A tool request being sent is never reported as server-accepted damage/healing.

## Reproducible offline validation

- Official Luau 0.747 compiler passes for the engine, power, native escape, combat guide, safe Rest, mobile trial, screen nametags, v11 UI, multi-download launcher and **single-file bundle**.
- Standalone build embeds exactly eight source modules, verified **byte-for-byte** in GitHub Actions.
- Luau unit tests check mobile recovery-rate classification, native Rest signal, baseline moving state, immediate cancellation on attack and cancellation when actual `WolfRest` would block bites.
- The prior successful v10 workflow also tests native grab handling, target geometry, read-only collision investigation and normal Rest cancellation.

**Limits:** Neither GitHub nor these offline tests can run Roblox on the user’s PC, access FERAL's private server-side scripts, or prove live permanent recovery, anti-grab instant escapes or increased server-authoritative hit range. No such guarantee is made.

## Source links

- [Single-download v11](feral-nova-prime-standalone-v11.0.lua)
- [Multi-download v11 fallback](feral-nova-prime-v11.0.lua)
- [Mobile recovery controller](feral-nova-mobile-v11.0.lua)
- [v11 UI](feral-nova-prime-ui-v11.0.lua)
- [v10 read-only combat/collision audit](feral-nova-combat-v10.0.lua)
- [v10 normal Rest/status tracker](feral-nova-recovery-v10.0.lua)
- [v9 native escape](feral-nova-escape-v9.0.lua)
- [v8 near-camera ESP tags](feral-nova-tags-v8.0.lua)
- [v11 CI workflow](../.github/workflows/feral-nova-prime-v11-validate.yml)
