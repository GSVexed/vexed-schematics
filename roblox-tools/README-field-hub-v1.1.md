# FERAL Field Hub v1.1

An update based on the user's v1.0 Roblox/Velocity field report. The user
reported working unlimited-stamina behaviour on Bear, overwritten local health
refills, and visible but unusable restricted animal cards. They also confirmed
that the oasis is an ordinary POI they had visited normally.
These are user-reported observations, not independent engine testing.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-field-hub-v1.1.lua"))()
```

The new loader stops the existing v1.0/v1.1 hub first. It restores owned
configuration/appearance changes and stops the old HP-writing loop. The new
panel opens directly. Turn **RESOURCES > STAMINA TUNING** on to use the same
cached tuning that the user reported working. Optional experiments start off.

## Changes

| Feature | v1.1 behaviour |
|---|---|
| Stamina | Same cached NeedsConfig tuning and WolfDbgNoStamina flag as v1.0. Its displayed field result is limited to the user's Bear test. |
| Health | The failed local writer and its toggle are removed. Health is observed only; no working regeneration or invulnerability is claimed. |
| Resource report | Health and stamina decreases have separate counters. Neither counter identifies the writer or proves a server correction. |
| Oasis | Labelled as an ordinary POI. Existing compass, landing checks and experimental one-shot travel remain; no secret protection or healing is claimed. |
| Hidden animal cards | Explicit visibility-only control. It does not grant owner/tester permission, currency, ownership or a playable spawn. |
| Earned amber | LIVE has **OPEN GAME REWARDS**. It requests the native reward UI; use that UI's CLAIM buttons for rewards already earned. |
| Native replies | Optional observation of known reply labels from FeralRewards and FeralSlots. All payload arguments and unrecognised labels are omitted. |

## Actual amber versus a displayed balance

This release does not add an arbitrary spendable balance. The recovered game
UI contains ordinary playtime and daily reward claims. Its eligibility,
requests and payouts remain handled by the existing game and server.

The shortcut sets the same `FeralRewardsRequest` UI request attribute watched
by the captured native client. It does not call reward remotes, claim
automatically, forge playtime or select a currency amount. Opening the native
UI can cause that game's existing `hello` request; clicking its CLAIM buttons
causes its normal claim requests. Existing eligibility and server checks remain.
If the native UI does not open in a particular game state, use the game's own
reward button; the hub does not force the UI or infer a payout.

**OBSERVE NORMAL REWARD / PURCHASE REPLIES** attaches to the two named native
channels if present. It stores at most twelve known event labels. `state` means
a reward state event was seen; `paid` is counted as a native paid notice, not
as an independently verified spendable balance. `poor` and `coatPoor` have
insufficient-amber handling in the captured native clients. Other rejection
reasons are not inferred from missing replies or unknown events.
No full state, error messages, IDs, names, slots, ownership tables or reply
payloads are saved. Observer listeners are disconnected on close/upgrade.

## What remains unresolved

- No working health-regeneration method is established. The local HP trial
  failed in the reported run. The exact authoritative writer was not recovered.
- Phantosuchus/Snow Leopard visibility does not grant purchase or spawning.
  The shared configuration contains owner/tester checks, but the actual server
  spawn handler is unavailable. No bypass or accepted restricted spawn is claimed.
- No arbitrary amber grant, permanent coat/animal unlock, paid entitlement,
  server-backed buff or currency-generator method has been established.
- Local coat trials and previews remain local; the game may overwrite them
  and other clients' views remain unverified.
- Landing checks see loaded geometry and approximate clearance. They cannot
  establish all hazards or server movement acceptance. Travel remains opt-in,
  revalidated, one-shot and unverified for safety.

These limits do not require another comprehensive diagnostic scan. The
existing client export does not contain the unavailable server handlers.

## Other controls

LIVE reads your resources, movement and supported effects. ANIMALS previews
replicated models. COATS loads compatible cached definitions and offers local
preview/appearance trials. FINDINGS contains the previous 26 searchable
discoveries with updated health and oasis context. Right Shift or `_` hides
the panel; the floating button reopens it. X stops the hub and attempts to
restore owned local settings. STOP EXPERIMENTS restores resource, lighting,
menu visibility and coat settings. Completed movement is not reversed.

The optional COPY/SAVE HUB STATUS report now distinguishes the field result,
retired HP writer, separate decrease counters and native reply labels. No
filesystem access is needed to run the hub, and it performs no decompilation or
full game scan.

## Verification

- Official Luau compiler accepts v1.1.
- 12 shared core checks and 30 simulated runtime/upgrade checks pass.
- The upgrade test runs the actual v1.0 source, enables its resource loops,
  upgrades to v1.1, and verifies that the old HP writer stops and owned settings
  restore. Other tests cover cache races, frozen/missing APIs, preview script
  removal, coat restoration, travel refusals, report privacy and observer cleanup.
- Static checks find no direct gameplay remote calls, currency/tester writes,
  health-writing loop, hooks, table unfreezing or player enumeration.
- The v1.0 stamina path has the user's runtime report. **The full v1.1 release,
  native reward shortcut and existing travel/appearance features have not been
  independently tested inside Roblox/Velocity.**

Run `python roblox-tools/tests/test-feral-field-hub-v1.1.py` with the official
Luau CLI available at `FERAL_LUAU`. The v1.0 files remain available for history;
use this loader for the updated behaviour.

Evidence: baseline `S0003658` FeralRewardsUI (normal hello/claim flow,
FeralRewardsRequest, state/paid handlers); `S0003659` FeralCoatsUI
(buyCoat/coatPoor); `S0003625` FeralMenu (poor); and the previously documented
controller, access and location sources. Reconstructed-source fidelity limits
remain in [FERAL-FINAL-ANALYSIS.md](FERAL-FINAL-ANALYSIS.md).
