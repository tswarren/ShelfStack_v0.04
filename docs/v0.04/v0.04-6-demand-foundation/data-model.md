# v0.04-6 Demand Foundation — Data Model Notes

## Status

**Planned** — companion to [spec.md](spec.md).

---

## New tables

### `demand_line_sequences`

| Column | Type | Notes |
| ------ | ---- | ----- |
| `store_id` | FK | unique |
| `last_sequence` | integer | default 0 |

Used by `DemandLines::NumberAllocator` to assign immutable `{store_number}-D{sequence:06d}`.

**Concurrency:** allocator must `with_lock` the sequence row while incrementing `last_sequence` inside the same transaction as demand line insert.

### `demand_lines`

**Grain:** one row = one identified need. No separate demand header table.

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `store_id` | FK stores | no | |
| `demand_number` | string | no | unique per store; immutable after create |
| `source` | string | no | controlled enum |
| `purpose` | string | no | controlled enum |
| `capture_intent` | string | yes | hold, notify, special_order, research, manual_tbo, used_wanted, buyer_replenishment |
| `status` | string | no | captured, open, canceled, expired |
| `product_id` | FK products | yes | |
| `product_variant_id` | FK product_variants | yes | required when status `open` |
| `customer_id` | FK customers | yes | per eligibility matrix |
| `customer_name_snapshot` | string | yes | walk-in |
| `customer_email_snapshot` | string | yes | |
| `customer_phone_snapshot` | string | yes | |
| `preferred_contact_method` | string | yes | e.g. email, phone, sms, in_person; optional |
| `quantity_requested` | integer | no | > 0 |
| `needed_by_date` | date | yes | |
| `expires_at` | datetime | yes | |
| `provisional_title` | string | yes | |
| `provisional_identifier` | string | yes | |
| `provisional_creator` | string | yes | |
| `notes` | text | yes | |
| `created_by_user_id` | FK users | no | |
| `matched_by_user_id` | FK users | yes | |
| `matched_at` | datetime | yes | |
| `canceled_by_user_id` | FK users | yes | |
| `canceled_at` | datetime | yes | |
| `cancel_reason` | text | yes | |
| `expired_by_user_id` | FK users | yes | |
| `expired_at` | datetime | yes | |
| `stock_consideration_id` | FK stock_considerations | yes | when converted from consideration |
| timestamps | | | |

**Validation:**

* When `product_variant_id` is present, `product_id` must be present and equal `product_variant.product_id`.
* `open` status requires `product_variant_id` (enforce on transition and save when open).

**Quantity fields deferred to v0.04-7:**

Do **not** add `filled_quantity`, `cancelled_quantity`, `quantity_open`, `quantity_allocated`, `quantity_fulfilled`, or `quantity_remaining` in v0.04-6. Use `quantity_requested` + terminal status only until allocations exist.

**Indexes:**

* unique `[store_id, demand_number]`
* `[store_id, status]`
* `[product_variant_id]`
* `[customer_id]`
* `[source, purpose, status]`

**Check constraints:**

* `quantity_requested > 0`

### `stock_considerations`

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `store_id` | FK | no | |
| `status` | string | no | open, reviewing, converted_to_demand, dismissed, duplicate, already_carried |
| `product_id` | FK | yes | |
| `product_variant_id` | FK | yes | |
| `provisional_title` | string | yes | |
| `provisional_identifier` | string | yes | |
| `provisional_creator` | string | yes | |
| `reason` | text | yes | |
| `priority` | string | yes | optional controlled enum if needed |
| `quantity_suggested` | integer | yes | |
| `notes` | text | yes | |
| `created_by_user_id` | FK users | no | |
| `reviewed_by_user_id` | FK users | yes | actor who moved out of `open`/`reviewing` |
| `reviewed_at` | datetime | yes | |
| `converted_by_user_id` | FK users | yes | when status `converted_to_demand` |
| `converted_at` | datetime | yes | |
| `dismissed_by_user_id` | FK users | yes | |
| `dismissed_at` | datetime | yes | |
| `dismiss_reason` | text | yes | |
| timestamps | | | |

**Provenance link (one direction only):** `demand_lines.stock_consideration_id` → `stock_considerations`. Do **not** add `stock_considerations.converted_demand_line_id` — use `has_one :converted_demand_line, foreign_key: :stock_consideration_id` on `StockConsideration`.

Optional `consideration_number` + sequence table if buyer queue needs human-readable IDs — defer unless UI requires in slice 1.

---

## Controlled enums

### `demand_lines.source`

```text
customer_order
manual_tbo
sales_replenishment
buyer_decision
frontlist_import
promotion
event
inventory_replacement
used_wanted_request
```

v0.04-6 create paths: `customer_order`, `manual_tbo`, `buyer_decision`, `used_wanted_request` (minimum).

### `demand_lines.purpose`

```text
customer_fulfillment
shelf_replenishment
frontlist_stock
display_stock
event_stock
preorder_fulfillment
backorder_fulfillment
replacement
used_wanted
```

### `demand_lines.status` (v0.04-6)

```text
captured
open
canceled
expired
```

Add `partially_allocated`, `allocated`, `fulfilled` in v0.04-7.

**Enum combinations:** services must reject invalid `source` + `purpose` + `capture_intent` triples per [spec eligibility matrix](spec.md#eligibility-matrix).

---

## Associations

```ruby
class DemandLine
  belongs_to :stock_consideration, optional: true
end

class StockConsideration
  has_one :converted_demand_line,
    class_name: "DemandLine",
    foreign_key: :stock_consideration_id
end
```

Single FK on `demand_lines` preserves provenance without reciprocal sync.

---

## Legacy tables (v0.04-6)

No schema changes required to `customer_requests`, `special_orders`, `purchase_requests`, or `inventory_reservations`.

**Runtime rule:** v0.04-6 services and item drawer **do not insert** into legacy demand tables.

Physical removal and FK cleanup → v0.04-10.

---

## Explicitly not in v0.04-6

```text
demand_allocations
sourcing_runs / sourcing_attempts / vendor_responses
demand_line → purchase_order_line FK
demand_line → inventory_reservation FK
demand_line → purchase_request_line FK
```

---

## Audit events

```text
demand_line.created
demand_line.matched
demand_line.canceled
demand_line.expired
stock_consideration.created
stock_consideration.converted
stock_consideration.dismissed
```

---

## Seeds

Idempotent `demand.*` and `stock_considerations.*` permission seeds.
