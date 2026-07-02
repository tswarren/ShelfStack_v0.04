# ShelfStack

ShelfStack is a bookstore-focused catalog, inventory, ordering, receiving, customer demand, and point-of-sale management application.

It is designed for independent bookstores and similar retailers that sell a mix of metadata-heavy products — books, periodicals, recorded music, video, games, calendars, and audiobooks — alongside simpler retail items such as sidelines, gifts, café items, services, donations, and gift cards.

---

## Project Status

**ShelfStack v0.04 is the active core domain model for the application going forward.**

The v0.03 implementation (Phases 1–10) delivered a working Rails codebase: foundation, inventory, POS, purchasing, buybacks, stored value, operational reports, and Phase 10-A/B/C/D interaction infrastructure (item cockpit, modals, drawers, POS workspace, workflow polish). That code remains the implementation base, but it uses older vocabulary around `catalog_items`, customer requests, special orders, purchase requests, and TBO lines.

v0.04 is not “Phase 11.” It is the new canonical architecture for:

```text
Product identity
→ Product identifiers
→ Product variants
→ Demand
→ Allocations
→ Sourcing
→ Purchase orders / receiving
→ Inventory posting
→ Fulfillment / POS
```

Implementation happens through ordered v0.04 milestones inside the existing Rails app. This is not a greenfield rewrite.

**Current priority:**

```text
Complete: v0.04-0 through v0.04-8
Current:  v0.04-9 — PO and receiving quantity model
```

See [docs/v0.04/README.md](docs/v0.04/README.md) and [docs/roadmap/v0.04-delivery-roadmap.md](docs/roadmap/v0.04-delivery-roadmap.md).

**v0.03 status:** Phases 1–10 are mostly complete (including Phase 10-C POS keyboard workspace and 10-D workflow polish). **Phase 10-E** (app-wide consistency sweep) is **paused** until the v0.04 core stabilizes. Phase **9c** (GL-shaped financial layer) remains deferred.

Because ShelfStack is not yet in production, v0.04 may use destructive schema changes where appropriate instead of long-lived compatibility shims.

### Built on v0.03 (carry forward)

| Keep | Replace under v0.04 |
| ---- | ------------------- |
| Product variant as operational grain | `catalog_items` vs `products` separation |
| `Inventory::Post`, ledger, balances | `customer_requests`, `special_orders`, `purchase_requests` / TBO |
| POS, voids, tax/discount/tender, stored value | Fragmented reservation + PO/receipt allocation model |
| Buybacks, classification/tax, foundation auth | `catalog_item_identifiers` → `product_identifiers` |
| Phase 10-A/B/C/D interaction infrastructure, item cockpit, modals, drawers, POS workspace, and workflow polish patterns | Supplier availability assumed at order time |
| Phase 6.5 external catalog lookup (ISBNdb) for Add Item | — |

Identity migration in brief:

```text
catalog_items + catalog_item_identifiers  →  products + product_identifiers
```

See [docs/roadmap/v0.04-delivery-roadmap.md](docs/roadmap/v0.04-delivery-roadmap.md) for the full legacy replacement map, invariants, and acceptance scenarios.

---

## v0.04 Core Model

ShelfStack v0.04 uses this domain model:

```text
Optional product_group
  → Product
    → Product Variant
      → Demand
        → Allocation
          → Sourcing
            → Purchase Order / Receiving
              → Inventory::Post
                → Fulfillment
```

### Product

A **product** represents one specific commercial item, edition, release, or manufactured item.

Examples:

* A specific hardcover book ISBN
* A specific paperback book ISBN
* A specific CD or vinyl UPC release
* A specific DVD/Blu-ray/video game release
* A specific gift or sideline item
* A defined café item or service

In v0.04, product metadata and commercial identity move onto `products`. The older `catalog_items` separation is being retired.

### Product Group

Optional grouping uses the **`product_groups`** table. **Work** is a `group_type` value (and display label for books), not the universal table name.

```text
product_groups.group_type: work | series_cluster | release_family | merchandise_family
```

Examples:

* Book editions sharing a title → `group_type: work`
* Related media formats → `release_family`
* Related sideline colorways → `merchandise_family`

Product groups are useful for search, navigation, related-edition display, and staff context. They are **never** the grain for POS, inventory, purchasing, receiving, or fulfillment.

### Product Variant

A **product variant** is the operational sellable, stockable, reservable, or orderable form of a product.

Examples:

```text
Product:
  North Woods hardcover, ISBN 978...

Variants:
  New hardcover
  Used hardcover
  Signed hardcover
  Damaged hardcover
  Remainder hardcover
```

Product variants remain the operational grain for:

* POS lines
* Inventory ledger entries
* Stock balances
* Purchase order lines
* Receipt lines
* Customer demand
* Reservations and allocations
* Buybacks
* Pricing, tax, and classification behavior
* Vendor orderability

---

## Identifiers and SKUs

v0.04 separates commercial identifiers from operational variant SKUs.

```text
Product identifier  → What commercial item is this?
Variant SKU         → Which sellable/stockable/reservable form is this?
Vendor item number  → How does this vendor refer to it?
```

### Product Identifiers

Product identifiers belong to products and use validation families:

```text
gtin      ISBN-13, EAN-13, UPC-A, GTIN-14
isbn      ISBN-10
freeform  Publisher numbers, BIPAD, other catalog references
house     Store-assigned EAN-13 barcodes (product identity, not variant SKU)
```

Key rules:

* ISBN-13 / EAN / UPC values are treated as GTIN-family identifiers.
* ISBN-10 remains separate because it uses Mod-11 validation.
* ISBN-10 entry automatically creates a primary ISBN-13 / GTIN alternate where possible.
* ISBN-13 beginning with `978` automatically creates a non-primary ISBN-10 alternate.
* ISBN-13 beginning with `979` does not create an ISBN-10 alternate.
* **House EAN-13** (prefix `200–229`, sequential allocation, EAN-13 check digit) is a **product identifier** for store-created items without manufacturer barcodes — not the variant SKU.
* Optional `products.sku` may cache the primary identifier for display/search; it does not generate variant SKUs.

### Variant SKUs

Variant SKUs belong to product variants and identify the exact sellable form. They are **system-assigned at variant creation** and do **not** derive from product identifiers, `products.sku`, or condition/attribute suffixes.

**Open decision (v0.04-2):** sequential internal codes (e.g. `1000042`) or system-generated EAN-13 from a dedicated prefix segment — see [docs/design/VERSION_0.04.md](docs/design/VERSION_0.04.md) §3. If v0.04-2 chooses system-generated EAN-13 variant SKUs, they must use a prefix segment **reserved for variant SKUs** and **distinct from product `house` identifier segments** (prefix 200–229).

Examples (illustrative until v0.04-2 chooses format):

```text
New hardcover:     1000042
Used hardcover:    1000043
Signed hardcover:  1000044
```

POS, receiving, inventory adjustment, and lookup workflows resolve scans in this order:

```text
1. Exact product_variants.sku match
2. Product primary identifier / products.sku
3. Any active product_identifiers row
4. If one active variant matches, select it
5. If multiple active variants match, prompt for disambiguation
6. Fall back to text search
```

Scanning an ISBN identifies the **product**; when multiple variants exist, staff disambiguate or scan the variant’s system-assigned label.

---

## Demand, Allocation, and Ordering

v0.04 replaces fragmented request concepts with a unified demand-to-fulfillment pipeline.

Legacy concepts being replaced include:

```text
customer_requests
special_orders
purchase_requests / TBO
inventory_reservations
purchase_order_line_allocations
receipt_line_allocations
```

The new model distinguishes:

| Concept | Purpose |
| ------- | ------- |
| Stock consideration | A non-committing buyer note or customer/staff interest |
| Demand line | A real customer or store need for a product variant |
| Allocation | A claim against on-hand stock or inbound supply |
| Sourcing attempt | A vendor attempt to satisfy unresolved demand |
| Vendor response | Confirmation, backorder, cancellation, unavailable quantity, or substitution |
| Purchase order | Vendor-facing supply document |
| Receiving | Physical arrival and acceptance/rejection record |
| Inventory posting | The only path that changes stock quantity |

### Bookseller workflow mapping

| Bookseller action | v0.04 concept |
| ----------------- | ------------- |
| Reserve a copy already on hand | `demand_line` + `on_hand` allocation |
| Reserve the next copy already on order | `demand_line` + `inbound_purchase_order` allocation |
| Ask buyer to order a copy | Unresolved demand → sourcing |
| Wait for a used copy | `used_wanted` demand; no vendor PO |
| Buyer note to consider stocking | `stock_consideration` — not committed demand |
| Manual TBO / store replenishment | Store-sourced `demand_line` |

There is no separate `special_orders` header in v0.04. Staff-facing UI may still label certain demand types as “special order.”

### Sourcing and vendor behavior

* Vendor availability is **not** assumed at order time; confirmed quantity comes from **vendor response**.
* Partial confirm / backorder / cancel splits quantity across allocations.
* Cascade to the next vendor is **buyer-reviewed** in v0.04 (not automatic by default).

Important rules:

* Demand does not mutate inventory.
* Allocations do not mutate inventory.
* Only **accepted receipt quantity** posts to inventory.
* Inventory changes only through controlled source-document posting via `Inventory::Post`.

Lifecycle status names and transition rules: [delivery roadmap — Lifecycle vocabulary](docs/roadmap/v0.04-delivery-roadmap.md#lifecycle-vocabulary-state-machines).

---

## Used Product Rules

Used variants are central to bookstore workflows.

In v0.04, used product variants are:

```text
customer-reservable
sellable if available
not vendor-orderable
not part of normal purchase order sourcing
```

If a customer wants a used copy that is available, demand can allocate to on-hand used stock.

If a customer wants a used copy that is not available, ShelfStack creates used-wanted demand or a notification-style request. It does **not** automatically create a vendor purchase order for a new copy unless staff intentionally create separate new-item demand.

---

## Documentation

Primary documentation lives in [`docs/`](docs/). Start with [`docs/README.md`](docs/README.md) for reading paths.

| Document | Purpose |
| -------- | ------- |
| [`docs/design/VERSION_0.04.md`](docs/design/VERSION_0.04.md) | Authoritative v0.04 core domain model |
| [`docs/roadmap/v0.04-delivery-roadmap.md`](docs/roadmap/v0.04-delivery-roadmap.md) | Milestones, invariants, legacy map, acceptance scenarios |
| [`docs/v0.04/README.md`](docs/v0.04/README.md) | v0.04 milestone spec index |
| [`docs/README.md`](docs/README.md) | Documentation hub and suggested reading order |
| [`docs/roadmap.md`](docs/roadmap.md) | Overall roadmap and v0.03 phase history |
| [`docs/implementation-guide.md`](docs/implementation-guide.md) | Developer conventions, services, seeds, testing |
| [`docs/architecture.md`](docs/architecture.md) | Technical architecture and service structure |
| [`docs/architecture-map.md`](docs/architecture-map.md) | Domain → tables → services → workspace map |
| [`docs/domain-model.md`](docs/domain-model.md) | Domain model *(v0.03 language until v0.04-11)* |
| [`docs/overview.md`](docs/overview.md) | High-level overview *(v0.03 language until v0.04-11)* |
| [`docs/schema-reference.md`](docs/schema-reference.md) | Schema reference; updated as milestones land |
| [`docs/glossary.md`](docs/glossary.md) | Domain terms *(partially v0.03 until migrated)* |
| [`docs/security.md`](docs/security.md) | Auth, permissions, sessions, audit |
| [`docs/testing.md`](docs/testing.md) | Test strategy and phase test plan index |
| [`AGENTS.md`](AGENTS.md) | Required context for AI coding agents |

Historical v0.03 phase specs remain useful for code not yet migrated. New work follows v0.04 vocabulary and design direction.

---

## v0.04 Delivery Milestones

| Milestone | Focus | Status |
| --------- | ----- | ------ |
| v0.04-0 | Baseline and cutover prep | **Complete** |
| v0.04-1 | Product model fusion | **Complete** |
| v0.04-2 | Product identifiers | **Complete** |
| v0.04-3 | Product groups | **Deferred** |
| v0.04-4 | Variant-grain wire-through | **Complete** |
| v0.04-5 | Used variant rules | **Complete** |
| v0.04-6 | Demand foundation | **Complete** |
| v0.04-7 | Allocations and reservations | **Complete** |
| v0.04-8 | Sourcing and vendor responses | **Complete** |
| v0.04-9 | PO and receiving quantity model | **Next** |
| v0.04-10 | Retire v0.03 ordering UI and reports | Planned |
| v0.04-11 | Documentation and schema cleanup | Planned |

Suggested first implementation slice:

```text
Create product with ISBN
  → auto ISBN alternates
  → create new variant (system-assigned SKU)
  → scan ISBN at POS (single variant) or variant label
  → receive on PO
  → sell / void
```

This proves the v0.04 item core before the full demand pipeline is rebuilt.

---

## Technical Stack

| Layer | Tool |
| ----- | ---- |
| Application framework | Ruby on Rails 8.1 |
| Language | Ruby 3.4 |
| Database | PostgreSQL 17 |
| Authentication | `has_secure_password` / bcrypt |
| Authorization | Role and permission service |
| Background jobs | Solid Queue |
| Cache | Solid Cache |
| Action Cable | Solid Cable |
| Frontend | Rails views, Hotwire, Turbo, Stimulus, Propshaft |
| Testing | Minitest, Capybara |
| Development | Docker Compose |

---

## Setup

Development runs in Docker. See [`DOCKER.md`](DOCKER.md) for full instructions, including migration from v0.03 Docker stacks.

```bash
git clone <repository-url>
cd ShelfStack_v0.04
docker compose up --build
```

In another terminal, prepare the database:

```bash
./dev/rails-docker bin/rails db:create db:migrate
./dev/rails-docker bin/rails shelfstack:seeds:validate
./dev/rails-docker bin/rails db:seed
```

Optional seed controls: `SKIP_BISAC_SEED=1`, `SEED_BISAC=1`. See [`docs/implementation/csv-seeds.md`](docs/implementation/csv-seeds.md).

Then visit:

```text
http://localhost:3000
```

On first seed, the terminal prints the development admin credentials. First login flow:

```text
Assign workstation if needed
→ log in
→ change password if forced
→ set PIN
→ dashboard
```

See [`docs/operations/foundation-runbook.md`](docs/operations/foundation-runbook.md) for more detail.

### Development Commands

Use `./dev/rails-docker` to run Rails, Bundler, tests, and other commands inside the `web` container.

```bash
./dev/rails-docker bin/rails console
./dev/rails-docker bin/rubocop
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails routes
```

---

## Development Workflow

For each milestone or implementation slice:

1. Review the relevant v0.04 roadmap and design context.
2. Confirm whether the area is still v0.03 code awaiting migration.
3. Implement migrations and models.
4. Implement services; keep controllers thin.
5. Add permissions and audit events for new mutations.
6. Add or update seed data.
7. Add model, service, integration, and system tests as appropriate.
8. Update documentation and milestone completion notes.

A milestone is not complete when tables exist. A milestone is complete when the behavior is implemented, permission-controlled, audited, seeded, tested, documented, and integrated into the relevant staff workflows.

See [`docs/implementation-guide.md`](docs/implementation-guide.md) for naming conventions, seed rules, and service patterns.

---

## Current Workspaces

Some workspace behavior still reflects the v0.03 implementation until the relevant v0.04 milestones migrate it.

| Workspace | Path | Purpose |
| --------- | ---- | ------- |
| Items | `/items` | Products, variants, identifiers, item setup, Add Item (ISBNdb) |
| Setup | `/setup` | Admin reference data, users, permissions, tax, discount reasons |
| Inventory | `/inventory` | Balances, adjustments, inventory locations, stock views |
| Orders | `/orders` | Purchasing, receiving, vendor returns |
| POS | `/pos` | Register, transactions, settlement, tenders, receipts |
| Buybacks | `/buybacks` | Used buyback sessions and used variant intake |
| Customers | `/customers` | Customer records, demand, fulfillment, stored value |
| Reports | `/reports` | Operational reports and reconciliation views |

---

## Cross-Cutting Rules

These rules apply across v0.04 work:

* Product variants remain the operational grain.
* Product groups are never operational.
* Demand does not post inventory.
* Allocations do not post inventory.
* Only `Inventory::Post` mutates authoritative on-hand quantity.
* Only accepted receipt quantity posts to inventory.
* Used variants are not vendor-orderable.
* Product identifiers belong to products.
* Variant SKUs are system-assigned and must not be derived from product identifiers.
* Vendor item numbers belong to vendor sourcing records.
* Controllers stay thin; business rules live in services.
* Permission checks and audit events are required for new mutations.
* Seeds must remain idempotent.
* Tests are required for identifier validation, demand transitions, allocation integrity, receiving, and POS lookup.

---

## Deferred Outside v0.04 Core

The following are not part of the core v0.04 redesign unless separately scoped:

* Phase 9c GL-shaped financial layer
* Full AP invoice reconciliation and freight allocation *(receipt-line cost snapshots for MAC and later invoice review remain in scope for v0.04-9)*
* Offline POS
* Copy-level serial tracking beyond variant SKUs
* Automatic vendor cascade without buyer review
* EDI / Pubnet availability integration
* Full production migration tooling
* Major UI redesign beyond what domain changes require
* Phase 10-E consistency sweep *(resumes after v0.04-11)*

---

## License

To be determined.

---

## Maintainers

To be determined.
