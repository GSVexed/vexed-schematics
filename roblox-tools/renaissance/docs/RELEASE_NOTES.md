# Renaissance 15.0.0 — isolated validation build

This commit is the scoped implementation and automated-test checkpoint. Release promotion is pending published CI and the authorized live staging check.

All 21 approved functions have an explicit implementation and status. The compact four-tab UI, Right Shift, permanent reach, hollow-only outlines and saved settings are preserved. The thirteen deliberate removals remain excluded.

The nine-module rewrite fixes false/OFF reconciliation, attach cleanup, duplicate renderers, native Grab V2 res handling, session wire types, duplicate presses, local rate compounding, stale config identity and native-Q double-tap risk.

The local suite passes 53 service-boundary scenarios; each module, both fixtures and the bundle compile with the pinned official Luau compiler. Native/server gameplay acceptance remains unverified.

## Rollback

The original stable clean loader remains unchanged. The exact rollback source is:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/158474ba80c0d613c3427399f24059341369acc8/roblox-tools/feral-nova-v14.0-clean-reach-core.lua"))()

The loader retires the active Renaissance hub through its compatibility close handle. Do not stack independent old hub versions manually.
