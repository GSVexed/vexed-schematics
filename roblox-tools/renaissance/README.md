# FERAL Project Renaissance — 15.8.6 hold-to-bite and minigame compatibility

**15.8.6** fixes two known scheduler barriers: input backends cannot generate another InputBegan by pressing an already-held M1, and previous versions entirely disabled bites during all grab minigames. Repeated M1 now requests a single owned Up → Down → Up edge when no validated native bite callback is available; each edge is asynchronous and can be safely cancelled on respawn, unload, or a new minigame.

During a **hunter** grab minigame, a validated native WolfController bite callback can run in parallel with the native grab timing automation **only when** the original M1 minigame binding is confirmed separated and a physical M1 hold is observed. The minigame's automatic timed presses are unchanged. Prey and captured players, native FeralClamp/carry restrictions, R2 minigame controls, unsafe or unavailable native bindings, and synthetic mouse fallback during grabs remain blocked. FERAL server-side permission and acceptance are not bypassed; no extra Bite or BiteHit requests are fabricated.

The build uses the existing 15.8.5 adaptive speed governor and retains all voice, Hippo, Territory, recovery and settings features. Gameplay acceptance requires independent live validation, not user diagnostics.

## Previous 15.8.5 candidate


**15.8.5** addresses held bite input lost to private callback discovery, synthetic minigame interference, early fake-hit attribution and aggressive client-only cooldown requests. Hold to Repeat Bites now combines M1/R2 edges with held-state polling, uses an optional bounded real-input replay when the native callback is isolated (no direct hit remotes), and pauses through native minigame windows. Faster Bites begins at 62% of stock local timing, cautiously approaches 55% after repeated uniquely matched positive server replies, and retreats toward stock timing on recurring clean stock-range no-damage windows. Client timing and server acceptance are still different. The old 15.8.4 immutable release and stable launcher are unchanged.

## Previous 15.8.4 candidate



**15.8.4** integrates an optional **Extended Proximity Hearing** toggle in the existing Vision tab, enabled by default and saved with other preferences. It listens for compatible default Roblox voice AudioEmitters, increases only local attenuation distance points by 25%, and restores prior values at OFF/unload or peer replacement. It has no manual diagnostic step and does not touch voice microphones, mute/permissions, game remotes, combat, minigames, or Territory.

The auditory effect is conditional on Roblox actually exposing voice AudioEmitters and transmitting the audio. Older/private voice systems and server voice distance restrictions cannot be bypassed by a local attenuation change; audible range is not live verified. **Use the new 15.8.4 candidate from its own branch, not the stable launcher.** The 15.8.3 release and stable rollbacks remain intact. The 15.8.0 historical file absent from this Hippo branch is restored from the independently archived PR #15 version (SHA256 ba69a1ef...), not presented as the missing Hippo 15.8.0 build (SHA256 e9c51181...).

## Prior 15.8.3 candidate

The candidate adds held left-click and R2 native bite repetition, a faster client bite cooldown, optional Auto Bite, moving-target lead, safer hit-reply matching, a Burst stamina fix and residual-condition recovery. Hippo assistance includes charge information, movement while charging, matching native gait HUD highlights and optional native smart release.

**251/251 core scenarios and 263/263 Territory scenarios pass.** The complete candidate contains 28 modules. Live damage, server-accepted attack rate, recovery and movement remain unverified. Damage uncapping, ability cooldown bypasses and the proposed Turtle shell protection for Hippo are not established.

See the [held-bite release notes](docs/V15_8_3_HELD_BITES.md), [implementation ledger](docs/V15_8_HIPPO_COMBAT.md), [15.8.1 HUD/Turtle investigation](docs/V15_8_1_HUD_TURTLE.md) and [15.8.2 Test Features](docs/V15_8_2_TEST_FEATURES.md). The versioned candidate bundle is `roblox-tools/feral-renaissance-v15.8.3.lua`. The stable launcher below still resolves to 15.7.0.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/37024d31941f0b20f62280d4c44e1102c847b79a/roblox-tools/feral-renaissance-v15.8.3.lua"))()
```

## Stable release: 15.7.0

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

Candidate 15.8.3 adds a **Test Features** page with a local report and a private PC runner sync. Territory retains its optional local COPY STATUS button.

### Zoom Unlock (15.6.2)

Enabled by default; use **Movement → Zoom Unlock** to switch it off. The normal mouse wheel can zoom from 0.5 to 100,000 studs where the standard camera supports it. Native limit changes are observed and reapplied, with current game defaults restored on OFF/unload. Scripted camera poses, collision behavior, camera subject and FOV stay under the existing camera controller. No extra overlay or keybind. This camera feature is retained in the 0.7 Territory release.

### Hippo ability speed (15.7.0)

The captured v2412 controller forces its run boolean off during Crusher Bite and consumes a trot-scaled Species value. The earlier cap-only patch did not change this calculation. A reversible, Hippo-only adapter now supplies the corresponding native sprint or Burst tier for Shift/X, on land and in surface water. Ordinary walk/trot, native denial, ability timing and cleanup remain covered. Server-accepted speed remains live-unverified; see the [native contract evidence](../feral-amber/docs/V0_7_RELEASE.md#hippo-ability-speed).
