# Renaissance 15.3.0 architecture

The v14 rollback is commit 158474ba80c0d613c3427399f24059341369acc8, with its existing clean loader unchanged. This replaces fourteen embedded legacy modules with thirteen original, independently compiled modules. No raw game bytecode or reconstructed game source is bundled.

| Owner | Responsibility | Lifecycle |
|---|---|---|
| core.luau | Exactly 21 feature records; requested/applied/observed/outcome fields; exclusive patch leases; bounded evidence ledger | One registry, lease map and ledger |
| settings.luau | Schema 15 validation, CLEAN migration, false values, backup and verified writeback | Reads at stage; writes on user changes |
| policy.luau | Local priorities, manual Rest sovereignty, attack windows, AFK eligibility | Shared by every controller |
| grab.luau | Native begin/strike/res/bite/n/end sessions; deduplication, actual time, own-character grades, missed-crossing recovery | One session per character generation |
| grab_input.luau | Reversible separation of native minigame mouse and manual key bindings | One lease per genuine native UI session |
| recovery.luau | Native Rest provenance, reversible native blend override, deficit and progress observation | One Rest owner; no HP/status writes |
| feeding.luau | User-started native feeding intent, approach protection, resource observation, one stall repair | One current own-character session; no resource writes |
| combat_input.luau | One delayed original-tryBite retry after Rest blocks a user bite | One bounded input per current character |
| rescue.luau | Manual G water-cub attempt through native eligibility and carry protocol | One short request; native attachment observed separately |
| features.luau | All shared client-config edits and own stamina flag | One reversible lease manager |
| roblox.luau | Services, snapshots, module identity, native observers, terrain queries | One heartbeat, one render binding, one small PreAnimation guard and the existing render callback after native animation |
| ui.luau | Four-tab menu, hollow outlines, separate pack/health cues, tags and guide | One GUI and renderer; at most 24 real-player records |
| controller.luau | Coordination, preemption, evidence, lifecycle and persistence acknowledgement | Inactive stage, activate, idempotent close |

## Activation and rollback

Every embedded source and interface is validated before accessing the old hub. All new GUI construction and listener attachment happens with the candidate inactive and its GUI disabled. Attach failure unwinds new resources and leaves the previous hub untouched. Stage-only validation never retires the old hub or applies gameplay config.

After all attaches succeed, the bootstrap closes the old hub and activates the candidate. First-frame errors close the candidate and restore owned fields. A legacy hub exposes only close(), so it cannot be resumed after successful retirement; re-execute pinned CLEAN v14 to roll back. This does not promise to resurrect arbitrary closed legacy closures after a later error.

## State and outcomes

Saved settings contain user intent, including true and false. The registry separately acknowledges local application. A requested feature with unavailable config displays WAIT. Linked recovery/effects records use one visible control.

Reach remains permanently requested, even when a compatibility conflict prevents application, and has no disable toggle. Config replacement releases the old table and patches the new one. External writes are preserved and reported.

Combat records intention, WolfBiteAt, a candidate near the expected claim window, native FeralHit feedback and later target HP. In v2412 the marker precedes the native Bite request. The hub does not observe actual outgoing Bite/BiteHit calls and never fabricates them. HP decline is a correlation. HP baselines are captured at the native marker rather than after the delayed claim, and native FeralBiteLocal targets and FeralHit replies remain separate evidence. The native HIT2.PREDICT flag is reversibly disabled so local prediction does not impersonate a confirmed impact.

Recovery does not keep Rest primed at full health. Real input releases owned Rest; held attacks prevent rearming. The native post-Rest lock is preserved and reported as a possible blocker. HP recovery yields to combat. Condition recovery can request native Rest during a known combat tag when there is an injury, bleed or venom deficit; it still yields to held/recent attacks, abilities, climb/flight, capture, minigames and feeding. Ground movement alone does not block recovery. Unknown combat state blocks both purposes. Stationary manual Rest is preserved. With recovery enabled, real walking ends that Rest action once; velocity from sliding alone does not. Only captured native R/ButtonY and actual Rest controls transfer manual ownership; Z/X are ordinary actions. Explicit controls take priority before native input, including deferred native Rest taps. Same-character automatic provenance survives delayed responses and hot reload instead of expiring into manual ownership. Successfully masked echoes do not cause a timed pause. WolfDbgRestP resets only the owned native sit/lie/hold blend; manual actions, downed state, character changes and shutdown release it. A pose mask establishes only local presentation. See V15_2_1_RECOVERY.md for the exact current animation contract.

Native HP and condition Rest factors remain intact at 2x and 4x respectively. Ordinary base rates are preserved; only unexpectedly larger factors are capped in the local reference. Independent real-value observations distinguish an increase from a request and never infer a multiplier from client config. Private server calculations may ignore all client values.

## Concurrent bites and minigames

The native v2412 FeralGrabV2Press action consumes MouseButton1 at priority 3000 and treats it as an immediate minigame press. During an eligible automatic session, grab_input temporarily removes that action and binds only Space/ButtonA/ButtonR2 to the original native serverPress closure. MouseButton1 can reach the ordinary game bite path. The native closure is discovered only within the own FeralGrabV2UI script, with its actual remote and state upvalues verified. Discovery resumes in bounded slices rather than repeatedly scanning the same prefix.

Automatic presses retain actual native session IDs, strike IDs and current server-clock timestamps. A successful dispatch marks only the matching native UI strike as pressed, preventing duplicate touch/key submissions. It does not create a game grade. Hunter-count changes preserve pending timing; a missed crossing can use a later valid crossing of that same strike. Native UI bite/end cleanup and character generations cancel stale timing.

Disable, shutdown and reload release the owned manual binding and restore the original-equivalent native callback, exact key list and priority only for the same live native session and character. No global hooks, physical rotation, opponent part edits or extra Bite/BiteHit requests are used. Missing executor introspection is reported as PARTIAL during an active session. This input separation cannot promise bites while native pin, cooldown, Rest or other gameplay restrictions prohibit them.

## Manual feeding and cub rescue

Native discovery first inspects existing own-script callbacks on InputBegan, FeralFeedTap and FeralGrabV2. It reads their function upvalues without invoking or replacing connections. WolfController closure discovery is scoped to the own script and requires the actual player/remote anchors. tryBite additionally verifies its captured doBite function and WolfActions reference. toggleFeed state layout is validated before reading native pending/started state. The named cancelFeed prototype is not required to remain live: cancellation can use the original toggleFeed first branch only after verifying an active mode. It cannot start an inactive feeding offer. All calls retain native cooldown, pin, diet, distance and other eligibility checks. Missing capability does not cause fabricated gameplay requests.

Feeding intent starts only from E/native feeding UI or an already active native session. Both native pending approach and a bounded manual-intent fallback block Rest. A stationary session with no measured hunger/thirst increase can receive one original-toggleFeed stop/start repair. Movement, attacks, native no-food/completion replies, respawn and shutdown cancel pending repairs. There is no food search, threshold activation or local hunger/thirst write.

G remains ordinary carry/drop unless a native-eligible friendly cub in water is selected. Rescue may request one ordinary jump, wait for actual water-exit eligibility, and dispatch the normal carry request once. It does not alter water flags, permissions, age/size limits, positions or opponents. An own native Carry clamp must reference the cub before the ledger records an observed pickup.

The NPC/litter registry is bounded and used for affiliation and rescue. Real Players service ownership wins over NPC attributes and litter Body references. Both tracker and renderer reject NPC overlays. Outlines are hollow and health-coloured; plain names retain pack hue. Floating percentages and distance labels are removed.

## Work and data bounds

One heartbeat gives pending minigame strikes priority. Discovery is restricted to three own-script callback chains; the shared resumable source examines at most 32 entries within an approximate 2 ms slice, with bounded depth, connections, queue and accepted functions. No heap enumeration fallback remains. Pending native strikes defer discovery and nonurgent scans/config/terrain work, including when recovered from native UI state. All discovery state is released on completion and shutdown. Target discovery runs at most about eight times per second and inspects at most 256 NPC children and 256 litter records. Geometry is calculated from current positions, and the guide uses the verified native target score. The renderer projects up to 24 real players and a small guide, skips disabled tags and avoids unchanged property writes. The marker combines client geometry with validated native cooldown/guard evidence; unknown timing and stale geometry are grey. Independent recovery observations use bounded six-second windows. Guarded Vulture release/resume handling lives with the existing flight owner and does not edit native physics or locks. See V15_3_IMPROVEMENTS.md. Terrain safety checks run only for requested idle walks. Pose guards read only the current own Rest attribute.

The ledger retains 160 events and aggregate rate buckets; transaction history retains 32 entries. Rates exclude character, maximum HP, combat, movement and Rest-mode transitions. Missing condition attributes never count as cures. The hub includes no console dump, private capture payload, credential or automatic GitHub upload.

## Right Shift

A single high-priority ContextActionService binding passes through when text is focused. It can consume event-driven sprint bindings. WolfController also polls IsKeyDown(RightShift), which an ordinary CAS sink cannot hide. Native sprint overlap remains a compatibility limitation.

The owned pose reset expires after a native animation frame (hub Camera+3; captured WolfAnim Camera+2), including long frame hitches. Visible cooldown guidance can use native Species/Passive calculations and the own bite marker when private callbacks are VM-isolated; that path reports private state as unverified. Validated previous-owner handles are preserved rather than searched for in the global heap.

15.4 adds one owned minigame deadline timer (at most four wakes per strike), with event/Heartbeat/render checks. The scheduler solves the first safe Perfect interval and always sends actual time. Readable native absence differs from a failed read. Manual takeover, end, respawn and close cancel timers; own results cancel only their matching pending strike. Native action attribute listeners can release Rest and idle movement before the next scheduled check. Current selected-body geometry is refreshed between full scans. Known native swim/climb/venom consumption inputs share the stamina lease; native level replacements invalidate the old plan. The existing ledger measures recent stamina by species/locomotion. See V15_4_UPGRADES.md for exact boundaries.
