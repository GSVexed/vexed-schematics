# FERAL Aurora v2.0 — Command Center

A rebuilt client-side FERAL menu with an original dark-glass Aurora design,
**nine sections**, **74 catalogued mechanics** and an opt-in local player-finder overlay.
It retains the most useful, evidence-backed features while keeping the
problematic older stamina-pool experiment separate.

## One-line Velocity launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-aurora-hub-v2.0.lua"))()
```

Run in FERAL 🐺 Animal Survival (PlaceId `108901361810209`).
It closes the older recognised FERAL hub/lab panels with their cleanup hooks
before starting. Re-running the launcher closes the previous Aurora hub and
restores its owned changes. No server-side code is downloaded.

## Navigation & UI polish

| Page | What's there |
| --- | --- |
| HOME | Live species, stage, mode, health, stamina, hunger, thirst, growth, Amber, active conditions, running switches and nearby-player count; shortcuts |
| RECOVERY | Native Recovery Assist; survival alerts; current bleed, venom, injury, exhaustion and Rest signal indicators; transparent Rest multiplier research |
| MOVEMENT | One-click calmer camera, brighter view, native performance mode; optional client injury-slow, 1.10× run/swim and 1.10× leap experiments |
| PLAYER FINDER | Floating nametags, animal species, player distance, health bars and colour-coded character outlines; visible-only/through-wall mode; nearest-player list; range selector; subtle/bold outline styles |
| AMBER | Own replicated wallet, 1×–3× survival-multiplier estimator, normal earned rewards and guide shortcuts, grazing/home-turf research |
| PROGRESSION | Current growth and stage, Thriving timer, Regrowth allowance, elder scaling and littermate/disabled-system reference |
| WORLD | Home Turf and Grazing status, territory bonuses, compass directions to 18 recorded points of interest; no forced travel |
| ATLAS | Search 74 recovered mechanics: Recovery, Economy, Progression, Territory, Abilities, Hidden. Filter categories, page through results, favourite entries |
| SETTINGS | Teal/violet/coral accents; interface scale; comfort preset; status-copy fallback; one-click restore; help and session activity |

Designed for desktop and smaller screens. Header is draggable. Buttons have a
subtle hover shimmer; the window auto-fits viewport size. The accent, scaling,
range and favourite mechanic entries can persist through
`FERAL_Aurora_Preferences_v2.json` **when Velocity supports writefile/readfile**.
Gameplay tools are NOT auto-enabled from saved preferences.

**Right Shift**: show/hide the hub. A floating `✦ AURORA` chip is shown while
hidden. **X**: cleanly closes everything. **RESTORE ALL**: turns off the
hub-owned gameplay and overlay modifications and leaves the interface open.

## Player Finder: Nametags and outline ESP

1. Open **PLAYER FINDER**, then enable the main switch. It starts OFF.
2. Leave **AESTHETIC NAME TAGS** and **CHARACTER OUTLINES** on or toggle them
   independently.
3. Select range **150 / 300 / 600 / 900 studs**.
4. Select **SUBTLE** or **BOLD** outlines.
5. Enable **THROUGH-WALL VISIBILITY** only when you deliberately want
   always-on-top tags/outlines. Default is visible-only.
6. Disable **PLAYER FINDER** to remove all created highlights/nameplates.

Nameplates show a replicated player's display name, their current character's
`Species` attribute if present, distance and current Humanoid health fraction.
Highlights are teal (near), amber (middle) and coral (far). There is a capped
**24-player** nearest-player list. Rendering updates about every 0.35 seconds.
Only players whose character and root/health data are **currently replicated**
to your client can be displayed; this does not read hidden server players or
supply their private state. A client-local Workspace folder owns the Highlight
instances, and BillboardGui tags stay in PlayerGui, following Roblox's
rendering guidance. Removed/changed characters are cleaned up. Nameplates and
highlights use local client rendering; there are no outbound calls for ESP.

Note: any executor/game policy or Roblox feature rendering limits can affect
availability. Compilation is not evidence of live compatibility.

## Which switches actually change something?

**Available native/client controls** (opt-in):

- Recovery Assist: sends the game's standard own-character `Rest=true`
  request at most every five seconds when missing HP or suffering a tracked
  condition; masks the own local Rest pose. It sends `Rest=false` cleanup
  when the current recovery episode ends. Client request success is not
  proof of server Rest acceptance.
- Calm Camera: sets the own local camera shake/sway settings; restores
  the original values where still owned.
- Brighter World: creates a local ColorCorrectionEffect in Lighting.
- Native Performance Mode: requests the game's own local performance setting.
- Injury Slowdown Inputs: changes two client cached movement inputs
  (`HURT_SLOW` and `INJURY.SLOW_PER_POINT`) if available; **not** injury
  removal or server immunity.
- 1.10× Speed Inputs: reversible cached `RUN_SPEED` and `SWIM_SPEED` values;
  movement still subject to server constraints and potential corrections.
- 1.10× Leap Inputs: reversible cached leap-distance/cap fields; not flight
  and not a double-jump unlock.
- Player Finder / Nametags / Outlines: locally rendered overlays only.
- Survival Alerts: own low-needs/exhaustion warnings.

No tool is guaranteed to prevent death. The previous unexplained Burst deaths
are unresolved. The old Recovery Hub v1.3 3× stamina tuning is **not loaded or
enabled** by Aurora. That prior file is preserved separately.

**Information-only systems**: Amber multipliers and amounts, passive species
abilities, Thriving, Regrowth, Elder perks, territory damage buffs, owned-coat
unlocks, disabled Quest/Litter/King Cobra branches. Aurora displays documented
config values and replicated status but **does not** grant server Amber, growth,
damage, paid entitlements, ownership, hidden abilities or permanent Rest.

The survival multiplier estimator operates on **hypothetical eligible minutes**;
it does not write an in-game multiplier. Grazing +20% and Home Turf +10%
damage, and Amber reward rates, are captured **configuration** values and not
asserted as live server effects or definitely stackable.

## Repository modules

- [Launcher](feral-aurora-hub-v2.0.lua)
- [Engine and player finder](feral-aurora-engine-v2.0.lua)
- [Custom UI](feral-aurora-ui-v2.0.lua)
- [74-entry mechanic atlas](feral-aurora-atlas-v2.0.lua)
- [Compilation and static workflow](../.github/workflows/feral-aurora-validate.yml)

## Validation and limitations

The GitHub Actions workflow compiles all four modules using official Luau
0.747 and checks required UI/ESP controls, cleanup and absence of health,
wallet, gift, purchase and arbitrary server-grant writers. **These checks have
passed.** No live Roblox/Velocity execution is possible from the CI sandbox.

The recovered FERAL client export contains many configuration and controller
bodies, but **not** its private server health, combat, entitlement, Rest and
anti-cheat handlers. Atlas entries distinguish observed behaviour, configurable
values, client-only effects, permission-gated features and disabled source
branches. Neither presence of a feature nor editable client settings guarantee
server acceptance.
