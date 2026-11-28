# FERAL input helper idle-write fix candidate

The installed 16.4.0-rc1 helper can retain its last nonempty hub token after the hub heartbeat expires. Its 20 ms timer then calls `WriteIntent(false)` every 75 ms even though the hub is absent. The hook and timer remain active until the helper exits.

This candidate writes an idle `false` once when the hub becomes unavailable, then stops writing until an armed heartbeat returns. Failed file writes back off for one second. The compiled self-test checks the idle, transition, active, and retry gates.

This branch is source-only. It has **not** installed or restarted the helper on the user's PC. The on-demand scheduled task has no logon trigger. Exit the installed helper from its tray menu to test without it.
