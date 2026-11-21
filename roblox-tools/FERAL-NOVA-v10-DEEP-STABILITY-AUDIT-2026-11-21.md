# FERAL NOVA v10 — deep stability audit and regression checkpoint
**Date:** 21 November 2026
**Primary release:** `roblox-tools/feral-nova-v10.0-potassium.lua`
**Scope:** source-level and Luau-mocked behaviour, not live gameplay/server-authority certification.

## Audited architecture
- 23 bundled modules, 19 gameplay modules unchanged from the v9 base and four individually sourced components: v10 UI, v10 evidence, v10.1 AFK, v10.1 Grab V2.
- Reviewed reload/bootstrap lifecycle, player UI identity, controller shutdown, action arbitration, AFK controls, native Rest priority, timed minigame inputs, own-character outcome collection and published workflow fixture parity.
- The existing public user loader remains unchanged; source is committed to the same canonical v10.0 path.

## Corrected definite defects
1. **False startup failure:** the wrapper searched for obsolete `FeralNovaPrimeV320` instead of checking the exact v10 GUI instance returned by `ui.mount(ctx)` (`FeralNovaV100`). A properly created UI could therefore be shown as `NO_HUB_CREATED`.
2. **Old overlay reuse:** same-session cleanup did not include `FeralNovaV100`. The v10 name is now recognized when retiring prior screens.
3. **Partial cleanup failure:** the UI's chained `.close()` calls were unprotected; one throwing controller could prevent later cleanup. Close calls are independently protected.
4. **AFK input swallowed:** the AFK synthetic-pulse ignore window previously returned early for every input, including real keyboard or primary-click controls. Filtering is now restricted to plausible synthetic mouse events and lasts only 0.25 seconds, instead of two seconds.
5. **Mouse input did not halt walking:** mouse movement/wheel updated activity state but returned before the auto-walk cancellation path. Unfiltered mouse movement now stops the current assisted walk.
6. **Grab V2 practice-ID validation:** string sessions such as `"-2"` or `"0"` could pass an allowlist that rejected only `"-1"`. Numeric-looking string IDs must now be strictly positive whole numbers; nonnumeric valid session tokens remain supported.
7. **Grab session continuity:** previously an active grab/minigame could remain active after character replacement or death until the timeout. Session owner character is now tracked and stale sessions are revoked.

## Quality gates
- Official Luau compilation of both full candidate and canonical release, plus all 23 bundled modules.
- Candidate/release source byte-parity with the intended release/candidate header difference only.
- 19 preserved v9 gameplay bodies checked byte-for-byte against the reference.
- Four updated components match their standalone sources byte-for-byte.
- Existing mocked native Rest attack lifecycle, pose retry, action priority, lease expiration, Grab Perfect crossing, AFK idle pulse, and read-only evidence segmentation.
- New mocked edge cases for synthetic mouse versus real keyboard/primary-click, real mouse cancelling live AFK movement, negative string Grab session IDs, and session invalidation on respawn or death.
- The 54 startup self-checks are interface/lifecycle checks, **not** proof that the Roblox server accepted gameplay changes.

## Open live-game checks / nonclaims
No live v10 in-game confirmation has been supplied to this audit. Prior v9 real client startup reached READY, but it does not verify this build's Roblox-world effects. In particular:
- No guarantee of server-sustained moving recovery or extra health regeneration.
- No proof of oversized Eagle carrying or shortened server Talon cooldown.
- No verified server-graded Perfect frequency, indefinite anti-idle, unattended survival bonus, or unlimited authoritative hunger/thirst.
- Roblox client/server updates may change native events without changing these mocked fixtures.

## Use and rollback
Canonical loader:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v10.0-potassium.lua"))()
```
Do not run old and new hub instances together. Right Shift toggles UI; End performs complete hub shutdown. The archived v7.5 release remains a separate rollback path if native bite/recovery regressions are observed. For live confirmation, compare same-animal, same-max-HP moving and stationary intervals in DATA and inspect native/replicated outcomes instead of trusting a toggle's label.
