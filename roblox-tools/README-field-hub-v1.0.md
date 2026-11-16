# FERAL Field Hub v1.0

A standalone in-game panel for PlaceId `108901361810209`, built from the
completed client investigation. This is a new client experiment tool, separate
from the read-only v3 diagnostics. It opens immediately and needs no Start
button, filesystem access, full instance scan or decompilation.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-field-hub-v1.0.lua"))()
```

All gameplay/appearance experiments start **off**. Running the loader again
closes the previous copy and attempts to restore its owned settings first.

## Controls

| Tab/control | Behaviour |
|---|---|
| LIVE | Your visible health, stamina, growth, needs, movement, amber and supported status effects. Observed changes are not automatically attributed to the server. |
| RESOURCES / stamina | Opt-in experimental cached client controller tuning and `WolfDbgNoStamina` flag. No repeated `Stamina` attribute refill. |
| RESOURCES / local HP | Opt-in local `Humanoid.Health` writes at up to 4 HP/s, clamped to maximum; never revives a dead humanoid. Server acceptance is unverified. |
| RESOURCES / brighter view | Your own removable colour-correction effect. |
| TRAVEL / scout | Requests scenery around the selected destination, then checks loaded ground, slope, water, headroom, footprint support and approximate body clearance. It does not move the character. |
| TRAVEL / move once | Separately attempts one local character movement to a fresh checked destination, revalidating geometry first. No automatic retries. |
| TRAVEL / return | Selects the last departure as a destination. It requires another scout and a separate movement click. |
| ANIMALS | Search all replicated portrait models, including restricted models if their assets exist. Script-stripped clones render in an isolated ViewportFrame. |
| ANIMALS / hidden cards | Changes the cached client `HIDE_LOCKED` visibility flag only. Reopen the native animal menu to refresh it. Owner/tester checks and server spawn permission are unchanged. |
| COATS | Load cached coat definitions for a selected portrait, preview compatible replicated appearances, optionally try a coat locally on your matching animal, and restore it. |
| FINDINGS | Search 26 curated findings with evidence categories and limitations. |
| _ / Right Shift | Hide/show the panel. A FERAL HUB button appears when hidden and recentres it when reopened. |
| X | Stop the hub, disconnect its listeners and attempt to restore owned configuration, flags, appearance and lighting. |
| STOP EXPERIMENTS | Stop resource/visibility experiments and restore local coat/menu changes. Prior movement or health changes are not reversed. |

## What is actually established

The exported `WolfController` requires `FeralWorld.NeedsConfig` and reads its
stamina fields while maintaining a private stamina accumulator. The new stamina
experiment targets that cached table instead of repeating the failed HUD-only
approach. It sets sprint drain and jump cost to zero, increases local regen to
250, removes its delay and removes the low-needs regen penalty. It also enables
the character flag read by several flight, climbing, venom and hold paths.
This is a plausible client experiment, **not a verified infinite-stamina result**.
Other costs, controller states and server rules may still apply.

Optional cached module reads require the exact target to appear in
`getloadedmodules()` before attempting `require(target)`. Only NeedsConfig,
AccessConfig and CoatConfig are requested. No arbitrary decompiled source is
executed. Executor module-cache behaviour is not established by the offline tests.
Absent/blocked APIs and read-only tables produce a partial feature with an
explicit status. The latest request wins if a toggle changes during a pending
cache lookup; late responses cannot reactivate stopped experiments.

The HP trial remains local and can be overwritten, as the earlier trial was.
It is not god mode, server-authoritative healing or a death-prevention mechanism.
Buffs and ailments are displayed from observed attributes; the hub does **not**
pretend that setting a badge grants a server damage or growth bonus.

## Oasis travel limits

The dataset names **Hidden oasis / The spring** at **X 1070, Z 1505**.
Its Y coordinate is measured from loaded geometry, rather than invented.
It is not established as a protected, healing or inaccessible area.

Scouting searches 25 positions within 28 studs of the configured point. Checks
reject absent ground, water, steep slopes, uneven footprint support, a detected
ceiling or overlapping collidable part bounds. Excessively large bodies are
rejected. A plan expires after 12 seconds and is invalidated on character change,
destination change or stopping experiments. Movement checks for a living
character, combat, several grab/carry states and substantial velocity.
The destination is rechecked immediately before moving.

These are conservative **local geometry checks**, not a guarantee of safe
travel. Roblox queries see streamed content and approximate bounding boxes;
they cannot establish all terrain/interactions, enemies, damage triggers,
future changes or server movement validation. The game may correct the position
or apply damage. The tool records position/health four seconds after an attempt
without treating those observations as proof of server approval. No fallback
blind teleport, repeated movement forcing, collision disabling, velocity launch,
automatic return or gameplay remote is used.

References: [Player streaming requests](https://create.roblox.com/docs/reference/engine/classes/Player#RequestStreamAroundAsync),
[streamed-content query limits](https://create.roblox.com/docs/workspace/streaming/techniques),
[WorldRoot spatial queries](https://create.roblox.com/docs/reference/engine/classes/WorldRoot#GetPartBoundsInBox).

## Animal, coat and currency limits

Portrait previews and hidden cards do not grant a playable spawn. The captured
AccessConfig labels Phantosuchus owner-only and Snow Leopard tester-only, and
also contains a server-side permission helper. The actual server spawn handler
was not recovered. No permission bypass or accepted restricted spawn is established.

Coat trials use replicated SurfaceAppearance/texture assets on local preview
clones or your matching current animal. Procedural recolor metadata depends on
the existing client renderer and can fail to render. Incompatible/missing
assets are reported; no arbitrary colour tint is presented as the actual coat.
An own-animal trial temporarily stashes its existing surface and restores it
when still applicable. Later game changes are preserved where identifiable.
The game may overwrite a local trial. Other clients' views are unverified.

The hub does **not** grant permanent coats, game passes, all animals, spendable
amber or server-backed buffs. The recovered coat UI sends purchases to the
server and waits for `coatBought`; changing the displayed Amber attribute is
not evidence of purchasing power. There are no fake currency buttons, purchase
prompts, gameplay remote calls, slot replacements or silent spending in this tool.

## Diagnostics and privacy

The diagnostic phase is already complete; this hub does not repeat it. It reads
only your supported live attributes and small named asset folders. Preview
trees have a 3,000-node budget, portrait search displays at most 256 matches,
and coat lists show at most 100 entries with explicit count/limit information.
Live history is bounded to 33 samples. Only one pending cache job per module
and one scout are allowed. UI lists disconnect replaced event handlers.

The optional small status report includes the place ID, your visible species,
resources, experiment state and error counts. It excludes usernames, account
IDs, chat, other players' data and credentials. Clipboard and `.txt` saving are
optional APIs, checked only when clicked. Saved reports are not read-back verified.
Failure reports retain an action/startup phase, fixed error category and source
line when available; raw API error messages are not retained.
No raw diagnostic data or reconstructed game sources are published with the hub.

## Verification

- Official Luau compiler accepts the self-contained source.
- 12 core behaviour/fault scenarios pass in Luau.
- 26 simulated runtime scenarios pass, including defaults, cached tuning,
  missing APIs, frozen tables, late callbacks, repeated launch, respawn,
  script removal, appearance restoration, landing refusal/revalidation,
  one-shot movement, external GUI destruction and cleanup.
- Static checks find no gameplay remote calls, player enumeration, decompilation,
  arbitrary source execution, hooks, forced table unfreezing, currency writes or
  tester-attribute spoofing.
- **Not tested inside Roblox or Velocity.** No live server effect, unlock,
  healing, travel safety, paid ownership or exploit success is claimed.

Run the offline checks with the official Luau CLI available at `FERAL_LUAU`:

```text
python roblox-tools/tests/test-feral-field-hub-v1.0.py
```

Source evidence and diagnostic limitations remain in
[FERAL-FINAL-ANALYSIS.md](FERAL-FINAL-ANALYSIS.md).
