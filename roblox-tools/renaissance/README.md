# FERAL Project Renaissance 15.5.0

Territory farming is now built into the main hub as its fifth tab. The same window, Right Shift key, scheduler, saved tab selection and unload lifecycle own both the original 21 feature records and Amber 0.5.0.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()
```

Open **Territory** and select **START FARMING** after spawning and joining a pack. Farming starts disabled. The existing combined Amber launcher opens this page directly. Hiding the hub or changing tabs keeps farming running; STOP or unloading the hub releases its owned input.

The update adds strategic 3×3 region sweeps and local routes, contested-hex skipping, stable claim completion, interrupted/full drinking, faster bounded tree recovery, sustained sprint/Burst and trailing NPC pursuit. See the [complete 15.5 / Amber 0.5 report](../feral-amber/docs/V0_5_RELEASE.md) for exact behavior and bounds.

**Validation:** 187/187 retained Renaissance regressions plus 170/170 Amber regressions pass with the pinned official Luau compiler/interpreter. All 23 embedded modules, complete bundle, fixtures and launcher compile; source parity and earlier rollback hashes pass. Published checks are recorded on the release pull request.

**Live gameplay remains unverified for this version.** No current Roblox/Potassium session is available here. Tests do not establish accepted speed, NPC damage, full-map retention, income, sustained stamina or recovery effects. Previous core features retain their earlier limits.

## Build

```bash
python3 roblox-tools/feral-amber/build.py
python3 roblox-tools/renaissance/run_tests.py \
  --luau /path/to/luau --compiler /path/to/luau-compile
python3 roblox-tools/feral-amber/run_tests.py \
  --luau /path/to/luau --compiler /path/to/luau-compile
```

Official Luau commit: `97b2f4bf9cd935bed666f3e643a3b749b4d22f38`. The complete bundle embeds thirteen core modules and ten Amber modules; no runtime Amber source downloads are needed.

## Rollback

All prior versioned bundles remain unchanged. Previous Renaissance 15.4.3:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/4dbf0780ca10aad757dd64631293b823cd4e7eed/roblox-tools/feral-renaissance-v15.4.3.lua"))()
```

To restore the companion Amber 0.4 as well, follow its [rollback instructions](../feral-amber/README.md#rollback).

## Records

- [Current release report](../feral-amber/docs/V0_5_RELEASE.md), [release metadata](release.json), [test results](test-results.json).
- [Architecture](docs/ARCHITECTURE.md), [21-feature audit](docs/FEATURE_AUDIT.md), [historical release notes](docs/RELEASE_NOTES.md).
- [Native territory/input contracts](../feral-amber/docs/native-contracts.json), [previous live evidence](docs/LIVE_EVIDENCE.md).

There is no diagnostics tab or automatic report upload. Territory has an optional local COPY STATUS button.
