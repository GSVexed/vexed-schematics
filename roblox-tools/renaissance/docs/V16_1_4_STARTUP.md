# Renaissance 16.1.4 small startup loader

This helper loads the same 16.1.4 gameplay code validated at source commit `5cea9ecf88c62eb9d7c3c80445aba737bcf9f132`. It tries one immutable raw bundle download, then reconstructs it from seven immutable, newline-preserving chunks pinned to `fa1a680b23a63ebae67bc2f42b18a9e98a93a448` if the executor rejects or truncates the large file.

The full tested source contains 562,782 bytes (SHA-256 `bc2eec2ae974adb614e228e0d4921b8ec9a8b5c0a49d3e2bb3478a95c80be674`). The validation workflow checks every piece and exact byte-for-byte reconstruction. The loader checks source header, byte counts, compilation and activation, and provides a visible startup error panel if any step fails.

**Controls remain left mouse** for attack and held-repeat. Faster Bites now affects request pacing, but the original game code and server control accepted bite rate. No Left Alt key binding is added.

The small loader is separately published as `roblox-tools/feral-renaissance-v16.1.4-loader.lua` on branch `renaissance/native-m1-adaptive-16.1.4`. Load from the pinned source commit presented in the release answer. The older 16.1.2 loader and stable bundles are unchanged.

**Live success, server damage, and executor native-callback discovery remain unverified.**
