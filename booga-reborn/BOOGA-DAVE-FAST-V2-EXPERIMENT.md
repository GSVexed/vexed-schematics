# Dave fast-break attempt v2 — evidence and test boundaries

The earlier v1 Dave tool simply held/tapped native mouse input and was
correctly rejected by the user as an AFK grinder, not a fast-break feature.

**[booga-dave-fast-break-v2.0.lua](booga-dave-fast-break-v2.0.lua)**
is a distinct experiment derived from *actual uploaded game client code*,
not copied from 2019 Booga scripts.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-dave-fast-break-v2.0.lua"))()
```

## Why this is meaningfully different

Recovered client `ReplicatedStorage/Game/tool` checks local
`Data.lastToolUse` and equipment `speed`, then dispatches
`tool/Slash` or `tool/Combat`. Those modules use a 6x11x5 hitbox,
retrieve unique `EntityID` objects and transmit a typed
`Modules/util/packets.SwingTool.send` payload with
`entityIDs`, character CFrame, timestamp from `util/clock`,
and optional player replication state.

v2 calls the same *typed packet* and uses real `Dave.EntityID` and
`clock.getServerTime(true)`, avoiding local mouse swing animation and
the local input scheduler. This is a **hypothesis**, not evidence of
server permission to bypass swing timing.

It runs short stages at:
- 3 requests/second, 1 Dave ID per request (normal-ish comparison)
- 10 requests/second, 1 ID per request
- 10 requests/second, 4 repeated target IDs per request

Each stage lasts six seconds. It compares true client-*replicated*
`Dave.Health.Value` change (which can also reflect hits from other
players). If the best accelerated stage produces at least 1.5×
the observed baseline rate and damage is nonzero, it continues at that
rate. If the accelerated rates do not demonstrably help, it **stops**,
says no fast-break has been established and doesn't pretend to break
Dave instantly. Any 22-second period with no observed HP decline stops.

The script also requires a real equipped tool and currently replicated
Dave within 8 studs, facing it; it never edits Dave Health,
spawns artificial Pie, teleports, injects reward events or
automatically scoops loot. F6 and STOP end it. Re-running cleans
old UI. Max outgoing packet requests is 10/s. It does not
upload anything to GitHub.

## Critical uncertainty

The server-side handler for the typed packet was **not** among the
recovered client scripts. We cannot verify from the uploaded archive
whether:
- packet rates above equipped `speed` are throttled,
- repeated entity IDs are deduplicated/rejected,
- Dave has additional damage rules or resistance,
- the server could flag/disconnect clients submitting extra requests,
- a genuine quick-break route exists at all.

Community-written scripts from the **older** 2019 Booga reborn
variants sometimes spam `Events.SwingTool:FireServer` with part
Instances every 0.01s. That is **not the current archive API**:
the captured PlaceId 11729688377 uses a typed ByteNet
`SwingTool` with entity IDs, CFrame and timestamp. Blindly copying
the old handler would likely do nothing.

**Validated:** The code compiled with official Luau 0.747 and passed
source-level assertions at
[GitHub Actions](../.github/workflows/booga-dave-fast-v2-validate.yml).
**NOT validated:** Any server-accepted real damage benefit, Pie drops
or live Velocity compatibility. Do not present as a proven instant
breaker. If it reports no acceleration, more direct code changes on
the client will not by themselves solve private server checks.
