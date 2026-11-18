# Booga Booga Reborn — server-side Voodoo validation findings (18 Nov 2026)

## Objective and result
Objective: genuine additional, server-accepted Voodoo regeneration for damaging Energy Bolt/Lightning casts, not a local full bar or repeated arm animations.

**Result: no reproducible server-side Voodoo-regeneration weakness has been found.** Do not advertise a working extra-regen script or remote exploit from these results.

## Current live evidence — exact runs
1. **One guarded craft-boundary trial**, [run 44310861368](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44310861368): player level 39, no Void Shroud or craft ingredients; one `CraftItem` request transmitted through the game’s ByteNet client interface; no local error, no `ItemAdded` or `ItemChanged`, no Shroud added to inventory. Status `CRAFT_REQUEST_DID_NOT_ADD_ITEM`. This **does not prove** all server validation is secure, but it closes that one exact attempt.
2. **Earlier intrusive listener-based measurement**, [run 44308016334](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44308016334): captured incoming `UpdateStatsUnreliable.voodoo` from 19 to 61 across 143.9 s (0.292 Voodoo/s) with 30-Voodoo spending, while local `gameUtil.Data.voodoo` and UI remained 100; 147 incoming messages disagreed with cache. The observer registered its own `packets.UpdateStatsUnreliable.listen` callback, so **measurement interference cannot be excluded**.
3. **Fresh listener-free local/UI inspection**, [run 44311921280](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44311921280): local game cache **41**, Voodoo GUI label **41.0**, showing the previous 100 freeze was not persistent. This test deliberately called **no** `.listen` method. It did not intercept native server packets, so should not be misrepresented as independently confirming native packet equivalence.
4. The in-game `packets.UpdateStatsUnreliable.getListeners` method is **nil** (same for `UpdateStats`, `SetBoost` and `UpdateArmor`). The current public ByteNet source supports `getListeners()` and multiple listeners, but **the game’s version is different**. It is unsafe to assume our observer can register/unregister independently; some earlier monitoring may have changed normal packet delivery. Avoid further `.listen` subscriptions until the exact game implementation is verified.

## Recovered client source audit
Re-checked the exact user-provided client archive `UPLOAD_PART_010_DATA(1).zip` against its 388 `game` source files:
- `Game/spells` (`S0010320`): `VoodooSpell.send` is the outbound spell request. It supplies `targetPos` and `aimDirection`; **no caller-selected regeneration amount or energy balance**.
- `Game/stats` (`S0010326`): `UpdateStats` / `UpdateStatsUnreliable` are incoming messages and intended to update `gameUtil.Data.voodoo` and the GUI. An observer replacing or disrupting a listener could cause client display desynchronisation.
- `Game/boosts` (`S0010367`): `SetBoost.listen` is present; **no `SetBoost.send` call found** in the archived game scripts. A local boost icon cannot establish a server grant.
- `Game/crafting` (`S0010353`): ordinary `CraftItem.send` and client eligibility checks; this exact unowned/underlevel Void Shroud case did not grant an item when transmitted.
- `Game/inventory` (`S0010366`): `UseBagItem.send` operates on existing inventory entries/indices; no verified fabricated-item grant.
- `Game/mojos` (`S0010323`): `ToggleMojo` and `PurchaseMojoItem`; Spellmaster is described as passive/non-toggleable. User already owns Spellmaster tier 1.
- `Game/armor` (`S0010324`): `UpdateArmor` is an incoming confirmation; local armour cache is not an authorised server equip.
- No recovered client-side source contains the server’s authoritative Voodoo regeneration or spell-cost validation handlers.

## Working constraints
Live snapshot: player level 39, Spellmaster tier 1, God Bag, no Void armour, no Void Bag, no Jelly Sandwich or necessary crafting resources. One genuine incoming-stat trace indicated ~0.29 Voodoo/sec, but was collected by an invasive listener and should be treated as **provisional until confirmed non-invasively**.

**Do not publish another “unlimited Voodoo” launcher, change `Data.voodoo`, imitate a `SetBoost` notification, or infer damage from a casting animation.** Genuine additional regeneration requires evidence in authentic server-recognised stats and ideally a successful damaging extra cast. For a real vulnerability audit, obtain the game owner’s server handler code or permission to test on a controlled development server; without that, assertions about actual server-side weaknesses are speculative.

## Sources
- Original user-provided `UPLOAD_PART_010_DATA(1).zip` decompiled client files (not authoritative server code).
- [Public ByteNet implementation](https://github.com/ffrostfall/ByteNet/blob/main/src/packets/packet.luau), for comparison **only**; the live game’s variant lacks exposed `getListeners`.
- Live run links above.
