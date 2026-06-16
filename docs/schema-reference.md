# ShelfStack Schema Reference

## Purpose

This document is an index and maintenance guide for the ShelfStack schema reference.

The full schema details are maintained in phase-specific data model documents.

---

# Source Documents

The schema reference is assembled from:

```text
docs/specifications/phase-1-data-model.md
docs/specifications/phase-2-data-model.md
docs/specifications/phase-3-data-model.md
docs/specifications/phase-4-data-model.md
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
catalog_items
catalog_item_identifiers
display_locations
store_display_locations
products
product_conditions
product_variants
vendors
```

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
  standard_physical
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

These are expected future schema areas (beyond Phase 4):

```text
inventory_location_balances
inventory_location_movements
inventory_transfers
inventory_transfer_lines
inventory_reservations
product_variant_vendors
purchase_orders
purchase_order_lines
receipts
receipt_lines
sales
sale_lines
sale_tenders
sale_taxes
cycle_counts
```

These should not be added until their workflows are defined.
