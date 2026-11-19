# FERAL NOVA PRIME v28.0 — Preserved Full Hub / Evidence-Driven Release

**Roblox:** FERAL Animal Survival (`108901361810209`)  
**Published:** 19 November 2026  
**Deployment:** One standalone 17-module Luau script, published as a versioned file with rollback preserved.

## Launch (Velocity)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v28.0.lua"))()
```

**IMPORTANT WHEN MIGRATING FROM v27 OR OLDER:** Rejoin Roblox once before loading v28. Older standalone releases could destroy the visible GUI without terminating all old module loops. v28 adds an `FERAL_NOVA_PRIME_ACTIVE` lifecycle registry, which safely closes a previous **v28 or newer registered instance** on reload. It does not claim to retroactively terminate unregistered older instances.

## Preserved functions — no replacements

13 original non-UI, non-flight v15 modules are still embedded *byte-for-byte*. They contain:

- **Original Endurance:** `WolfDbgNoStamina`, cached land/air stamina recovery and sprint/jump cost modifications.
- **Health:** guarded native Rest-signaled recovery plus the established 2× client regeneration config.
- **Negative conditions:** the established 4× locally configured `HEAL` (injury), `CLOT` (bleed), and `FADE` (venom) recovery inputs.
- **ESP:** player outlines and nametags, range, through-wall option and lifecycle cleanup.
- **Auto escape:** hostile grab handling and same-species friendly baby carrying exception.
- **Quick Climb:** Q-buffering and action-priority protection.
- **Combat, nonphysical reach, native carry:** existing v15 behavior.
- **Flight, Clear View, Agility, recovery/Rest and mobile trials:** maintained existing integrations.

Additional v28 modules are `feral-nova-flight-v28.0.lua`, `feral-nova-mechanics-v28.0.lua`, `feral-nova-diagnostics-v28.0.lua`, and `feral-nova-prime-ui-v28.0.lua`.

## Water flight: surface takeoff without underwater flying

- **On the surface:** If a flying animal is swimming/floating within a verified water-surface range, the hub supports normal Jump-triggered takeoff via the game's `FeralFlyRequest` attribute.
- **Underwater:** If the water surface cannot be verified or the animal is submerged, the hub blocks its extra takeoff request.
- **If flight continues underwater:** Requests the game's native `FeralFlyDrop` action; restores its temporary `WATER.NO_TAKEOFF` lease and temporary air-carry configuration.
- **New:** Tracks whether `FeralFlyLocal` actually turns off within 2 seconds after the drop request; reports confirmed versus unconfirmed exits.
- **No global water modifications:** The original `WATER.GRACE` setting is never modified. The temporary takeoff allowance is restored after takeoff, timeout, shutdown or character change.
- **No teleports or geometry modification.** If terrain-water surface detection fails, the hub blocks the supplemental water request rather than risk underwater flight.

Offline simulations verified the source logic, but whether the game consumes the native drop reliably on every water entry still requires live FERAL evidence.

## Eagle experiments — separate local edit versus observed outcome

The local Eagle Growth / Carry / Talon CD settings remain **optional and OFF on launch**; server behavior is not asserted.

v28 improves their integrity and displays:

- Number of local config values successfully changed and still holding.
- Number of changed fields subsequently overwritten by another controller.
- Actual `FeralLungeCdTotal` samples in groups near 1.5 seconds and near 60 seconds.
- Growth progress per minute with the local growth option on versus off (only within continuous sessions).
- Evidence of outgoing held prey or grab events, separate from a local CATCH display.

### Important observation from the v26 private report

With the experimental Talon CD feature ON, the observed `FeralLungeCdTotal` repeatedly jumped between approximately 1.5 seconds and 60 seconds. A client-only 1.5-second setting therefore **must not** be represented as a proved shorter server cooldown. v28 records such transitions explicitly.

## Recovery and endurance measurements

Unlike v26, which divided observed healing across whole wall-clock periods (including time at full health), v28 separately records:

- **HP gained per second while already wounded**.
- Bleed and venom clearance per second while the relevant effect was active.
- Config-only, Native-only, Native+Config and Neither health recovery modes.
- Own stamina gained/lost while **flying**, **swimming** or **land/other**, split by whether `WolfDbgNoStamina` is active.
- Whether the original cached Endurance lease still appears applied.
- Real growth progress per minute, split by experimental Growth enabled/disabled.
- Talon cooldown total field source (own Player or own Character), raw value transitions and observed distribution.

These measurements can support A/B conclusions when enough comparable conditions exist. They don't prove which system authored a value or whether the server accepted an altered growth/carry/cooldown rule.

## Automatic private diagnostics — no manual uploads required for retrieval

v28 saves a JSON report in the Velocity workspace using `writefile`, by default every 25 seconds:

`FERAL_NOVA_v28_session.json`

Only local own-character measurements are retained: no usernames, UserIds, chat, tokens, exact positions or other player details. In-game Luau has **no network upload code**.

The user's existing Windows self-hosted GitHub Actions runner reads the dedicated v28 report using `.github/workflows/feral-v26-private-diagnostics-collector.yml` in the **private** repository `GSVexed/chatgpt-minecraft-testlab`. It validates the v28 schema, then synchronizes its latest valid copy into:

`diagnostics/feral-nova/latest.json`

Collector polling is scheduled about every 5 minutes (GitHub's schedule is not exact). Unchanged report hashes are ignored to avoid unnecessary Git history writes.

**ChatGPT can retrieve the private report upon a new message through the connected GitHub tool, but cannot spontaneously post chat replies from the runner.** The collector does not publish data to the public `vexed-schematics` repo or embed credentials in Roblox.

## Control guide

- **Right Shift:** hide/show the hub.
- **CLOSE:** full shutdown and local setting rollback.
- **End:** emergency shutdown hotkey.
- **✦ NOVA:** reopen hidden hub.
- **SAVE DIAG:** save the current own-character JSON locally.
- **COPY DIAG:** copy an immediate summary for fallback.
- **AUTO FILE:** enable/disable local 25-second saves.
- **SURFACE FLY:** toggle the floating-surface takeoff assistant.
- **GROWTH, EAGLE CARRY, TALON CD, PRESET:** experimental local settings.
- **REGEN 2x / 4x, ESP, REACH, QUICK CLIMB, BABY CARRY:** restored original controls.

## Validation and limitations

Offline GitHub CI checks:

1. Official Luau compiler on all 17 standalone components and combined release.
2. Exact 17-module standalone/source equality.
3. Byte-for-byte preservation of 13 untouched original v15 modules.
4. Machine-readable `FERAL_NOVA_PRIME_FEATURE_MANIFEST_v28.json` listing all 17 modules and 25 mandatory features.
5. Simulated surface takeoff, temporary lease restoration, native underwater flight-drop request and acknowledgement.
6. Simulated own-character sampling, regeneration/stamina/status rollups, autosave, clipboard and cleanup.
7. Simulated Eagle mechanics toggles, presets, local readback and rollback.

The v15, v26 and v27 releases remain available as immutable rollback points. Never call a locally modified field “server verified.” Never drop a previously working module without documenting and testing its replacement.
