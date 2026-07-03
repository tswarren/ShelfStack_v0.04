# ShelfStack Overview

## What is ShelfStack?

ShelfStack is a bookstore-focused inventory, catalog, stock, and point-of-sale management application.

It is designed for independent bookstores and similar retailers that sell metadata-heavy products (books, periodicals, recorded music, videos, calendars, audiobooks) alongside simpler retail merchandise (sidelines, gifts, food and beverage, services, donations, gift cards).

**ShelfStack v0.04** is the canonical domain model: descriptive metadata on **`Product`**, operational behavior on **`ProductVariant`**, customer need on **`DemandLine`**, supply claims on **`DemandAllocation`**, and authoritative stock changes only through **`Inventory::Post`**.

See [VERSION_0.04.md](design/VERSION_0.04.md) and [v0.04 delivery roadmap](roadmap/v0.04-delivery-roadmap.md).

---

## Core Purpose

ShelfStack helps stores answer four operational questions:

1. **What is this item?**  
   Product metadata, identifiers (ISBN/UPC), formats, creators, publishers, subjects.

2. **How does the store sell it?**  
   Product variants (SKUs), prices, conditions, classification, display locations, inventory tracking.

3. **Where is it and what is its stock status?**  
   Inventory ledger, `inventory_balances`, receiving, adjustments, demand allocations.

4. **How is it handled at POS and in reporting?**  
   Register sessions, transactions, tax/discount snapshots, demand pickup, operational reports at `/reports`.

---

## Intended Users

* Independent and used/new bookstores
* Stores with sidelines, gifts, or café/service items
* Multi-store booksellers needing store-scoped tax, workstations, and inventory

---

## Major Product Areas

| Domain | Purpose |
| ------ | ------- |
| Foundation | Users, roles, permissions, stores, workstations, sessions, audit events. |
| Classification | Departments, subdepartments, tax categories, store tax rates, category schemes. |
| Products & identifiers | v0.04 products, product identifiers, variants, conditions, vendors. |
| Demand & allocation | Demand lines, allocations, queues at `/demand`, POS pickup fulfillment. |
| Sourcing & purchasing | Sourcing runs, vendor responses, POs, receiving, RTV. |
| Inventory | Ledger, balances, adjustments; only `Inventory::Post` mutates on-hand. |
| POS | Register sessions, transactions, tax/discount/tender, voids, demand pickup. |
| Stored value & buyback | Gift cards, store/trade credit, staged buyback workflow. |
| Reporting | Operational reports at `/reports` (Phase 9a/9b). GL export deferred (Phase 9c). |

---

## Design Philosophy (v0.04)

```text
Product (+ product_identifiers)
  → Product Variant  (operational grain)
  → DemandLine → DemandAllocation → Sourcing → PO / Receipt
  → Inventory::Post
  → POS fulfillment / reporting
```

### Key principles

1. **ProductVariant is the sellable and stock grain** — POS, inventory, PO, receipt, and demand all reference variants.

2. **Demand does not post inventory** — allocations claim supply; receiving and POS post through `Inventory::Post`.

3. **Store context matters** — tax, permissions, workstations, and balances are store-scoped.

4. **Setup is auditable** — security, catalog, product, variant, and tax changes create audit events.

5. **Practical data entry** — structured metadata where useful; semicolon-separated creator/subject parsing where appropriate.

6. **Legacy compatibility is explicit** — v0.03 ordering tables were retired in v0.04-10; redirect aliases and deprecated params are documented, not hidden.

### Retained temporary

`catalog_items` remains as a **legacy bibliographic admin** surface (external lookup, import, buyback). It is not the canonical v0.04 model. New work uses `Product` + `product_identifiers`.

---

## Current Roadmap Summary

| Track | Focus |
| ----- | ----- |
| **v0.04 core** | Product fusion, identifiers, demand, allocations, sourcing, PO/receiving, retire v0.03 ordering — **v0.04-0 through v0.04-10 complete**. |
| **v0.04-11** | Documentation and schema cleanup — **in progress**. |
| **Phase 10** | Comprehensive UX expansion (10-E consistency sweep after v0.04-11). |
| **Phase 9c** | GL-shaped financial layer — **deferred**. |

Historical Phase 1–10 specs under `docs/specifications/` are **v0.03 implementation reference** unless marked otherwise.

---

## Related Documents

```text
docs/design/VERSION_0.04.md
docs/domain-model.md
docs/roadmap/v0.04-delivery-roadmap.md
docs/v0.04/README.md
AGENTS.md
```
