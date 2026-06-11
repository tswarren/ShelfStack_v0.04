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

The classification domain defines how future sellable items are grouped, reported, priced by default, and taxed.

## Core Concepts

| Concept                 | Meaning                                                            |
| ----------------------- | ------------------------------------------------------------------ |
| Department              | Top-level sales/reporting bucket.                                  |
| Category                | Product-level classification linked to a department.               |
| Tax Category            | Global taxability classification for items.                        |
| Store Tax Rate          | Store-specific tax rate.                                           |
| Store Tax Category Rate | Effective-dated mapping of store + tax category to store tax rate. |

## Key Relationships

```text
Department → Category
Category → Default Tax Category
Store → Store Tax Rate
Store + Tax Category + Date → Store Tax Category Rate → Store Tax Rate
```

## Important Rules

* Departments and categories are global across the ShelfStack instance.
* Categories provide defaults for future sellable items.
* Tax categories do not directly define rates.
* Tax rates belong to stores.
* Store tax category rates define which rate applies to each tax category at each store during a date range.
* For a given store, tax category, and date, tax lookup must return exactly one applicable rate.

## Phase 3B transitional mapping

Phase 3B separates merchandise behavior, topic classification, and accounting mapping while keeping legacy Phase 2 structures working. See:

```text
docs/roadmap/phase-3-rework-merchandise-classification-structure/transitional-domain-mapping.md
```

| Legacy / transitional | Target concept |
| --- | --- |
| `Category` | `MerchandiseClass` (behavior defaults), not topic `CategoryNode` |
| `CategoryScheme` / `CategoryNode` / `Categorization` | Topic / section classification |
| `AccountingMapping` | Sales account and reporting bucket rules |
| `product_variants.category_id` | Required bridge through transition |

Default resolution order for pricing/tax/accounting derivation:

```text
variant override → accounting mapping → merchandise class → legacy category → legacy department GL
```

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
Product Variant → Category
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

# 5. Future Inventory Domain

The inventory domain is not yet implemented in early phases, but the Phase 3 model prepares for it.

## Expected Concepts

| Concept          | Meaning                                              |
| ---------------- | ---------------------------------------------------- |
| Inventory Ledger | Append-only record of stock movements.               |
| Stock Balance    | Derived or cached quantity on hand/available.        |
| Receiving        | Process of adding purchased inventory.               |
| Adjustment       | Correction to stock due to damage, count, loss, etc. |
| Transfer         | Movement between stores or locations.                |
| Inventory Value  | Cost basis/value of stock on hand.                   |

## Design Direction

Future inventory should operate at the product variant level.

```text
Product Variant → Inventory Ledger → Stock Balance
```

Product variant `inventory_behavior` should influence how future inventory/POS behavior works.

---

# 6. Future POS Domain

The POS domain is not yet implemented in early phases, but the model prepares for it.

## Expected Concepts

| Concept        | Meaning                                 |
| -------------- | --------------------------------------- |
| Sale           | POS transaction.                        |
| Sale Line      | Product variant sold.                   |
| Tender         | Payment method used.                    |
| Tax Line       | Tax amount applied.                     |
| Receipt        | Customer-facing sale document.          |
| Return         | Reversal or return transaction.         |
| Drawer Session | Register/cash drawer operating session. |

## Design Direction

Future POS sale lines should snapshot important mutable data:

* Product variant SKU
* Product name
* Variant name
* Price
* Tax rate
* Tax identifier
* Department/category
* Store/workstation/user context

This prevents later setup changes from rewriting transaction history.

---

# 7. Conceptual Flow

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
