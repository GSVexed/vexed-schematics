# Booga Booga Reborn — zero-Voodoo bolts and alternate Lightning pathways
**Investigated:** 18 November 2026  
**Basis:** Original uploaded `UPLOAD_PART_010_DATA(1).zip` (not server source); live Velocity/Roblox read-only audit [run 44314604101](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44314604101); public spell descriptions for background.

## Live user-approved restricted spell selection trials — 18 November 2026

The user explicitly accepted the possibility that these tests could replace normal Energy Bolt. The code was compiled with Luau 0.747 and launched **inside the active Roblox/Velocity session** through the existing self-hosted Windows runner. The tests made direct, ordinary `PromptSpellChoice.send(itemID)` requests and **never wrote local `Data.spell`**, intercepted packet listeners, cast a spell, or consumed items.

| Candidate | item ID | Transport | Local game `Data.spell` after observation |
|---|---:|---|---|
| God's Bolt | 354 | One request, no local error | Energy Bolt after 19 seconds |
| Rainbow Ray | 89 | One request, no local error | Energy Bolt after 9 seconds |
| Equinox Bolt | 353 | One request, no local error | Energy Bolt after 9 seconds |
| Bullet's Ray | 144 | One request, no local error | Energy Bolt after 9 seconds |

- [God's Bolt live workflow 44318047221](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44318047221), status `NO_SELECTION_CHANGE_WITHIN_19_SECONDS`, `request_count=1`. `unlockedSpells["God's Bolt"]` also remained unset.
- [Remaining three live workflow 44318511191](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44318511191), status `ALL_THREE_NO_SELECTION_CHANGE`, `request_count=3`, each `send_ok=true` but selected spell stayed Energy Bolt. The character advanced from level 39 to 40 while playing; no change attributed to this script.

**Interpretation:** All four attempts reached the client send path without a local error, but none produced an observed spell-selection change. This is consistent with server-side rejection (possibly because the player already has a selected spell), and no free zero-cost damaging bolt was demonstrated. The test does **not** reveal the server's private reason for rejecting requests or prove whether a fresh character without an existing selection could ever choose these restricted IDs. Do not repeat these requests on the same account without new evidence. A rebirth/character reset is a separate, potentially destructive action and was **not** attempted.

---

## Core finding
The decompiled item data includes **four combat-sounding entries with `voodooCost = 0`**, but all four also have `blacklisted = true` and `voodooSpell = false`:

| Item | itemIDS | listed damage | cost | blacklisted | voodooSpell | in normal chooser | unlocked on checked client |
|---|---:|---:|---:|---|---|---|---|
| God's Bolt | 354 | 90 | 0 | true | false | No | No flag present |
| Rainbow Ray | 89 | 70 | 0 | true | false | No | No flag present |
| Equinox Bolt | 353 | 70 | 0 | true | false | No | No flag present |
| Bullet's Ray | 144 | 60 | 0 | true | false | No | No flag present |
| Energy Bolt (baseline) | 360 | 35 | 30 | false | true | Yes | Selected |

Definitions are in `UPLOAD_PART_005_DATA/sources/game/S0009390_part001.source.txt`, mirrored locally as `game_ReplicatedStorage_Modules_data_itemData_data.txt` around lines 14656–14748; numerical IDs in `S0009392`. These damage figures are **metadata, not observed live server damage**. The descriptions for the four free abilities inconsistently say "5 Voodoo" and "60 AOE damage" despite `voodooCost=0` and differing damage numbers. Treat as unverified developer/restricted/legacy entries, not four proven callable spells.

## Live read-only entitlement check
Compiled [read-only inspector](booga-bolt-entitlements-v1.lua); automated launch inside live Roblox through Velocity via self-hosted runner was **successful**. [Live audit](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44314604101) reported:
- `selected_spell` = `Energy Bolt`.
- Normal `VoodooSelect.List` has an Energy Bolt entry and it is visible; all four special items are absent from that list.
- `Data.unlockedSpells` exists as a table but contains no readable unlocked flag for any of the four special names.
- No spell selection requests, modifications, listeners, casts, item uses, keyboard inputs or other game actions were performed.

## Cast and authority path
The recovered client `S0010320` (`Game/spells`) calls `packets.VoodooSpell.send({targetPos, aimDirection})`. The `S0009504` packet schema is exactly `{targetPos = vec3, aimDirection = vec3}`; it supplies **no spell name, damage, cost, bolt variant or item ID**. The legitimate UI `PromptSpellChoice.send(itemIDS[chosenName])` is a separate control flow.

Implications:
- Editing local `gameUtil.Data.spell`, `itemData.voodooCost`, a local animation, or forcing a rendering packet does **not by itself** authorise a new server-recognised spell type or damage.
- A truly useful zero-cost ability would require the **server itself** to associate the player with an eligible castable ability, then apply damage without normal Voodoo spending. We have **not demonstrated** such an association or validated any bypass.
- A raw `PromptSpellChoice` for a blacklisted spell might be rejected, or if unexpectedly accepted might permanently replace Energy Bolt; **not executed**, because there is no verified safe rollback or permission. No claim of exploitability.

## Other superficially similar projectiles
1. **EnergyBolt** packet is received by `S0010288` rendering module via `.listen`, with origin, target, segments and time. It schedules visual segments based on game time. It is **not a client-owned command to cause damage**. Server may send it for genuine strikes.
2. **Weather storm lightning** uses `S0010362` (`createLightningStorm`), `S0010359` (`createLightning`) to instantiate short-lived neon segments and sounds near local player; no Voodoo cost because it's not a player-cast attack. Client-side creation isn't proof of damage.
3. **Boss lightning** in `S0010374` is received through `HeadlessHorseman.listen` and renders yellow neon lightning. The server controls monster attack behaviour; visual playback does not grant a player the same attack.
4. **Crossbow/ballista Bolt ammunition** is an ordinary ranged projectile (item `Bolt`, inventory/crafting/use-tool). `S0010401` processes `CreateProjectile`, `ProjectileImpact`, and server-owned `ServerCreateProjectile`; this is a *different weapon and damage pathway* with ammo/tool prerequisites, not free Energy Bolt magic.
5. **Admin "Smite"** action is exposed in a separate moderation GUI `S0010712` and calls `ModSend:InvokeServer("smite", target)`. The UI handles an "Insufficient permissions" response. Not a normal player spell or free cast.

## Exhaustive source cross-reference audit (additional verification)

Reopened and scanned the **exact original uploaded ZIP** `UPLOAD_PART_010_DATA(1).zip`, SHA-256 `8327295d1eb972b9a59103a9cedd66d4d56f254116f2bcffa157cb0a9f7602fd`, across **388 archived game source files**.

- Each of `God's Bolt`, `Rainbow Ray`, `Equinox Bolt`, and `Bullet's Ray` occurs **only** in `S0009390` (itemData) and `S0009392` (itemIDS), **zero references in gameplay activation scripts**.
- `PromptSpellChoice` occurs only in `S0009504` (packet definitions) and `S0010320` (regular spell GUI client).
- `UnlockSpell` occurs only in those same two files, and the only gameplay-side `UnlockSpell` use is `.listen` on an incoming notification.
- `voodooSpell` occurs only in itemData; it is never consumed in an archived client activation script.
- `voodooCost` occurs only in itemData and the spell client, where it governs **local animation gating** before sending the normal cast packet.
- `blacklisted` occurs in itemData and an unrelated moderation blacklist UI; no player spell-access mechanism for the four items appears in client source.

**Risk:** normal gameplay docs state selected spells cannot be switched until rebirth; this player has Energy Bolt already. We have **not** transmitted `PromptSpellChoice` with a special ID because, if unexpectedly accepted, it might replace their selected working spell with no verified restoration procedure. A rollback attempt via the same selection packet is not reliable proof of reversibility if the server enforces one choice per rebirth.

**Practical conclusion:** The regular player UI/cast path exposes no means to activate these four entries. Server-side permission, entitlement, or event mechanisms are not present in the archive. This does not logically prove no bug exists, but sending arbitrary item IDs to the live player account would be an ungrounded, potentially destructive test—not a validated access method.


## Most useful next validated steps
- Do not use or promise a four-bolt switcher or spam `EnergyBolt` notifications: zero local metadata cost alone is not server-authorized damage.
- To establish any route, an authorised server-side diagnostic would check actual selected spell, allowed casting flags, energy deductions and damage events, ideally in a private dev environment. The recovered archive omits all server handlers.
- Without owner access, only non-destructive live entitlement and visual/energy observation are verified here. The previously tested one-shot underlevel Void Shroud `CraftItem` request also granted nothing; see [server-validation record](BOOGA-VOODOO-SERVER-VALIDATION-2026-11-18.md).
- If the user explicitly accepts a possibility of losing/replacing their selected spell and game terms permit testing, a single controlled selection request might test the authorization boundary; this has **not** been attempted and must not be described as a working method.

**Conclusion:** The four zero-Voodoo definitions are real and worth documenting, but current evidence indicates **restricted/unavailable client metadata**, not four proven zero-cost damage attacks available to the player.
