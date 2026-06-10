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
| Phase 2 | Classification and Taxes        | Departments, categories, tax categories, store tax rates, and effective-dated tax mappings.                  |
| Phase 3 | Catalog, Products, and Variants | Catalog metadata, identifiers, products, product variants, SKUs, conditions, display locations, and vendors. |
| Phase 4 | Inventory Foundation            | Inventory ledger, stock balances, stock movements, and inventory value.                                      |
| Phase 5 | Purchasing and Receiving        | Vendors, purchase orders, receiving, supplier terms, vendor costs, and returns to vendor.                    |
| Phase 6 | POS Foundation                  | Sales, returns, line items, tax calculation, tenders, receipts, and session/workstation-aware POS behavior.  |
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

# Phase 2: Departments, Categories, and Taxes

## Purpose

Phase 2 establishes the classification and tax setup layer.

It answers:

> How are future sellable items classified for reporting, pricing defaults, and tax behavior?

## Major Capabilities

* Departments
* Categories
* Tax categories
* Store tax rates
* Store tax category rates
* Effective-dated tax lookup
* Category default pricing model
* Category default margin target
* Category default supplier discount
* Category default tax category
* Phase 2 setup permissions
* Phase 2 audit events
* Bookstore-oriented seed data

## Key Outcomes

At the end of Phase 2:

1. Departments exist as top-level sales/reporting buckets.
2. Department numbers are three-character zero-padded strings.
3. Categories belong to departments.
4. Categories provide defaults for future sellable items.
5. Tax categories classify item taxability.
6. Store tax rates define store-specific tax percentages.
7. Store tax category rates map tax categories to store tax rates by effective date.
8. Tax lookup returns exactly one active rate for a store, tax category, and date.
9. Phase 2 setup screens are permission-controlled.
10. Phase 2 setup changes are audited.

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

Phase 4 should establish the inventory ledger and stock balance foundation.

It should answer:

> What stock exists, where is it, how did it get there, and what is its value?

## Expected Capabilities

* Inventory ledger
* Stock movement types
* Stock balances
* Quantity on hand
* Quantity available
* Quantity committed/held
* Cost tracking
* Inventory value
* Adjustments
* Inventory audit events
* Store-level stock views
* Product variant stock views

## Expected Design Direction

Inventory should operate at the product variant level.

```text
Product Variant → Inventory Ledger → Stock Balance
```

Inventory records should be append-oriented. Stock balances may be derived or cached from ledger events.

## Possible Tables

```text
inventory_ledger_entries
stock_balances
inventory_adjustments
inventory_adjustment_lines
stock_movement_types
```

## Major Risks

* Average cost calculation
* Handling used inventory
* Handling consignment inventory
* Handling non-inventory product variants
* Preventing stock quantity drift
* Preserving historical cost/value

---

# Phase 5: Purchasing and Receiving

## Purpose

Phase 5 should establish vendor purchasing, receiving, supplier costs, and returns to vendor.

It should answer:

> How does inventory enter the store, what did it cost, and which vendor supplied it?

## Expected Capabilities

* Vendor-product sourcing
* Vendor item numbers
* Purchase orders
* Purchase order lines
* Receiving
* Receiving discrepancies
* Supplier discount/cost defaults
* Returnability
* Vendor terms
* Returns to vendor
* Receiving audit events

## Expected Design Direction

Purchasing and receiving should operate at the product variant level.

Vendor relationships should not be stored directly on products or variants as a single fixed vendor because many products may be available from multiple suppliers.

## Possible Tables

```text
product_variant_vendors
purchase_orders
purchase_order_lines
receipts
receipt_lines
vendor_terms
returns_to_vendor
return_to_vendor_lines
```

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

Phase 6 should establish core POS sales behavior.

It should answer:

> What was sold, at what price, with what tax, through which workstation, by which user, and how was payment taken?

## Expected Capabilities

* Sales
* Sale lines
* Return lines
* Taxes
* Tenders
* Receipts
* Register/workstation context
* Product variant lookup by SKU
* Tax calculation
* Price snapshotting
* Name/SKU snapshotting
* Sale audit events

## Expected Design Direction

POS sale lines should snapshot mutable product data.

Future sale lines should store:

* Product SKU snapshot
* Variant SKU snapshot
* Product name snapshot
* Variant name snapshot
* Price snapshot
* Tax category snapshot
* Tax rate snapshot
* Department/category snapshot
* Store/workstation/user context

## Possible Tables

```text
sales
sale_lines
sale_tenders
sale_taxes
receipt_events
return_reasons
```

## Major Risks

* Tax accuracy
* Historical snapshot preservation
* Product/variant name changes after sale
* SKU changes after sale
* Locked sessions and workstation context
* Offline POS requirements

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
stock_transfers
stock_transfer_lines
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

```text
Phase 1 ✓  →  Phase 2 (active)  →  Phase 3
```

Implementation record: [docs/implementation/phase-1-completion.md](implementation/phase-1-completion.md).

Once Phase 3 is complete, the next major design decision is whether to proceed with:

1. Inventory ledger foundation, or
2. Purchasing/receiving foundation, or
3. Minimal POS foundation.

The recommended next phase is **Inventory Foundation**, because purchasing, receiving, and POS all depend on reliable stock movement behavior.
