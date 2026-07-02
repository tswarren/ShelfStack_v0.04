# v0.04-9 PO and Receiving Quantity Model — Test Plan

## Status

**Planned** — companion to [spec.md](spec.md) and [data-model.md](data-model.md).

---

## Test categories

| Category | Focus |
| -------- | ----- |
| Models | Vendor state, bucket validations, conversion FKs, receipt breakdown |
| Services | PoLineQuantitySummary, SyncPoLineVendorQuantitiesFromSourcing, convert, release |
| Integration | Atomic `Purchasing::PostReceipt` with v0.04 allocations |
| Ordering | FIFO conversion; reverse-FIFO release |
| Legacy isolation | No legacy allocation writes |
| Inventory | Accepted-only post; MAC |
| Verifier | STRICT v0049 checks per spec |

---

## Implementation slices (test order)

| Slice | Test focus |
| ----- | ---------- |
| **A** | Vendor state backfill, summary math, unconfirmed vs recorded, sync idempotency, InboundAvailability |
| **B** | ConvertInboundFromReceipt, new on_hand + inbound converted, atomic PostReceipt, FIFO |
| **C** | Reverse-FIFO release, rejected-not-replaceable, close-short, no auto-release on reject alone |
| **D** | Verifier STRICT, v0047/v0048 regression |

---

## Model tests

### `PurchaseOrderLine` (extended)

* Defaults: `vendor_quantity_state = unconfirmed`, `vendor_quantities_recorded_at = nil`
* Rejects negative vendor buckets
* Rejects bucket sum > `quantity_ordered` when recorded
* `quantity_received` semantics documented in test names (accepted-to-stock)

### `DemandAllocation` (conversion fields)

* New on_hand row requires `converted_from_allocation_id` + `conversion_receipt_line_id` when created via conversion
* Inbound row `converted` is terminal; not `active`
* `allocation_kind` unchanged on inbound after conversion

---

## PO line quantity summary tests

| State | recorded? | ordered | confirmed | received | closed_short | effective_inbound | open_to_receive |
| ----- | --------- | ------: | --------: | -------: | -----------: | ----------------: | --------------: |
| unconfirmed | no | 5 | 0 | 0 | 0 | 5 | 5 |
| recorded partial | yes | 5 | 4 | 0 | 0 | 4 | 4 |
| recorded partial recv | yes | 5 | 4 | 2 | 0 | 2 | 2 |
| recorded zero confirm | yes | 5 | 0 | 0 | 0 | **0** | **0** (no fallback to 5) |
| recorded canceled all | yes | 5 | 0 | 0 | 0 | 0 | 0 |
| close short | yes | 5 | 4 | 3 | 1 | 0 | 0 |

Minus claims in separate `open_for_inbound_allocation` tests.

---

## Inbound availability tests

* **Unconfirmed:** uses `quantity_ordered - quantity_received - closed_short`
* **Recorded with confirmed 4:** uses confirmed base, not ordered 5
* **Recorded confirmed 0:** effective supply 0 — does not fall back to ordered
* Legacy + v0.04 claims subtracted (unchanged from v0.04-7)
* Active inbound claims cannot exceed `open_for_inbound_allocation` (verifier-style fixture)

---

## Sourcing sync tests

`Purchasing::SyncPoLineVendorQuantitiesFromSourcing`:

* Two final responses on same PO line → aggregate totals, not sum of increments on re-sync
* Re-run sync after response edit → idempotent totals
* Sets `vendor_quantities_recorded_at` and `vendor_quantity_state`
* Does not mutate demand allocations

---

## Receipt conversion tests

### Happy path

* Inbound 3 → receipt accepted 3 → on_hand 3 active; inbound `converted`; conversion FKs set

### FIFO partial

* Demand A inbound 2 (older), B inbound 1 (newer); accepted 2 → A converted fully; B active

### Pattern guard

* Inbound row `allocation_kind` still `inbound_purchase_order` after conversion (not `on_hand`)

### Audit

* Events on both inbound and on_hand rows

---

## PostReceipt integration tests

* **Atomic rollback:** stub conversion failure → no inventory post persisted, receipt still draft
* `Inventory::Post` quantity equals sum of `quantity_accepted` only
* Legacy path still runs for customer-request fixture; v0.04 demand does not create `ReceiptLineAllocation`

---

## Short / release tests

| Scenario | Expected |
| -------- | -------- |
| Expected 3, accepted 2, inbound 3 | Convert 2 FIFO; release 1 **reverse-FIFO** |
| Rejected 3, supply unchanged, `rejected_not_replaceable = false` | **No** inbound release |
| Rejected 3, `rejected_not_replaceable = true` | Release per explicit rule + audit |
| PO close-short | Release uncovered inbound reverse-FIFO |
| Vendor canceled qty on recorded PO line | Release uncovered inbound |

---

## Verifier tests (STRICT)

* Unconfirmed may use ordered fallback
* Recorded confirmed-zero does not use ordered fallback
* Converted inbound not active
* on_hand from conversion has receipt_line + from_allocation FKs
* Short release does not write `receipt_line_allocations`
* PostReceipt integration fixture passes

---

## Test helpers (`V0049TestHelper`)

```text
create_unconfirmed_po_line!
record_vendor_quantities_on_po_line!
create_inbound_allocation_for_po_line!
post_receipt_for_po!
grant_v0049_po_receiving_permissions!
```

---

## Out of scope

* POS `demand_allocation_id`
* Posted receipt reversal
* PO-line `quantity_cascaded`
* Auto PO line creation from demand
