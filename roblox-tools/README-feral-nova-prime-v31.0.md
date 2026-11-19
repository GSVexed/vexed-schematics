# FERAL NOVA PRIME v31 — Native Eagle Actions

**Place:** FERAL Animal Survival / `108901361810209`

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-prime-standalone-v31.0.lua"))()
```

This is a **19-module standalone release**, extending v30 without replacing original stamina, unified Active Recovery, 2x HP/4x status inputs, ESP, friendly baby carrying, hostile escape, Quick Climb, water-surface takeoff, native underwater flight drop, combat or the other existing features.

## Eagle improvements that change the actual client action

### Carry assist (optional)

Previously, the hub changed `AbilityConfig.Talon.CARRY_RATIO` to show CATCH for larger prey. That could produce the CATCH label even when the actual attack still scratched. v31 includes `feral-nova-eagle-actions-v31.0.lua`.

When the **CARRY ASSIST** toggle is on and playing as an Eagle, it:

1. Observes the game's own selected prey via the freshly created `FeralTalonTarget` ObjectValue.
2. Waits for an actual `FeralLunge.OnClientEvent("bit")` response, meaning the native attack scratched.
3. Requires a recent selected target, valid living prey, attack-range proximity, no new-player protection, and an oversized target whose patched `grabMode("Talon")` returns `drag`.
4. Calls the existing `AbilityConfig.attach("drag", attacker, prey, from)` to construct the native relative attachment transform.
5. Sends one properly shaped `FeralLunge:FireServer("latch", prey, rel, "drag")` attempt, rate-limited to at most one per five seconds.
6. Counts server-received `bit`, `clamp`, and `miss` replies separately. A CATCH label does not count as success.

**Boundary:** The server may reject this attempt due to a server-side size rule, cooldown, missing lunge state, distance or its own collision validation. No actual oversized server-accepted carry has yet been demonstrated from this version. Never interpret `FireServer` executing without an error as proof of acceptance.

### Talon cooldown gate assist (optional)

The original `WolfController` listens to `LocalPlayer.FeralLungeReadyAt` and copies the deadline into its local input gate. The existing local `Talon.FLAT_COOLDOWN` / `STOOP.CD_PICK` configuration patches do **not** always update that deadline, which can persist at approximately 60 seconds.

With **TALON GATE** on, v31 changes the local `FeralLungeReadyAt` deadline after the game writes it to the user-selected preset, clamped to 0.35–8 seconds. This triggers the original controller's attribute listener, giving the native controller a chance to accept another attack input sooner.

The module restores the previous locally observed deadline when disabled or shut down, if its own written value is still present.

**Boundary:** A shorter local gate is not proof that the authoritative server will accept a second Catch. The module never fabricates a successful server response or claims that an underlying server cooldown was cleared.

### Faster Elder growth (still unresolved)

The currently loaded Growth switch edits `Species.ADULT_MINUTES.Eagle`, `GrowthConfig.ELDER_RATE`, and `CUB_BOOST` locally, preserving reversible changes.

The recovered `WolfController` reads the `Growth` attribute that the game advances. The recovered client code does **not** contain a proved way to tell the game server to credit additional Growth. A local rate change is not a proven faster path to Elder. No client-only edit can be claimed to deliver the user's intended faster server-side Elder growth from the evidence available.

## Existing feature controls

- Right Shift: show/hide menu
- CLOSE or End: full shutdown
- **CARRY ASSIST**: existing carry-ratio local edit plus native one-shot drag attempt after a confirmed scratch
- **TALON GATE**: existing local cooldown edits plus actual client deadline modification
- **GROWTH LOCAL**: experimental client configuration only, no authoritative progress claim
- Unified Active Recovery: one control; pose recurrence guard
- ESP, Auto Escape, baby carry, Q Quick Climb, Surface Fly, Endurance and Reach: maintained

The optional Eagle controls are not enabled at first launch. Do not run overlapping v30 and v31 instances; v31 closes a registered previous hub, but a fresh Roblox join is safest if older unregistered scripts were loaded.

## Automatic private results

The built-in diagnostic recorder remains automatic and saves `FERAL_NOVA_v31_session.json` when supported. It now includes `summary.eagleNativeAction`, with observed client deadline shortenings, native drag retry requests and genuine server bit/clamp reply counts.

The existing Windows private collector supports the v31 filename and schema and can synchronize validated records into `GSVexed/chatgpt-minecraft-testlab/diagnostics/feral-nova/latest.json` on its schedule. There is **no public report upload** and no token inside the Roblox script. Reports can be retrieved in a later chat message via connected GitHub without having to manually paste them.

## Verification

[GitHub Actions v31 run 44641324623](https://github.com/GSVexed/vexed-schematics/actions/runs/44641324623) passed:
- Official Luau compiler across 19 modules plus standalone.
- Source/bundle exact equality and manifest containing 37 required features.
- Mocked native Talon drag request when a selected oversized target is scratched.
- Mocked original LocalPlayer lunge deadline shortening and safe restoration.
- All inherited Endurance/recovery module-preservation, water flight, diagnostics, rollback and unified recovery simulations.

These are compilation and offline simulations, **not successful live oversized carries, reduced accepted server cooldowns or accelerated server growth**. This is the most direct client-side protocol attempt so far; no verified method to bypass the server's independent decisions has been found.
