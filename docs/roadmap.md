# ShelfStack Roadmap

## Purpose

This document summarizes ShelfStack’s development roadmap.

It explains the purpose of each phase, the major capabilities introduced, and how each phase builds toward a complete bookstore-focused catalog, inventory, purchasing, and point-of-sale system.

Detailed implementation specifications live in the phase-specific roadmap, functional specification, data model, and test plan documents.

---

# Roadmap Summary

ShelfStack is being developed in phases.

Each phase should produce a coherent working foundation for later phases, rather than a disconnected set of tables or screens.

| Phase   | Focus                           | Outcome                                                                                                      |
| ------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Phase 1 | Foundation                      | Users, roles, permissions, stores, workstations, sessions, and audit events.                                 |
| Phase 2 | Classification and Taxes        | Departments, subdepartments, tax categories, store tax rates, and effective-dated tax mappings.              |
| Phase 3 | Catalog, Products, and Variants | Catalog metadata, identifiers, products, product variants, SKUs, conditions, display locations, and vendors. |
| Phase 4 | Inventory Foundation            | Inventory ledger, store balances, adjustments, valuation snapshots, and inventory read surfaces.             |
| Phase 5 | Purchasing and Receiving        | Vendors, purchase orders, receiving, supplier terms, vendor costs, and returns to vendor.                    |
| Phase 6 | POS Foundation                  | Register sessions, POS transactions, tax/tender snapshots, inventory posting, void reversals, receipts, and workstation-aware POS behavior. |
| Phase 7 | Advanced Store Operations       | Transfers, adjustments, cycle counts, special orders, holds, and operational workflows.                      |
| Phase 8 | Reporting and Accounting        | Sales reporting, inventory valuation, tax reporting, GL export, and operational dashboards.                  |

Later phases may be split or reordered as implementation details become clearer.

---

# Phase 1: Foundation

## Purpose

Phase 1 establishes the operational foundation for ShelfStack.

It answers:

> Who is using the system, where are they working, what are they allowed to do, and how is their activity audited?

## Major Capabilities

* Users
* Roles
* Permissions
* Role assignments
* Stores
* Workstations
* Browser-to-workstation assignments
* User sessions
* Session locking/unlocking
* Forced session termination
* Audit events
* Setup navigation
* Foundation seed data

## Key Outcomes

At the end of Phase 1:

1. Users can log in and out.
2. Sessions can be locked, unlocked, expired, ended, or force-ended.
3. Workstation and store context are resolved server-side.
4. Permissions are resolved from roles and role assignments.
5. Roles may be global or store-scoped.
6. Setup screens are permission-controlled.
7. Audit events are created for security and setup changes.
8. The application shell displays user, store, workstation, and session context.

**Status:** Implemented. See [implementation/phase-1-completion.md](implementation/phase-1-completion.md).

## Detailed Documents

```text
docs/roadmap/phase-1-foundation.md
docs/specifications/phase-1-foundation-spec.md
docs/specifications/phase-1-data-model.md
docs/specifications/phase-1-test-plan.md
```

---

# Phase 2: Departments, Subdepartments, and Taxes

## Purpose

Phase 2 establishes the classification and tax setup layer.

It answers:

> How are future sellable items classified for reporting, pricing defaults, and tax behavior?

> **Note:** Phase 2 originally delivered a `categories` table. That table was removed in the 2025-06 classification simplification; operational defaults now live on `sub_departments`. See [implementation/classification-cleanup.md](implementation/classification-cleanup.md).

## Major Capabilities

* Departments
* Subdepartments (operational merchandise behavior buckets)
* Tax categories
* Store tax rates
* Store tax category rates
* Effective-dated tax lookup
* Subdepartment default pricing model
* Subdepartment default margin target
* Subdepartment default supplier discount
* Subdepartment default tax category
* Phase 2 setup permissions
* Phase 2 audit events
* Bookstore-oriented seed data

## Key Outcomes

At the end of Phase 2:

1. Departments exist as top-level sales/reporting buckets.
2. Department numbers are three-character zero-padded strings.
3. Subdepartments belong to departments and provide operational defaults for sellable items.
4. Subdepartments provide defaults for future product variants.
5. Tax categories classify item taxability.
6. Store tax rates define store-specific tax percentages.
7. Store tax category rates map tax categories to store tax rates by effective date.
8. Tax lookup returns exactly one active rate for a store, tax category, and date.
9. Phase 2 setup screens are permission-controlled.
10. Phase 2 setup changes are audited.

**Status:** Implemented. See [implementation/phase-2-completion.md](implementation/phase-2-completion.md).

## Detailed Documents

```text
docs/roadmap/phase-2-departments-categories-taxes.md
docs/specifications/phase-2-classification-and-tax-spec.md
docs/specifications/phase-2-data-model.md
docs/specifications/phase-2-test-plan.md
```

---

# Phase 3: Catalog, Products, and Product Variants

## Purpose

Phase 3 establishes the catalog and sellable SKU foundation.

It answers:

> What is this item, how does the store sell it, and what is the sellable SKU?

## Major Capabilities

* Formats
* Catalog items
* Catalog item identifiers
* Local identifier generation
* ISBN-10 to ISBN-13 conversion
* Identifier validation and warnings
* Creator metadata parsing
* Subject metadata parsing
* Products
* Product conditions
* Product variants
* Product SKU generation
* Variant SKU generation
* Product and variant name rendering
* Display locations
* Store display locations
* Vendor directory
* Phase 3 setup permissions
* Phase 3 audit events

## Key Outcomes

At the end of Phase 3:

1. Catalog items can describe books, media, periodicals, sidelines, and other items.
2. Every catalog item has at least one active identifier.
3. Every catalog item has exactly one active primary identifier.
4. Product SKUs are required base SKUs.
5. Product variants are actual sellable SKUs.
6. Variant SKUs are generated from product SKU plus condition and/or attribute components.
7. Product names default from catalog titles or user entry.
8. Variant names default from product name plus condition and/or attributes.
9. Display locations support merchandising setup.
10. Vendors exist as a basic directory.
11. Phase 3 setup screens are permission-controlled.
12. Phase 3 setup changes are audited.

## Detailed Documents

```text
docs/roadmap/phase-3-catalog-products-variants.md
docs/specifications/phase-3-catalog-products-variants-spec.md
docs/specifications/phase-3-data-model.md
docs/specifications/phase-3-test-plan.md
```

---

# Phase 4: Inventory Foundation

## Purpose

Phase 4 establishes the inventory ledger and store-level balance foundation.

It answers:

> What quantity of each product variant does each store have, how did it change, and what is its estimated value?

Detailed scope: [roadmap/phase-4-inventory-foundation.md](roadmap/phase-4-inventory-foundation.md)

## Expected Capabilities

* Grouped inventory postings and append-only ledger entries
* Cached `inventory_balances` at `store_id + product_variant_id`
* Quantity on hand and quantity available (initially equal)
* Negative on-hand support
* Opening inventory and manual adjustments
* Cost and retail valuation snapshots
* Inventory reason codes and optional inventory locations (context only)
* Inventory audit events
* Store, variant, product, and enterprise read surfaces
* Balance rebuild and integrity-check tooling

## Expected Design Direction

Inventory operates at the product variant + store level.

```text
Product Variant → Inventory Posting → Inventory Ledger Entries → Inventory Balance
```

Only variants with `inventory_behavior = standard_physical` are ledger-eligible in Phase 4.

Balances are cached projections from posted ledger entries. Application code must post through `Inventory::Post`, not mutate balances directly.

## Phase 4 Tables

```text
inventory_postings
inventory_ledger_entries
inventory_balances
inventory_adjustments
inventory_adjustment_lines
inventory_reason_codes
inventory_locations
```

Phase 4 also restores `sub_departments.default_margin_target_bps` for cost estimation.

## Documentation

```text
docs/roadmap/phase-4-inventory-foundation.md
docs/specifications/phase-4-inventory-foundation-spec.md
docs/specifications/phase-4-data-model.md
docs/specifications/phase-4-test-plan.md
```

## Major Risks

* Preventing balance drift from direct mutation
* Idempotent posting from adjustments
* Cost estimation when actual cost is unknown
* Handling ineligible variant behaviors
* Store-scoped authorization on write paths

---

# Phase 5: Purchasing and Receiving — **Complete**

Phase 5 was completed on 2026-06-10. See [docs/implementation/phase-5-completion.md](docs/implementation/phase-5-completion.md).

Normative requirements:

```text
docs/roadmap/phase-5-purchasing-and-receiving.md
docs/specifications/phase-5-purchasing-and-receiving-spec.md
docs/specifications/phase-5-data-model.md
docs/specifications/phase-5-test-plan.md
```

Delivered: vendor sourcing, purchase requests (TBO), purchase orders, receiving with moving average cost, returns to vendor, Orders workspace (`/orders`), setup sourcing CRUD, permissions, audit events, and seeds.

---

## Major Risks

* Multiple vendors for the same item
* Vendor-specific item numbers
* Returnable versus non-returnable inventory
* Supplier discounts
* Net cost versus list-price discount purchasing
* Partial receiving
* Backorders and cancellations

---

# Phase 6: POS Foundation

## Purpose

Phase 6 establishes core point-of-sale behavior.

It should answer:

> What was sold or returned, at what price, with what tax, through which workstation, by which user, on which business date, and how was payment taken?

## Documentation

Detailed scope, locked decisions, and exit criteria:

```text
docs/roadmap/phase-6-pos-foundation.md
docs/specifications/phase-6-pos-foundation-spec.md
docs/specifications/phase-6-data-model.md
docs/specifications/phase-6-test-plan.md
```

## Expected Capabilities

* Register sessions and cash movements
* Draft, suspended, completed, and voided POS transactions
* Sale, return, and exchange (mixed signed lines)
* Open-ring lines and open-ring returns
* Tax and tender snapshots
* Workstation-scoped transaction numbering
* Register-session business dates
* Inventory posting via `Inventory::Post` (`pos_transaction`, `pos_void`)
* Completed void reversal workflow (`pos_voids`)
* Receipts and snapshot reports
* Full `pos.*` permissions and audit events

## Design Direction

* Use `pos_*` tables, not `sales` / `sale_*`.
* Snapshot mutable product, price, and tax data on lines at completion.
* Do not store `inventory_posting_id` on `pos_transactions`; use polymorphic posting sources.
* One inventory posting per completed transaction; void reversals use separate `PosVoid` source.

## Major Risks

* Tax accuracy and business-date handling
* Historical snapshot preservation
* Return quantity validation across partial returns
* Register session and suspended-transaction edge cases
* Void reversal correctness (inventory and tenders)
* Offline POS requirements (deferred)

---

# Phase 7: Advanced Store Operations

## Purpose

Phase 7 should expand operational workflows around inventory and customer-facing store activity.

## Expected Capabilities

* Store transfers
* Cycle counts
* Physical inventory
* Holds
* Special orders
* Buybacks
* Consignment
* Damaged inventory
* Customer requests
* Internal notes/tasks

## Possible Tables

```text
inventory_transfers
inventory_transfer_lines
cycle_counts
cycle_count_lines
holds
special_orders
buybacks
consignment_accounts
```

## Major Risks

* Workflow complexity
* State transitions
* Inventory reservation behavior
* Partial fulfillment
* Buyback pricing rules
* Consignment liability tracking

---

# Phase 8: Reporting and Accounting

## Purpose

Phase 8 should provide reporting, analysis, tax summaries, inventory valuation, and accounting export support.

## Expected Capabilities

* Sales reports
* Department/category reports
* Tax reports
* Inventory valuation
* Stock aging
* Purchase reports
* Vendor reports
* Audit reports
* GL/accounting export

## Expected Design Direction

Reports should prefer immutable transaction snapshots and ledger entries rather than mutable setup records.

Departments, categories, tax rates, and product names should be snapshot where needed in transaction history.

## Major Risks

* Historical accuracy
* Reconciliation
* Tax reporting
* Inventory valuation
* Cost methodology
* Performance on large datasets

---

# Roadmap Principles

## 1. Build foundations before workflows

Each phase should create the stable setup and data structure required by later workflows.

## 2. Keep historical data stable

Future transaction and inventory records should snapshot mutable setup data.

## 3. Prefer append-only ledgers for financial/stock movement

Inventory and audit history should not be silently overwritten.

## 4. Keep UI practical

ShelfStack should support detailed metadata without making routine store operations slow.

## 5. Defer complexity until required

Do not normalize every metadata concept too early. Use JSONB where it provides useful flexibility, then normalize later when workflows justify it.

---

# Current Priority

**Phase 1 (Foundation) is complete** as of 2025-06-10.

**Phase 2 (Departments, Categories, and Taxes) is complete** as of 2025-06-10.

**Phase 3 (Catalog, Products, and Product Variants) is complete** as of 2026-06-10 (manual QA sign-off).

```text
Phase 1 ✓  →  Phase 2 ✓  →  Phase 3 ✓  →  Phase 4 (inventory foundation) ← current priority
```

Implementation records:

- [docs/implementation/phase-1-completion.md](implementation/phase-1-completion.md)
- [docs/implementation/phase-2-completion.md](implementation/phase-2-completion.md)
- [docs/implementation/phase-3-completion.md](implementation/phase-3-completion.md)

**Next phase:** **Inventory Foundation** — purchasing, receiving, and POS all depend on reliable stock movement behavior. See [Phase 4: Inventory Foundation](#phase-4-inventory-foundation) in this document.
