# v0.04-9 PO and Receiving Quantity Model — Data Model Notes

## Status

**In review** — companion to [spec.md](spec.md). Depends on v0.04-6 (`demand_lines`), v0.04-7 (`demand_allocations`), v0.04-8 (`sourcing_*`).

---

## Schema changes (planned)

### `purchase_order_lines` — extend

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `vendor_quantity_state` | string | no | default `unconfirmed`; see spec enum |
| `quantity_confirmed_by_vendor` | integer | no | default 0 |
| `quantity_backordered_by_vendor` | integer | no | default 0 |
| `quantity_canceled_by_vendor` | integer | no | default 0 |
| `quantity_rejected_on_line` | integer | no | default 0; cumulative rejected at receipt |
| `quantity_closed_short` | integer | no | default 0 |
| `vendor_quantities_recorded_at` | datetime | yes | nil = unconfirmed fallback allowed |
| `vendor_quantities_source_type` | string | yes | `manual`, `sourcing_response`, `import`, `api` |
| `vendor_quantities_source_id` | bigint | yes | optional source row id |

**Deferred from v0.04-9 baseline:** `quantity_cascaded` on PO line (cascade stays on `sourcing_attempts`).

**Retained columns (semantic clarification):**

| Column | v0.04-9 meaning |
| ------ | --------------- |
| `quantity_ordered` | Store-requested qty at submit |
| `quantity_received` | Cumulative **accepted-to-stock** on PO line (not physical receipt count) |
| `status` | Existing enum; spelling **`cancelled`** (matches `PurchaseOrderLine::STATUSES`) |

**`vendor_quantity_state` values:**

```text
unconfirmed
partially_confirmed
confirmed
backordered
canceled          -- line-level vendor cancel state (PO status enum uses cancelled)
mixed
```

**Check constraints (conceptual):**

```text
vendor bucket columns >= 0
when vendor_quantities_recorded_at present:
  confirmed + backordered + canceled <= quantity_ordered
quantity_received + quantity_closed_short <= ceiling per effective supply rules
```

**Backfill:**

```text
vendor_quantity_state = unconfirmed
vendor_quantities_recorded_at = nil
vendor bucket columns = 0
quantity_received unchanged
```

---

### `demand_allocations` — extend (conversion traceability)

Add status **`converted`** to `STATUSES` (terminal), or use `released` + `release_reason = converted_to_on_hand` if enum extension deferred — **prefer `converted`**.

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `converted_from_allocation_id` | FK demand_allocations | yes | on new on_hand row |
| `converted_to_allocation_id` | FK demand_allocations | yes | on inbound row being terminalized |
| `conversion_receipt_line_id` | FK receipt_lines | yes | |
| `converted_at` | datetime | yes | |
| `converted_by_user_id` | FK users | yes | |
| `conversion_reason` | string | yes | default `receipt_post` |
| `release_reason` | string | yes | for non-convert releases: `receipt_short`, `po_closed_short`, `vendor_canceled`, `not_replaceable`, etc. |

**Rules:**

* Do **not** mutate `allocation_kind` on inbound row.
* New `on_hand` row points to inbound via `converted_from_allocation_id`.
* Terminal inbound row points to on_hand via `converted_to_allocation_id`.

---

### `receipt_lines` — extend (optional)

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `quantity_damaged` | integer | no | default 0 |
| `quantity_wrong_item` | integer | no | default 0 |
| `quantity_substituted` | integer | no | default 0 |
| `quantity_short` | integer | no | default 0 |
| `rejected_not_replaceable` | boolean | no | default false; staff flag for demand release |
| `invoice_cost_cents` | integer | yes | optional; AP out of scope |

**Receipt-line `quantity_received`** = physically counted on this receipt (unchanged).

---

## Quantity helpers

### `Purchasing::PoLineQuantitySummary`

```text
vendor_quantities_recorded?(po_line)
effective_inbound_supply(po_line)
open_to_receive_quantity(po_line)        # same as effective_inbound_supply when defined this way
open_for_inbound_allocation(po_line)     # effective_inbound_supply minus claims
derive_vendor_quantity_state(po_line)    # from buckets + ordered
```

**Normative math:**

```text
if vendor_quantities_recorded_at.present?:
  base = quantity_confirmed_by_vendor
else:
  base = quantity_ordered

effective_inbound_supply =
  max(base - quantity_received - quantity_closed_short, 0)

open_for_inbound_allocation =
  effective_inbound_supply
  - legacy_po_line_allocation_claims
  - v0047_active_inbound_claims
```

### `Purchasing::SyncPoLineVendorQuantitiesFromSourcing`

```text
Inputs: purchase_order_line_id
Source: vendor_responses WHERE final_response = true AND purchase_order_line_id = ?
Aggregate quantity_confirmed, quantity_backordered, quantity_unavailable+canceled buckets per spec mapping
Write totals (not increment)
Set vendor_quantities_recorded_at, source_type/id, vendor_quantity_state
```

### `DemandAllocations::InboundAvailability` (update)

Uses `PoLineQuantitySummary.open_for_inbound_allocation` — eligibility rules unchanged from v0.04-7.

---

## Demand allocation conversion (normative)

Service: `DemandAllocations::ConvertInboundFromReceipt` (or per-allocation `ConvertInboundToOnHand`)

```text
1. Lock inbound allocation row
2. Create new on_hand demand_allocation:
     quantity_allocated = convert_qty
     converted_from_allocation_id = inbound.id
     conversion_receipt_line_id = receipt_line.id
     purchase_order_line_id = optional copy for traceability
3. Terminalize inbound row:
     status = converted
     converted_to_allocation_id = new_on_hand.id
     converted_at, converted_by_user_id
4. Audit both rows
5. RecalculateAllocationStatus + RebuildAvailabilityCache
```

**Ordering:** FIFO by `allocated_at` for conversion.

**Release (slice C):** `DemandAllocations::ReleaseUncoveredInbound` — reverse-FIFO by `allocated_at`.

---

## `Purchasing::PostReceipt` transaction boundary

Single `Receipt.transaction` (existing) must include:

```text
Inventory::Post (accepted lines)
UpdatePoLineQuantities
DemandAllocations::ConvertInboundFromReceipt (v0.04 path)
Legacy Receiving::AllocateCustomerDemandFromReceipt (unchanged)
receipt.status = posted
Audit
```

Rollback all on any failure after lock.

---

## Status spelling reference

| Model | Cancel spelling | Notes |
| ----- | --------------- | ----- |
| `PurchaseOrder` / `PurchaseOrderLine` | `cancelled` | **Keep existing** |
| `DemandAllocation` | `canceled` | **Keep existing** |
| `vendor_quantity_state` on PO line | `canceled` | State name; distinct from PO line status enum |

Do not normalize PO enums to single-L in v0.04-9.

---

## Legacy tables (read / no v0.04-9 writes)

| Table | v0.04-9 |
| ----- | ------- |
| `purchase_order_line_allocations` | Read in inbound math only |
| `receipt_line_allocations` | Legacy PostReceipt path only |
| `inventory_reservations` | Legacy incoming convert only |

---

## Explicitly not in v0.04-9

```text
quantity_cascaded on purchase_order_lines
purchase_order_line_allocations schema changes
receipt_line_allocations schema changes
pos_transaction_lines.demand_allocation_id
posted receipt reversal workflow
automatic PO creation from demand
```

---

## Migration ordering

```text
db/migrate/*_add_v0049_po_line_vendor_quantities.rb
db/migrate/*_add_v0049_demand_allocation_conversion_fields.rb
db/migrate/*_add_v0049_receipt_line_breakdown.rb (optional)
db/migrate/*_backfill_v0049_po_line_unconfirmed.rb
```
