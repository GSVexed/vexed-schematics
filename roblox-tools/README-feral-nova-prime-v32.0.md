# FERAL NOVA PRIME v32.0 — Native Eagle carry confirmation

**Roblox:** FERAL Animal Survival, PlaceId `108901361810209`.  
**Release:** single standalone Luau file, 19 bundled modules, inherited full hub plus Eagle native-action improvements.

## One-line Velocity launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v32.0.lua"))()
```

## What changed in v32

### 1. Larger Bald Eagle catches

Recovered client source in the diagnostic archive (`UPLOAD_PART_003_DATA/sources/game/S0003869_part001.source.txt`, `S0003944_part001.source.txt` and `S0003941_part001.source.txt`) confirms:

- TalonView places an `ObjectValue` named `FeralTalonTarget` under the own bird character, with `Value=prey` and `At=os.clock()` (S0003944:652–671).
- The native WolfController uses `AbilityConfig.grabMode` and `AbilityConfig.attach` to obtain a mode and a relative CFrame before sending `FeralLunge:FireServer("latch", prey, rel, mode)` (S0003869:2861–2900, 1339–1341, 1581–1601).
- TalonView displays CATCH based on its **client-only** size comparison, which can disagree with gameplay (S0003944:384–407).
- The native controller observes server `FeralLunge.OnClientEvent("miss"|"bit"|"clamp")` responses (S0003869:3185 onward).

The v31 assistant already made one bounded native drag request after a confirmed scratch on a recently selected oversized prey.

**v32 adds stronger correlation and real-result checks:**

- Records the native selected target timestamp and resets the cached selection when the character changes.
- Refuses stale character selection and selection that predates a newer Talon press.
- Retains the original living-target, distance and new-player checks, with no arbitrary nearest-player targeting or repeated remote spam.
- Counts an observed **matching replicated `FeralClamp`** separately from a generic CLAMP event reply.
- Measures actual locally observed hold durations and tracks CLAMP replies without a corresponding matched hold.
- Only uses the native `AbilityConfig.attach` CFrame and proper `FeralLunge("latch", prey, rel, "drag")` argument shape. No fabricated successful clamp is displayed.

**Limit:** Even a well-formed native drag request may be rejected by the game's server, including oversized targets. The server's validation code was not included in the client export. This release has not been tested against a live public-server large pickup.

### 2. Talon cooldown

The recovered `WolfController` listens for changes to `LocalPlayer.FeralLungeReadyAt` and uses the server-time delta to update its local cooldown gate (S0003869:3740–3745). The game can also update this attribute through its Talon UI controller.

The v31 assistant changes the local active deadline, with reversible restoration when the toggle is disabled. v32 retains this and counts additional changes that override a locally shortened deadline. That separates **local input-gate behavior** from a server-accepted second catch.

**Limit:** Reducing the client-side deadline cannot be assumed to reduce a separate authoritative cooldown. Repeated remote calls aren't used to fabricate a success.

### 3. Faster Eagle growth

The existing experimental growth switch continues to edit locally cached `Species.ADULT_MINUTES.Eagle`, `GrowthConfig.ELDER_RATE` and `CUB_BOOST`.

Source audit of the available reconstructed client snapshot found `Growth` attribute writes on cinematic mock actors (`FeralCineCast`) but did **not** establish an equivalent client-requested grant of actual Growth to the user's live Eagle. An arbitrary `SetAttribute("Growth", ...)` would not demonstrate server-recognised progression, and we have not added one.

**Limit:** Faster authoritative Elder growth remains **unresolved** from the available client source. Please don't treat a local visual or configuration change as a working real growth benefit.

## Full hub preservation

- Existing Endurance including `WolfDbgNoStamina`, sprint and jump cached inputs.
- Unified **one-button Active Recovery**, guarded native Rest, cached 2× health and 4× status tuning, combat exclusion.
- ESP outlines and player tags/distances.
- Automatic hostile-grab escape, friendly same-species baby carrying, native G carry.
- Native Q-buffered Quick Climb, combat/reach configuration, agility and Clear View.
- Water-surface floating takeoff **allowed**, submerged takeoff blocked, and native underwater flight exit requested.
- Right Shift menu toggle; CLOSE / End shutdown and active instance cleanup.

The full v32 bundle contains 19 modules. **16 modules from v31 are byte-for-byte unchanged**; only Eagle Actions, Eagle UI and automatic own-character report modules were upgraded. No other system was rebuilt.

## Automatic private reports

`feral-nova-diagnostics-v32.0.lua` writes `FERAL_NOVA_v32_session.json` about every 25 seconds when Velocity exposes `writefile`.

The Windows self-hosted collector in the private `GSVexed/chatgpt-minecraft-testlab` repository was updated to recognise the v32 schema and saves only the validated dedicated report to `diagnostics/feral-nova/latest.json`. It does not make public uploads or send gameplay data from Roblox directly. The report can be retrieved through connected GitHub when the user next messages.

v32 records own-attack native request counts, server Bit/Clamp replies, replicated clamp matching selected prey, longest observed held duration and cooldown attribute overwrites. **This is evidence of client-observed gameplay, not proof of the game's private server logic.**

## Validation

The `.github/workflows/feral-nova-prime-v32-validate.yml` suite validates:
- Official Luau compilation for all 19 modules and standalone;
- Exact bundle-module source equality and preservation of the 41-feature manifest;
- Mocked native `FeralLunge` scratch → one drag request → clamp reply → matching `FeralClamp` hold → hold release;
- Client cooldown deadline shortening and restoration;
- Preserved recovery, combat-healing exclusion, water takeoff, native underwater flight drop, Endurance and private diagnostics.

**Offline compilation and simulations cannot guarantee any of the three server-controlled goals.**

## Controls and rollout

1. Rejoin FERAL once if an older standalone was active.
2. Load the launcher.
3. Enable **CARRY ASSIST** and **TALON GATE** separately in the Eagle section when needed; both are optional and start OFF.
4. The **GROWTH (LOCAL)** setting is still a client-only experiment, not an established accelerated Elder rate.
5. Use right Shift to show/hide; CLOSE or End to shut down. Existing autosave runs without manual reports.

Keep v31 as an untouched rollback at `roblox-tools/feral-nova-prime-standalone-v31.0.lua`.
