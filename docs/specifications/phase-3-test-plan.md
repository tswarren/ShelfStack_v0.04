# Phase 3 Test Plan

## Purpose

This document defines the test coverage required for ShelfStack Phase 3.

Phase 3 introduces catalog metadata, catalog identifiers, products, product variants, conditions, display locations, vendors, SKU generation, name rendering, and metadata parsing.

---

# 1. Test Categories

| Category | Purpose |
|---|---|
| Model tests | Validate fields, relationships, controlled values, normalization, and constraints. |
| Service tests | Validate identifier normalization, validation, SKU generation, name rendering, and metadata parsing. |
| Authorization tests | Validate Phase 3 permission enforcement. |
| Request/controller tests | Validate setup and CRUD behavior. |
| System tests | Validate browser-level catalog/product setup flows. |
| Audit tests | Validate Phase 3 audit event creation. |
| Seed tests | Validate idempotent Phase 3 seeds. |

---

# 2. Format Tests

## 2.1 Format Can Be Created

Expected:

- Format saves.
- `active` defaults to true.
- Audit event is created.

## 2.2 Format Key Is Unique

Expected:

- Duplicate `format_key` is rejected.

## 2.3 Inactive Format Cannot Be Assigned to New Catalog Item

Expected:

- Catalog item creation blocks inactive format.

---

# 3. Catalog Item Tests

## 3.1 Catalog Item Can Be Created With Identifier

Expected:

- Catalog item saves.
- At least one identifier exists.
- Exactly one active primary identifier exists.
- Audit event is created.

## 3.2 Catalog Item Cannot Save Without Identifier

Expected:

- Save is rejected.
- User receives validation message.

## 3.3 Catalog Item Type Controlled Values

Allowed:

```text
book
calendar
periodical
recorded_music
sideline
videorecording
audiobook
ebook
map
game
gift
other
```

Expected:

* Allowed values pass.  
* Invalid values fail.

## 3.4 Type Controls UI Field Display

Expected:

* Book shows book-relevant fields.  
* Periodical shows frequency fields.  
* Calendar shows year.  
* eBook hides physical dimension fields by default.  
* Hidden fields are not database-prohibited.

---

# 4. Catalog Identifier Tests

## 4.1 Standard Identifiers Normalize Digits-Only

Inputs:

```
978-0-123456-78-9
978 0 123456 78 9
```

Expected:

```
9780123456789
```

## 4.2 ISBN-13 Check Digit Validates

Expected:

* Valid ISBN-13 stores `valid_check_digit = true`.  
* Invalid ISBN-13 stores `valid_check_digit = false`.  
* Invalid ISBN-13 creates warning.

## 4.3 ISBN-10 Check Digit Validates

Expected:

* Valid ISBN-10 stores `valid_check_digit = true`.  
* Invalid ISBN-10 stores warning.

## 4.4 ISBN-10 Creates ISBN-13 Primary

Given:

```
0123456789
```

Expected:

* ISBN-10 identifier is created.  
* ISBN-10 is non-primary.  
* Generated ISBN-13 identifier is created.  
* ISBN-13 is primary.  
* Audit event `catalog_item_identifier.isbn10_converted` is created.

## 4.5 UPC/EAN/GTIN Check Digit Validates

Expected:

* Valid values pass with `valid_check_digit = true`.  
* Invalid values save with warning.

## 4.6 Publisher Number Preserves Display Value

Input:

```
ABC 123-45
```

Expected:

* `identifier_value = "ABC 123-45"`  
* `normalized_identifier = "ABC12345"`

## 4.7 Publisher Number Is Not Globally Unique

Expected:

* Same normalized publisher number may exist on different catalog items if publisher/source context is not enforced.

## 4.8 Local Identifier Generates

Expected:

* Local identifier is generated.  
* Identifier type is `local`.  
* Identifier becomes primary if no primary exists.  
* Audit event `catalog_item_identifier.local_generated` is created.

## 4.9 One Active Primary Identifier Is Enforced

Expected:

* Catalog item cannot have two active primary identifiers.  
* Changing primary clears prior primary or fails unless done through service.

---

# 5. Creator Parsing Tests

## 5.1 Creator Entry Parses Roles

Input:

```
Smith, John [author]; Doe, Jane [actor; director]
```

Expected JSON includes:

```json
[
  {
    "display_name": "Smith, John",
    "family_name": "Smith",
    "given_names": "John",
    "roles": ["author"]
  },
  {
    "display_name": "Doe, Jane",
    "family_name": "Doe",
    "given_names": "Jane",
    "roles": ["actor", "director"]
  }
]
```

## 5.2 Creator Without Comma Is Preserved

Input:

```
The Beatles [performer]
```

Expected:

* `display_name = "The Beatles"`  
* `family_name = null`  
* `given_names = null`  
* `roles = ["performer"]`

## 5.3 Blank Creator Segments Ignored

Expected:

* Empty semicolon segments do not create JSON entries.

---

# 6. Subject Parsing Tests

## 6.1 Subject With Scheme And Code Parses

Input:

```
HISTORY > General [BISAC/HIS000000]
```

Expected:

```json
{
  "heading": "HISTORY > General",
  "scheme": "BISAC",
  "code": "HIS000000"
}
```

## 6.2 Subject With Scheme Only Parses

Input:

```
Comedy [local]
```

Expected:

```json
{
  "heading": "Comedy",
  "scheme": "local",
  "code": null
}
```

## 6.3 Subject Without Scheme Defaults Local

Input:

```
Comedy
```

Expected:

```json
{
  "heading": "Comedy",
  "scheme": "local",
  "code": null
}
```

---

# 7. Product Tests

## 7.1 Catalog-Linked Product Defaults Name And SKU

Expected:

* Product name defaults from catalog title.  
* Product SKU defaults from catalog primary identifier.  
* Product saves.

## 7.2 Non-Catalog Product Requires Name And SKU

Expected:

* User-entered name accepted.  
* Manual or generated SKU accepted.  
* Missing SKU rejected.

## 7.3 Product SKU Is Unique

Expected:

* Duplicate SKU rejected.

## 7.4 Product SKU Change Is Audited

Expected:

* SKU change creates `product.sku_changed`.

## 7.5 Product Name Can Be Overridden

Expected:

* `name_override` controls displayed/stored current name.  
* Audit event created.

## 7.6 Product Without Active Variant Is Not Sellable

Expected:

* Product setup can exist.  
* Product cannot be used as sellable item until active variant exists.

---

# 8. Product Condition Tests

## 8.1 Seed Conditions Exist

Expected all seed conditions exist:

```
New
Signed Copy
Special Edition
Used - Like New
Used - Very Fine
Used - Fine
Used - Good
Used - Poor
Used - Ex-Library
Used - Book Club
Remainder
```

## 8.2 New Condition SKU Component Is Null

Expected:

* New condition has null SKU component.

## 8.3 SKU Components Normalize Uppercase

Input:

```
sg
```

Expected:

```
SG
```

## 8.4 Default List Price Factor Validates

Expected:

* 0 allowed.  
* 10000 allowed.  
* Negative rejected.  
* Above 10000 rejected.

---

# 9. Product Variant Tests

## 9.1 New Variant SKU Equals Product SKU

Given product SKU:

```
9780123456789
```

Expected new variant SKU:

```
9780123456789
```

## 9.2 Signed Variant SKU Appends Condition Component

Expected:

```
9780123456789-SG
```

## 9.3 Used Like New Variant SKU Appends Condition Component

Expected:

```
9780123456789-UN
```

## 9.4 Variable Variant SKU Appends Attribute Component

Expected:

```
9780123456789-BLU
```

## 9.5 Matrix Variant SKU Appends Two Attribute Components

Expected:

```
9780123456789-BLU-LG
```

## 9.6 Duplicate Variant SKU Is Rejected

Expected:

* Duplicate SKU fails validation.

## 9.7 Only One Unsuffixed Variant Per Product

Expected:

* Product cannot have two variants with SKU equal to product SKU.

## 9.8 Variant Name Generated For New Variant

Expected:

* New variant name equals product name.

## 9.9 Variant Name Generated For Condition Variant

Expected:

```
The Hobbit - Signed
```

## 9.10 Variant Name Generated For Matrix Variant

Expected:

```
Store T-Shirt - Blue / Large
```

## 9.11 Variant Name Override Works

Expected:

* Override value used.  
* Audit event created.

## 9.12 Inventory Behavior Controlled Values

Expected:

* Allowed values pass.  
* Invalid values rejected.

---

# 10. Display Location Tests

## 10.1 Display Location Can Be Created

Expected:

* Saves successfully.  
* `active` defaults true.  
* Audit event created.

## 10.2 Display Location Short Name Unique

Expected:

* Duplicate short name rejected.

## 10.3 Hierarchy Works

Expected:

* Child display location can reference parent.  
* Parent/child display correctly.

## 10.4 Store Display Location Unique Per Store

Expected:

* Same display location cannot be added twice to same store.  
* Same display location can be used by different stores.

---

# 11. Vendor Tests

## 11.1 Vendor Can Be Created

Expected:

* Vendor saves.  
* Audit event created.

## 11.2 Parent Vendor Can Be Assigned

Expected:

* Vendor can reference parent vendor.

## 11.3 Inactive Vendor Cannot Be Used For New Future Sourcing Records

Future-facing rule.

---

# 12. Authorization Tests

## 12.1 User With Catalog Permission Can Access Catalog Setup

Expected:

* Access allowed.

## 12.2 User Without Catalog Permission Is Denied

Expected:

* Access denied.

## 12.3 Product Setup Requires Product Permissions

Expected:

* Unauthorized users cannot create/update products.

## 12.4 Store Display Location Honors Store Scope

Expected:

* Store-scoped user can manage only permitted store display locations.

## 12.5 Super Administrator Has All Phase 3 Permissions

Expected:

* Seeded super administrator role receives all Phase 3 permissions.

---

# 13. Audit Event Tests

## 13.1 Required Phase 3 Audit Events Are Created

Test required events for:

* formats  
* catalog items  
* catalog item identifiers  
* display locations  
* store display locations  
* products  
* product conditions  
* product variants  
* vendors

## 13.2 Audit Event Includes Context

Expected:

* actor user  
* event name  
* auditable record  
* occurred at  
* store/workstation/session context when available

## 13.3 Record-Level Audit Timelines Work

Expected:

* Catalog item detail shows related audit events.  
* Product detail shows related audit events.  
* Variant detail shows related audit events.  
* Vendor detail shows related audit events.

---

# 14. Seed Tests

## 14.1 Format Seeds Are Idempotent

Expected:

* Running seeds multiple times does not duplicate formats.

## 14.2 Product Condition Seeds Are Idempotent

Expected:

* Running seeds multiple times does not duplicate conditions.

## 14.3 Display Location Seeds Are Idempotent

Expected:

* Running seeds multiple times does not duplicate seeded display locations.

## 14.4 Vendor Seeds Are Idempotent

Expected:

* Running seeds multiple times does not duplicate seeded vendors.

## 14.5 Phase 3 Permissions Are Seeded

Expected:

* All Phase 3 permissions exist.  
* Super administrator receives all permissions.

---

# 15. Regression Risks

These areas require regression coverage in later phases:

1. SKU changes after inventory or transactions exist.  
2. Identifier changes after products exist.  
3. Scanning alternate identifiers.  
4. Variant SKU generation.  
5. Product/variant name snapshots on sale lines.  
6. Category changes after inventory exists.  
7. Inventory behavior during POS.  
8. Vendor sourcing once purchasing is implemented.  
9. Display location versus inventory location confusion.  
10. JSONB metadata search limitations.

---

# 16. Minimum Definition of Done

Phase 3 is done only when:

1. All migrations run cleanly.  
2. Phase 3 seeds are idempotent.  
3. Catalog items can be created with required identifiers.  
4. Identifier normalization/validation works.  
5. ISBN-10 conversion works.  
6. Local identifier generation works.  
7. Products can be created from catalog items.  
8. Non-catalog products can be created.  
9. Product SKUs are required and unique.  
10. Variants can be created and SKU generation works.  
11. Product and variant names are generated and overrideable.  
12. Product conditions are seeded.  
13. Display locations and store display locations work.  
14. Vendors can be managed.  
15. Authorization is enforced.  
16. Audit events are created.  
17. Phase 3 test suite passes.