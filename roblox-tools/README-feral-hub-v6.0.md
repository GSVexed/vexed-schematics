# FERAL HUB v6.0 — Health Recovery and Eagle Carry Focus

**Release:** `roblox-tools/feral-hub-v6.0-potassium.lua`.
**Game:** FERAL Animal Survival. **Scope:** your own character's client-side assistance, observed game responses, and recovery workflows. Server controls remain authoritative.

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v6.0-potassium.lua"))()
```

Full script is a standalone offline Lua bundle with 19 embedded modules. The hosted loader is optional. You can load the whole Lua file directly in Potassium if your executor lacks `game:HttpGet`.

## Why this exists

Your v4 live gameplay logs established that Health Recovery sometimes reaches `NATIVE_RECOVERY` but often reports `WAITING_FOR_SAFE_WINDOW`; real heal gains were observed. Eagle recorded server Clamp responses and local holds, but no strictly confirmed matching oversized assisted hold.

## Health recovery update

- The existing Active Recovery controller can now detect **12 eligible seconds of zero HP improvement** while its own native Rest signal is active on a wounded character. Rather than repeatedly assuming masked Rest is healing, it switches to the game's **genuine visible Rest** through the Safe Rest controller.
- Safe Rest retains its own stationary checks, nearby threats, combat, hunger/thirst and rest request controls. It cancels Rest during flying, diving, climbing, feeding and on Q input, as well as movement, attacks and carrying. The client doesn't force HP, clear real statuses, or pretend the server healed.
- This fallback may visibly rest/sit. It is intentional: natural Rest is more credible for server-recognised healing than hiding the Rest pose. If the game server refuses Rest or healing, the script cannot override that.
- The summary now reports `realRestFallback`, fallback counts and reasons, elapsed eligible masked time and observed gains. `REAL_REST_FALLBACK_ACTIVE` means a Rest request is owned; **not proof** that HP increased.

## Eagle carry update

- Preserves observed holds, local size-ratio accounting, per-target native reply evidence and anti-spam protections from v5.
- Rebinds the native `FeralLunge` event if it appears late or is replaced, without blindly guessing prey or sending extra requests. Records native remote bind and missing-remote counts.
- Keeps client-side estimates separate from authoritative outcomes. A server-rejected oversized player cannot be made carryable merely by client configuration or Potassium.

## Validation

- CI: https://github.com/GSVexed/vexed-schematics/actions/runs/44732975227 (SUCCESS). The entire standalone and all 19 embedded Luau modules compiled. Exactly five modules differ from v5; the other fourteen are unchanged.
- Mocked Eagle test: selection, assisted and independent holds, response correlation, late/replaced native event, local cooldown restore.
- Mocked Active Recovery test: action safety, no-healing trigger, transition to game-owned visible Rest, disabling/resetting that mode.
- Original v5 Growth comparison regression retained (growth is no longer the current development priority).
- Private runner workflow: https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/44733217462. A successful fixture/test runner is not live gameplay validation.

## Automatic diagnostics

- Own-character files: `FERAL_HUB_STARTUP_v6.json`, `FERAL_HUB_SESSION_v6.json`, and compatible native `FERAL_NOVA_v32_session.json`.
- The Windows runner runs the v6 Potassium collector about every 5 minutes and uploads only sanitised allowlisted fields to the PRIVATE file `diagnostics/feral-potassium/latest-v6.json`.
- v5 collector remains available on-demand but is no longer scheduled.

## How to evaluate

1. Close an existing v5 UI or rejoin, launch v6 in Potassium, then HELP > RUN SELF-CHECK (target **30/30**).
2. At less than full HP, use Active Recovery. When stationary and not under threat, check whether health gains occur while the native signal is active, or whether visible safe Rest engages after a no-heal trial. Observe actual HP over time, not status text.
3. For Eagle carry, check whether a larger-than-normal animal actually stays held in the game's real physics and whether the hub's remote/Clamp evidence records that. Server restrictions may reject the request. No guaranteed override is asserted.
4. Ask ChatGPT to check the private `latest-v6.json` report after the runner syncs. The assistant only sees that file when invoked in an active chat.

## Rollback and risk

**Validated live baseline:** [v4](feral-hub-v4.0-potassium.lua). **Prior CI-validated baseline:** [v5](feral-hub-v5.0-potassium.lua).

v6 has passed automated tests, but **not yet live Potassium testing**. Potassium and other third-party Roblox executors can violate platform rules and present account and security risks. Keep security protection enabled.