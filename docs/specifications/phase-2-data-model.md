# Phase 2 Data Model

## Purpose

This document defines the Phase 2 ShelfStack data model, including tables, fields, recommended indexes, constraints, controlled values, and seed data.

This document should be treated as the source of truth for Phase 2 migrations.

---

# 1. Naming Conventions

## 1.1 Tables

Phase 2 introduces:

```text
tax_categories
store_tax_rates
store_tax_category_rates
departments
categories
```

## 1.2 Booleans

Use Rails-style boolean names without `is_`.

Use:

```
active
```

Avoid:

```
is_active
```

---

## 1.3 Timestamps

Use standard Rails timestamps:

```
created_at
updated_at
```

Use `_on` suffix for date-only effective dates:

```
effective_on
ends_on
```

---

## 1.4 Basis Points

Rates, percentages, discounts, and margin targets are stored as integer basis points.

Examples:

| Percent | Basis Points |
| ----: | ----: |
| 0.00% | `0` |
| 6.00% | `600` |
| 9.50% | `950` |
| 25.00% | `2500` |
| 40.00% | `4000` |
| 100.00% | `10000` |

---

## 1.5 Department Numbers

Department numbers are stored as strings.

Rules:

* Required  
* Unique  
* Numeric-only  
* Fixed width of three characters  
* Zero-padded

Examples:

```
001
002
010
100
```

---

# 2. Table Matrix

## 2.1 `tax_categories`

Global product taxability classifications.

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `name` | string | null false, unique | Full tax category name. |
| `short_name` | string | null false, unique, limit 20 | Appears in setup screens and future receipt/tax summaries. |
| `sort_order` | integer | null false, default 0 | Display order. |
| `active` | boolean | null false, default true | Inactive tax categories cannot be selected for new category defaults. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

### Notes

`tax_categories.receipt_identifier` is intentionally not included.

Receipt detail markers belong to `store_tax_rates.tax_identifier`.

---

## 2.2 `store_tax_rates`

Store-specific tax rates.

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `store_id` | bigint | references `stores`, null false | Store this rate belongs to. |
| `name` | string | null false | Example: `Michigan Sales Tax`. |
| `short_name` | string | null false, limit 20 | Prints in future receipt totals. |
| `tax_identifier` | string | null false, limit 1 | Prints on future receipt detail lines. Unique within store. |
| `tax_rate_bps` | integer | null false, default 0 | Tax rate in basis points. Example: `600` \= 6%. |
| `active` | boolean | null false, default true | Inactive rates cannot be used in new mappings. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

## 2.3 `store_tax_category_rates`

Effective-dated mapping of store \+ tax category to store tax rate.

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `store_id` | bigint | references `stores`, null false | Store context. |
| `tax_category_id` | bigint | references `tax_categories`, null false | Taxability classification. |
| `store_tax_rate_id` | bigint | references `store_tax_rates`, null false | Applied store tax rate. Must belong to same store. |
| `effective_on` | date | null false | First date this mapping applies. |
| `ends_on` | date | nullable | Last date this mapping applies. Null means open-ended. |
| `active` | boolean | null false, default true | Inactive mappings are ignored by tax lookup. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

## 2.4 `departments`

Global top-level sales/reporting departments.

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `department_number` | string | null false, unique, limit 3 | Numeric-only, fixed-width, zero-padded. Example: `001`, `010`, `100`. |
| `name` | string | null false, unique | Full department name. |
| `short_name` | string | null false, unique, limit 20 | Short display/printing name. |
| `gl_account_code` | string | limit 20 | Optional future accounting/export reference. Not unique. |
| `description` | text | nullable | Optional description. |
| `active` | boolean | null false, default true | Inactive departments cannot be assigned to new categories. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

## 2.5 `categories`

Global sellable-item categories linked to departments.

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `department_id` | bigint | references `departments`, null false | Parent department. |
| `name` | string | null false | Category name. Unique within department. |
| `short_name` | string | null false, limit 20 | Short display/printing name. Unique within department. |
| `sort_order` | integer | null false, default 0 | Display order within department. |
| `default_pricing_model` | string | nullable | Controlled value. |
| `default_margin_target_bps` | integer | nullable | Default target margin in basis points. |
| `default_supplier_discount_bps` | integer | nullable | Default supplier discount in basis points. |
| `default_tax_category_id` | bigint | references `tax_categories`, null false | Default tax category for future sellable items. |
| `active` | boolean | null false, default true | Inactive categories cannot be assigned to new sellable items. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

# 3. Recommended Indexes

## 3.1 `tax_categories`

| Index | Type | Notes |
| :---- | :---- | :---- |
| `name` | unique | Prevent duplicate global tax category names. |
| `short_name` | unique | Prevent ambiguous short labels. |
| `sort_order` | normal | Supports ordered display. |
| `active` | normal | Supports active/inactive filtering. |

---

## 3.2 `store_tax_rates`

| Index | Type | Notes |
| :---- | :---- | :---- |
| `store_id` | normal | Store tax setup lookup. |
| `store_id, name` | unique composite | Prevent duplicate rate names within store. |
| `store_id, short_name` | unique composite | Prevent duplicate receipt total labels within store. |
| `store_id, tax_identifier` | unique composite | Prevent receipt marker ambiguity within store. |
| `active` | normal | Supports active/inactive filtering. |

---

## 3.3 `store_tax_category_rates`

| Index | Type | Notes |
| :---- | :---- | :---- |
| `store_id` | normal | Store-specific lookup. |
| `tax_category_id` | normal | Tax category lookup. |
| `store_tax_rate_id` | normal | Store tax rate lookup. |
| `store_id, tax_category_id, effective_on` | unique composite | Prevent duplicate mappings with same effective date. |
| `store_id, tax_category_id, active` | normal | Supports active tax lookup. |
| `effective_on, ends_on` | composite | Supports date range lookup. |

### Optional PostgreSQL exclusion constraint

A stronger PostgreSQL exclusion constraint could prevent overlapping date ranges, but this may be deferred in favor of model/service validation during Phase 2.

---

## 3.4 `departments`

| Index | Type | Notes |
| :---- | :---- | :---- |
| `department_number` | unique | Primary department display/sort/reporting identifier. |
| `name` | unique | Prevent duplicate top-level reporting labels. |
| `short_name` | unique | Prevent ambiguous short labels. |
| `gl_account_code` | normal | Supports future accounting/export filtering. |
| `active` | normal | Supports active/inactive filtering. |

---

## 3.5 `categories`

| Index | Type | Notes |
| :---- | :---- | :---- |
| `department_id` | normal | Department category listing. |
| `default_tax_category_id` | normal | Tax category dependency lookup. |
| `department_id, name` | unique composite | Prevent duplicate category names within department. |
| `department_id, short_name` | unique composite | Prevent duplicate short names within department. |
| `department_id, sort_order` | normal | Supports ordered display within department. |
| `default_pricing_model` | normal | Optional filtering/reporting. |
| `active` | normal | Supports active/inactive filtering. |

---

# 4. Recommended Constraints

## 4.1 Department Number Format

PostgreSQL check constraint:

```sql
ALTER TABLE departments
ADD CONSTRAINT chk_departments_department_number_format
CHECK (department_number ~ '^[0-9]{3}$');
```

Application normalization should left-pad valid numeric input before validation.

---

## 4.2 Tax Rate Basis Points

Recommended check constraint:

```sql
ALTER TABLE store_tax_rates
ADD CONSTRAINT chk_store_tax_rates_tax_rate_bps
CHECK (tax_rate_bps >= 0 AND tax_rate_bps <= 10000);
```

If unusual rates above 100% may ever be needed, remove the upper bound and enforce only `>= 0`.

---

## 4.3 Category Basis Point Fields

Recommended constraints:

```sql
ALTER TABLE categories
ADD CONSTRAINT chk_categories_default_margin_target_bps
CHECK (
  default_margin_target_bps IS NULL
  OR (default_margin_target_bps >= 0 AND default_margin_target_bps <= 10000)
);

ALTER TABLE categories
ADD CONSTRAINT chk_categories_default_supplier_discount_bps
CHECK (
  default_supplier_discount_bps IS NULL
  OR (default_supplier_discount_bps >= 0 AND default_supplier_discount_bps <= 10000)
);
```

---

## 4.4 Store Tax Category Rate Date Range

Recommended constraint:

```sql
ALTER TABLE store_tax_category_rates
ADD CONSTRAINT chk_store_tax_category_rates_date_range
CHECK (
  ends_on IS NULL
  OR ends_on >= effective_on
);
```

---

## 4.5 Controlled Pricing Model Values

Allowed values:

```
trade_discount
trade_discount_returnable
short_discount
net_cost_markup
blended_lot_cost
buyback_resale
recipe_cost
pass_through
markdown
```

This can be enforced with Rails model validation and optionally a PostgreSQL check constraint.

Example PostgreSQL constraint:

```sql
ALTER TABLE categories
ADD CONSTRAINT chk_categories_default_pricing_model
CHECK (
  default_pricing_model IS NULL
  OR default_pricing_model IN (
    'trade_discount',
    'trade_discount_returnable',
    'short_discount',
    'net_cost_markup',
    'blended_lot_cost',
    'buyback_resale',
    'recipe_cost',
    'pass_through',
    'markdown'
  )
);
```

---

## 4.6 Store Tax Rate Same-Store Rule

A `store_tax_category_rate` must reference a `store_tax_rate` belonging to the same `store_id`.

This is best enforced in application/model/service validation.

Rule:

```
store_tax_category_rates.store_id must equal store_tax_rates.store_id
```

---

## 4.7 Non-Overlapping Tax Mapping Rule

For a given `store_id` and `tax_category_id`, only one active mapping may apply on a given date.

This should be enforced by model/service validation in Phase 2.

Rule:

```
No active store_tax_category_rate may overlap another active mapping for the same store and tax category.
```

---

# 5. Tax Lookup Service

## 5.1 Purpose

The tax lookup service resolves the applicable store tax rate for a store, tax category, and date.

Conceptual interface:

```
TaxRateLookup.call(
  store: store,
  tax_category: tax_category,
  date: date
)
```

## 5.2 Lookup Rule

Find active `store_tax_category_rates` where:

```
store_id = store.id
tax_category_id = tax_category.id
active = true
effective_on <= date
ends_on IS NULL OR ends_on >= date
```

Expected result count:

| Result Count | Behavior |
| ----: | :---- |
| 0 | Raise/configuration error: no applicable tax rate. |
| 1 | Return associated `store_tax_rate`. |
| \>1 | Raise/configuration error: ambiguous tax setup. |

---

# 6. Seed Data

## 6.1 Seed Requirements

Seeds must be idempotent.

Running Phase 2 seeds multiple times should update existing records by stable keys rather than creating duplicates.

Stable keys:

| Entity | Stable Key |
| :---- | :---- |
| Tax Category | `name` or `short_name` |
| Store Tax Rate | `store_id + name` |
| Store Tax Category Rate | `store_id + tax_category_id + effective_on` |
| Department | `department_number` |
| Category | `department_id + name` |
| Permission | `permission_key` |

---

## 6.2 Seed Tax Categories

| Name | Short Name | Sort Order | Active |
| :---- | :---- | ----: | ----: |
| Non-Taxable | Non-Tax | 10 | true |
| Books | Books | 20 | true |
| Periodicals | Periodicals | 30 | true |
| General Merchandise | Merch | 40 | true |
| Prepared Food | Food | 50 | true |
| Gift Card | Gift Card | 60 | true |

---

## 6.3 Seed Store Tax Rates

Each seeded store receives at least:

| Rate Name | Short Name | Tax Identifier | Rate BPS |
| :---- | :---- | ----: | ----: |
| Non-Taxable | Non-Tax | `N` | `0` |
| Taxable | Taxable | `T` | Store demo rate |

Suggested demo rates for Phase 1 stores:

| Store | Taxable Rate BPS | Notes |
| :---- | ----: | :---- |
| Store `001` / Michigan demo | `600` | 6.00% demo rate. |
| Store `002` / California demo | `950` | 9.50% demo rate. |

These are demo rates only and should not be treated as live tax guidance.

---

## 6.4 Seed Store Tax Category Rates

For each seeded store:

| Tax Category | Store Tax Rate |
| :---- | :---- |
| Non-Taxable | Non-Taxable |
| Books | Store-specific taxable/non-taxable choice from demo seed |
| Periodicals | Store-specific taxable/non-taxable choice from demo seed |
| General Merchandise | Taxable |
| Prepared Food | Taxable |
| Gift Card | Non-Taxable |

Recommended simple demo mapping:

### Store `001`

| Tax Category | Rate |
| :---- | :---- |
| Non-Taxable | Non-Taxable |
| Books | Non-Taxable |
| Periodicals | Taxable |
| General Merchandise | Taxable |
| Prepared Food | Taxable |
| Gift Card | Non-Taxable |

### Store `002`

| Tax Category | Rate |
| :---- | :---- |
| Non-Taxable | Non-Taxable |
| Books | Taxable |
| Periodicals | Taxable |
| General Merchandise | Taxable |
| Prepared Food | Taxable |
| Gift Card | Non-Taxable |

All mappings use:

```
effective_on: 2026-01-01
ends_on: null
active: true
```

---

## 6.5 Seed Departments

| Department Number | Name | Short Name | Suggested GL Account Code |
| :---- | :---- | :---- | :---- |
| `001` | Books | Books | 4000 |
| `002` | Periodicals | Periodicals | 4010 |
| `003` | Sidelines | Sidelines | 4020 |
| `004` | Used Books | Used Books | 4030 |
| `005` | Gift Cards | Gift Cards | 2100 |
| `006` | Food & Beverage | Food/Bev | 4040 |

GL account codes are optional demo values and may be adjusted later.

---

## 6.6 Seed Categories

### Department `001` — Books

| Name | Short Name | Pricing Model | Margin BPS | Supplier Discount BPS | Tax Category |
| :---- | :---- | :---- | ----: | ----: | :---- |
| Hardcover | Hardcover | `trade_discount` | `4000` | `4600` | Books |
| Trade Paperback | Trade Paper | `trade_discount` | `4000` | `4600` | Books |
| Mass Market Paperback | Mass Market | `trade_discount` | `4000` | `4600` | Books |
| Children’s Books | Children | `trade_discount` | `4000` | `4600` | Books |

### Department `002` — Periodicals

| Name | Short Name | Pricing Model | Margin BPS | Supplier Discount BPS | Tax Category |
| :---- | :---- | :---- | ----: | ----: | :---- |
| Magazines | Magazines | `trade_discount` | `3500` | `3500` | Periodicals |
| Newspapers | Newspapers | `trade_discount` | `2500` | `2500` | Periodicals |

### Department `003` — Sidelines

| Name | Short Name | Pricing Model | Margin BPS | Supplier Discount BPS | Tax Category |
| :---- | :---- | :---- | ----: | ----: | :---- |
| Gifts | Gifts | `net_cost_markup` | `5000` | null | General Merchandise |
| Stationery | Stationery | `net_cost_markup` | `5000` | null | General Merchandise |
| Games & Puzzles | Games | `net_cost_markup` | `5000` | null | General Merchandise |

### Department `004` — Used Books

| Name | Short Name | Pricing Model | Margin BPS | Supplier Discount BPS | Tax Category |
| :---- | :---- | :---- | ----: | ----: | :---- |
| Used Hardcover | Used HC | `buyback_resale` | `6000` | null | Books |
| Used Paperback | Used PB | `buyback_resale` | `6000` | null | Books |

### Department `005` — Gift Cards

| Name | Short Name | Pricing Model | Margin BPS | Supplier Discount BPS | Tax Category |
| :---- | :---- | :---- | ----: | ----: | :---- |
| Gift Cards | Gift Cards | `pass_through` | `0` | null | Gift Card |

### Department `006` — Food & Beverage

| Name | Short Name | Pricing Model | Margin BPS | Supplier Discount BPS | Tax Category |
| :---- | :---- | :---- | ----: | ----: | :---- |
| Prepared Beverages | Beverages | `net_cost_markup` | `6000` | null | Prepared Food |
| Packaged Snacks | Snacks | `net_cost_markup` | `5000` | null | Prepared Food |

---

## 6.7 Phase 2 Permissions

The `super_administrator` role receives all Phase 2 permissions.

### Tax Categories

```
setup.tax_categories.view
setup.tax_categories.create
setup.tax_categories.update
setup.tax_categories.inactivate
setup.tax_categories.reactivate
setup.tax_categories.delete
```

### Store Tax Rates

```
setup.store_tax_rates.view
setup.store_tax_rates.create
setup.store_tax_rates.update
setup.store_tax_rates.inactivate
setup.store_tax_rates.reactivate
setup.store_tax_rates.delete
```

### Store Tax Category Rates

```
setup.store_tax_category_rates.view
setup.store_tax_category_rates.create
setup.store_tax_category_rates.update
setup.store_tax_category_rates.inactivate
setup.store_tax_category_rates.reactivate
setup.store_tax_category_rates.delete
```

### Departments

```
setup.departments.view
setup.departments.create
setup.departments.update
setup.departments.inactivate
setup.departments.reactivate
setup.departments.delete
```

### Categories

```
setup.categories.view
setup.categories.create
setup.categories.update
setup.categories.inactivate
setup.categories.reactivate
setup.categories.delete
```

---

# 7. Migration Notes

## 7.1 Dependencies

Phase 2 depends on Phase 1 tables:

```
stores
users
permissions
roles
role_permissions
audit_events
```

## 7.2 Foreign Keys

Add foreign keys for:

```
store_tax_rates.store_id → stores.id
store_tax_category_rates.store_id → stores.id
store_tax_category_rates.tax_category_id → tax_categories.id
store_tax_category_rates.store_tax_rate_id → store_tax_rates.id
categories.department_id → departments.id
categories.default_tax_category_id → tax_categories.id
```

## 7.3 Restrictive Deletes

Use restrictive deletes where practical.

Preferred behavior is inactivation/end-dating rather than hard deletion once records are referenced.
