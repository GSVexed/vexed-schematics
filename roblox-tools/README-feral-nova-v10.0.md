# FERAL NOVA v10.0 — Coordinated Gameplay Hub

**Built:** 21 November 2026  
**Status:** Software release with **23 embedded modules**, **54 startup checks**, and the official Luau full-bundle and regression suite passing. Live **v10** game/server validation is still outstanding; v9 successfully reached READY in a real Potassium session.  
**Canonical release:** `feral-nova-v10.0-potassium.lua`.

**Deep stability hotfix, 21 November 2026:** The startup GUI check now uses the actual mounted `FeralNovaV100` UI; old v10 overlays are removed on reload and each UI module shutdown is separately protected. Additional v10.1 variants of AFK and Grab V2 repair synthetic-input filtering, reject numeric nonpositive string session IDs and clear stale minigames across animal death/change. The existing one-paste v10.0 release URL includes these fixes. All changes have dedicated official Luau mocks; real-server acceptance still requires live testing.

## One-paste Potassium loader

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v10.0-potassium.lua"))()
```

Right Shift = show/hide hub. End = full shutdown. **DATA** (top-right of UI) opens the new four-tab evidence dashboard.

The new build is intentionally based on the working v9.0 game action architecture, which preserves the original v7.5 bite-damage repair. Do not run two different FERAL loaders simultaneously. If normal attacking or another native action behaves unexpectedly, press **End**, and use the v7.5 rollback launcher below.

## What the overhaul actually did

### Shared action authority

The v9/v10 action core replaces scattered game-action priorities with a single read-only state policy:

- **Native grab session > captured > actual combat > real attack input > native bite eligibility > carrying/climb/flight > AFK movement > idle.**
- Recovery releases Rest whenever a real conflicting higher-priority action starts and can resume afterward; the broader local-only bite hint no longer creates needless healing pauses.
- Auto Escape now defers its legacy shake/tug automation during the actual Grab V2 timing minigame.
- Hub-initiated native G carrying checks the action policy before an input and again if that input was deferred; *manual* native G remains untouched.
- Buffered Q climbing defers to actual grabs/menus/chat and retains the 2.25-second buffer and one guarded re-tap.
- Optional short ground AFK movement owns an expiring low-priority lease and cancels for real user controls, grab, combat and unsafe surroundings.
- All callbacks, leases and client-local overrides are designed to be cleaned up on shutdown and reloading.

### Recovery and noncombat status effects

- The original successful v7.5 combat-first Rest release remains in place.
- Noncombat hidden-pose native Rest uses a 5-second compatibility request refresh while still, and at most a 3-second bounded refresh while moving and wounded. Actual HP effects are **not guaranteed** by local Rest flags.
- Regeneration configuration is a reversible client edit, not evidence that the server accepted additional healing.
- The game’s recovered `NeedsConfig` lists 0.01 base HP regeneration and a 2× Rest multiplier, and the recovered status config indicates a 4× Rest multiplier for relevant status clearance. Those are *game config values* and do not prove every server outcome.
- It does **not** forcibly regenerate health while fighting, fabricate injury expiration, or write Humanoid Health.

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

1. Exactly 23 embedded modules; **19 legacy gameplay module bodies remain byte-for-byte identical to v9**; four updated components (v10 UI, evidence, v10.1 AFK and v10.1 Grab) each match their standalone source.
2. Official Luau compilation of the hub and all 23 embedded modules, plus the final canonical release script.
3. v7.5-style attack-safe native Rest lifecycle, combat-tag and mask retry regression.
4. v9 Action Core state priorities, native bite vs client hint, timed lease preemption and cleanup.
5. Automated AFK heartbeat mock and no unsolicited movement.
6. Native Grab V2 timed single-press mock, manual input priority and practice-id exclusion.
7. NEW v10 own-animal evidence mock: clean HP status observations, changing movement phases, max-HP growth exclusion, combat exclusion and safe disposal.
8. Failure containment, v10 GUI identity, old-overlay removal and protected controller cleanup verified by static/startup checks.
9. Regression cases for synthetic idle mouse input versus real keyboard/primary-click control, cancellation of active AFK travel, negative string practice Grab IDs, and Grab session cleanup after death or animal change.

**Important distinction:** The above are source parity, simulated game event and compile tests. They cannot prove that the live game server accepts or rewards all attempted local actions. The v10 release remains open to live-specific corrections.

## Architecture and inherited features

The bundle has 23 Luau modules. It preserves 19 v9 module bodies unchanged. Four components are independently checked: `feral-nova-evidence-v10.0.lua`, `feral-nova-ui-v10.0.lua`, `feral-nova-afk-v10.1.lua` and `feral-nova-grab-v10.1.lua`. This is a stability hotfix inside the existing v10 distribution URL, not a claim of newly supported server authority.

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
