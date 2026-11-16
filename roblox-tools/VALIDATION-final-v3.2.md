# Final project validation

## Actual Roblox/Velocity evidence

- User's v3.0.3 baseline reached `finished`: all 37,987 eligible logical
  sources exported, zero pending and no reported collection limits.
- User's v3.1 menu and Tiger captures both reached `finished`, each exporting
  the 71 selected paths. Before/after compiler checks ran in that session.
- Those runs establish actual behaviour of those versions, not of v3.2.
  **The final v3.2 collector has not been tested inside Roblox here.**

## Completed offline checks

- Official Luau 0.747 `luau-compile --null` accepts the generated v3.2 script.
- 32 final-supplement fault-injection cases cover menu-only and in-game-only
  use, both captures, hide/show, early/wrong-mode clicks, a character whose
  Name differs from LocalPlayer.Name, invalid/identical output, filter
  regression, unavailable/throwing compiler, missing decompiler/target,
  readable Source, getgenv fallback, yielding, pause, cancellation, timeout,
  uncancellable worker, source API errors, file write/read-back failure,
  chunking, source size limits, unsupported interpolation, text-only files and
  the fully verified success status when all selected reads succeed.
- Synthetic reconstructed closures would set an execution marker if called;
  the marker remains unset. Mocks reject gameplay mutations and remote calls;
  neither occurs. At most one decompiler is active. Only the live Animate path
  is targeted; the previous 64 paths are not retried.
- Mock catalog payloads and whole-source references are reassembled and
  checked. Immutable earlier checkpoint controls remain verifiable after
  later saves. Missing/invalid/unverified content produces explicit statuses.
- Eight standalone-verifier cases cover valid, parent-wrapped and split ZIPs,
  corrupt payload, missing source, unsafe path, wrong session and incorrect
  whole-source reference. The verifier also checks both actual uploaded ZIPs:
  22,845 baseline payloads and 1,037 recovery payloads, without discrepancies.
- All 22,511 preserved canonical source bodies were compile-checked, covering
  37,987 logical exports: 22,016 canonical bodies accepted and 495 rejected.
  The game/platform and logical-reference counts are preserved in the quality
  index. No input source was executed or imported.

## Reproduce the code checks

```sh
python3 roblox-tools/build-feral-final-v3.2.py
python3 roblox-tools/tests/test-feral-final-v3.2.py
python3 roblox-tools/tests/test-feral-verifier.py
luau-compile --null roblox-tools/feral-final-gap-v3.2.lua
```

The optional ZIP verifier needs Python's standard library only. It is for
offline inspection; the Windows user does not need it to create/upload a ZIP.

```sh
python3 roblox-tools/verify-feral-export.py COMPLETE_EXPORT.zip
python3 roblox-tools/verify-feral-export.py METADATA.zip DATA_001.zip DATA_002.zip
```

The verifier's `integrity_ok` means the catalogued files and references match
the selected manifest. It does not claim all original scripts, all streamed
objects, server authority rules or faithful reconstruction were recovered.

Native executor calls may block the engine despite cooperative Luau timeout
handling. Syntax checks are compiler-version-specific and do not validate
logic. GUI rendering, replication timing and current Velocity API behaviour
remain runtime checks. The actual final live source must be collected on the
user's client; no offline fixture can stand in for it.
