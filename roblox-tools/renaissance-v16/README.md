# FERAL Renaissance 16.4.0-rc1

Build 2415 compatibility and input reliability candidate, recovered from the complete 16.3.2 release.

The versioned loader is published and pins an immutable source commit. The candidate passes 230 Luau cases and the Windows helper's 10,000-cycle state test. The helper is installed with a rollback copy. Live gameplay remains unverified because the passive executor observations returned no confirmed receipt. The floating production loader and earlier pinned launchers are unchanged. See [release instructions](docs/RELEASE.md) for the actual launcher and rollback.

- [Investigation](docs/INVESTIGATION.md)
- [Complete feature matrix](docs/FEATURE_MATRIX.md)
- [Per-module compatibility and all 19 legacy checks](docs/compatibility.json)
- [Source recovery and unchanged-module evidence](docs/source-recovery.json)
- [Automated Luau test results](test-results.json)
- [CI, installation and passive observation receipts](docs/verification.json)
- [Release and rollback instructions](docs/RELEASE.md)

The helper's `--self-test` checks its Windows input ABI and the actual hold-state implementation without installing hooks or generating input. `install.ps1` compiles with the machine's existing .NET Framework compiler, saves the previous helper and starts the on-demand task in the already active desktop. No boot/logon trigger is added. Ctrl+Alt+F12 pauses the helper.

To restore the saved helper, run the installed `%LOCALAPPDATA%\FERALInputBridge\rollback.ps1`. It checks the saved executable's hash and the task's executable path before replacing anything. The previous hub loader remains independently usable; settings files are not deleted.

To reproduce client checks with the pinned official Luau tools:

```sh
python3 roblox-tools/renaissance-v16/run_tests.py --luau /path/to/luau --compiler /path/to/luau-compile
```

The report labels client effects, native observations and server outcomes separately. In particular, 2415 restricts the old stamina debug flag to Studio and exposes server fatigue. Existing local drain controls are retained, but unlimited server-recognized stamina is unproven.
