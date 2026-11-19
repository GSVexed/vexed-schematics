# FERAL NOVA PRIME v30 — Three Eagle Goals: Growth, Large Catches and Talon Cooldown

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v30.0.lua"))()
```

**Build:** One 18-module standalone script. **Preserves all v29 source modules except the updated diagnostic recorder and UI.** The v29 single Active Recovery, Endurance, ESP, auto escape, Q Quick Climb, baby carry, reach, water surface takeoff and native underwater flight exit are unchanged. The Eagle mechanics module and its reversible local settings are unchanged.

## Three goals: actual source evidence

| Goal | Exact recovered game source | Currently applied local input | Evidence required for gameplay verification |
| --- | --- | --- | --- |
| Faster growth into Elder | `Species` S0000035: ADULT_MINUTES.Eagle=19, GrowthConfig.ELDER_RATE=.385, GrowthConfig.CUB_BOOST=2; `WolfController` S0003620 reads character `Growth` | Cached `Species.ADULT_MINUTES.Eagle`, `GrowthConfig.ELDER_RATE` and `CUB_BOOST` | Larger sustained slope of **actual character Growth** in matched young/Elder trial intervals; retained after authority refresh; not merely earlier HUD label |
| Larger Eagle catch | `AbilityConfig` S0000056: `Talon.CARRY_RATIO=1.45`, `NO_ELDER_LIFT=true`; `grabMode("Talon", attacker, prey)` calculates relative size; `WolfController` S0003620 uses grabMode at local target selection | Cached Talon ratio and NO_ELDER_LIFT | Attacker physically holds and moves a prey target that formerly only yielded Scratch, with a sufficiently long actual carry; own local `FeralClamp` alone is insufficient as proof |
| Shorter Talon cooldown | `AbilityConfig.Talon.FLAT_COOLDOWN=60`, `FlightConfig.STOOP.CD_PICK=60`; `WolfController` listens for **LocalPlayer** `FeralLungeReadyAt` and sends `FeralLunge:FireServer("lunge", ...)` | Cached `Talon.FLAT_COOLDOWN` and `STOOP.CD_PICK/CD_CANCEL/CD_EMPTY` | Subsequent native Catch genuinely accepted sooner, not just showing a shorter client countdown |

### Crucial original-code findings

The native `WolfController` writes `FeralTalonPress` and `FeralTalonPending` as attributes on **LocalPlayer**, not on the character. v29 incorrectly read the character. v30 fixes both; pending is a **numeric timestamp**, not a boolean.

The game's original client-side `grabMode` routine can choose whether a target is eligible for Talon grab, but the native `FeralLunge` packet does not include the locally edited carry ratio. Server validation is unobserved. Likewise, `WolfController` reads the character's `Growth` attribute; changing Species/GrowthConfig locally cannot prove accelerated authoritative Growth.

Earlier v26 reporting observed cooldown totals near 60 seconds even when an experimental shorter value was shown. That is consistent with local and authoritative cooldowns diverging, but not yet sufficient to identify the exact server decision.

## What v30 changes

- **Correct source for Talon signals:** reads own `FeralTalonPress` and `FeralTalonPending` timestamps from LocalPlayer, so real attempts are no longer silently missed.
- **Simultaneous event correlation:** a Talon press and local outgoing clamp appearing in the same 0.5-second sample are associated.
- **Carry evidence:** counts local outgoing clamps within three seconds of a Talon press and holds lasting at least two seconds. No other player's name or target model is recorded.
- **Cooldown evidence:** records short versus long observed cooldown changes close to Talon press events, plus actual gaps between press signals.
- **Growth evidence:** separates actual Growth-attribute changes into Eagle/other, young/Elder and experimental setting on/off. Mixed-species and stage averages are no longer presented as equivalent.
- **UI:** displays own Talon press count, locally sustained holds and observed cooldown alongside experimental settings.
- **No risky game-modification changes:** the working v29 mechanics, recovery, stamina, flight and climbing implementations remain identical.

## Controlled live test sequence

**Start with a fresh Roblox join, preferably as a Bald Eagle**, and load v30. This resets any old pre-v28 controller loops.

1. **Growth:** With only the Growth experiment OFF, record several minutes of the same Eagle's `Growth` progression (while staying under or over the `Growth=1` threshold); then turn the Growth experiment ON and keep playing the same character for a comparable period. The recorder tracks both periods automatically. Avoid comparing baby growth to Elder progress as if they used identical rates.
2. **Catch:** For a normal valid prey target, try at least a few Talon pickups with the large-catch experiment OFF and ON. The recorder counts Talon press/pending signals and sustained *local* clamps. A visible or observed server-recognized carry is still necessary to establish real success.
3. **Cooldown:** With the Talon cooldown experiment OFF, perform a normal Eagle Catch attempt and let the cooldown end. Then enable only the cooldown experiment, attempt another valid Catch and watch whether a second Catch works earlier. The recorder separates a local 1.5-second cooldown field from observed ~60-second values and press/carry outcomes.

Do not change all three experiments simultaneously if the goal is to identify which one caused a result.

## Automatic private report

The script saves `FERAL_NOVA_v30_session.json` in the Velocity workspace about every 25 seconds (when `writefile` works). The existing private Windows runner now validates v30's schema and synchronizes it into `GSVexed/chatgpt-minecraft-testlab/diagnostics/feral-nova/latest.json`. It can be fetched through the connected GitHub app after a collector run, without manually pasting. The latest retrieved report before this release was still **v26**, not v29/v30.

## Verification and limitations

Offline Luau CI tests include 18-module and 33-feature integrity, simulated LocalPlayer Talon events, simultaneous press/clamp correlation, sustained local holds, stage-specific Growth buckets, water-surface flight behavior, single-recovery coordination, client setting rollback and private-data checks.

**These tests do not prove the server accepts accelerated Growth, larger pickups or reduced Talon cooldowns.** The game server implementation is not contained in the recovered client export. The next step is to compare the real saved `Growth` trajectory and accepted Eagle actions in a fresh live session—not to promise arbitrarily high server-accepted values from client constants.
