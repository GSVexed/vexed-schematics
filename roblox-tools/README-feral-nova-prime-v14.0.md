# FERAL NOVA PRIME v14.0 — full-spectrum client upgrade

**Release date:** 19 November 2026. **Target:** FERAL Animal Survival, Roblox PlaceId \`108901361810209\`. **Delivery:** single-download Velocity launcher with 12 version-pinned modules.

## Recommended one-line launcher

\`\`\`lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v14.0.lua"))()
\`\`\`

The standalone version contains its entire dependency tree. No additional network downloads are needed after the first loader fetch; the official Luau validation workflow checks that the embedded sources match their repository originals byte-for-byte.

**Important migration step:** If you ever loaded v7 or v8's physical HITBOX TEST in the current Roblox session, fully leave and rejoin FERAL before using v14. The old scripts could have modified other animals' client-local HumanoidRootPart sizes; v14 deliberately never changes target-part dimensions or collision.

## Comprehensive improvements over v13

| System | v14 implementation | What the private server still decides |
| --- | --- | --- |
| **Virtual Hitbox / Bite Reach** | Expands the cached client \`CombatConfig.REACH\` 1.22×, \`HIT_SCALE\` 1.20×, cone by 8°, slack by .35 and virtual \`bodyGap\` margin by .72 studs; never touches animal physics. Original values restored on OFF/CLOSE. | Whether a particular \`BiteHit\` claim outside normal range is actually accepted as damage. |
| **Read-only Bite Guide** | Computes client bite window, distinguishes normal and extended-only eligibility, counts bite starts and nearby target HP decreases in extended windows, reports current client config values. | Correlated HP decreases are not proof a specific bite caused them. |
| **Non-Rest Regen** | Opt-in/automatically enabled cached input attempt: \`NeedsConfig.HEALTH_REGEN\` 2×, \`HEALTH_NO_REGEN_IN_COMBAT=false\`; \`StatusConfig.INJURY.HEAL\`, \`BLEED.CLOT\`, \`VENOM.FADE\` 4× where readable. Does not enter Rest or write own HP/status attributes. | Server may enforce its own regen, combat and status timers and ignore these client inputs. No permanent 2×/4× benefit has been established. |
| **Evidence-based recovery measurements** | Copy Status separates normal, combat and unclassified non-Rest HP gain intervals and injury/bleed/venom decay rates. Excludes resting intervals, full-health observations and damage-contaminated healing windows. | Changes in observed rates can have other causes; compare similar species/conditions over longer periods. |
| **Endurance for flight and land** | Single Endurance toggle uses 3× cached stamina regen, zero cached sprint/jump costs, no-delay inputs, and the own local \`WolfDbgNoStamina\` flag; reasserts it if the controller resets it while the same animal remains active. | A client debug flag and cached drain input do not necessarily change server-authoritative stamina or damage rules. |
| **Bald Eagle diagnosis** | Tracks which flight or land/swim stamina path is active, total stamina gained/lost, burst seconds, large HP-loss events, stamina-out events and mode changes. | Doesn't infer that birds bypass an anti-exploit check; this tests the user's observation. |
| **Water Takeoff** | Reversible cached \`FlightConfig.WATER.NO_TAKEOFF=false\` and \`GRACE=0\`. When jumping in water, requests native \`FeralFlyRequest\` rather than teleporting or fabricating flight packets. | May be blocked by other native flight conditions or authoritative server validation. |
| **Air Carry** | Temporarily adjusts the **owner's outgoing** \`FeralClamp.Mode\` to \`"drag"\` during takeoff/flight, including prey collected mid-flight, and restores the original value on G/drop, landing, death, shutdown or end of takeoff attempt. | The server still decides whether the carried animal remains attached and whether a takeoff is accepted. |
| **Native Carry / Drop** | Preserves game G key and \`_G.FeralCarryPress\` helper, distinguishing owner holding prey/carcass from victim captured. Does not send invented pickup or drop remotes. Water flight relinquishes its temporary clamp-mode change before G. | Server pickup eligibility and carry/drop acceptance. |
| **Auto Escape** | Own pinned/carry-victim/grab detection with prey-protected outgoing carry; native getoff .435s, tug .12s, shake .17s bounded intervals and observed progress. | No guaranteed instant escape. User specifically prefers *good and believable*, not suspiciously instantaneous. |
| **Turtle** | Keeps Shell condition observer and separate SAFE REST action; it does not automatically enter Rest during fights. | Actual Turtle damage reduction is a server outcome; shell condition alone isn't proof. |
| **ESP / Controls** | Close-camera-safe unboxed nametags, outline-only highlights, clean single-screen UI, one Endurance switch, Agility and Clear View. Adds REACH and WATER FLY quick controls. | ESP and local display features do not modify server combat. |
| **Recovery A/B Test** | Keeps an optional \`A/B TEST\` on the Regen card. It temporarily turns off the non-Rest config patch while comparing movement baseline vs a native Rest signal; it stops on attacks and pauses for carrying, and restores the standard config after a trial. | It is a diagnostic, not a guaranteed working always-on Rest bypass. |

### Evidence from the captured client

- Recovered \`FlightConfig.WATER.NO_TAKEOFF=true\` and \`GRACE=1.2\`: direct local water-takeoff gating, not merely a short stamina bar.
- Recovered \`FeralFlight\` checks the outgoing \`FeralClamp\` mode and its \`"drag"\` path; the normal aerial controller can stop flight when holding prey in other clamp modes.
- \`WolfController\`'s bite-claim selection uses a required local \`CombatConfig\` shared table; v14 edits those math inputs rather than physically enlarging enemy objects.
- \`NeedsConfig.HEALTH_NO_REGEN_IN_COMBAT=true\` and \`HEALTH_REST_MULT=2\` are separate game-client configuration fields. V14 attempts non-Rest regeneration without sending a Rest request in its primary mode.
- \`StatusConfig\` recovered field names are \`HEAL\` for injury, \`CLOT\` for bleeding, and \`FADE\` for venom. Parts of the decompiled StatusConfig were lossy; v14 reports missing fields rather than inventing a rate.
- User's v13 copy report showed Endurance ON but \`WolfDbgNoStamina=false\`. V14's flag maintenance checks the current animal again, not only on character change.
- User's Bald Eagle observation: continuous sprint/burst replenishment without sudden death, unlike some prior land-animal attempts. V14 now measures both paths to clarify if species-specific drain is different.

## What switches ON at launch?

- **On:** Endurance, Auto Escape, virtual bite reach, non-Rest client regeneration inputs, Water Flight, Outline ESP, nametags and the previously retained Agility/Clear View defaults.
- **Off:** Native SAFE REST and experimental moving A/B Rest signals. Neither should unexpectedly block combat or native carrying.
- **Reversible:** Cached local configuration leases and the temporary own outgoing clamp mode restore on OFF/RESET/CLOSE where still owned by the hub. A fresh join remains the surest way to clear an older terminated script's unrelated local edits.

## Tests actually run

The GitHub Actions workflow \`.github/workflows/feral-nova-prime-v14-validate.yml\` uses the official Luau 0.747 compiler to compile all modules and the standalone, verifies all **12 embedded modules** match their source files, and tests:

- Land Endurance RECOVER activates and reasserts \`WolfDbgNoStamina\` when the same character's flag gets overwritten; reset restores original sprint/jump/regen inputs.
- Virtual claim-reach, cone, scale, slack and \`bodyGap\` changes apply and restore without physical part edits.
- 2× health / 4× injury-bleed-venom cached inputs and combat-regen flag apply and restore exactly.
- Flight takeoff removes client water restriction, sets native \`FeralFlyRequest\`, applies temporary local drag carry, and restores the original mode on G plus WATER config on close.
- Existing regression tests: predator holding prey versus victim being carried/pinned/dragged; native carry helper and no duplicated G press; Rest released before carrying; carrying-paused recovery resumes; genuine victim escape remains possible despite G grace; Safe Rest releases its own request when carrying begins, including if \`WolfRest\` was active.

**All tests passed offline.** This is not a live Roblox/Velocity test: the GitHub connector cannot run the user's Windows desktop, read the private FERAL server code or prove game-server acceptance of virtual hit reach, water takeoff with prey, or a permanent healing multiplier. The hub now distinguishes "client patch applied" from "observed game outcome".

## Source links

- [Standalone v14 loader](feral-nova-prime-standalone-v14.0.lua)
- [Modular v14 loader](feral-nova-prime-v14.0.lua)
- [Nonphysical bite reach](feral-nova-reach-v14.0.lua)
- [Bite Guide with extended window evidence](feral-nova-combat-v14.0.lua)
- [Non-Rest health/status recovery](feral-nova-regen-v14.0.lua)
- [Land and flight Endurance](feral-aurora-power-v14.0.lua)
- [Water takeoff and air-carry controller](feral-nova-flight-v14.0.lua)
- [Carry-preserving G controller](feral-nova-carry-v14.0.lua)
- [Controlled escape](feral-nova-escape-v14.0.lua)
- [One-screen interface](feral-nova-prime-ui-v14.0.lua)
- [Validation workflow](../.github/workflows/feral-nova-prime-v14-validate.yml)
