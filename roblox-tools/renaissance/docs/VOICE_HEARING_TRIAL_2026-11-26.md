# FERAL Extended Proximity Hearing — isolated v0.1 trial

This candidate is separate from the stable Renaissance hub and from the 15.8.3 combat candidate. No combat, recovery, flight, UI, stable launcher, Territory, minigame input, settings or voice recordings are modified.

## Purpose and limits
- For default **AudioEmitter** instances on remote players who also have an **AudioDeviceInput**, multiply the local attenuation distances by **1.25** (25%).
- Preserve custom curve volume levels and scale only distance coordinates. For built-in preset modes, scale NumberRange bounds.
- No microphone data, voice samples, recordings or other players' mute/access decisions are read, captured or sent.
- If no suitable visible voice emitters or no explicit custom curve exists, report unsupported rather than fabricating success.
- Client-side attenuation does not defeat the Roblox server's transmission/routing boundaries. An adjusted curve is **not proof of extended audible voice**.
- No live FERAL voice session has been tested; not promoted to main hub.

## Load isolated candidate
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/b11d44950a5c22ae86397c5314cb2e7b134dbd60/roblox-tools/feral-voice-hearing-experiment-v0.1.lua"))()
```

Run beside the 15.8.3 candidate; the module is independent of the hub. Default enabled at 25% extension.

## Controls
```lua
getgenv().FERAL_VOICE_HEARING:report()
getgenv().FERAL_VOICE_HEARING:setFactor(1.15) -- lower to 15%
getgenv().FERAL_VOICE_HEARING:setFactor(1.30) -- up to 30%
getgenv().FERAL_VOICE_HEARING:setEnabled(false)
getgenv().FERAL_VOICE_HEARING:setEnabled(true)
getgenv().FERAL_VOICE_HEARING:close() -- restore and unload
```

The result reports remote player counts, identified inputs/emitters, adjusted emitters, restorations, failed/skipped cases, and flags that server transmission is not extended.

## Test protocol
1. Have another voice-enabled player speak at a measured distance in FERAL.
2. Check `report()` for an adjusted emitter. If status is NO_VOICE_EMITTERS or NO_COMPATIBLE_CURVE, do not claim improvement.
3. Compare voice audibility at identical positions and speaker volume with feature disabled and enabled.
4. Repeat on different species, after respawn, and after teleport or voice reconnect. Check for chat loss/distortion.
5. Toggle OFF and unload to confirm the original perceived range returns. Never treat changed local properties alone as confirmation of actual hearing.

## Release gate
Review official Luau compile and pure attenuation-curve tests in `.github/workflows/feral-voice-hearing-trial.yml`. Live verification is required before folding into any Renaissance settings or hub release.
