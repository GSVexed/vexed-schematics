# ARENA NOVA — v4.1 live MATCH capture

The first match capture on 2026-11-22 exported 80 valid Luau v14 bytecode files and stopped at its intentional 80-attempt budget. A lobby comparison found 82 additional eligible match-only script paths not yet exported. This updated collector targets that gap without doing in-game decompilation.

**Only run in a live Arena of Survival match.** Paste:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/arena-nova-bytecode-first-v4.1.lua"))()
```

MODE defaults to **MATCH**. Click **START CAPTURE** once. Allow it to finish or save a bounded partial result. Use **COPY REPORT** to see its summary, then tell ChatGPT the capture is finished.

### Changes from v4.0

- 480 rather than 80 new bytecode attempts in MATCH mode (still one getter invocation per candidate).
- 14,000 rather than 6,000 max discovered objects; up to 8 seconds of discovery.
- 26-second cooperative runtime budget.
- Reuses existing `ARENA_NOVA_BYTECODE_V4/cache-index.json.txt` cache, keyed by **place ID + place version + script path** so match code is not confused with lobby code.
- Keeps FPS stop guard, filesize limits, privacy exclusions, manifest checksums, checkpointing and **zero decompilation / network remote firing in-game**.

The game may use separate lobby and match places within the same universe. v4.1 does not retrieve any server-only source. Output is raw compiled client bytecode, which is **not privacy-redacted**.

The private GitHub pickup routine used to transfer v4.0 is currently pinned to v4.0. After the new collection, ChatGPT must update its scoped version gate and retrieve the latest v4.1 MATCH folder through the existing private Windows runner. Do not upload raw capture to a public repository.
