# Amber, restricted spawns and recovery — focused methods

17 November 2026. Source-guided investigation using the existing verified
client export and the two v1.2 reports. No new full scan or original server
source was obtained. v1.4 implements explicit own-account trials for the
concrete paths below; no positive game-server outcome has been observed yet.

## Corrections to earlier assumptions

The Field Hub through v1.3 revealed hidden cards and previewed replicated
animals; it did not send a restricted FeralSelect request. Failed card clicks
therefore did **not** establish rejection by the actual server spawn handler.
Client UI gates, ownership, price and server spawn validation are separate.

The v1.2 gift lookup used a text self ID. Its unexpected_reply summary discarded
the reply shape. That did not establish the same result for a numeric lookup or
the independent give branch. v1.4 distinguishes those outcomes without copying
raw replies or querying another account.

The failed HP writer is a separate experiment from sending the server the
native Rest intent. Ordinary game recovery in later reports is not counted as
successful added hub regeneration.

## Protocol and evidence map

| Goal/path | Captured evidence | v1.4 trial | What would support it / what remains unknown |
|---|---|---|---|
| Own amber gift | S0003719 FeralGiveUI: action payload at 927–943, ask wrapper at 1071–1084, look at 1359, give at 1447–1448; S0000114 GiftConfig | Own baseline lookup; one give(self, amber, positive amount); recognized reply and optional own saved balance comparison | Own verified server balance increasing by the expected amount supports a credited result. Permission, inferred tuple fidelity, spending and persistence remain separate |
| Own animal/all-animal gift | S0003719:950–963 and give call; wildcard * is a supported UI option | One self-only animal tuple for SnowLeopard, Phantosuchus or * | Reply is not ownership proof; fresh own sync and then a live spawn are stronger evidence. Owner/tester spawn gates can remain independent |
| Claimed reward replay | S0003658: play claim sites around 2073/2085/2215 and state/paid handling around 3092; S0000064 RewardConfig | Read fresh state, replay one already-claimed play tier, watch matching paid + fresh state + balance | Tests whether the server independently prevents duplicates. Client claimed checks alone cannot answer this. A matching observation is a candidate, not causal/persistence proof |
| Direct restricted spawn | S0003625:chooseTarget at 608–660, pickAnimal at 782–901, FeralSelect six-argument calls at 879/899 | One species/sex/empty-slot/false/nil/nil request | Matching living species/root plus a new matching active-slot sync supports an actual spawn. Existing tools had not tested this. Server ownership, role, name and slot validation are unknown |
| Snow Leopard amber purchase | S0003625:819, buy(species); S0000054:182–219, loaded client price | Normal buy with enough visible amber and expected client price, skipping already-owned state | New own ownership after the request is evidence. The request has no amount/price argument; changing a local price does not change that wire packet |
| Mobile Rest recovery | S0003620:6205–6253, local movement clears controller rest and state changes send Rest(bool); S0000033 health constants | Baseline → direct Rest=true → Rest=false, then optional bounded request loop | Tests whether server recovery follows the reported Rest intent independently of client movement. Actual Health implementation and server immobility/combat checks are absent |

The gift wrapper and its vararg unpacking have reconstruction defects. The
give tuple is inferred from the UI payload and call sites, not recovered
original source or captured live wire traffic. Unclassified/nil replies remain
ambiguous; no permission failure is invented from silence.

## The health method in detail

WolfController keeps local rest state in reconstructed locals v59/v60. Its
movement loop clears local rest on movement. It sends WolfActions Rest only
when those local states change. Sending the normal boolean directly does not
write either local variable or Health. If the server trusts that intent without
requiring immobility, this could permit the ordinary rest multiplier while
moving. If it validates movement/eligibility, it may do nothing. Neither outcome
can be decided from the client code alone.

The earlier reports provide a useful reference: selected unchanged-max,
non-combat Tiger intervals were roughly 1% max HP/s without rest and 2% with
rest. Those were ordinary game behavior. The new trial specifically compares
moving samples around the direct server signal.

It requires a large enough initial deficit so full-health saturation does not
hide the aftermath. Rates use unchanged maximum HP, adequate needs and matched
interval timing. Three moving intervals per phase are a minimum exploratory
screen; the result is not a controlled statistical proof. Damage, mode changes
and native assist interference stop the trial and clean up the signal.

The separate loop remains labeled unproven, even if a comparison shows an
uplift. It sends at most one true packet per five seconds and restores false
when the same character is still active. No runtime patch of HEALTH_REGEN,
Humanoid.Health or server-only code is attempted.

## Currency/spawn constraints found in the code

- Captured ShopConfig prices are Snow Leopard **3,000** and Phantosuchus
  **100,000,000**. The client AccessConfig separately marks tester-only and
  owner-only eligibility. Price, entitlement and role are not interchangeable.
- Native animal buy sends only a species. Spoofing the wallet or a displayed
  product price provides no evidence that the server will accept a purchase.
- Native saved-animal play selects a slot. Replacing a locally displayed slot
  species would not establish that the server's saved slot changed.
- SaveConfig defines five base slots plus separately locked extras. The new
  spawn trial uses only the loaded base count, a fresh numeric-keyed own map
  and an empty slot. It does not guess paid-slot access or overwrite a grown
  Tiger to test a hypothesis.
- AmberConfig describes survival payouts, stages, hunts, quests and old-pine
  chunks. The baseline inventory contains a FeralAmberChunks folder and 21
  empty model shells with no captured pickup parts and default pivots. Those
  records do not provide a usable pickup route or a minting endpoint. FeralAmber
  appears as an inbound gain/intro notification in the recovered HUD; v1.4 does
  not invent an outbound add-currency verb for it.
- Quest UI's recovered direct request is hello; visible reward descriptions
  are not evidence of an arbitrary client award amount. Tutorial/owner/debug
  interfaces exist, but their server validation was not recovered.

## What the tests establish

Compile-only and simulated tests verify packet arity/types, fixed own targets,
positive gift bounds, independent read/write classification, fresh empty-slot
selection, no purchase on a spawn trial, no duplicate purchase for reported
ownership, one replay attempt, no automatic startup traffic, cancellation of
late work, Rest cleanup/throttling, rate classification and privacy. Actual
v1.0–v1.3 source upgrades are exercised in the mock environment.

They cannot establish game-server acceptance, real spending, persistence,
protection from damage or a universally exploitable server flaw. No server-only
handler was retrieved. Complexity does not guarantee that any grant exists.
The focused report makes successful, unsuccessful and unresolved observations
inspectable without another huge client dump.

[Run and upload guide](README-field-hub-v1.4.md)
