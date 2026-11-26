# Renaissance 15.8.2: Test Features and private Potassium result bridge

This is a candidate based on the FERAL v2412 client capture. It has not been
validated in a live game. The stable launcher still points to 15.7.0.

## In the hub

Open **Test Features** from the left menu. Recording begins when the hub starts,
for every animal. While you play, the hub saves
`FERAL_RENAISSANCE_TESTS_LATEST.json` through the executor's local `writefile`
function. The page shows current species, HP, Rest, local save state and the
number of HP loss samples. Save and Copy are available as manual backups.

The report retains bounded own-character HP changes, Rest and charge markers,
status effects, stamina and needs samples, matched game hit replies, Hippo
replies, feature intent/status and the hub's numeric ledger summaries. HP loss
is grouped by animal and Rest state. Max-HP changes are not counted as normal
damage samples. Player names, other-character identifiers, raw remotes and
credential data are not included.

**One-shot Turtle / Crusher request** is a separate manual test. It only sends
one native-shaped start request while the character is naturally resting as a
Snapping Turtle for at least 1.25 seconds in v2412. It releases after 6.1
seconds unless the character changes or the server sends a cancel. It does not
change Species, Rest, shell configuration or HP. Silence is inconclusive;
the client shell multiplier and a hit effect do not prove reduced server damage.

## Private runner bridge

The private Windows PC Lab workflow runs every five minutes while the runner is
online. It uses the locally encrypted Potassium MCP credential to ask the active
15.8.2 hub for its bounded report via `execute_script` and `read_console`.
The executed snippet only reads `hub.tests:bridgeReport()` and prints tagged
chunks. If MCP is unavailable, the runner searches only known Potassium
workspace locations for the exact report filename. The runner validates and
allowlists the fields before it syncs a JSON report to the private repo at
`diagnostics/feral-renaissance-tests/latest.json`. No raw console text or local
credential is sent. The PowerShell workflow has an explicit execution-policy
setting and uses GitHub's contents API without a local Git dependency.

The recorder can save while Potassium is disconnected, but automatic retrieval
requires the PC runner to be online at some point while the local report exists.
The UI's “local report saved” status does not claim the private sync completed.

## Checks

- Renaissance: 248 of 248 local service-boundary scenarios pass.
- Integrated Territory: 263 of 263 simulated scenarios pass.
- Windows runner fixture and live MCP status must be checked separately.

Neither suite establishes that the FERAL server accepts a cross-species ability
request or gives a non-Turtle reduced damage. Compare controlled real HP loss
for the same incoming attack before making any such claim.
