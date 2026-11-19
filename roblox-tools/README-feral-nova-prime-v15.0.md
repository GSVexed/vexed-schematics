# FERAL NOVA PRIME v15 — Recovery & Movement Overhaul

**Release date:** November 19, 2026  
**Game:** FERAL Animal Survival, Roblox place \`108901361810209\`  
**Release format:** One standalone launcher containing **15 source-pinned Luau modules**, not separate downloads.

## One-line Velocity launcher

\`\`\`lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v15.0.lua"))()
\`\`\`

**Fresh-session note:** Older v7/v8 physical hitbox expanders could leave local enemy root geometry altered until rejoin. Fully leave and rejoin FERAL once if you haven't already since those tests. V15 does **not** alter enemy Part.Size or collision.

## Main changes

### 1. Restore the older useful recovery mechanism, conditionally

The older [Recovery Hub v1.3](feral-recovery-hub-v1.3.lua) used \`WolfActions:FireServer("Rest",true)\` plus a **local** \`WolfRest=false\` pose mask. Earlier live notes recorded roughly 2% max HP/s outside combat and 4-point bleed/venom decay during that mode; combat HP recovery, injury and server-authoritative acceptance were not established. The mask was dropped in later builds to avoid interfering with bites, carrying and the Turtle shell. Replacing it with local \`NeedsConfig\` edits alone **did not reproduce** the old live result.

[V15 Native Recovery](feral-nova-native-recovery-v15.0.lua) restores the old Rest signal and local pose mask, but exclusively for your own character and **only while there is missing health or injury/bleed/venom to clear**. It:
- Disables any competing normal Safe Rest or Mobile A/B Rest owner when activated.
- Sends the native \`Rest=true\` at most once every five seconds while eligible. Only this module owns the corresponding \`Rest=false\` cleanup.
- Masks the local \`WolfRest\` pose with a guarded attribute-change listener and periodic maintenance; never writes \`Humanoid.Health\`, condition attributes or remote damage.
- Relinquishes the Rest request during native G carry, Quick Climb Q, jumping/flight, attack input, held mouse attacks, active flight, dive, grabbing, feeding, chatting and character death/change.
- **Excludes SnappingTurtle** from this mask to preserve Turtle's normal Rest/shell behaviour.
- Tracks the actual observed HP gain and bleed/venom/injury decay per second during the native signal.
- Leaves the regular v14 client-only \`HEALTH_REGEN×2\` and status-config \`HEAL/CLOT/FADE×4\` edits available, while [Regen v15](feral-nova-regen-v15.0.lua) *excludes masked native Rest signal intervals* from claims about pure non-Rest healing.
- Is enabled by the default V15 hub profile, with a clear **ACTIVE RECOVERY** switch to turn it off.

**Important limitation:** This is an experimentally restored native-client behaviour, **not confirmed always-on server health regeneration or verified combat HP regen**. The user requested meaningful recovery even while fighting, but this version temporarily releases Rest around attack inputs so bites and normal actions take priority. If the game server refuses the Rest signal during movement, it won't generate the desired bonus. An observed HP gain can also have unrelated causes. V15 reports actual measurements separately.

### 2. Same-species baby carrying without premature Auto Escape

Game [CarryConfig] eligibility recovered from client: baby's \`Growth<=0.34\`, carrier's \`Growth>=0.67\`, same species, appropriate size ratio, diet, facing and distance. V14 instantly sent \`getoff\` whenever \`FeralCarried=true\`; user reported that eligible adult same-species animals couldn't hold the user's baby.

[V15 Baby Carry](feral-nova-baby-v15.0.lua) adds an explicit **BABY CARRY ON/OFF** control. When ON it:
- Permits the native pickup to persist when another eligible same-species adult has an outgoing \`FeralClamp\` ObjectValue pointing to the baby.
- Uses a bounded nearby eligible-adult fallback for replication lag (up to 12 seconds), not a blanket exemption for every animal of the same species.
- **Always resumes Auto Escape immediately on \`FeralPinned\` or \`FeralDragged\`**; adulthood and different-species adults never qualify.
- Does not fabricate pickups, force another player to carry the baby or change server eligibility.
- Reports confirmed clamps, proximity-only observations, and hostile-pin overrides.

The proximity fallback cannot establish the other player's intent; disable BABY CARRY when you prefer the normal automatic getoff response to all captures.

### 3. Integrated one-press Quick Climb

[V15 Climb](feral-nova-climb-v15.0.lua) integrates the separately tested [Quick Climb v1.0](feral-quick-climb-v1.0.lua) into the main hub. It buffers an early Q for **1.3 seconds** and then writes the native player \`FeralClimbTap\` once if \`ClimbCan=true\`; does not spam Q or teleport onto a tree. Reversible local PassiveConfig changes make grab reach, facing and mount timing more forgiving and enable sprint-grab eligibility in the lower climber levels. It refuses competing DiveCan, carrying, captured, feeding and existing-climb states.

Quick Climb turns ON with the default hub profile, has a dedicated **Q CLIMB ON/OFF** toggle and live status, and cleans up only its own settings on reset/close. The old independent Quick Climb overlay is closed if it was previously installed. The game server can still reject a mount outside its accepted reach.

### 4. Preserve successful Endurance — no growth edits

**Exactly the v14 power implementation is retained**, using \`feral-aurora-power-v14.0.lua\`: \`WolfDbgNoStamina=true\` maintained after resets, 3× cached regen, zero local sprint/jump costs. The user's Bear previously showed **417 seconds of land movement, 244 seconds of burst, zero recorded drain and zero StaminaOut transitions**. No Growth attributes or growth rules are modified by v15.

### 5. Bite range honesty and diagnostic upgrade

The v14 nonphysical cached CombatConfig virtual reach remains, with \`REACH=1.769\`, \`HIT_SCALE=1.380\`, \`CONE=79\`, reduced \`bodyGap\`, and *no physical enemy hitbox edits*. The user's v14 report had 100 extended-only client windows but **zero bite starts** in them; not evidence of longer server-accepted reach.

[V15 Combat](feral-nova-combat-v15.0.lua) records actual Mouse1 attack inputs, how many occur in **extended-only** target range, and whether the game's \`WolfBiteAt\` start follows them. This distinguishes **never attempted** from **game client did not initiate** from **HP decline near bite**. The report still does not treat nearby HP loss as proof of server-accepted extended damage.

### 6. Flight, native G and Turtle continue

- v14 water takeoff and midair prey retention module retained with v15 Rest hand-off before takeoff.
- Native Carry/Drop G retains the FERAL game's own helper and relinquishes any v15 masked native Rest signal before pickup/drop.
- Turtle Safe Rest/nominal shell monitor remains separate and mutually exclusive with the masked native Rest signal.
- Auto Escape keeps the controlled non-instant \`getoff\`/tug/shake cadence, adding the baby-carry exception.
- Screen-projected close-range nametags, outline-only ESP, one Endurance control, Agility, Clear View and Copy Status remain.
- The new interface uses an extra compact action row for **Q CLIMB** and **BABY CARRY**. It shows which action is winning (friendly pickup, climb queue, native recovery, escape) instead of mislabelling every grab as hostile.

## Startup defaults, interactions and controls

**Enabled by default:** Endurance, Auto Escape, nonphysical Reach, non-Rest cached Regen, experimental Active Native Recovery, Quick Climb, Friendly Baby Carry, Water Flight, ESP/Tags, retained Agility and Clear View settings.

**Disabled by default:** competing *ordinary* Safe Rest and the separate experimental Mobile A/B Rest comparison. Both can be selected manually. The main Recovery card toggles native recovery. The small \`A/B\` button temporarily disables Native Recovery and local Regen configuration during its controlled comparison, then restores the previous modes afterward. Normal Safe Rest disables active Native Recovery.

In the integrated status report, Native Recovery is distinct from local Regen configuration. Never infer server-authoritative advantage solely from a successful attribute/config write, Rest request or UI toggle. The report also shows current Growth for observation only.

## Validation

[Official Luau v15 workflow](../.github/workflows/feral-nova-prime-v15-validate.yml) checks that **all fifteen bundled module sources exactly match** the standalone release, compiles all sources and the standalone with official Luau 0.747, and runs the existing v14 suite plus:

- native Rest request and masked WolfRest=false pose, observed HP/status change, Rest release on carry and held/normal attack, and shutdown;
- same-species infant/adult eligibility, confirmed outgoing clamp, hostile pin override, species mismatch and Growth boundary;
- integrated Q buffering before ClimbCan, exactly one native FeralClimbTap, observed mount, Dive priority and config restoration;
- source-level conditions to avoid other-character hitbox edits, unverified server-value claims and competing native Rest controllers;
- land/bird Endurance, nonphysical Reach, RegenConfig reversibility, water flight with outgoing prey, native G carry/rest cleanup and Escape regressions inherited from v14.

These tests are **offline Luau simulations, not a live Roblox test**. Live health rates, friendly pickup, climb mounting and server hit acceptance are still necessary to validate actual effectiveness.

## Source

- [Single-download v15](feral-nova-prime-standalone-v15.0.lua)
- [Modular v15](feral-nova-prime-v15.0.lua)
- [Native Rest-signal recovery](feral-nova-native-recovery-v15.0.lua)
- [Friendly baby carry](feral-nova-baby-v15.0.lua)
- [Integrated climbing](feral-nova-climb-v15.0.lua)
- [Escape](feral-nova-escape-v15.0.lua)
- [Combat diagnostics](feral-nova-combat-v15.0.lua)
- [Native G coordination](feral-nova-carry-v15.0.lua)
- [Flight coordination](feral-nova-flight-v15.0.lua)
- [Non-Rest config/clean measurements](feral-nova-regen-v15.0.lua)
- [Normal Safe Rest](feral-nova-recovery-v15.0.lua)
- [UI](feral-nova-prime-ui-v15.0.lua)
- [CI](../.github/workflows/feral-nova-prime-v15-validate.yml)
