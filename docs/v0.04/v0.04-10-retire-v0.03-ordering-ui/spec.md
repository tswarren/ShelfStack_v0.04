# v0.04-10 Retire v0.03 Ordering UI and Reports — Functional Specification

## Status

**Planned** — scoping complete. Depends on [v0.04-9 completion](../../implementation/v0.04-9-completion.md) (merged).

Companion documents: [data-model.md](data-model.md), [test-plan.md](test-plan.md).

---

## Job

**Retirement / cutover milestone** — not a new domain-model milestone.

Make staff workflows, reports, POS pickup, and schema agree with the v0.04 operational chain:

```text
demand_lines
  → demand_allocations
  → sourcing
  → PO / receiving
  → inventory posting
  → fulfillment / POS pickup
```

v0.04-6 through v0.04-9 already cut over **new writes** to `demand_lines`, `demand_allocations`, sourcing, and v0.04 receipt conversion. v0.04-10 removes legacy **routes, UI, reports, POS reservation bridge, presenters**, and (after quarantine) **deprecated tables**.

### Milestone boundary (non-negotiable)

v0.04-10 **must not** become:

* a broad UI redesign
* a new purchasing automation milestone
* a catalog / `catalog_items` cleanup milestone (v0.04-11)
* compensating demand on return/refund (later)

---

## Roadmap definition of done

From [delivery roadmap](../../roadmap/v0.04-delivery-roadmap.md):

1. **No staff-facing routes** depend on `customer_requests`, `special_orders`, or `purchase_requests`.
2. **Report parity** for store reconciliation on the demand model.

Extended (this spec):

3. **POS demand pickup** completes the end-to-end fulfillment bridge when `inventory_reservations` are removed.
4. **No staff workflow writes** to legacy ordering tables before destructive drop (see [No legacy write gate](#no-legacy-write-gate)).
5. **`Receiving::AllocateCustomerDemandFromReceipt`** removed from active receipt post path after G2.

`inventory_reservations` removal is **conditional**: drop only if POS demand pickup is fully migrated and no remaining staff/system path requires `inventory_reservation_id`. See [Hard gate: inventory_reservations](#hard-gate-inventory_reservations).

---

## Data strategy

ShelfStack is **pre-production**. Prefer **reseed** over row-level migration.

| Decision | v0.04-10 answer |
| -------- | --------------- |
| Historical legacy rows | **Not preserved** across cutover — reseed dev/test/demo after G2 |
| Legacy show URL mapping | **No fake mapping** — redirects to `/demand` or 404; do not pretend legacy IDs map to demand rows after reseed |
| Destructive schema | **G2 only**, after quarantine verifier passes |

Document reseed command in completion note (`db:seed` + verifier suite).

---

## Implementation slices (delivery order)

```text
0 → C → A → B → D → E → F → G1 → G2
```

POS pickup (Slice C) runs **before** full queue/dashboard work so queue semantics can use true pickup-ready / fulfilled state.

| Slice | Name | Purpose |
| ----- | ---- | ------- |
| **0** | Preflight / spec | Audit, permissions map, verifier skeleton, acceptance scenarios |
| **C** | POS demand pickup | Critical fulfillment bridge |
| **A** | Demand operational queues | Replace customer-request dashboard / nav |
| **B** | Orders / TBO retirement | Remove purchase-request hub and item TBO entry points |
| **D** | PO / receipt projection cleanup | v0.04 allocation projections; remove legacy receipt allocator |
| **E** | Reports | Demand queue report replaces customer request queue |
| **F** | Captured demand match flows | Replace legacy customer-request match context |
| **G1** | Legacy quarantine | Routes removed or redirected; code frozen; tables may remain |
| **G2** | Destructive drop | FK removal, table drop, service deletion, verifier requires absence |

Each slice leaves the app runnable and tested before the next begins.

---

### Slice 0 — Preflight

* Grep audit: routes, nav, reports, POS, receipt post, seeds referencing legacy tables
* Permission mapping table (see [Permissions](#permissions))
* `shelfstack:v00410:verify_legacy_ordering_retired` skeleton (phased checks per G1/G2)
* Confirm reseed strategy with team

### Slice C — POS demand pickup (first operational bridge)

**Schema**

* `pos_transaction_lines.demand_allocation_id` (FK → `demand_allocations`, optional, indexed)

**Services**

* `Pos::DemandPickupLookup` — search ready pickup rows by customer / demand number
* `Pos::AddDemandAllocationLine` — add draft line linked to allocation
* Wire transaction **complete** → `DemandAllocations::Fulfill` with `fulfillment_reference:` POS transaction or line
* Wire **void before completion** → remove pending line; allocation stays active
* Retire staff use of `Pos::CustomerPickupLookup`, `Pos::AddReservationLine`, `CompleteReservationFulfillment` for new flows (remove in G1/G2)

**POS fulfillment semantics (normative)**

```text
Pickup line add:
  - pos_transaction_line.demand_allocation_id set
  - product_variant_id from allocation
  - normal POS sale line pricing/tax/discount rules apply

Transaction complete:
  - Inventory posts via existing Pos::CompleteTransaction / Inventory::Post (sold movement)
  - DemandAllocations::Fulfill marks allocation fulfilled
  - fulfillment_reference_type/id → PosTransaction or PosTransactionLine
  - DemandLines::RecalculateAllocationStatus updates demand line
  - NO separate inventory movement from Fulfill (allocation is not Inventory::Post)

Void before completion:
  - Remove draft line; demand_allocation remains active

Void / refund after completion:
  - OUT OF SCOPE v0.04-10 (compensating demand / reopen allocation deferred)
  - Return transaction uses existing customer_return inventory path only
```

**UI**

* Pickup panel: “Demand number” (not “Request number”); results from demand allocations
* `/pickup` command uses new lookup

**Tests**

* On-hand allocate → POS pickup → complete → demand `fulfilled`, allocation `fulfilled`, inventory sold
* Void draft transaction before complete → allocation still active

### Slice A — Demand operational queues

Replace `CustomerRequests::QueueScope` / `Customers::DashboardPresenter` legacy queues with **`DemandLines::QueueScope`**.

**Customers workspace**

* Dashboard queue cards → demand queues (paths under `/demand?queue=…`)
* Remove **Customer requests** nav tab; link **Demand** / filtered queues
* Remove **New request** where **New demand** exists
* Reuse Phase 10-D metric strip / filter patterns where helpful

**`/demand` index**

* Support `queue` param mapping to scoped filters (see [Operational queues](#operational-queues-normative))

Queues are defined **after** Slice C so `ready_for_pickup` reflects real fulfillable allocations.

### Slice B — Orders / TBO retirement

* Remove `purchase_requests` routes, controller, views
* Remove `from_tbo` / `create_from_tbo` PO collection routes
* Orders home: drop TBO cards; link to `/demand?capture_intent=manual_tbo` and `/sourcing`
* Item selling tab: remove **Mark TBO**
* Item drawer / header: remove **TBO**, **Order**, legacy activity block, variant-scoped legacy request/TBO lines
* `manual_tbo` / buyer replenishment: `/demand` → sourcing (no `purchase_requests` row)

### Slice D — PO / receipt legacy projection cleanup

* Rewrite `Orders::ReceiptShowPresenter` — project v0.04 `demand_allocations` (inbound / converted / on_hand), not `receipt_line_allocations`
* Rewrite `Purchasing::PurchaseOrderLineDemandBreakdown` — demand allocation rows + links to `/demand/:id`
* PO show: remove purchase-request document hub section
* **`Purchasing::PostReceipt`:** remove `Receiving::AllocateCustomerDemandFromReceipt` call (G1 freeze writes; G2 remove service)
* Remove mixed legacy/v0.04 claim guard once legacy allocation tables dropped (G2)
* Update `DemandAllocations::InboundAvailability` to stop subtracting legacy PO line allocations (G2)

Deferred from v0.04-9 and **in scope** here: full receipt show v0.04 projection.

### Slice E — Reports

* Replace `Reports::CustomerRequests` with **`Reports::DemandQueue`** (same queue keys as Slice A)
* Update `Reports::Registry`; permission `demand.access` or new `demand.reports.queue`
* Item links: `/items/item?product_variant_id=:id&tab=overview` per [Phase 9 drill-down contract](../../handoff/phase-9-item-drill-down-contract.md)
* Redirect `/reports/customer_requests` → new report (see [Route redirect policy](#route-redirect-policy))
* Purchasing Summary: optional inbound-demand metric — **non-blocking**

### Slice F — Captured demand match flows

Replace legacy **`Customers::RequestMatchContext`** with **`DemandLines::MatchContext`** (or equivalent):

* Add Item / external lookup / index match banner → `captured` demand line
* Match variant → `DemandLines::MatchVariant` → redirect `/demand/:id`
* Remove links to `customers_customer_request_path` from item index and wizard

### Slice G1 — Legacy quarantine

**Remove or redirect staff-facing legacy surfaces** (tables may still exist):

* All routes in [Route redirect policy](#route-redirect-policy)
* Legacy nav links and controllers unreachable from staff UI
* Freeze legacy models: no new staff-path writes (verifier enforced)
* POS: no new `inventory_reservation_id` lines from staff UI
* Receipt post: no new `receipt_line_allocations` (stop calling legacy allocator)
* PO paths: no new `purchase_order_line_allocations`
* Delete **obviously dead** code (e.g. unrouted `Items::CustomerDemandActionsController`) when grep-clean

**Do not** drop tables in G1.

Verifier phase **G1**: staff-facing independence from legacy tables; legacy write gate passes.

### Slice G2 — Destructive drop

Only after G1 verifier **STRICT** passes:

1. Remove FKs (`pos_transaction_lines.inventory_reservation_id`, allocation FKs on legacy tables, etc.)
2. Drop tables: `customer_requests`, `customer_request_lines`, `special_orders`, `purchase_requests`, `purchase_request_lines`, `inventory_reservations`, `purchase_order_line_allocations`, `receipt_line_allocations`
3. Delete legacy models, controllers, services, views, tests (see [Service deletion sequencing](#service-deletion-sequencing))
4. `Inventory::RebuildAvailabilityCache` — v0.04 on-hand allocations only
5. Reseed + full verifier suite

Verifier phase **G2**: legacy tables **absent**; no code references in `app/`.

---

## Route redirect policy

Pre-production reseed: prefer **clear removal** over ID mapping.

| Legacy route | v0.04-10 behavior |
| ------------ | ----------------- |
| `/customers/customer_requests` | **302** → `/demand` |
| `/customers/customer_requests/:id` | **302** → `/demand` (no ID map) or **404** after G2 |
| `/orders/purchase_requests` | **302** → `/demand?capture_intent=manual_tbo` |
| `/orders/purchase_requests/:id` | **302** → `/demand?capture_intent=manual_tbo` |
| `/orders/purchase_orders/from_tbo` | **302** → `/sourcing` or `/orders` |
| `/reports/customer_requests` | **302** → `/reports/demand_queue` (new path) |
| `/reports/shells/queue` | Already redirects; retarget to demand queue report |

Staff nav must not link to legacy paths after G1.

---

## Operational queues (normative)

Implemented in `DemandLines::QueueScope`. Each queue is a **filter composition** over demand line + allocation + sourcing state.

**Shared terms**

* **Terminal demand:** `status` ∈ `fulfilled`, `canceled`, `expired`
* **Active allocation:** `demand_allocations.status` = `active`
* **Expired allocation:** `expires_at` present and `expires_at < now`

### `ready_for_pickup`

```text
active on_hand demand_allocation
AND demand_line.status NOT terminal
AND allocation NOT expired
AND product_variant_id present
AND quantity_allocated > 0
```

Staff action: POS pickup (Slice C).

### `expiring_holds`

Same as `ready_for_pickup`, plus:

```text
allocation.expires_at <= now + EXPIRING_HOLD_WINDOW (default 3 days)
```

### `notify_customer`

**Stock-arrived, customer not yet fulfilled** — not intent-only notify rows with zero allocation.

```text
demand_line.capture_intent = notify
AND demand_line.status IN (open, partially_allocated, allocated)
AND EXISTS active on_hand allocation
AND NOT EXISTS fulfilled covering full requested quantity
```

Optional staff action: contact customer (out of scope for automation); queue is operational visibility.

### `needs_research`

```text
demand_line.status = captured
(unmatched variant — research / match flow)
```

### `awaiting_response`

Buyer or vendor response pending on linked sourcing:

```text
demand_line.status IN (open, partially_allocated, allocated)
AND (
  EXISTS sourcing_run for demand_line WHERE status IN (needs_review, awaiting_vendor, active)
  OR EXISTS sourcing_attempt WHERE buyer_review_required = true AND status NOT IN (canceled, cascaded, completed)
)
AND NOT ready_for_pickup
```

Does **not** include terminal failed demand without active sourcing (those surface in demand show / sourcing run).

### `approved_to_order`

Special-order intent awaiting vendor attempt or PO linkage:

```text
demand_line.capture_intent = special_order
AND demand_line.status IN (open, partially_allocated)
AND NOT EXISTS active inbound_purchase_order allocation
AND NOT EXISTS active vendor_backorder allocation covering remaining qty
AND (no active sourcing_attempt OR latest attempt awaiting submit)
```

Narrow queue: “approved to source/order,” not all special-order demand.

### `on_order`

Inbound PO supply claimed for demand:

```text
EXISTS active inbound_purchase_order demand_allocation for demand_line
```

### `vendor_backorder`

Separate queue (not folded into `on_order`):

```text
EXISTS active vendor_backorder demand_allocation for demand_line
```

Operational visibility only — no receipt conversion (v0.04-9 excluded `vendor_backorder` from convert path).

### Terminal / archive queues (lower priority)

* `completed` → `demand_line.status = fulfilled`
* `cancelled` → `demand_line.status = canceled`
* `expired` → `demand_line.status = expired`

Report and dashboard **OPERATIONAL_QUEUE_KEYS** (minimum):

```text
ready_for_pickup
expiring_holds
notify_customer
needs_research
awaiting_response
approved_to_order
on_order
vendor_backorder
```

---

## Hard gate: `inventory_reservations`

Do **not** drop `inventory_reservations` until **all** are true:

1. `pos_transaction_lines.demand_allocation_id` exists and is used by staff POS pickup
2. Demand pickup lookup returns fulfillable on_hand allocations
3. Transaction complete calls `DemandAllocations::Fulfill` with fulfillment reference
4. Void-before-completion tested; allocation remains active
5. No staff POS code path requires `inventory_reservation_id` for new pickup flows
6. G1 verifier: no staff writes to `inventory_reservations`

If any check fails, G2 drops ordering tables but **may retain** `inventory_reservations` read-only until a follow-up slice — document exception in completion note.

---

## No legacy write gate

Before G2 table drop, verifier **G1** enforces:

```text
Legacy tables MAY exist, but:
- no staff-facing route writes customer_requests / special_orders / purchase_requests
- no staff workflow service writes legacy allocation tables
- no POS staff path creates inventory_reservations
- Purchasing::PostReceipt does not call Receiving::AllocateCustomerDemandFromReceipt
- no PO submit/receive path creates purchase_order_line_allocations
```

G2 is **cleanup**, not behavior change.

---

## Service deletion sequencing

Do **not** bulk-delete `CustomerRequests::*` (21 services) at start of G.

Delete when grep audit shows **zero** `app/` references:

```text
1. Routes + controllers removed (G1)
2. Reports migrated (E)
3. POS migrated (C)
4. PO/receipt presenters migrated (D)
5. Match flows migrated (F)
6. Tests deleted or rewritten
7. G2 table drop
8. Remove service directories per family
```

Same pattern for `InventoryReservations::*`, `Receiving::AllocateCustomerDemandFromReceipt`, `PurchaseRequests::*`.

---

## Permissions

| Legacy keys | v0.04-10 handling |
| ----------- | ----------------- |
| `customer_requests.*` | Remove from seeds; map roles to `demand.*` |
| `inventory_reservations.*` | Remove; covered by `demand.allocations.*` |
| `special_orders.create` | Remove; `demand.create` + sourcing permissions |
| `orders.purchase_requests.*` | Remove |

Add if needed:

```text
demand.reports.queue   # demand queue report access
```

Re-run role seed / document manual role updates in test plan.

---

## Legacy replacement reference

| Legacy | Replacement | Retire in |
| ------ | ----------- | --------- |
| `customer_requests` / lines | `demand_lines` | G2 |
| `special_orders` | demand `capture_intent` + sourcing | G2 |
| `purchase_requests` | `manual_tbo` demand / stock considerations | G2 |
| `inventory_reservations` | `demand_allocations` (`on_hand`) | G2 if POS gate passes |
| `purchase_order_line_allocations` | `demand_allocations` (`inbound_purchase_order`) | G2 |
| `receipt_line_allocations` | inbound → on_hand conversion (v0.04-9) | G2 |

---

## Hard gates preserved

* `Inventory::Post` remains sole inventory mutation path
* PO/receipt posting rules from v0.04-9 unchanged except **removal** of legacy allocator
* Buyback, POS tax/discount/tender, stored value unchanged
* No new PO auto-create from demand

---

## Verification

### Rake tasks

```bash
STRICT=1 bin/rails shelfstack:v0046:verify_demand_foundation
STRICT=1 bin/rails shelfstack:v0047:verify_allocations
STRICT=1 bin/rails shelfstack:v0048:verify_sourcing
STRICT=1 bin/rails shelfstack:v0049:verify_po_receiving
STRICT=1 bin/rails shelfstack:v00410:verify_legacy_ordering_retired   # G1 + G2 phases
```

### v00410 checks (draft)

**G1**

* No routes matching `customer_requests`, `purchase_requests`, `from_tbo` (except redirects)
* No `CustomerRequest` / `PurchaseRequest` references in `app/controllers` or `app/views`
* POS pickup uses `demand_allocation_id`
* PostReceipt does not call legacy receipt allocator
* Legacy write gate (static + optional runtime probe)

**G2**

* Legacy tables absent from `schema.rb`
* No legacy model files under `app/models`
* `InboundAvailability` does not reference `purchase_order_line_allocations`

See [test-plan.md](test-plan.md) for acceptance scenarios.

---

## Explicitly out of scope

| Item | Target |
| ---- | ------ |
| `catalog_items` removal / bibliographic admin | v0.04-11 |
| Phase 10-E consistency sweep | v0.04-11 |
| Product groups (v0.04-3) | Deferred |
| `vendor_backorder` → inbound conversion | Follow-up |
| Compensating demand / reopen allocation on return-refund | Later |
| Manual PO vendor quantity edit UI | Optional follow-up |
| AP invoice reconciliation | Future |
| Broad customers workspace redesign beyond queue cutover | Avoid |

---

## Definition of done

| # | Criterion |
| - | --------- |
| 1 | Slice C POS pickup: on-hand demand → POS complete → allocation fulfilled |
| 2 | Slice A: customers dashboard uses demand queues; no customer_requests nav |
| 3 | Slice B: no purchase_request or from_tbo staff entry points |
| 4 | Slice D: receipt/PO show project demand allocations; legacy allocator removed |
| 5 | Slice E: demand queue report; customer request report redirected |
| 6 | Slice F: captured demand match replaces request match context |
| 7 | G1 verifier STRICT passes (quarantine) |
| 8 | G2 verifier STRICT passes (tables dropped, reseed documented) |
| 9 | Acceptance scenarios in test plan pass |
| 10 | Completion note; roadmap advances to v0.04-11 |

---

## Next milestone

**v0.04-11** — documentation and schema cleanup (`domain-model.md`, `schema-reference.md`, Phase 10-E).
