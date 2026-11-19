# FERAL AURORA NOVA v4.0 — minimal high-impact hub

The recommended current launcher for Roblox **FERAL Animal Survival**, PlaceId
\`108901361810209\`, running in the user's existing Velocity executor.

\`\`\`lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-aurora-nova-v4.0.lua"))()
\`\`\`

## What changed from Aurora FORCE v3.1

- **Two screens only, no scrolling:** CONTROL and ESP, with live HP/stamina/
  hunger/thirst across both. Compact 820×520 draggable window, viewport
  autoscaling, Right Shift hide/show and reopen chip.
- **One-tap setup:** locally selects 3× stamina recovery, enables player
  outlines, enables automatic escape watching, and enables native Rest
  recovery assistance. No 40-button setup.
- **Auto escape without holding ALT:** *when an explicit grab is detected*,
  emits short Space press/release pulses. It watches for character/player/
  humanoid grab-related attributes, visible on-screen escape prompts, and
  physical joints connecting the local animal to another player's animal.
  It pauses for chat, respawn and menu, then resumes watching. It has a
  clear INPUT UNAVAILABLE or INPUT BLOCKED indicator if executor injection
  is unavailable or fails.
- **ESP fixed:** the existing replicated-player tracker is reused (including
  respawn handling, distance caps, and cleanup), but every highlight has
  \`FillTransparency=1\` and \`OutlineTransparency=0\`: genuine outline-only,
  without body-color overlays or glow. Names are optional, compact and
  unboxed above the animal, with text stroke for legibility. Track range
  200/400/800 studs, optional through-wall outlines.
- **Other relevant controls:** STOCK / 3× RECOVER / APEX client stamina
  selector; NORMAL / SWIFT / FAST speed; NORMAL / LONG / MAX leap;
  native recovery assist, night visibility and calm camera. Full reset.
- Existing working v2.1 core and v3.1 power module are preserved; this
  is a UI and detection upgrade, not a new unverified stamina engine.

**Defaults:** outline ESP ON, name tags OFF, auto-escape watcher ON.
Experimental stamina/speed/leap, night view, camera and recovery assistance
start OFF. One-Tap Setup enables the practical recovery bundle explicitly.

## Critical verification limits

Lua syntax and static source requirements are checked in GitHub Actions
by \`.github/workflows/feral-aurora-nova-v4-validate.yml\`; live Roblox/
Velocity acceptance has **not** been verified by the developer.

The client-side script can watch for a grab and attempt Space input.
The exact server-authoritative latch signal is not established in recovered
FERAL client evidence. If a grab exposes none of the recognized cues, the
watcher will show **WATCHING** without pressing Space. If key simulation is
rejected or ignored, the script cannot force the game to recognize escape.

Client settings do not create Amber, grant health immunity, bypass server
permissions or guarantee infinite Burst. Previous prolonged Burst deaths
were unexplained. APEX is **high-risk**; 3× RECOVER is the default one-tap
choice.

The launcher is hosted on GitHub; it does **not** use GitHub Actions to
control a user's PC or automatically start the game. To run it, paste the
one-line loader into Velocity while inside FERAL.

## Files

- \`feral-aurora-nova-v4.0.lua\` — public launcher
- \`feral-aurora-nova-ui-v4.0.lua\` — compact UI, auto-escape watcher and ESP styling
- \`feral-aurora-engine-v2.1.lua\` — retained player tracker / own-status engine
- \`feral-aurora-power-v3.1.lua\` — retained reversible client tuning
- \`.github/workflows/feral-aurora-nova-v4-validate.yml\` — compiler + checks
