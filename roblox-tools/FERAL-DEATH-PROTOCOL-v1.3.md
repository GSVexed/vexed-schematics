# Death-cause capture and Burst reliability — 2026-11-17

The current objective is to identify the unexplained full-health death while
Burst and stamina tuning were active. The user reports the stamina bar stayed
working and suspects enforcement. That suspicion is not a recorded verdict.

## Existing evidence

The first v1.2 capture contains two distinct deaths. The earlier one followed
incoming player-hit feedback and bleed damage. The later life had 107/107 HP
in its last regular sample and HP=0 about 0.675 seconds later, during Burst,
without a combat tag, incoming hit feedback or recorded harmful condition in
that life. Cached stamina tuning still matched and recovery requests were
inactive. Hunger/thirst were adequate. Actual stamina and oxygen values and
the native death message were not included in that version's report.

The later life lasted about 192 seconds, including swimming and several Burst
segments. Its final observed uninterrupted Burst segment was about 25 seconds.
This does not establish a repeatable sixty-second threshold, a safe duration
or the internal cause. An unexplained kill/reset is the supported finding.

## Source-backed native death interface

The existing exported `S0003645` FeralDeathUI body provides these anchors:

| Location in the original reconstructed source | Evidence |
|---|---|
| Around 24 | ReplicatedStorage FeralDeath is the native client event |
| Around 738–739 | Headings map hunger, thirst and other; killed has a separate presentation branch |
| Around 750 | The native screen is named FeralDeath |
| Around 833–858 | `payload.cause` selects the heading; unrecognized values fall back to a generic death heading |
| Around 1000–1020 | The UI uses numeric lifetime statistics and the cause category |
| Around 1828–1860 | Event kind `dead` accepts a payload table, opens the death UI and follows its corpse model |

The four source-backed cause labels are **killed, hunger, thirst, other**. No
literal anti-cheat handler or detailed stamina enforcement decision was found
in the recovered client bodies. The server-only combat/health/enforcement
implementation was not retrieved. The exported client set is not all server
code, and reconstruction defects remain a limitation.

v1.3 receives the same native event without calling it. It preserves the
reported cause and lifetime within a closed data filter. Optional reason/code
fields are inspected only if present. A fixed list of English investigation
labels permits a category to be retained if actually delivered, but does not
assert that those guessed labels are implemented by the game. Unknown text
is redacted rather than copied into the export.

The current native heading can also be classified into a known category.
Only that category and visibility/provenance are exported; names embedded in
a killed-by heading are not saved. The heading is a UI hint, not a server
decision record or a retrospective recovery of a previous packet.

## New measurements and limits

The report adds client stamina/max/depleted observations, the local stamina
flag, oxygen, separate Burst flags, observed Burst elapsed time, movement and
displacement speeds, numeric cached tuning fields, and a bounded trace around
HP-zero transitions. These measurements can distinguish a visible resource
depletion, a position/velocity anomaly, normal reported damage, and a remaining
unexplained kill/reset. They do not expose a private server resource budget or
prove which server function ran.

Fatal records and death messages have explicit generation/model/timing
associations. Delayed packets and revival in a reused model are not silently
treated as independent authoritative proof of an exact cause. A generic
`other` result remains generic; no anti-cheat conclusion is manufactured.

All new behaviour is observational. The optional five-field stamina tuning
and owned stamina flag are unchanged apart from added log events. No HP,
oxygen, stamina pool, Burst intent, combat timer, safety state or death value
is assigned. The only gameplay remote call remains the optional pre-existing
Rest boolean action. No revival, purchase, transfer or debug-death request is
submitted.

The first useful check is an existing death screen, if still open, followed
by a saved report. No intentional death is required to read that heading.
If it has already closed, future native messages can be observed during
ordinary play, but past packets or an undisclosed internal check cannot be
retrieved from this client. The goal is to identify evidence before choosing
a fix; no Burst fix, safe cooldown or enforcement bypass is established.
