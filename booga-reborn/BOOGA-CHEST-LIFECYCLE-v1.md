# Chest lifecycle review — 18 November 2026

**Scope: spawning a resource chest while owning zero of it, without a
purchase or consumption of owned chests. No working grant has been found.**
The user explicitly excluded owned-chest tests and other resource methods.

## What the collected client actually does

| Stage | Evidence in the original export | What it establishes |
|---|---|---|
| Inventory display | `Game/inventory`, S0010366 around 1224–1247 | The Open control is enabled from the local inventory quantity. The UI refuses an unowned opening before sending anything. |
| Open request | S0010366 around 1250 | The typed ChestDrop request contains the chest name. No discovered ownership receipt, passed-check flag, cost or quantity is attached. |
| Purchase request | S0010366 around 1253 | Buying is a separate PurchaseChest request containing an item ID. The client does not supply a purchase-price override here. |
| Incoming spawn animation | `Game/worldEffects`, S0010393 around 89–129 | FallingChest receives an existing entity ID, timing and an end CFrame, resolves the entity, and animates it. This incoming event is not a client grant command. |
| Entity registration | `Game/entities`, S0010284 around 27–32 and 67–136 | Entity-tagged instances are indexed by EntityID; native rendering can resolve them through getEntity. |
| Physical chest | Archived object records under `Workspace/dropChests` | 24 Pleb Chest models all have the Entity tag, numeric EntityID and positive IntValue Health. Their format matches the original observer's structural assumptions. |
| Loot and inventory | S0010393 around 59–83; `Game/pickup`, S0010273 around 132–144; S0010366 around 783–795 | Client break feedback handles presentation, pickup requests identify existing world entities, and incoming inventory packets update the local view. These are separate stages from spawning a chest. |

Each archived Pleb Chest has a Contents folder. Those 24 folders had no
exported children or attributes. They do not expose an editable client
inventory that establishes server-side chest contents. Item-data possibleDrops
lists are visible configuration, not an observed client-authorized loot grant.
Reconstruction aliases in the large item-data table remain unreliable; they
are not used to infer authoritative live prices or loot receipts.

The 24-model observation validates Pleb Chest structure in the archived
session. It does not independently validate every current Resource Chest
spawn, distance, streaming condition or timing in the user's later session.

## Actual outcomes so far

1. The first Pleb Chest report stopped at BEFORE_UNAVAILABLE with both request
   flags false. It never tested the chest-open handler.
2. The v1.0.1 Resource Chest report submitted one client request and observed
   no matching chest during 10.1 seconds. Both reads showed zero owned and
   unchanged coins. RequestData returned nil both times, so both views came
   from the live client cache.

The second result establishes no working free spawn. It does not contain a
server acknowledgment, ownership-error message, native falling-chest event,
loot grant or persistence check. Server ownership validation is consistent
with the outcome; the private handler and exact reason remain unavailable.

## Native dispatch detail relevant to a reliable observer

`Modules/libraries/byteNet/packets/packet`, S0009459, keeps a single callback:
calling listen replaces it. A naive extra FallingChest.listen call could
disable the game's normal chest animation handler.

`byteNet/process/read`, S0009463 around 72–83, instead looks up the packet's
fireListener field at dispatch time. v1.1 temporarily wraps that specific
field, observes only a nearby falling-chest signal, and calls the original
dispatcher exactly once with the same arguments and return values. Native
exceptions propagate normally; observer exceptions cannot suppress delivery.
Cleanup restores the field only while the observer still owns it.
Unsupported/frozen packet tables are not forced writable, and prevent the
new request if native observation cannot be installed.

Independent Notify/Toast OnClientEvent subscriptions classify only fixed
ownership, cooldown, affordability and unknown-chest categories. Raw messages,
names and arbitrary payloads are discarded. Nearby falling events can still
belong to another action, so correlation remains explicit rather than proof.

## Current bounded continuation

[Unowned Chest Trial v1.1](README-booga-chest-trial-v1.1.md) retains the zero-owned
gate and one normal open request. It adds native feedback and fixed server
notice classifications. It has no purchases, owned opening mode, paired
requests, inventory edits, loot-table edits, local chest clones or gameplay
remotes unrelated to ChestDrop. A single instrumented recheck of a type tried
by v1.0 is possible within the same inherited three-request session budget.

Other legacy endpoint names, including CreateChest, have no identified
matching client protocol/handler in the recovered game sources. Their names
alone do not establish a working alternate grant. No such endpoint was invoked.

This continuation improves evidence about the existing request. It does not
invent a new grant mechanism or establish that the server has an exploitable
ownership check. A free-spawn claim requires an observed real chest and
usable server-recognized loot; that evidence is still missing.
