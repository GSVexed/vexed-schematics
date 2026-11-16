# FERAL goal review and owner-tool findings — v1.2

This review distinguishes implemented client work, user observations and
unresolved server behaviour. A preview, status icon or displayed balance is
not treated as a completed gameplay grant.

| Goal | Concrete work | Outcome |
|---|---|---|
| Reliable unlimited stamina | Same cached tuning, repair, module/drift checks and species/activity/tuning observations. | User reported v1.0 working on Bear. Broader coverage and v1.2 remain untested in Roblox. |
| Actual health regeneration | Failed writer removed; own health/maxima changes and relevant conditions recorded. | No working health grant; exact authoritative writer unidentified. |
| Arbitrary spendable amber | Wallet observations, native replies and optional own-save amber snapshot if lookup accepts it. | No arbitrary grant or purchasing-power increase established. |
| Unlock/spawn all animals | Filtered own ownership, observed character species and owner access/read checks. | No accepted restricted spawn or bypass established; ownership and spawn permission differ. |
| Permanent coats | Filtered own coat flags, better local template matching, restoration and replacement detection. | Local trials only; no permanent paid/owned entitlement grant. |
| Functional buffs/ailments | Reversible cached low-HP/injury movement-input adjustment and speed/status observations. | New experiment untested; no health cure, injury removal, damage or growth grant claimed. |
| Useful travel | General X/Z, saved bookmarks, landing revalidation and corrected body-centre observations. | Implemented client movement attempt; safety/acceptance unverified. |
| UI/reliability | Dedicated OWNER/REPORT, reversible settings, bounded observers, explicit errors and one-file evidence. | Source/simulation checks pass; full engine verification outstanding. |
| Owner gift/save tools | Capability audit, cached self predicates, optional self look/list and existing launchers. | Intended client capabilities identified; gift/restore permission unverified. |

## Health investigation

A SHA-256 deduplicated search of 221 distinct saved reconstructed game source
texts found no literal .Health = or .MaxHealth = assignments. HEALTH_REGEN
appeared as one definition in NeedsConfig without a recovered client consumer.
This limited search does not cover indirect writes, reconstruction omissions,
uncollected code or server behaviour.

The inventory contains a StarterCharacterScripts/Health Script whose
server/unknown source was not recovered. The final Animate supplement is
animation-track logic. Another client scan cannot establish unavailable
server code.

The user reported that local HP increases were overwritten. That establishes
failure of that method in the reported run. Timing, maxima, growth, damage,
bleeding, venom and rest observations may clarify later behaviour but do not
identify the writer.

## A concrete movement path

Recovered WolfController lines 6992–7017 read NeedsConfig.HURT_SLOW and
StatusConfig.INJURY.SLOW_PER_POINT when applying movement multipliers.
v1.2 validates these cached inputs and changes them only as an opt-in
experiment, with rollback/restoration. Actual movement improvement and server
acceptance are unverified; health and status points remain unchanged.

## Owner interfaces

| Interface | Recovered client predicate | Intended capabilities visible in client code |
|---|---|---|
| FeralGiveUI / FeralGive | GiftConfig enabled; own UserId in ADMINS array. | Positive/negative amber, all/individual animals, coats, revives, pending/history/cancellation. |
| FeralSaveAdminClient / FeralSaveAdmin | Own UserId in OnboardingConfig.OWNERS map. | Saved-version lookup, restore and undo. Restore text indicates kicking the target and replacing progress. |
| FeralTestNew | Own UserId in DevConfig.OWNERS array. | Start/stop PLAY AS NEW test context. |
| FeralWolfB | Own UserId in DevConfig.OWNERS array. | Developer alternate model/animation template where a _B variant exists. |
| FeralPerfTest | Own UserId in DevConfig.OWNERS array. | Client graphics/performance controls. |
| Onboarding admin | Own UserId in OnboardingConfig.OWNERS map. | Owner onboarding inspection/control. |

The gift UI has an explicit all-animal choice. A gift of ownership would not
itself prove removal of AccessConfig's separate owner/tester spawn checks.
The gift UI describes queued delivery to offline/other-server recipients and
cancellable pending items; this is intended developer functionality, not
evidence that an ordinary account may use it.

The client shows a native look request for gifts and list for saves. v1.2
offers these only as explicit self-targeted read checks. It validates the
returned target before retaining limited metadata. Successful reading does
not establish giving, restoring or other write permission.

No owner IDs, recipients, raw saves, version contents or raw server errors
are published. The hub does not modify owner tables/identity, execute
decompiled admin code, query another account, or submit gift, cancellation,
restore, undo, test-start or variant-toggle operations. Existing launcher
visibility is separate from server permission.

## Evidence map

Paths refer to the original uploaded baseline. Reconstructed line numbers and
fidelity limits apply; exact server implementations were not recovered.

| Evidence | Exported source |
|---|---|
| Stamina and movement | UPLOAD_PART_002_DATA/sources/game/S0003620_part001.source.txt |
| Needs/health constants | UPLOAD_PART_002_DATA/sources/game/S0000033_part001.source.txt |
| Injury movement input | UPLOAD_PART_002_DATA/sources/game/S0000085_part001.source.txt |
| Restricted access | UPLOAD_PART_002_DATA/sources/game/S0000088_part001.source.txt |
| Coat ownership/purchases | UPLOAD_PART_003_DATA/sources/game/S0003659_part001.source.txt |
| Gift config | UPLOAD_PART_002_DATA/sources/game/S0000114_part001.source.txt |
| Gift client flow | UPLOAD_PART_003_DATA/sources/game/S0003719_part001.source.txt |
| Save list/restore/undo | UPLOAD_PART_003_DATA/sources/game/S0003699_part001.source.txt |
| PLAY AS NEW owner UI | UPLOAD_PART_003_DATA/sources/game/S0003670_part001.source.txt |
| Alternate variant owner UI | UPLOAD_PART_003_DATA/sources/game/S0003704_part001.source.txt |
| Performance owner UI | UPLOAD_PART_003_DATA/sources/game/S0003721_part001.source.txt |

The next useful evidence is the focused field report, including any optional
self-read result. There is no current evidence that all server-dependent
goals are complete.
