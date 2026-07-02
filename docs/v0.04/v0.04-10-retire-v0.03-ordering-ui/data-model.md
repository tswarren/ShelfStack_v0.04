# v0.04-10 Retire v0.03 Ordering UI — Data Model Notes

## Status

**Planned** — companion to [spec.md](spec.md). Depends on v0.04-6 (`demand_lines`), v0.04-7 (`demand_allocations`), v0.04-8 (`sourcing_*`), v0.04-9 (PO/receipt quantity + conversion).

---

## Schema changes (planned)

### Slice C — POS demand pickup

**Add**

| Table | Column | Type | Notes |
| ----- | ------ | ---- | ----- |
| `pos_transaction_lines` | `demand_allocation_id` | `bigint` FK → `demand_allocations`, nullable, indexed | Pickup line references active on_hand allocation |

**Retain through G1**

| Table | Column | Notes |
| ----- | ------ | ----- |
| `pos_transaction_lines` | `inventory_reservation_id` | Legacy pickup FK; staff paths retired G1; column dropped G2 if reservations dropped |

No change to `demand_allocations` — `fulfillment_reference_type` / `fulfillment_reference_id` already exist (v0.04-7).

### Slice G2 — Tables to drop

After G1 quarantine verifier passes and reseed plan confirmed:

```text
customer_requests
customer_request_lines
special_orders
purchase_requests
purchase_request_lines
inventory_reservations          # conditional — see spec hard gate
purchase_order_line_allocations
receipt_line_allocations
```

Supporting sequence tables if present (e.g. customer request sequences) — drop with parent domain.

### Slice G2 — FK columns to remove

Audit during G1 grep; minimum expected:

| Table | Column |
| ----- | ------ |
| `pos_transaction_lines` | `inventory_reservation_id` |
| `purchase_order_lines` | any legacy-only FKs to special_orders / customer_request_lines (if present) |
| `receipt_lines` | legacy allocation associations via join tables |

Run `schema.rb` diff after migration; update [schema-reference.md](../../schema-reference.md) in v0.04-11.

---

## Tables unchanged (carry forward)

```text
demand_lines
demand_line_sequences
demand_allocations
stock_considerations
sourcing_runs
sourcing_attempts
vendor_responses
purchase_orders
purchase_order_lines
receipts
receipt_lines
inventory_postings / ledger / balances
pos_* (except line FK addition)
```

---

## Write path after G2

| Event | Writes |
| ----- | ------ |
| Staff create demand | `demand_lines` only |
| Hold / allocate | `demand_allocations` + availability cache |
| Sourcing / vendor response | v0.04-8 tables + PO vendor qty sync |
| Receipt post | inventory + PO lines + `DemandAllocations::ConvertInboundFromReceipt` |
| POS pickup complete | POS tables + `DemandAllocations::Fulfill` |
| **No** | `customer_requests`, `inventory_reservations`, `*_line_allocations` |

---

## Availability cache (G2)

`Inventory::RebuildAvailabilityCache` / `DemandAllocations::InboundAvailability`:

* **G1:** may still subtract legacy reservations/allocations for transitional data
* **G2:** v0.04 `demand_allocations` only for reserved and inbound open supply

---

## Permissions (seed)

Remove permission keys tied to dropped tables; map roles to `demand.*`. See [spec.md — Permissions](spec.md#permissions).

New optional key: `demand.reports.queue`.

---

## Verifier data-model checks

**G1**

* `pos_transaction_lines.demand_allocation_id` column present
* Legacy tables exist but write gate passes (no new rows from staff paths in test harness)

**G2**

* Legacy tables absent
* `pos_transaction_lines.inventory_reservation_id` absent (if reservations dropped)
* Sample POS completed pickup row: `demand_allocation.status = fulfilled`, `fulfillment_reference` populated

---

## Explicitly not in v0.04-10

* Drop `catalog_items` / product fusion cleanup (v0.04-11)
* `pos_transaction_lines` rename or broader POS schema redesign
* Migration of historical legacy rows into `demand_lines` (reseed instead)
