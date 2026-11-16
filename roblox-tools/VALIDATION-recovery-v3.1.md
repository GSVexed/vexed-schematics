# Recovery supplement v3.1 validation

The previous diagnostic was actually used in Roblox/Velocity. This new
two-mode supplement has **not been tested inside Roblox/Velocity here**.
Its checks below use a compiler and synthetic offline mocks.

## Completed checks

- Official Luau 0.747 `luau-compile --null` accepts the generated standalone
  script. No reconstructed game source is executed by this check.
- 34 offline fault-injection cases use system liblua5.4 with Roblox/Velocity
  fixtures. They cover menu-only, in-game-only, menu then Tiger in-game in
  one folder, premature/wrong-mode clicks, duplicate clicks, hide/show,
  compiler missing/throwing, before/after filter regression, identical invalid
  retries, a retry improving syntax, missing targets, Source-property reads,
  missing decompiler/readfile/file APIs, getgenv API fallback, yielding calls,
  pause during source recovery and observation, cancellation, repeated timeouts, uncancellable worker, source API
  errors, file write/read-back failure, chunked Unicode text, source/object
  limits, unsupported interpolation and text-only extension restrictions.
- Every catalogued mock payload and manifest-listed control file is checked
  against byte lengths and Adler-32. Prior checkpoint manifests remain
  verifiable after later saves. Exported source chunks are reassembled and
  checked against whole-source byte length/checksum.
- Each completed/partial source pass seals one terminal record per target.
  The dual-capture case verifies 142 distinct capture/target results in one
  session and exact-text references back to prior captures.
- Test fixture closures would set a marker if executed; the marker stays
  unset. Synthetic credential/private-data markers do not appear in files.
  Mocks reject gameplay property writes and remote invocation; neither occurs.
  At most one decompiler is active in the tested cases.
- Static checks reject gameplay remote/bindable invocation, SetAttribute,
  require of modules, hooking, hidden-property access and getgc calls.
- The 71 path plan includes all 64 file sets rejected in the prior game-source
  syntax audit plus seven explicitly identified semantic-review candidates.
  Numeric baseline IDs are never used to resolve current instances.

## Limits of these checks

Mocks cannot establish Velocity's actual compiler/decompiler behaviour,
native-call preemption, Roblox UI rendering, replication/streaming timing,
game menu flags, performance on the user's PC, or Windows ZIP operations.
API presence and compiler capability are checked at runtime. A native blocking
call can still stall the engine; a Luau timeout cannot guarantee preemption.

Source checksum verification establishes that saved filtered text matches the
recorded bytes. It does not establish accurate decompilation or authentic
original source. The raw/filtered syntax comparison diagnoses where a syntax
rejection is observed; a raw pass does not prove correct reconstructed logic.

Run offline checks:

```sh
python3 roblox-tools/build-feral-recovery-v3.1.py
python3 roblox-tools/tests/test-feral-recovery-v3.1.py
luau-compile --null roblox-tools/feral-recovery-supplement-v3.1.lua
```
