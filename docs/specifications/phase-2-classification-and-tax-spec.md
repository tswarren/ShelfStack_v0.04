# Phase 2 Classification and Tax Functional Specification

## Purpose

This specification defines the functional behavior for ShelfStack Phase 2.

Phase 2 establishes the classification and tax setup layer used by later product, inventory, and POS workflows.

> **Phase 3B note:** Parts of this specification are superseded in part by the Phase 3B merchandise classification rework. Legacy `Category` semantics, default resolution, and UI labels are described in `docs/roadmap/phase-3-rework-merchandise-classification-structure/transitional-domain-mapping.md`.

For schema details, see:

```text
docs/specifications/phase-2-data-model.md
```

For test coverage, see:

```
docs/specifications/phase-2-test-plan.md
```

---

# 1. Core Concepts

## 1.1 Department

A department is a global top-level classification used for sales reporting and future general ledger export.

Departments are used to group categories and support high-level reporting.

Examples:

```
Books
Periodicals
Sidelines
Used Books
Gift Cards
Food & Beverage
```

Departments are global across the ShelfStack instance.

---

## 1.2 Department Number

Each department has a user-assigned `department_number`.

Rules:

* Required  
* Unique  
* Stored as string  
* Numeric-only  
* Fixed-width, three characters  
* Zero-padded

Examples:

```
001
002
010
100
```

The department number is used for:

* Sorting  
* Display  
* Setup screens  
* Reporting  
* Future accounting/export references

Users may enter a shorter number such as `1` or `10`; the application should normalize it to `001` or `010`.

---

## 1.3 Category

A category is a global classification assigned to future sellable items.

Each category belongs to one department.

Categories provide defaults for future sellable items, including:

* Pricing model  
* Margin target  
* Supplier discount  
* Tax category

Examples:

| Department | Category |
| :---- | :---- |
| Books | New Hardcover |
| Books | Trade Paperback |
| Books | Mass Market Paperback |
| Periodicals | Magazines |
| Sidelines | Gifts |
| Used Books | Used Trade Paperback |

Categories are global across the ShelfStack instance.

---

## 1.4 Tax Category

A tax category is a global product taxability classification.

It describes how an item should be classified for tax purposes, not the rate itself.

Examples:

```
Non-Taxable
Books
Periodicals
General Merchandise
Prepared Food
Gift Card
```

A tax category may be taxable in one store and non-taxable in another store because stores may operate in different tax jurisdictions.

---

## 1.5 Store Tax Rate

A store tax rate defines a specific tax rate available at a store.

Examples:

| Store | Name | Rate |
| :---- | :---- | ----: |
| Store 001 | Non-Taxable | 0.00% |
| Store 001 | Michigan Sales Tax | 6.00% |
| Store 002 | Non-Taxable | 0.00% |
| Store 002 | California Demo Tax | 9.50% |

Tax rates are stored in basis points.

---

## 1.6 Store Tax Category Rate

A store tax category rate maps a tax category to a store tax rate for an effective date range.

It answers:

At this store, for this tax category, on this date, which tax rate applies?

Example:

| Store | Tax Category | Store Tax Rate | Effective | Ends |
| :---- | :---- | :---- | :---- | :---- |
| Store 001 | Books | Non-Taxable | 2026-01-01 | null |
| Store 001 | General Merchandise | Michigan Sales Tax | 2026-01-01 | null |
| Store 002 | Books | California Demo Tax | 2026-01-01 | null |

---

# 2. Department Behavior

## 2.1 Department Creation

Authorized users may create departments.

Required fields:

* Department number  
* Name  
* Short name

Optional fields:

* GL account code  
* Description

On create:

1. Department number is normalized.  
2. Department number is validated.  
3. Name and short name are validated for uniqueness.  
4. Department is saved as active by default.  
5. `department.created` audit event is created.

---

## 2.2 Department Number Normalization

User input should be normalized before save.

Examples:

| User Input | Stored Value |
| ----: | ----: |
| `1` | `001` |
| `2` | `002` |
| `10` | `010` |
| `25` | `025` |
| `100` | `100` |

Invalid examples:

| User Input | Reason |
| ----: | :---- |
| blank | Required |
| `A10` | Non-numeric |
| `1.5` | Non-integer |
| `1000` | More than three digits |

---

## 2.3 Department Editing

Authorized users may edit:

* Name  
* Short name  
* GL account code  
* Description  
* Active status through explicit inactivate/reactivate actions

Changing `department_number` should be allowed only if the department is not yet referenced, or should be carefully permission-controlled.

Recommendation for Phase 2:

Allow editing department number only while the department has no categories.

---

## 2.4 Department Inactivation

Departments may be inactivated.

Inactivation rules:

* Inactive departments remain visible in setup where appropriate.  
* Inactive departments cannot be assigned to new categories.  
* Existing categories may remain linked to inactive departments for history.  
* Inactivation creates `department.inactivated` audit event.

---

## 2.5 Department Deletion

Hard deletion should be restricted.

A department may be deleted only if:

1. It is not a system/seed-protected record.  
2. It has no categories.  
3. It has no future product references.  
4. It has no other dependent records.

If referenced, department should be inactivated instead.

---

# 3. Category Behavior

## 3.1 Category Creation

Authorized users may create categories.

Required fields:

* Department  
* Name  
* Short name  
* Default tax category

Optional/default fields:

* Sort order  
* Default pricing model  
* Default margin target  
* Default supplier discount

On create:

1. Department must be active.  
2. Name must be unique within department.  
3. Short name must be unique within department.  
4. Default tax category must be active.  
5. Controlled pricing model value must be valid if present.  
6. Category is saved as active by default.  
7. `category.created` audit event is created.

---

## 3.2 Category Defaults

Categories provide default values for future sellable items.

Defaults include:

| Field | Purpose |
| :---- | :---- |
| `default_pricing_model` | Suggested pricing model for future sellable items. |
| `default_margin_target_bps` | Suggested target gross margin. |
| `default_supplier_discount_bps` | Suggested supplier discount. |
| `default_tax_category_id` | Suggested tax category. |

Category defaults do not directly price or tax anything in Phase 2.

Later product/item records may override these defaults.

---

## 3.3 Pricing Model Values

Allowed Phase 2 pricing model keys:

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

Definitions:

| Pricing Model | Meaning |
| :---- | :---- |
| `trade_discount` | MSRP/list price less standard supplier discount. |
| `trade_discount_returnable` | Trade discount model where returnability matters. |
| `short_discount` | Reduced supplier discount, sometimes with surcharge. |
| `net_cost_markup` | Store buys at net cost and applies markup. |
| `blended_lot_cost` | Cost derived from mixed/lot acquisition. |
| `buyback_resale` | Used/buyback resale model. |
| `recipe_cost` | Cost derived from components/recipe. |
| `pass_through` | Non-inventory/pass-through sale. |
| `markdown` | Contra-revenue/markdown model. |

---

## 3.4 Margin and Discount Basis Points

Margin and discount defaults are stored as basis points.

Examples:

| Percent | Stored BPS |
| ----: | ----: |
| 0.00% | `0` |
| 25.00% | `2500` |
| 40.00% | `4000` |
| 46.00% | `4600` |
| 100.00% | `10000` |

Validation:

* Must be integer if present.  
* Must be greater than or equal to 0 if present.  
* Should generally be less than or equal to 10000.

---

## 3.5 Category Inactivation

Categories may be inactivated.

Inactivation rules:

* Inactive categories cannot be assigned to future sellable items.  
* Existing future product records may retain inactive categories for history.  
* Inactivation creates `category.inactivated` audit event.

---

## 3.6 Category Deletion

Hard deletion should be restricted.

A category may be deleted only if:

1. It has no future product/sellable item references.  
2. It has no other dependent records.

If referenced, category should be inactivated instead.

---

# 4. Tax Category Behavior

## 4.1 Tax Category Creation

Authorized users may create tax categories.

Required fields:

* Name  
* Short name

Optional/default fields:

* Sort order  
* Active status

On create:

1. Name must be globally unique.  
2. Short name must be globally unique.  
3. Tax category is active by default.  
4. `tax_category.created` audit event is created.

---

## 4.2 Tax Category Inactivation

Tax categories may be inactivated.

Inactivation rules:

* Inactive tax categories cannot be assigned as defaults for new categories.  
* Existing categories may retain inactive tax category references for history.  
* Existing effective-dated tax mappings may remain for historical lookup.  
* Inactivation creates `tax_category.inactivated` audit event.

---

## 4.3 Tax Category Deletion

Hard deletion should be restricted.

A tax category may be deleted only if:

1. It is not referenced by categories.  
2. It is not referenced by store tax category rates.  
3. It has no future product/item references.

If referenced, tax category should be inactivated instead.

---

# 5. Store Tax Rate Behavior

## 5.1 Store Tax Rate Creation

Authorized users may create store tax rates for stores they are allowed to manage.

Required fields:

* Store  
* Name  
* Short name  
* Tax identifier  
* Tax rate in basis points

On create:

1. Store must be active.  
2. Name must be unique within store.  
3. Short name must be unique within store.  
4. Tax identifier must be unique within store.  
5. Tax rate must be valid.  
6. Store tax rate is active by default.  
7. `store_tax_rate.created` audit event is created.

---

## 5.2 Tax Identifier

The `tax_identifier` is the receipt detail marker for the applied tax rate.

Examples:

```
A
B
C
N
```

Rules:

* Required  
* Limit 1 character  
* Unique within store  
* Normalized uppercase  
* Printed on future receipt detail lines  
* Explained in future receipt tax totals

Example future receipt behavior:

```
BOOK                    19.99 A
SIDELINE                 9.99 B
```

Where:

```
A = Non-Taxable
B = Michigan Sales Tax 6.00%
```

---

## 5.3 Tax Rate Basis Points

Tax rates are stored as integer basis points.

Examples:

| Rate | Stored Value |
| ----: | ----: |
| 0.00% | `0` |
| 6.00% | `600` |
| 8.25% | `825` |
| 9.50% | `950` |

Validation:

* Must be present.  
* Must be integer.  
* Must be greater than or equal to 0.  
* Should generally be less than or equal to 10000.

---

## 5.4 Store Tax Rate Inactivation

Store tax rates may be inactivated.

Inactivation rules:

* Inactive store tax rates cannot be used in new effective-dated tax mappings.  
* Existing mappings may remain for historical lookup.  
* Inactivation creates `store_tax_rate.inactivated` audit event.

---

## 5.5 Store Tax Rate Deletion

Hard deletion should be restricted.

A store tax rate may be deleted only if:

1. It is not referenced by store tax category rates.  
2. It has no future transaction references.

If referenced, store tax rate should be inactivated instead.

---

# 6. Store Tax Category Rate Behavior

## 6.1 Purpose

A store tax category rate defines which store tax rate applies to a tax category during a date range.

It is not merely a join table. It is an effective-dated tax rule.

---

## 6.2 Creation

Authorized users may create store tax category rates.

Required fields:

* Store  
* Tax category  
* Store tax rate  
* Effective date

Optional fields:

* End date

On create:

1. Store must be active.  
2. Tax category must be active.  
3. Store tax rate must be active.  
4. Store tax rate must belong to the same store.  
5. Effective date must be present.  
6. End date must be blank or greater than/equal to effective date.  
7. Mapping must not overlap with another active mapping for the same store and tax category.  
8. `store_tax_category_rate.created` audit event is created.

---

## 6.3 Effective Date Lookup

Given:

* Store  
* Tax category  
* Transaction date

ShelfStack resolves the applicable mapping where:

```
store_id = active store
tax_category_id = item tax category
active = true
effective_on <= transaction date
ends_on is null OR ends_on >= transaction date
```

There must be exactly one result.

If there are zero matches:

Tax lookup fails because no tax rule is configured.

If there are multiple matches:

Tax lookup fails because tax configuration is ambiguous.

Future POS phases should fail loudly if tax lookup is missing or ambiguous.

---

## 6.4 Non-Overlap Rule

For a given store and tax category, only one active mapping may apply on a given date.

Invalid example:

| Store | Tax Category | Rate | Effective | Ends |
| :---- | :---- | :---- | :---- | :---- |
| Store 001 | Books | Non-Taxable | 2026-01-01 | 2026-12-31 |
| Store 001 | Books | Taxable 6% | 2026-06-01 | null |

These overlap between 2026-06-01 and 2026-12-31.

---

## 6.5 Updating Effective-Dated Mappings

When tax rules change, preferred behavior is:

1. End-date the current mapping.  
2. Create a new mapping with the new effective date.

Example:

| Store | Tax Category | Rate | Effective | Ends |
| :---- | :---- | :---- | :---- | :---- |
| Store 001 | Books | Non-Taxable | 2026-01-01 | 2026-06-30 |
| Store 001 | Books | Taxable 6% | 2026-07-01 | null |

Avoid overwriting historical mappings if they may be needed for historical transaction lookup.

---

## 6.6 Inactivation

Store tax category rates may be inactivated.

Inactivation rules:

* Inactive mappings are ignored by tax lookup.  
* Historical mappings should generally be end-dated rather than inactivated if the rule changed over time.  
* Inactivation creates `store_tax_category_rate.inactivated` audit event.

---

## 6.7 Deletion

Hard deletion should be restricted.

A store tax category rate may be deleted only if:

1. It has no future transaction references.  
2. It is not needed for historical lookup.

Preferred action is usually end-dating, not deletion.

---

# 7. Setup Area Behavior

## 7.1 Setup Navigation

Phase 2 adds setup areas for:

* Tax Categories  
* Store Tax Rates  
* Store Tax Category Rates  
* Departments  
* Categories

These should appear in the existing Phase 1 Setup area.

---

## 7.2 Authorization

All Phase 2 setup screens require permissions.

Global setup records:

* Tax categories  
* Departments  
* Categories

Store-scoped setup records:

* Store tax rates  
* Store tax category rates

Store-scoped users may manage store-specific tax setup only for stores in their permitted scope.

---

## 7.3 Record-Level Audit Timeline

Detail pages for Phase 2 records should show relevant audit events:

| Record | Audit Timeline |
| :---- | :---- |
| Tax Category | Events where auditable is the tax category. |
| Store Tax Rate | Events where auditable is the store tax rate. |
| Store Tax Category Rate | Events where auditable is the mapping. |
| Department | Events where auditable is the department. |
| Category | Events where auditable is the category. |

---

# 8. Permissions

Phase 2 adds permissions to the Phase 1 permission catalog.

## 8.1 Tax Category Permissions

```
setup.tax_categories.view
setup.tax_categories.create
setup.tax_categories.update
setup.tax_categories.inactivate
setup.tax_categories.reactivate
setup.tax_categories.delete
```

## 8.2 Store Tax Rate Permissions

```
setup.store_tax_rates.view
setup.store_tax_rates.create
setup.store_tax_rates.update
setup.store_tax_rates.inactivate
setup.store_tax_rates.reactivate
setup.store_tax_rates.delete
```

## 8.3 Store Tax Category Rate Permissions

```
setup.store_tax_category_rates.view
setup.store_tax_category_rates.create
setup.store_tax_category_rates.update
setup.store_tax_category_rates.inactivate
setup.store_tax_category_rates.reactivate
setup.store_tax_category_rates.delete
```

## 8.4 Department Permissions

```
setup.departments.view
setup.departments.create
setup.departments.update
setup.departments.inactivate
setup.departments.reactivate
setup.departments.delete
```

## 8.5 Category Permissions

```
setup.categories.view
setup.categories.create
setup.categories.update
setup.categories.inactivate
setup.categories.reactivate
setup.categories.delete
```

The `super_administrator` role receives all Phase 2 permissions.

---

# 9. Audit Events

Phase 2 setup changes must create audit events.

## 9.1 Tax Category Events

```
tax_category.created
tax_category.updated
tax_category.inactivated
tax_category.reactivated
tax_category.deleted
```

## 9.2 Store Tax Rate Events

```
store_tax_rate.created
store_tax_rate.updated
store_tax_rate.inactivated
store_tax_rate.reactivated
store_tax_rate.deleted
```

## 9.3 Store Tax Category Rate Events

```
store_tax_category_rate.created
store_tax_category_rate.updated
store_tax_category_rate.inactivated
store_tax_category_rate.reactivated
store_tax_category_rate.deleted
```

## 9.4 Department Events

```
department.created
department.updated
department.inactivated
department.reactivated
department.deleted
```

## 9.5 Category Events

```
category.created
category.updated
category.inactivated
category.reactivated
category.deleted
```

---

# 10. Deletion and Inactivation Rules

| Record | Hard Delete? | Preferred Action Once Referenced |
| :---- | ----: | :---- |
| Tax Category | Only if unused | Inactivate |
| Store Tax Rate | Only if unused | Inactivate |
| Store Tax Category Rate | Only if unused | End-date or inactivate |
| Department | Only if unused | Inactivate |
| Category | Only if unused | Inactivate |

---

# 11. Normalization Rules

| Field | Normalization |
| :---- | :---- |
| `departments.department_number` | Numeric-only, left-pad to three digits. |
| `departments.name` | Trim whitespace. |
| `departments.short_name` | Trim whitespace. |
| `categories.name` | Trim whitespace. |
| `categories.short_name` | Trim whitespace. |
| `tax_categories.name` | Trim whitespace. |
| `tax_categories.short_name` | Trim whitespace. |
| `store_tax_rates.name` | Trim whitespace. |
| `store_tax_rates.short_name` | Trim whitespace. |
| `store_tax_rates.tax_identifier` | Trim and uppercase. |
| `categories.default_pricing_model` | Lowercase controlled key. |

---

# 12. Error Handling

## 12.1 Missing Tax Mapping

If tax lookup finds no applicable mapping:

```
No tax rate is configured for this store, tax category, and date.
```

In future POS phases, this should block sale completion until configuration is corrected.

---

## 12.2 Ambiguous Tax Mapping

If tax lookup finds more than one applicable mapping:

```
Multiple tax rates apply for this store, tax category, and date. Tax setup must be corrected.
```

In future POS phases, this should block sale completion.

---

## 12.3 Inactive Reference

If a user tries to assign an inactive reference:

```
This record is inactive and cannot be selected for new setup.
```

---

## 12.4 Duplicate Setup Record

If uniqueness validation fails:

```
A record with this value already exists.
```

Use field-specific messages where practical.

---

# 13. Functional Acceptance Criteria

Phase 2 behavior is accepted when:

1. Departments can be managed by authorized users.  
2. Department numbers normalize and validate correctly.  
3. Categories can be managed by authorized users.  
4. Category defaults validate correctly.  
5. Tax categories can be managed by authorized users.  
6. Store tax rates can be managed by authorized users.  
7. Store tax category rates can be managed by authorized users.  
8. Tax lookup returns the correct effective rate.  
9. Overlapping active tax mappings are prevented.  
10. Phase 2 permissions are seeded and enforced.  
11. Phase 2 setup changes create audit events.  
12. Phase 2 records show audit timelines.  
13. Seeds are idempotent.  
14. Tests cover validation, authorization, audit, tax lookup, setup UI, and seed behavior.