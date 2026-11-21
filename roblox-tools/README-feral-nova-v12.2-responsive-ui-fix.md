# FERAL NOVA v12.2 — Responsive UI Repair

**Released:** 21 November 2026  
**Status:** GitHub Actions compiler + full regression suite **PASS**  
**Validation:** https://github.com/GSVexed/vexed-schematics/actions/runs/44947968353

## Launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-nova-v12.2-renaissance-ui-fixed-potassium.lua"))()
```

Use **End** in the existing hub to fully close it before launching the replacement. Right Shift hides/shows the interface.

## User-reported issue

Certain toggles in FERAL HUB visually failed to turn on or otherwise appeared unresponsive.

### Root cause identified in v12.1

The UI's recurring `ctx.onUI` refresh attempted to concatenate missing Eagle fields `Eagle.anyClampObservations` and `Eagle.clientOversizeClampObservations`. Those counters no longer exist in `feral-nova-eagle-actions-v12.0.lua`. This raised a runtime error each refresh before updating the Eagle lab, quick climb, Baby carry, reach, water flight, diagnostics and some other dynamic control labels. A one-time log-only warning made it difficult to see why the UI did not appear to react.

### Implemented repairs

1. **Safe Eagle refresh:** `UI.eagleSummary()` reads only existing Eagle counters (`actualClampObservations`, `serverClampReplies`, `serverClampWithoutObservedCarry`), and gracefully displays zero for absent optional observations. The ABILITIES dashboard also uses these current fields and no longer claims to have a non-existent local oversize hold counter.
2. **Larger main switches:** The full 386×78 card surface is clickable using a transparent button, with the existing 59×33 ON/OFF control layered above it. Both invoke the same action.
3. **Reliable desktop click fallback:** Both `TextButton.Activated` and `MouseButton1Click` invoke one guarded dispatch function. Duplicate notifications from one physical click are suppressed in a 120-ms window to avoid rapidly toggling a feature off again.
4. **User feedback:** The footer displays **CLICK RECEIVED** or **ACTION ERROR**, without misreporting success as a server gameplay grant. Action errors and refresh errors are also included in the **COPY STATUS** report.
5. **Window drag arbitration:** Dragging starts only from the left 66% of the header, preventing a press on DATA, HELP, minimize or CLOSE from starting a window drag.
6. **Startup integrity:** Version metadata, GUI identity and loader are aligned to v12.2; an additional UI telemetry capability check is included.

## Verified tests

Run https://github.com/GSVexed/vexed-schematics/actions/runs/44947968353 passed:

- Official Luau compilation of the launcher and all 23 embedded modules.
- Exact source-to-bundle identity: only the UI module changed versus v12.1; **22 gameplay module bodies preserved byte-for-byte**.
- Previous native feeding/rest, action-priority, Eagle, grab and deferred-carry mock regressions.
- **70/70** self-checks on the real extracted startup function in a simulated runtime, plus an intentionally removed field correctly producing INCOMPLETE.
- New real Lua click-dispatch test proving one callback for an Activated + MouseButton1Click pair, later independent click acceptance, failed callback feedback, and the safe Eagle heading rendering with present or absent observation counters.
- No obsolete Eagle reference in the v12.2 UI; both main hitboxes and the non-dragging header region are asserted.

## Important distinction

The UI defect is fixed at source level and tested in offline mocks. The tests do **not** prove every control receives input in a live Roblox/Potassium session, nor that server-owned Eagle pickup, Talon cooldown or 4× injury recovery will be awarded. If the new build's buttons receive clicks but an actual game mechanic still refuses the requested action, that is a separate feature/game-server behavior, not the identified UI refresh bug.
