# Phase 3 Catalog, Products, and Product Variants Functional Specification

## Purpose

This specification defines the functional behavior for ShelfStack Phase 3.

Phase 3 establishes the catalog metadata and sellable SKU foundation used by later inventory, purchasing, receiving, and POS workflows.

For schema details, see:

```text
docs/specifications/phase-3-data-model.md
```

  
For test coverage, see:

```
docs/specifications/phase-3-test-plan.md
```

---

# 1. Core Concepts

## 1.1 Catalog Item

A catalog item is a metadata record.

It describes the thing being sold or tracked:

* Book  
* Calendar  
* Periodical  
* Recorded music  
* Videorecording  
* Audiobook  
* eBook  
* Map  
* Game  
* Gift item  
* Sideline  
* Other catalog record

A catalog item may be linked to one or more products, but is not itself the POS-sellable SKU.

---

## 1.2 Catalog Item Identifier

A catalog item identifier is an external or local identifier associated with a catalog item.

Supported identifier types:

```
isbn10
isbn13
ean
upc
gtin
publisher_number
local
```

Every catalog item must have at least one active identifier.

Every catalog item must have exactly one active primary identifier.

---

## 1.3 Product

A product is the store-facing product grouping.

Products may be:

* Catalog-linked  
* Non-catalog-linked

A catalog-linked product defaults its name and SKU from catalog metadata.

A non-catalog-linked product uses user-entered or system-generated values.

---

## 1.4 Product Variant

A product variant is the actual sellable SKU.

Future POS, receiving, ordering, and inventory workflows should operate at the product variant level.

A product is not sellable until it has at least one active product variant.

---

## 1.5 Product Condition

A product condition describes the variant’s condition or special state.

Examples:

* New  
* Signed Copy  
* Used \- Like New  
* Used \- Good  
* Remainder

Conditions may contribute to SKU generation and default price factor calculations.

---

## 1.6 Display Location

A display location describes merchandising placement.

Examples:

* Front Table  
* New Fiction  
* Children’s Wall  
* Bargain Cart  
* Register Counter

Display locations are not inventory locations.

---

## 1.7 Vendor

A vendor is a supplier or source organization.

Phase 3 includes a basic vendor directory only.

Vendor-product sourcing and vendor ordering rules are deferred.

---

# 2. Catalog Item Types

Supported `catalog_item_type` values:

```
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

The catalog item type controls form display and suggested metadata fields.

It should not create hard database restrictions that block unusual but valid metadata.

---

# 3. Catalog Item Dynamic Field Display

The UI should show or emphasize fields based on `catalog_item_type`.

Common fields shown for all catalog item types:

* Catalog item type  
* Title  
* Publisher  
* Publisher details  
* Publication status  
* Format  
* Description

Metadata field display is a UI/configuration concern, not a database constraint.

## General field display guidance

| Field | Used For |
| :---- | :---- |
| `creators` / `creator_details` | Books, calendars, recorded music, videos, audiobooks, ebooks, other. |
| `publisher` / `publisher_details` | Most types. |
| `publication_date` | Books, periodicals, media, audiobooks, ebooks, other. |
| `series_name` / `series_data` | Books, recorded music, videos, audiobooks, ebooks, other. |
| `dimensions` / `weight` | Physical items. Usually hidden for ebooks. |
| `page_count` | Books and other text-like items. |
| `duration_minutes` | Recorded music, videos, audiobooks, other timed media. |
| `large_print` | Books and other text-like items. |
| `subjects` | Books, audiobooks, ebooks, other. |
| `genres` | Books, periodicals, recorded music, videos, other. |
| `themes` | Most types except where irrelevant. |
| `target_audiences` | Books, periodicals, media, games, gifts, other. |
| `access_restrictions` | Periodicals, recorded music, videos, other. |
| `publication_frequency` | Periodicals and other recurring publications. |
| `year` | Calendars, annuals, planners, year-specific items, other. |
| `digital` | Digital media and other digital items. |

---

# 4. Catalog Item Identifiers

## 4.1 Required Identifier Rule

Every catalog item must have:

1. At least one active identifier.  
2. Exactly one active primary identifier.

This rule should be enforced through catalog item creation/update services.

---

## 4.2 Identifier Types

| Type | Meaning |
| :---- | :---- |
| `isbn10` | Legacy 10-digit ISBN. |
| `isbn13` | Current 13-digit ISBN. |
| `ean` | European Article Number / EAN barcode. |
| `upc` | Universal Product Code. |
| `gtin` | Global Trade Item Number. |
| `publisher_number` | Publisher/vendor/catalog number. |
| `local` | ShelfStack-generated local identifier. |

---

## 4.3 Standard Identifier Normalization

For these identifier types:

```
isbn10
isbn13
ean
upc
gtin
```

ShelfStack should:

1. Remove spaces.  
2. Remove punctuation.  
3. Keep digits only, except ISBN-10 may allow terminal `X`.  
4. Normalize ISBN-10 terminal `x` to `X`.  
5. Validate the check digit.  
6. Store validation result.

Invalid identifiers may be saved, but the user must be warned.

---

## 4.4 ISBN-10 Conversion

When a user enters an ISBN-10:

1. Normalize the ISBN-10.  
2. Validate the ISBN-10 check digit.  
3. Save the ISBN-10 as a non-primary identifier.  
4. Convert ISBN-10 to ISBN-13 using prefix `978`.  
5. Recalculate the ISBN-13 check digit.  
6. Save the generated ISBN-13 as the primary identifier.  
7. Use the generated ISBN-13 as the catalog item’s primary identifier.

Example:

| User Enters | Saved Identifier | Primary? |
| :---- | :---- | ----: |
| `0123456789` | ISBN-10 `0123456789` | false |
| generated | ISBN-13 `9780123456786` | true |

---

## 4.5 Publisher Number Normalization

Publisher numbers preserve display punctuation/spacing but store a normalized searchable value.

Example:

| Display Value | Normalized Identifier |
| :---- | :---- |
| `ABC 123-45` | `ABC12345` |

Rules:

* Preserve entered display value in `identifier_value`.  
* Store uppercase alphanumeric-only value in `normalized_identifier`.  
* Do not apply ISBN/UPC/EAN/GTIN check digit validation.  
* Do not require global uniqueness for publisher numbers.

---

## 4.6 Local Identifier Generation

When an item does not have a manufacturer/vendor identifier, the user may generate a local identifier.

Recommended format:

```
L000000001
```

Behavior:

1. User selects “Generate Local Identifier.”  
2. ShelfStack generates the next available local identifier.  
3. Local identifier is saved as active.  
4. Local identifier becomes primary unless another primary is explicitly selected.  
5. Catalog-linked product SKU defaults from the local identifier.

---

## 4.7 Primary Identifier Changes

Changing a catalog item’s primary identifier does not automatically change existing product or variant SKUs after products, variants, inventory, or transaction history exist.

Rules:

1. New catalog-linked products use the current primary identifier.  
2. Existing products keep their SKU unless explicitly changed.  
3. Product SKU changes are permission-controlled and audited.  
4. Future transaction records must snapshot SKU/name data at time of sale.

---

# 5. Creator Metadata

## 5.1 Manual Entry Format

Users may enter creators as semicolon-separated values.

Example:

```
Smith, John [author]; Doe, Jane [actor; director]; The Beatles [performer]
```

---

## 5.2 Stored Display String

The entered string is preserved in `catalog_items.creators`.

Example:

```
Smith, John [author]; Doe, Jane [actor; director]; The Beatles [performer]
```

---

## 5.3 Stored JSONB

The system parses the value into `creator_details`.

Example:

```json
[
  {
    "display_name": "Smith, John",
    "name_type": "person",
    "family_name": "Smith",
    "given_names": "John",
    "roles": ["author"]
  },
  {
    "display_name": "Doe, Jane",
    "name_type": "person",
    "family_name": "Doe",
    "given_names": "Jane",
    "roles": ["actor", "director"]
  },
  {
    "display_name": "The Beatles",
    "name_type": "unknown",
    "family_name": null,
    "given_names": null,
    "roles": ["performer"]
  }
]
```

---

## 5.4 Creator Parsing Rules

1. Split creators on semicolons outside brackets.  
2. Trim whitespace.  
3. Ignore blank entries.  
4. If a creator contains bracketed roles, parse roles.  
5. If name contains a comma, parse as `family_name, given_names`.  
6. If name does not contain a comma, preserve `display_name` and do not over-parse.  
7. Normalize roles to lowercase/snake\_case.  
8. Preserve original display name.

---

# 6. Subject and Classification Metadata

## 6.1 Manual Entry Format

Users may enter subjects as semicolon-separated values.

Examples:

```
HISTORY > General [BISAC/HIS000000]
Comedy [local]
Fiction > Mystery [BISAC/FIC022000]
```

---

## 6.2 Stored Display String

The entered string is preserved in the corresponding display field, such as:

```
bisac_subjects
genres
themes
target_audiences
```

---

## 6.3 Stored JSONB

Example:

```json
[
  {
    "heading": "HISTORY > General",
    "scheme": "BISAC",
    "code": "HIS000000"
  },
  {
    "heading": "Comedy",
    "scheme": "local",
    "code": null
  }
]
```

Structured catalog item forms select BISAC subjects from the imported `CategoryScheme(bisac)` tree. Linked nodes are stored as `Categorization` records; `bisac_subjects` and `bisac_subject_data` are regenerated from those links for export and import compatibility. A collapsed advanced field still accepts pasted publisher or Ingram subject strings.

---

## 6.4 Subject Parsing Rules

1. Split entries on semicolons outside brackets.  
2. Trim whitespace.  
3. Ignore blank entries.  
4. Parse `[SCHEME/CODE]` when present.  
5. Parse `[SCHEME]` when present.  
6. If no scheme is provided, default to `local`.  
7. Preserve heading exactly as entered, except trimmed whitespace.  
8. Normalize scheme consistently.  
9. Store code when present.

---

# 7. Product Behavior

## 7.1 Catalog-Linked Product Creation

When creating a product linked to a catalog item:

1. Product name defaults from catalog item title.  
2. Product SKU defaults from catalog item primary identifier.  
3. Product list price may be entered manually.  
4. Product type defaults based on format/product context.  
5. Product is active by default.  
6. Product is not sellable until at least one active variant exists.

---

## 7.2 Non-Catalog Product Creation

For products not linked to catalog items:

1. User enters product name.  
2. User may manually enter product SKU.  
3. User may request system-generated SKU.  
4. Product type is selected.  
5. Product is active by default.  
6. Product is not sellable until at least one active variant exists.

---

## 7.3 Product SKU Rules

Product SKU is the base SKU for variants.

Rules:

1. Required.  
2. Unique.  
3. Normalized consistently.  
4. Catalog-linked products default to catalog primary identifier.  
5. Non-catalog products may be manual or generated.  
6. SKU changes are permission-controlled and audited.  
7. SKU changes should be restricted after variants, inventory, or transaction history exist.

---

## 7.4 Product Name Rules

Catalog-linked product:

```
product.name = catalog_item.title
```

Non-catalog product:

```
product.name = user-entered name
```

General rules:

1. Product name is store-facing.  
2. Product name is used in POS, ordering, setup, and search.  
3. Product name should be conservatively generated.  
4. User may provide `name_override`.  
5. Product may have optional `short_name`.  
6. Name changes are audited.  
7. Automatic title cleanup should be conservative.

---

# 8. Product Variant Behavior

## 8.1 Variant Creation

Product variants are the actual sellable SKUs.

Required fields:

* Product  
* Name  
* SKU  
* Category  
* Selling price  
* Inventory behavior

Optional fields:

* Condition  
* Display location  
* Attribute 1  
* Attribute 2  
* Pricing model override  
* Name override  
* Short name

---

## 8.2 Variant SKU Generation

### New/default variant

If condition is New and no attributes are present:

```
variant_sku = product_sku
```

Example:

```
9780123456789
```

### Condition variant

```
variant_sku = product_sku + "-" + condition.sku_component
```

Example:

```
9780123456789-SG
9780123456789-UN
```

### Variable variant

```
variant_sku = product_sku + "-" + attribute1_sku_component
```

Example:

```
9780123456789-BLU
```

### Matrix variant

```
variant_sku = product_sku + "-" + attribute1_sku_component + "-" + attribute2_sku_component
```

Example:

```
9780123456789-BLU-LG
```

### Collision rule

Generated SKU must be unique.

If generated SKU already exists, creation must fail or prompt for manual adjustment.

---

## 8.3 Unsuffixed Variant Rule

A product may have at most one variant whose SKU equals the base product SKU.

This is normally the New/default variant.

Additional variants must have a condition component or attribute component.

---

## 8.4 Variant Name Rendering

Variant names are generated from:

* Product name  
* Condition short name  
* Attribute values

### New/default variant

```
variant.name = product.name
```

### Condition variant

```
variant.name = product.name + " - " + condition.short_name
```

Example:

```
The Hobbit - Signed
The Hobbit - Like New
```

### Variable variant

```
variant.name = product.name + " - " + attribute1_value
```

Example:

```
Store T-Shirt - Blue
```

### Matrix variant

```
variant.name = product.name + " - " + attribute1_value + " / " + attribute2_value
```

Example:

```
Store T-Shirt - Blue / Large
```

### Condition and attributes

```
variant.name = product.name + " - " + condition.short_name + " - " + attributes
```

---

## 8.5 Name Overrides

Both products and variants support name overrides.

Rules:

1. If `name_override` is present, use it as the generated/current name.  
2. If `name_override` is blank, generate the name.  
3. Name changes are audited.  
4. Future transaction records must snapshot names at time of sale.

---

## 8.6 Inventory Behavior

Product variant inventory behavior values:

```
standard_physical
digital_asset
drop_ship
composite_recipe
capacitated_service
pure_financial
non_inventory
```

Meanings:

| Behavior | Meaning |
| :---- | :---- |
| `standard_physical` | Physical stocked item; future inventory decrement. |
| `digital_asset` | Digital item; no physical stock decrement. |
| `drop_ship` | Fulfilled externally; no in-store stock decrement. |
| `composite_recipe` | Finished item tied to recipe/bulk costing later. |
| `capacitated_service` | Event/ticket/service with capacity behavior later. |
| `pure_financial` | Donation/pass-through/financial item. |
| `non_inventory` | Ordinary non-stock sale/service. |

Phase 3 stores this behavior only. Actual inventory/POS behavior is implemented later.

---

# 9. Product Conditions

## 9.1 Product Condition Rules

Product conditions are controlled setup records.

Rules:

1. Conditions may be active/inactive.  
2. Inactive conditions cannot be assigned to new variants.  
3. `sku_component` is nullable.  
4. New condition has null `sku_component`.  
5. Non-null SKU components are normalized uppercase.  
6. `default_list_price_factor_bps` may be used to suggest used/special prices.  
7. One primary condition is assigned per variant in Phase 3.  
8. Condition stacking is deferred.

---

## 9.2 Seeded Product Conditions

| Name | Short Name | SKU Component | Sort Order | New Condition | Default List Price Factor BPS |
| :---- | :---- | :---- | ----: | ----: | ----: |
| New | New | null | 0 | true | 10000 |
| Signed Copy | Signed | SG | 1 | true | 10000 |
| Special Edition | Special Edition | SP | 2 | true | 10000 |
| Used \- Like New | Like New | UN | 11 | false | 9000 |
| Used \- Very Fine | Very Fine | UV | 12 | false | 7000 |
| Used \- Fine | Fine | UF | 13 | false | 6000 |
| Used \- Good | Good | UG | 14 | false | 5000 |
| Used \- Poor | Poor | UP | 15 | false | 3000 |
| Used \- Ex-Library | Ex-Library | UX | 16 | false | 4000 |
| Used \- Book Club | Book Club Edition | UB | 17 | false | 2500 |
| Remainder | Remainder | RM | 21 | true | 10000 |

---

# 10. Display Locations

## 10.1 Display Location Behavior

Display locations are global merchandising locations.

They may be hierarchical through `parent_id`.

Examples:

* Books  
    
  * Fiction  
  * Mystery  
  * Children’s


* Front Table  
    
* Register Counter  
    
* Bargain Cart

---

## 10.2 Store Display Locations

`store_display_locations` activates a display location for a store.

It may store optional merchandising capacity, such as `linear_feet`.

This is not an inventory balance.

---

# 11. Vendors

Phase 3 includes a basic vendor directory.

Vendors may have:

* Name  
* Parent vendor  
* Default pricing model  
* Default margin target  
* Default supplier discount

Vendor-product sourcing is deferred.

---

# 12. Setup Permissions

Phase 3 adds permissions for:

```
setup.formats.*
setup.catalog_items.*
setup.display_locations.*
setup.store_display_locations.*
setup.products.*
setup.product_conditions.*
setup.product_variants.*
setup.vendors.*
```

Each setup area should include:

```
view
create
update
inactivate
reactivate
delete
```

The seeded `super_administrator` role receives all Phase 3 permissions.

---

# 13. Audit Events

Required Phase 3 audit events include:

```
format.created
format.updated
format.inactivated
format.reactivated
format.deleted

catalog_item.created
catalog_item.updated
catalog_item.inactivated
catalog_item.reactivated
catalog_item.deleted

catalog_item_identifier.created
catalog_item_identifier.updated
catalog_item_identifier.inactivated
catalog_item_identifier.reactivated
catalog_item_identifier.deleted
catalog_item_identifier.primary_changed
catalog_item_identifier.local_generated
catalog_item_identifier.isbn10_converted

display_location.created
display_location.updated
display_location.inactivated
display_location.reactivated
display_location.deleted

store_display_location.created
store_display_location.updated
store_display_location.inactivated
store_display_location.reactivated
store_display_location.deleted

product.created
product.updated
product.inactivated
product.reactivated
product.deleted
product.sku_changed
product.name_regenerated

product_condition.created
product_condition.updated
product_condition.inactivated
product_condition.reactivated
product_condition.deleted

product_variant.created
product_variant.updated
product_variant.inactivated
product_variant.reactivated
product_variant.deleted
product_variant.sku_generated
product_variant.sku_changed
product_variant.name_regenerated

vendor.created
vendor.updated
vendor.inactivated
vendor.reactivated
vendor.deleted
```

---

# 14. Deletion and Inactivation Rules

| Record | Hard Delete? | Preferred Action Once Referenced |
| :---- | ----: | :---- |
| Format | Only if unused | Inactivate |
| Catalog Item | Only if unused | Inactivate |
| Catalog Item Identifier | Only if unused | Inactivate |
| Display Location | Only if unused | Inactivate |
| Store Display Location | Only if unused | Inactivate |
| Product | Only if unused | Inactivate |
| Product Condition | Only if unused | Inactivate |
| Product Variant | Only if unused | Inactivate |
| Vendor | Only if unused | Inactivate |

Future inventory and sales records should prevent destructive deletes.

---

# 15. Functional Acceptance Criteria

Phase 3 behavior is accepted when:

1. Catalog items support dynamic field display by type.  
2. Catalog item identifiers support normalization, validation, local generation, primary selection, and ISBN-10 conversion.  
3. Products can be catalog-linked or non-catalog-linked.  
4. Product SKUs are required and unique.  
5. Product variants are actual sellable SKUs.  
6. Variant SKU generation follows product/condition/attribute rules.  
7. Product and variant names are generated and overrideable.  
8. Product conditions use approved seed values.  
9. Display locations and store display locations are manageable.  
10. Vendors are manageable.  
11. Phase 3 permissions are seeded and enforced.  
12. Phase 3 audit events are created.  
13. Phase 3 seed data is idempotent.  
14. Phase 3 tests pass.