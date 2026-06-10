# Phase 2: Departments, Categories, and Taxes

## Purpose

Phase 2 establishes ShelfStack’s product classification and tax setup layer.

This phase defines the departments used for sales and general ledger reporting, the categories used to classify future sellable items, and the tax category/rate mappings required to support store-specific tax behavior.

Phase 2 does not yet implement sellable products, product variants, inventory, purchasing, receiving, or POS transactions. Instead, it creates the classification and tax foundation those later workflows will depend on.

---

## Goals

Phase 2 should provide a reliable setup framework for:

1. Department-level sales reporting.
2. Future general ledger export mapping.
3. Category-level product classification.
4. Category-level default pricing behavior.
5. Category-level default margin/discount behavior.
6. Category-level default tax classification.
7. Store-specific tax rates.
8. Effective-dated tax category-to-rate mappings.
9. Tax lookup rules that can later be used by POS.
10. Setup UI for departments, categories, tax categories, store tax rates, and tax mappings.
11. Audit events for all Phase 2 setup changes.
12. Tests for classification, tax, setup, validation, and seed behavior.

---

## Non-Goals

Phase 2 does not include:

- Works
- Editions
- Bibliographic records
- Products
- Product variants
- SKUs
- Inventory ledger
- Purchase orders
- Receiving
- POS sales
- Register/cash drawer workflows
- Customer records
- Supplier/vendor records
- Tax calculation during live sale transactions
- Tax remittance reporting
- GL export generation
- Store-specific category overrides
- Business-date/register-closeout behavior

---

## Major Capabilities

| Capability | Description |
|---|---|
| Tax categories | Define global product taxability classifications such as Books, Periodicals, General Merchandise, Prepared Food, and Gift Card. |
| Store tax rates | Define tax rates that apply at a specific store. |
| Store tax category rates | Effective-dated mapping of store + tax category to a store tax rate. |
| Departments | Define top-level sales/reporting departments. |
| Categories | Define product-level categories linked to departments. |
| Category defaults | Store default pricing model, margin target, supplier discount, and tax category for future sellable items. |
| Setup UI | Authorized users can manage Phase 2 setup records. |
| Audit logging | Setup changes create audit events. |
| Seed data | Bookstore-oriented demo departments, categories, tax categories, tax rates, and tax mappings are seeded. |
| Test coverage | Validation, tax lookup, setup permissions, audit events, and seed idempotency are tested. |

---

## Internal Phase Breakdown

Phase 2 may be implemented as three internal workstreams.

---

## Phase 2A: Tax Classification Foundation

### Purpose

Build the tax classification setup layer.

### Includes

- `tax_categories`
- `store_tax_rates`
- `store_tax_category_rates`
- Store-specific tax rate setup
- Effective-dated tax category rate mappings
- Tax lookup service
- Tax setup permissions
- Tax setup audit events
- Tax seed data

### Primary question answered

> Given a store, tax category, and date, which tax rate applies?

### Exit Criteria

Phase 2A is complete when:

1. Authorized users can manage tax categories.
2. Authorized users can manage store tax rates.
3. Authorized users can manage store tax category rate mappings.
4. Tax rates are stored in basis points.
5. Tax category mappings are effective-dated.
6. Tax lookup service returns exactly one applicable rate for a valid store/tax category/date.
7. Overlapping active mappings for the same store/tax category/date are prevented.
8. Store tax rate identifiers are unique within each store.
9. Audit events are created for tax setup changes.
10. Tax seed data is created idempotently.

---

## Phase 2B: Department and Category Foundation

### Purpose

Build the classification structure used by future products and product variants.

### Includes

- `departments`
- `categories`
- Department numbering
- Department GL account reference
- Category pricing defaults
- Category tax defaults
- Category setup permissions
- Category setup audit events
- Department/category seed data

### Primary question answered

> How will future sellable items be classified for reporting, pricing defaults, and tax defaults?

### Exit Criteria

Phase 2B is complete when:

1. Authorized users can manage departments.
2. Authorized users can manage categories.
3. Departments use fixed-width, zero-padded, three-digit department numbers.
4. Department number, name, and short name are globally unique.
5. Categories belong to departments.
6. Category name and short name are unique within department.
7. Categories store default pricing model.
8. Categories store default margin target.
9. Categories store default supplier discount.
10. Categories store default tax category.
11. Inactive departments cannot be assigned to new categories.
12. Inactive tax categories cannot be assigned as new category defaults.
13. Audit events are created for department/category setup changes.
14. Department/category seed data is created idempotently.

---

## Phase 2C: Setup UI, Audit, and Testing

### Purpose

Build the administrative interface and verify the classification/tax foundation.

### Includes

- Setup navigation updates
- Tax category setup screens
- Store tax rate setup screens
- Store tax category rate setup screens
- Department setup screens
- Category setup screens
- Record-level audit timelines
- Phase 2 permission seeding
- Phase 2 test coverage

### Primary question answered

> Can an authorized administrator safely configure classification and tax behavior?

### Exit Criteria

Phase 2C is complete when:

1. Setup navigation includes Phase 2 setup areas.
2. Authorized users can access Phase 2 setup screens.
3. Unauthorized users are blocked from Phase 2 setup screens.
4. Phase 2 setup screens enforce validation and deletion/inactivation rules.
5. Phase 2 setup changes create audit events.
6. Record detail pages show relevant audit timelines.
7. Phase 2 seeds are idempotent.
8. Tests cover data model validations, authorization, tax lookup, setup UI, audit events, and seed behavior.

---

## Models Introduced

Phase 2 introduces the following tables:

| Table | Purpose |
|---|---|
| `tax_categories` | Global product taxability classifications. |
| `store_tax_rates` | Store-specific tax rates. |
| `store_tax_category_rates` | Effective-dated mapping of store + tax category to store tax rate. |
| `departments` | Global top-level sales/reporting departments. |
| `categories` | Global sellable-item categories linked to departments. |

---

## Key Design Decisions

### Departments and categories are global

Departments and categories are global across the ShelfStack instance.

Store-specific differences should be handled later through explicit store-level overrides if needed, not by duplicating global categories.

---

### Department numbers are fixed-width strings

Department numbers are stored as strings.

Rules:

- Required
- Unique
- Numeric-only
- Fixed width of three digits
- Zero-padded

Examples:

```text
001
002
010
100
```

This allows correct display and sorting while preserving leading zeroes.

---

### Departments are top-level reporting buckets

Departments are the top-level classification used for:

* POS sales reporting  
* Department-level sales summaries  
* Future accounting/general ledger export  
* High-level product organization

Departments should remain relatively stable.

---

### Categories classify future sellable items

Categories are assigned to individual sellable items in later phases.

Each category belongs to one department and provides default values for:

* Pricing model  
* Margin target  
* Supplier discount  
* Tax category

Category defaults are defaults only. Later product/item records may override them.

---

### Tax categories are global taxability classifications

Tax categories describe the kind of item for tax purposes.

Examples:

* Non-Taxable  
* Books  
* Periodicals  
* General Merchandise  
* Prepared Food  
* Gift Card

Tax categories do not directly store a store-specific rate.

---

### Store tax rates are store-specific

Tax rates belong to stores.

Each store may define:

* Non-Taxable rate  
* Primary taxable rate  
* Additional special rates as needed

Rates are stored in basis points.

Examples:

| Display Rate | Stored `tax_rate_bps` |
| ----: | ----: |
| 0.00% | `0` |
| 6.00% | `600` |
| 8.25% | `825` |
| 9.50% | `950` |
| 13.00% | `1300` |

---

### Store tax category rates are effective-dated mappings

The table `store_tax_category_rates` maps:

```
store + tax category + date range → store tax rate
```

This allows the same global tax category to be taxable in one store, non-taxable in another store, or to change over time.

---

### Receipt tax identifier belongs to store tax rates

ShelfStack stores the receipt tax marker on `store_tax_rates.tax_identifier`.

The field `tax_categories.receipt_identifier` is intentionally not used.

Reason:

Receipt detail lines usually need to show which applied tax rate was used, not just the product’s tax classification.

---

### Short names use a consistent limit

All Phase 2 short names use a limit of 20 characters:

* `tax_categories.short_name`  
* `store_tax_rates.short_name`  
* `departments.short_name`  
* `categories.short_name`

---

### Booleans use Rails-style names

Use:

```
active
```

Avoid:

```
is_active
```

---

## Deferred Items

The following are intentionally deferred:

| Item | Reason |
| :---- | :---- |
| Product assignment to categories | Products are introduced in a later phase. |
| Store-specific category overrides | Global categories are sufficient for Phase 2. |
| POS tax calculation | Phase 2 prepares tax lookup, but does not calculate sales transactions. |
| Tax remittance reports | Requires POS transaction data. |
| GL export generation | Departments store GL account codes, but export logic is deferred. |
| Business-date tax lookup | Phase 2 uses transaction/date lookup; business date rules are deferred. |
| Historical transaction tax preservation | Future POS transactions should store applied tax details at time of sale. |
| Advanced jurisdiction modeling | Store tax rates are sufficient for Phase 2. |

---

## Final Phase 2 Exit Criteria

Phase 2 is complete when all of the following are true.

### Tax setup

1. Authorized users can create, update, inactivate, reactivate, and delete unused tax categories.  
2. Authorized users can create, update, inactivate, reactivate, and delete unused store tax rates.  
3. Authorized users can create, update, inactivate, reactivate, and delete unused store tax category rate mappings.  
4. Store tax rates store rates in basis points.  
5. Store tax rate tax identifiers are unique per store.  
6. Tax category mappings are effective-dated.  
7. Overlapping active mappings for the same store/tax category/date are prevented.  
8. Tax lookup service returns the correct applicable store tax rate.

### Department setup

1. Authorized users can create, update, inactivate, reactivate, and delete unused departments.  
2. Department numbers are stored as three-character zero-padded strings.  
3. Department number, name, and short name are globally unique.  
4. Department numbers sort correctly as strings.  
5. Inactive departments cannot be assigned to new categories.

### Category setup

1. Authorized users can create, update, inactivate, reactivate, and delete unused categories.  
2. Categories are linked to departments.  
3. Category name and short name are unique within department.  
4. Categories store default pricing model.  
5. Categories store default margin target.  
6. Categories store default supplier discount.  
7. Categories store default tax category.  
8. Inactive tax categories cannot be assigned as defaults for new categories.  
9. Inactive categories cannot be assigned to future sellable items.

### Authorization

1. Phase 2 permissions are seeded.  
2. Setup access is permission-controlled.  
3. Unauthorized users cannot access Phase 2 setup screens.  
4. Store-scoped users can manage store tax rates only for permitted stores.  
5. Global setup permissions are required for global records such as departments, categories, and tax categories.

### Auditability

1. Phase 2 setup changes create audit events.  
2. Audit events include actor, event name, affected record, timestamp, and context.  
3. Authorized users can view Phase 2 audit events.  
4. Record-level audit timelines work for Phase 2 records.

### Seed data

1. Phase 2 seed data is bookstore-oriented.  
2. Seeds are idempotent.  
3. Each seeded store has default non-taxable and taxable tax rates.  
4. Seeded tax category mappings allow tax lookup to succeed for each seeded store and tax category.

### Testing

1. Model validation tests pass.  
2. Authorization tests pass.  
3. Tax lookup tests pass.  
4. Setup UI tests pass.  
5. Audit event tests pass.  
6. Seed idempotency tests pass.