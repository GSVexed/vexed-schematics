# FERAL NOVA v10.0 — Coordinated Gameplay Hub

**Built:** 21 November 2026  
**Status:** Software release with **23 embedded modules**, **54 startup checks**, and the official Luau full-bundle and regression suite passing. Live **v10** game/server validation is still outstanding; v9 successfully reached READY in a real Potassium session.  
**Recommended active release:** `feral-nova-v10.3-moving-recovery-potassium.lua` (previous v10.0 and v10.2 remain available as rollback versions).

**Recovery integration hotfix, 21 November 2026:** In addition to the v10 startup, AFK and Grab repairs, the current loader now bundles a v10.2 **manual Rest sovereignty** controller and v10.2 action policy. Manual in-game Rest is given ownership of its pose and is no longer overwritten or cancelled by the automatic Rest mask. Merely having a native-bite-ready animal nearby—friend or foe—never counts as combat and does not halt active recovery. Actual attacks, server combat tags, captures/grab timing and explicit AFK movement still have action priority. The UI reports manual Rest distinctly, and all UI module shutdowns are now individually guarded. Dedicated official Luau mocks pass, but live game-server effects remain unverified.

## Current v10.3 moving recovery / visual Rest fix (recommended)

**Issue:** User observed the animal visibly resting while moving with the automatic recovery controller enabled. The previous v10.2 Native Recovery treated any `WolfRest=true` echo arriving more than one second after its last own Rest request as evidence of **manual** Rest, unbinding the pose mask and leaving a moving Rest animation visible.

**v10.3 fix:** A late Rest echo inside an owned automatic session is kept auto-owned and masked. The local pose guard now also runs before animation evaluation when `RunService.PreAnimation` exists, and at earlier render priority. Stationary, deliberately entered manual Rest remains protected; starting actual movement hands ownership back to the masked **automatic** recovery controller without introducing a movement-related `Rest(false)` pause. The guard excludes the inherited manual pose from repeated-own-echo safety counting. Attack and combat exclusions remain unchanged.

Use the **fresh v10.3 launcher** to avoid the older download cache:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v10.3-moving-recovery-potassium.lua"))()
```

A new actual startup report should show `"version":"10.3.0"`. The v10.3 script bundles 23 modules with all names resolving correctly. [Full Luau and simulated regression results](https://github.com/GSVexed/vexed-schematics/actions/runs/44937937943) pass, including a delayed automatic pose echo and stationary-manual-to-moving-auto handoff. **Live visual appearance to other players and actual server healing while moving are not yet independently confirmed.** A local pose mask cannot guarantee how the server or other clients render the character. Shut down previous builds with **End** before loading v10.3.

## Previous v10.2 cache-safe loader (rollback)



**As of 21 November 2026:** The old `v10.0-potassium.lua` download URL may be cached by the executor. After renaming the Native Recovery, Action Core and Unified Active Recovery modules to v10.2, the earlier script's preflight `MODULE_ORDER` still referenced legacy v9 filenames. Although the canonical GitHub file has since been corrected, repeated user Potassium startup reports showed `Missing module source: feral-nova-native-recovery-v9.0.lua`, version `10.0.0`, proving an outdated payload was still executed.

To bypass that stale download, use this **new filename / URL**:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v10.2-hotfix-potassium.lua"))()
```

The cache-safe file is byte-identical to the corrected canonical release except its `v10.2` banner, two startup/session version strings (`10.2.0`), and active-record version (`feral-nova-v10.2`). Its 23 embedded modules, preflight names, and runtime `get()` references match. The official validation workflow tests the new file directly. An actual game report should show `"version":"10.2.0"`; `10.0.0` indicates an older script was executed. Shut down any existing instance with **End** before launching the new one.

## One-paste Potassium loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v10.0-potassium.lua"))()
```

Right Shift = show/hide hub. End = full shutdown. **DATA** (top-right of UI) opens the new four-tab evidence dashboard.

The new build is intentionally based on the working v9.0 game action architecture, which preserves the original v7.5 bite-damage repair. Do not run two different FERAL loaders simultaneously. If normal attacking or another native action behaves unexpectedly, press **End**, and use the v7.5 rollback launcher below.

## What the overhaul actually did

### Shared action authority

The v9/v10 action core replaces scattered game-action priorities with a single read-only state policy:

- **Native grab session > captured > actual combat > real attack input > native bite eligibility (guide only) > carrying/climb/flight > AFK movement > idle.** Native target/bite eligibility is **not** itself a recovery-blocking attack.
- Automatic recovery releases only its **own** Rest signal for conflicting actual actions, then resumes after they end. Physical Rest requested by the player takes precedence: the hub yields and does **not** overwrite `WolfRest` or send an automatic `Rest(false)` against the player's Rest. A nearby animal alone cannot trigger a recovery pause.
- Auto Escape now defers its legacy shake/tug automation during the actual Grab V2 timing minigame.
- Hub-initiated native G carrying checks the action policy before an input and again if that input was deferred; *manual* native G remains untouched.
- Buffered Q climbing defers to actual grabs/menus/chat and retains the 2.25-second buffer and one guarded re-tap.
- Optional short ground AFK movement owns an expiring low-priority lease and cancels for real user controls, grab, combat and unsafe surroundings.
- All callbacks, leases and client-local overrides are designed to be cleaned up on shutdown and reloading.

### Recovery and noncombat status effects

- The original successful v7.5 combat-first Rest release remains in place for actual attacks and combat, while native-bite proximity no longer interrupts resting with teammates.
- Noncombat hidden-pose native Rest uses a 5-second compatibility request refresh while still, and at most a 3-second bounded refresh while moving and wounded. Actual HP effects are **not guaranteed** by local Rest flags.
- Regeneration configuration is a reversible client edit, not evidence that the server accepted additional healing.
- The game’s recovered `NeedsConfig` lists 0.01 base HP regeneration and a 2× Rest multiplier, and the recovered status config indicates a 4× Rest multiplier for relevant status clearance. Those are *game config values* and do not prove every server outcome.
- It does **not** forcibly regenerate health while fighting, fabricate injury expiration, or write Humanoid Health. Manual Rest has its own explicit status; when you leave manual Rest, the automation may re-arm outside combat.

### Combat, Eagle, stamina and movement

- Existing stamina/no-drain configuration, attack guide, client reach hints, flight surface assist, native Talon/carry attempts, baby carry safeguards, quick climb, ESP and animal state tracking are preserved.
- Real server-recognised oversized carrying and shortened server Talon cooldown are **not established**. Native server replies and actual sustained clamp/hold observations must support claims.
- The user previously confirmed working bite damage and enemy health bars in v7.5. v9 maintained successful native Rest/attack mocked regression tests, but v10 must still be checked in live combat before we call it fully gameplay validated.
- Infinite *server-owned* hunger/thirst is **not established**. The hub reads real values and does not spoof server needs.

### Anti-idle, survival activity, Auto Perfect

- Roblox anti-idle attempts VirtualUser input and displays a clear best-effort status. No claim that this prevents every engine timeout or game-side transfer.
- Survival AFK is a **separate, opt-in** short-real-walk assistant, OFF by default. It may be unsafe near predators and may not prevent server survival-bonus pauses.
- Grab V2 Auto Perfect acts on *native server-issued strike packets* with real synchronized current timestamps. Correct local timing does not establish guaranteed server Perfect grading, and negative/practice IDs are never sent as real requests.

## New DATA dashboard

The **DATA** button in the hub header has four tabs:

| Tab | Measured values |
| --- | --- |
| **SURVIVAL** | Moving vs stationary clean HP increases per second, ratio, injury/bleed/venom clearance, stamina consumed, hunger and thirst lost, survival credit changes |
| **COMBAT** | Action policy, granted action leases and denials, grabbed-minigame strike/press count, recognized server Perfect replies, bite hints and escape status |
| **ABILITIES** | Eagle clamp observations vs local oversized labels, Talon local clock adjustments, native carry/climb/flight status |
| **SYSTEM** | Latest action priorities, update/cache counts, AFK settings, evidence sample count and errors, shutdown keys |

**Evidence Engine safeguards:**

- Only own-animal and game-local values are observed, no coordinates/player identities/chat/credentials.
- Samples after growth-induced max-HP changes, during combat, across motion/Rest transitions, or after respawn are excluded from clean movement comparisons.
- Clean rate estimates require multiple intervals. A positive health increase is an observation, **not proof that this hub caused it**.
- The evidence module does not write player attributes, call game remotes, transmit HTTP data or change the game.
- The privacy-filtered private Potassium collector now supports the v10 schema and own-animal dashboard metrics.

### Latest available real-game observations

The latest private report available during the build was **v9.0**, with **22/22 modules loaded**, **49/49 startup checks passed**, and a live Bear session. Its Grab V2 controller observed native strike events and sent native press requests. **No recognized server Perfect reply** was recorded. The survival number advanced during gameplay, but the player was active, so this is **not** evidence of unattended bonus retention. These are not v10 live results.

## QA

Official GitHub Actions workflow: [FERAL v10 validation](https://github.com/GSVexed/vexed-schematics/actions/workflows/feral-nova-v10.0-validate.yml). The tests validate:

1. Exactly 23 embedded modules; **16 legacy gameplay bodies remain byte-for-byte identical to v9**. Seven changed components—the v10 UI, evidence, v10.1 AFK/Grab, v10.2 native recovery/action core/unified active recovery—each match standalone source.
2. Official Luau compilation of the hub and all 23 embedded modules, plus the final canonical release script.
3. v7.5-style attack-safe native Rest lifecycle, combat-tag, manual Rest and pose-mask retry regression; auto recovery resumes after a user leaves manual Rest.
4. v10.2 Action Core: nearby native bite targets do not stop recovery, but actual mouse attacks, combat, capture, minigame leases and AFK safety still take precedence.
5. Automated AFK heartbeat mock and no unsolicited movement.
6. Native Grab V2 timed single-press mock, manual input priority and practice-id exclusion.
7. NEW v10 own-animal evidence mock: clean HP status observations, changing movement phases, max-HP growth exclusion, combat exclusion and safe disposal.
8. Failure containment, v10 GUI identity, old-overlay removal and protected controller cleanup verified by static/startup checks.
9. Regression cases for synthetic idle input versus manual control, AFK travel cancellation, negative string Grab IDs, and grab cleanup after death or animal change.
10. Unified Active Recovery mode transitions: `MANUAL_REST` → `NATIVE_RECOVERY` → `COMBAT_BLOCKED`, without falsely treating manual Rest as missing healing uptime.
11. Manual Rest respected even when already active before the hub loads; safe shutdown never sends an auto-owned Rest-off request against it.

**Important distinction:** The above are source parity, simulated game event and compile tests. They cannot prove that the live game server accepts or rewards all attempted local actions. The v10 release remains open to live-specific corrections.

## Architecture and inherited features

The bundle has 23 Luau modules, retaining 16 original v9 bodies unchanged. Seven updated modules are independently checked against their standalone code: `feral-nova-evidence-v10.0.lua`, `feral-nova-ui-v10.0.lua`, `feral-nova-afk-v10.1.lua`, `feral-nova-grab-v10.1.lua`, `feral-nova-native-recovery-v10.2.lua`, `feral-nova-action-core-v10.2.lua` and `feral-nova-active-recovery-v10.2.lua`. These corrections are shipped inside the existing v10 loader path and do not claim server authority.

The older, mutually exclusive Safe Rest and Mobile Recovery Test components remain available as diagnostic/rollback tools but are not automatically enabled. This avoids losing previous experiments while the integrated Active Recovery controller retains ownership of normal gameplay.

Full source/architecture [audit](FERAL-NOVA-v9-ARCHITECTURE-AUDIT.md). v10 release candidate [full source](feral-nova-v10.0-release-candidate-potassium.lua).

## Rollback / game troubleshooting

**Known v7.5 fallback**:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v7.5-potassium.lua"))()
```

To capture actionable real-game confirmation: load v10, check that **normal bites still reduce enemy HP**, move while injured outside combat for several seconds, use one actual Grab V2 minigame, and open **DATA**. Compare measured HP rates and recognized server results; don’t equate an ON toggle with proven server benefit.

## Honesty about "finished"

This is the completed **architecture-and-integration software release**, not a certification of 100% success for server-owned mechanics. The outstanding live experiments are: 20+ minute anti-idle retention, unattended survival credit, same-stage moving recovery speed, server-confirmed Perfect frequency, larger Eagle carries, Talon server cooldown, and any genuine hunger/thirst authority change. We cannot guarantee or invent those outcomes without server-access or actual live evidence.
