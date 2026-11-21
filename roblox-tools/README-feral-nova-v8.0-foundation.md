# FERAL NOVA v8.0 — Foundation / Overhaul Phase 1

**Date:** 21 November 2026  
**Status:** Public foundation release, compiled and mock-tested; **not automatically activated in the live Roblox session**.  
**Stable fallback:** [FERAL Hub v7.5](README-feral-hub-v7.5.md), where user-confirmed normal bite damage was restored.

## Launcher (optional preview)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v8.0-foundation-potassium.lua"))()
```

**Right Shift** opens/minimises the UI. **End** closes the hub and its new AFK controllers. Do not stack versions. The version registry is `feral-hub-v8.0`.

## Evidence-based explanation of AFK mechanics

The recovered FERAL client scripts contain **two separate AFK concerns**, independent of Roblox's own idle timer:

| System | Exported configuration | What it means |
| --- | --- | --- |
| Roblox engine | Common ~20-minute inactivity disconnect; `Player.Idled` is a read-only event | A virtual input method might keep the idle clock active, but success must be tested on a live client |
| FERAL native AFK | `AfkConfig.HOP_AT=1080`, `WARN=60`, `KICK_AT=1200` | The FeralAfk client counts local input/inactivity and may ask the server to transfer to another instance |
| FERAL survival bonus | `SurvivalConfig.AFK_AFTER=120`, `AFK_MOVE=4` | A bonus-pause condition appears tied to actual movement, not simply a mouse event |
| FERAL reward progression | `LocalPlayer:GetAttribute("FeralSurvival")` in FeralSurvivalUI | Hub observes this replicated value; it never writes it or claims unearned survival credit |

These are **recovered client configuration values**, not server-side source code. The server may also enforce checks that cannot be observed from the client. The v8.0 controller attempts to read the active replicated config instead of relying only on the archived defaults.

## Feature A: ANTI IDLE KICK

**Default: ON.** After a sufficiently long idle period, the hub tries Roblox's `VirtualUser:CaptureController()` and `ClickButton2` with `Player.Idled` as a fallback trigger. Success is a successful *input API call*; it is **not** proof that the Roblox engine or the FERAL AFK script reset their respective timers. The underlying APIs might be unavailable or behave differently in a given executor. FERAL or Roblox may still transfer/disconnect the user. Use the status report to distinguish `INPUT API UNAVAILABLE` from `VIRTUAL INPUT SENT / RESET UNVERIFIED`.

- This system does **not** teleport servers or issue FERAL AFK server requests.
- The automatic input is deliberately infrequent and generally only occurs when user input has been absent.
- It does **not** move the animal or establish that survival-bonus accumulation continues.

## Feature B: SURVIVAL AFK

**Default: OFF; user must explicitly opt in.** FERAL's survival system appears to require real positional movement. The new controller can occasionally ask the player's own `Humanoid:MoveTo()` to walk a short distance exceeding the currently replicated `SurvivalConfig.AFK_MOVE` by roughly two studs, then move back later.

This is a **real walk**, not a fake survival credit, a local attribute overwrite, a teleport, or a forged server message.

The assistant requires all of the following before moving:

- The game is running with a living, locally controlled animal.
- At least 55 seconds without user input; no immediate bite target or held attack.
- No active combat tag, carry, pinned state, climb, swim, fall, flight, visible Rest, seated or stunned state.
- At least 80% HP, adequate hunger and thirst, no positive injury/bleed/venom attributes.
- No other humanoid in the nearby 28-stud checked radius.
- Ground exists and is reasonably flat at the origin and candidate destination; no unsafe raycast corridor, cliff or water found by those checks.
- The candidate step is small and within the module's maximum permitted distance. If the game's required movement threshold increases beyond a safe checked step, the feature **refuses to move** rather than attempting a risky path.

Native Rest is released before the short walk; the v7.5 attack-first Rest logic is preserved. User input immediately cancels any ongoing automatic walk. It will not move if checks fail, and **the survival bonus may still pause**: checks are conservative but cannot guarantee terrain or predator safety.

**Important limitation:** We can verify that a replicated survival timer advances, but without server code and a controlled AFK experiment we cannot prove that the movement was counted by the server as valid activity or that it prevents every bonus pause.

## What was preserved and changed

This is an intentionally **non-destructive first stage of a larger overhaul**:

- 17 legacy modules embedded byte-for-byte unchanged from v7.5.
- Native Rest module revised only to recognise optional survival travel, releasing Rest during its movement.
- UI expanded to show two separate AFK toggles, statuses, reports and reset actions.
- New **Action Coordinator**: one read-only shared observation of bite, combat, carry/escape, menu, native locomotion and Rest state.
- New **AFK Controller**: separate engine-idle heartbeat and opt-in short safe ground movements.
- All original stamina, bite guide/reach, Eagle carrying, Talon local controls, flight, climbing, escape, baby carrying, health regeneration, visual tools and diagnostics remain present.

## Validation

- [FERAL NOVA v8.0 CI — 21-module parity, compile and mocked regression](https://github.com/GSVexed/vexed-schematics/actions/runs/44925831955)
- Exact bundle/module parity and previous 17 unchanged modules.
- Official Luau compiler passed for the full offline bundle and all 21 embedded modules.
- Existing v7.5 mocked attack/Rest lifecycle passed unchanged.
- New virtual-input callback / `Player.Idled` / no-animal safety-default mocked test passed.
- Private Potassium collector now accepts version `8.0.0` and safely exports only the new own-character AFK counters and observed survival progress, excluding secrets and other-player data.

**Not yet live-confirmed:** 20+ minute uninterrupted client retention, avoidance of FERAL's automatic hop, survival-bonus accumulation while unattended, movement safety on every terrain, or future server policy changes.

## Next overhaul workstreams

| Area | Preserved functionality | Next evidence-based overhaul work |
| --- | --- | --- |
| Stamina/endurance | User-observed stamina retention; original no-drain path | Formalise effects by animal, distinguish flight/burst/land paths, add rollback audit |
| Healing / injury / bleed / venom | User-observed noncombat mobile HP recovery, native Rest action, combat-safe release | A/B compare same-max-HP rates and actual `FeralInjury` decay during safe windows; minimise interruptions without disabling bites |
| Combat / bite reach | v7.5 attack compatibility confirmed by user; local bite geometry guide | Validate native bite start and target HP reduction independently of visual hitbox/health bar |
| Eagle / Talon | Native single-press path, physical clamp observers, local cooldown gate | Verify oversized hold vs server clamp; compare server-accepted Talon timings |
| Climbing / flight / mobility | Buffered Q and guarded second tap; flight surface guard | Compare successful activation under the same terrain and native conditions; improve conflicts |
| AFK and survival multiplier | New, *unverified* | Live duration test: confirm engine and game AFK clocks, real survival timer continues, zero unsafe move |
| UI and settings | Added two AFK controls without replacing the stable six-card layout | Progressive reorganisation into species-specific panels, clear supported/experimental/unsupported labels |
| Lifecycle and diagnostics | Full controller shutdown and startup self-check | Consolidate overlapping status collectors, verify no duplicate event loops and no stale native Rest requests |

## Rollback

The previous v7.5 script remains unchanged:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v7.5-potassium.lua"))()
```

Do not run both versions concurrently. Prefer closing with **End** before switching. If the animal is in an unsafe area, disable **SURVIVAL AFK** or revert to v7.5.
