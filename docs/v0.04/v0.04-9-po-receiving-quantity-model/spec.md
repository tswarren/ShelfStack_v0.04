# v0.04-9 PO and Receiving Quantity Model — Functional Specification

## Status

**In review** — branch `v0.04-9-po-receiving-quantity-model`. Depends on [v0.04-8 completion](../../implementation/v0.04-8-completion.md) (merged). Mark **Complete** after PR merge.

Companion documents: [data-model.md](data-model.md), [test-plan.md](test-plan.md).

---

## Implementation slices

v0.04-9 is delivered in four implementation slices. Each slice should leave the app runnable and tested before the next begins.

### Slice A — PO line quantity lifecycle (schema + math)

* Migration: vendor quantity columns on `purchase_order_lines`; `vendor_quantity_state` + recorded-at/source markers
* Backfill historical lines as **`unconfirmed`** (not implicitly confirmed)
* `Purchasing::PoLineQuantitySummary` — authoritative open/confirmed/inbound math
* Update `DemandAllocations::InboundAvailability`:
  * use **recorded vendor supply** when `vendor_quantities_recorded_at` present;
  * fall back to `quantity_ordered - quantity_received` **only when unconfirmed**
* `Purchasing::SyncPoLineVendorQuantitiesFromSourcing` — aggregate/idempotent sync from final `vendor_responses` linked to a PO line
* PO/line status derivation aligned with [roadmap lifecycle vocabulary](../../roadmap/v0.04-delivery-roadmap.md#lifecycle-vocabulary-state-machines)
* Verifier skeleton (`shelfstack:v0049:verify_po_receiving`)
* Model and service tests for slice A

**Deferred in slice A:** `quantity_cascaded` on PO lines (cascade remains sourcing-level in v0.04-8; PO-line cascade workflow deferred).

### Slice B — Receipt → demand allocation conversion (v0.04 path)

* `DemandAllocations::ConvertInboundFromReceipt` — **FIFO** convert active `inbound_purchase_order` allocations for accepted receipt quantity
* Conversion pattern (normative):
  1. Create **new** active `on_hand` `demand_allocation`
  2. Terminalize inbound row as **`converted`** (or `released` with `release_reason = converted_to_on_hand` if enum extension deferred)
  3. Link both sides via conversion reference fields (see [data-model.md](data-model.md))
* Integrate into `Purchasing::PostReceipt` inside the **same transaction** as inventory post, PO qty updates, cache rebuild, and demand recalc — rollback entire post on conversion failure
* Legacy `Receiving::AllocateCustomerDemandFromReceipt` unchanged for v0.03 rows
* No writes to `receipt_line_allocations` or `purchase_order_line_allocations`
* Service tests + PostReceipt integration tests (v0.04 demand only)

### Slice C — Short, reject, close-short, and release paths

* `DemandAllocations::ReleaseUncoveredInbound` — release uncovered active inbound qty **reverse-FIFO** by `allocated_at` when effective inbound supply drops
* **Rejected receipt quantity does not auto-release demand** unless supply is reduced (close-short, vendor cancel, staff marks not replaceable, or explicit release)
* Receipt line exception breakdown UI; PO line vendor/receive/open columns; demand inbound vs on-hand state after post
* `Purchasing::UpdatePoLineQuantities` uses v0.04-9 accepted-to-stock semantics on PO lines

### Slice D — Operational snapshot, verification, docs

* `Purchasing::InboundAvailabilitySnapshot` (or equivalent read model)
* STRICT verifier checks (see [Verification](#verification-strict))
* Permissions audit; completion note; roadmap advance to v0.04-10

---

## Job

Close the v0.04 demand pipeline loop:

```text
Demand
  → Allocation (on_hand / inbound_purchase_order / vendor_backorder)
    → Sourcing (v0.04-8)
      → PO line (vendor quantity state + buckets)
        → Receipt (expected / physically received / accepted / rejected)
          → Demand allocation conversion (new on_hand + inbound converted)
            → Fulfillment / pickup (v0.04-7 Fulfill bridge)
```

v0.04-6 created demand lines.

v0.04-7 created demand allocations against existing open PO lines using legacy open-qty math.

v0.04-8 modeled vendor responses and inbound / vendor_backorder allocations without changing PO or receipt posting.

v0.04-9 makes **PO line and receipt line quantity lifecycle explicit** and wires **receipt posting to v0.04 demand allocations**.

---

## Purpose

v0.04-9 answers:

* How much did we request from the vendor on this PO line?
* Has the vendor responded, and in what buckets (confirmed / backorder / cancel)?
* How much is still open to receive against effective inbound supply?
* What arrived on the dock vs what was accepted to stock?
* Which demand inbound allocations convert to on-hand when stock is accepted?
* When does demand get released vs kept waiting for replacement?
* What is operationally “inbound” for allocation and staff UI?

---

## Core rules

### Inventory posting unchanged

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
| New `on_hand` allocation from conversion | No (directly) | **Yes** (via cache rebuild) |

### Naming: PO-line vs receipt-line `quantity_received`

These columns **do not mean the same thing**:

| Location | Column | Meaning |
| -------- | ------ | ------- |
| `purchase_order_lines` | `quantity_received` | Cumulative **accepted-to-stock** from posted receipts |
| `receipt_lines` | `quantity_received` | Physically counted on **this receipt draft** |
| `receipt_lines` | `quantity_accepted` | Accepted to stock on this line (posts inventory) |

Spec and UI copy should use “accepted on PO line” vs “physically received on receipt” where ambiguity matters. Renaming PO-line column is **out of scope** for v0.04-9; document semantics instead.

### Vendor response ≠ receipt ≠ invoice

* **Vendor response** (sourcing) — what vendor said they would ship.
* **Receipt** — what arrived and what was accepted.
* **Invoice/AP** — out of scope.

### Receipt post atomicity

```text
Inventory posting, PO/receipt quantity updates, inbound allocation conversion,
availability cache rebuild, and demand status recalculation must occur in the
same Purchasing::PostReceipt transaction.

If conversion fails, the receipt post rolls back.
```

Accepted stock must not become broadly available if promised demand conversion fails.

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
3. **No legacy customer-request / special-order / TBO expansion.**
4. **No AP invoice workflow.**
5. **No automatic PO header/line creation from demand** in v0.04-9 baseline.
6. **POS `demand_allocation_id` schema/linkage deferred from v0.04-9.** Pickup continues via v0.04-7 fulfill bridge only.
7. **No retiring v0.03 ordering UI** (v0.04-10).
8. **Product variant remains operational grain.**
9. **Moving average cost** on accepted receipt quantity only.
10. **RTV posting behavior preserved.**
11. **Destructive schema changes allowed** (pre-production).
12. **FIFO for inbound conversion; reverse-FIFO for shortage release** (see below).
13. **Do not mutate `allocation_kind`** from `inbound_purchase_order` to `on_hand` — create new on_hand row + terminalize inbound row.
14. **Posted receipt reversal/correction out of scope** unless existing behavior already supports it; conversion rows must retain `conversion_receipt_line_id` for future reversal.

---

## Settled decisions (planning)

| Decision | v0.04-9 answer |
| -------- | -------------- |
| Rename `quantity_ordered`? | **Keep**; maps to design-doc `quantity_requested` |
| Vendor confirmation state? | **Yes** — `vendor_quantity_state` + `vendor_quantities_recorded_at` |
| Confirmed zero falls back to ordered? | **No** — only **unconfirmed** lines fall back |
| Inbound→on_hand pattern? | **New on_hand row + inbound terminalized as `converted`** |
| Conversion ordering? | **FIFO** convert; **reverse-FIFO** release on shortage |
| Rejected qty auto-releases demand? | **No** — only when supply reduced or staff explicit |
| Sourcing→PO sync? | **Aggregate recalc** via `Purchasing::SyncPoLineVendorQuantitiesFromSourcing` |
| `quantity_cascaded` on PO line? | **Deferred** — sourcing-level in v0.04-9 |
| Status spelling | **PO:** `cancelled` (existing enum); **demand_allocation:** `canceled` / `converted` per existing + new |
| `vendor_backorder` → inbound? | **Deferred** |
| POS `demand_allocation_id`? | **Deferred from v0.04-9** |
| Receipt post transaction? | **Single atomic transaction** |

---

## Legacy posture

| Legacy / existing concept | v0.04-9 behavior |
| ------------------------- | ---------------- |
| `purchase_order_line_allocations` | Read for inbound math; **no writes** |
| `receipt_line_allocations` | Legacy PostReceipt path **unchanged** |
| `inventory_reservations` | Legacy incoming convert **unchanged** |
| Phase 5 `Purchasing::PostReceipt` | Extend in-place; atomic v0.04 conversion step |

---

## Reuse (existing services)

| Existing | v0.04-9 use |
| -------- | ----------- |
| `Purchasing::PostReceipt` | Atomic hook for conversion after inventory post |
| `Purchasing::UpdatePoLineQuantities` | Accepted-to-stock PO line semantics |
| `DemandAllocations::InboundAvailability` | Updated open formula + vendor state |
| `DemandAllocations::AllocateInboundPurchaseOrder` | Eligibility uses updated inbound math |
| `DemandAllocations::Release` / `Cancel` | Patterns for explicit release |
| `DemandLines::RecalculateAllocationStatus` | After convert/release |
| `Inventory::RebuildAvailabilityCache` | After on_hand creation |
| `Sourcing::RecordVendorResponse` | Calls sync service when PO line linked |

---

## PO line quantity model

### Vendor quantity state

Do **not** infer vendor response from `quantity_confirmed_by_vendor > 0` alone.

```text
vendor_quantity_state:
  unconfirmed
  partially_confirmed
  confirmed
  backordered
  canceled
  mixed

vendor_quantities_recorded_at   -- nil until first vendor qty recorded
vendor_quantities_source_type   -- manual | sourcing_response | import | api
vendor_quantities_source_id     -- optional polymorphic/id reference
```

**Backfill:** historical lines → `vendor_quantity_state = unconfirmed`, `vendor_quantities_recorded_at = nil`.

### Vendor quantity buckets

```text
quantity_ordered              -- store requested at submit (existing)
quantity_confirmed_by_vendor
quantity_backordered_by_vendor
quantity_canceled_by_vendor   -- vendor canceled (PO spelling: cancelled in status enum only)
```

**Deferred:** `quantity_cascaded` on PO line (sourcing attempts own cascade in v0.04-8).

Invariant when vendor quantities recorded:

```text
quantity_confirmed_by_vendor
  + quantity_backordered_by_vendor
  + quantity_canceled_by_vendor
  <= quantity_ordered
```

### Effective inbound supply

```text
if vendor_quantities_recorded_at present:
  effective_inbound_supply =
    max(quantity_confirmed_by_vendor - quantity_received - quantity_closed_short, 0)
else:
  effective_inbound_supply =
    max(quantity_ordered - quantity_received - quantity_closed_short, 0)
```

**Important:** vendor confirmed **zero** or vendor canceled all does **not** fall back to `quantity_ordered`.

### Open to receive (receiving documents)

```text
open_to_receive =
  max(
    effective_inbound_supply,
    0
  )
```

Where `quantity_received` on the **PO line** is cumulative **accepted-to-stock**, not physically counted receipt qty.

### Open for inbound allocation claims

```text
open_for_inbound_allocation =
  effective_inbound_supply
  - legacy_po_line_allocation_claims
  - v0047_active_inbound_demand_allocation_claims
```

### PO line / header status

Use existing `PurchaseOrderLine::STATUSES` spelling: **`cancelled`** (double-L), not `canceled`.

```text
open
partially_received
received
backordered
cancelled
closed_short
closed
```

---

## Receipt line quantity model

```text
quantity_expected   -- from PO open_to_receive or manual
quantity_received   -- physically counted on this receipt
quantity_accepted   -- accepted to stock (only this posts inventory)
quantity_rejected   -- rejected on this receipt
```

Optional breakdown: `quantity_damaged`, `quantity_wrong_item`, `quantity_substituted`, `quantity_short`.

---

## Demand allocation conversion (normative)

When `Purchasing::PostReceipt` posts a PO-backed line with `quantity_accepted = N`:

1. `Inventory::Post` for `N` (unchanged).
2. Select active `inbound_purchase_order` allocations on that `purchase_order_line_id`, **FIFO by `allocated_at`**.
3. For each, up to remaining `N`:
   * Create new active **`on_hand`** `demand_allocation` with `conversion_receipt_line_id`, `converted_from_allocation_id`, etc.
   * Terminalize inbound row as **`converted`** (preferred) with `converted_to_allocation_id`, `converted_at`, `converted_by_user_id`.
   * **Do not** change `allocation_kind` on the inbound row.
4. `Inventory::RebuildAvailabilityCache` for affected variants.
5. `DemandLines::RecalculateAllocationStatus`.
6. Audit both sides (`demand_allocation.converted_inbound_to_on_hand`, inbound terminal event).
7. No legacy `receipt_line_allocations` for v0.04 demand.

Partial FIFO example:

```text
Demand A: inbound 2 (older)
Demand B: inbound 1 (newer)
Receipt accepted 2
→ A: inbound converted 2 → on_hand 2; B unchanged
```

---

## Short / reject / close-short / release

### Conversion vs release ordering

```text
Accepted receipt quantity  → convert inbound FIFO
Uncovered inbound supply   → release inbound reverse-FIFO
```

### When demand is released/requeued

Release active inbound allocation quantity when:

* PO line **closed short** reduces effective inbound supply;
* Vendor **canceled** quantity recorded on PO line;
* Receipt **short** reduces effective inbound supply below active inbound claims;
* Staff **explicitly releases** inbound allocation; or
* Staff marks rejected quantity **not replaceable** (explicit action).

**Do not** auto-release demand solely because `quantity_rejected > 0` on a receipt line if effective inbound supply is unchanged (replacement expected).

`vendor_backorder` allocations: **do not auto-release** in v0.04-9 unless explicitly covered in a follow-up.

---

## Sourcing ↔ PO line sync

Service: **`Purchasing::SyncPoLineVendorQuantitiesFromSourcing`**

```text
Recalculate PO line vendor buckets from final vendor_responses linked to purchase_order_line_id.
Write aggregate totals — never increment blindly.
Idempotent on re-run / edited response.
Set vendor_quantities_recorded_at and vendor_quantity_state from bucket totals.
```

Called from `Sourcing::RecordVendorResponse` when `purchase_order_line` present on final response (or immediately after in same transaction).

Inbound demand allocations from v0.04-8 remain separate claims; sync updates supply visibility only.

---

## UI scope (bounded)

| Surface | v0.04-9 addition |
| ------- | ---------------- |
| PO line show / hub | Vendor state, buckets, accepted-on-PO vs open |
| Receipt draft/post | Expected / physical / accepted / rejected |
| `/demand/:id` | Inbound vs on-hand after conversion |
| Item variant ops PO table | Updated inbound math |

Reports rewrite → v0.04-10.

---

## Permissions and audit

Reuse `orders.receipts.post`, `orders.purchase_orders.*`, `demand.allocations.*` where sufficient.

Audit events (minimum):

```text
purchase_order_line.vendor_quantities_updated
receipt.posted                    (extend: v0.04 conversion counts)
demand_allocation.converted_inbound_to_on_hand
demand_allocation.released_inbound
```

---

## Verification (STRICT)

Rake: `shelfstack:v0049:verify_po_receiving`

Checks (minimum):

* Required columns and services present
* v0.04-9 services do not call `Inventory::Post` except via `PostReceipt`
* v0.04-9 services do not write legacy allocation tables
* **Unconfirmed** PO lines may use ordered fallback; **recorded** lines do not
* **Confirmed zero / canceled all** does not fall back to `quantity_ordered`
* Active inbound allocations per PO line ≤ `open_for_inbound_allocation`
* Converted inbound allocations are not `active`
* New on_hand rows from conversion reference `conversion_receipt_line_id` and `converted_from_allocation_id`
* Receipt accepted qty is the only quantity posted through `Inventory::Post`
* Short/close-short release does not write `receipt_line_allocations`
* PostReceipt fixture: inbound converts on post; rollback on conversion failure

Run with:

```bash
STRICT=1 bin/rails shelfstack:v0049:verify_po_receiving
STRICT=1 bin/rails shelfstack:v0047:verify_allocations
STRICT=1 bin/rails shelfstack:v0048:verify_sourcing
```

---

## Definition of done

1. PO lines have vendor state, buckets, backfill as unconfirmed, and summary math.
2. `InboundAvailability` uses recorded-vendor vs unconfirmed fallback correctly.
3. `SyncPoLineVendorQuantitiesFromSourcing` is aggregate/idempotent.
4. Posted receipts convert inbound→on_hand (FIFO) inside atomic PostReceipt transaction.
5. Short/close-short/cancel release uncovered inbound reverse-FIFO; rejected qty does not auto-release.
6. Conversion reference fields populated; inbound rows terminalized, not kind-mutated.
7. Bounded UI shows quantity breakdown.
8. Legacy customer-request receipt path unchanged.
9. Tests per [test-plan.md](test-plan.md); STRICT v0049 passes.
10. Completion note; roadmap → v0.04-10.

**Milestone outcome:** Traceable **demand → allocation → PO → receipt → on-hand allocation → fulfill** for v0.04 demand on PO-backed supply.

---

## Deferred

| Topic | Target |
| ----- | ------ |
| `quantity_cascaded` on PO lines | Post v0.04-9 / with PO cascade UI |
| Auto-create PO lines from demand/sourcing | v0.04-9+ / v0.04-10 |
| `vendor_backorder` → `inbound_purchase_order` | v0.04-9+ follow-up |
| POS `demand_allocation_id` | **Deferred from v0.04-9** |
| Posted receipt reversal/correction | Out of scope; design for traceability via conversion FKs |
| AP invoice / freight | Out of v0.04 core |
| Full reports rewrite | v0.04-10 |
| EDI/API vendor confirmation | Post v0.04-9 |

---

## Next milestone

**v0.04-10** — Retire v0.03 ordering UI and reports.
