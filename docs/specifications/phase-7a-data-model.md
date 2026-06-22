# Phase 7A Data Model

## Purpose

Source of truth for Phase 7A migrations.

Functional behavior: [phase-7a-customer-demand-spec.md](phase-7a-customer-demand-spec.md)

Normative roadmap: [phase-7a-customer-demand.md](../roadmap/phase-7a-customer-demand.md)

---

# 1. Naming Conventions

- Booleans: `active` (not `is_active`)
- Money: integer cents (`quoted_price_cents`, `max_customer_price_cents`)
- Datetimes: `_at` suffix; dates: `_on` suffix
- Controlled string enums validated in models (not Rails STI `type` column)
- Store-scoped operational records include `store_id`

---

# 2. Schema Changes on Existing Tables

## 2.1 `inventory_balances`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `quantity_reserved` | integer | NOT NULL, default 0 | Cached sum of active on-hand reservations |

Check constraint:

```sql
quantity_reserved >= 0
```

After Phase 7A:

```text
quantity_available = quantity_on_hand - quantity_reserved
```

`Inventory::BalanceUpdater` must not set `quantity_available = quantity_on_hand` without subtracting reserved.

## 2.2 `pos_transaction_lines`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `customer_request_line_id` | bigint | FK nullable | Pickup fulfillment link |
| `special_order_id` | bigint | FK nullable | Pickup fulfillment link |
| `inventory_reservation_id` | bigint | FK nullable | Pickup fulfillment link |

Indexes on each FK column.

**Pickup line FK rules:**

- **Normal sale lines:** all three nullable.
- **Reservation pickup lines:** `inventory_reservation_id` required; `special_order_id` and `customer_request_line_id` populated when available; services validate consistent demand chain.

## 2.3 `pos_transactions`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `customer_id` | bigint | FK nullable | Pickup context; line links authoritative |

Index on `customer_id`.

---

# 3. New Tables

## 3.1 `customers`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `home_store_id` | bigint | FK nullable | Optional reference store |
| `display_name` | string | NOT NULL | |
| `email` | string | nullable | |
| `phone` | string | nullable | |
| `preferred_contact_method` | string | nullable | `phone`, `email`, `sms`, `in_person`, `other` |
| `notes` | text | nullable | |
| `active` | boolean | NOT NULL, default true | |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

Indexes:

- `index_customers_on_active`
- `index_customers_on_display_name` (for search)
- `index_customers_on_home_store_id`
- optional trigram/GIN on `display_name`, `email`, `phone` if search requires (defer to implementation)

Foreign keys: `home_store_id → stores.id`

---

## 3.2 `customer_request_sequences`

Store-scoped sequence for request numbers (mirrors `pos_workstation_sequences` pattern).

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `store_id` | bigint | FK NOT NULL | |
| `last_sequence` | integer | NOT NULL, default 0 | |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

Unique index: `store_id`

Foreign keys: `store_id → stores.id`

Request number assigned as `REQ-{stores.store_number}-{last_sequence zero-padded to 6}`.

---

## 3.3 `customer_requests`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `store_id` | bigint | FK NOT NULL | Operational store |
| `customer_id` | bigint | FK nullable | |
| `request_number` | string | NOT NULL | Unique per store |
| `status` | string | NOT NULL | See §4.1 |
| `source` | string | NOT NULL, default `in_store` | `in_store`, `phone`, `email`, `web`, `pos`, `staff` |
| `preferred_contact_method` | string | nullable | |
| `needed_by_date` | date | nullable | |
| `expires_at` | datetime | nullable | Optional whole-request expiry |
| `assigned_to_user_id` | bigint | FK nullable | |
| `created_by_user_id` | bigint | FK NOT NULL | |
| `last_contacted_at` | datetime | nullable | |
| `completed_at` | datetime | nullable | |
| `cancelled_at` | datetime | nullable | |
| `cancellation_reason` | text | nullable | |
| `unfillable_reason` | text | nullable | |
| `customer_name_snapshot` | string | nullable | When customer_id blank |
| `customer_email_snapshot` | string | nullable | |
| `customer_phone_snapshot` | string | nullable | |
| `notes` | text | nullable | |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

Indexes:

- unique `(store_id, request_number)`
- `(store_id, status)`
- `customer_id`
- `assigned_to_user_id`
- `created_by_user_id`

Foreign keys: `store_id`, `customer_id`, `assigned_to_user_id`, `created_by_user_id`

Validation: require `customer_id` OR at least `customer_name_snapshot` present.

---

## 3.4 `customer_request_lines`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `customer_request_id` | bigint | FK NOT NULL | |
| `line_number` | integer | NOT NULL | Unique per request |
| `request_type` | string | NOT NULL | `research`, `notify`, `hold`, `special_order` |
| `status` | string | NOT NULL | See §4.2 |
| `catalog_item_id` | bigint | FK nullable | |
| `product_id` | bigint | FK nullable | |
| `product_variant_id` | bigint | FK nullable | Required before hold/SO/PO/POS |
| `requested_quantity` | integer | NOT NULL, default 1 | > 0 |
| `approved_quantity` | integer | NOT NULL, default 0 | ≥ 0 |
| `ordered_quantity` | integer | NOT NULL, default 0 | ≥ 0 |
| `filled_quantity` | integer | NOT NULL, default 0 | ≥ 0 |
| `cancelled_quantity` | integer | NOT NULL, default 0 | ≥ 0 |
| `provisional_title` | string | nullable | |
| `provisional_creator` | string | nullable | |
| `provisional_identifier` | string | nullable | |
| `provisional_format` | string | nullable | |
| `quoted_price_cents` | integer | nullable | ≥ 0 |
| `max_customer_price_cents` | integer | nullable | ≥ 0 |
| `notes` | text | nullable | |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

Indexes:

- unique `(customer_request_id, line_number)`
- `product_variant_id`
- `(status, request_type)` partial indexes as needed for queues

Foreign keys: request, catalog_item, product, product_variant

Check constraints:

```sql
requested_quantity > 0
approved_quantity >= 0
ordered_quantity >= 0
filled_quantity >= 0
cancelled_quantity >= 0
```

---

## 3.5 `special_orders`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `store_id` | bigint | FK NOT NULL | |
| `customer_id` | bigint | FK NOT NULL | |
| `customer_request_line_id` | bigint | FK NOT NULL | |
| `product_variant_id` | bigint | FK nullable until matched | |
| `vendor_id` | bigint | FK nullable | |
| `status` | string | NOT NULL | See §4.3 |
| `quantity_committed` | integer | NOT NULL | > 0 |
| `quantity_ordered` | integer | NOT NULL, default 0 | |
| `quantity_received` | integer | NOT NULL, default 0 | |
| `quantity_ready` | integer | NOT NULL, default 0 | |
| `quantity_completed` | integer | NOT NULL, default 0 | |
| `quantity_cancelled` | integer | NOT NULL, default 0 | |
| `created_by_user_id` | bigint | FK NOT NULL | |
| `approved_at` | datetime | nullable | |
| `ordered_at` | datetime | nullable | |
| `ready_at` | datetime | nullable | |
| `completed_at` | datetime | nullable | |
| `cancelled_at` | datetime | nullable | |
| `notes` | text | nullable | |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

Indexes:

- `(store_id, status)`
- `customer_id`
- unique `customer_request_line_id` (one active special order per line — enforce in model if multiples needed later)
- `product_variant_id`

Foreign keys: store, customer, customer_request_line, product_variant, vendor, created_by_user_id

---

## 3.6 `inventory_reservations`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `store_id` | bigint | FK NOT NULL | |
| `customer_id` | bigint | FK nullable | |
| `customer_request_line_id` | bigint | FK nullable | |
| `special_order_id` | bigint | FK nullable | |
| `product_variant_id` | bigint | FK NOT NULL | |
| `reservation_type` | string | NOT NULL | §4.4 |
| `status` | string | NOT NULL | §4.5 |
| `quantity_reserved` | integer | NOT NULL | > 0 |
| `quantity_fulfilled` | integer | NOT NULL, default 0 | |
| `quantity_released` | integer | NOT NULL, default 0 | |
| `purchase_order_line_id` | bigint | FK nullable | For incoming_reserve |
| `receipt_line_id` | bigint | FK nullable | Set when converted from receipt |
| `pos_transaction_line_id` | bigint | FK nullable | Set on fulfill |
| `reserved_by_user_id` | bigint | FK NOT NULL | |
| `reserved_at` | datetime | NOT NULL | |
| `expires_at` | datetime | nullable | Default reserved_at + 14 days for on_hand_hold |
| `ready_at` | datetime | nullable | |
| `fulfilled_at` | datetime | nullable | |
| `released_at` | datetime | nullable | |
| `release_reason` | string | nullable | §4.10 controlled values |
| `over_reserved` | boolean | NOT NULL, default false | Manager override flag |
| `override_authorized_by_user_id` | bigint | FK nullable | Customers-workspace over-reserve |
| `override_authorized_at` | datetime | nullable | |
| `override_reason` | text | nullable | |
| `notes` | text | nullable | |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

Indexes:

- `(store_id, product_variant_id, status)`
- `(store_id, status, reservation_type)` for queues
- `customer_id`
- `customer_request_line_id`
- `special_order_id`
- `purchase_order_line_id`
- `expires_at` (partial: active statuses)

Foreign keys: store, customer, customer_request_line, special_order, product_variant, purchase_order_line, receipt_line, pos_transaction_line, reserved_by_user_id, override_authorized_by_user_id

Check constraints:

```sql
quantity_reserved > 0
quantity_fulfilled >= 0
quantity_released >= 0
quantity_fulfilled + quantity_released <= quantity_reserved
```

---

## 3.7 `purchase_order_line_allocations`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `purchase_order_line_id` | bigint | FK NOT NULL | |
| `special_order_id` | bigint | FK NOT NULL | Customer-backed commitment |
| `customer_request_line_id` | bigint | FK nullable | Denormalized; must match special_order line when present |
| `quantity_allocated` | integer | NOT NULL | > 0 |
| `quantity_received` | integer | NOT NULL, default 0 | |
| `status` | string | NOT NULL | §4.6 |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

Indexes:

- `purchase_order_line_id`
- `special_order_id`
- `customer_request_line_id`

Model validation: `special_order_id` required. If `customer_request_line_id` present, must equal `special_order.customer_request_line_id`.

Check: `quantity_allocated > 0`, `quantity_received >= 0`, `quantity_received <= quantity_allocated`

Sum of `quantity_allocated` for a PO line must not exceed `purchase_order_lines.quantity_ordered` (service validation).

---

## 3.8 `receipt_line_allocations`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `receipt_line_id` | bigint | FK NOT NULL | |
| `purchase_order_line_allocation_id` | bigint | FK nullable | |
| `inventory_reservation_id` | bigint | FK nullable | |
| `customer_request_line_id` | bigint | FK nullable | |
| `special_order_id` | bigint | FK nullable | |
| `quantity_allocated` | integer | NOT NULL | > 0 |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

Indexes on all FK columns.

Check: `quantity_allocated > 0`

Sum of `quantity_allocated` per receipt line must not exceed `receipt_lines.quantity_accepted`.

---

## 3.9 `customer_contact_events`

| Field | Type | Constraints | Notes |
| --- | --- | --- | --- |
| `id` | bigint | PK | |
| `customer_id` | bigint | FK nullable | |
| `customer_request_id` | bigint | FK nullable | |
| `customer_request_line_id` | bigint | FK nullable | |
| `contact_method` | string | NOT NULL | §4.7 |
| `direction` | string | NOT NULL | `outbound`, `inbound` |
| `status` | string | NOT NULL | §4.8 |
| `summary` | text | NOT NULL | |
| `recorded_by_user_id` | bigint | FK NOT NULL | |
| `occurred_at` | datetime | NOT NULL | |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

Indexes: `customer_id`, `customer_request_id`, `occurred_at`

Require at least one of customer_id, customer_request_id.

---

# 4. Controlled Values

## 4.1 `customer_requests.status`

```text
new
researching
awaiting_customer_response
approved_to_order
ordered
partially_filled
ready_for_pickup
completed
cancelled
unfillable
```

## 4.2 `customer_request_lines.status`

```text
new
researching
matched
awaiting_customer_response
approved
ordered
partially_filled
ready_for_pickup
completed
cancelled
unfillable
```

## 4.3 `special_orders.status`

```text
pending_match
approved
ordered
partially_received
ready_for_pickup
completed
cancelled
unfillable
```

## 4.4 `inventory_reservations.reservation_type`

```text
on_hand_hold
incoming_reserve
special_order_reserve
```

## 4.5 `inventory_reservations.status`

```text
active
ready
fulfilled
released
expired
cancelled
```

**Active for quantity_reserved cache:** types `on_hand_hold`, `special_order_reserve` with status `active` or `ready`.

**Active for reserved_incoming:** type `incoming_reserve` with status `active` tied to open PO line.

## 4.6 `purchase_order_line_allocations.status`

```text
active
partially_received
received
cancelled
closed_short
```

## 4.7 `customer_contact_events.contact_method`

```text
phone
email
sms
in_person
other
```

## 4.8 `customer_contact_events.status`

```text
attempted
reached
left_message
no_answer
failed
not_needed
```

## 4.9 `customer_requests.source`

```text
in_store
phone
email
web
pos
staff
```

## 4.10 `inventory_reservations.release_reason`

```text
customer_cancelled
customer_declined
expired
staff_release
fulfilled_elsewhere
order_cancelled
unfillable
manager_override
data_correction
other
```

---

# 5. Migration Strategy

Split migrations by workstream for reviewable PRs (create `special_orders` before `inventory_reservations`):

| Migration | Tables / changes |
| --- | --- |
| 7A-A | `customers`, `customer_request_sequences`, `customer_requests`, `customer_request_lines` |
| 7A-B | `special_orders` |
| 7A-C | `inventory_balances.quantity_reserved`, `inventory_reservations` |
| 7A-D | `purchase_order_line_allocations` |
| 7A-E | `receipt_line_allocations` |
| 7A-F | `customer_contact_events` |
| 7A-G | `pos_transactions.customer_id`, `pos_transaction_lines` FKs |
| 7A-H | Permissions seeds (no schema) |

---

# 6. Seeds

- `db/seeds/phase7a_permissions.rb` — all permission keys from functional spec §16
- Idempotent; include in `db/seeds.rb`
- Demo customers/requests optional in development seeds (minimal)

---

# 7. Store Consistency Validations

Enforced in services; add model-level checks where practical. See functional spec §12.

---

# 8. Foreign Key Reference

Full list of Phase 7A foreign keys:

```text
customers.home_store_id → stores.id

customer_request_sequences.store_id → stores.id

customer_requests.store_id → stores.id
customer_requests.customer_id → customers.id
customer_requests.assigned_to_user_id → users.id
customer_requests.created_by_user_id → users.id

customer_request_lines.customer_request_id → customer_requests.id
customer_request_lines.catalog_item_id → catalog_items.id
customer_request_lines.product_id → products.id
customer_request_lines.product_variant_id → product_variants.id

special_orders.store_id → stores.id
special_orders.customer_id → customers.id
special_orders.customer_request_line_id → customer_request_lines.id
special_orders.product_variant_id → product_variants.id
special_orders.vendor_id → vendors.id
special_orders.created_by_user_id → users.id

inventory_reservations.store_id → stores.id
inventory_reservations.customer_id → customers.id
inventory_reservations.customer_request_line_id → customer_request_lines.id
inventory_reservations.special_order_id → special_orders.id
inventory_reservations.product_variant_id → product_variants.id
inventory_reservations.purchase_order_line_id → purchase_order_lines.id
inventory_reservations.receipt_line_id → receipt_lines.id
inventory_reservations.pos_transaction_line_id → pos_transaction_lines.id
inventory_reservations.reserved_by_user_id → users.id
inventory_reservations.override_authorized_by_user_id → users.id

purchase_order_line_allocations.purchase_order_line_id → purchase_order_lines.id
purchase_order_line_allocations.special_order_id → special_orders.id
purchase_order_line_allocations.customer_request_line_id → customer_request_lines.id

receipt_line_allocations.receipt_line_id → receipt_lines.id
receipt_line_allocations.purchase_order_line_allocation_id → purchase_order_line_allocations.id
receipt_line_allocations.inventory_reservation_id → inventory_reservations.id
receipt_line_allocations.customer_request_line_id → customer_request_lines.id
receipt_line_allocations.special_order_id → special_orders.id

customer_contact_events.customer_id → customers.id
customer_contact_events.customer_request_id → customer_requests.id
customer_contact_events.customer_request_line_id → customer_request_lines.id
customer_contact_events.recorded_by_user_id → users.id

pos_transactions.customer_id → customers.id

pos_transaction_lines.customer_request_line_id → customer_request_lines.id
pos_transaction_lines.special_order_id → special_orders.id
pos_transaction_lines.inventory_reservation_id → inventory_reservations.id
```

**Unchanged Phase 5 paths:**

```text
purchase_order_lines.purchase_request_line_id → purchase_request_lines.id
```

No direct customer FK on `purchase_order_lines` or `receipt_lines`.

**Service-level store consistency** (not all enforceable as FKs): see functional spec §12 (Store Consistency).
