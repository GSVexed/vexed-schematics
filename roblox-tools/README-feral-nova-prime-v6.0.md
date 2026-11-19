# FERAL NOVA PRIME v6.0

**Current recommended hub.** A single 830 × 528 dashboard for FERAL Animal
Survival (Roblox PlaceId `108901361810209`). No scrolling, no multi-profile
stamina decision, no speculative currency/health/ownership grant buttons.

## One-line Velocity launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-v6.0.lua"))()
```

The launcher checks the FERAL PlaceId, closes the prior v5/v4 and older
Aurora/Field hubs using their cleanup hooks, loads the established v2.1 core
and v3.1 power modules, and attaches the new v6 ESCAPE and UI modules.

## Controls

Exactly six large toggles (one screen, no navigation):

| Control | Actual action |
| --- | --- |
| **Endurance** | Reversible 3× cached client stamina recovery, zero delay and own-character no-drain flag. **One choice, on/off**, no Apex/Stock/Recover profile picker |
| **Auto Escape** | ON by default. Prefers native `FeralLunge:getoff` when the own animal is carried and `FeralLunge:shake` with supported local clamp/shake cues. Uses bounded simulated Space as a secondary fallback. Does not require ALT |
| **Outline ESP** | ON by default, outlines only with transparent fill; no body colour/glow |
| **Agility** | Reversible local 1.30× speed and 1.35× leap input combination, applied or reverted as one |
| **Anti-Slow** | Reversible local injury movement penalty changes, without claiming to heal or remove server-owned statuses |
| **Clear View** | Reversible local brightness/fog adjustment |

ESP also has three small quick options: **TAGS**, **WALLS**, **RANGE**.
Visible-only or through-wall outlines render at up to 450/900 studs for a
maximum of 24 *replicated* living players. The existing engine filters local
characters, maintains its highlight records and cleans up on respawn/close.

The name tags in v6 are no longer fixed 3.35-stud plates: the tag uses the
current replicated animal's Model bounding box to position a small, unboxed,
outlined text label above the mesh. Bounding-box adjustment is cached and
applies only while name tags are enabled. `Highlight.FillTransparency=1`
prevents a glow over the animal's skin/coat.

## Automatic escape reliability improvements

The new `feral-nova-escape-v6.0.lua` distinguishes:

1. **High-confidence native carry**: own `FeralCarried=true`.
2. **Native carry action bound**: `FeralCarryEscape` present on two successive
   native action checks.
3. **Native shake**: appropriate `FeralClampGame`/`FeralClampN` or
   `FeralShakeNeed` cue corroborated with `FeralShakeMash` or
   `FeralTugTap`, or both clamp/shake numeric signals present.
4. **Fallback**: own grab-like attributes, visible on-screen escape prompts
   or a physical joint between own character and another player's character.

Native `getoff` is throttled to ≥0.43 s and `shake` to ≥0.23 s.
Fallback Space pulses are limited to ~8/s. Input scanning is bounded and
rate-limited; it pauses and releases any key during chat, death, selection
menu or hub shutdown. Native mode clears the fallback timer when it ends,
avoiding accidental jumps after an escape.

**This is not guaranteed to escape every grab.** The reconstructed client
names provide evidence of legitimate escape actions, but the game's server
may ignore or validate requests differently. Velocity key injection may be
unsupported. The bottom bar differentiates `WATCHING`, `NATIVE ESCAPE`,
`SPACE ESCAPE`, `INPUT UNAVAILABLE`, and error states.

## Quality-of-life changes

- **Better ESP**: true outline-only fills, name labels above different-sized
  animals, optional tags, and no opaque background plate blocking the model
- **Settings that matter persist**: tags, wall visibility and range are
  optionally saved as `FERAL_NovaPrime_Display_v6.json` through the
  executor's local readfile/writefile support. Experimental power toggles
  are **not** silently enabled on relaunch
- **Low health and low needs**: header highlights conditions under 25% HP
  or hunger/thirst below 20, without altering resources
- **Copy Status**: one small diagnostic button copies own escape counts,
  status/error, stamina/health display and ESP state; no names/account IDs
  or private source uploads. When clipboard is unsupported, emits to console
- **Right Shift** hides/reopens the single-page menu. Reset restores owned
  settings, switches escape OFF and clears local fog. X closes and cleans up

## Evidence and boundaries

The prior field reports support local controller tuning in some Bear/Tiger
movement samples, but do **not** prove server-side unlimited stamina,
permanent Burst survival, anti-cheat immunity or immunity to death. The
previously unexplained deaths during prolonged Burst were not resolved.
Endurance remains opt-in.

Earlier read-only client reconstruction and targeted field trials did not
establish working grants for arbitrary Amber, restricted species, infinite
health or server permissions. This hub deliberately omits fake buttons.

**Testing:** Official Luau 0.747 compilation of the full module dependency
set, static wiring/cleanup checks, and standalone native-escape policy tests
are performed by GitHub Actions. All are *offline*; actual Velocity/FERAL
runtime behavior and whether the game server accepts an escape still need
to be tested by a player in the game.

## Repository files

- [v6 one-line launcher](feral-nova-prime-v6.0.lua)
- [v6 dashboard + display settings](feral-nova-prime-ui-v6.0.lua)
- [v6 automatic escape](feral-nova-escape-v6.0.lua)
- [v2.1 core](feral-aurora-engine-v2.1.lua)
- [v3.1 reversible power module](feral-aurora-power-v3.1.lua)
- [v6 official Luau validation](../.github/workflows/feral-nova-prime-v6-validate.yml)

No automatic GitHub uploads, no local desktop access via runner,
and no access to private server scripts are implied by GitHub Actions.
