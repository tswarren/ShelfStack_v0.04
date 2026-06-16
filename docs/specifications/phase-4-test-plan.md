# Phase 4 Test Plan

## Purpose

This document defines the test coverage required for ShelfStack Phase 4.

Phase 4 introduces the inventory ledger, store-level balances, opening inventory, manual adjustments, valuation snapshots, read surfaces, and integrity tooling.

Functional behavior: [phase-4-inventory-foundation-spec.md](phase-4-inventory-foundation-spec.md)

Data model: [phase-4-data-model.md](phase-4-data-model.md)

---

# 1. Test Categories

| Category | Purpose |
| --- | --- |
| Model tests | Validate fields, relationships, controlled values, and constraints. |
| Service tests | Validate eligibility, cost estimation, posting, balance updates, rebuild, and integrity checks. |
| Authorization tests | Validate Phase 4 permission enforcement and store scoping. |
| Request/controller tests | Validate inventory workspace, setup CRUD, and adjustment workflows. |
| Integration tests | Validate end-to-end draft → post → balance → ledger flows. |
| Audit tests | Validate Phase 4 audit event creation. |
| Seed tests | Validate idempotent Phase 4 seeds and restored margin column. |
| Rake/task tests | Validate rebuild and integrity-check tasks. |

---

# 2. Inventory Reason Code Tests

## 2.1 Reason Code Can Be Created

Expected:

* Reason code saves with unique `reason_key` and `name`.
* Audit event is created.

## 2.2 Reason Key and Name Are Unique

Expected:

* Duplicate `reason_key` or `name` is rejected.

## 2.3 Inactive Reason Code Cannot Be Assigned to New Adjustment Line

Expected:

* Line validation blocks inactive reason code on create/update.

---

# 3. Inventory Location Tests

## 3.1 Location Can Be Created Per Store

Expected:

* Location saves with `store_id`, `name`, and `short_name`.
* Audit event is created.

## 3.2 Short Name Is Unique Per Store

Expected:

* Duplicate `(store_id, short_name)` is rejected.
* Same `short_name` may exist on different stores.

## 3.3 Inactive Location Cannot Be Assigned to New Line

Expected:

* Adjustment line validation blocks inactive location.

---

# 4. Inventory Adjustment Tests

## 4.1 Draft Adjustment Can Be Created

Expected:

* Draft saves with `adjustment_type`, `store_id`, and `status = draft`.
* Audit event `inventory_adjustment.created`.

## 4.2 Adjustment Type Controlled Values

Allowed:

```text
opening_inventory
manual_adjustment
```

Expected:

* Allowed values pass.
* Invalid values fail.

## 4.3 Status Controlled Values

Allowed:

```text
draft
posted
cancelled
```

Expected:

* Posted adjustment cannot return to draft.
* Cancelled draft cannot be posted.

## 4.4 Draft Lines Require Non-Zero Quantity at Post

Expected:

* Draft may save with zero quantity temporarily if UI allows.
* Post rejects lines with `quantity_delta = 0`.

## 4.5 Posted Adjustment Is Immutable

Expected:

* Posted adjustment header and lines cannot be edited.
* Posted adjustment cannot be cancelled.

## 4.6 Cancel Draft

Expected:

* Status becomes `cancelled`.
* No posting or ledger entries created.
* Audit event `inventory_adjustment.cancelled`.

---

# 5. Inventory Eligibility Tests

## 5.1 Only `standard_physical` Variants May Post

Expected:

* `Inventory::Eligibility.eligible?` returns true only for `standard_physical`.
* Posting rejects ineligible variants with clear error.

## 5.2 Condition Does Not Affect Eligibility

Expected:

* Used, signed, or remainder variants with `standard_physical` may post.

## 5.3 Ineligible Behaviors Rejected

For each non-eligible `inventory_behavior`:

```text
digital_asset
drop_ship
composite_recipe
capacitated_service
pure_financial
non_inventory
```

Expected:

* Post is rejected.

---

# 6. Cost Estimation Tests

## 6.1 Manual Line Cost Takes Precedence

Expected:

* When `unit_cost_cents` is present on line, `cost_source = manual`.

## 6.2 Margin Estimate From Subdepartment

Expected:

* When line cost is blank and subdepartment has `default_margin_target_bps`, estimated cost uses variant selling price and margin.
* `cost_source = margin_estimate`.

## 6.3 Unknown Cost When Margin Missing

Expected:

* When line cost is blank and margin is unavailable, cost snapshots are null or zero per spec and `cost_source = unknown`.

## 6.4 Retail Snapshot From Variant Selling Price

Expected:

* `unit_retail_cents` from variant `selling_price_cents`.
* `retail_source = variant_selling_price` when price present.

## 6.5 Restored `default_margin_target_bps` Validation

Expected:

* Values outside 0–10000 are rejected.
* Null is allowed.

---

# 7. Posting Service Tests

## 7.1 Post Creates Posting and Ledger Entries

Expected:

* One `inventory_posting` per posted adjustment.
* One ledger entry per adjustment line.
* Ledger `store_id` and `product_variant_id` match line.
* `movement_type` matches adjustment type rules.

## 7.2 Post Updates Balance Atomically

Expected:

* `inventory_balances` row created or updated in same transaction.
* `quantity_on_hand` equals prior balance plus `quantity_delta`.
* `quantity_available` equals `quantity_on_hand` in Phase 4.

## 7.3 Post Is Idempotent

Expected:

* Re-posting same source adjustment fails or no-ops per unique `(source_type, source_id)`.
* Duplicate `idempotency_key` rejected.

## 7.4 Negative On-Hand Allowed

Expected:

* Posting a line that drives balance negative succeeds.
* Negative exception audit may fire when crossing zero.

## 7.5 Direct Balance Mutation Blocked

Expected:

* Application code outside `Inventory::BalanceUpdater` does not update balances in tests that simulate improper paths (model callback guards or service-only API).

## 7.6 Optional Location and Reason Preserved

Expected:

* Ledger entry copies optional `inventory_location_id` and `inventory_reason_code_id`.

---

# 8. Inventory Balance Tests

## 8.1 Unique Balance Per Store and Variant

Expected:

* Duplicate `(store_id, product_variant_id)` rejected.

## 8.2 Balance Matches Ledger Sum

Expected:

* After post, `quantity_on_hand = SUM(ledger.quantity_delta)` for store + variant.

## 8.3 Value Fields Updated

Expected:

* `inventory_cost_value_cents` and `inventory_retail_value_cents` reflect posted snapshots per spec.

---

# 9. Opening Inventory Tests

## 9.1 Opening Inventory Posts With Correct Types

Expected:

* `adjustment_type = opening_inventory`
* `posting_type = opening_inventory`
* `movement_type = opening_balance`

## 9.2 Opening Inventory Creates Positive Balances

Expected:

* Store variant balances reflect opening quantities.

---

# 10. Manual Adjustment Tests

## 10.1 Positive and Negative Deltas

Expected:

* Increase and decrease lines post correctly.

## 10.2 Multi-Line Adjustment

Expected:

* One posting with multiple ledger entries updates multiple balances.

---

# 11. Authorization Tests

## 11.1 Inventory Access Permission

Expected:

* User without `inventory.access` cannot reach `/inventory`.

## 11.2 View Balances

Expected:

* `inventory.balances.view` required for store inventory index.

## 11.3 Adjustment Permissions

Expected:

* Create/edit requires `inventory.adjustments.create`.
* Post requires `inventory.adjustments.post`.
* Cancel requires `inventory.adjustments.cancel`.
* View requires `inventory.adjustments.view`.

## 11.4 Ledger and Negative Exceptions

Expected:

* `inventory.ledger.view` required for variant ledger history.
* `inventory.negative_exceptions.view` required for negative report.

## 11.5 Enterprise Rollup

Expected:

* `inventory.enterprise.view` required to view cross-store rollup.

## 11.6 Admin Rebuild

Expected:

* `inventory.admin.rebuild_balances` required for rebuild/integrity tasks.

## 11.7 Setup Permissions

Expected:

* Reason code and location setup require matching `setup.inventory_*` permissions.

## 11.8 Store Scoping

Expected:

* Store-scoped role assignments limit adjustment and balance views to permitted stores.

---

# 12. Audit Event Tests

## 12.1 Adjustment Lifecycle Events

Expected audit events:

```text
inventory_adjustment.created
inventory_adjustment.updated
inventory_adjustment.cancelled
inventory_adjustment.posted
inventory_posting.created
```

## 12.2 Negative Balance Events

Expected:

* `inventory_balance.negative` when balance crosses below zero.
* `inventory_balance.cleared_negative` when balance returns to zero or positive.

## 12.3 Integrity Tooling Events

Expected:

* `inventory.balance_rebuild`
* `inventory.integrity_check`

## 12.4 Audit Context

Expected:

* Events include actor, store, session, and workstation where applicable.

---

# 13. Read Surface Tests

## 13.1 Store Inventory Index

Expected:

* Lists balances for current store with variant SKU, name, quantities, and values.
* Supports search/filter basics per spec.

## 13.2 Variant Ledger History

Expected:

* Shows postings and ledger entries for store + variant.

## 13.3 Product Rollup on Items Detail

Expected:

* Product detail shows per-store or current-store quantity rollup across eligible variants.

## 13.4 Negative Inventory Report

Expected:

* Lists rows where `quantity_on_hand < 0`.

## 13.5 Enterprise Rollup

Expected:

* Authorized users see quantities aggregated across permitted stores.

## 13.6 Adjustment Detail

Expected:

* Draft shows editable lines.
* Posted shows linked posting and ledger entries.

---

# 14. Integrity Tooling Tests

## 14.1 Rebuild Balances

Expected:

* `Inventory::RebuildBalances` recomputes all balances from ledger.
* Mismatched cached balances corrected.
* Audit event created.

## 14.2 Balance Integrity Check

Expected:

* `Inventory::BalanceIntegrityCheck` reports mismatches without mutating data.
* Exit code or summary indicates pass/fail for rake task.

---

# 15. Seed Tests

## 15.1 Reason Codes Idempotent

Expected:

* Running Phase 4 seeds twice does not duplicate reason codes.

## 15.2 Permissions Idempotent

Expected:

* Phase 4 permissions and role assignments seed without duplication.

## 15.3 Subdepartment Margin Column

Expected:

* CSV or seed helper populates `default_margin_target_bps` where configured.
* Re-seed updates values without duplicate subdepartments.

---

# 16. Deferred Behavior (No Phase 4 Tests)

Do not add Phase 4 tests for:

* Purchase orders and receiving
* POS sales and returns
* Transfers and in-transit inventory
* Location-level balance invariants
* Reservations and committed quantity
* Average cost / COGS
* Copy-level inventory
* Reversal posting UI

---

# 17. Test File Organization (Recommended)

```text
test/models/inventory_*
test/services/inventory/*
test/integration/inventory_*
test/integration/phase4_authorization_test.rb
test/tasks/inventory_*
```

Use `test/support/phase3_test_helper.rb` or a Phase 4 helper for standard physical variants, stores, and posting fixtures.
