# Ingram Catalog Import Specification

## Purpose

Import sellable new items from Ingram spreadsheet exports into ShelfStack catalog items, products, and product variants.

Sample file: `docs/samples/List 06102026.xls`

---

## Row semantics

Each row represents a proposed sellable **new** item. The importer:

1. Resolves the catalog item by **EAN** (preferred) or **Product Code**
2. Creates or updates the catalog item and linked product
3. Creates a **new-condition** product variant only when an equivalent variant does not already exist
4. Matches existing variants without overwriting them

---

## Supported columns

| Ingram column | ShelfStack field |
|---|---|
| Product Code | ISBN-10 identifier lookup/creation |
| EAN | ISBN-13/EAN identifier lookup (preferred) |
| Product Name | `catalog_items.title` |
| Contributor | `catalog_items.creators` |
| Product Type | `catalog_items.catalog_item_type` |
| Format | `catalog_items.format_id` |
| Supplier | `catalog_items.publisher` |
| Pub Date | `catalog_items.publication_date` |
| Series | `catalog_items.series_name` |
| BISAC Category | `catalog_items.bisac_subjects` |
| US SRP | `products.list_price_cents` |
| Weight | `catalog_items.weight` (`weight_units: lb`) |

Deferred in v1: Disc Price, Dewey, Ingram Category, LC fields, harmonized code, country of manufacture.

---

## Upsert policy

### Catalog items

- **Create** when no identifier match exists
- **Update** bibliographic fields from the row on re-import
- Identifiers added when missing; conflicts between EAN and Product Code on different items produce row errors

### Products

- Resolve active catalog-linked product for the item (prefer SKU match, then conditional variation type)
- **Create** physical / conditional product when none exists
- **Update** `list_price_cents` from US SRP only

### Product variants

- Match active **new** condition variant with no variable/matrix attributes
- **Create** when missing, using import default category (and optional display location)
- **Never overwrite** existing variant attributes by default

---

## Authorization

Permission: `items.ingram_import.run`

UI: Items → Ingram Import

---

## Audit events

- `catalog_item.created` / `catalog_item.updated`
- `product.created` / `product.updated`
- `product_variant.created` (new variants only)
- `ingram_import.completed` (summary)
