# FERAL NOVA v13.5.6 — Eagle Talon + Mobile Condition Recovery (experimental)

**Status:** Official Luau compile and preservation checks passed; in-game server outcomes unverified. Separate from stable v13.5.3; no auto flight or auto attacks.

## Launch in Potassium

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v13.5.6-eagle-mobile-recovery-experimental-potassium.lua"))()
```

## All retained from the Eagle experiments

- Native Elder and normal-sized prey drag retry only after a real Talon scratch response, only for the native selected prey, using the game's own `grabMode("Talon", ...)` and attachment CFrame.
- Five-second minimum between assisted native requests, one per validated scratch.
- Confirmation of real hold requires the replicated `FeralClamp` matching the selected prey.
- Stops the client cooldown shortcut when long native deadlines repeatedly reappear, and avoids rewriting the deadline while the native Talon target view is open or immediately after an FeralTalonPress.
- The Elder-lift local configuration changes were already present in v13.5.3; a server-accepted oversized Elder lift is not demonstrated.

## New mobile status recovery experiment (only module changed vs v13.5.5)

User-reported symptom: venom, bleeding and injury clear at an enhanced rate while stationary, but not while running/moving. The current v13.5.3 module was refreshing `WolfActions("Rest", true)` every **3 seconds while moving**, instead of an older **5-second** cadence linked to previously observed mobile HP recovery. More frequent Rest reassertions may conflict with native pose/Rest state; this is a hypothesis, not a proven explanation.

v13.5.6:
- Restores **five-second moving refresh**, preserving existing five-second standing cadence, movement-transition rearming, and native pose safety backoff.
- Separately counts observed decay rates for `FeralInjury`, `FeralBleed`, `FeralVenomAmt` by moving/stationary, auto/manual/baseline and combat/noncombat, and excludes intervals during movement-state transitions.
- Keeps the first bite input Rest release, mixpacking-safe behaviour, manual resting, ability and feeding safety, and no forced resting pose.
- Does not write health, damage multipliers, status amounts or server timestamps.

**Limits:** A 4× local `StatusConfig.REST_MULT` value alone is not proof of faster real clearance. The private server may reject mobile Rest or require an actual stationary Rest state. Inspect observed effect numbers in-game before claiming a fix. For a fair comparison, use the same animal and effect with real status decrements recorded during both continuous walking and standing, no attacking or feeding, then compare decay per second. If movement is exclusively during bite chains, the deliberate post-attack Rest protection continues to pause recovery.

## Turtle shell investigation

- v2411 `CombatConfig.SHELL.SnappingTurtle={TAKEN=0.3,AFTER=1}` represents 70% damage reduction after one second tucked into Rest.
- An offline scan of all 464 archived client scripts found no client caller of `CombatConfig.shellMult` applying actual incoming damage and no client writer for `WolfRestAt`. No proven server-accepted transfer to Eagle or other species.
- Consequently this release **does not** add a cosmetic `SHELL.Eagle` toggle or promise invulnerability.

## Validation and fallback

- [v13.5.5 validation](https://github.com/GSVexed/vexed-schematics/actions/runs/45048294525) — passed.
- [v13.5.6 validation](https://github.com/GSVexed/vexed-schematics/actions/runs/45048541416) — passed. All 23 modules compiled and only the native recovery module changed relative to v13.5.5.
- [v2411 Turtle shell offline scan](https://github.com/GSVexed/chatgpt-minecraft-testlab/actions/runs/45048059720) — passed.

Stable fallback:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v13.5.3-first-bite-rest-off-potassium.lua"))()
```
