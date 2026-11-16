# FERAL Complete Diagnostic v3.0.1

**Use [v3.0.2](README-v3.0.2.md) for the current fix.** A runtime report showed that v3.0.1 stopped while saving its PowerShell helper. V3.0.2 exports text data only and uses Windows' normal ZIP operation afterward.

Startup fix for the reported v3.0 panel that appeared without a scan starting. The exact failure inside Velocity has not yet been established; this version makes startup explicit and reports where it stops.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-complete-diagnostic-v3.0.1.lua"))()
```

1. Run the replacement loader while joined to FERAL. It replaces the earlier diagnostic panel; existing export files are retained.
2. Confirm the title says **v3.0.1**, then click the green **START SCAN** button.
3. The status shows each file check, then the inventory count. Collection does not start before this click.
4. If it stops, click **COPY STARTUP REPORT** and paste that report into ChatGPT. The report contains the version, phase, startup step, capability availability, controlled failure code, diagnostic source line where available, and file-operation failure details. Arbitrary exception text, game source, private messages, credentials and environment data are not copied.
5. When collection finishes, use **Pack-FERAL.cmd** in the displayed export folder and upload all ZIP parts plus **UPLOAD_INDEX.json**, as in v3.0.

## Changes

- A visible Start control runs the collector from the user action. Startup/rendering no longer depends on a spawned background loop; progress updates cooperate with collection.
- Both Activated and the desktop click event are supported for Start, with a guard against duplicate runs.
- File capability checks, folder creation, a small write/read-back probe, packer export, and the initial manifest each have a visible startup step.
- Capability resolution checks the normal globals and, when available, only the named diagnostic functions in the executor environment. It never enumerates other environment values.
- `makefolder` returning `false` is treated as failure. Missing file APIs and failed read-back checks stay explicit; collection never silently substitutes a short clipboard report.
- Optional TextEditable/drag support failures do not prevent the main scan controls from being connected.
- Failed startup shows a copyable report directly in the panel. The report stays visible when clipboard access is unavailable.

The data schema and Windows packer remain compatible with v3.0. [Collection scope, privacy rules, limits and packaging details](README-v3.0.md) still apply. The folder name starts `FERAL_Complete_Diagnostic_v3_0_1_`.

## Verification

The standalone source compiles with official Luau 0.747. The offline integration suite has 27 cases, including the existing 37,991-script fixture and new cases for waiting before Start, API resolution through the executor environment, unavailable background spawning, optional UI compatibility failures, false-returning folder creation, desktop clicks, duplicate Start events, and copyable startup failures. The same real PowerShell packer is checked against generated exports.

These are source and simulated-runtime checks. Execution inside Roblox/Velocity and Windows 11 remains unverified. A native executor API that blocks the engine cannot be forcibly interrupted by this script. The startup step shown in the panel identifies the last attempted operation if that occurs.
