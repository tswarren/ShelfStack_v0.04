# v0.04-7 Allocations and Reservations — Data Model Notes

## Status

**Planned** — companion to [spec.md](spec.md). Depends on v0.04-6 schema (`demand_lines`, etc.).

---

## New tables

### `demand_allocations`

**Grain:** one row = one claim of a quantity from a demand line against a supply source.

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `store_id` | FK stores | no | denormalized from demand line for scoping/indexes |
| `demand_line_id` | FK demand_lines | no | |
| `product_id` | FK products | no | must match demand line / variant |
| `product_variant_id` | FK product_variants | no | allocation grain |
| `allocation_kind` | string | no | `on_hand`, `inbound_purchase_order` |
| `status` | string | no | `active`, `fulfilled`, `released`, `expired`, `canceled` |
| `quantity_allocated` | integer | no | > 0 |
| `purchase_order_line_id` | FK purchase_order_lines | yes | required when kind = `inbound_purchase_order` |
| `expires_at` | datetime | yes | for on-hand holds; default from `demand_lines.expires_at` on create |
| `allocated_by_user_id` | FK users | no | actor who created allocation |
| `allocated_at` | datetime | no | |
| `released_by_user_id` | FK users | yes | |
| `released_at` | datetime | yes | |
| `release_reason` | text | yes | |
| `canceled_by_user_id` | FK users | yes | |
| `canceled_at` | datetime | yes | |
| `cancel_reason` | text | yes | |
| `expired_by_user_id` | FK users | yes | null when system expiry job |
| `expired_at` | datetime | yes | |
| `fulfilled_by_user_id` | FK users | yes | |
| `fulfilled_at` | datetime | yes | |
| `fulfillment_reference_type` | string | yes | optional polymorphic reference |
| `fulfillment_reference_id` | bigint | yes | e.g. POS line id when bridged |
| `override_availability` | boolean | no | default false; true when over-allocate override used |
| `override_authorized_by_user_id` | FK users | yes | |
| `override_authorized_at` | datetime | yes | |
| `override_reason` | text | yes | |
| `notes` | text | yes | |
| timestamps | | | |

**Validation:**

* When `product_variant_id` is present on the demand line, `demand_allocations.product_id` must equal `demand_line.product_id` and `product_variant.product_id`.
* `product_variant_id` must match `demand_line.product_variant_id`.
* `store_id` must match demand line store.
* `purchase_order_line_id` required iff `allocation_kind = inbound_purchase_order`; must be null for `on_hand`.
* `quantity_allocated` > 0.
* Cannot allocate when demand line status is `captured` or terminal.
* **Override (on_hand only):** `override_availability` applies only to `on_hand` allocations in v0.04-7 — not inbound PO. When `override_availability = true`: `override_authorized_by_user_id`, `override_authorized_at`, and `override_reason` are required.
* **Terminal allocation statuses** — required fields:

| Status | Required fields |
| ------ | --------------- |
| `released` | `released_at`, `released_by_user_id`; `release_reason` optional |
| `canceled` | `canceled_at`, `canceled_by_user_id`, `cancel_reason` |
| `expired` | `expired_at`; `expired_by_user_id` optional when system/job expiry |
| `fulfilled` | `fulfilled_at`; `fulfilled_by_user_id` when staff manual fulfill, or `fulfillment_reference_type/id` when reference-driven |

**Service-set timestamps:** `allocated_at` defaults to `Time.current` on create. Terminal timestamps (`released_at`, `canceled_at`, `expired_at`, `fulfilled_at`) are set by services — not user input.

**System expiry:** When expired by `DemandLines::ExpireDue`, `expired_by_user_id` may be null; `expired_at` is required. Audit event actor should indicate system/job context (no fake system user on allocation row).

**Indexes:**

* `[demand_line_id, status]`
* `[store_id, product_variant_id, allocation_kind, status]`
* `[purchase_order_line_id, status]`
* `[status, expires_at]` — expiry job (active allocations due)
* `[store_id, status, expires_at]` — optional; add if store-scoped expiry queries need it

**Check constraints:**

* `quantity_allocated > 0`
* `allocation_kind` in allowed set
* `status` in allowed set

---

## Changes to existing tables

### `demand_lines`

**Status enum extension:**

```text
captured
open
partially_allocated
allocated
fulfilled
canceled
expired
```

**Terminal statuses:**

```text
fulfilled
canceled
expired
```

Update model constant `TERMINAL_STATUSES`.

**No new quantity cache columns in v0.04-7** — continue to use `quantity_requested` only on demand line; derive allocated/fulfilled/unallocated from allocation rows via services/presenters.

**Hold default expiry:** When `capture_intent = hold` and `expires_at` blank at create, set `expires_at = 14.days.from_now` in `DemandLines::Create` / `StartFromItem` (v0.04-7 behavior change).

---

## Derived quantities

Computed in `DemandAllocations::Availability` and `DemandLines::RecalculateAllocationStatus`:

```text
active_allocated_quantity =
  SUM(quantity_allocated) WHERE status = active

fulfilled_quantity =
  SUM(quantity_allocated) WHERE status = fulfilled

allocated_or_fulfilled_quantity =
  active_allocated_quantity + fulfilled_quantity

unallocated_quantity =
  quantity_requested - allocated_or_fulfilled_quantity
  (floor at 0)
```

**Status recalculation (normative):**

Status is based on **uncovered quantity** (remaining to fulfill), not active allocations alone.

```text
remaining_to_fulfill =
  quantity_requested - fulfilled_quantity

IF demand is captured
  → no allocation allowed

IF demand is terminal (fulfilled, canceled, expired)
  → do not recalculate unless the service explicitly owns the terminal transition

IF fulfilled_quantity >= quantity_requested
  → status = fulfilled

ELSE IF active_allocated_quantity >= remaining_to_fulfill
  → status = allocated

ELSE IF active_allocated_quantity > 0 OR fulfilled_quantity > 0
  → status = partially_allocated

ELSE
  → status = open
```

**Example:** `quantity_requested = 2`, `fulfilled_quantity = 1`, `active_allocated_quantity = 1` → `allocated` (fully covered; one fulfilled, one still active).

Edge cases covered in service tests.

---

## Availability cache (no new table)

**Service:** `Inventory::RebuildAvailabilityCache`

Per `inventory_balances` (store + product_variant):

```text
legacy_on_hand_reserved =
  SUM from InventoryReservation.active_on_hand
  (quantity_reserved - quantity_fulfilled - quantity_released)  # match existing rebuild semantics

v0047_on_hand_reserved =
  SUM demand_allocations.quantity_allocated
  WHERE allocation_kind = on_hand AND status = active
  (includes override_availability rows)

quantity_reserved = legacy_on_hand_reserved + v0047_on_hand_reserved

quantity_available = quantity_on_hand - quantity_reserved
```

**Layers (do not conflate):**

```text
quantity_reserved =
  legacy on-hand inventory_reservations
  + active v0.04 on_hand demand_allocations

available_for_allocation =
  quantity_on_hand - quantity_reserved
  (floor at 0 for normal non-override allocation decisions)

available_for_sale_now =
  quantity_on_hand - quantity_reserved - active pending/suspended POS claims
```

Pending/suspended POS claims are **not** demand allocations. They reduce sale confidence but are not stored on `demand_allocations`. Preserve existing POS/session claim rules the app already applies; document in implementation.

**Negative availability:** `quantity_available` **may be negative** when an authorized override creates reservations greater than on-hand quantity. UI should show **over-allocated**, not silently floor to zero. Normal (non-override) allocate paths still use `available_for_allocation` floored at zero.

**Inbound allocations do not affect `quantity_reserved`** — they claim expected inbound supply, not current physical stock.

---

## Inbound PO available quantity

Implementation helper (conceptual name: `DemandAllocations::InboundAvailability`):

```text
eligible_line =
  purchase_order_line in allowed statuses
  AND purchase_order in allowed header statuses
  AND same store as demand

open_line_quantity =
  use existing PurchaseOrderLine open-quantity helper if present;
  if none exists, define Purchasing helper in v0.04-7 compatible with current
  PO fields (e.g. quantity_ordered - quantity_received) until v0.04-9 replaces lifecycle

legacy_inbound_claimed =
  SUM purchase_order_line_allocations.quantity_allocated
  WHERE status IN active/partially_received open set

v0047_inbound_claimed =
  SUM demand_allocations.quantity_allocated
  WHERE kind = inbound_purchase_order AND status = active

available_inbound =
  open_line_quantity - legacy_inbound_claimed - v0047_inbound_claimed
```

Confirm allowed PO/line statuses against `PurchaseOrder` / `PurchaseOrderLine` models at implementation time. **No override_availability on inbound PO allocations in v0.04-7.**

---

## Relationships

```text
DemandLine has_many demand_allocations
DemandAllocation belongs_to demand_line
DemandAllocation belongs_to store
DemandAllocation belongs_to product
DemandAllocation belongs_to product_variant
DemandAllocation belongs_to purchase_order_line (optional)
```

No reciprocal FK from PO lines or inventory balances to demand allocations.

---

## Legacy tables (read only for v0.04-7)

| Table | v0.04-7 write | v0.04-7 read |
| ----- | ------------- | ------------ |
| `inventory_reservations` | no | yes — availability rebuild |
| `purchase_order_line_allocations` | no | yes — inbound availability |
| `receipt_line_allocations` | no | no in v0.04-7 |

---

## Explicitly not in v0.04-7

```text
demand_allocations.allocation_kind beyond on_hand, inbound_purchase_order
pos_transaction_lines.demand_allocation_id (optional defer)
sourcing_runs / sourcing_attempts / vendor_responses
PO line confirmed/backordered/canceled quantity columns (v0.04-9)
receipt allocation conversion services
quantity_* cache columns on demand_lines
source_snapshot jsonb on demand_allocations (optional debug/audit; not required v0.04-7)
```

---

## Audit events

See [spec.md](spec.md). Store context on allocation events; include demand_line id, allocation kind, quantity, override flag when applicable.

---

## Seeds

Idempotent permission seeds:

```text
demand.allocations.*
demand.expire_due
```

Wire in `db/seeds.rb` and test helper mirroring v0.04-6.
