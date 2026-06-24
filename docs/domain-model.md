# ShelfStack Domain Model

## Purpose

This document explains the major business concepts in ShelfStack and how they relate to each other.

It is intended to help developers, contributors, and future maintainers understand the product domain before reading the detailed data model and phase specifications.

---

# 1. Foundation Domain

The foundation domain establishes who is using ShelfStack, where they are working, and what they are allowed to do.

## Core Concepts

| Concept                | Meaning                                                         |
| ---------------------- | --------------------------------------------------------------- |
| User                   | Application user or system actor.                               |
| Role                   | Named bundle of permissions.                                    |
| Permission             | Specific application capability.                                |
| Role Assignment        | Assignment of a role to a user, globally or within a store.     |
| Store                  | Physical store/location using ShelfStack.                       |
| Workstation            | Store-level computer/register/service desk/back-office station. |
| Workstation Assignment | Browser-to-workstation assignment using a secure token.         |
| User Session           | Persisted login/session lifecycle record.                       |
| Audit Event            | Append-only record of significant application activity.         |

## Key Relationships

```text
User → User Role Assignment → Role → Role Permission → Permission
Store → Workstation → Workstation Assignment
User → User Session
Audit Event → Actor/User + Auditable Record + Context
```

## Important Rules

* Users receive permissions through roles.
* Role assignments may be global or store-scoped.
* Store-scoped assignments apply only in the matching store context.
* Workstation context is resolved server-side from a browser assignment token.
* Audit events record security, setup, and system activity.

---

# 2. Classification and Tax Domain

The classification domain defines how sellable items are grouped for reporting, operational defaults, shelving/topic organization, and taxation.

## Core Concepts

| Concept | Meaning |
| --- | --- |
| Department | Top-level sales/reporting bucket with GL account code. |
| SubDepartment | Operational merchandise behavior bucket (pricing model, margin, supplier discount, tax category, returnability). Required on every product variant. |
| Category Scheme | Named topical classification system (for example, `store_categories`, BISAC). |
| Category Node | A node within a category scheme hierarchy (for example, Fiction, Biography). Store categories are **not** the merchandise behavior bucket. |
| Display Location | Store-facing shelf/signage location; distinct from inventory locations. |
| Tax Category | Global taxability classification for items. |
| Store Tax Rate | Store-specific tax rate. |
| Store Tax Category Rate | Effective-dated mapping of store + tax category to store tax rate. |

## Key Relationships

```text
Department → SubDepartment
SubDepartment → Default Tax Category
Catalog Item → Store Category (CategoryNode in store_categories scheme)
Product Variant → SubDepartment (required)
Store → Store Tax Rate
Store + Tax Category + Date → Store Tax Category Rate → Store Tax Rate
```

## Important Rules

* Departments and subdepartments are global across the ShelfStack instance.
* Subdepartments provide operational defaults for product variants (pricing model, margin target, supplier discount, tax category).
* Store category nodes classify catalog topics and may suggest defaults on catalog-linked items; they are not required on every variant.
* Tax categories do not directly define rates.
* Tax rates belong to stores.
* Store tax category rates define which rate applies to each tax category at each store during a date range.
* For a given store, tax category, and date, tax lookup must return exactly one applicable rate.

Default resolution order for operational defaults:

```text
variant override → variant.sub_department → product defaults → store category defaults (catalog path)
```

GL posting:

```text
variant.sub_department → department.gl_account_code
```

Reference data loads from CSV (`db/seeds/data/*.csv`) via `Seeds::CsvClassificationImporter`. Validate with `rails shelfstack:seeds:validate`. See [implementation/csv-seeds.md](implementation/csv-seeds.md) and [specifications/classification-target-spec.md](specifications/classification-target-spec.md).

### Historical note

Phase 2 originally introduced a `categories` table combining merchandise behavior and topic classification. That table was **removed** in the 2025-06 classification simplification. Operational defaults now live on `sub_departments`; topic trees use `category_schemes` / `category_nodes`. See [implementation/classification-cleanup.md](implementation/classification-cleanup.md).

---

# 3. Catalog Domain

The catalog domain describes the metadata associated with books, periodicals, media, sidelines, gifts, games, and other items.

## Core Concepts

| Concept                 | Meaning                                                                          |
| ----------------------- | -------------------------------------------------------------------------------- |
| Format                  | Controlled format record, such as hardcover, paperback, DVD, calendar, or eBook. |
| Catalog Item            | Descriptive metadata record.                                                     |
| Catalog Item Identifier | ISBN, UPC, EAN, GTIN, publisher number, or local identifier.                     |
| Creator Details         | Structured JSONB metadata for creators and roles.                                |
| Subject Details         | Structured JSONB metadata for subject headings, schemes, and codes.              |

## Key Relationships

```text
Catalog Item → Format
Catalog Item → Catalog Item Identifier
Catalog Item → Product
```

## Important Rules

* Every catalog item must have at least one active identifier.
* Every catalog item must have exactly one active primary identifier.
* ISBN-10 identifiers are saved as non-primary and converted to ISBN-13 primary identifiers.
* Invalid standard identifiers may be saved, but users are warned.
* Publisher numbers preserve display value and store a normalized searchable value.
* Catalog item type controls UI field display, not hard database validity.

---

# 4. Product Domain

The product domain defines how the store sells cataloged and non-cataloged items.

## Core Concepts

| Concept                | Meaning                                             |
| ---------------------- | --------------------------------------------------- |
| Product                | Store-facing product grouping.                      |
| Product Variant        | Actual sellable SKU.                                |
| Product Condition      | New, signed, used, remainder, or special condition. |
| Display Location       | Merchandising/display placement.                    |
| Store Display Location | Store-specific activation of a display location.    |
| Vendor                 | Supplier or source organization.                    |

## Key Relationships

```text
Catalog Item → Product → Product Variant
Product Variant → SubDepartment
Product Variant → Product Condition
Product Variant → Display Location
Product → Default Display Location
Store → Store Display Location → Display Location
```

## Important Rules

* Products may be catalog-linked or non-catalog-linked.
* Product SKU is the base SKU for variants.
* Product variants are the actual sellable SKUs.
* A product is not sellable until it has at least one active variant.
* Catalog-linked product names default from catalog item titles.
* Catalog-linked product SKUs default from catalog item primary identifiers.
* Variant SKUs are generated from product SKU plus condition or attribute components.
* New variants do not add a SKU suffix.
* Variant names are generated from product name plus condition and/or attributes.
* Product and variant names may be overridden.

---

# 5. Inventory Domain (Phase 4)

Phase 4 implements store-level inventory at the product variant grain.

## Core Concepts

| Concept | Meaning |
| --- | --- |
| Inventory Posting | Atomic posted inventory event grouping one or more ledger entries. |
| Inventory Ledger Entry | Append-only quantity and value effect for one store + variant within a posting. |
| Inventory Balance | Cached quantity and estimated value for one store + variant. |
| Inventory Adjustment | User-facing draft workflow that posts opening inventory or manual corrections. |
| Inventory Location | Optional store context on ledger lines; not an authoritative balance grain in Phase 4. |
| Inventory Value | Management cost and retail snapshots on ledger entries and balances. |

## Authoritative Grain

```text
store_id + product_variant_id
```

Product-level, department-level, and enterprise quantities are rollups from variant/store balances.

## Eligibility

Only **inventory-eligible** product variants receive ledger entries in Phase 4.

Implementation: `Inventory::Eligibility` / `Inventory::TrackingResolver` (`inventory` / `non_inventory`). Legacy stored value:

```text
inventory_behavior = standard_physical
```

## Design Direction

```text
Product Variant → Inventory Posting → Inventory Ledger Entries → Inventory Balance
```

Posted ledger entries are immutable. Balances update only through `Inventory::Post` (and rebuild tooling).

Phase 4 defers POS, transfers, holds, location balances, and full accounting beyond moving-average receipt cost.

---

# 6. Purchasing Domain (Phase 5)

Phase 5 implements vendor sourcing, purchase requests (TBO), purchase orders, receiving, and returns to vendor at the product variant grain.

## Core Concepts

| Concept | Meaning |
| --- | --- |
| Product Vendor | Product-level vendor sourcing defaults (item number, discount, returnability). |
| Product Variant Vendor | Variant-level vendor overrides; highest precedence for returnability. |
| Purchase Request (TBO) | Store demand signal; does not affect inventory. |
| Purchase Order | Committed order to a vendor with line snapshots at submit time. |
| Receipt | Posted receiving document; only `quantity_accepted` posts to inventory. |
| Return to Vendor (RTV) | Posted vendor return; negative quantity via inventory ledger. |
| Moving Average Cost | `inventory_balances.moving_average_unit_cost_cents` updated on receive. |

## Returnability Precedence

```text
product_variant_vendors → product_vendors → product_variants.returnability_status
```

## Design Direction

```text
Purchase Request → Purchase Order → Receipt → Inventory::Post (receiving)
Return to Vendor → Inventory::Post (vendor_return)
```

Purchasing documents are sources; inventory changes only through `Inventory::Post`.

---

# 7. POS Domain (Phase 6)

Phase 6 implements point-of-sale using `pos_*` tables. Inventory changes only through `Inventory::Post`.

## Core Concepts

| Concept              | Meaning                                              |
| -------------------- | ---------------------------------------------------- |
| Register Session     | Drawer/register period on a workstation (`business_date`). |
| POS Transaction      | Sale, return, or exchange document (`pos_transactions`). |
| Transaction Line     | Variant or open-ring line with signed quantity.      |
| Tender               | Payment or refund row (`pos_tenders`).               |
| Receipt              | Customer-facing document (`pos_receipts`).          |
| Void                 | Reversal of a completed transaction (`pos_voids`).   |
| Authorization        | Supervisor override record (`pos_authorizations`).   |

## Transaction Types

`transaction_type` is stored on the header and derived at completion from signed merchandise lines (`variant`, `open_ring`):

* all positive → `sale`
* all negative → `return`
* mixed → `exchange`

## Inventory Posting

Completed transaction:

```text
inventory_postings.posting_type = pos_transaction
inventory_postings.source = PosTransaction
inventory_ledger_entries.movement_type = sold | customer_return
```

Completed void:

```text
inventory_postings.posting_type = pos_void
inventory_postings.source = PosVoid
(reversal_of_posting_id links to original transaction posting)
```

Only `standard_physical` lines with `product_variant_id` post. Open-ring lines without a variant do not post.

Do not store `inventory_posting_id` on `pos_transactions`.

## Snapshotting

POS lines snapshot SKU, name, price, tax category, tax rate, and classification context at completion so later catalog or tax setup changes do not rewrite history.

## Related Documents

```text
docs/roadmap/phase-6-pos-foundation.md
docs/specifications/phase-6-pos-foundation-spec.md
docs/specifications/phase-6-data-model.md
```

---

# 8. Customer Demand Domain (Phase 7A)

Phase 7A links customer-facing demand to catalog, purchasing, inventory reservations, and POS pickup.

| Concept | Description |
| --- | --- |
| Customer | Lightweight customer profile (`customers`). |
| Customer Request | Store-scoped multi-line demand document (`customer_requests`). |
| Request Line | Provisional or matched line with type: research, notify, hold, special_order. |
| Special Order | Customer-backed commitment at variant grain (`special_orders`). |
| Inventory Reservation | On-hand hold, incoming reserve, or special-order reserve (`inventory_reservations`). |
| PO Line Allocation | Customer quantity on a PO line (`purchase_order_line_allocations`). |
| Receipt Line Allocation | Customer quantity from a posted receipt (`receipt_line_allocations`). |

Availability after Phase 7A:

```text
quantity_available = quantity_on_hand - quantity_reserved
on_order_available = on_order - reserved_incoming
```

Notify lines enter a staff queue on stock arrival; holds are created manually (no auto-hold).

## Related Documents

```text
docs/roadmap/phase-7a-customer-demand.md
docs/specifications/phase-7a-customer-demand-spec.md
docs/specifications/phase-7a-data-model.md
```

---

# 9. Conceptual Flow

ShelfStack’s core data flow can be summarized as:

```text
Foundation
  ↓
Departments / Categories / Taxes
  ↓
Catalog Items
  ↓
Products
  ↓
Product Variants
  ↓
Inventory / Purchasing / POS
  ↓
Reporting / Accounting
```

Each layer builds on the prior layer.
