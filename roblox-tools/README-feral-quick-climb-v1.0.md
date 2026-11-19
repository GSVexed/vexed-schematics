# FERAL Quick Climb v1.0 — optional add-on for NOVA PRIME v14

**Scope:** This is a standalone climbing-assist prototype, deliberately **not** a replacement NOVA PRIME v15 release. It can run in the same session as v14 without changing the v14 loader, Escape, Rest, native G carry, flight or bite-targeting modules.

## Launcher (run after v14)

\`\`\`lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-quick-climb-v1.0.lua"))()
\`\`\`

While sprinting toward a tree, **press Q once**. If you're too early, Quick Climb buffers that one intent for up to 1.3 seconds and triggers the game's own \`LocalPlayer.FeralClimbTap\` action as soon as the animal's native \`ClimbCan\` flag is true. It doesn't continuously spam Q and won't toggle you off an existing tree. A compact top-right indicator shows queue/ready/mounted and a toggle, along with COPY STATUS. Running the loader again stops the prior copy. Disabling stops the buffer and restores owned config changes.

## Recovered client evidence

- \`S0003916\` FeralClimbController: native keyboard \`Q\` via \`BindActionAtPriority("FeralClimbKey", ..., keyPriority=2500)\`; native UI/mobile uses \`LocalPlayer:SetAttribute("FeralClimbTap",os.clock())\` to call \`toggleClimb()\`. The client exposes \`ClimbCan\`, \`ClimbCanPos\`, and \`FeralClimbLocal\` as readiness/mount observations.
- \`S0000492\` PassiveConfig.CLIMBER: \`GRAB_REACH=.9\`, \`GRAB_FACING=.55\`, \`E_REACH=1.6\`, \`MOUNT_TIME=.32\`, \`HINT_RANGE=14\`. It distinguishes species and levels, including Bear Climber 1 and Red Panda/Cougar/SnowLeopard Climber 3.
- Basic climber levels have \`sprintGrab\` unset. Recovered code makes a high-speed approach ineligible for native mounting unless that capability is present; explains the difficulty catching a tree while being chased.
- The same Q binding overlaps with Dive. Quick Climb explicitly avoids an extra climb tap while \`DiveCan\` is true, or while carrying, resting, pinned, feeding or already climbing.

## Small reversible settings

When switched on, the addon changes only the shared **client** \`PassiveConfig.CLIMBER\` table: reach approx 1.3× (capped at 1.25), facing tolerance less strict (0.55→0.319), extended proximity 1.6→2.0, hint range 14→17.5, mount transition 0.32→0.24, and \`sprintGrab=true\` for levels 1 and 2. It tracks original values (including missing sprintGrab fields) and restores them when disabled or closed, provided another script has not overwritten them.

It does **not** modify trees, colliders, root sizes, Humanoid movement, FeralClimb RemoteEvent packets, other characters, or absolute positions. The server is free to reject an altered climb distance or eligibility. Neither this source nor GitHub CI can prove actual accelerated mounting in the live FERAL server.

## Validation

[GitHub Actions official Luau test](https://github.com/GSVexed/vexed-schematics/actions/runs/44575239585) passed: script compilation, native climb tap instead of fabricated remotes, Q queued before initial heartbeat, native \`ClimbCan\` readiness → exactly one \`FeralClimbTap\`, mount observation, Dive priority, local config lease restoration and safe shutdown.

## Related investigation (not patched in this addon)

The game's \`CarryConfig\` sets \`MAX_BABY_GROWTH=.34\`, \`MIN_CARRIER_GROWTH=.67\`, \`SAME_SPECIES=true\`, \`MAX_SIZE_RATIO=.55\`, and diet eligibility (carnivore/omnivore; some species excluded). The v14 Auto Escape immediately chooses \`getoff\` when its own baby character has \`FeralCarried=true\`. The observed last v14 copy had **2 getoff requests, 2 grab episodes and 0.22 seconds longest duration**: entirely consistent with automatic escape releasing a friendly pickup almost at once, although it does not prove which packet caused the release. A future coordinated option should allow **opt-in same-species adult baby carrying** only when the adult has a genuine outgoing \`FeralClamp\` pointing to the baby's character; genuine hostile pins should still be escaped. No change to Escape or native carry is shipped here because the user requested a project-status discussion before the next full release.

Historical recovery v1.3 used native \`Rest=true\` with a local rest-pose mask, showing recorded approximately 2% max HP/s outside combat and 4-point venom/bleed decreases; current v14 only changes local \`NeedsConfig\`/\`StatusConfig\` and does not make native Rest requests in the main non-Rest setting. That removal is the main known behaviour difference. The older mask had combat/Turtle interactions, so it should not be reintroduced wholesale.
