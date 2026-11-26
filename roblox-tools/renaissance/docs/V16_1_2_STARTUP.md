# FERAL 16.1.2 startup troubleshooting

The pinned 16.1.2 bundle is present and the complete code passes the official Luau regression gate (424 Renaissance and 305 Territory checks). This does not establish that every executor or game runtime can load it.

The standalone **loader** fetches the same immutable bundle, retries the existing candidate branch URL only on transport/response failure, verifies the version header, and displays the failing stage (`Wrong game`, `Download`, `Executor`, `Compile`, `Startup`, or `Activation`). It does not silently downgrade or call unrelated game remotes. Existing 16.1.1/stable bundles remain untouched.

To load:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/renaissance/reliability-audit-hold-sustain-16.1.2/roblox-tools/feral-renaissance-v16.1.2-loader.lua"))()
```

An executor blocking both GitHub raw downloads cannot run an HTTP-based loader; an automatic fallback cannot grant missing HTTP or loadstring capability. If both requests fail, the loader prints a warning and attempts to show a visible error panel. The user should not need a separate manual collector.

Source identity: `63b189fc871dbc48315e24cdbfe16d1df8246589`, SHA-256 `b8d63d8456f21ed61457b60559720ea03dc25bf7a66c7e696d927c8ab452de0b`.

Live gameplay, accepted damage and sustained hold-input remain unverified.
