# DonutSMP Bonemeal V4: engineering baseline and validation plan

Status: **NOT YET FUNCTIONALLY RE-VERIFIED**. The original factory files have not been modified.

## Canonical reference

User-provided full four-module file:
- Filename: `DonutSMP-V4-Four-Modules-One-Sell-Wall (1).litematic`
- SHA-256: `44b409d5d6b8b3c58ddd34ce6c546b97caebfb91fb499e0565585bb0b138f310`
- Schematic NBT: 1 region, 36 × 29 × 18 bounding box, 18,792 total positions, 6,414 non-air positions, 555 block entities, 20 entities
- 487 hopper blocks, 579 redstone wire blocks, 136 wall torches, 120 repeater blocks, 116 sticky pistons, 120 regular pistons, 44 composters, 8 dispensers, 8 droppers, 4 moss blocks, 1 main lever
- Packed block-state indices decoded with no out-of-palette values.

Old compact single-module reference:
- SHA-256: `1d51b0f0aa9575f2a6d5943588b6b6d2dd02d4fb8620649e0c628e0de82bc591`
- 16 × 13 × 16, 1,542 non-air positions

These are structural measurements only, not production or reliability evidence.

## Priorities in order

1. **TestLab recoverability:** confirm current Minecraft version, Java 25 compatibility, TestLab supervisor/agent availability, local world backups, and safe test launch.
2. **Independent modules:** verify growth-and-break cycle, composter output, bonemeal return loop, loaded and idle clocks and per-module throughput at 20 TPS. Record each module separately.
3. **Distribution:** validate hopper routing, shulker loader/unloader, empty shulker replenishment, separate modules feeding the common sell wall and failures due to full storage.
4. **Reliability:** startup after chunk unload/reload, pause and resume, power cut while pistons operate, empty input inventory, storage full, restart after transient lag. Never mark PASS without an actual assertion.
5. **Measured throughput:** run at least 72,000 game ticks in a vanilla-compatible test engine with a fixed startup inventory; report net produced and collected bonemeal, loss, uptime, TPS, and any uncollected items. Measure each module and the integrated four-module assembly.
6. **Real-server differences:** label vanilla/Carpet results separately from Donut SMP observations, especially server TPS, anti-lag changes and plugin-driven item rates.

## Candidate optimisation hypotheses (not confirmed)

- Hopper count and unnecessary always-ticking item transportation may be reducible.
- Shared item transport or shulker supply may be a single point of failure.
- Shared master lever and long redstone lines require repeatable startup and pause tests.
- A fully independent modular design may recover better from one failed module.

## Required acceptance evidence

A release must identify the exact schematic SHA, Minecraft version, test harness and PASS/FAIL/INCONCLUSIVE results, including at least one extended production run, multiple module integration, stop/restart, full output storage, and chunk unload/reload tests. Do not imply that a GitHub Actions build alone verified farm operation.

## Build strategy

Preserve original V4 for comparison. Prototype alternative mechanisms in a separate branch or file. Only promote a new Litematica as a recommended build after the required behavioural tests pass.

## 2026-10-11 Round 2 engine baseline

A fresh local Minecraft **Java 26.2** engine test verified the **underlying** hopper/composter mechanics, not the complete V4 build:

- Hopper successfully transferred bonemeal into a chest.
- A moss-block input hopper fed a composter and collected resulting bonemeal into a separate chest.
- Both outputs were asserted against actual container item states before the combined PASS was emitted.
- [Test manifest](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/jobs/034-20261011-bonemeal-item-and-composter-engine/manifest.json), [result](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/034-20261011-bonemeal-item-and-composter-engine/result.json), [Minecraft log](https://github.com/GSVexed/chatgpt-minecraft-testlab/blob/main/results/034-20261011-bonemeal-item-and-composter-engine/minecraft-latest.log).

This establishes a repeatable starting point for validating the storage and composting components. **V4 functional performance, chunk-reload reliability, storage backup recovery and live Donut SMP equivalence remain unverified.**
