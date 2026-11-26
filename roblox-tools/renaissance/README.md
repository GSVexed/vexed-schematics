# FERAL Project Renaissance 15.7.0

Territory farming is now built into the main hub as its fifth tab. The same window, Right Shift key, scheduler, saved tab selection and unload lifecycle own both the original 21 feature records plus Zoom Unlock and Amber 0.7.0.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-renaissance.lua"))()
```

Open **Territory** and select **START FARMING** after spawning and joining a pack. Farming starts disabled. The existing combined Amber launcher opens this page directly. Hiding the hub or changing tabs keeps farming running; STOP or unloading the hub releases its owned input.

The 0.7 upgrade adds observed travel costs, stable priority-aware itineraries, nearby region entry, scent deadline estimates, body-width support checks, longer checked obstacle routes, spatial recovery memory, unified survival decisions and complete-cycle accounting. It also corrects the actual Hippo ability speed calculation. See the [0.7 report](../feral-amber/docs/V0_7_RELEASE.md) and [all 44 prep items](../feral-amber/docs/PREPARATION_EXECUTION_LEDGER.md).

**Validation:** 202/202 retained Renaissance regressions plus 263/263 Amber regressions pass with the pinned official Luau compiler/interpreter. All 26 embedded modules, complete bundle, fixtures and launcher compile; source parity and earlier rollback hashes pass. Published checks are recorded on the release pull request.

**Live gameplay remains unverified for this version.** No authenticated game-execution connection is available here; the approved PC metadata check confirmed running apps only. Tests do not establish accepted speed, NPC damage, full-map retention, income, sustained stamina or recovery effects. Previous core features retain their earlier limits.

The [15.6.1 Territory patch report](../feral-amber/docs/V0_6_1_RELEASE.md) covers false native gait flags, close-prey facing, rejected virtual mouse fallback and retained attack evidence. The broader 0.6 navigation and survival overhaul remains.

## Build

```bash
python3 roblox-tools/feral-amber/build.py
python3 roblox-tools/renaissance/run_tests.py \
  --luau /path/to/luau --compiler /path/to/luau-compile
python3 roblox-tools/feral-amber/run_tests.py \
  --luau /path/to/luau --compiler /path/to/luau-compile
```

Official Luau commit: `97b2f4bf9cd935bed666f3e643a3b749b4d22f38`. The complete bundle embeds fourteen core modules and twelve Amber modules; no runtime Amber source downloads are needed.

## Rollback

All prior versioned bundles remain unchanged. Previous Renaissance 15.6.2 with integrated Amber 0.6.1:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/71051c5b707076f3a78080e745c649ae95ee4ae2/roblox-tools/feral-renaissance-v15.6.2.lua"))()
```

The 15.6.2 rollback includes its Territory page and Zoom Unlock. Earlier companion releases remain unchanged.

## Records

- [Current release report](../feral-amber/docs/V0_7_RELEASE.md), [release metadata](release.json), [test results](test-results.json).
- [Architecture](docs/ARCHITECTURE.md), [21-feature audit](docs/FEATURE_AUDIT.md), [historical release notes](docs/RELEASE_NOTES.md).
- [Native territory/input contracts](../feral-amber/docs/native-contracts.json), [previous live evidence](docs/LIVE_EVIDENCE.md).

There is no diagnostics tab or automatic report upload. Territory has an optional local COPY STATUS button.

### Zoom Unlock (15.6.2)

Enabled by default; use **Movement → Zoom Unlock** to switch it off. The normal mouse wheel can zoom from 0.5 to 100,000 studs where the standard camera supports it. Native limit changes are observed and reapplied, with current game defaults restored on OFF/unload. Scripted camera poses, collision behavior, camera subject and FOV stay under the existing camera controller. No extra overlay or keybind. This camera feature is retained in the 0.7 Territory release.

### Hippo ability speed (15.7.0)

The captured v2412 controller forces its run boolean off during Crusher Bite and consumes a trot-scaled Species value. The earlier cap-only patch did not change this calculation. A reversible, Hippo-only adapter now supplies the corresponding native sprint or Burst tier for Shift/X, on land and in surface water. Ordinary walk/trot, native denial, ability timing and cleanup remain covered. Server-accepted speed remains live-unverified; see the [native contract evidence](../feral-amber/docs/V0_7_RELEASE.md#hippo-ability-speed).
