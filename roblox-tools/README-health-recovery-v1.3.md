# FERAL Death + Stamina Trace v1.3

This build investigates the unexplained Burst death. **It does not claim an
anti-cheat bypass, a safe Burst duration, combat HP recovery or a fixed stamina
method.** The five tuning values and stamina flag behaviour are unchanged;
the new code observes death feedback and your own resource/movement state.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-health-recovery-v1.3.lua"))()
```

## First use: an existing death screen

If the game's death screen is still open, load v1.3 and click
**READ CURRENT DEATH SCREEN** near the top of the panel. It reads the known
heading and saves a small report automatically. This does not damage your
character, request a death or require enabling stamina/recovery.

The existing heading may disclose only a broad category. A previous native
death packet cannot be recovered after it has already passed; an absent or
unrecognized heading is recorded explicitly. This button cannot retrieve a
private server check that the game never sent to the client.

## What is captured during play

- The existing `FeralDeath("dead", payload)` client message, using the game's
  reported cause and numeric lifetime. Only fixed non-sensitive labels are
  saved; unknown strings and killer identity/details are redacted.
- Client-observed stamina, maximum stamina, depleted flag, no-stamina debug
  flag, oxygen, movement mode/speed and separate HUD/character Burst flags.
- Observed continuous/cumulative Burst time per character. These are elapsed
  client observations, not the server's private stamina budget or exact intent
  start times before the capture began.
- HP-zero transitions, including the last positive HP observation, tuning
  configuration, and a bounded pre-death trace. Horizontal displacement speed
  is derived locally; absolute positions are not saved.
- Existing self-only native hit feedback, combat timer and condition logging.

The trace runs automatically. **Recovery Assist** and **Stamina Tuning** start
OFF. Loading v1.3 stops the older panel and restores its owned settings first.
Enabling a feature remains an explicit choice. The recent abrupt death makes
sustained Burst with stamina tuning unresolved; this build does not make it
safe or change its tuning values.

Click **SAVE HEALTH REPORT .JSON** to save manually. HP-zero transitions,
native death feedback and character removal also request an evidence save
after about 1.25 seconds, allowing nearby feedback to arrive. Reports are
plain text files beginning `FERAL_Health_Report_v1_3_...` in Velocity's workspace.
Upload the `.json.txt` file directly; no ZIP or full scan is needed.

The remaining controls are retained: **STOP & SAVE** stops recovery while
passive observation continues; **X** stops features/listeners and saves before
closing. Stamina tuning remains independent. The panel is draggable and its
contents scroll; `-`/`+` collapses/expands it.

## What a cause does and does not establish

The recovered native UI recognizes `killed`, `hunger`, `thirst` and `other`.
Those are broad categories. `other`, an absent packet or HP abruptly reaching
zero does **not** establish anti-cheat. The optional `reason`/`code` fields are
inspected only if actually present, and only exact labels from a fixed filter
are retained. Their inclusion in that filter is not evidence the game sends
them. No arbitrary payload, killer name, username, account ID or credential is
exported. A death-screen heading is explicitly labelled as local UI evidence,
separate from a native message.

Packets can arrive before HP reaches zero or after character replacement.
The report records model/timing associations and generations explicitly,
rather than silently claiming a private authoritative explanation. Even a
reported enforcement category may not identify the internal condition that
triggered it. See [the protocol and evidence limits](FERAL-DEATH-PROTOCOL-v1.3.md).

## Limits and verification

The recent trace holds at most 60 samples from a 15-second window, sampled at
most four times per second. A fatal record may append the transition point
for a maximum of 61 samples. Sampling gaps and omitted older frames are
counted. The first 16 fatal records are retained; subsequent omissions are
explicit. The main journal still preserves the first 6,000 events and counts
later omissions. Checkpoints remain every 30 seconds when file APIs work.

Compilation, static checks and **67 simulated cases** pass. These include the
previous 50 cases plus native death privacy, generic/unknown causes, event
ordering, revival/respawn association, stamina/oxygen reads, trace bounds and
gaps, history limits, current-heading capture, automatic saving, cancellation,
remote replacement and the actual v1.2 upgrade. See the
[check record](FERAL-HEALTH-RECOVERY-v1.3-CHECKS.json) and
[reproducible test](tests/test-feral-health-recovery-v1.3.py).

**v1.3 has not been executed inside Roblox/Velocity.** The exact cause of the
reported Burst death remains unresolved. No new gameplay remote is invoked:
only the existing optional Rest boolean request remains.
