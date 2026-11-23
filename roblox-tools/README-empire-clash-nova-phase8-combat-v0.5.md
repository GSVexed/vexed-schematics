# Empire Clash NOVA — Phase 8 v0.5 reliability maintenance

**Date:** 2026-11-23  
**Status:** Original Luau source delivered for the ongoing Phase 8 reliability project. **Silent Aim remains experimental and server-unverified. No anti-cheat bypass is implemented or represented as working.**

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/project-empire-clash-nova/roblox-tools/empire-clash-nova-phase8-combat-v0.5.lua"))()
```

This is an existing file in the `project-empire-clash-nova` development branch of `GSVexed/vexed-schematics`. RightShift toggles the panel. Experimental shot correction is still OFF on every startup and is a separate manually selected feature.

## Fixed since v0.4

- **Strict target ordering:** the player distance sorting comparator previously returned `true` for a comparison involving the same selected player twice, violating the comparator contract. It now prioritises selected targets only when exactly one item is selected, then sorts by distance and deterministic `UserId` for ties.
- **Stale selected target:** each selection carries a `sampledAt` timestamp; selections over 350 milliseconds old are rejected instead of leaving a potentially outdated marker, and failed selector updates actively clear the previous selection.
- **Updated eligibility:** selected targets are rechecked for current character generation, living humanoid, team membership, max distance and required local visibility before being displayed or used.
- **Bad saved values:** numeric configuration parameters reject NaN/non-finite values and clamp to supported ranges, falling back to known defaults when necessary.
- **Bad weapon stats:** raw `Accuracy` values that are unavailable or non-finite no longer get displayed as valid measurements.
- **Diagnostics:** a selection age value is available in the local status model; no extra user diagnostic collection is required.

## Existing features retained

- Native reticle approximation and target FOV ring.
- Shared selected enemy, head / torso / adaptive target mode, locally estimated movement lead *for visual preview only*.
- Transparent-fill outline ESP, nametags, selected-target card, team/obstruction checks and controlled visual budgets.
- RightShift draggable interface, saved settings and optional teleport queue.
- An **experimental optional** outgoing shot-ray correction based on the recovered `FireGun` client request. It preserves the native shot call and does not originate extra shots. This does not establish that a server will accept the changed ray.
- Off-by-default experiment, error shutdown and clean GUI lifecycle. A function wrapper may remain inert in memory until the Roblox process ends.

## Anti-cheat and user expectations

The user wishes to avoid bans. We have identified evidence of anti-tamper mechanisms in the recovered client and know Roblox servers may validate the shot independently. Source-side reliability fixes are **not** stealth technology, and no code can be described as undetectable on the evidence at hand.

This version does not disable integrity checks, suppress reports or attempt to conceal modifications. Client-side interception and executor usage can introduce account risk. The safest way to avoid those risks is an unmodified Roblox client.

## Validation requirements

Official offline Luau syntax compilation and source invariants run via `.github/workflows/empire-clash-nova-phase8-v05-compile.yml`. The current build is **not tested in Roblox**, so runtime compatibility, server-hit acceptance, actual headshot damage, detection and ban safety remain unknown.

The user explicitly declined further in-game diagnostics; do not request collector runs, screenshots or telemetry as a condition of this deliverable.

Older builds v0.2–v0.4 remain preserved. The project's private research remains under `GSVexed/chatgpt-minecraft-testlab`.
