# FERAL Rest-State Lab v1.1 — HudRest hypothesis

This version tests the user's specific observation: **Rest while stationary
raises visible stamina (+2.76/s in the first v1.0 report), whereas moving
Rest with `HudRest=false` still drained stamina (-1.13/s)**. Those numbers
are observational averages from differently moving intervals, not proof that
`HudRest` is a recovery control.

## Velocity loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-rest-state-lab-v1.1.lua"))()
```

The original [Rest-Only v1.0](feral-rest-only-lab-v1.0.lua) and
[Recovery Hub v1.3](feral-recovery-hub-v1.3.lua) stay unchanged. This new
panel replaces older FERAL test panels when loaded, and starts with BOTH
controls OFF.

## Two distinct controls

1. **CONTINUOUS REST**: sends the native, own-character Rest=true request
   at most every five seconds (as in v1.0), and masks the local WolfRest
   pose indicator. Rest=false cleanup is sent on stopping for the same
   still-current character. A request/echo is not proof of server acceptance.
2. **TEST HUDREST (12s max)**: available only while CONTINUOUS REST is ON.
   Temporarily asserts the LocalPlayer `HudRest=true` attribute during a
   brief movement comparison, no more than once per 0.2 seconds. It records
   the game's subsequent resets and restores the original local attribute
   value if still holding our value when the test stops. It stops by itself
   after 12 seconds, if movement appears blocked, or after 36 resets. This
   is only a bounded CLIENT-LOCAL hypothesis test. It does not toggle the
   game's internal private rest state or force the game server to heal.

## Test steps

- Spawn safely with 25–60% stamina remaining, adequate hunger/thirst.
  Don't activate the older 3x stamina feature simultaneously, and avoid
  Burst; the earlier unexplained Burst deaths remain unresolved.
- Enable CONTINUOUS REST; walk steadily for 10–15 seconds with HUDREST TEST
  OFF. The `on_moving` group is the baseline *with Rest requests*.
- Click **TEST HUDREST** then continue the same gentle movement. It
  automatically finishes within 12 seconds. If movement stops or the native
  controller cancels the flag repeatedly, the test stops early.
- Click COPY REPORT and paste the result into ChatGPT. Then switch
  CONTINUOUS REST OFF.

## Reading the report

Compare `on_moving` and `on_hud_moving`. The latter is meaningful only if
stamina was below its cap and you actually kept moving during the short HUD
phase. Review the counts for `HudRest true/false sampled` and resets:
a flag that the native controller immediately clears will not establish
a sustained Rest state. If the test reports movement blocked, the HUD
flag likely conflicts with movement; that is NOT a working mobile Rest fix.

`off_moving` is retained for ordinary no-Rest comparisons. The report
also separates stationary intervals, health observations below the cap,
and client-only state signals. This probe makes no HP, stamina or internal
config writes. Visible stamina changes are not a verified server resource
budget. Combat HP healing and indefinitely accepted movement/Rest remain
unproven.

## Validation

The official Luau compile workflow is
[FERAL Rest Luau compile](https://github.com/GSVexed/vexed-schematics/actions/workflows/feral-rest-luau-compile.yml).
Compilation and static review are not execution inside Roblox/Velocity.
