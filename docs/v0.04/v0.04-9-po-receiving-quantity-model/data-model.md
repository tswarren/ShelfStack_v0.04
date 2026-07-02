# v0.04-9 PO and Receiving Quantity Model — Data Model Notes

## Status

**Planned** — companion to [spec.md](spec.md). Depends on v0.04-6 (`demand_lines`), v0.04-7 (`demand_allocations`), v0.04-8 (`sourcing_*`).

---

## Schema changes (planned)

### `purchase_order_lines` — extend

**Grain unchanged:** one row = one variant line on one PO.

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `quantity_confirmed_by_vendor` | integer | no | default 0; vendor acknowledged shippable |
| `quantity_backordered_by_vendor` | integer | no | default 0 |
| `quantity_canceled_by_vendor` | integer | no | default 0 |
| `quantity_cascaded` | integer | no | default 0; moved to alternate source |
| `quantity_rejected_on_line` | integer | no | default 0; cumulative rejected at receipt (optional name: `quantity_rejected`) |
| `quantity_closed_short` | integer | no | default 0; closed without full receipt |
| `vendor_confirmed_at` | datetime | yes | when vendor qty last synced/recorded |
| `vendor_confirmation_source` | string | yes | `manual`, `sourcing_response`, `import`, `api` |

**Retained columns (semantic clarification, not rename in v0.04-9):**

| Column | v0.04-9 meaning |
| ------ | --------------- |
| `quantity_ordered` | Store-requested qty at submit (= design doc `quantity_requested`) |
| `quantity_received` | Cumulative **accepted-to-stock** from posted receipts |
| `status` | Derived from vendor + receiving state |

**Check constraints (conceptual):**

```text
all vendor qty columns >= 0
quantity_confirmed + backordered + canceled + cascaded <= quantity_ordered
quantity_received <= effective_confirmed_or_ordered ceiling
quantity_closed_short >= 0
```

**Backfill (migration):**

```text
quantity_confirmed_by_vendor = 0 for historical rows
quantity_received unchanged
For open lines with no vendor confirmation, inbound math falls back to quantity_ordered - quantity_received (v0.04-7 behavior)
```

**Indexes:** no new indexes required beyond existing PO line indexes unless query patterns demand `[purchase_order_id, status]` vendor-qty filters.

---

### `receipt_lines` — extend (optional columns)

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `quantity_damaged` | integer | no | default 0 |
| `quantity_wrong_item` | integer | no | default 0 |
| `quantity_substituted` | integer | no | default 0 |
| `quantity_short` | integer | no | default 0; derived or stored when `quantity_received < quantity_expected` |
| `line_disposition` | string | yes | summary: `accepted`, `rejected`, `mixed`, `short` (derived ok) |
| `invoice_cost_cents` | integer | yes | deferred optional — AP out of scope |

Existing columns remain authoritative for post:

```text
quantity_expected
quantity_received
quantity_accepted
quantity_rejected
exception_reason
unit_cost_cents
```

Validation (model):

```text
quantity_accepted + quantity_rejected <= quantity_received (when enforcing at post)
quantity_* breakdown sums <= quantity_received when breakdown columns populated
```

---

### No new tables required (baseline)

v0.04-9 reuses:

```text
purchase_orders
purchase_order_lines
receipts
receipt_lines
receiving_discrepancies
demand_lines
demand_allocations
sourcing_attempts
vendor_responses
```

Optional future table (not v0.04-9 baseline):

```text
purchase_order_line_quantity_events  -- append-only vendor qty audit; defer unless needed
```

---

## Quantity helpers (conceptual services)

### `Purchasing::PoLineQuantitySummary`

Methods (names illustrative):

```text
effective_confirmed_quantity(po_line)
open_to_receive_quantity(po_line)
open_for_inbound_allocation(po_line)
vendor_buckets_total(po_line)
```

### `DemandAllocations::InboundAvailability` (update)

Replace open qty source:

```text
open_qty = Purchasing::PoLineQuantitySummary.open_for_inbound_allocation(po_line)
legacy_claimed = SUM purchase_order_line_allocations (open statuses)
v0047_claimed = SUM demand_allocations inbound active
available = open_qty - legacy_claimed - v0047_claimed
```

Eligibility rules unchanged: receivable PO header + eligible line status.

---

## Demand allocation conversion

No new allocation **kind** required for baseline conversion.

Pattern (recommended):

```text
1. DemandAllocations::ConvertInboundToOnHand.call!(
     demand_allocation: inbound_row,
     actor:,
     quantity: n,
     source_receipt_line:,
     notes:
   )
2. Inbound row: reduce quantity or move to released/fulfilled terminal with partial semantics
3. Create new on_hand allocation row OR increment existing active on_hand on same demand line (prefer single active on_hand per demand line if v0.04-7 already enforces — confirm at implementation)
4. Audit + RecalculateAllocationStatus + RebuildAvailabilityCache
```

Alternative (if simpler): mutate `allocation_kind` with audit event — **only if** audit trail remains clear; spec prefers explicit convert service.

---

## Relationships (unchanged grains)

```text
PurchaseOrderLine has_many receipt_lines
PurchaseOrderLine has_many demand_allocations (inbound kind)
ReceiptLine belongs_to purchase_order_line (optional)
DemandAllocation belongs_to purchase_order_line (optional, inbound only)
VendorResponse belongs_to purchase_order_line (optional, v0.04-8)
```

No reciprocal FK from PO lines to demand beyond existing optional `purchase_order_line_id` on allocations.

---

## Legacy tables (read / no v0.04-9 writes)

| Table | v0.04-9 |
| ----- | ------- |
| `purchase_order_line_allocations` | Read in inbound availability only |
| `receipt_line_allocations` | Legacy PostReceipt path only |
| `inventory_reservations` | Legacy incoming convert only |

---

## Status derivation notes

### `purchase_order_lines.status`

Inputs: vendor buckets, `quantity_received`, `quantity_closed_short`, line cancellation.

Illustrative priority:

```text
cancelled when explicitly canceled
closed_short when close-short qty accounts for remainder
received when quantity_received >= effective_confirmed
partially_received when quantity_received > 0 and not received
backordered when vendor backorder bucket covers unresolved confirmed supply (coordinate with existing backordered status)
open otherwise
```

Confirm against existing `PurchaseOrderLine::STATUSES` at implementation — do not introduce statuses outside enum without migration.

### Receipt posted state

Unchanged: `receipts.status = posted` with `inventory_posting_id` when at least one accepted line posts.

---

## Audit events

Store context on all mutations:

```text
actor
store_id
demand_line_id (when applicable)
purchase_order_line_id
receipt_line_id
quantity deltas
source (receipt_post, sourcing_sync, manual_po_edit)
```

---

## Seeds

No new reference seeds required unless new permissions added.

If permissions added, use stable keys in `db/seeds/v0049_permissions.rb` (name TBD) and wire in `db/seeds.rb` + test helper.

---

## Explicitly not in v0.04-9

```text
New PO header fields beyond existing notes/status
purchase_order_line_allocations schema changes
receipt_line_allocations schema changes
pos_transaction_lines.demand_allocation_id
Full GL / invoice tables
Automatic PO creation from demand
Retiring customer_requests tables
```

---

## Migration ordering

Suggested filenames (timestamps assigned at implementation):

```text
db/migrate/*_add_v0049_po_line_vendor_quantities.rb
db/migrate/*_add_v0049_receipt_line_breakdown.rb (optional)
db/migrate/*_backfill_v0049_po_line_vendor_quantities.rb
```

Run after v0.04-8 migrations (`sourcing_*`, demand_allocations vendor_backorder columns).
