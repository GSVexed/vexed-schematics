# Booga Booga Reborn — actual PC / server-Voodoo authority investigation
Date: 2026-11-18

## Result: Genuine client/server mismatch detected; no increased regeneration proven

On a real Windows 11 desktop with Roblox and Velocity in the same interactive session, the GitHub Actions self-hosted runner **loaded and executed** pinned Luau probes through Velocity's actual Open-file dialog and Execute UI. This was not just static source analysis.

### Direct evidence

- [PC shared-session capability check](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44300718931): one Roblox and one Velocity process, both in runner's Windows session, Velocity Execute control accessible.
- [Native v1 successful live launch](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44303398107): real in-game report received, actual game PlaceId `11729688377`, passive Spellmaster tier 1.
- [Native v2 successful live launch](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44305259413): [v2 Luau](booga-voodoo-lab-v2.lua), [official compiler PASS](https://github.com/GSVexed/vexed-schematics/actions/runs/44305295859), inbound UpdateStatsUnreliable listeners installed. In-game `gameUtil.Data.voodoo` stayed 100 throughout while **server-origin `UpdateStatsUnreliable.voodoo` varied**. This is a **local value mismatch**. The root cause has not been isolated; an old local override or broken subscriber/update path are plausible, not proven.
- [Live native v2 data](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44306258340): real inbound packet value rose gradually at approximately **0.28–0.33 Voodoo/s** in clean observation windows. Three distinct inbound decrements were observed (e.g., **37→7**, **35→5**, **31→1**), consistent with real 30-cost casts. The displayed/local 100 did not equate to unlimited actual energy. The one test request targeting unoccupied air was *sent* but its resource cost could not reliably be attributed; do not count it as success.
- [Read-only owned-resource and recipe scout](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44306720757): player level 39, 18 rebirths, owns Spellmaster tier 1, God Bag equipped, head/torso/legs none. 17 ordinary inventory entries; no owned Void Shroud, Void Chestplate, Void Greaves, Void Bag, Candy/Easter/other regen bags, or Jelly Sandwich. No Jelly, Void Shards or Magnetite in ordinary inventory, and game `canCraftItem` false for Void Armour/Bag. The recovered in-game recipe data requires level 100 for Void gear. A single Crystal Chunk was in inventory. This is a **snapshot of one inventory surface**, not a claim about all possible storage.
- [One bounded real craft request](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44307166041): [Lua one-shot](booga-regen-craft-authority-v1.lua) sent exactly one ordinary `CraftItem` request for Void Shroud below the required level and with zero necessary materials. Before and after inventory count were both 0; **NO_SERVER_ITEM_GRANTED**. This rejects the naive idea that bypassing the client crafting UI creates genuine Void armour. Not a proof that every possible request manipulation fails.

## Source-backed constraints

The client's `Game/stats` normally copies inbound `UpdateStatsUnreliable.voodoo` into `gameUtil.Data.voodoo`, so the persistent 100 local vs much lower inbound value suggests an independent local override or malfunction. The authoritative server-side Voodoo regen formula remains unavailable. `SetBoost` and `UpdateStats` are server-to-client message listeners, not outgoing grant APIs. `VoodooSpell.send` carries target information and the server continues to charge real Voodoo. An outgoing request counter or arm animation cannot establish a damaging spell.

Spellmaster is already owned and contributes to native regeneration. User explicitly wants **much faster genuine server-recognized Voodoo regeneration**, not cosmetics, equip UI, resource grinding or repeated casts. **No client-side technique has yet produced a verified increase**. Do not publish a hub claiming one.

## PC workflow / safety notes

The session bridge uses GitHub Actions self-hosted Windows runner `GSVexed/chatgpt-minecraft-testlab` with controlled Velocity file-picker UI automation. Code is pinned to a precise Git commit for each run. Reports are restricted to dedicated JSON names in the executor workspace. Read-only scans excluded passwords, editor text, private PC documents, clipboard, chat or browser data. One ordinary sky spell request and one bounded Void Shroud craft request were the only experimental game packet sends in these runs. No repeated packet flood. The v2 monitor stops itself after 560 seconds.

## What would count as actual progress

An incoming server packet must show the Voodoo **slope** increasing after a genuine accepted change, and it should survive multiple server updates / normal gameplay. Equipment ownership or boost *display* alone does not qualify. An unauthorized bonus, if sought, is unverified until reproduced. A normal Void Bag/Armour/Jelly effect can be tested when legitimately owned; none was available in the observed inventory. Avoid unsupported claims of infinite regen.

## Current verdict

**Genuine measurable regeneration exists but remains approximately 0.3/s. Server-enforced casting costs are observed. Local apparent 100 Voodoo is misleading. Neither zero-resource gear creation nor an additional regen mechanism was demonstrated.**
