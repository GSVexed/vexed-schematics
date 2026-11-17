# FERAL Field Hub v1.4 — three-goal trials

This version focuses on **spendable amber, actual restricted-animal spawns and
lasting health recovery**. It retains the v1.3 controls, including the
Bear/Tiger-supported stamina path, and adds concrete native-protocol trials.
**These new methods have not been tested inside Roblox and are not established
working grants.** None runs automatically at startup.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GSVexed/vexed-schematics/main/roblox-tools/feral-field-hub-v1.4.lua"))()
```

Run once in FERAL using Velocity. The panel is ready immediately; no full scan
is needed. v1.4 replaces older Field Hub windows and restores their owned
settings. Right Shift hides/reopens it. **X** stops the tool and restores its
owned settings. Goal trials are at the top of LIVE, ANIMALS and RESOURCES.

## 1. Amber — LIVE

| Control | What it actually does |
|---|---|
| CHECK MY GIFT LOOKUP — NUMBER / TEXT | Reads only your own target through the captured gift interface; compares numeric and text ID formats if necessary. Does not establish write permission |
| TRY OWN AMBER GIFT — AMOUNT ABOVE | Reads an own baseline, attempts one self gift, and checks an own server balance afterward if the gift response is recognized. Defaults to **1 amber**; positive integers only, maximum 1,000,000 |
| TEST ONE ALREADY-CLAIMED PLAY REWARD AGAIN | Reads fresh state, selects one tier already marked claimed, submits exactly one repeat claim and watches matching paid/state/balance observations. This is different from the ordinary earned-reward shortcut |

The gift write is tested independently of lookup success: an unusable read
does not prove how a different server branch validates writes. It is still a
self-only request, with no role or identity spoofing. The inferred gift tuple
comes from reconstructed UI code, so an unexplained reply is not automatically
called a permission rejection.

No arbitrary balance display is written. An acknowledgment alone is not a
credited grant. A server-save balance increase is reported separately from a
visible wallet increase; neither is presented as a completed unlimited-money
method. Normal spending or a rejoin provides additional evidence.

The replay has a one-request limit and a one-minute cooldown. It does not loop
claims after a possible duplicate award. A matching paid notice, positive
wallet change and fresh claimed-state observation are labeled a **candidate**;
other scripts or earnings can confound attribution.

## 2. Restricted animals — ANIMALS

| Control | What it actually does |
|---|---|
| TRY SNOW LEOPARD / PHANTOSUCHUS NEW-SLOT SPAWN | Reads fresh own slots and submits one six-argument FeralSelect request into an empty base slot. Requires returning through the game's normal menu first |
| TRY SNOW LEOPARD BUY — EXPECTED 3000 AMBER | Attempts the native amber purchase only if the loaded client price is positive and no more than 3,000, your visible balance covers it, and fresh state does not already list ownership |
| TRY OWN SNOW LEOPARD / PHANTOSUCHUS / ALL-ANIMAL GIFT | Attempts the corresponding native self-gift tuple; does not change your owner/tester role |

**The Snow Leopard buy can spend your amber if accepted.** The server decides
the actual charge and eligibility; the protocol carries the species, not a
client-enforced maximum price. The captured price was 3,000; Phantosuchus was
100,000,000 and has no purchase button here.

The spawn test never sends a purchase, deletes a save, chooses an occupied
slot or automatically despawns your living animal. It uses the loaded
SaveConfig base-slot count, rejects ambiguous string-keyed slot maps and
passes false in the native empty-slot confirmation argument. Missing/free
slots come from a fresh own reply, not from guessing a slot number.

Only a matching living character with a root part **and a new matching active
slot sync** qualifies as an observed spawn. A portrait, ownership boolean,
different species or a timeout does not qualify. Persistence after rejoining
remains a separate test. The captured owner/tester restrictions may still
prevent a spawn even if ownership is granted.

## 3. Recovery — RESOURCES

The previous local HP writer failed and remains removed. The new method tests
the native **WolfActions Rest boolean** without putting the client controller
into its ordinary R-key rest state.

- **RUN 26s SERVER-REST RECOVERY COMPARISON:** 8 seconds of baseline, 10 with
  Rest=true, then 8 after Rest=false. Start when already at or below **60% HP**,
  outside combat, with hunger/thirst at least 25. Walk steadily through all
  phases. The tool never injures you or writes Health.
- **UNPROVEN SERVER REST LOOP:** a separate opt-in trial that sends true at
  most once per five seconds. It does not automatically switch on after a
  comparison. Combat, death, character/root changes, unsupported modes, native
  assist interference, Stop or X end it. A false cleanup request is sent only
  for the same still-current character.

This asks the game to treat your character as resting; it can affect ordinary
rest-related behavior. It is not a combat-protection or invulnerability system.
Server checks for movement, needs, combat or resting may make it ineffective.

The comparison excludes full-health intervals, changing maximum HP, inadequate
needs, gaps and invalid rates. A moving uplift requires at least three valid
moving intervals in every phase and a signal median at least 1.5 times both
baseline and afterward. That is exploratory evidence, not causal proof. Growth,
status recovery, lag and native actions can still affect the result. Damage,
combat, water/flight/grab modes and character changes stop the comparison.

## Save one focused result

After trying the relevant controls, open **REPORT** and click
**SAVE FOCUSED FIELD REPORT .JSON.TXT**, then **COPY LAST FIELD REPORT FILENAME**.
Find that file in Velocity's workspace and upload it directly to ChatGPT.
It starts `FERAL_Field_Report_v1_4_` and includes a session, part and revision.
No additional full diagnostic or clipboard excerpt is needed.

Reports preserve up to **32 goal trials** per run with all their individual
outcomes. Reaching that limit blocks new trials rather than deleting old ones.
The existing 6,000-event journal, verified numbered parts and alternating A/B
checkpoints remain available. Any omitted timeline events are explicit.

**STOP GOAL EXPERIMENTS** cancels future chained work and ends the Rest signal.
An RPC already sent cannot be recalled and may complete after the panel stops.
Pending RPCs remain bounded; timeouts do not trigger automatic retries. Normal
close performs cleanup before its final optional checkpoint.

Only allowlisted own state is exported. Raw saves, account IDs, names, gift
lists, gain reasons, chat, credentials and other players' data are not retained.
Gain reasons can contain names, so only amount and time are recorded.

## Verification and limits

Read the [method investigation](FERAL-THREE-GOAL-METHODS-v1.4.md) and
[check record](FERAL-FIELD-HUB-v1.4-CHECKS.json). **133 offline checks pass:
31 core and 102 simulated runtime/upgrade cases.** Tests use an engine substitute,
not Roblox or Velocity. They verify exact packets, self targets, empty-slot
guards, cancellation, cleanup, result classification and privacy, alongside
earlier regressions. Server acceptance remains untested.

A complete captured client export cannot guarantee an accepting server path.
If these trials produce no confirmed result, that is evidence to narrow the
investigation, not a reason to relabel local display changes as successful grants.
