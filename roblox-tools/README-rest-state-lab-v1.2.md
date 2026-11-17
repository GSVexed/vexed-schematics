# FERAL Rest-State Lab v1.2 — phase- and gait-separated follow-up

This build corrects an evidence limitation found in the user's v1.1 report.
The report showed one complete 12s HudRest probe with 23 true samples and 0
resets, but 44 aggregated `on_hud_moving` intervals. v1.1 reset its latest
probe counters each time **without resetting the session-wide on_hud totals**.
It likely aggregated more than one 12s run, making the reported +0.19 stamina/s
ineligible for a clean one-run causal comparison.

Additionally, v1.1 grouped ordinary movement, Sprint and Burst together as
"moving", though those modes can have very different stamina costs. This
version fixes both reporting limitations, not the game's unknown authority.

## One-line Velocity loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-rest-state-lab-v1.2.lua"))()
```

New control is still OFF by default. Loading v1.2 closes older FERAL lab/hub
panels; keep the successful Recovery Hub v1.3 otherwise unchanged.

## Repeatable comparison

1. Spawn with partial stamina and adequate needs; do not activate the
   separate 3× stamina tool, other health tools, or normal Rest.
2. While CONTINUOUS REST is OFF, **walk only** (do not Sprint or Burst)
   for 10–15 seconds.
3. Turn CONTINUOUS REST ON and **walk at the same pace** for 10–15 seconds.
   The server Rest packets and pose mask are as in v1.1.
4. While still walking and HudRest is false, click TEST HUDREST; continue
   walking until the bounded 12-second test finishes automatically.
5. Copy the report. Then turn CONTINUOUS REST OFF.

If the game blocks movement or something else changes unexpectedly, end
the test and rejoin if Rest does not return to normal. Avoid intentional
Burst stress testing while the earlier abrupt deaths remain unexplained.

## Reading v1.2 output

- `off_Moving`: ordinary walking, no extra Rest packet.
- `on_Moving`: walking with repeated Rest=true, without the HudRest probe.
- `on_hud_Moving`: walking during the latest short HudRest local flag probe.
- `*_Sprint` and `*_Burst` are now separate. They will not corrupt the
  walking comparison. Still periods are separate as well.
- Compare stamina net/s only where the same gait, similar average *horizontal
  velocity* and at least several eligible partial-stamina interval pairs exist.
  Max-stamina changes and full-bar periods are excluded from resource rates.
- The on_hud totals are reset **per HUD probe**, so current 12-second
  sample count can be checked against interval count. Rest OFF/ON totals
  remain per script session; reload the script for an independent run.
- `HudRest true` from a local SetAttribute only shows that a client flag
  remained true; it is not a server acceptance or native private-rest proof.

The v1.1 observation that 23/23 local HudRest samples stayed true despite
movement does **not** mean the true server stamina rest bonus was granted.
The +0.19/s versus -0.03/s difference was small and confounded by mixed
movement modes and potentially more than one HUD probe. No health recovery
rate was measurable (HP stayed at its cap); combat regen also stays unknown.

## Validation

Official Luau compiler and static scope-check workflow:
[FERAL Rest Luau compile](https://github.com/GSVexed/vexed-schematics/actions/workflows/feral-rest-luau-compile.yml).
These checks cannot establish actual live Roblox/Velocity results.
