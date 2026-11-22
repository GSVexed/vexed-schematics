# ARENA NOVA v4.0 — Bytecode-first capture, offline analysis

**Target:** Arena of Survival, Roblox universe `7209131331`, place `72238253016204`.

## Potassium launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/arena-nova-bytecode-first-v4.0.lua"))()
```

Stop and close any older Arena diagnostic before running this one. Existing v1-v3 ZIPs are not overwritten.

### What v4 does instead

v1-v3 used `decompile()` inside Roblox; that process could be extremely slow and cause severe frame rate drops. This collector **never calls `decompile()`**. It indexes client-visible game scripts and relevant remotes, invokes Potassium's `getscriptbytecode(script)` on eligible LocalScript/ModuleScript/Client Script objects, and saves the returned binary bytes unchanged as `.luauc` files.

The manifest records each script's path, class, output file, byte count, Adler-32 checksum, first-byte format hint, cache provenance, completeness and failure counts. The archive is **self-contained**: all exported `.luauc` files live inside the capture folder. Prior cache hits are copied into the capture and labelled *unverified same-place-version/path reuse* rather than confirmed bytecode matches.

The tool omits other-player private characters and private/auth branches, and skips large Roblox platform modules. It has bounded discovery per root and queues scripts by gameplay priority. **It is intentionally not a complete dump of every platform script or every object property.**

### Performance safeguards

- **Lobby**: cooperative collection budget **50 seconds**, discovery allocation **13 seconds**, up to **350 new bytecode API attempts** and up to **22,000 visited objects**.
- **Match**: cooperative collection budget **18 seconds**, discovery allocation **4 seconds**, up to **80 new bytecode API attempts** and up to **6,000 visited objects**.
- Up to 2 MiB of bytecode per script and 48 MiB per capture.
- One bytecode retrieval attempt per candidate; no decompilation retries. Timeout is cooperative at 0.9 seconds per script, but **native executor code may block the Roblox client and therefore no hard runtime guarantee is possible**.
- Stop on sustained severe low FPS, repeated extremely slow bytecode retrieval, or five early errors with zero successful new captures.
- Yield frequently during discovery and extraction, checkpoint export files between stages, and write a persistent same-place-version/path cache index to avoid redundant retrievals on later scans.

### Run in lobby

1. Join the lobby. Close/stop previous diagnostics.
2. Run the launcher; leave **MODE: LOBBY**.
3. Click **START CAPTURE**.
4. When it finishes (or reports a partial capture), click **COPY REPORT** and paste the JSON summary into ChatGPT.
5. In Potassium's executor workspace, find `ARENA_NOVA_BYTECODE_V4/captures/LOBBY_<timestamp>_<id>/`. **ZIP the entire timestamped folder and upload the ZIP**. You don't need to include the entire cache folder.

### Run in match

Join a live round, load the same launcher, choose **MODE: MATCH**, then start. The short match mode is meant to capture newly visible client scripts and remotes. For later sessions, the cache helps avoid repeated `getscriptbytecode()` calls. The cache depends on previous capture folders remaining accessible on disk.

### Offline analysis

After receiving the ZIP, ChatGPT can verify the binary files against the manifest, inspect their Luau bytecode versions, group them by game feature, inspect metadata and attempt offline decompilation/disassembly using compatible tools.

**Important limitations:** `getscriptbytecode` yields compiled code for *accessible client scripts* only, not server-only code. Some bytecode may be compressed, obfuscated, inaccessible or newer than the formats supported by an offline decompiler; reconstructed source may have missing original variable names and altered control-flow representation. We cannot guarantee reconstruction of every script.

**Privacy:** Binary bytecode is **not redacted** and can contain embedded strings or other sensitive literal constants. Do not upload the archive unless you are comfortable sharing the contained code and are authorised to do so. The metadata collector excludes other-player private branches, but cannot scrub the bytes of compiled scripts without breaking the bytecode. Files are written locally and are never uploaded automatically.

**Validation:** [Luau compilation and static checks](https://github.com/GSVexed/vexed-schematics/actions/workflows/arena-nova-v4-bytecode-first-validate.yml) passed. This validates syntax, code structure and absence of `decompile()` invocation, not the actual Potassium API's performance or successful runtime operation.
