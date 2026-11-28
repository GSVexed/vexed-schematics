# FERAL Renaissance 16.4.3-rc1

Build 2415 hub candidate based on 16.4.2. It targets the reported exhausted-sprint slowdown by requesting both a sampled local pace and the held keyboard movement direction after native WolfMove. Local Stamina Conservation is on by default for new settings; an explicit saved OFF remains OFF. Automatic diagnostic writes now back off after a failure rather than retrying every frame, and normal saves run at most every 30 seconds.

The published loader pins an immutable source commit. All 240 local Luau checks pass, covering failed-write backoff, fatigue direction replay and cleanup along with the earlier combat and Territory regressions. The hosted client, Windows helper, Amber and v15 checks pass. The installed Windows helper is retained. Other-player visibility, server acceptance, actual infinite stamina and a live frame-time improvement remain unverified. The floating production loader and earlier pinned launchers are unchanged. See [release instructions](docs/RELEASE.md) for the launcher and rollback.

- [Investigation](docs/INVESTIGATION.md)
- [Complete feature matrix](docs/FEATURE_MATRIX.md)
- [Per-module compatibility and all 19 legacy checks](docs/compatibility.json)
- [Source recovery and unchanged-module evidence](docs/source-recovery.json)
- [Automated Luau test results](test-results.json)
- [Current verification](docs/PERFORMANCE_VERIFICATION.json), [prior candidate](docs/POLISH_VERIFICATION.json), [endurance experiment](docs/ENDURANCE_VERIFICATION.json) and [earlier candidate receipts](docs/verification.json)
- [Release and rollback instructions](docs/RELEASE.md)

The helper's `--self-test` checks its Windows input ABI and the actual hold-state implementation without installing hooks or generating input. `install.ps1` compiles with the machine's existing .NET Framework compiler, saves the previous helper and starts the on-demand task in the already active desktop. No boot/logon trigger is added. Ctrl+Alt+F12 pauses the helper.

To restore the saved helper, run the installed `%LOCALAPPDATA%\FERALInputBridge\rollback.ps1`. It checks the saved executable's hash and the task's executable path before replacing anything. The previous hub loader remains independently usable; settings files are not deleted.

To reproduce client checks with the pinned official Luau tools:

```sh
python3 roblox-tools/renaissance-v16/run_tests.py --luau /path/to/luau --compiler /path/to/luau-compile
```

The report labels client effects, native observations and server outcomes separately. In particular, 2415 restricts the old stamina debug flag to Studio and exposes server fatigue. Existing local drain controls are retained, but unlimited server-recognized stamina is unproven.
