# FERAL NOVA PRIME v10 — clean geometry, accurate Rest/status telemetry

**Place ID:** `108901361810209` (FERAL Animal Survival). Built from the actual v9 live status supplied by the user, the older FERAL client archive, and v7/v8/v9 code investigation.

## Paste into Velocity (after fully rejoining FERAL once)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-v10.0.lua"))()
```

**Important one-time recovery step:** Completely exit the old FERAL play session and join a fresh game before running v10. The v7/v8 experiment had physically enlarged other animals' *local* HumanoidRootPart sizes and may not have fully restored all changes after an interrupted executor/script shutdown. A new hub cannot reliably infer and reset each target's original size. A fresh session clears those local script-side modifications; if close-range movement still fails without the hub, the cause isn't simply a leftover NOVA resize.

## Changes from v9

### Local collision issue: never mutate other animals again

- The ineffective HITBOX TEST from v7/v8 remains removed. v10 **does not write opponent Size, CanCollide, CollisionGroup, CFrame, Humanoid.Health, or physical attributes**.
- The existing BITE GUIDE still predicts the client-side target window and observes bite starts and nearby HP loss. It isn't an exploit that enlarges server-authoritative damage reach.
- The new **read-only collision audit** records your own root XYZ size, the nearest nearby animal root XYZ size (within 30 studs), its CanCollide and CollisionGroup, plus the category and collidability of a rate-limited line-of-sight ray obstruction. It does not export other players' names or coordinates.
- **COPY STATUS** adds `physical_part_edits_by_v10=0`, `old_v7_v8_gui_present`, `nearest_root_size_xyz`, `nearest_root_can_collide`, `ray_obstruction_category` and `ray_obstruction_collidable`. Ray casting is optional and safely reports unavailable if unsupported.
- Roblox's networking model generally does not replicate ordinary client-side part-property modifications to the server. Local part enlargement may still change the client-visible collision geometry and does not prove additional damage hits.

### Health recovery and 4x negative-effect recovery

The archived live client contained these config values:

| Config field | Archived value | Intended meaning |
|---|---:|---|
| `NeedsConfig.HEALTH_REGEN` | `0.01` | Baseline HP regen as a fraction of max HP |
| `NeedsConfig.HEALTH_REST_MULT` | `2` | **2× HP regeneration only while resting** |
| `StatusConfig.INJURY.HEAL` | `0.45` | Baseline injury recovery per applicable interval |
| `StatusConfig.INJURY.REST_MULT` | `4` | **4× injury clearing only while resting** |
| `StatusConfig.BLEED.REST_MULT` | `4` | **4× bleed clearing only while resting** |
| `StatusConfig.VENOM.REST_MULT` | `4` | **4× venom clearing only while resting** |

These are rules from an archived client configuration, **not a guaranteed effect from modifying your local table**. The server is responsible for deciding when actual Rest and recovery conditions apply. Decompiler reconstruction errors also exist in parts of the archived StatusConfig; v10 compares actual live attributes instead of treating the recovered table as authoritative.

The v9 live report had 80 positive non-resting healing intervals and **zero native Rest requests**, so it never actually demonstrated a doubled Rest healing rate. Previously, the assistant mistakenly spoke of boosted regeneration while the hub was only measuring recovery.

V10 corrects the practical blocker: **when HP is full but injury, bleed or venom is present, that effect alone now makes Rest worth requesting**. The Rest control is still OFF at startup, to avoid an older dangerous conflict: WolfController refuses ordinary bites while `WolfRest=true`. You can enable REST RECOVERY when safe. When enabled, it waits for a stable idle, checks needs, recent combat/damage and players within 32 studs, requests the **normal** `WolfActions:FireServer("Rest", true)` when eligible, watches the local observed Rest attribute (which WolfController can write locally and therefore does **not** prove server recognition) and cancels its own request on movement/attack or significant damage. It does not send continuous requests in a fight.

The report now includes:
- Current readable client config values, when available, plus archived 2×/4× rule labels.
- Observed local Rest-attribute transitions (neither requests nor local attributes alone prove server recognition).
- Positive HP gains per second when Rest is active versus absent, excluding intervals where MaxHealth changed, where the animal is already full, where damage intervened, or where Rest state changed mid-interval.
- Measured replicated `FeralInjury`, `FeralBleed`, `FeralVenomAmt` decline rates per second while Rest is active or absent. Status re-applications are not treated as recovery.
- Whether an eligible negative effect was actually present during the observation.

An observed 4× rate across comparable full-health/stable-MaxHealth status samples would be evidence consistent with the **game's Rest mechanic**, not necessarily a server guarantee. V10 cannot force the server to award this effect continuously while moving, attacking or being grabbed.

### Turtle and combat coexistence

- Turtle client shell rule still checks its own SnappingTurtle species, `WolfRest=true`, and at least one second since `WolfRestAt`, with nominal multiplier `0.30`.
- Rest can block normal bites. V10 remains combat-first: no forced rest at startup, and releasing an owned Rest request when you attack or move. If you **explicitly enable REST RECOVERY while playing Turtle**, the hub can request native Rest at full HP in a safely stationary situation even without injury/bleed/venom, to try activating shell defense. It still releases its own Rest for movement or attacking; continuous protection while running remains unproven.
- The status bar shows a shell *condition*, not a guaranteed 70% reduction in authoritative damage.
- Automatic escape continues with the source-guided v9 directional shake/tug and carry logic; no false guarantee of instant escape.

### Interface retained

One page, six controls: Endurance, Auto Escape, Outline ESP, Agility, **REST RECOVERY**, Clear View. Compact quick strip for name tags, through-wall outlines, range and Bite Guide. Normal Right Shift hide/reopen, RESET, close and COPY STATUS controls remain. Nametags use v8's close-camera-safe screen projection rather than billboard-only labels.

RESET restores settings that v10 owns; it cannot reliably reverse local body dimensions changed by a previously terminated v7/v8 instance. Its confirmation now specifically reminds you to **rejoin** if a leftover collision issue remains.

## Validation

`.github/workflows/feral-nova-prime-v10-validate.yml` compiles all module dependencies with official Luau and executes offline tests for:
- native shake/tug/carry input-selection rules;
- multiple pinned/shake requests and observed progress/release transitions;
- native Bite Guide geometry and a simulated nearby ray-blocker collision classification, without altering animal dimensions;
- Rest OFF by default and immediate owned-Rest cancellation on attack;
- **Rest request with full HP but active injury**, plus observed FeralInjury decline under a replicated Rest flag;
- no synthetic HP/Amber writes, enemy part-size writes or unsolicited attack remotes.

**Offline tests do not validate live server acceptance.** There is no direct remote-desktop bridge from this GitHub connector to the user's Windows/Velocity session. A live test after rejoining is still needed to decide whether a server-side recovery multiplier is actually active.

## Code
- [v10 launcher](feral-nova-prime-v10.0.lua)
- [v10 interface](feral-nova-prime-ui-v10.0.lua)
- [v10 collision audit and bite guide](feral-nova-combat-v10.0.lua)
- [v10 Rest/health/status observations](feral-nova-recovery-v10.0.lua)
- [v9 escape controller](feral-nova-escape-v9.0.lua)
- [v8 screen-projected nametags](feral-nova-tags-v8.0.lua)
- [v10 validation](../.github/workflows/feral-nova-prime-v10-validate.yml)
