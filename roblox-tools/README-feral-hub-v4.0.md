# FERAL HUB v4.0 — Three-Goal Engineering Release

**Game:** FERAL Animal Survival, PlaceId `108901361810209`  
**Release file:** `roblox-tools/feral-hub-v4.0-potassium.lua`  
**Purpose:** Fix concrete client bugs affecting Eagle carry assistance and cooldown local restoration; measure observed growth rates honestly. No server-authority bypass is claimed.

## Source-level changes, verified on the published artifacts

- 19 embedded modules total; compared with v3, **16 remain byte-for-byte unchanged**.
- Exactly three embedded sources changed: Eagle Actions, experimental Mechanics, and user interface.
- New module sources: `feral-hub-eagle-v4.0.lua`, `feral-hub-mechanics-v4.0.lua`, `feral-hub-ui-v4.0.lua`.
- Full offline bundle still precompiles every module before replacing an existing hub, retains 24 startup checks, Right Shift controls, HELP and local reporting.

## Goal 1 — Eagle growth to Elder

**Problem:** Prior releases patched cached client `Species` and `GrowthConfig` values. No recovered client code established that these edits cause the real server to grant Growth faster.

**v4 improvement:** A throttled, read-only sampler records the observed existing `Growth` attribute of the user's Eagle each second, separately with the Growth experiment OFF and ON. It excludes character changes, decreases, stale gaps and implausibly large jumps; reports elapsed seconds, growth deltas, and change per minute. The experiment still uses reversible local configuration edits; it does not write `Growth`.

**Result:** A measurable comparison is available through **COPY THREE GOALS**, with no fabricated increase. A change in rate may be correlated with local settings or ordinary gameplay and is not automatically causal/server-accepted.

## Goal 2 — Bald Eagle pickup of larger animals

**Identified bug:** The old `FeralTalonTarget` handler read `.Value` only when the ObjectValue was first added; it could miss a target assigned after parenting.

**v4 improvements:** Watch the target object's `Value` and `At` updates; invalidate cleared selections; clear references on character changes. Observe replicated `FeralClamp.Value` changes immediately when available, rather than relying exclusively on the periodic 0.25-second scan. Flush actual hold durations on release or shutdown. Suppress unnecessary retry attempts while already holding prey.

**Preserved limits:** Only one guarded native drag request on an actual scratch and user-selected recent target. No blind targeting, fake server event, forced server results, or repeated remote spam. The separate game server can reject oversized prey regardless of client configuration. A visible CATCH label is not proof of a successful carry.

## Goal 3 — Talon cooldown

**Identified bug:** Reapplying the local cooldown gate with a new preset could replace the stored original deadline with an already shortened value. A subsequent RESET might fail to restore the true previous local deadline.

**v4 improvement:** Keep the latest externally supplied original deadline as the restoration anchor, never overwrite it with the hub's own previous timestamp. Track original-deadline changes and keep the existing server-time comparison, local attribute listener and periodic recheck.

**Limit:** This improves local deadline consistency and reversibility. It does **not** establish a shorter server-enforced cooldown, and the project does not assume a follow-up action will be accepted.

## Interface

- FERAL HUB v4 header; retained previous feature controls.
- The Eagle experiment status shows matched holds, scratches, local gate edits, and observed growth-on/off rates once enough data has accumulated (a minimum 15 seconds per condition for display).
- HELP has **COPY THREE GOALS** to export detailed Eagle and Mechanics reports.
- Fixed a help-guide escaping bug that displayed literal newline markers.
- Existing RUN SELF-CHECK and copyable startup/session reports retained.

## How to launch after obtaining Potassium

**Preferred offline route:** open the complete `feral-hub-v4.0-potassium.lua` file directly in the executor; this avoids HTTP download support.

**Optional hosted launcher** (only if the executor supports `game:HttpGet` and `loadstring`):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-hub-v4.0-potassium.lua"))()
```

**Controls:** Right Shift to hide/show; HELP for reports and self-test; End or CLOSE for cleanup; RESET restores local features where possible.

## Validation state

- **Executed source-comparison checks:** 19 modules present, exactly three intended modules changed from v3, other 16 unchanged, three embedded sources match published standalone modules exactly.
- **Executed structural checks:** source delimiters and bracket balancing; no embedded HTTP fetch; previous startup/self-check logic present.
- **Published workflow:** `.github/workflows/feral-hub-v4-validate.yml`, compiling the entire v4 source and all 19 modules using official Luau and running mocked Eagle and Growth regression tests.
- **Important:** Successful GitHub Actions execution of the v4 workflow has not been independently confirmed. A prepared test is not a passed test.
- **Not performed:** Live Potassium startup, account security evaluation or test of server-accepted Elder growth, oversized prey carry, or shortened authoritative Talon cooldown.

## Actual acceptance criteria

1. All startup checks pass in Potassium, and the hub can close/reload without duplicate controllers.
2. A late-assigned Eagle target is detected without needing another Talon press; observed matching replicated carries are measured when they actually occur.
3. The cooldown gate can be turned off after a preset change and restores its prior own-client deadline; the actual server action acceptance remains independently observed.
4. Growth-on and growth-off trials each contain enough elapsed time and comparable in-game conditions. No conclusion is drawn from local configuration edits alone.
5. If any test fails, capture `FERAL_HUB_STARTUP_v4.json`, `FERAL_HUB_SESSION_v4.json` and the original v32 report, then fall back to v3.

**Do not interpret this release as proof that client changes can override private server rules.** Using a third-party executor may violate Roblox rules and carries account and malware risks.