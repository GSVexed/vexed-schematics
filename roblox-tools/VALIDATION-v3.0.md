# FERAL v3.0 verification

Verified in the development environment on **16 November 2026**. These checks are distinct from testing inside Roblox.

| Check | Result and scope |
| --- | --- |
| Prior implementation review | Read the actual GitHub v2.4, v2.5, v2.6 snapshots and v2.3 regeneration trial. V2.5 had a 5,000-source cap; v2.6 raised it but still called decompile synchronously. Both retained a compact clipboard report. |
| Official Luau compilation | Standalone v3.0 compiles with the official Luau **0.747** CLI. This validates Luau syntax/compiler limits, not Roblox API access. |
| Simulated integration cases | **20** cases: normal, yielding decompiler, no decompiler, no readfile, cancel, pause/resume, repeated timeouts, uncancellable worker, object cap, memory-growth cap, deep hierarchy, chunked Unicode source, oversize source, stop during inventory, write failure, read-back corruption, missing file APIs, source export budget, JSON configuration structure cap, and scale. |
| Scale fixture | **37,991 script instances**, including **37,990 eligible** client containers; **37,988 sources exported**, two intentional failures, and one server-context source deliberately ineligible. No 5,000-source cutoff. The fixture has **38,021 inventoried objects**; it does not simulate all 123,405 objects or the real game's complexity. |
| Export verification | Checks every manifest/catalog byte count and Adler-32 checksum, one terminal outcome per known script, source chunk reconstruction, unique paths/IDs, and continued validity of prior immutable checkpoints. |
| Privacy fixtures | No fixture secrets, player identities/private attributes, UI/chat text, raw server source, source comments, credential literals, escaped secret literals, private JSON fields, or arbitrary exception strings appear in saved files. This tests implemented filters, not every possible runtime data layout. |
| Read-only fixtures | Mocked game instance writes and gameplay remote invocation raise errors; neither occurs. Only tool-owned UI and mock export files are written. |
| Actual PowerShell packaging | Executed **Pack-FERAL.ps1** with PowerShell **7.7.0 on Linux/.NET**, creating **three independent ZIP parts** from a synthetic export. All archived bytes/checksums and ZIP SHA-256/index metadata pass round-trip verification. |
| Packaging failure cases | Actual packer refuses altered/missing files and paths escaping the export; falls back from damaged latest JSON to immutable manifests; preserves and labels pipeline failure reports. |
| Embedded packer | Test checks that the packer embedded in the Lua loader exactly matches the standalone repository file. |

Official tool release downloads were checked against the SHA-256 digests published in their GitHub release metadata. Test tools and synthetic exports are not part of the diagnostic runtime.

## Not yet verified

- Execution inside Roblox, rendering/input in the real client, and Velocity's actual exposed APIs.
- Windows 11 and Windows PowerShell 5.1 execution. The packer uses .NET/PowerShell constructs intended to be compatible with 5.1; the executed test was on PowerShell 7.7.0/Linux.
- Native decompiler behavior, throughput, fidelity, memory usage, API implementation details, or engine-blocking calls in Velocity.
- Whether the real 37,991-script population primarily belongs to CorePackages/CoreGui. V3.0 exports root counts to answer that with evidence.
- Actual FERAL health/stamina server logic or why a particular value was corrected. The user's observed correction is consistent with server authority, but this remains an inference until exported client evidence and any available server evidence are analyzed.

The default diagnostic never invokes gameplay remotes or attempts to change server behavior. Final runtime success should be judged by the exported manifest and Windows packer's verification, not by a GUI completion label alone.
