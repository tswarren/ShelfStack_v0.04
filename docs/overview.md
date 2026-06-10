# ShelfStack Overview

## What is ShelfStack?

ShelfStack is a bookstore-focused inventory, catalog, stock, and point-of-sale management application.

It is designed for independent bookstores and similar retailers that sell a mix of metadata-heavy products, such as books, periodicals, recorded music, videos, calendars, and audiobooks, alongside simpler non-bibliographic items such as sidelines, gifts, food and beverage items, services, donations, and gift cards.

ShelfStack separates descriptive catalog metadata from store-facing products and sellable SKUs. This allows the application to support detailed bibliographic records where needed while still remaining practical for ordinary retail merchandise.

---

## Core Purpose

ShelfStack exists to help stores answer four operational questions:

1. **What is this item?**
   Catalog metadata, identifiers, formats, creators, publishers, subjects, and descriptions.

2. **How does the store sell it?**
   Products, product variants, SKUs, prices, conditions, categories, display locations, and inventory behavior.

3. **Where is it and what is its stock status?**
   Future inventory ledger, stock balances, receiving, transfers, and adjustments.

4. **How should it be handled at POS and in reporting?**
   Departments, categories, tax categories, store tax rates, product variants, and transaction records.

---

## Intended Users

ShelfStack is intended for:

* Independent bookstores
* Used and new bookstores
* Bookstores with sidelines or gift departments
* Stores selling books plus media, calendars, magazines, games, gifts, and cafe/service items
* Multi-store booksellers that need store-specific tax, workstation, and inventory behavior

---

## Major Product Areas

ShelfStack is organized around these major domains:

| Domain         | Purpose                                                                            |
| -------------- | ---------------------------------------------------------------------------------- |
| Foundation     | Users, roles, permissions, stores, workstations, sessions, and audit events.       |
| Classification | Departments, categories, tax categories, store tax rates, and tax mappings.        |
| Catalog        | Metadata records for books, media, sidelines, and other cataloged items.           |
| Products       | Store-facing product records and product variants/SKUs.                            |
| Inventory      | Future stock ledger, stock balances, receiving, transfers, and adjustments.        |
| Purchasing     | Future vendors, purchase orders, receiving, returns to vendor, and supplier terms. |
| POS            | Future sales, returns, tendering, taxes, receipts, and drawer behavior.            |
| Reporting      | Future sales, tax, inventory valuation, purchasing, and operational reports.       |

---

## Design Philosophy

ShelfStack favors a layered model:

```text
Catalog Item → Product → Product Variant/SKU → Inventory/POS Activity
```

This keeps descriptive metadata separate from sellable behavior.

For example:

* A catalog item may describe a book title, ISBN, publisher, contributors, format, and subjects.
* A product represents how the store offers that catalog item.
* A product variant represents the actual sellable SKU, such as New, Signed, Used - Like New, or Used - Good.

This structure allows the same catalog item to support multiple sellable variants while preserving clean catalog metadata.

---

## Key Principles

### 1. Catalog metadata and sellable SKUs are separate

A catalog item describes what something is.
A product variant describes what the store actually sells.

### 2. Product variants are the sellable unit

Future POS, inventory, receiving, and purchasing workflows should operate at the product variant/SKU level.

### 3. Store context matters

ShelfStack supports multiple stores. Store context affects time zones, workstations, tax rates, permissions, and later inventory behavior.

### 4. Setup records are auditable

Changes to users, roles, departments, categories, taxes, catalog records, products, and variants should create audit events.

### 5. Data entry should be practical

ShelfStack should support structured data where useful, but not force excessive complexity on frontline users. For example, creator and subject metadata can be entered as semicolon-separated text and parsed into JSONB.

### 6. Defaults should be useful but overrideable

Categories, vendors, product conditions, and catalog metadata can provide defaults. Product and variant records should allow overrides when store practice requires it.

---

## Current Roadmap Summary

| Phase         | Focus                                                                                                                                 |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Phase 1       | Foundation: users, roles, stores, workstations, sessions, permissions, and audit events.                                              |
| Phase 2       | Classification and tax setup: departments, categories, tax categories, store tax rates, and effective-dated tax mappings.             |
| Phase 3       | Catalog, products, and product variants: metadata, identifiers, products, SKUs, variants, display locations, conditions, and vendors. |
| Future Phases | Inventory ledger, purchasing, receiving, POS, reporting, and operational workflows.                                                   |

---

## What ShelfStack Is Not

ShelfStack is not intended to be only a bibliographic database.

It is also not intended to be only a generic retail POS.

Its purpose is to combine bookstore-specific catalog and inventory needs with practical retail operations.
