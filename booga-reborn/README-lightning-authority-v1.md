# Booga Booga Reborn — Lightning server-authority experiment v1

**Status: officially Luau-compiled; not confirmed in a live server. Not an infinite-Voodoo hub.**

## Critical limitation identified on 20 Nov 2026 — target validity

This v1 probe is **not a valid stand-alone proof of infinite Voodoo**. It selects a **non-player creature** and treats the creature's replicated Health loss as a proxy for an accepted Energy Bolt. The only publicly available *historical* Booga server handler that we can inspect applies Energy Bolt AOE damage to **players**, not necessarily critters or resources. Therefore, even a perfectly accepted cast could leave the tested NPC's Health unchanged. The captured current Reborn **client** does not prove that it damages non-player targets.

**Do not interpret zero NPC damage as a server rejection, or positive damage as a free cast** without a current-game authorised target and independent damage and balance evidence. The experiment remains a bounded client request/cached-resource test only. We cannot certify server-recognised infinite energy from this script; no credible current-version exploit has been validated. See [20 Nov Voodoo server-authority checkpoint](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/pc-lab/BOOGA_VOODOO_CURRENT_SERVER_AUTHORITY_CHECKPOINT_2026-11-20.md).

## What is different from v4–v6?

Previous hubs periodically sent `VoodooSpell.send({targetPos,aimDirection})`. More outgoing requests were wrongly confused with actual strikes. This experiment tests one *distinct and falsifiable* hypothesis: **can two back-to-back, same-client-execution-slice spell requests result in two damaging strikes while the player has only enough Voodoo to afford one?**

That hypothesis is not established by static source; it is a test for possible server-side request ordering. It will usually fail when the server checks and deducts energy synchronously.

## One-line launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/booga-reborn/booga-lightning-authority-v1.lua"))()
```

## Controls and bounded live test

1. Enter Booga Booga Reborn with **Energy Bolt** selected, spawn alive and aim at a **non-player boss or creature** with a replicated `Health` NumberValue/IntValue or Health attribute. No auto-aim and no shots at players from this tool.
2. Start at **30–59 genuine Voodoo**, because one 30-cost cast is affordable and two ordinarily are not. Spellmaster may regenerate some Voodoo during observation, so interpret the amount spent carefully.
3. Press **B** once to send a single normal `VoodooSpell` request; it observes lowest target Health and Voodoo over 5 seconds. No repeated requests.
4. After energy regenerates to 30–59, press **N** once to send **two consecutive VoodooSpell requests without any yield**. Observe lowest target Health and Voodoo over 5 seconds. The program cannot guarantee ByteNet/server processing order.
5. Press **COPY RESULTS** to copy JSON to the clipboard and write an executor-local `booga_bolt_authority_v1.json` where supported. F6 closes; four-test maximum and 9-second cooldown prevent automated request loops.

The output separates **request count, observed target health reduction, observed lowest Voodoo and errors**. It flags a **possible** two-for-one when the double test shows at least 55 points of target health loss and under 45 displayed Voodoo loss. This is *not proof*: other damage, armor/mitigation, AoE, regeneration, replication delay or server scheduling can confound the result. A meaningful result needs an isolated target and repeated matched comparisons. Health loss may fail to appear if the NPC doesn't replicate a compatible `Health` property.

## Evidence from recovered game code

- `ReplicatedStorage/Game/spells` confirms Energy Bolt is requested through `VoodooSpell` with `targetPos` and `aimDirection`; the client sends a request even when it doesn't play the animation at low Voodoo.
- `Modules/data/itemData/data` lists Energy Bolt `voodooCost=30`, and a nominal `damage=35` while its description refers to 30 AoE.
- `Game/stats` reads incoming `UpdateStats` and `UpdateStatsUnreliable` into `gameUtil.Data.voodoo`.
- The recovered archive excludes the authoritative server handler; no client-side mechanism for arbitrary server Voodoo was found.

See [Voodoo authority audit](BOOGA-VOODOO-REGEN-AUTHORITY-AUDIT-2026-11-18.md).

## Outcome rules

- **Normal server enforcement:** Double request causes no greater damage than the single comparison, or spends 60 Voodoo when sufficient energy later exists. **Stop pursuing that avenue.**
- **Possible exception:** Two distinct damaging strikes at 30–59 starting Voodoo with only one actual 30-Voodoo charge. **Reproduce and distinguish other damage before calling it accepted.**
- **Unknown:** Only outgoing request attempts counted, no target replicated Health, or ambiguous damage. **No bypass conclusion.**

No new v7 hub has been created because no free casts or artificial regeneration have yet been observed. This experiment is an evidence gate, not a promised bypass.

**Validation:** [GitHub Actions compile and static tests](https://github.com/GSVexed/vexed-schematics/actions/runs/44293466660) passed. In-game server acceptance is unverified.
