# Booga Booga Reborn vs publicly shared legacy Booga — server source access and Voodoo comparison
**Date:** 18 November 2026  
**Question:** Can the current public Reborn server be made to send private scripts? Does the original legacy server implementation reveal a working live Voodoo bypass?

## Sources reopened
1. [Public legacy server source](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/booga/public-legacy/extracted/source/ServerScriptService/Big%20Mama_10942.server.lua), from a [public archival .rbxl](https://github.com/R4tD3v/RobloxGames/blob/main/Booga%20Booga.rbxl). This is **not** confirmed as current Reborn code.
2. [Current Reborn client protocol evidence](BOOGA-VOODOO-REGEN-AUTHORITY-AUDIT-2026-11-18.md), derived from the original user's recovered game client archive.
3. [Four blacklisted zero-Voodoo bolt attempts](BOOGA-ZERO-VOODOO-BOLT-AUDIT-2026-11-18.md), actually executed through Roblox/Velocity on the player's account.
4. A fresh public GitHub/source search for current Reborn server handlers, which found **client-side scripts** and an older legacy place, but no verified current server repository.

## What the legacy source proves

### Private gameplay data and regeneration
The legacy script `ServerScriptService/Big Mama`, around lines **3519–3577**, declares `validVoodooItems` for Void Chestplate, Void Bag, Void Greaves, and Void Shroud, each worth `0.2`, then calculates:

```lua
local totalVoodooRestored = 0
local worldVoodooMultiplier = 2

for _, armorName in next, _G.sessionData[player.UserId].armor do
    local voidClass = validVoodooItems[armorName]
    if voidClass then
        totalVoodooRestored += voidClass
    end
end

totalVoodooRestored *= worldVoodooMultiplier
data.voodoo = math.clamp(data.voodoo + totalVoodooRestored, 0, 100)
```

The excerpt is simplified for explanation. **This algorithm is from the legacy server**, not necessarily the current Reborn server. It relies on server-side session data; editing a locally replicated armour field does not demonstrate genuine server-equipped armour.

### Server checks spell cost
Near lines **5034–5051**, `rep.Events.VoodooSpell.OnServerEvent` reads `_G.sessionData[player.UserId].spell`, looks up `itemData[spell].voodooCost`, checks the server balance, subtracts the cost, and then processes the spell, including `Energy Bolt`. The cast request contains targeting, not a player-chosen cost.

### Does the old server expose its own script files?
Near lines **2033–2038**, `rep.Events.RequestData.OnServerInvoke(player)` waits for and returns `_G.sessionData[player.UserId]`. That is **the player's gameplay/session data**, not `ServerScriptService` contents or `Script.Source`.

An exact scan of the legacy main server source found no `.Source` or `Script.Source` reads, no `loadstring(`, and no file-source export command. This is evidence against an **obvious** existing source-transfer route in the inspected handler, not proof that no other code or vulnerabilities exist.

## Current Reborn client comparison

| Capability | Public legacy server archive | Recovered current Reborn client | What can be concluded |
|---|---|---|---|
| Spell cast transport | `rep.Events.VoodooSpell:FireServer(targetPos)` | `packets.VoodooSpell.send({targetPos,aimDirection})` | The protocol changed; old event calls are not drop-in compatible |
| Spell cost accounting | Server reads `sessionData.spell` and `itemData[spell].voodooCost` | Client uses 30-cost Energy Bolt metadata, but live server handlers absent | Local cost patches cannot be called authoritative |
| Voodoo restoration | Server computes an equipment-derived total and clamps to 100 | `UpdateStats` / `UpdateStatsUnreliable` received as notifications; no genuine client regen setter identified | No evidence of arbitrary client-specified regen amounts |
| Spell selection | No directly analogous current server handler recovered here | `PromptSpellChoice.send(itemIDS[chosenName])` | One request per special ID was tested; no selection change |
| Requesting data | Legacy `RequestData` returns own session record | Current Reborn client source includes data reads and incoming stats; details differ | A data response is not a code disclosure |
| Script-file export | No `Script.Source` reading/export in inspected legacy main handler | No verified exposed script-file export in the recovered current client protocol | No established mechanism to make public live server send private scripts |

## Practical result
- **Successfully obtained** 238 readable Lua scripts from a publicly released legacy place, including a real server-side Voodoo calculation.
- **Still missing** the present Reborn server implementation and permission to change or retrieve its private files.
- The exposed client packets and the legacy `RequestData` function give **no verified server-file download method or zero-cost Lightning method**.
- Do not repeat old blocked special spell requests, local Voodoo cache edits, or speculative source-exfiltration calls as though they were a breakthrough.
- To inspect current proprietary server handlers, obtain an authorised development copy from its owner or a genuine public source release. For reproducible gameplay testing, use the saved legacy place in Roblox Studio, but label the results **legacy only** and do not assume they apply to the public Reborn server.

## Project assets
- [Extracted legacy Lua scripts](https://github.com/GSVexed/chatgpt-minecraft-testlab/tree/main/booga/public-legacy/extracted/source)
- [Main recovered legacy server source](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/booga/public-legacy/extracted/source/ServerScriptService/Big%20Mama_10942.server.lua)
- [Legacy project extraction provenance](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/booga/public-legacy/README.md)
