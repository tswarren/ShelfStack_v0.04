# v0.04-7 Allocations and Reservations — Functional Specification

## Status

**Complete** — delivered in v0.04-7. Depends on [v0.04-6 completion](../../implementation/v0.04-6-completion.md) (merged).

Companion documents: [data-model.md](data-model.md), [test-plan.md](test-plan.md).

## Job

Introduce **`demand_allocations`** as the v0.04 mechanism for claiming or pointing demand toward supply.

v0.04-7 turns v0.04-6 demand from “recorded need” into actionable allocation state:

```text
demand_line
  → demand_allocation
      → on-hand stock (operational reserve via availability cache)
      → inbound purchase order line
      → [v0.04-8+] sourcing / vendor response
      → [v0.04-9+] receipt conversion / fulfillment
```

## Purpose

v0.04-6 created the canonical demand record. v0.04-7 adds the layer that answers:

* Is any quantity already reserved for this demand?
* Is this demand waiting for stock?
* Is this demand tied to an inbound purchase order line?
* How much of the requested quantity is allocated, unallocated, fulfilled, released, expired, or canceled?
* Can staff see which customer/store demand has a claim on current or inbound supply?
* Can the system expire holds and release claims without posting inventory?

## Core rule

**Allocation is not an inventory ledger event.**

```text
Demand allocations must not call Inventory::Post or create inventory ledger entries.

Active on-hand demand allocations do affect operational availability through
inventory_balances.quantity_reserved / quantity_available, refreshed by a
dedicated availability rebuild service.
```

| Quantity | Source of truth |
| -------- | --------------- |
| `quantity_on_hand` | Inventory ledger / `Inventory::Post` |
| `quantity_reserved` | **Cache** — active legacy on-hand reservations + active v0.04 `on_hand` demand allocations (+ any existing POS/session reserved claims the app already includes) |
| `quantity_available` | **Cache or derived** — `quantity_on_hand - quantity_reserved` (and any existing POS pending-claim rules the app already applies) |

**Non-negotiable:** Without updating the reserved/available cache, v0.04-7 allocations would appear in `/demand` but would not reduce sellable availability at POS.

---

## Source documents

```text
docs/design/VERSION_0.04.md
docs/roadmap/v0.04-delivery-roadmap.md
docs/v0.04/v0.04-6-demand-foundation/spec.md
docs/v0.04/v0.04-6-demand-foundation/data-model.md
docs/implementation/v0.04-6-completion.md
docs/v0.04/v0.04-5-used-variant-rules/spec.md
docs/specifications/phase-7a-customer-demand-spec.md (legacy behavior reference)
docs/specifications/phase-8.5-3a-order-handling-readiness-spec.md
AGENTS.md
```

---

## Hard gates

1. **No sourcing runs, vendor attempts, vendor responses, or cascade logic** — v0.04-8.
2. **No PO quantity lifecycle redesign** — requested/confirmed/backordered/canceled/received/short modeling belongs to v0.04-9.
3. **No `PostReceipt` or receipt-line allocation bridge** — v0.04-9.
4. **No receipt posting changes** in v0.04-7.
5. **No allocation service calls `Inventory::Post`.**
6. **No legacy `inventory_reservations` writes** from v0.04 allocation services.
7. **No legacy `purchase_order_line_allocations` or `receipt_line_allocations` writes** from v0.04 services.
8. **Do not auto-convert unavailable used demand to new-item vendor demand.**
9. **Preserve v0.04-5 used variant rules** through `ProductVariants::OperationalPolicy`.
10. **Product variant remains the allocation grain**; **demand line remains the need grain**.
11. **Allocation kinds implemented in v0.04-7:** `on_hand` and `inbound_purchase_order` only.
12. **No vendor backorder, sourcing attempt, receipt line, or transfer inbound allocation kinds** in v0.04-7.
13. **No POS schema replacement** beyond optional fulfillment reference on allocation fulfill — `pos_transaction_lines.inventory_reservation_id` unchanged until a later bridge slice.
14. **v0.04-10 owns full legacy route and table cleanup.**
15. **No cache quantity columns on `demand_lines`** in v0.04-7 — derive from allocation rows.
16. **Preserve v0.04-6 write-path cutover** — new demand still creates `demand_lines` only; allocations attach via v0.04-7 services.

---

## Legacy posture (v0.04-7)

| Aspect | v0.04-7 behavior |
| ------ | ---------------- |
| New on-hand holds | **`demand_allocations` (`on_hand`)** — not `InventoryReservations::ReserveOnHand` |
| New inbound customer claims | **`demand_allocations` (`inbound_purchase_order`)** — not new `purchase_order_line_allocations` |
| Legacy `inventory_reservations` | **Read** for availability rebuild; **not written** by v0.04 services |
| Legacy PO/receipt allocations | **Read** for inbound quantity math; **not written** by v0.04 services |
| Legacy customer-request / TBO routes | May remain reachable; not expanded |
| POS pickup | Existing `inventory_reservation_id` path unchanged; v0.04 fulfill bridge is optional reference only |
| Item drawer legacy activity | Remains collapsed read-only until v0.04-10 |

**Transition rule:**

```text
v0.04-7 does not write inventory_reservations. Until v0.04-10, availability rebuilds
must account for both legacy active on-hand inventory_reservations and active v0.04
on_hand demand_allocations so staff-facing available quantity remains accurate.
```

---

## Baseline mapping

| Legacy concept | v0.03 path | v0.04-7 target |
| -------------- | ---------- | -------------- |
| On-hand hold / reservation | `InventoryReservations::ReserveOnHand` | `DemandAllocations::AllocateOnHand` + availability cache rebuild |
| Incoming PO customer allocation | `purchase_order_line_allocations` + `inventory_reservations` incoming | `DemandAllocations::AllocateInboundPurchaseOrder` |
| Reserved / available display | `inventory_balances.quantity_reserved` from legacy reservations only | Unified rebuild: legacy + v0.04 `on_hand` allocations |
| Hold from item drawer | v0.04-6: demand only | v0.04-7: demand + partial on-hand allocation when stock available |
| Nightly hold expiry | `InventoryReservations::Expire` (Phase 7A) | `DemandLines::ExpireDue` + allocation expire cascade |
| POS pickup fulfillment | `Pos::AddReservationLine` / `inventory_reservation_id` | `DemandAllocations::Fulfill` with optional reference; POS schema unchanged |
| Notify queue | Legacy customer-request notify paths | `/demand` filter: `capture_intent=notify`, unallocated |

---

## Explicit deferrals

| Capability | Defer to |
| ---------- | -------- |
| Vendor sourcing / vendor response allocations | v0.04-8 |
| PO line confirmed/backordered/short quantity lifecycle | v0.04-9 |
| Receipt allocation conversion (inbound → on-hand at receive) | v0.04-9 |
| `PostReceipt` updating demand allocations | v0.04-9 |
| Full POS pickup from `demand_allocation_id` | Later bridge (post v0.04-7 or with v0.04-9) |
| Legacy route/table removal | v0.04-10 |
| Allocation kinds: `vendor_backorder`, `sourcing_attempt`, `receipt_line`, `transfer_inbound`, `waitlist`, `preorder` | v0.04-8 / v0.04-9 / later |
| Production scheduler wiring for expiry job | Optional in v0.04-7 (service + job + rake required) |
| Compensating demand on return/refund reopening `fulfilled` demand | Later milestone |

---

## Concepts

### Demand line

A committed need created in v0.04-6. See [v0.04-6 spec](../v0.04-6-demand-foundation/spec.md).

### Demand allocation

A claim or pointer from a `demand_line` to supply.

v0.04-7 supports:

```text
on_hand                  — claims current stock at store + variant (via availability cache)
inbound_purchase_order   — claims expected quantity on an existing open PO line
```

Multiple allocation rows per demand line are preferred over one row with mixed supply.

### Unallocated demand

Derived — do **not** create an “unallocated allocation” row:

```text
quantity_requested
  - active_allocated_quantity
  - fulfilled_quantity
= unallocated_quantity
```

Where:

```text
active_allocated_quantity = sum(active demand_allocations.quantity_allocated)
fulfilled_quantity        = sum(fulfilled demand_allocations.quantity_allocated)
```

---

## Intent-specific allocation behavior

Normative matrix — drives services, drawer behavior, and tests.

| Capture intent | Allocate on create? | Partial allocation? | Default expiry | Manual on-hand later? | Manual inbound PO later? | Notes |
| -------------- | ------------------: | ------------------: | -------------- | --------------------: | -----------------------: | ----- |
| `hold` | yes | yes | **14 days** | yes | yes | Protect stock when possible |
| `notify` | no | n/a | none by default | yes | yes | No auto-hold on arrival in v0.04-7 |
| `special_order` | no | n/a | staff-set | yes | yes | No sourcing in v0.04-7 |
| `used_wanted` | no | n/a | staff-set | yes, **used-like only** | **no** | No vendor path |
| `manual_tbo` | no | n/a | none | yes | yes | Store demand; `/demand` only |
| `buyer_replenishment` | no | n/a | none | yes | yes | Store demand; `/demand` only |
| `research` | no | n/a | none | no until matched | no until matched | `captured` cannot allocate |

**Hold on create (v0.04-7):**

```text
Record hold request
  → create demand_line (default expires_at = 14.days.from_now unless staff override)
  → DemandAllocations::AllocateOnHand for min(quantity_requested, available_on_hand)
  → DemandLines::RecalculateAllocationStatus
  → Inventory::RebuildAvailabilityCache for store + variant
```

| Requested | Available | Demand status | Staff message (example) |
| --------: | --------: | ------------- | ----------------------- |
| 1 | 1 | `allocated` | Hold recorded; 1 copy allocated. |
| 3 | 2 | `partially_allocated` | Hold recorded; 2 of 3 copies allocated. |
| 3 | 0 | `open` | Hold recorded; no stock was available to allocate. |

**Over-availability override:** When staff intentionally allocate more than `available_on_hand`, require `demand.allocations.override_availability`, override reason, actor, and audit event. Do not use `pos_authorizations` for this path.

---

## Allocation kinds (v0.04-7)

| Kind | Meaning | Supply reference |
| ---- | ------- | ---------------- |
| `on_hand` | Claims current stock | `store_id` + `product_variant_id` |
| `inbound_purchase_order` | Claims expected inbound stock | `purchase_order_line_id` |

Deferred kinds: see [Explicit deferrals](#explicit-deferrals).

---

## Allocation statuses

```text
active
  → fulfilled
  → released
  → expired
  → canceled
```

| Status | Meaning |
| ------ | ------- |
| `active` | Allocation currently claims supply |
| `fulfilled` | Allocated quantity satisfied (pickup/sale/manual fulfill) |
| `released` | Staff deliberately released claim |
| `expired` | Expired with demand/hold expiry |
| `canceled` | Canceled due to demand cancel or administrative correction |

---

## Demand line statuses (v0.04-7 extension)

v0.04-6:

```text
captured
open
canceled
expired
```

v0.04-7 adds:

```text
partially_allocated
allocated
fulfilled
```

**Terminal statuses:**

```text
fulfilled
canceled
expired
```

### Status rules (normative)

1. **`captured` demand cannot be allocated** — must `MatchVariant` → `open` first.
2. **`fulfilled` is terminal** in v0.04-7 (later refund workflows may create compensating demand rather than reopen).
3. **`DemandLines::Cancel` cancels active allocations first**, then marks demand `canceled`.
4. **Manual `DemandLines::Expire` and `DemandLines::ExpireDue` expire active allocations first**, then mark demand `expired`.
5. **Every allocation mutation** calls `DemandLines::RecalculateAllocationStatus`.
6. **`fulfilled`** when `fulfilled_quantity >= quantity_requested`. **`allocated`** when active allocations cover `remaining_to_fulfill` (see [data-model.md](data-model.md) — e.g. 1 fulfilled + 1 active on a qty-2 demand is `allocated`, not `partially_allocated`).

### Status meaning

| Status | Meaning |
| ------ | ------- |
| `captured` | Provisional/unmatched; no allocations |
| `open` | Matched; zero active/fulfilled allocation covering any quantity |
| `partially_allocated` | Some but not all requested quantity actively allocated and/or fulfilled |
| `allocated` | Full requested quantity actively allocated; not yet fulfilled |
| `fulfilled` | Full requested quantity fulfilled |
| `canceled` | Demand canceled |
| `expired` | Demand expired |

---

## Availability cache

### Service

**`Inventory::RebuildAvailabilityCache`** (extend or supersede `InventoryReservations::RebuildReservedQuantities`):

For each `inventory_balances` row (store + variant):

```text
legacy_reserved =
  sum active legacy on-hand inventory_reservations
  (existing ON_HAND_CACHE_TYPES / ON_HAND_CACHE_STATUSES rules)

v0047_reserved =
  sum active demand_allocations
  where allocation_kind = on_hand

quantity_reserved = legacy_reserved + v0047_reserved (+ any existing POS reserved claims already included by current app rules)

quantity_available = quantity_on_hand - quantity_reserved
```

**When to rebuild:** After every on-hand allocation create, release, cancel, expire, fulfill, and after demand cancel/expire cascades affecting on-hand allocations. May rebuild scoped to affected store + variant.

**Inbound PO allocations do not affect `quantity_reserved`.**

### Display (item / variant operations)

Show v0.04 allocation-derived reserved quantity **separately from** legacy reservations until v0.04-10 where practical:

```text
On hand
Reserved (v0.04 allocations)
Reserved (legacy)
Available
On order
Allocated inbound (v0.04)
Allocated inbound (legacy)
Unallocated demand (count/qty summary)
```

Exact presentation may compress labels; tests assert underlying numbers.

---

## Inbound PO allocation

Staff may manually allocate demand to an **existing** purchase order line.

**Available inbound quantity** (conceptual — confirm column names in implementation against current `PurchaseOrderLine` model):

```text
open_line_quantity =
  existing open quantity on PO line (e.g. quantity_ordered - quantity_received for eligible lines)

available_inbound =
  open_line_quantity
  - active v0.04 inbound_purchase_order demand_allocations on that line
  - active legacy purchase_order_line_allocations on that line
```

**Rules:**

1. PO line same store as demand (via PO header).
2. PO line same `product_variant_id` as demand.
3. PO header and line in eligible open/inbound statuses (implementation lists allowed statuses from current models — e.g. line `open`, `partially_received`, `backordered`; not terminal canceled/closed).
4. Allocation quantity positive; does not exceed `available_inbound`.
5. **Must not double-claim** quantity already claimed by legacy PO line allocations.
6. **Does not change** PO line quantity or PO header status.
7. **Does not post inventory.**

Do **not** introduce confirmed/backordered/short lifecycle fields in v0.04-7.

---

## Core services

### Demand allocation services

| Service | Responsibility |
| ------- | -------------- |
| `DemandAllocations::AllocateOnHand` | Create active `on_hand` allocation; rebuild availability cache; audit |
| `DemandAllocations::AllocateInboundPurchaseOrder` | Create active inbound allocation; audit |
| `DemandAllocations::Release` | Active → `released`; recalc demand; rebuild cache if on-hand |
| `DemandAllocations::Cancel` | Active → `canceled`; recalc demand; rebuild cache if on-hand |
| `DemandAllocations::Expire` | Active → `expired`; recalc demand; rebuild cache if on-hand |
| `DemandAllocations::Fulfill` | Active → `fulfilled`; optional fulfillment reference; recalc demand; rebuild cache if on-hand |
| `DemandAllocations::Availability` | `available_on_hand`, `available_inbound` calculations |

### Demand line services (extended)

| Service | Responsibility |
| ------- | -------------- |
| `DemandLines::RecalculateAllocationStatus` | Single status recalc entry point from allocation sums |
| `DemandLines::StartFromItem` | **Extended:** hold path orchestrates create + partial allocate |
| `DemandLines::Cancel` | **Extended:** cancel active allocations first |
| `DemandLines::Expire` | **Extended:** expire active allocations first |
| `DemandLines::ExpireDue` | Scheduled/staff batch expiry for due demand lines |
| `DemandLines::ExpireDueJob` | Job wrapper for expire due |
| `Inventory::RebuildAvailabilityCache` | Unified reserved/available cache rebuild |

---

## Allocation lifecycle (summary)

All paths:

* Record audit events.
* Call `DemandLines::RecalculateAllocationStatus`.
* **Never** call `Inventory::Post`.
* On-hand mutations **rebuild availability cache** for affected store + variant.

**`DemandAllocations::AllocateOnHand`** — allowed when demand not terminal, variant present, quantity positive, variant matches demand, store matches, sufficient availability (unless `override_availability`), used policy allows combination.

**`DemandAllocations::AllocateInboundPurchaseOrder`** — allowed when demand not terminal, PO line eligible, variant match, sufficient inbound availability.

**Fulfill:** Minimal bridge — if fulfillment is a POS sale, POS continues to post inventory through existing POS flow; allocation fulfill records operational completion only.

---

## Expiry job

v0.04-7 implements:

```text
DemandLines::ExpireDue
DemandLines::ExpireDueJob
shelfstack:v0047:expire_due_demand   (operator rake)
```

Behavior:

1. Find non-terminal demand lines with `expires_at <= now`.
2. Expire active allocations for those lines.
3. Mark demand lines `expired`.
4. Rebuild availability cache for affected on-hand allocations.
5. Audit events; no deletes; no `Inventory::Post`.

Production scheduler wiring is **optional** in v0.04-7; service + job + rake must exist and be testable.

---

## UI scope

### `/demand/:id`

Allocation summary:

```text
Requested | Allocated (active) | Fulfilled | Unallocated | Status
```

Allocation table: kind, status, quantity, supply reference, allocated_at, expires_at, actor.

Actions (permission-gated):

```text
Allocate from on hand
Allocate from inbound PO
Release
Cancel
Expire
Fulfill
```

### `/demand` index

Add filters:

```text
allocation_state = unallocated | partially_allocated | allocated | fulfilled
allocation_kind = on_hand | inbound_purchase_order
capture_intent = notify (notify queue substitute)
```

### Item drawer

Hold result messaging per [Intent-specific allocation behavior](#intent-specific-allocation-behavior).

Label may remain **Record hold request**; success copy reflects allocation outcome.

### Customer show

Demand lines show allocation state (`Open`, `Partially allocated`, `Allocated`, `Fulfilled`, `Expired`, etc.).

### Item availability / variant operations

Show v0.04 vs legacy reserved breakdown per [Availability cache](#availability-cache).

---

## Permissions

Seed via `Seeds::V0047Permissions` (mirror v0.04-6 pattern):

```text
demand.allocations.access
demand.allocations.create
demand.allocations.release
demand.allocations.cancel
demand.allocations.expire
demand.allocations.fulfill
demand.allocations.override_availability
demand.expire_due
```

Existing `demand.access` grants viewing allocation summaries unless a narrower rule is required.

Store-scoped authorization consistent with `/demand` workspace.

---

## Audit events

```text
demand_allocation.created
demand_allocation.released
demand_allocation.canceled
demand_allocation.expired
demand_allocation.fulfilled
demand_allocation.override_availability_used
demand_line.allocation_status_recalculated
demand_line.expired_due
```

Do **not** audit every availability cache rebuild by default (too noisy). Optional debug-only logging if needed.

---

## Verification

Rake:

```text
shelfstack:v0047_verify_allocations
alias: shelfstack:v0047:verify_allocations
```

**STRICT checks (minimum):**

* `demand_allocations` table exists; enums load.
* Demand statuses include `partially_allocated`, `allocated`, `fulfilled`.
* v0.04 allocation services do not call `Inventory::Post`.
* v0.04 allocation services do not write legacy `inventory_reservations`.
* v0.04 allocation services do not write legacy PO/receipt allocation tables.
* Active on-hand allocation totals never exceed on-hand quantity for store/variant (except audited override rows flagged accordingly).
* Active inbound allocation totals never exceed eligible PO line available inbound (including legacy allocation subtraction).
* Used-wanted on-hand allocations use used-like variants only.
* Used demand not auto-allocated to vendor-orderable new supply.
* Expire-due path expires allocations without inventory posting.

---

## Implementation slices

Delivery order within v0.04-7:

| Slice | Scope |
| ----- | ----- |
| **A** | Schema + `on_hand` allocate/release/cancel/expire + status recalc + availability cache + hold-from-drawer |
| **B** | Inbound PO manual allocation + expire-due service/job/rake |
| **C** | Fulfill bridge + customer/index filters + UI polish |
| **D** | Verification rake, tests, completion note, roadmap update |

---

## Resolved decisions

| Decision | v0.04-7 decision |
| -------- | ---------------- |
| Hold auto-allocation | Yes; partial allowed |
| Default hold expiry | 14 days when not supplied |
| Over-availability override | Yes; `demand.allocations.override_availability` + reason + audit |
| Inbound PO allocation | Yes; manual only; existing open PO lines |
| Cache on `demand_lines` | No |
| Availability cache | Yes; legacy on-hand reservations + v0.04 `on_hand` allocations |
| Legacy reservation writes | No v0.04 writes; read in rebuild |
| POS pickup | `DemandAllocations::Fulfill` + optional reference; no POS schema replacement |
| Expiry scheduler | Service + job + rake required; production scheduler optional |
| End-to-end receipt conversion | Deferred to v0.04-9 |

---

## Definition of done

1. Migration for `demand_allocations` runs cleanly.
2. `DemandAllocation` model, validations, and enums implemented.
3. Demand line statuses extended: `partially_allocated`, `allocated`, `fulfilled`; terminal set updated.
4. Allocation services implemented: on-hand, inbound PO, release, cancel, expire, fulfill.
5. `DemandLines::RecalculateAllocationStatus` implemented and invoked on every allocation mutation.
6. **`Inventory::RebuildAvailabilityCache`** includes active v0.04 `on_hand` allocations and legacy on-hand reservations.
7. Hold from item drawer: default `expires_at` 14 days; partial on-hand allocation when stock available; clear staff messaging.
8. Notify remains unallocated on create; filterable on `/demand`.
9. Used wanted: manual on-hand used-like only; no inbound PO auto-path.
10. Manual TBO / buyer replenishment: no auto-allocate on create; `/demand` only.
11. Inbound PO allocation references existing lines; does not alter PO quantities/status; subtracts legacy PO allocation claims.
12. `DemandLines::Cancel` and manual `Expire` cascade to active allocations first.
13. `DemandLines::ExpireDue` + job + rake implemented; no `Inventory::Post`.
14. Over-availability override requires permission, reason, audit.
15. No v0.04 service writes legacy reservation or PO/receipt allocation rows.
16. Allocation summary on `/demand/:id`; customer show and index filters; item availability shows v0.04 vs legacy reserved breakdown.
17. Permissions seeded and enforced.
18. Tests per [test-plan.md](test-plan.md); verify rake passes `STRICT=1`.
19. [v0.04-7 completion](../../implementation/v0.04-7-completion.md) written; roadmap priority → v0.04-8.

**Softened milestone outcome:** Traceable **demand → allocation → fulfillment reference** in v0.04-7. Full **demand → PO → receipt → pickup** conversion belongs to v0.04-9+.

---

## Next milestone

**v0.04-8 — Sourcing and vendor responses.** **v0.04-3 — Product groups** remains deferred.
