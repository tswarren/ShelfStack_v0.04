# Phase 3 Data Model

## Purpose

This document defines the Phase 3 ShelfStack data model, including tables, fields, recommended indexes, constraints, controlled values, and seed data.

This document should be treated as the source of truth for Phase 3 migrations.

---

# 1. Naming Conventions

## 1.1 Tables

Phase 3 introduces:

```text
formats
catalog_items
catalog_item_identifiers
display_locations
store_display_locations
products
product_conditions
product_variants
vendors
```

  
---

## 1.2 Booleans

Use Rails-style boolean names without `is_`.

Use:

```
active
virtual
digital
large_print
new_condition
primary_identifier
```

Avoid:

```
is_active
is_virtual
is_digital
is_large_print
is_new
```

---

## 1.3 JSONB

Use `jsonb` for structured metadata fields:

```
creator_details
publisher_details
series_data
bisac_subject_data
genre_data
theme_data
target_audience_data
access_restriction_data
```

---

# 2. Table Matrix

## 2.1 `formats`

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `format_key` | string | null false, unique, limit 30 | Stable key. Example: `hardcover`, `trade_paperback`, `dvd`. |
| `name` | string | null false | Full format name. |
| `short_name` | string | null false, limit 20 | Short display name. |
| `code` | string | limit 20 | Optional external/internal code. |
| `virtual` | boolean | null false, default false | True for digital/virtual formats. |
| `active` | boolean | null false, default true | Inactive formats cannot be assigned to new records. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

## 2.2 `catalog_items`

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `catalog_item_type` | string | null false | Controlled value. |
| `title` | string | null false | Main title/display title. |
| `creators` | string | nullable | Semicolon-separated display string. |
| `creator_details` | jsonb | nullable | Parsed creator details. |
| `publisher` | string | nullable | Publisher display string. |
| `publisher_details` | jsonb | nullable | Optional structured publisher data. |
| `publication_date` | date | nullable | Publication/release date. |
| `publication_status` | string | null false, default `active` | Controlled value. |
| `series_name` | string | nullable | Series name. |
| `series_enumeration` | string | limit 15 | Volume/number in series. |
| `series_data` | jsonb | nullable | Optional structured series data. |
| `format_id` | bigint | references `formats`, null false | Catalog format. |
| `edition_statement` | string | nullable | Example: `2nd edition`, `Revised edition`. |
| `language_code` | string | limit 10 | Optional language code. |
| `height` | decimal(10,2) | nullable |  |
| `width` | decimal(10,2) | nullable |  |
| `depth` | decimal(10,2) | nullable |  |
| `dimension_units` | string | nullable | `cm`, `in`. |
| `weight` | decimal(10,2) | nullable |  |
| `weight_units` | string | nullable | `g`, `kg`, `lb`, `oz`. |
| `page_count` | integer | nullable |  |
| `duration_minutes` | integer | nullable |  |
| `large_print` | boolean | null false, default false |  |
| `bisac_subjects` | string | nullable | Display string. |
| `bisac_subject_data` | jsonb | nullable | Parsed subject data. |
| `genres` | string | nullable | Display string. |
| `genre_data` | jsonb | nullable | Parsed genre data. |
| `themes` | string | nullable | Display string. |
| `theme_data` | jsonb | nullable | Parsed theme data. |
| `target_audiences` | string | nullable | Display string. |
| `target_audience_data` | jsonb | nullable | Parsed audience data. |
| `access_restrictions` | string | nullable | Display string. |
| `access_restriction_data` | jsonb | nullable | Parsed restriction data. |
| `publication_frequency` | string | nullable | Controlled value. |
| `description` | text | nullable | Description/summary. |
| `year` | string | limit 4 | Four-digit year for calendars/annuals. |
| `digital` | boolean | null false, default false | Digital catalog item flag. |
| `store_category_id` | bigint | references `category_nodes`, nullable | Store topic category (`store_categories` scheme). |
| `active` | boolean | null false, default true | Inactive catalog items cannot be linked to new products. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

## 2.3 `catalog_item_identifiers`

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `catalog_item_id` | bigint | references `catalog_items`, null false | Parent catalog item. |
| `identifier_type` | string | null false | Controlled value. |
| `identifier_value` | string | null false, limit 100 | Display/preserved value. |
| `normalized_identifier` | string | null false, limit 100 | Search/index value. |
| `primary_identifier` | boolean | null false, default false | Exactly one active primary per catalog item. |
| `valid_check_digit` | boolean | nullable | Null when not applicable. |
| `validation_message` | string | nullable | Warning or validation message. |
| `source` | string | nullable | Example: `manual`, `local_generated`, `vendor_feed`. |
| `active` | boolean | null false, default true | Inactive identifiers ignored for primary lookup. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

## 2.4 `display_locations`

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `name` | string | null false | Full display location name. |
| `short_name` | string | null false, unique, limit 20 | Short display name. |
| `parent_id` | bigint | references `display_locations`, nullable | Optional hierarchy. |
| `sort_order` | integer | null false, default 0 | Display order. |
| `active` | boolean | null false, default true | Inactive locations cannot be assigned to new products/variants. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

## 2.5 `store_display_locations`

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `display_location_id` | bigint | references `display_locations`, null false | Global display location. |
| `store_id` | bigint | references `stores`, null false | Store using this location. |
| `linear_feet` | integer | null false, default 0 | Optional merchandising capacity. |
| `active` | boolean | null false, default true | Inactive store locations cannot be assigned to new products/variants. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

## 2.6 `products`

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `catalog_item_id` | bigint | references `catalog_items`, nullable | Nullable for non-catalog products. |
| `name` | string | null false | Current store-facing product name. |
| `name_override` | string | nullable | Optional user override. |
| `short_name` | string | limit 40 | Optional compact display name. |
| `sku` | string | null false, unique, limit 50 | Base SKU for variants. |
| `product_type` | string | null false, default `physical` | Controlled value. |
| `variation_type` | string | null false, default `standard` | Controlled value. |
| `list_price_cents` | integer | null false, default 0 | MSRP/list/cover price when applicable. |
| `default_display_location_id` | bigint | references `display_locations`, nullable | Default merchandising location. |
| `default_sub_department_id` | bigint | references `sub_departments`, nullable | Default subdepartment for variants (catalog path may inherit from store category). |
| `variant1_label` | string | nullable | Example: `Color`, `Size`. |
| `variant2_label` | string | nullable | Example: `Size`, `Style`. |
| `active` | boolean | null false, default true | Inactive products cannot be used for new variants/sales. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

## 2.7 `product_conditions`

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `condition_key` | string | null false, unique | Stable seed key. |
| `name` | string | null false | Full display name. |
| `short_name` | string | null false, unique, limit 20 | Short display name. |
| `sku_component` | string | unique, limit 5 | Nullable for New. Normalize uppercase. |
| `sort_order` | integer | null false, default 0 | Display order. |
| `new_condition` | boolean | null false, default false | True for non-used/new-like conditions. |
| `default_list_price_factor_bps` | integer | null false, default 10000 | Factor applied to list price. |
| `description` | text | nullable | Optional. |
| `active` | boolean | null false, default true | Inactive conditions cannot be assigned to new variants. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

## 2.8 `product_variants`

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `product_id` | bigint | references `products`, null false | Parent product. |
| `name` | string | null false | Current store-facing variant name. |
| `name_override` | string | nullable | Optional user override. |
| `short_name` | string | limit 40 | Optional compact POS/receipt name. |
| `sku` | string | null false, unique, limit 50 | Actual sellable SKU. |
| `condition_id` | bigint | references `product_conditions`, nullable | Primary condition. |
| `sub_department_id` | bigint | references `sub_departments`, null false | Required operational subdepartment for sellable SKU. |
| `display_location_id` | bigint | references `display_locations`, nullable | Variant display override. |
| `attribute1_value` | string | nullable | Example: `Blue`. |
| `attribute1_sku_component` | string | limit 5 | Example: `BLU`. |
| `attribute2_value` | string | nullable | Example: `Large`. |
| `attribute2_sku_component` | string | limit 5 | Example: `LG`. |
| `selling_price_cents` | integer | null false, default 0 | Current selling price. |
| `pricing_model_override` | string | nullable | Controlled Phase 2 pricing model value. |
| `inventory_behavior` | string | null false, default `standard_physical` | Controlled value. |
| `active` | boolean | null false, default true | Inactive variants cannot be sold/ordered. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

## 2.9 `vendors`

| Field | Type | Constraints | Notes |
| :---- | ----: | :---- | :---- |
| `id` | bigint | auto increment |  |
| `name` | string | null false | Vendor/supplier name. |
| `parent_vendor_id` | bigint | references `vendors`, nullable | Parent vendor/group. |
| `default_pricing_model` | string | nullable | Controlled Phase 2 pricing model value. |
| `default_margin_target_bps` | integer | nullable | Optional default margin target. |
| `default_supplier_discount_bps` | integer | nullable | Optional supplier discount. |
| `active` | boolean | null false, default true | Inactive vendors cannot be assigned to new future sourcing records. |
| `created_at` | datetime | null false |  |
| `updated_at` | datetime | null false |  |

---

# 3. Controlled Values

## 3.1 `catalog_items.catalog_item_type`

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

## 3.2 `catalog_items.publication_status`

```
active
not_yet_published
out_of_print
out_of_stock_indefinitely
discontinued
publication_cancelled
unknown
```

## 3.3 `catalog_items.publication_frequency`

```
daily
weekly
biweekly
semi_monthly
monthly
bi_monthly
quarterly
semi_annual
annual
irregular
unknown
```

## 3.4 `catalog_item_identifiers.identifier_type`

```
isbn10
isbn13
ean
upc
gtin
publisher_number
local
```

## 3.5 `products.product_type`

```
physical
digital
service
non_inventory
financial
```

## 3.6 `products.variation_type`

```
standard
conditional
variable
matrix
```

## 3.7 `product_variants.inventory_behavior`

```
standard_physical
digital_asset
drop_ship
composite_recipe
capacitated_service
pure_financial
non_inventory
```

## 3.8 Pricing Model Values

Use Phase 2 pricing model values:

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

---

# 4. Recommended Indexes

## 4.1 `formats`

| Index | Type |
| :---- | :---- |
| `format_key` | unique |
| `short_name` | normal |
| `code` | normal |
| `active` | normal |

## 4.2 `catalog_items`

| Index | Type |
| :---- | :---- |
| `catalog_item_type` | normal |
| `title` | normal |
| `publisher` | normal |
| `publication_status` | normal |
| `format_id` | normal |
| `series_name` | normal |
| `year` | normal |
| `active` | normal |

## 4.3 `catalog_item_identifiers`

| Index | Type | Notes |
| :---- | :---- | :---- |
| `catalog_item_id` | normal | Parent lookup. |
| `identifier_type, normalized_identifier` for standard/local identifiers | unique partial | Exclude publisher numbers if not globally unique. |
| `normalized_identifier` | normal | Fast search/scanning. |
| `catalog_item_id` where `active = true AND primary_identifier = true` | partial unique | Enforces one active primary. |
| `active` | normal | Active/inactive filtering. |

## 4.4 `display_locations`

| Index | Type |
| :---- | :---- |
| `short_name` | unique |
| `parent_id` | normal |
| `sort_order` | normal |
| `active` | normal |

## 4.5 `store_display_locations`

| Index | Type |
| :---- | :---- |
| `display_location_id` | normal |
| `store_id` | normal |
| `store_id, display_location_id` | unique composite |
| `active` | normal |

## 4.6 `products`

| Index | Type |
| :---- | :---- |
| `catalog_item_id` | normal |
| `sku` | unique |
| `name` | normal |
| `product_type` | normal |
| `variation_type` | normal |
| `default_display_location_id` | normal |
| `active` | normal |

## 4.7 `product_conditions`

| Index | Type |
| :---- | :---- |
| `condition_key` | unique |
| `short_name` | unique |
| `sku_component` | unique partial or unique allowing nulls |
| `sort_order` | normal |
| `new_condition` | normal |
| `active` | normal |

## 4.8 `product_variants`

| Index | Type |
| :---- | :---- |
| `product_id` | normal |
| `sku` | unique |
| `condition_id` | normal |
| `sub_department_id` | normal |
| `display_location_id` | normal |
| `inventory_behavior` | normal |
| `pricing_model_override` | normal |
| `active` | normal |

## 4.9 `vendors`

| Index | Type |
| :---- | :---- |
| `name` | normal or unique, depending policy |
| `parent_vendor_id` | normal |
| `default_pricing_model` | normal |
| `active` | normal |

---

# 5. Recommended Constraints

## 5.1 One Active Primary Identifier

```sql
CREATE UNIQUE INDEX index_catalog_item_identifiers_one_active_primary
ON catalog_item_identifiers (catalog_item_id)
WHERE active = true AND primary_identifier = true;
```

## 5.2 Product Condition Factor Range

```sql
ALTER TABLE product_conditions
ADD CONSTRAINT chk_product_conditions_list_price_factor
CHECK (
  default_list_price_factor_bps >= 0
  AND default_list_price_factor_bps <= 10000
);
```

## 5.3 Product and Variant Prices

```sql
ALTER TABLE products
ADD CONSTRAINT chk_products_list_price_cents
CHECK (list_price_cents >= 0);

ALTER TABLE product_variants
ADD CONSTRAINT chk_product_variants_selling_price_cents
CHECK (selling_price_cents >= 0);
```

## 5.4 Year Format

```sql
ALTER TABLE catalog_items
ADD CONSTRAINT chk_catalog_items_year_format
CHECK (
  year IS NULL
  OR year ~ '^[0-9]{4}$'
);
```

## 5.5 Store Display Location Uniqueness

```sql
CREATE UNIQUE INDEX index_store_display_locations_unique
ON store_display_locations (store_id, display_location_id);
```

---

# 6. Seed Data

## 6.1 Product Conditions

| Condition Key | Name | Short Name | SKU Component | Sort | New Condition | Factor BPS |
| :---- | :---- | :---- | :---- | ----: | ----: | ----: |
| `new` | New | New | null | 0 | true | 10000 |
| `signed_copy` | Signed Copy | Signed | SG | 1 | true | 10000 |
| `special_edition` | Special Edition | Special Edition | SP | 2 | true | 10000 |
| `used_like_new` | Used \- Like New | Like New | UN | 11 | false | 9000 |
| `used_very_fine` | Used \- Very Fine | Very Fine | UV | 12 | false | 7000 |
| `used_fine` | Used \- Fine | Fine | UF | 13 | false | 6000 |
| `used_good` | Used \- Good | Good | UG | 14 | false | 5000 |
| `used_poor` | Used \- Poor | Poor | UP | 15 | false | 3000 |
| `used_ex_library` | Used \- Ex-Library | Ex-Library | UX | 16 | false | 4000 |
| `used_book_club` | Used \- Book Club | Book Club Edition | UB | 17 | false | 2500 |
| `remainder` | Remainder | Remainder | RM | 21 | true | 10000 |

## 6.2 Example Formats

| Format Key | Name | Short Name | Code | Virtual |
| :---- | :---- | :---- | :---- | ----: |
| `hardcover` | Hardcover | Hardcover | HC | false |
| `trade_paperback` | Trade Paperback | Trade PB | TP | false |
| `mass_market_paperback` | Mass Market Paperback | Mass Market | MM | false |
| `calendar` | Calendar | Calendar | CAL | false |
| `magazine` | Magazine | Magazine | MAG | false |
| `compact_disc` | Compact Disc | CD | CD | false |
| `dvd` | DVD | DVD | DVD | false |
| `ebook` | eBook | eBook | EBK | true |
| `audiobook_digital` | Digital Audiobook | Digital Audio | DAB | true |
| `sideline` | Sideline | Sideline | SIDE | false |

## 6.3 Example Display Locations

| Name | Short Name |
| :---- | :---- |
| Front Table | Front Table |
| New Releases | New Releases |
| Fiction | Fiction |
| Children’s | Children’s |
| Bargain | Bargain |
| Register Counter | Register |

## 6.4 Example Vendors

| Name | Notes |
| :---- | :---- |
| Ingram | Book distributor demo vendor. |
| Local Vendor | Generic local/vendor demo record. |
| Direct Publisher | Generic direct publisher demo record. |

---

# 7. Migration Notes

## 7.1 Dependencies

Phase 3 depends on:

```
stores
categories
tax_categories
permissions
roles
role_permissions
audit_events
```

## 7.2 Deferred Tables

Do not add these in Phase 3 unless scope changes:

```
product_variant_identifiers
product_variant_vendors
catalog_item_contributors
catalog_item_subjects
publishers
contributors
subjects
inventory_ledger
stock_balances
product_price_history
```

## 7.3 Deletion Policy

Use restrictive foreign keys where practical.

Prefer inactivation over deletion after references exist.

---

# Appendix A — Classification target migration (post Phase 3B)

Authority: `docs/specifications/classification-target-spec.md`

## Renamed table: `sub_departments`

Renamed from `merchandise_classes`. Stable key column: `sub_department_key`.

| Field | Type | Notes |
| :---- | ----: | :---- |
| `department_id` | bigint | **Required.** FK to `departments`; parent reporting/GL department |
| `default_variation_type` | string | Default `standard`; validates against `Product::VARIATION_TYPES` |
| `default_inventory_behavior` | string | Validates against `ProductVariant::INVENTORY_BEHAVIORS` |
| `default_tax_category_id` | bigint | Operational tax default (unchanged from merchandise class) |

Legacy `categories.sub_department_id` remains a bridge from Phase 2 categories during setup reference only; item entry uses variant `sub_department_id` directly.

## `catalog_items.store_category_id`

| Field | Type | Notes |
| :---- | ----: | :---- |
| `store_category_id` | bigint | Nullable FK to `category_nodes` in the `store_categories` scheme |

## `category_nodes` default FKs

| Field | Type | Notes |
| :---- | ----: | :---- |
| `default_sub_department_id` | bigint | Nullable FK to `sub_departments` |
| `default_display_location_id` | bigint | Nullable FK to `display_locations` |
| `default_store_category_id` | bigint | Nullable self-FK; used on BISAC nodes to suggest a store category |

## `products.default_sub_department_id`

| Field | Type | Notes |
| :---- | ----: | :---- |
| `default_sub_department_id` | bigint | Nullable FK to `sub_departments`; may be set from store category defaults on catalog path |

## `product_variants` classification (updated)

Replace prior `category_id` documentation with:

| Field | Type | Notes |
| :---- | ----: | :---- |
| `sub_department_id` | bigint | **Required.** FK to `sub_departments`; sellable operational classification |

`category_id` removed in migration `20250615120200_classification_target_retire_legacy`.

## Index updates

| Table | Index |
| :---- | :---- |
| `product_variants` | `sub_department_id` (replaces `category_id`) |
| `catalog_items` | `store_category_id` |
| `products` | `default_sub_department_id` |