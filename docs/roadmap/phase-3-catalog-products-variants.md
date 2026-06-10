# Phase 3: Catalog, Products, and Product Variants

## Purpose

Phase 3 establishes ShelfStack’s sellable-item foundation.

This phase introduces catalog metadata, product records, product variants/SKUs, product conditions, display locations, formats, and a basic vendor directory.

Phase 3 does not yet implement inventory balances, purchase orders, receiving, sales transactions, stock ledger posting, vendor ordering rules, or POS checkout. Instead, it creates the catalog and sellable SKU structure that those later workflows require.

---

## Goals

Phase 3 should provide a reliable foundation for:

1. Catalog metadata for books, periodicals, media, sidelines, and other bookstore items.
2. Multiple catalog identifiers per catalog item.
3. Exactly one active primary identifier per catalog item.
4. Standard identifier normalization and validation.
5. Local identifier generation for items without manufacturer/vendor identifiers.
6. ISBN-10 to ISBN-13 conversion behavior.
7. Product records linked optionally to catalog metadata.
8. Product SKUs as base SKUs for product variants.
9. Product variants as the actual POS-sellable SKUs.
10. Product condition handling for new, signed, used, remainder, and special copies.
11. Product/variant name rendering.
12. Dynamic catalog metadata fields based on catalog item type.
13. Creator and subject metadata parsing into JSONB.
14. Display location setup.
15. Store-specific display location activation.
16. Basic vendor setup.
17. Phase 3 permissions, audit events, setup screens, seed data, and tests.

---

## Non-Goals

Phase 3 does not include:

- Inventory ledger
- Stock balances
- Receiving
- Purchase orders
- Vendor-item sourcing rules
- Vendor costs
- Vendor terms
- Product price history
- Sale transactions
- POS checkout
- Discounts/promotions
- Stock transfers
- Customer special orders
- Tax calculation during sale
- GL posting
- Full bibliographic normalization into contributor/subject tables
- Full external bibliographic API integration
- Product image/media management
- Full recipe/BOM costing
- Event capacity tracking implementation

---

## Core Conceptual Model

ShelfStack separates catalog metadata from sellable products and sellable variants.

| Layer | Meaning | Example |
|---|---|---|
| Catalog Item | Descriptive metadata about a thing | ISBN title, publisher, creators, format, subjects |
| Product | Store-facing product grouping | The store’s product record for a catalog item or non-catalog item |
| Product Variant | Actual sellable SKU | New copy, signed copy, used copy, blue/large T-shirt, 16 oz latte |

This separation allows ShelfStack to support metadata-heavy items such as books and media while also supporting simpler non-catalog items such as cafe items, gift cards, event tickets, donations, and sidelines.

---

## Major Capabilities

| Capability | Description |
|---|---|
| Formats | Controlled list of catalog/product formats. |
| Catalog items | Metadata records for books, periodicals, media, sidelines, maps, games, gifts, and other items. |
| Catalog item identifiers | Multiple identifiers per catalog item, including ISBN, UPC, EAN, GTIN, publisher number, and local identifiers. |
| Primary identifiers | Exactly one active primary identifier per catalog item. |
| Local identifiers | System-generated identifiers for items without manufacturer/vendor identifiers. |
| Identifier validation | Normalize and validate standard identifiers while allowing invalid values with warnings. |
| Products | Store-facing product groupings, optionally linked to catalog items. |
| Product SKUs | Base SKUs used to generate variant SKUs. |
| Product variants | Actual sellable SKUs used by POS, ordering, and future inventory workflows. |
| Product conditions | Controlled setup for new, signed, used, remainder, and special item conditions. |
| SKU generation | Variant SKUs are generated from product SKU plus condition/attribute components. |
| Product names | Product and variant names are generated conservatively, overrideable, and auditable. |
| Display locations | Global merchandising/display locations. |
| Store display locations | Store-specific activation/capacity for display locations. |
| Vendors | Basic vendor/supplier directory. |
| Audit events | Setup changes and key generation actions create audit events. |
| Tests | Validations, identifiers, SKU generation, name rendering, setup access, audit events, and seeds are tested. |

---

## Internal Phase Breakdown

Phase 3 may be implemented as three internal workstreams.

---

## Phase 3A: Catalog Metadata Foundation

### Purpose

Build the descriptive metadata layer.

### Includes

- `formats`
- `catalog_items`
- `catalog_item_identifiers`
- Catalog item type behavior
- Identifier normalization and validation
- Local identifier generation
- ISBN-10 to ISBN-13 conversion
- Creator metadata parsing
- Subject metadata parsing
- Catalog search/list/detail screens
- Catalog setup permissions
- Catalog audit events

### Primary question answered

> What is this title, item, media object, or catalog record?

### Exit Criteria

Phase 3A is complete when:

1. Authorized users can manage formats.
2. Authorized users can create catalog items.
3. Catalog item type controls field display in the UI.
4. Catalog items require at least one active identifier.
5. Catalog items have exactly one active primary identifier.
6. Standard identifiers are normalized.
7. ISBN, UPC, EAN, and GTIN check digits are validated.
8. Invalid identifiers may be saved with warning.
9. ISBN-10 entries generate ISBN-13 primary identifiers.
10. Local identifiers can be generated.
11. Publisher numbers preserve display value and store normalized index value.
12. Creator semicolon entry parses to JSONB.
13. Subject semicolon entry parses to JSONB.
14. Catalog item changes create audit events.
15. Catalog item seeds/tests pass.

---

## Phase 3B: Product and Variant Foundation

### Purpose

Build the store-facing sellable item layer.

### Includes

- `products`
- `product_conditions`
- `product_variants`
- Product SKU rules
- Variant SKU generation
- Product name rendering
- Variant name rendering
- Product type and variation type behavior
- Product variant inventory behavior
- Product/variant setup permissions
- Product/variant audit events

### Primary question answered

> How does the store sell this item?

### Exit Criteria

Phase 3B is complete when:

1. Authorized users can create catalog-linked products.
2. Authorized users can create non-catalog-linked products.
3. Catalog-linked product SKUs default from catalog primary identifiers.
4. Non-catalog product SKUs may be user-entered or system-generated.
5. Product SKUs are required and unique.
6. Variant SKUs are required and unique.
7. New condition variants use the product SKU without suffix.
8. Condition variants append the condition SKU component.
9. Variable variants append attribute 1 SKU component.
10. Matrix variants append attribute 1 and attribute 2 SKU components.
11. Product names are generated from catalog titles or user entry.
12. Variant names are generated from product name plus condition/attributes.
13. Name overrides are supported.
14. Products are not sellable until at least one active variant exists.
15. Product/variant changes create audit events.
16. Product/variant tests pass.

---

## Phase 3C: Display Locations, Vendors, Setup UI, and Tests

### Purpose

Build supporting setup records and verify the Phase 3 foundation.

### Includes

- `display_locations`
- `store_display_locations`
- `vendors`
- Setup navigation updates
- Record-level audit timelines
- Phase 3 seed data
- Phase 3 test coverage

### Primary question answered

> Can the store organize, merchandise, and administer sellable items safely?

### Exit Criteria

Phase 3C is complete when:

1. Authorized users can manage display locations.
2. Authorized users can manage store display locations.
3. Authorized users can manage vendors.
4. Display locations support a hierarchy.
5. Store display locations activate display locations per store.
6. Display locations are clearly distinct from inventory locations.
7. Vendor directory exists, while vendor-item sourcing is deferred.
8. Setup navigation includes Phase 3 areas.
9. Record-level audit timelines work for Phase 3 records.
10. Phase 3 seed data is idempotent.
11. Phase 3 test suite passes.

---

## Models Introduced

Phase 3 introduces the following tables:

| Table | Purpose |
|---|---|
| `formats` | Controlled catalog/product formats. |
| `catalog_items` | Metadata records for books, media, periodicals, sidelines, and other items. |
| `catalog_item_identifiers` | Multiple identifiers per catalog item. |
| `display_locations` | Global merchandising/display location hierarchy. |
| `store_display_locations` | Store-specific activation/capacity for display locations. |
| `products` | Store-facing product records. |
| `product_conditions` | Controlled condition values for new/used/special/remainder variants. |
| `product_variants` | Actual sellable SKUs. |
| `vendors` | Basic vendor/supplier directory. |

---

## Key Design Decisions

### Catalog items are metadata records

Catalog items describe the item, title, publication, media object, or merchandise concept.

Catalog items are not themselves POS-sellable SKUs.

---

### Products are store-facing product groupings

A product is the store’s sellable product grouping.

A product may be linked to a catalog item, but does not have to be.

Examples of non-catalog products:

- Gift card
- Latte
- Event ticket
- Donation
- Shipping charge
- Local service
- Store merchandise

---

### Product variants are the actual sellable SKUs

A product variant is the record that future POS, ordering, and inventory workflows will sell or track.

Examples:

- New copy
- Signed copy
- Used - Like New
- Used - Good
- Blue / Large
- 16 oz
- General Admission

---

### Catalog items require identifiers

Every catalog item must have at least one active identifier.

A catalog item may have many identifiers, but must have exactly one active primary identifier.

---

### Primary identifier drives catalog-linked product SKU

For catalog-linked products:

```text
products.sku = catalog_item.primary_identifier
```

unless explicitly overridden by an authorized user.

---

### Local identifiers are generated when needed

If no manufacturer/vendor identifier exists, ShelfStack can generate a local identifier.

Example format:

```
L000000001
```

A generated local identifier may become the catalog item’s primary identifier.

---

### ISBN-10 is converted to ISBN-13

When a user enters an ISBN-10:

1. Save ISBN-10 as a non-primary identifier.  
2. Generate the equivalent ISBN-13 using the `978` prefix.  
3. Recalculate the ISBN-13 check digit.  
4. Save the generated ISBN-13 as the primary identifier.

---

### Invalid standard identifiers may be saved with warnings

ShelfStack normalizes and validates standard identifiers.

Invalid check digits do not block saving, but the user must be notified.

---

### Publisher numbers are preserved and indexed separately

Publisher numbers preserve display punctuation/spacing.

Example:

| Display Value | Normalized Index |
| :---- | :---- |
| `ABC 123-45` | `ABC12345` |

Publisher numbers are searchable but not globally unique by themselves.

---

### Product SKU is required

Product SKU is the base SKU for product variants.

Product SKU is required and unique.

---

### Variant SKU is required

Variant SKU is the actual sellable SKU.

Variant SKU is required and unique.

---

### New condition has no SKU suffix

For the New condition, `sku_component` is null.

Therefore:

```
new variant SKU = product SKU
```

Example:

```
9780123456789
```

---

### Condition variant SKU generation

For condition variants:

```
variant SKU = product SKU + "-" + condition.sku_component
```

Example:

```
9780123456789-SG
9780123456789-UN
```

---

### Variable variant SKU generation

For one-attribute variants:

```
variant SKU = product SKU + "-" + attribute1_sku_component
```

Example:

```
9780123456789-BLU
```

---

### Matrix variant SKU generation

For two-attribute variants:

```
variant SKU = product SKU + "-" + attribute1_sku_component + "-" + attribute2_sku_component
```

Example:

```
9780123456789-BLU-LG
```

---

### Product names are generated conservatively

For catalog-linked products:

```
product.name = catalog_item.title
```

For non-catalog products:

```
product.name = user-entered name
```

User overrides are allowed.

---

### Variant names are generated from product name and descriptors

Variant names are generated from:

* Product name  
* Condition short name  
* Attribute values

User overrides are allowed.

---

### Catalog item type controls UI display, not schema validity

`catalog_item_type` controls which fields are displayed or emphasized in the UI.

It should not create hard database restrictions that prevent unusual but valid metadata.

---

### Creator and subject detail fields use JSONB

Users may enter semicolon-separated creators and subjects.

ShelfStack preserves the display string and parses a structured JSONB detail field.

Full contributor/subject normalization is deferred.

---

### Display locations are merchandising locations

Display locations describe where an item is displayed, shelved, or merchandised.

They do not represent inventory ownership, inventory quantity, or stock ledger location.

---

### Vendor directory is basic in Phase 3

Phase 3 introduces vendors.

Vendor-product sourcing, vendor item numbers, vendor costs, discounts, terms, minimums, and ordering rules are deferred.

---

## Deferred Items

| Item | Reason |
| :---- | :---- |
| Product variant aliases | Useful for scanning alternate barcodes, but deferred. |
| Vendor-product sourcing | Better handled with purchasing/receiving. |
| Product price history | Deferred until pricing/POS phase. |
| Inventory ledger | Deferred until inventory phase. |
| Stock balances | Deferred until inventory phase. |
| Normalized contributors | JSONB is sufficient for Phase 3. |
| Normalized subjects | JSONB is sufficient for Phase 3. |
| Publisher normalization | Publisher string/JSONB is sufficient for Phase 3. |
| Product images | Deferred. |
| External bibliographic API integration | Deferred or optional later. |
| Full recipe/BOM costing | Inventory/costing phase. |
| Event capacity logic | POS/events phase. |

---

## Final Phase 3 Exit Criteria

Phase 3 is complete when all of the following are true.

### Catalog metadata

1. Formats can be managed by authorized users.  
2. Catalog items can be created and edited by authorized users.  
3. Catalog item type controls the form display.  
4. Catalog items require at least one active identifier.  
5. Catalog items have exactly one active primary identifier.  
6. Standard identifiers are normalized.  
7. ISBN, UPC, EAN, and GTIN check digits are validated.  
8. Invalid identifiers may be saved with warning.  
9. ISBN-10 creates a non-primary ISBN-10 and primary generated ISBN-13.  
10. Local identifiers can be generated.  
11. Creator entries parse to JSONB.  
12. Subject entries parse to JSONB.

### Products and variants

1. Products can be created by authorized users.  
2. Catalog-linked product SKU defaults from catalog primary identifier.  
3. Non-catalog product SKU may be manual or generated.  
4. Product SKU is required and unique.  
5. Product variants can be created by authorized users.  
6. Variant SKU is required and unique.  
7. Variant SKU generation follows condition/attribute rules.  
8. Product and variant names are generated and overrideable.  
9. Product is not sellable until it has at least one active variant.  
10. Product variant inventory behavior is recorded.

### Supporting setup

1. Product conditions can be managed by authorized users.  
2. Display locations can be managed by authorized users.  
3. Store display locations can be managed by authorized users.  
4. Vendors can be managed by authorized users.  
5. Phase 3 setup screens enforce permissions.  
6. Phase 3 setup changes create audit events.  
7. Phase 3 seeds are idempotent.