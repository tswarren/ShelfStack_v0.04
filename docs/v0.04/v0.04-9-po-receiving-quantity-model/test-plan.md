# v0.04-9 PO and Receiving Quantity Model — Test Plan

## Status

**Planned** — companion to [spec.md](spec.md) and [data-model.md](data-model.md).

---

## Test categories

| Category | Focus |
| -------- | ----- |
| Models | PO line vendor qty validations; receipt line breakdown sums |
| Services | PoLineQuantitySummary, InboundAvailability update, convert inbound→on_hand, release on short |
| Integration | `Purchasing::PostReceipt` with v0.04 demand allocations |
| Sourcing bridge | PO line vendor qty sync from final vendor response (if implemented in v0.04-9) |
| Legacy isolation | No writes to legacy allocation tables from v0.04-9 paths |
| Inventory invariant | Only `quantity_accepted` posts; MAC on accepted only |
| Demand integration | RecalculateAllocationStatus after convert/release |
| Cache | RebuildAvailabilityCache after on_hand conversion |
| Authorization | Receipt post and allocation permissions |
| Audit | Conversion, release, vendor qty update events |
| Verifier | `shelfstack:v0049:verify_po_receiving` STRICT |
| UI/request | Bounded PO/receipt/demand panels (smoke) |

---

## Implementation slices (test order)

| Slice | Test focus |
| ----- | ---------- |
| **A** | PO vendor columns, summary math, InboundAvailability, backfill, sourcing PO sync |
| **B** | ConvertInboundFromReceipt, PostReceipt integration, FIFO partial conversion |
| **C** | Short/reject release, close-short, UI presenters |
| **D** | Verifier STRICT, regression with v0047/v0048 verifiers |

---

## Model tests

### `PurchaseOrderLine` (extended)

* Vendor qty columns default 0
* Rejects negative vendor buckets
* Rejects vendor bucket sum > `quantity_ordered`
* `quantity_received` cannot exceed effective confirmed ceiling (when enforced)
* Status derivation cases (table below)

### `ReceiptLine` (extended, if breakdown columns added)

* Breakdown components sum ≤ `quantity_received`
* `quantity_accepted + quantity_rejected <= quantity_received` at post validation

---

## PO line quantity summary tests

| PO state | Expected open_to_receive | Expected open_for_inbound_allocation |
| -------- | ------------------------ | ------------------------------------ |
| ordered 5, confirmed 0, received 0 | 5 (fallback) | 5 minus claims |
| ordered 5, confirmed 4, received 0 | 4 | 4 minus claims |
| ordered 5, confirmed 4, received 2 | 2 | 2 minus claims |
| ordered 5, confirmed 4, received 4 | 0 | 0 |
| closed_short 1, confirmed 4, received 3 | 0 | 0 |

Claims columns in tests: legacy PO allocation + v0.04 inbound demand allocation.

---

## Inbound availability tests

Extend `DemandAllocations::InboundAvailability` tests:

* Uses confirmed qty when `quantity_confirmed_by_vendor > 0`
* Falls back to `quantity_ordered - quantity_received` when confirmed is 0
* Subtracts legacy `purchase_order_line_allocations` open claims
* Subtracts v0.04 `demand_allocations` inbound active claims
* Rejects ineligible PO header/line status (unchanged from v0.04-7)

---

## Receipt conversion tests (`DemandAllocations::ConvertInboundFromReceipt`)

### Happy path

* Demand with inbound alloc 3 on PO line; receipt accepted 3; post receipt → inbound released/fulfilled; on_hand alloc 3 active; demand `allocated`; cache reserved updated

### Partial receipt FIFO

* Demand A inbound 2, Demand B inbound 1, same PO line; receipt accepted 2 → A fully converted, B unchanged

### No v0.04 inbound allocations

* Receipt posts inventory only; no conversion errors; legacy path unaffected

### Multi-line receipt

* Only PO-backed lines with accepted qty trigger conversion for matching PO line

### Audit

* `demand_allocation.converted_inbound_to_on_hand` recorded with receipt_line reference

---

## PostReceipt integration tests

* Full transaction rollback if conversion fails after inventory post (must remain atomic)
* `Inventory::Post` called once with accepted lines only
* `Purchasing::UpdatePoLineQuantities` updates PO line `quantity_received` consistently
* Legacy `Receiving::AllocateCustomerDemandFromReceipt` still invoked for legacy rows (spy or fixture with customer_request chain) — no double conversion for v0.04 demand

---

## Short / release tests

| Scenario | Expected demand effect |
| -------- | ---------------------- |
| Expected 3, accepted 2, inbound alloc 3 on demand | Convert 2 to on_hand; release 1 inbound |
| Expected 3, accepted 0, rejected 3 | Release active inbound alloc 3; demand recalc toward open |
| PO close-short after partial receive | Release uncovered inbound allocations |

---

## Sourcing bridge tests (if in scope)

* Final vendor response confirmed 4 on linked PO line → PO line `quantity_confirmed_by_vendor = 4`
* Idempotent re-sync does not inflate confirmed qty
* Inbound allocation from v0.04-8 unchanged by sync alone

---

## Legacy isolation tests

* v0.04 demand receipt post: `ReceiptLineAllocation.count` unchanged
* v0.04 demand receipt post: `PurchaseOrderLineAllocation` rows unchanged
* Legacy customer-request receipt fixture: legacy allocation path still creates rows (existing test extended)

---

## Inventory and MAC tests

* Receipt with accepted 0 on all lines → post fails (existing behavior)
* Receipt accepted 5 → MAC updates from accepted cost only
* Conversion services do not change `InventoryLedgerEntry` count

---

## Verifier tests

* `v0049_verify_po_receiving` PASS in development fixture
* STRICT mode fails when legacy write detected in v0.04-9 service list
* STRICT fails when inbound availability helper missing

Run in CI with:

```bash
STRICT=1 bin/rails shelfstack:v0049:verify_po_receiving
STRICT=1 bin/rails shelfstack:v0047:verify_allocations
STRICT=1 bin/rails shelfstack:v0048:verify_sourcing
```

---

## UI / request smoke tests

* PO show displays vendor-confirmed vs open columns
* Receipt show/draft displays expected/accepted/rejected
* Demand show reflects on_hand conversion after receipt post (integration or system test)

---

## Regression matrix (roadmap acceptance scenarios)

| # | Scenario | v0.04-9 coverage |
| - | -------- | ---------------- |
| 3 | Receive PO → only accepted posts → MAC | PostReceipt + MAC tests |
| 5 | Demand → sourcing → partial confirm → cascade | v0048 tests unchanged; PO confirmed columns if synced |
| 8 | Receipt short → allocation released / demand requeued | Short/release tests |

---

## Test helpers

Add `V0049TestHelper` mirroring v0.04-7/8:

* `create_po_with_confirmed_line!`
* `create_inbound_allocation_for_po_line!`
* `post_receipt_for_po!`
* `grant_v0049_po_receiving_permissions!`

Wire in `test/test_helper.rb` when permissions seed exists.

---

## Out of scope (v0.04-10+)

* Customer request index/report parity
* POS pickup with `demand_allocation_id`
* Full AP invoice variance
* Auto PO line creation from demand UI
