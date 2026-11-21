# FERAL NOVA v11.2 — Project Renaissance: Engineering Completion

Release date: 21 November 2026  
State: **Integrated build published; automated compile/runtime regressions PASS.**  
Runtime note: These tests do not demonstrate that the game server honors client-only benefits.

## Launch

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v11.2-renaissance-complete-potassium.lua"))()
```

End = close an older hub; Right Shift = hide/show FERAL HUB.

**Rollback:** `feral-nova-v11.0-renaissance-potassium.lua` is retained unchanged, as is `feral-nova-v10.3-moving-recovery-potassium.lua`.

## Engineering accomplishments

- **Single Rest writer:** Only `feral-nova-native-recovery-v11.2.lua` contains the hub's automatic `WolfActions:FireServer("Rest", ...)` path. The old Safe Rest and Mobile A/B modules are inert API-compatible adapters without heartbeats, input listeners or remotes. Even the dormant Rest(true) / Rest(false) paths in the shared Aurora engine have been retired, avoiding unexpected cancellation of manual Rest or automatic recovery.
- **Action-priority coordination:** The v11 Action Core recognizes real `WolfFeed` and early native feed intent, alongside combat, grabs, carrying, climbing and optional AFK movement. Native feeding and drinking interrupt hub-owned Rest. Recovery automatically re-arms after feeding and a bounded settling period. User-owned manual Rest remains separate. The hub does not independently manufacture food/water resource changes.
- **First-click feeding protection:** When `FeedCan` is available and the player makes a real, unprocessed primary click, automatic Rest is released before waiting for `WolfFeed`. This addresses the potential first-consumption race while preserving the game's actual Feed protocol. Native `FeralFeedTap` and `WolfFeed` signals also preempt Rest.
- **Late Rest pose protection:** The native controller's guarded local pose mask rejects bounded late echoes of *its own* released Rest signal during feeding. This is a local animation intervention, not proof of how other players see the animal.
- **Reliable own-condition accounting:** Injuries, venom and bleeding count as cleared when a status attribute is removed, not only when the final value is numeric zero. The native recorder separates manual Rest, automatic Rest, baseline, combat and feeding windows so rates from incompatible states are not mixed.
- **Honest 4× claims:** Client-side `StatusConfig.REST_MULT=4` is reported as an available configuration input, not a confirmed server effect. No client-side writing of HP, injury, bleed, venom, Hunger or Thirst to fabricate gameplay success.
- **Startup consistency and lifecycle:** UI title/GUI identity, bootstrap status, release metadata, evidence version and self-check requirements now target v11.2. The bundle retains 23 precompiled/ordered modules and all cross-module references resolve. New startup checks cover sole ownership, feed priority, effect-clearance buckets and retirement of legacy engine Rest.
- **Backward-compatible modules:** Other systems—Eagle assist, Talon state, combat, grab minigame, climbing, flight, anti-idle, survival movement, carry, escape, UI and diagnostics—retain their existing functionality. The coordinator handles conflicts with recovery instead of silently enabling a second Rest controller.

## Module inventory (23)

| Group | Modules | Review result |
|---|---|---|
| Engine and settings | Aurora Engine v11.2, Aurora Power v14 | Old engine Rest remotes removed; movement/input settings otherwise preserved |
| Combat, escape and handling | Escape Core v9, Combat v15, Carry Core v9, Reach v14, Eagle Actions v32, Grab v10.1, Baby v15 | Preserved; replicated outcomes versus local hints remain separated |
| Recovery and condition management | Rest compatibility v11.2, Mobile compatibility v11.2, Native Recovery v11.2, Regen Config v11, Active Recovery v11.2 | Duplicate Rest controllers retired; feed and combat priority retained; no new server-grant claims |
| Mobility / social / idle | Flight v28, Climb v9, Tags v8, AFK v10.1 | Existing reversible client features and action guards retained |
| Interface, mechanics and evidence | UI v11.2, Mechanics v28, Diagnostics v32, Action Core v11, Evidence v11.2 | Correct version, priority, preservation of terminal effect-clearance samples |

**Preservation:** Against v11.0, 16 module bodies remain identical, and seven are revised or replaced. The earlier v11.0 build itself had already introduced dedicated updates to Action Core and client recovery configuration.

## Quality gates completed

Workflow: [FERAL NOVA v11.2 Renaissance Validation](https://github.com/GSVexed/vexed-schematics/actions/runs/44943635478).

- Official Luau compilation of the full launcher and all 23 embedded sources.
- Every embedded module name and all 23 runtime loader references resolve, with unchanged modules checked byte-for-byte.
- Only the Native Recovery module can send automatic Rest; no old engine / compatibility module Rest calls remain.
- Runtime mock of native `WolfFeed` immediate preemption, first primary-click `FeedCan` preemption, `FeralFeedTap`, delayed own Rest echoes, manual Rest sovereignty, recovery resumption and cleared-condition counting.
- Runtime mock of Action Core rejecting recovery, AFK walking, climbing and carrying during feeding.
- Runtime mock verifying the two legacy compatibility modules cannot be re-enabled, have no native remote sends, retain optional Turtle-shell observation and close cleanly.
- Existing v11.0 tests also previously passed; no separate user diagnostic run is required for this release.

## Important boundaries

1. **Food and water outcome:** The hub now prioritizes native feeding and removes the identified Rest conflict, but Roblox server acceptance of a food/water transaction and a Hunger/Thirst increase still requires live verification. An animation alone is not an accepted resource grant.
2. **Negative-effect 4× multiplier:** The source contains client-side `REST_MULT=4`, but only the game server controls the real decay. This release cannot guarantee the 4× effect during invisible moving Rest, nor does it invent an alternative cure.
3. **Other server-owned abilities:** Oversized Eagle pickup, reduced Talon server cooldown, perfect minigame ratings, truly infinite Hunger/Thirst and unbroken survival bonus are **not proven** merely because their local handlers compile. They retain their best-existing bounded client implementation and outcome disclaimers.
4. **Other-player appearance:** A client pose mask is not a proof of replicated movement/animation. The release protects its owned Rest transitions as far as client code allows.
5. **Future game updates:** A native Roblox game update could alter inputs, events, species rules or server acceptance independently of this hub.

## Conclusion

The **software-engineering overhaul** has been integrated and validated: the recovery architecture has one writer, action conflicts are prioritized, duplicate controllers are retired, evidence is more accurate, stale versions are removed, and the old releases remain available for rollback. **Gameplay perfection or server-owned effects are not guaranteed by offline tests.** This distinction is intentional.
