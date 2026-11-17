# FERAL Rest-Only Lab v1.0 — focused follow-up

This is the next controlled experiment after Recovery Hub v1.3. It specifically
fixes the testing gap where **Recovery Assist stopped requesting Rest at full
health and without a visible status condition**, so it could not isolate a
possible stamina effect of normal Rest.

## One-line Velocity loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-rest-only-lab-v1.0.lua"))()
```

Run it only while inside FERAL (PlaceId 108901361810209). This version opens
with **CONTINUOUS REST OFF** and performs no gameplay request until clicked.
Loading it closes older Recovery/Field Hub windows so the previous stamina
tuning or recovery requests do not contaminate this experiment. The working
Recovery Hub v1.3 file is unchanged.

## What it does

- While enabled and a living own animal is active, sends the normal native
  `WolfActions("Rest", true)` RemoteEvent action at most every **five seconds**.
  This happens **even at full HP and full stamina**.
- Locally masks `Character@WolfRest` to avoid deliberately enforcing the
  ordinary resting animation during movement. This is client-side pose work,
  not confirmation that the game server accepts Rest.
- Reports the own-character health, maximum health, visible stamina, needs,
  movement mode, `HudRest` and observed `WolfRest` echoes.
- Separates normal baseline samples (**OFF**) from Rest-request samples
  (**ON**) and distinguishes moving vs stationary intervals.
- On OFF / X, attempts `Rest=false` only for the original still-current
  character. When the old character is gone, no cleanup packet is sent to the
  replacement. An enabled toggle re-arms after respawn.
- Never writes HP, stamina or max stamina, never edits stamina/health config,
  and never modifies combat, needs, permissions, or native controller upvalues.
  It only writes the local `WolfRest=false` appearance attribute while masking.
- Copies a bounded, privacy-minimised report. If a clipboard API is unavailable,
  shows selectable text in the panel.

## First useful test

1. Spawn an animal in a low-risk location. **Do not enable Recovery Hub v1.3's
   stamina switch** concurrently: the Rest-only loader closes that panel.
2. Use ordinary walking to lower stamina to about half. Keep hunger/thirst
   reasonably high. Full HP is fine for testing stamina, but a missing-HP
   interval is needed to measure health recovery.
3. With CONTINUOUS REST **OFF**, walk at a steady pace for around 10–15 seconds
   to get the normal moving baseline.
4. Turn CONTINUOUS REST **ON**. Continue the **same walking pace** for
   approximately 15–20 seconds without manually pressing Rest.
5. Click **COPY REPORT** and paste the contents into ChatGPT. Then turn the
   experiment OFF. We can compare `off_moving` with `on_moving`, and test a
   separate normal-rest interval if needed.

Avoid prolonged Burst testing for now: its earlier unexplained deaths have not
been diagnosed. This controlled walking comparison does not need an additional
bulk diagnostic or a forced death.

## How to interpret the report

- `Rest=true sent` shows **client request submission only**, not an
  acknowledgement from the authoritative server.
- `WolfRest true seen before local masking` is a **local replication echo**,
  not a proof that the server granted stamina or health effects.
- `HP gain %max/s` measures only eligible unchanged-max, non-damage,
  below-full intervals. Blank means insufficient useful pairs (e.g. full HP).
  Positive-only health changes are accumulated across all valid interval time,
  rather than inflating the rate by ignoring zero-change intervals.
- `stamina net/s` is client-visible net change; negative means the working
  resource was still draining. Stamina may be owned/recomputed locally; its
  display does **not** prove an independent server stamina budget.
- Rising HP outside combat may support native Rest healing; only repeated,
  comparable tests can strengthen this conclusion. Combat HP regen, true
  moving Rest acceptance and indefinite Burst remain **unconfirmed**.

## Implementation and verification boundary

Source: [feral-rest-only-lab-v1.0.lua](feral-rest-only-lab-v1.0.lua).
This is a fresh focused build, not an update to the successful v1.3 stamina
method. Official Luau **0.747 compile-only** and static resource-write/scope checks
passed in [GitHub Actions run 44103217850](https://github.com/GSVexed/vexed-schematics/actions/runs/44103217850).
This verifies script syntax and selected invariants, **not** live game behavior.
**No live Roblox/Velocity result has yet been collected for this build.**
