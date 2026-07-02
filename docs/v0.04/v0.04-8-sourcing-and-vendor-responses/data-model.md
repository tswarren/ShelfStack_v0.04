# v0.04-8 Sourcing and Vendor Responses — Data Model Notes

## Status

**In review** — companion to [spec.md](spec.md). Implemented on branch `v0.04-8-sourcing-and-vendor-responses`; CI passing. Depends on v0.04-6 (`demand_lines`) and v0.04-7 (`demand_allocations`).

---

## New tables

### `sourcing_runs`

**Grain:** one row = one sourcing lifecycle for one demand line and product variant.

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `store_id` | FK stores | no | denormalized for scoping |
| `demand_line_id` | FK demand_lines | no | |
| `product_id` | FK products | no | must match demand line |
| `product_variant_id` | FK product_variants | no | sourcing grain |
| `status` | string | no | see lifecycle below |
| `quantity_requested` | integer | no | snapshot at run start; > 0 |
| `started_by_user_id` | FK users | no | |
| `started_at` | datetime | no | |
| `closed_by_user_id` | FK users | yes | |
| `closed_at` | datetime | yes | |
| `close_reason` | text | yes | required when closing with unresolved qty |
| `canceled_by_user_id` | FK users | yes | |
| `canceled_at` | datetime | yes | |
| `cancel_reason` | text | yes | when status = canceled |
| `notes` | text | yes | |
| timestamps | | | |

**Status values:**

```text
open
partially_resolved
resolved
needs_review
canceled
```

**Active statuses** (at most one active run per demand line):

```text
open
partially_resolved
needs_review
```

**Validation:**

* `store_id`, `product_id`, `product_variant_id` must match demand line.
* `quantity_requested > 0`.
* Cannot start run when demand line is terminal or `captured`.
* Partial unique index or service guard: one active run per `demand_line_id`.

**Indexes:**

* `[demand_line_id, status]`
* `[store_id, status, started_at]`
* `[store_id, product_variant_id, status]`

---

### `sourcing_attempts`

**Grain:** one row = one vendor attempt inside a sourcing run.

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `store_id` | FK stores | no | |
| `sourcing_run_id` | FK sourcing_runs | no | |
| `demand_line_id` | FK demand_lines | no | denormalized |
| `product_id` | FK products | no | |
| `product_variant_id` | FK product_variants | no | |
| `vendor_id` | FK vendors | no | |
| `product_variant_vendor_id` | FK product_variant_vendors | yes | source link |
| `product_vendor_id` | FK product_vendors | yes | source link |
| `purchase_order_line_id` | FK purchase_order_lines | yes | optional manual link |
| `previous_sourcing_attempt_id` | FK sourcing_attempts | yes | cascade source |
| `status` | string | no | derived/cached workflow state |
| `sequence_number` | integer | no | per run, 1-based |
| `quantity_requested` | integer | no | > 0 |
| `submitted_by_user_id` | FK users | yes | required when submitted |
| `submitted_at` | datetime | yes | |
| `response_due_at` | datetime | yes | operational hint |
| `cascade_reason` | string | yes | when cascaded from prior |
| `buyer_review_required` | boolean | no | default false |
| `manual_vendor_override` | boolean | no | default false |
| `manual_override_reason` | text | yes | required when override |
| `override_authorized_by_user_id` | FK users | yes | |
| `override_authorized_at` | datetime | yes | |
| `vendor_name_snapshot` | string | yes | set at submit |
| `vendor_item_number_snapshot` | string | yes | |
| `source_level_snapshot` | string | yes | variant_vendor, product_vendor, preferred, manual |
| `source_record_type` | string | yes | polymorphic type |
| `source_record_id` | bigint | yes | |
| `vendor_priority_snapshot` | integer | yes | |
| `estimated_unit_cost_cents_snapshot` | integer | yes | |
| `returnability_snapshot` | string | yes | |
| `canceled_by_user_id` | FK users | yes | |
| `canceled_at` | datetime | yes | |
| `cancel_reason` | text | yes | |
| `notes` | text | yes | |
| timestamps | | | |

**Status values:**

```text
pending
submitted
confirmed
partially_confirmed
backordered
canceled
failed
cascaded
```

**Validation:**

* `quantity_requested > 0`.
* Sum of in-flight attempt qty per demand line must not exceed `Sourcing::UnresolvedQuantity` rules.
* `manual_vendor_override = true` requires override reason, actor, timestamp.
* `purchase_order_line_id` when present: same store, same variant, eligible PO header status (match v0.04-7 inbound rules).
* Snapshots populated on `SubmitAttempt`, not on create.

**Indexes:**

* `[sourcing_run_id, sequence_number]` unique
* `[demand_line_id, status]`
* `[store_id, vendor_id, status]`
* `[purchase_order_line_id]`
* `[previous_sourcing_attempt_id]`

---

### `vendor_responses`

**Grain:** one row = one vendor response event for one sourcing attempt. **Append-only** in normal operation.

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `store_id` | FK stores | no | |
| `sourcing_attempt_id` | FK sourcing_attempts | no | |
| `vendor_id` | FK vendors | no | |
| `response_status` | string | no | |
| `response_method` | string | no | manual, import, api (manual default) |
| `responded_by_user_id` | FK users | no | |
| `responded_at` | datetime | no | |
| `vendor_reference` | string | yes | PO ack, EDI ref, etc. |
| `message` | text | yes | |
| `expected_ship_date` | date | yes | optional |
| `expected_arrival_date` | date | yes | optional |
| `quantity_confirmed` | integer | no | default 0 |
| `quantity_backordered` | integer | no | default 0 |
| `quantity_unavailable` | integer | no | default 0 |
| `quantity_canceled` | integer | no | default 0 |
| `quantity_failed` | integer | no | default 0 |
| `quantity_substitute_offered` | integer | no | default 0 |
| `final_response` | boolean | no | default false |
| `purchase_order_line_id` | FK purchase_order_lines | yes | link at response time |
| `notes` | text | yes | |
| `raw_payload` | jsonb | yes | future import/API |
| timestamps | | | |

**Response status values:**

```text
confirmed
partially_confirmed
backordered
unavailable
canceled
failed
substitute_offered
mixed
```

**Validation:**

* All quantity fields >= 0.
* Sum of quantity buckets <= `sourcing_attempt.quantity_requested`.
* When `final_response = true`: sum of buckets **equals** `quantity_requested`.
* No updates/deletes in normal operation; corrections via new response row or void pattern deferred.

**Indexes:**

* `[sourcing_attempt_id, responded_at]`
* `[store_id, vendor_id, responded_at]`

---

## Changes to existing tables

### `demand_allocations`

**Extend `allocation_kind` enum:**

```text
on_hand
inbound_purchase_order
vendor_backorder          # v0.04-8
```

**New optional columns:**

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `sourcing_attempt_id` | FK sourcing_attempts | yes | |
| `vendor_response_id` | FK vendor_responses | yes | |

**`vendor_backorder` validation:**

```text
allocation_kind = vendor_backorder
  requires sourcing_attempt_id OR vendor_response_id
  must NOT have purchase_order_line_id
  does not trigger Inventory::RebuildAvailabilityCache
```

**Status lifecycle:** same as v0.04-7 (`active`, `fulfilled`, `released`, `expired`, `canceled`).

---

### `demand_lines`

**No new status values.** No sourcing cache columns.

Sourcing visibility is via joins to `sourcing_runs` / `sourcing_attempts`.

---

## Derived quantities

### Demand allocation sums (extend v0.04-7)

Computed in `DemandAllocations::AllocationQuantities` (extend):

```text
active_on_hand_allocation_qty =
  SUM quantity_allocated WHERE kind = on_hand AND status = active

active_inbound_purchase_order_allocation_qty =
  SUM quantity_allocated WHERE kind = inbound_purchase_order AND status = active

active_vendor_backorder_allocation_qty =
  SUM quantity_allocated WHERE kind = vendor_backorder AND status = active

active_allocated_quantity =
  active_on_hand + active_inbound + active_vendor_backorder
  (all status = active)

fulfilled_quantity =
  SUM quantity_allocated WHERE status = fulfilled

unallocated_quantity (demand) =
  quantity_requested - active_allocated_quantity - fulfilled_quantity
  (floor at 0)
```

**Note:** `vendor_backorder` is included in `active_allocated_quantity` for demand status recalculation.

### Sourcing unresolved (authoritative — `Sourcing::UnresolvedQuantity`)

```text
unresolved_for_sourcing =
  demand_line.quantity_requested
  - fulfilled_allocation_qty
  - active_on_hand_allocation_qty
  - active_inbound_purchase_order_allocation_qty
  - active_vendor_backorder_allocation_qty
  - in_flight_sourcing_attempt_qty
```

**`in_flight_sourcing_attempt_qty`:**

```text
For each sourcing_attempt on demand_line where status IN (pending, submitted):
  in_flight += quantity_requested
    - quantity covered by final vendor_response buckets on that attempt
    - unless attempt status IN (cascaded, canceled, failed) with fully accounted qty
```

Implementation may compute in-flight as:

```text
SUM(sourcing_attempts.quantity_requested)
WHERE status IN (pending, submitted)
AND sourcing_run.status IN (open, partially_resolved, needs_review)
```

Refine when partial final responses exist (only unaccounted remainder is in-flight).

### Run unresolved quantity

For a sourcing run, unresolved is the portion of run `quantity_requested` not yet:

* covered by final response allocations (inbound / vendor_backorder)
* marked cascaded to successor attempt
* explicitly closed on run

Service-level definition in `Sourcing::RunQuantities` (implementation detail).

---

## Status recalculation (demand lines — extend v0.04-7)

**No change to status enum.** Extend active allocation sum to include `vendor_backorder`.

Normative rules (unchanged structure from v0.04-7):

```text
remaining_to_fulfill = quantity_requested - fulfilled_quantity

IF fulfilled_quantity >= quantity_requested → fulfilled
ELSE IF active_allocated_quantity >= remaining_to_fulfill → allocated
ELSE IF active_allocated_quantity > 0 OR fulfilled_quantity > 0 → partially_allocated
ELSE → open
```

**Example (vendor backorder):**

| Requested | Active on_hand | Active inbound | Active vendor_backorder | Fulfilled | Status |
| --------: | -------------: | -------------: | ----------------------: | --------: | ------ |
| 2 | 0 | 0 | 2 | 0 | `allocated` |

Inventory cache unchanged.

---

## Availability cache (no change to formula)

`Inventory::RebuildAvailabilityCache` continues to sum **only** `allocation_kind = on_hand` and legacy reservations.

**Explicit exclusion:**

```text
vendor_backorder allocations MUST NOT affect quantity_reserved or quantity_available
inbound_purchase_order allocations MUST NOT affect quantity_reserved (v0.04-7 rule preserved)
```

Verifier STRICT check required.

---

## In-flight vs allocation (anti double-count)

| State | Counts in `unresolved_for_sourcing` subtraction | Counts in `active_allocated_quantity` |
| ----- | ----------------------------------------------- | ------------------------------------- |
| Pending attempt | yes (in-flight) | no |
| Submitted, no final response | yes (in-flight) | no |
| Final confirmed + PO linked → inbound alloc | no (inbound alloc subtracts) | yes (inbound) |
| Final confirmed, no PO | yes until buyer resolves OR attempt closed | no |
| Final backorder + vendor_backorder alloc | no (vendor_backorder subtracts) | yes (vendor_backorder) |
| Cascaded attempt predecessor | no | no |
| Unavailable/failed on final response | no in-flight on attempt; returns to unresolved pool | no |

---

## PO line linkage

**Eligible PO line** (same rules as v0.04-7 `AllocateInboundPurchaseOrder`):

* Same `store_id` as demand
* Same `product_variant_id`
* PO header in receivable/open statuses per `PurchaseOrder::RECEIVABLE_PO_STATUSES`
* Sufficient inbound availability on line (legacy + v0.04 claims)

Link may be set on `sourcing_attempts.purchase_order_line_id` before submit or on `vendor_responses.purchase_order_line_id` at response record time.

**v0.04-8 does not create PO headers or lines.**

---

## Lock order (recommended)

Mirror v0.04-7 mutation patterns:

```text
demand_line
  → sourcing_run
  → sourcing_attempt
  → demand_allocation (when creating inbound/vendor_backorder)
  → purchase_order_line (when linking inbound)
```

---

## Audit and permissions

See [spec.md](spec.md). Seed file: `db/seeds/v0048_permissions.rb` (planned).

---

## Migration notes

Suggested migration id prefix: `20260703*` or next available timestamp.

Order:

1. Create `sourcing_runs`
2. Create `sourcing_attempts`
3. Create `vendor_responses`
4. Alter `demand_allocations`: add kind value, FK columns, check constraints

Backfill: none required (greenfield tables).

---

## Deferred schema

Not in v0.04-8:

```text
PO line quantity_confirmed_by_vendor / backordered / cascaded columns → v0.04-9
receipt line allocation bridge columns → v0.04-9
vendor_response void/reversal rows → later if needed
auto-cascade vendor profile flags → later
```
