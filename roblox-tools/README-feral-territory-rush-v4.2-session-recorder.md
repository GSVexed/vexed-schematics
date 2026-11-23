# FERAL Territory Rush v4.2 — local session recorder

This is an opt-in client-side FERAL hub. It does **not** prove server-invisible movement, server-accepted underground claiming, successful feeding or combat. Those outcomes must be established from ordinary gameplay and the game's replicated state.

## Launcher

Run in FERAL:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-territory-rush.lua"))()
```

The stable loader launches the previously published FERAL NOVA main hub and the `feral-territory-rush-v4.2.lua` addon.

## Collecting a session report

1. Spawn an animal, join a pack, and enable the modes you intend to try. The recorder starts automatically when the Territory Rush panel loads.
2. Play normally. Periodic observations are stored in memory. When Potassium exposes the `writefile` function, the same local file is updated approximately every **45 seconds**. All report data stays on the local device unless **you** share it.
3. After the test, press **SAVE REPORT** at the bottom of the Territory Rush panel. This tries to save the full JSON report as a text file and copies the same JSON to the clipboard when supported.
4. Find a file named `FERAL_TERRITORY_RUSH_V42_SESSION_<timestamp>.json.txt` in your executor's workspace folder. Upload that text file directly to the next ChatGPT message.
5. If no file appears, click **COPY JSON**, paste the clipboard contents into Notepad, save as `.json.txt`, and upload that file. If neither file writing nor clipboard access works, the script prints the JSON in the executor console on request.
6. Pressing the panel's X button attempts a final local save, too. A game crash can lose data since the previous autosave.

## What is captured

- **Every ~2 seconds:** territory mode, selected hex, current attempted hex, actual replicated owner/claim/scent state, move type, animal position and speed, hover's distance from surface, position error and correction cooldown, health/hunger/thirst, native feed eligibility, approximate FPS, nearby-player count and nearest-player distance
- **Every ~3.5 seconds, change-only:** per-territory replicated ownership relationship, claim progress, scent and claim state; tiny ordinary scent drift is filtered
- **On events:** manual actions, territory handoffs, observed claim/scent progress, correction failures, underground hold results, native E/attack input attempts and care completion/timeouts
- **Summary:** completed actions, corrected snaps, underground attempts and observed server-state changes, final mode and error messages

Rolling-buffer caps: 650 events, 1,800 periodic samples (about one hour at two-second intervals), and 1,000 significant hex-state changes. Oldest observations are discarded after caps are reached, so save before exceptionally long sessions.

**Privacy:** Other players' names, user IDs and chat contents are not intentionally recorded. A name scrub applies to status messages. No webhooks, outgoing data uploads or GitHub credentials are used.

## Important distinctions

- A local teleport, physics hover or altered appearance is **not** proof of server acceptance or genuine invisibility to other players.
- A replicated territory change is an observation, not incontrovertible proof that the controller caused it if packmates are also acting.
- A native E key or attack input is **not** proof that hunger increased or prey died. The recorder captures subsequent observed state for validation.

## Verification

Source and official Luau compiler checks: https://github.com/GSVexed/vexed-schematics/actions/runs/45203262017 — **success**.

**Live gameplay result: unverified.**
