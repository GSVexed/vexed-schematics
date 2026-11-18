# Infinite Voodoo – full Reborn client + historical server feasibility audit
**Date:** 2026-11-18  
**Goal:** An Energy Bolt that genuinely damages through the public game server repeatedly without running out of Voodoo.  
**Result:** **No publicly reproducible server-authoritative infinite-Voodoo bug established.** No new exploit has been deployed.

## Primary source: original current Reborn client archive
Reopened the actual user-provided `UPLOAD_PART_010_DATA(1).zip`, mapped by the provided `booga_game_script_index.json`, and searched **438 successfully exported game source scripts** (of 451 indexed game entries) for every Voodoo, spell, cost, unlock, boost and related packet reference.

| Exact symbol | Source scripts containing symbol | Main observations |
|---|---:|---|
| `voodoo` | 15 | Mostly item metadata, spell UI, stats display, patch notes; no client-exposed authoritative regen setter |
| `voodooCost` | 2 | `ReplicatedStorage/Modules/data/itemData/data` and `ReplicatedStorage/Game/spells` only |
| `VoodooSpell` | 3 | Item metadata, client spell controller and packet definitions |
| `SetBoost` | 2 | `Game/boosts` incoming listener and packet declarations only |
| `RemoveBoost` | 2 | Client incoming listener and packet declarations |
| `UpdateStats` | 2 | Client stats listener and packet declarations |
| `PromptSpellChoice` | 2 | Client spell menu and packet declarations |
| `UnlockSpell` | 2 | Incoming client spell-unlock listener and packet declarations |
| `Spellmaster` | 2 | Only item metadata and item IDs |
| `Jelly Sandwich` | 5 | Items, recipes, vendor metadata and boost display definitions |

**Observed current client implementation:** `Game/spells` calls `VoodooSpell.send({targetPos, aimDirection})`; there is **no client field for a proposed Voodoo balance, cast cost or damage**. It uses client `voodooCost` to gate local animations. Sending an event is not evidence that the server dealt damage. The normal spell menu invokes `PromptSpellChoice.send(itemId)`, whose server-side validation is unavailable.

**Important limitation:** The decompiled `Modules/util/packets` reuses generic temporary `v35` for many packet declarations; do not infer authoritative per-packet types from that pseudo-source alone. Live module or verified call sites are needed. This does not reveal a hidden `voodoo = amount` command.

## Actual public game spell cost definitions
The `Modules/data/itemData/data` source includes:
- `Energy Bolt`: `voodooSpell=true`, cost **30**, metadata damage **35**.
- `Spirit Link`: cost 80.
- `Soul Dash`: cost 30.
- `Amaterasu`: cost 100.
- `Time Stop`: cost 20.
- `Energy Shield`: cost 60.
- `Void Cloak`: cost 60.
- `Voodoo Vortex`: cost 75.
- `Shadow Warp`: cost 90.
- `Hate Train`, `Stop Time`: cost 10 each in data, but no demonstrated real damaging player cast or unlock entitlement. **Not zero-cost Energy Bolt substitutes.**
- `God's Bolt` 90 damage, `Rainbow Ray` and `Equinox Bolt` 70, `Bullet's Ray` 60: all **client cost 0**, but **`blacklisted=true` and `voodooSpell=false`**, not unlocked.

Damage metadata does not by itself establish server-recognised gameplay damage. Special spell descriptions contain outdated or conflicting text.

## Primary source: openly shared historical Booga Booga server
From [public legacy place extracted server Lua](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/booga/public-legacy/extracted/source/ServerScriptService/Big%20Mama_10942.server.lua):
- Around lines 3519–3577: server adds 0.2 for each qualifying equipped Void item, multiplies by 2 in that historical script, clamps Voodoo to 100.
- Around lines 5034–5051: server reads `_G.sessionData[player.UserId].spell`, takes `itemData[spell].voodooCost`, checks server-side Voodoo, deducts it **before** processing Energy Bolt. An obvious client override of mana/cost cannot be inferred from this handler.
- Around 2033–2038: `RequestData` returns player session data; it does not return private script source.
- This code uses older `rep.Events.*` RemoteEvents; Reborn uses a newer `packets.*` interface. **It is not the present Reborn server source** and cannot prove its internal validation behaviour.

## Live test outcomes that matter
- [Incoming stats vs client cache](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44308016334): saw real 30-point deductions and approximately 0.29/s restoration while cache/UI were previously stuck at 100. Earlier monitoring added packet listeners; *monitor-induced interference is possible*, so do not overinterpret the 100 cache.
- [Invalid Void Shroud craft request](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44310861368): one request yielded no real item.
- [God's Bolt selection](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44318047221): one request; Energy Bolt still selected.
- [Other 3 cost-zero special bolts](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44318511191): one selection request per entry; all left Energy Bolt selected.
- [Special regen bag eligibility](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44320829071): at level 40, no accessible special regen bag recipe; God Bag equipped. Void Bag and Void Shroud require level 100 and missing materials.

These are negative or incomplete tests; none establishes universal security or rules out every possible game bug. None confirms unlimited real Voodoo.

## Current external search (18 Nov 2026)
Public searches for `Booga Booga Reborn infinite voodoo`, `free lightning`, current server source, and cheats didn't reveal a credible verified **infinite Voodoo server-accounting exploit**. Some community sources describe endless *passive regeneration* or auto-casting when enough energy is available, which is not unlimited instant energy.

Background:
- [Reborn Spell wiki](https://booga-booga-reborn-wiki.fandom.com/wiki/Spell)
- [Spellmaster mojo upgrade](https://www.booga.gg/wiki/rebirth)
- [Jelly Sandwich reports 20% 30s boost, non-stacking](https://booga-booga-reborn-wiki.fandom.com/wiki/Food)

## Decisive result requirement and next branch
At the observed approximate baseline of **0.29 Voodoo/s**, continuously offsetting one **30-point Energy Bolt every second** requires roughly **100×** the current rate. Small normal buffs cannot accomplish that.

To claim success, require evidence of **all**:
1. Authentic game state has less than 30 Voodoo or a deduction/refill cycle consistent with extra accepted casts;
2. Another cast produces independently verifiable **server-sustained damage**;
3. The result survives a clean rejoin and cannot be explained by a local display override.

No evidence currently meets all three.

**The technical blocker:** Our recovered source is the client, and the server handles that set the actual cost, regeneration and damage for *this* game have not been published or made available. The next genuinely novel route is obtaining an **authorised copy of current Reborn server code or development test access**, then inspecting and reproducing the resource-accounting logic there. Do not misrepresent the historical code as a live-server vulnerability.

**Do not repeat** fake `Data.voodoo` writes, non-owned crafting attempts, random special-spell IDs, and visual Bolt replication as a supposed infinite solution. They have already produced no confirmed result.
