# Voodoo Sync v6.0 — genuine-effect helper

## Launch in Velocity

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-voodoo-sync-v6.0.lua"))()
```

**Focus:** The user already owns Spellmaster, a passive Voodoo-regeneration Mojo. This version does not try to buy or toggle it. It replaces v5's duplicate casting-route panel with genuine owned-effect activation and visible evidence.

## Implemented

- **Reversible session control**: live UI, tab for Lightning and tab for Genuine Regen, draggable panel, Right Shift hide/show, floating reopen chip, F6 emergency cast stop, close destroys the GUI and disconnects its listeners. Re-run closes known v4/v5 and earlier related hubs.
- **Hold V to attempt Energy Bolt** (2/4/6/8 requests per second): exact recovered `VoodooSpell` shape `{targetPos,aimDirection}` based on native mouse/aim behaviour. Does **not** wait on Voodoo in the script; releasing V stops added attempts. Real server still enforces its own energy rules. Counts requests, never claims those are actual strikes or damage.
- **Existing Spellmaster passive ownership**: reads `gameUtil.Data.mojoItems.Spellmaster`. Never sends `ToggleMojo` or `PurchaseMojoItem`; no Mojo Points spent.
- **Owned Void gear**: finds genuine item inventory keys for Void Shroud/head, Void Chestplate/torso, Void Greaves/legs and Void Bag/bag. One explicit click attempts `UseBagItem` for gear present but not equipped, with the native item lock check. Checks `gameUtil.Data.armor` after each request. Reports equipped, unowned, unconfirmed, locked; it does not fabricate gear ownership. **This may replace existing non-Void armour or bag.**
- **Owned Jelly Sandwich**: exactly one `UseBagItem` request only after two clicks within five seconds. Skips when the game's Jelly Sandwich boost is already visible. Checks native boost icon and owned inventory consumption afterward. No automatic item consumption; no invented stacking.
- **Voodoo telemetry**: reads the client's server-synchronised `gameUtil.Data.voodoo` over time; estimates idle Voodoo/s after stable 5+ second observations below cap and without a resource decrease. Accumulated gains and spending are observations and do not establish accepted spell counts or source attribution. Optional executor-local `booga_voodoo_sync_v6_report.json` contains a small own-session report if `writefile` is supported.

## Authority and limitations

This script uses recovered client sources for `Game/spells`, `Game/inventory`, `Game/armor`, `Game/mojos`, `Game/boosts`, `Game/stats`, `Modules/util/gameUtil`, `Modules/util/packets`, and `Modules/data/itemData`, archived on 18 Nov 2026. Source details and limits are documented in [the Voodoo regeneration audit](BOOGA-VOODOO-REGEN-AUTHORITY-AUDIT-2026-11-18.md).

**No discovered or demonstrated server-side exploit**: Cannot make the server grant extra regeneration beyond equipment, consumables or Mojo the player is authorised to use. A fake boost, client bar increase or extra packet does not equal Voodoo or damage. The script cannot make a 30-Voodoo spell free by sending faster. User-reported v5 "doesn't work" is not presented as resolved for unlimited Lightning.

**Evidence quality:** Official Luau v0.747 compile and static contract checks pass in [GitHub Actions](../.github/workflows/booga-voodoo-sync-v6-validate.yml). No live in-game use, successful equip, Jelly buff, extra real regeneration, or server-accepted rapid strikes has yet been personally verified by the assistant. If a button returns "unconfirmed," don't count it as a real effect. The script's source-derived item and module structure may change in later game updates.

## Practical use

1. Spawn in Booga Booga Reborn and select **Energy Bolt**.
2. Open **Genuine Regen** and confirm your Spellmaster passive shows owned.
3. Only if you have Void equipment in your bag and want to switch gear, click **EQUIP OWNED VOID REGEN GEAR**. Note the equipped/unconfirmed result.
4. If you have an actual Jelly Sandwich and intend to consume one, click its button twice within five seconds. This is optional.
5. With Voodoo below full, stand idle without casting for a few seconds to see the measured regeneration rate.
6. Hold V in the Lightning tab to attempt casts; release to stop. It cannot guarantee casts at zero Voodoo.

No purchases, resource spending or equipment switching happen automatically on load. Only the explicit Sandwich action consumes an owned item; the explicit gear action may replace worn gear.

**Note:** The user's requested unlimited server-recognised regeneration requires a separate validated server-accepted mechanism not established in the current source archive. Do not rebrand this optimiser as that breakthrough.
