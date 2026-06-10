# ShelfStack

ShelfStack is a bookstore-focused catalog, inventory, stock, and point-of-sale management application.

It is designed for independent bookstores and similar retailers that sell a mix of metadata-heavy products, such as books, periodicals, recorded music, videos, calendars, and audiobooks, alongside simpler retail items such as sidelines, gifts, food and beverage items, services, donations, and gift cards.

ShelfStack separates descriptive catalog metadata from store-facing products and sellable SKUs. This allows the application to support detailed bibliographic records where needed while still remaining practical for day-to-day retail operations.

---

## Project Status

ShelfStack is currently in early planning and foundation development.

The project is being built in phases:

| Phase         | Focus                                                                                                                                         |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Phase 1       | Foundation: users, roles, permissions, stores, workstations, sessions, and audit events.                                                      |
| Phase 2       | Classification and taxes: departments, categories, tax categories, store tax rates, and effective-dated tax mappings.                         |
| Phase 3       | Catalog, products, and product variants: catalog metadata, identifiers, products, SKUs, variants, conditions, display locations, and vendors. |
| Future phases | Inventory ledger, stock balances, purchasing, receiving, POS, reporting, and accounting workflows.                                            |

---

## Core Concepts

ShelfStack is organized around a layered model:

```text
Catalog Item → Product → Product Variant/SKU → Inventory/POS Activity
```

### Catalog Item

A catalog item is a metadata record.

Examples include:

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
* Sideline item
* Other catalog record

Catalog items describe what something is. They may include identifiers, title, creators, publisher, format, publication date, subjects, genres, themes, audiences, dimensions, and other metadata.

### Product

A product is the store-facing product grouping.

Products may be linked to catalog items, but they do not have to be. Non-catalog products may include cafe items, event tickets, gift cards, donations, store merchandise, or services.

### Product Variant

A product variant is the actual sellable SKU.

Future POS, inventory, purchasing, receiving, and reporting workflows should operate at the product variant level.

Examples:

* New copy
* Signed copy
* Used - Like New
* Used - Good
* Blue / Large T-shirt
* 16 oz latte

---

## Major Domains

| Domain         | Purpose                                                                            |
| -------------- | ---------------------------------------------------------------------------------- |
| Foundation     | Users, roles, permissions, stores, workstations, sessions, and audit events.       |
| Classification | Departments, categories, tax categories, store tax rates, and tax mappings.        |
| Catalog        | Metadata records for books, media, sidelines, and other cataloged items.           |
| Products       | Store-facing product records and sellable product variants/SKUs.                   |
| Inventory      | Future stock ledger, stock balances, receiving, transfers, and adjustments.        |
| Purchasing     | Future vendors, purchase orders, receiving, returns to vendor, and supplier terms. |
| POS            | Future sales, returns, tendering, taxes, receipts, and drawer behavior.            |
| Reporting      | Future sales, tax, inventory valuation, purchasing, and operational reports.       |

---

## Design Principles

### Catalog metadata and sellable SKUs are separate

A catalog item describes what something is.
A product variant describes what the store actually sells.

### Product variants are the sellable unit

Product variants are the records that future POS, ordering, receiving, and inventory workflows will use.

### Store context matters

ShelfStack supports multi-store behavior. Store context affects time zones, workstations, store-scoped permissions, tax rates, and future inventory behavior.

### Setup changes are auditable

Security, setup, catalog, product, tax, and SKU-related changes should create audit events.

### Data entry should be practical

ShelfStack should support structured data where useful without making everyday store workflows slow or overly technical.

For example, creators and subjects can be entered as semicolon-separated text and parsed into JSONB detail fields.

### Defaults should be useful but overrideable

Categories, vendors, product conditions, catalog metadata, and other setup records may provide defaults. Product and variant records should allow overrides where store practice requires it.

---

## Documentation

Primary documentation lives in `docs/`.

Recommended structure:

```text
docs/
  overview.md
  product-vision.md
  domain-model.md
  architecture.md
  roadmap.md
  implementation-guide.md
  glossary.md
  schema-reference.md

  roadmap/
    phase-1-foundation.md
    phase-2-departments-categories-taxes.md
    phase-3-catalog-products-variants.md

  specifications/
    phase-1-foundation-spec.md
    phase-1-data-model.md
    phase-1-test-plan.md
    phase-2-classification-and-tax-spec.md
    phase-2-data-model.md
    phase-2-test-plan.md
    phase-3-catalog-products-variants-spec.md
    phase-3-data-model.md
    phase-3-test-plan.md
```

### Important Documents

| Document                       | Purpose                                            |
| ------------------------------ | -------------------------------------------------- |
| `docs/overview.md`             | High-level explanation of ShelfStack.              |
| `docs/domain-model.md`         | Core business concepts and relationships.          |
| `docs/architecture.md`         | Technical architecture and service structure.      |
| `docs/roadmap.md`              | Phase-by-phase development roadmap.                |
| `docs/implementation-guide.md` | Developer conventions and implementation guidance. |
| `docs/glossary.md`             | Definitions of recurring domain terms.             |
| `docs/schema-reference.md`     | Schema, index, and constraint reference.           |

---

## Planned Technical Stack

ShelfStack is currently planned as a Rails application.

Expected stack:

| Layer                 | Tool                                                    |
| --------------------- | ------------------------------------------------------- |
| Application framework | Ruby on Rails                                           |
| Database              | PostgreSQL                                              |
| Authentication        | Rails-compatible password digest/authentication flow    |
| Authorization         | Role/permission service                                 |
| Background jobs       | To be determined                                        |
| Frontend              | Rails views/Hotwire or equivalent Rails-first approach  |
| Testing               | Rails test framework or RSpec, depending project choice |

This section should be updated once the implementation stack is finalized.

---

## Setup

This section should be updated once the application skeleton exists.

Expected local setup flow:

```bash
git clone <repository-url>
cd shelfstack
bundle install
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
bin/rails server
```

Then visit:

```text
http://localhost:3000
```

---

## Development Workflow

Recommended development flow:

1. Review the relevant phase roadmap.
2. Review the functional specification.
3. Review the data model.
4. Implement migrations and models.
5. Implement services.
6. Implement setup screens.
7. Add permissions and audit events.
8. Add or update seed data.
9. Add tests.
10. Update documentation.

A phase is not complete when tables exist. A phase is complete when the behavior is implemented, permission-controlled, audited, seeded, tested, and documented.

---

## Key Services

ShelfStack should centralize important business rules in services.

Expected service areas:

| Service                | Responsibility                                                           |
| ---------------------- | ------------------------------------------------------------------------ |
| Authorization          | Permission resolution and store-scope checks.                            |
| Audit Events           | Consistent audit event creation.                                         |
| Current Context        | User, store, workstation, session, and time zone context.                |
| Session Lifecycle      | Login, logout, lock, unlock, expiration, force-end.                      |
| Workstation Assignment | Browser-to-workstation token assignment and resolution.                  |
| Tax Lookup             | Effective-dated tax rate resolution.                                     |
| Catalog Identifiers    | Identifier normalization, validation, local generation, ISBN conversion. |
| Metadata Parsing       | Creator and subject parsing into JSONB.                                  |
| SKU Generation         | Product and variant SKU generation.                                      |
| Product Name Rendering | Product and variant name generation and override behavior.               |

---

## Seed Data

Seed data should be idempotent.

Running seeds multiple times should update known seed records instead of creating duplicates.

Important stable keys include:

| Entity            | Stable Key          |
| ----------------- | ------------------- |
| User              | `username`          |
| Role              | `role_key`          |
| Permission        | `permission_key`    |
| Store             | `store_number`      |
| Department        | `department_number` |
| Format            | `format_key`        |
| Product Condition | `condition_key`     |

---

## Testing

Each phase should include tests for:

* Models
* Validations
* Services
* Authorization
* Setup screens
* Audit events
* Seeds
* Security workflows
* Domain-specific behavior

Important test areas include:

* Authentication and session lifecycle
* Store-scoped permissions
* Super administrator protection
* Tax lookup
* Identifier normalization and validation
* ISBN-10 to ISBN-13 conversion
* Local identifier generation
* Product SKU generation
* Variant SKU generation
* Product and variant name rendering
* Seed idempotency

---

## Naming Conventions

### Booleans

Use Rails-style boolean names without `is_`.

Preferred:

```text
active
virtual
digital
large_print
new_condition
primary_identifier
```

Avoid:

```text
is_active
is_virtual
is_digital
is_large_print
is_new
```

### Stable Keys

Use `_key` for stable internal identifiers.

Examples:

```text
permission_key
role_key
format_key
condition_key
```

### Dates and Times

Use `_at` for datetimes:

```text
created_at
updated_at
last_login_at
locked_at
ended_at
```

Use `_on` for dates:

```text
effective_on
ends_on
```

### Controlled Type Fields

Avoid a plain `type` column unless intentionally using Rails single-table inheritance.

Use explicit fields:

```text
user_type
scope_type
catalog_item_type
product_type
variation_type
identifier_type
```

---

## Current Scope

The current design focus covers:

1. Phase 1 foundation
2. Phase 2 classification and taxes
3. Phase 3 catalog, products, and product variants

The next major area after Phase 3 is expected to be inventory foundation.

---

## License

To be determined.

---

## Maintainers

To be determined.
