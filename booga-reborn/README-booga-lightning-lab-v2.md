# Lightning Lab v2 — Hold-V continuous Energy Bolt trials

**Target:** Booga Booga Reborn, Roblox place `11729688377`.

**One-line Velocity loader:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-lightning-lab-v2.0.lua"))()
```

## Controls and promise

- Use your **already selected Energy Bolt**; the hub never selects spells or buys items.
- **Hold V** to send scheduled casts with the selected options.
- **Release V** to immediately cancel all queued casts. No background auto-casting.
- **F6** stops all hub casting until you rearm with the button.
- **X** closes and disconnects the hub. Re-running replaces both earlier Lightning Lab and the current one.
- Scroll the switch list to see additional options. Adjust pulses/second with +/-.
- Rate is bounded to 2/4/6/8/12 pulses per second and 24 script attempts per second. Native Roblox's normal V KeyDown cast may also happen once at the beginning of a hold.

**IMPORTANT:** The success of `VoodooSpell.send()` is only the successful **client-side submission** of a typed packet. It is not evidence that the server accepted the request, charged Voodoo, created a projectile, or damaged Dave. The script does not change server-owned player energy, game code, Dave Health or actual currency. Spamming extra requests may be ignored or could trigger game anti-cheat.

## Switches

| Switch | Function / hypothesis |
|---|---|
| Direct Spell Packets | Submit native typed `VoodooSpell.send({targetPos, aimDirection})` without input-animation scheduling. |
| Replay Game UI Handler | Invoke the real `SpellImage.Activated` callback if the executor exposes `firesignal` or `getconnections`. More native client checks than direct packet mode. If unsupported, this may not work. |
| Alternate Both Methods | Alternate direct calls with the above UI handler; reverts to direct if native replay cannot be called. |
| Double Pulse | Schedule two distinct cast attempts per pulse, bounded globally. Not proven to duplicate server-accepted spells. |
| Triple Pulse | Schedule three cast attempts per pulse. Mutually exclusive with Double Pulse. |
| Aim Lock: Dave | Target nearest positively identified, loaded Dave stump. |
| AOE Offset Sweep | Alternate strike target within a small 2-stud cross around loaded Dave; useful to compare impact/area hit behavior. |
| Aim Direction: Target | Aim trajectory toward strike target rather than the camera. |
| Voodoo Energy Guard | Avoid sending requests below the item-data's reported 30-Voodoo cost. |
| Regen Smart Pace | Reduce outgoing cast pulse frequency when local Voodoo is low. **It does not increase the actual regeneration rate.** |
| Timing Variation | Apply a bounded +/-12% pulse interval jitter, not a guaranteed bypass. |
| Sustained Burst Requeue | Shortcut toggle for enabling/disabling bounded double pulses while V remains held; not independent of Double/Triple. |

For **continuous rapid attempts** with a single chosen lightning spell, try Direct mode with Aim Lock and the energy guard OFF, start at 2 pulses/s, increase only if the game visibly accepts casts. With the guard OFF, the script also sends requests when the local bar is low: **this does not grant extra energy and may be rejected or penalized by the server**.

For the closer-to-normal game path, use Replay Game UI Handler and Energy Guard ON. The UI handler checks the Voodoo cost client side and can refuse calls even if the direct mode is willing to try.

Only one of the Direct, Native and Alternate mode switches can be active, and only one of Double and Triple pulse can be active. All options still require the V key to be held.

## Grounding from recovered archived client source

Previously recovered user archive `UPLOAD_PART_010_DATA(1).zip` includes:

- `game/ReplicatedStorage/Game/spells` (ID 10320): the desktop V handler and the main spell icon handler use `VoodooSpell.send` with `targetPos` and `aimDirection`. They check `voodooCost` before animations; the V key handler still submits the packet if that local display/animation condition isn't met. The icon handler only submits under the local energy check. This does **not** establish the server validation behavior.
- `game/ReplicatedStorage/Modules/data/itemData/data` (ID 9390): `Energy Bolt` has `voodooCost=30`, `damage=35`, `aims=true`, and an in-game description that says 30 AOE damage. This source discrepancy is unresolved; neither value is confirmed for damage to Dave.
- `game/ReplicatedStorage/Game/stats` (ID 10326): client Voodoo bar driven by incoming `UpdateStats` from game packets. Modifying local `gameUtil.Data.voodoo` does not establish server-granted energy.
- `game/ReplicatedStorage/Game/boosts/data` (ID 10368): visible buffs include `Voodoo Passive`, `Void Armor`, and `Jelly Sandwich`; these are described as flat Voodoo boosts. The hub monitors the visible buff widgets without creating or altering those boosts.
- `game/ReplicatedStorage/Modules/data/itemData/data` (ID 9390): Spellmaster Mojo upgrade description specifies extra Voodoo regeneration.
- Native UI event replay depends on your executor exposing a callable signal API; this has not been tested in Velocity live.

## Genuine Voodoo-regeneration routes

These are legitimate **in-game** avenues and do not come from the hub artificially writing Voodoo values:

1. **Spellmaster Mojo**: a permanent purchase, 3 Mojo Points, extra Voodoo regeneration. Source: https://www.booga.gg/wiki/rebirth
2. **Void Armor**: a set of genuine armor pieces; the Reborn wiki says additional equipped pieces improve regeneration. Source: https://booga-booga-reborn-wiki.fandom.com/wiki/Spell
3. **Void Bag / Candy Bag / Easter Bag**: the Reborn wiki lists these as Voodoo-regenerating bags. Source: https://booga-booga-reborn-wiki.fandom.com/wiki/Spell
4. **Jelly Sandwich**: Reborn wiki says +20% flat Voodoo boost for 30 seconds, refreshed (not stacked) on repeated consumption. Source: https://booga-booga-reborn-wiki.fandom.com/wiki/Food
5. **Inside The Void**: listed in community documentation as a regeneration condition; behavior may differ across game versions. Source: https://booga-booga-roblox.fandom.com/wiki/Voodoo

Check ownership and status inside the game. The hub does not automatically craft, buy, equip, or consume any of the above.

## Current status

- Official Luau 0.747 compiler and source-level checks: **PASS**, workflow https://github.com/GSVexed/vexed-schematics/actions/runs/44275830774
- Live game/server-accepted extra lightning: **NOT YET TESTED**
- Additional real damage on Dave: **NOT ESTABLISHED**
- The replicated Dave HP readout may reflect hits from other players.
