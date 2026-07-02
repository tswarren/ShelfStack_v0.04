# v0.04-9 PO and Receiving Quantity Model — Functional Specification

## Status

**Planned** — depends on [v0.04-8 completion](../../implementation/v0.04-8-completion.md) (merged).

Companion documents: [data-model.md](data-model.md), [test-plan.md](test-plan.md).

---

## Implementation slices

v0.04-9 is delivered in four implementation slices. Each slice should leave the app runnable and tested before the next begins.

### Slice A — PO line quantity lifecycle (schema + math)

* Migration: vendor-confirmed quantity columns on `purchase_order_lines`; optional receipt-line breakdown fields
* Backfill from existing `quantity_ordered` / `quantity_received` semantics
* `Purchasing::PoLineQuantitySummary` (or equivalent) — authoritative open/confirmed/inbound math
* Update `DemandAllocations::InboundAvailability` to use v0.04-9 open inbound quantity (not legacy `quantity_ordered - quantity_received` alone when vendor-confirmed qty is present)
* Bridge hook: when v0.04-8 sourcing confirms against a linked PO line, sync PO line vendor-confirmed quantities (no new sourcing behavior in v0.04-9 beyond sync)
* PO/line status derivation service aligned with [roadmap lifecycle vocabulary](../../roadmap/v0.04-delivery-roadmap.md#lifecycle-vocabulary-state-machines)
* Verifier skeleton (`shelfstack:v0049:verify_po_receiving`)
* Model and service tests for slice A

### Slice B — Receipt → demand allocation conversion (v0.04 path)

* `DemandAllocations::ConvertInboundFromReceipt` — FIFO convert active `inbound_purchase_order` allocations to `on_hand` for accepted receipt quantity on a PO-backed line
* Integrate into `Purchasing::PostReceipt` **after** inventory post, **before** or alongside legacy customer-demand receipt allocation (legacy path must remain untouched for v0.03 rows)
* Partial receipt: convert up to accepted qty across active inbound allocations on that PO line
* Audit events for conversion rows
* No writes to `receipt_line_allocations` or `purchase_order_line_allocations`
* Service tests + PostReceipt integration tests (v0.04 demand only)

### Slice C — Short, reject, and release paths

* `DemandAllocations::ReleaseInboundForReceiptVariance` (name TBD) — release active inbound allocation quantity when receipt is short/rejected vs expectation tied to demand
* Update `Purchasing::UpdatePoLineQuantities` (or successor) to use v0.04-9 quantity fields and accepted-vs-received distinction consistently
* Receipt line exception breakdown UI (expected / received / accepted / rejected / short) on bounded PO/receipt screens
* PO line show: vendor-requested vs confirmed vs backordered vs received vs open
* Demand detail: inbound allocation state after receipt post (converted vs still waiting)

### Slice D — Operational snapshot, verification, docs

* `Purchasing::InboundAvailabilitySnapshot` (or extend existing presenter/hub) for staff-facing “what is actually inbound” reads on demand/PO/receipt surfaces
* STRICT verifier checks (no legacy allocation writes, accepted-only inventory post preserved)
* Permissions audit (reuse existing `orders.*` / `demand.allocations.*` where sufficient; add keys only if missing)
* Completion note; roadmap advance to v0.04-10

---

## Job

Close the v0.04 demand pipeline loop:

```text
Demand
  → Allocation (on_hand / inbound_purchase_order / vendor_backorder)
    → Sourcing (v0.04-8)
      → PO line (vendor-confirmed quantities)
        → Receipt (expected / received / accepted / rejected)
          → Demand allocation conversion (inbound → on_hand)
            → Fulfillment / pickup (v0.04-7 Fulfill bridge)
```

v0.04-6 created demand lines.

v0.04-7 created demand allocations and manual inbound PO claims against **existing** open PO lines using legacy open-qty math.

v0.04-8 modeled vendor responses and inbound / vendor_backorder allocations without changing PO or receipt posting.

v0.04-9 makes **PO line and receipt line quantity lifecycle explicit** and wires **receipt posting to v0.04 demand allocations**.

---

## Purpose

v0.04-9 answers:

* How much did we request from the vendor on this PO line?
* How much did the vendor confirm, backorder, cancel, or cascade?
* How much is still open to receive against confirmed supply?
* What arrived on the dock vs what was accepted to stock?
* Which demand inbound allocations convert to on-hand when stock is accepted?
* What happens to demand when a receipt is short or rejected?
* What is operationally “inbound” for allocation and staff UI?

---

## Core rules

### Inventory posting unchanged in principle

```text
Only receipt line quantity_accepted posts to inventory via Inventory::Post inside Purchasing::PostReceipt.

Demand allocation conversion does not call Inventory::Post.
```

| Layer | Affects `quantity_on_hand` | Affects `quantity_reserved` / `quantity_available` |
| ----- | -------------------------- | -------------------------------------------------- |
| PO vendor quantity fields | No | No |
| Receipt expected/received/rejected fields | No | No |
| Receipt accepted qty | **Yes** (via `Inventory::Post`) | Indirectly after inbound→on_hand conversion rebuilds cache |
| `inbound_purchase_order` allocation | No | No |
| Convert inbound → `on_hand` allocation | No (directly) | **Yes** (via cache rebuild) |

### Vendor response ≠ receipt ≠ invoice

Preserve v0.04-8 separation:

* **Vendor response** (sourcing) records what the vendor said they would ship.
* **Receipt** records what arrived and what was accepted.
* **Invoice/AP** remains out of scope (cost snapshots on receipt lines only).

A vendor-confirmed quantity may still arrive short, damaged, wrong, or substituted.

---

## Source documents

```text
AGENTS.md
docs/design/VERSION_0.04.md (§10 Purchase Orders, §11 Receiving)
docs/roadmap/v0.04-delivery-roadmap.md
docs/v0.04/v0.04-7-allocations-and-reservations/spec.md
docs/v0.04/v0.04-8-sourcing-and-vendor-responses/spec.md
docs/implementation/v0.04-7-completion.md
docs/implementation/v0.04-8-completion.md
```

---

## Hard gates

1. **No change to inventory posting gate.** `Purchasing::PostReceipt` posts only `quantity_accepted > 0` lines via `Inventory::Post`.
2. **No legacy allocation writes.** v0.04-9 services must not create or update `purchase_order_line_allocations` or `receipt_line_allocations`.
3. **No legacy customer-request / special-order / TBO expansion.** v0.04 demand remains source of truth; legacy receipt allocation path stays for unmigrated rows only.
4. **No AP invoice workflow.** Optional receipt cost snapshot fields only; no invoice matching or GL export.
5. **No automatic PO header/line creation from demand** in v0.04-9 baseline (same as v0.04-8). Staff may continue manual PO workflows; optional “create PO line from demand” is deferred unless explicitly added in a later slice.
6. **No POS schema replacement.** Pickup continues via v0.04-7 fulfill bridge; `pos_transaction_lines.demand_allocation_id` remains optional/deferred unless cheaply added.
7. **No retiring v0.03 ordering UI.** That belongs to v0.04-10.
8. **Product variant remains operational grain** for PO lines, receipt lines, allocations, and inventory post.
9. **Moving average cost** updates only on accepted receipt quantity (preserve Phase 5 behavior).
10. **RTV posting behavior preserved.**
11. **Destructive schema changes allowed** (pre-production): prefer additive columns + backfill over long-lived dual-write shims.
12. **FIFO for inbound allocation conversion** on partial receipts unless spec later adds override — match v0.04-7 legacy FIFO intent for customer allocations.

---

## Settled decisions (planning)

| Decision | v0.04-9 answer |
| -------- | -------------- |
| Rename `quantity_ordered`? | **Keep column name**; treat as staff-requested / store-requested qty; document mapping to design-doc `quantity_requested` |
| Add vendor-confirmed PO columns? | **Yes** — see [data-model.md](data-model.md) |
| Open inbound for allocations | **Confirmed-not-received** when vendor-confirmed qty > 0; else fall back to current open-qty helper until backfill complete |
| Receipt posts convert v0.04 inbound allocations? | **Yes** — new service; legacy path unchanged |
| Short receipt releases inbound allocations? | **Yes** — release active inbound qty tied to unreceived expectation |
| `vendor_backorder` → inbound on ship confirm? | **Deferred** — record-only in v0.04-8; conversion rules belong in v0.04-9+ follow-up or slice C only if cheap |
| Substituted receipt lines | **Operational record + release/requeue**; no substitute catalog workflow |
| New demand-line status for receiving? | **No** — use allocation status + demand recalc |
| Availability snapshot service | **Yes** — read model for staff UI; not a cached balance table in v0.04-9 |

---

## Legacy posture

| Legacy / existing concept | v0.04-9 behavior |
| ------------------------- | ---------------- |
| `purchase_order_line_allocations` | Read for inbound math until retired; **no writes** from v0.04-9 services |
| `receipt_line_allocations` | Legacy path in `Receiving::AllocateCustomerDemandFromReceipt` **unchanged** for v0.03 customer-request chains |
| `inventory_reservations` incoming | Legacy convert path **unchanged**; v0.04 demand uses allocation conversion |
| `quantity_ordered` / `quantity_received` on PO lines | Retained; vendor columns added; receiving updates use v0.04-9 summary rules |
| Phase 5 `Purchasing::PostReceipt` | Extend, do not fork — add v0.04 conversion step inside existing transaction |

---

## Reuse (existing services)

| Existing | v0.04-9 use |
| -------- | ----------- |
| `Purchasing::PostReceipt` | Hook demand allocation conversion after inventory post |
| `Purchasing::UpdatePoLineQuantities` | Extend for v0.04-9 PO line fields and accepted-vs-received semantics |
| `DemandAllocations::InboundAvailability` | Update open-qty formula |
| `DemandAllocations::AllocateInboundPurchaseOrder` | Unchanged create path; eligibility uses updated inbound math |
| `DemandAllocations::Release` / `Cancel` | Patterns for short/release paths |
| `DemandLines::RecalculateAllocationStatus` | After conversion and release |
| `Inventory::RebuildAvailabilityCache` | After inbound→on_hand conversion |
| `Sourcing::RecordVendorResponse` | Optional sync target for PO line vendor-confirmed columns when PO line linked |

---

## PO line quantity model

Authoritative vocabulary aligns with [VERSION_0.04.md §10](../../design/VERSION_0.04.md#10-purchase-orders) and [roadmap lifecycle](../../roadmap/v0.04-delivery-roadmap.md#purchase_order_lines-quantity--header-status).

### Staff-requested vs vendor-confirmed

```text
quantity_ordered              -- store requested qty at PO submit (existing column)
quantity_confirmed_by_vendor  -- vendor acknowledged shippable qty (new)
quantity_backordered_by_vendor
quantity_canceled_by_vendor
quantity_cascaded             -- qty moved to another source/attempt (new)
```

Invariant (per line, after vendor confirmation recorded):

```text
quantity_confirmed_by_vendor
  + quantity_backordered_by_vendor
  + quantity_canceled_by_vendor
  + quantity_cascaded
  <= quantity_ordered
```

Until vendor confirmation is recorded, operational UI may show requested-only state.

### Receiving vs acceptance on PO line

Existing `quantity_received` on PO lines currently accumulates **accepted** qty from posted receipts. v0.04-9 clarifies semantics:

```text
quantity_received_on_po_line  -- cumulative accepted-to-stock from posted receipts (keep quantity_received column; document)
quantity_rejected_on_po_line  -- cumulative rejected at receipt (new, optional slice A/C)
quantity_closed_short         -- explicit close-short qty when PO line closed without full receipt (new)
```

Open receive qty for receiving documents:

```text
open_to_receive =
  effective_confirmed_qty - quantity_received
  where effective_confirmed_qty =
    quantity_confirmed_by_vendor if > 0 else quantity_ordered
```

Open inbound for **demand allocation** claims:

```text
open_for_inbound_allocation =
  effective_inbound_supply
  - legacy_po_line_allocation_claims
  - v0047_inbound_demand_allocation_claims

effective_inbound_supply =
  max(effective_confirmed_qty - quantity_received, 0)
```

### PO line / header status

Line status derivation must consider vendor confirmation and receiving progress, not ordered-vs-received alone.

Normative line statuses (existing enum retained; derivation updated):

```text
open
partially_received
received
backordered
cancelled
closed_short
closed
```

Header status remains derived from line rollup (existing pattern in `Purchasing::UpdatePoLineQuantities` / close PO services).

---

## Receipt line quantity model

Align with [VERSION_0.04.md §11](../../design/VERSION_0.04.md#11-receiving) and roadmap `receipt_lines` lifecycle.

Existing columns:

```text
quantity_expected   -- from PO open qty or manual entry
quantity_received   -- physically counted on receipt draft
quantity_accepted   -- accepted to stock (posts inventory)
quantity_rejected   -- rejected at receipt
```

v0.04-9 additions (optional but recommended):

```text
receipt_line_status or derived status method
quantity_damaged
quantity_wrong_item
quantity_substituted
quantity_closed_short
unit_cost_cents snapshot fields (already partially present)
```

Validation rules:

```text
quantity_accepted + quantity_rejected <= quantity_received (when received is authoritative)
quantity_received may differ from quantity_expected → ReceivingDiscrepancy (existing)
Only quantity_accepted > 0 posts inventory
Fully rejected lines may still post receipt with zero inventory lines (existing guard: at least one accepted line required today — preserve unless spec explicitly allows zero-accept post for audit-only receipts in a later slice)
```

---

## Demand allocation conversion on receipt post

When `Purchasing::PostReceipt` posts a PO-backed receipt line with `quantity_accepted = N`:

1. Inventory post `N` units (unchanged).
2. Find active `demand_allocations` with `kind = inbound_purchase_order` and matching `purchase_order_line_id`, ordered FIFO by `allocated_at`.
3. For each allocation, convert up to remaining `N`:
   * Release or fulfill inbound portion (prefer explicit `DemandAllocations::ConvertInboundToOnHand` that creates new `on_hand` row + releases inbound row, or atomic kind transition with audit — pick one pattern in implementation; must be auditable).
4. Rebuild availability cache for affected variants.
5. `DemandLines::RecalculateAllocationStatus` for affected demand lines.
6. Do **not** write legacy receipt line allocation rows for v0.04 demand.

Partial conversion example:

```text
Demand A: inbound alloc 2 on PO line
Demand B: inbound alloc 1 on PO line
Receipt accepted qty 2
→ FIFO: Demand A fully converted to on_hand (2), Demand B unchanged
```

---

## Short / reject / close-short effects on demand

When receipt variance or PO close-short reduces effective inbound supply:

* Release active `inbound_purchase_order` allocation quantity that can no longer be covered (FIFO).
* `vendor_backorder` allocations: **do not auto-release** in slice B unless explicitly covered in slice C — document behavior (likely remain active until buyer review).
* Demand line returns toward `open` / `partially_allocated` via recalc.
* Audit event records release reason (`receipt_short`, `receipt_rejected`, `po_closed_short`).

---

## Sourcing ↔ PO line sync (bridge)

When a final v0.04-8 vendor response confirms quantity against a linked `purchase_order_line_id`:

* v0.04-9 may update PO line `quantity_confirmed_by_vendor` (and backorder/cancel buckets if present in response) via a dedicated sync service called from `Sourcing::RecordVendorResponse` **or** a post-response job — must be idempotent and must not double-count across multiple responses.
* Inbound demand allocations created in v0.04-8 remain authoritative claims; PO line columns are operational/supply visibility.

Do not collapse sourcing attempts into PO submit — PO lines may exist before sourcing responses.

---

## UI scope (bounded)

v0.04-9 extends existing Phase 5 / 10-D bounded surfaces; no full procurement redesign.

| Surface | v0.04-9 addition |
| ------- | ---------------- |
| PO line show / hub | Vendor-confirmed vs requested vs received vs open columns |
| Receipt draft/post | Expected/received/accepted/rejected breakdown; link to demand conversion preview where cheap |
| `/demand/:id` | Inbound allocation status after receipt; “waiting on receive” vs “ready on hand” |
| Item variant ops PO lines table | Use updated open inbound math |
| Reports | No full report rewrite (v0.04-10) |

Defer full stock-consideration domain UI.

---

## Permissions and audit

Prefer reuse:

```text
orders.receipts.post
orders.purchase_orders.*
demand.allocations.*
```

New permission keys only if a new staff-facing mutation lacks coverage.

Audit events (minimum):

```text
purchase_order_line.vendor_quantities_updated
receipt.posted                           (existing — extend details with v0.04 conversion counts)
demand_allocation.converted_inbound_to_on_hand
demand_allocation.released_inbound
```

---

## Verification (STRICT)

Rake task `shelfstack:v0049:verify_po_receiving` checks:

* Required columns present
* Core services exist
* v0.04-9 services do not reference `Inventory::Post` except via existing PostReceipt path
* v0.04-9 services do not write legacy allocation tables
* Inbound availability uses v0.04-9 open formula on sample rows
* PostReceipt integration test fixture: inbound allocation converts on post

Run alongside:

```bash
STRICT=1 bin/rails shelfstack:v0047:verify_allocations
STRICT=1 bin/rails shelfstack:v0048:verify_sourcing
```

---

## Definition of done

1. PO lines expose vendor-confirmed quantity lifecycle fields with backfill and validations.
2. `DemandAllocations::InboundAvailability` uses v0.04-9 open inbound supply.
3. Posted receipts convert v0.04 inbound allocations to on-hand for accepted quantity (FIFO).
4. Short/reject/close-short paths release uncovered inbound demand allocations.
5. PO and receipt bounded UI show quantity breakdown staff need for reconciliation.
6. Legacy customer-request receipt allocation path still works unchanged for legacy rows.
7. No v0.04-9 service writes legacy allocation tables.
8. Tests per [test-plan.md](test-plan.md); `STRICT=1` v0049 verifier passes.
9. [v0.04-9 completion](../../implementation/v0.04-9-completion.md) written; roadmap priority → v0.04-10.

**Milestone outcome:** Traceable **demand → allocation → PO → receipt → on-hand allocation → fulfill** for v0.04 demand lines on PO-backed supply.

---

## Deferred

| Topic | Target |
| ----- | ------ |
| Auto-create PO lines from demand / sourcing | Later (optional v0.04-9+ or v0.04-10) |
| `vendor_backorder` → `inbound_purchase_order` on ship confirm | v0.04-9+ follow-up |
| POS `demand_allocation_id` on transaction lines | Post v0.04-9 or with v0.04-10 |
| AP invoice reconciliation / freight allocation | Out of v0.04 core |
| Full operational reports rewrite | v0.04-10 |
| EDI/API vendor confirmation import | Post v0.04-9 |
| Zero-accept receipt post for audit-only | Only if operational need confirmed |

---

## Next milestone

**v0.04-10** — Retire v0.03 ordering UI and reports.
