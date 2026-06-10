# Phase 2 Test Plan

## Purpose

This document defines the test coverage required for ShelfStack Phase 2.

Phase 2 introduces the classification and tax setup layer. Tests should verify validations, controlled values, authorization, effective-dated tax lookup, audit events, setup UI behavior, and seed idempotency.

---

# 1. Test Categories

| Category | Purpose |
|---|---|
| Model tests | Validate fields, uniqueness, normalization, constraints, and relationships. |
| Service tests | Validate tax lookup and overlap prevention. |
| Authorization tests | Validate Phase 2 permission enforcement. |
| Request/controller tests | Validate setup access control and CRUD behavior. |
| System tests | Validate browser-level setup flows. |
| Audit tests | Validate audit event creation and context. |
| Seed tests | Validate idempotent Phase 2 seed behavior. |

---

# 2. Department Tests

## 2.1 Department Can Be Created

### Scenario

Authorized user creates a valid department.

### Expected

- Department is saved.
- `active` defaults to true.
- `department.created` audit event is created.

---

## 2.2 Department Number Normalizes to Three Digits

### Examples

| User Input | Expected Stored Value |
|---:|---:|
| `1` | `001` |
| `2` | `002` |
| `10` | `010` |
| `25` | `025` |
| `100` | `100` |

### Expected

- Input is normalized before validation/save.
- Stored value is fixed-width three-character string.

---

## 2.3 Invalid Department Number Is Rejected

### Invalid values

```text
blank
A10
1.5
1000
-1
```

### Expected

* Validation fails.  
* Record is not saved.

---

## 2.4 Duplicate Department Number Is Rejected

### Expected

* Department number must be globally unique.  
* Duplicate record is not saved.

---

## 2.5 Duplicate Department Name Is Rejected

### Expected

* Department name must be globally unique.

---

## 2.6 Duplicate Department Short Name Is Rejected

### Expected

* Department short name must be globally unique.

---

## 2.7 Department Number Sorts Correctly

### Setup

Departments:

```
001
002
010
100
```

### Expected

Ordering by `department_number` returns:

```
001, 002, 010, 100
```

---

## 2.8 Department Can Be Inactivated

### Expected

* `active` becomes false.  
* `department.inactivated` audit event is created.  
* Department remains visible in setup where appropriate.

---

## 2.9 Inactive Department Cannot Be Assigned to New Category

### Expected

* Category creation fails if selected department is inactive.

---

## 2.10 Referenced Department Cannot Be Hard Deleted

### Setup

Department has categories.

### Expected

* Delete is blocked.  
* User is instructed to inactivate instead.

---

# 3. Category Tests

## 3.1 Category Can Be Created

### Scenario

Authorized user creates category with active department and active default tax category.

### Expected

* Category is saved.  
* `active` defaults to true.  
* `category.created` audit event is created.

---

## 3.2 Category Requires Department

### Expected

* Category without department is invalid.

---

## 3.3 Category Requires Default Tax Category

### Expected

* Category without default tax category is invalid.

---

## 3.4 Category Name Is Unique Within Department

### Expected

* Duplicate category name within same department is rejected.  
* Same category name in different department is allowed.

---

## 3.5 Category Short Name Is Unique Within Department

### Expected

* Duplicate short name within same department is rejected.  
* Same short name in different department is allowed.

---

## 3.6 Category Sort Order Defaults to Zero

### Expected

* If not provided, `sort_order = 0`.

---

## 3.7 Invalid Pricing Model Is Rejected

### Invalid example

```
random_model
```

### Expected

* Validation fails.

---

## 3.8 Allowed Pricing Models Are Accepted

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

### Expected

* Each allowed value passes validation.

---

## 3.9 Margin Target Basis Points Validate

### Expected

* Null is allowed.  
* Integer 0 is allowed.  
* Integer 10000 is allowed.  
* Negative values are rejected.  
* Values greater than 10000 are rejected unless upper bound is intentionally relaxed.

---

## 3.10 Supplier Discount Basis Points Validate

### Expected

* Null is allowed.  
* Integer 0 is allowed.  
* Integer 10000 is allowed.  
* Negative values are rejected.  
* Values greater than 10000 are rejected unless upper bound is intentionally relaxed.

---

## 3.11 Inactive Tax Category Cannot Be Assigned as New Default

### Expected

* Category creation/update is blocked if selecting inactive tax category as default.

---

## 3.12 Category Can Be Inactivated

### Expected

* `active` becomes false.  
* `category.inactivated` audit event is created.

---

## 3.13 Referenced Category Cannot Be Hard Deleted

### Future-facing test

Once products exist, category with product references cannot be deleted.

For Phase 2, category with no dependent references may be deleted if allowed.

---

# 4. Tax Category Tests

## 4.1 Tax Category Can Be Created

### Expected

* Tax category is saved.  
* `active` defaults to true.  
* `tax_category.created` audit event is created.

---

## 4.2 Tax Category Name Is Globally Unique

### Expected

* Duplicate name is rejected.

---

## 4.3 Tax Category Short Name Is Globally Unique

### Expected

* Duplicate short name is rejected.

---

## 4.4 Sort Order Defaults to Zero

### Expected

* If not provided, `sort_order = 0`.

---

## 4.5 Tax Category Can Be Inactivated

### Expected

* `active` becomes false.  
* `tax_category.inactivated` audit event is created.

---

## 4.6 Inactive Tax Category Cannot Be Used for New Category Defaults

### Expected

* New category cannot select inactive tax category.

---

## 4.7 Referenced Tax Category Cannot Be Hard Deleted

### Setup

Tax category is used by category or store tax category rate.

### Expected

* Delete is blocked.  
* User is instructed to inactivate instead.

---

# 5. Store Tax Rate Tests

## 5.1 Store Tax Rate Can Be Created

### Expected

* Rate is saved.  
* `active` defaults to true.  
* `store_tax_rate.created` audit event is created.

---

## 5.2 Store Tax Rate Requires Store

### Expected

* Rate without store is invalid.

---

## 5.3 Name Is Unique Within Store

### Expected

* Duplicate name in same store is rejected.  
* Same name in different store is allowed.

---

## 5.4 Short Name Is Unique Within Store

### Expected

* Duplicate short name in same store is rejected.  
* Same short name in different store is allowed.

---

## 5.5 Tax Identifier Is Unique Within Store

### Expected

* Duplicate tax identifier in same store is rejected.  
* Same tax identifier in different store is allowed.

---

## 5.6 Tax Identifier Normalizes Uppercase

### Example

| Input | Stored |
| :---- | :---- |
| `a` | `A` |
| `n` | `N` |

---

## 5.7 Tax Identifier Limit Is Enforced

### Expected

* Blank value is invalid.  
* More than one character is invalid.

---

## 5.8 Tax Rate BPS Is Required

### Expected

* Null value is invalid.  
* 0 is valid.

---

## 5.9 Tax Rate BPS Validates Range

### Expected

* Negative values are rejected.  
* 0 is allowed.  
* 600 is allowed.  
* 10000 is allowed.  
* Values over 10000 are rejected unless upper bound is intentionally relaxed.

---

## 5.10 Store Tax Rate Can Be Inactivated

### Expected

* `active` becomes false.  
* `store_tax_rate.inactivated` audit event is created.  
* Inactive rate cannot be used in new mappings.

---

## 5.11 Referenced Store Tax Rate Cannot Be Hard Deleted

### Setup

Store tax rate is used by store tax category rate.

### Expected

* Delete is blocked.  
* User is instructed to inactivate instead.

---

# 6. Store Tax Category Rate Tests

## 6.1 Mapping Can Be Created

### Expected

* Mapping is saved.  
* `active` defaults to true.  
* `store_tax_category_rate.created` audit event is created.

---

## 6.2 Mapping Requires Store

### Expected

* Missing store is invalid.

---

## 6.3 Mapping Requires Tax Category

### Expected

* Missing tax category is invalid.

---

## 6.4 Mapping Requires Store Tax Rate

### Expected

* Missing store tax rate is invalid.

---

## 6.5 Store Tax Rate Must Belong to Same Store

### Setup

* Mapping store: Store 001  
* Store tax rate belongs to Store 002

### Expected

* Mapping is invalid.

---

## 6.6 Effective Date Is Required

### Expected

* Missing `effective_on` is invalid.

---

## 6.7 End Date Must Not Precede Effective Date

### Invalid

| Effective | Ends |
| :---- | :---- |
| 2026-06-01 | 2026-05-31 |

### Expected

* Validation fails.

---

## 6.8 Duplicate Effective Date Is Rejected

### Setup

Existing mapping:

| Store | Tax Category | Effective |
| :---- | :---- | :---- |
| Store 001 | Books | 2026-01-01 |

New mapping with same store/category/effective date.

### Expected

* Validation fails.

---

## 6.9 Overlapping Active Mappings Are Rejected

### Existing

| Store | Tax Category | Effective | Ends |
| :---- | :---- | :---- | :---- |
| Store 001 | Books | 2026-01-01 | 2026-12-31 |

### New invalid mapping

| Store | Tax Category | Effective | Ends |
| :---- | :---- | :---- | :---- |
| Store 001 | Books | 2026-06-01 | null |

### Expected

* Validation fails.

---

## 6.10 Adjacent Date Ranges Are Allowed

### Existing

| Store | Tax Category | Effective | Ends |
| :---- | :---- | :---- | :---- |
| Store 001 | Books | 2026-01-01 | 2026-06-30 |

### New valid mapping

| Store | Tax Category | Effective | Ends |
| :---- | :---- | :---- | :---- |
| Store 001 | Books | 2026-07-01 | null |

### Expected

* Validation passes.

---

## 6.11 Inactive Mapping Is Ignored by Tax Lookup

### Expected

* Lookup does not use inactive mappings.

---

## 6.12 Mapping Can Be Inactivated

### Expected

* `active` becomes false.  
* `store_tax_category_rate.inactivated` audit event is created.

---

# 7. Tax Lookup Service Tests

## 7.1 Tax Lookup Returns Matching Rate

### Given

* Store  
* Tax category  
* Date within mapping range

### Expected

* Correct store tax rate is returned.

---

## 7.2 Tax Lookup Uses Open-Ended Mapping

### Given

* Mapping has `ends_on = null`  
* Date is after `effective_on`

### Expected

* Mapping applies.

---

## 7.3 Tax Lookup Uses Closed Date Range

### Given

* Mapping effective 2026-01-01 through 2026-06-30

### Expected

* 2026-01-01 applies.  
* 2026-06-30 applies.  
* 2026-07-01 does not apply.

---

## 7.4 Tax Lookup Fails When No Mapping Exists

### Expected

* Service raises or returns configuration error.  
* POS/future transaction should not silently assume zero tax.

---

## 7.5 Tax Lookup Fails When Multiple Mappings Apply

### Expected

* Service raises or returns ambiguous configuration error.

---

## 7.6 Tax Lookup Is Store-Specific

### Given

Same tax category has different mappings in Store 001 and Store 002.

### Expected

* Store 001 returns Store 001 rate.  
* Store 002 returns Store 002 rate.

---

# 8. Authorization Tests

## 8.1 User With Tax Category View Permission Can View Tax Categories

### Expected

* Access allowed.

---

## 8.2 User Without Tax Category View Permission Is Denied

### Expected

* Access denied.

---

## 8.3 User With Department Permission Can Manage Departments

### Expected

* Authorized actions succeed.  
* Audit events are created.

---

## 8.4 User Without Department Permission Cannot Manage Departments

### Expected

* Create/update/delete/inactivate actions are denied.

---

## 8.5 Store-Scoped User Can Manage Store Tax Rates Only For Assigned Store

### Setup

User has store-scoped permissions for Store 001.

### Expected

* User can manage Store 001 tax rates.  
* User cannot manage Store 002 tax rates.

---

## 8.6 Global Admin Can Manage All Phase 2 Setup

### Expected

* Global super administrator has all Phase 2 permissions.

---

# 9. Setup UI Tests

## 9.1 Setup Navigation Includes Phase 2 Areas

### Expected

Setup includes links/cards for:

* Tax Categories  
* Store Tax Rates  
* Store Tax Category Rates  
* Departments  
* Categories

---

## 9.2 Unauthorized Users Cannot See Phase 2 Setup Links

### Expected

* Links are hidden or inaccessible.  
* Direct URL access is denied.

---

## 9.3 Department Setup Flow Works

### Expected

Authorized user can:

* Create department  
* Edit department  
* Inactivate department  
* Reactivate department  
* Delete unused department

---

## 9.4 Category Setup Flow Works

### Expected

Authorized user can:

* Create category  
* Edit category  
* Inactivate category  
* Reactivate category  
* Delete unused category

---

## 9.5 Tax Category Setup Flow Works

### Expected

Authorized user can:

* Create tax category  
* Edit tax category  
* Inactivate tax category  
* Reactivate tax category  
* Delete unused tax category

---

## 9.6 Store Tax Rate Setup Flow Works

### Expected

Authorized user can:

* Create store tax rate  
* Edit store tax rate  
* Inactivate store tax rate  
* Reactivate store tax rate  
* Delete unused store tax rate

---

## 9.7 Store Tax Category Rate Setup Flow Works

### Expected

Authorized user can:

* Create mapping  
* Edit mapping  
* Inactivate mapping  
* Reactivate mapping  
* Delete unused mapping

---

# 10. Audit Event Tests

## 10.1 Required Phase 2 Events Are Created

Test creation for:

```
tax_category.created
tax_category.updated
tax_category.inactivated
tax_category.reactivated
tax_category.deleted

store_tax_rate.created
store_tax_rate.updated
store_tax_rate.inactivated
store_tax_rate.reactivated
store_tax_rate.deleted

store_tax_category_rate.created
store_tax_category_rate.updated
store_tax_category_rate.inactivated
store_tax_category_rate.reactivated
store_tax_category_rate.deleted

department.created
department.updated
department.inactivated
department.reactivated
department.deleted

category.created
category.updated
category.inactivated
category.reactivated
category.deleted
```

---

## 10.2 Audit Event Includes Required Context

### Expected

Audit event includes:

* `actor_user_id`  
* `event_name`  
* `occurred_at`  
* `event_details`  
* auditable reference  
* store/workstation/session context when available

---

## 10.3 Record-Level Audit Timeline Works

### Expected

* Tax category detail page shows related audit events.  
* Store tax rate detail page shows related audit events.  
* Store tax category rate detail page shows related audit events.  
* Department detail page shows related audit events.  
* Category detail page shows related audit events.

---

# 11. Seed Tests

## 11.1 Seeds Create Required Tax Categories

### Expected

Seed creates:

* Non-Taxable  
* Books  
* Periodicals  
* General Merchandise  
* Prepared Food  
* Gift Card

---

## 11.2 Seeds Create Store Tax Rates For Each Store

### Expected

Each seeded store receives:

* Non-Taxable rate  
* Taxable rate

---

## 11.3 Seeds Create Store Tax Category Rate Mappings

### Expected

Each seeded store has mappings for each seeded tax category.

Tax lookup succeeds for every seeded store/tax category/date combination.

---

## 11.4 Seeds Create Departments

### Expected

Seed creates departments:

```
001 Books
002 Periodicals
003 Sidelines
004 Used Books
005 Gift Cards
006 Food & Beverage
```

---

## 11.5 Seeds Create Categories

### Expected

Seed creates bookstore-oriented categories under seeded departments.

---

## 11.6 Seeds Add Phase 2 Permissions

### Expected

All Phase 2 permissions exist.

---

## 11.7 Super Administrator Receives Phase 2 Permissions

### Expected

Seeded `super_administrator` role has all Phase 2 permissions.

---

## 11.8 Seeds Are Idempotent

### Expected

Running seeds multiple times does not duplicate:

* Tax categories  
* Store tax rates  
* Store tax category rates  
* Departments  
* Categories  
* Permissions  
* Role permissions

---

# 12. Regression Risks

These areas require regression coverage in later phases:

1. Department/category deletion after products exist.  
2. Tax lookup during POS.  
3. Tax changes over time.  
4. Historical transaction tax preservation.  
5. Category defaults copied to future product records.  
6. Store-scoped tax setup permissions.  
7. Inactive tax categories/rates/categories/departments.  
8. Seed idempotency.  
9. Receipt tax identifier uniqueness.  
10. Department number formatting.

---

# 13. Minimum Definition of Done

Phase 2 is done only when:

1. All migrations run cleanly.  
2. All Phase 2 seeds run idempotently.  
3. Tax categories can be managed by authorized users.  
4. Store tax rates can be managed by authorized users.  
5. Store tax category rates can be managed by authorized users.  
6. Departments can be managed by authorized users.  
7. Categories can be managed by authorized users.  
8. Department numbers normalize and validate correctly.  
9. Tax lookup service works.  
10. Overlapping tax mappings are prevented.  
11. Setup UI enforces permissions.  
12. Setup changes create audit events.  
13. Seeded tax lookup succeeds for all seeded stores/tax categories.  
14. Phase 2 test suite passes.