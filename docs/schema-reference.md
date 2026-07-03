# ShelfStack Schema Reference

## Purpose

This document is a **schema index and maintenance guide**, not a complete table-by-table schema reference.

The full schema details live in phase-specific data model documents. **Authoritative runtime schema:** `db/schema.rb`.

> **v0.04 active model.** Operational tables below reflect post–v0.04-10 `db/schema.rb`. v0.03 ordering tables were **removed in v0.04-10** — do not reintroduce.

---

# v0.04 Operational Tables (curated)

Canonical chain tables developers need most often:

```text
products
product_identifiers
product_variants
demand_lines
demand_allocations
demand_line_sequences
sourcing_runs
sourcing_attempts
vendor_responses
purchase_orders
purchase_order_lines
purchase_order_line_demand_plans   # v0.04-13 planned coverage (draft PO)
receipts
receipt_lines
receipt_line_matches               # v0.04-13 multi-PO shipment matching
inventory_postings
inventory_ledger_entries
inventory_balances
pos_transactions
pos_transaction_lines   (includes demand_allocation_id for pickup)
customers
stored_value_*          (Phase 7B)
buyback_*               (Phase 7C)
```

Detail: [VERSION_0.04.md](design/VERSION_0.04.md), [domain-model.md](domain-model.md), milestone data models under [docs/v0.04/](v0.04/README.md).

---

# Retired v0.03 Ordering Tables (v0.04-10 — do not reintroduce)

Removed in migration `20260703002008_drop_v00410_legacy_ordering`:

```text
customer_requests
customer_request_lines
special_orders
purchase_requests
purchase_request_lines
inventory_reservations
purchase_order_line_allocations
receipt_line_allocations
```

Also removed: `customer_request_sequences` (if present), legacy FKs on POS lines for `inventory_reservation_id`.

Verify: `./dev/rails-docker env V00410_PHASE=g2 STRICT=1 bin/rails shelfstack:v00410:verify_legacy_ordering_retired`

---

# Retained Temporary (legacy admin)

Quarantined bibliographic surface — **not canonical v0.04 model**:

```text
catalog_items
catalog_item_identifiers
products.catalog_item_id   (optional legacy FK)
```

New item work uses `products` + `product_identifiers`. Future catalog cleanup milestone may drop these.

---

# Source Documents

The schema reference is assembled from phase data model documents. **Authoritative runtime schema:** `db/schema.rb`. Phase data models are design source of truth for migrations and constraints.

## Phase index

| Phase | Data model | Status |
| ----- | ---------- | ------ |
| 1 | [phase-1-data-model.md](specifications/phase-1-data-model.md) | Complete |
| 2 | [phase-2-data-model.md](specifications/phase-2-data-model.md) | Complete |
| 3 | [phase-3-data-model.md](specifications/phase-3-data-model.md) | Complete |
| 4 | [phase-4-data-model.md](specifications/phase-4-data-model.md) | Complete |
| 5 | [phase-5-data-model.md](specifications/phase-5-data-model.md) | Complete |
| 6 | [phase-6-data-model.md](specifications/phase-6-data-model.md) | Complete |
| 7A | [phase-7a-data-model.md](specifications/phase-7a-data-model.md) | Complete |
| 7B | [phase-7b-data-model.md](specifications/phase-7b-data-model.md) | Complete |
| 7C | [phase-7c-data-model.md](specifications/phase-7c-data-model.md) | Complete |
| 8 | [phase-8-data-model.md](specifications/phase-8-data-model.md) | Complete |
| 8.5-1 | [phase-8.5-1-data-model.md](specifications/phase-8.5-1-data-model.md) | Complete |
| 8.5-2a/b | [phase-8.5-2a-data-model.md](specifications/phase-8.5-2a-data-model.md), [phase-8.5-2b-data-model.md](specifications/phase-8.5-2b-data-model.md) | Complete |
| 8.5-3a | [phase-8.5-3a-data-model.md](specifications/phase-8.5-3a-data-model.md) | Complete |
| 8.5-4 | [phase-8.5-4-data-model.md](specifications/phase-8.5-4-data-model.md) | Complete |
| 9a / 9b | See phase 9 specs (minimal new tables; mostly reads operational data) | Complete |
| 10 | UX phases — no new domain tables in 10-A/B/C unless explicitly scoped | In progress |

Full document list:

```text
docs/specifications/phase-1-data-model.md
docs/specifications/phase-2-data-model.md
docs/specifications/phase-3-data-model.md
docs/specifications/phase-4-data-model.md
docs/specifications/phase-5-data-model.md
docs/specifications/phase-6-data-model.md
docs/specifications/phase-7a-data-model.md
docs/specifications/phase-7b-data-model.md
docs/specifications/phase-7c-data-model.md
docs/specifications/phase-8-data-model.md
docs/specifications/phase-8.5-1-data-model.md
docs/specifications/phase-8.5-2a-data-model.md
docs/specifications/phase-8.5-2b-data-model.md
docs/specifications/phase-8.5-3a-data-model.md
docs/specifications/phase-8.5-4-data-model.md
```

Each phase data model should include:

1. Schema table
2. Recommended indexes
3. Recommended constraints
4. Controlled values
5. Seed data
6. Migration notes

---

# Phase 1 Tables

Phase 1 introduces foundation tables.

**Implementation status:** Present in `db/schema.rb` as of 2025-06-10 (migration `20250610120000_create_phase1_foundation`). Design source of truth: [specifications/phase-1-data-model.md](specifications/phase-1-data-model.md).

```text
audit_events
permissions
roles
role_permissions
stores
users
user_role_assignments
workstations
user_sessions
workstation_assignments
```

## Phase 1 Focus

* Authentication
* Authorization
* Store context
* Workstation context
* User sessions
* Audit events
* Setup administration

---

# Phase 2 Tables

Phase 2 introduces classification and tax tables.

**Implementation status:** Present in `db/schema.rb` as of 2025-06-10 (migration `20250611120000_create_phase2_classification_and_tax`). Design source of truth: [specifications/phase-2-data-model.md](specifications/phase-2-data-model.md). Completion record: [implementation/phase-2-completion.md](implementation/phase-2-completion.md).

```text
tax_categories
store_tax_rates
store_tax_category_rates
departments
```

> **Note:** Phase 2 `categories` was removed in migration `20250616120000_classification_simplification_cleanup`. Operational classification uses `sub_departments` (Phase 3B). See [implementation/classification-cleanup.md](implementation/classification-cleanup.md).

## Phase 2 Focus

* Department reporting structure
* Tax classification
* Store tax rates
* Effective-dated tax mappings

---

# Phase 3 Tables

Phase 3 introduces catalog and sellable-item foundation tables.

**Implemented** in `db/migrate/20250612120000_create_phase3_catalog_products_variants.rb`. See [implementation/phase-3-completion.md](implementation/phase-3-completion.md).

```text
formats
display_locations
store_display_locations
products
product_identifiers
product_conditions
product_variants
vendors
```

**Retained temporary (legacy admin):** `catalog_items`, `catalog_item_identifiers` — see [Retained Temporary](#retained-temporary-legacy-admin) above. Not required for v0.04 product create paths.

## Phase 3 Focus

* Catalog metadata
* Identifiers
* Products
* Product variants
* SKUs
* Product conditions
* Display locations
* Vendor directory

---

# Phase 4 Tables

Phase 4 introduces inventory foundation tables.

**Implemented** per [specifications/phase-4-data-model.md](specifications/phase-4-data-model.md). See [implementation/phase-4-completion.md](implementation/phase-4-completion.md).

```text
inventory_reason_codes
inventory_locations
inventory_adjustments
inventory_adjustment_lines
inventory_postings
inventory_ledger_entries
inventory_balances
```

Phase 4 also restores:

```text
sub_departments.default_margin_target_bps
```

## Phase 4 Focus

* Grouped inventory postings
* Append-only ledger entries
* Store + variant balances
* Opening inventory and manual adjustments
* Valuation snapshots
* Reason codes and optional location context

---

# Schema Formatting Standard

Schema references should use this format:

```text
Table | Field | Type | Constraints | Notes
```

Example:

| Table          | Field           |   Type | Constraints                    | Notes                                        |
| -------------- | --------------- | -----: | ------------------------------ | -------------------------------------------- |
| `audit_events` | `actor_user_id` | bigint | references `users`, null false | User/system actor that performed the action. |

---

# Index Formatting Standard

Indexes should use this format:

```text
Table | Index | Type | Notes
```

Example:

| Table          | Index           | Type   | Notes                          |
| -------------- | --------------- | ------ | ------------------------------ |
| `audit_events` | `actor_user_id` | normal | Supports user activity review. |

---

# Constraint Formatting Standard

Constraints should use this format:

```text
Table | Constraint | Notes
```

Example:

| Table          | Constraint                   | Notes                             |
| -------------- | ---------------------------- | --------------------------------- |
| `audit_events` | `event_name` must be present | Prefer dot-separated event names. |

---

# Controlled Value Standard

Controlled values should be documented in the relevant phase data model.

Example:

```text
product_variants.inventory_behavior:
  standard_physical   # legacy; maps to inventory tracking (Phase 8)
  digital_asset
  drop_ship
  composite_recipe
  capacitated_service
  pure_financial
  non_inventory
```

Use controlled string values consistently across:

* Model validations
* Database check constraints where practical
* Seeds
* Tests
* Documentation
* UI labels

---

# Naming Standards

## Booleans

Use:

```text
active
virtual
digital
large_print
new_condition
primary_identifier
```

Avoid:

```text
is_active
is_virtual
is_digital
is_large_print
is_new
```

## Stable keys

Use `_key` for stable internal identifiers:

```text
permission_key
role_key
format_key
condition_key
```

## Datetime fields

Use `_at`:

```text
created_at
updated_at
last_login_at
locked_at
ended_at
```

## Date fields

Use `_on`:

```text
effective_on
ends_on
```

## Avoid `type`

Use explicit type names:

```text
user_type
scope_type
catalog_item_type
product_type
variation_type
identifier_type
```

---

# Migration Checklist

For every new table, confirm:

1. Primary key exists.
2. Required fields have null constraints.
3. Foreign keys are present.
4. Controlled fields have model validations.
5. Check constraints are added where practical.
6. Useful indexes are added.
7. Unique constraints match business rules.
8. Timestamps are included.
9. Deletion/inactivation behavior is documented.
10. Seed data is idempotent where applicable.
11. Audit events are defined for setup changes.
12. Tests cover validations and constraints.

---

# Deferred Schema Areas

These are expected future schema areas (beyond implemented phases):

```text
inventory_location_balances
inventory_location_movements
inventory_transfers
inventory_transfer_lines
cycle_counts
```

**Superseded future-table language:** Phase 6 docs referenced separate `gift_card_accounts` and `store_credit_accounts`. Phase 7B replaces these with the canonical stored value model below.

Phase 7B stored value tables (7B-2 implemented):

```text
stored_value_reason_codes
stored_value_accounts
stored_value_identifiers
stored_value_ledger_entries
stored_value_transfers
```

Phase 7B also extends `pos_tenders` with settlement columns (7B-1) and stored-value linkage columns (`stored_value_account_id`, `stored_value_identifier_id`, `generate_stored_value_identifier`, 7B-3). See [phase-7b-data-model.md](specifications/phase-7b-data-model.md).

Phase 5 tables (implemented):

```text
product_vendors
product_variant_vendors
vendor_terms
purchase_orders
purchase_order_lines
receipts
receipt_lines
receiving_discrepancies
returns_to_vendor
return_to_vendor_lines
inventory_balances.moving_average_unit_cost_cents
product_variants.returnability_status
```

**Retired v0.03:** `purchase_requests` / `purchase_request_lines` — removed v0.04-10. Manual TBO uses `demand_lines`.

Phase 7A / v0.04 demand tables (implemented):

```text
customers
demand_lines
demand_allocations
demand_line_sequences
customer_contact_events
```

**Retired v0.03 Phase 7A tables** — see [Retired v0.03 Ordering Tables](#retired-v03-ordering-tables-v004-10--do-not-reintroduce).

Phase 7A extends `inventory_balances.quantity_reserved` and `pos_transaction_lines.demand_allocation_id` for pickup fulfillment.

Phase 6 tables (implemented):

```text
pos_register_sessions
pos_cash_movements
pos_transactions
pos_transaction_lines
pos_tenders
pos_receipts
pos_authorizations
pos_voids
pos_discount_applications
pos_discount_allocations
discount_reasons
tax_exception_reasons
pos_tax_exemptions
pos_line_tax_overrides
```

Phase 8.5-2 extends `pos_transaction_lines` with `normal_tax_*`, `applied_tax_source`, and `pos_transactions.normal_tax_cents`.

Phase 8.5-1 extends `departments`, `sub_departments`, `products`, and `product_variants` with `discountable` (default `true`).

Phase 6 extends `inventory_postings.posting_type` with `pos_transaction` and `pos_void`.

See phase data model documents in the index above for table-level detail. [architecture-map.md](architecture-map.md) maps domains to key tables.

