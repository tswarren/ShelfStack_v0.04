# ShelfStack

ShelfStack is a bookstore-focused catalog, inventory, stock, and point-of-sale management application.

It is designed for independent bookstores and similar retailers that sell a mix of metadata-heavy products, such as books, periodicals, recorded music, videos, calendars, and audiobooks, alongside simpler retail items such as sidelines, gifts, food and beverage items, services, donations, and gift cards.

ShelfStack separates descriptive catalog metadata from store-facing products and sellable SKUs. This allows the application to support detailed bibliographic records where needed while still remaining practical for day-to-day retail operations.

---

## Project Status

ShelfStack is developed in phases. **Phases 1–8**, **6.5**, and **7A–7C** are **complete**. **Phase 8.5-1** (structured POS discounts) is **in review** on branch `phase-8.5-operational-cleanup` (target completion after merge).

| Phase | Focus | Status |
| ----- | ----- | ------ |
| 1 | Foundation: users, roles, permissions, stores, workstations, sessions, audit | **Complete** |
| 2 | Classification and taxes | **Complete** |
| 3 | Catalog, products, and variants | **Complete** |
| 4 | Inventory foundation | **Complete** |
| 5 | Purchasing and receiving | **Complete** |
| 6 | POS foundation | **Complete** |
| 6.5 | External catalog lookup (ISBNdb) | **Complete** |
| 7A | Customer demand (requests, holds, special orders) | **Complete** |
| 7B | Customer credit (settlement, stored value, POS integration) | **Complete** |
| 7C | Used buyback | **Complete** |
| 8 | Inventory eligibility and tracking refactor | **Complete** |
| 8.5-1 | POS discount model and calculation | **In review** |
| 8.5+ | Operational cleanup (tax exceptions, tender/customer) | Roadmap |
| 9 | Reporting and accounting | Roadmap |

See [docs/roadmap.md](docs/roadmap.md) for the full phase sequence and [docs/implementation/](docs/implementation/) for completion records.

Recent completion records: [Phase 6](docs/implementation/phase-6-completion.md) · [Phase 7A](docs/implementation/phase-7a-completion.md) · [Phase 7C](docs/implementation/phase-7c-completion.md) · [Phase 8](docs/implementation/phase-8-3-4-5-completion.md) · [Phase 8.5-1](docs/implementation/phase-8.5-1-completion.md) (in review).

---

## Core Concepts

ShelfStack is organized around a layered model:

```text
Catalog Item → Product → Product Variant/SKU → Inventory/POS Activity
```

* **Catalog item** — descriptive metadata record (book, calendar, media item, sideline, and so on).
* **Product** — store-facing product grouping; may or may not link to a catalog item.
* **Product variant** — the actual sellable SKU (new copy, used condition, size/color, and so on).

Future POS, inventory, purchasing, receiving, buyback, and reporting workflows operate at the product variant level (with structured POS discounts under Phase 8.5-1).

See [docs/overview.md](docs/overview.md) and [docs/domain-model.md](docs/domain-model.md) for more detail.

---

## Documentation

Primary documentation lives in [docs/](docs/). Start with [docs/README.md](docs/README.md) for reading paths and a full document index.

| Document                       | Purpose                                            |
| ------------------------------ | -------------------------------------------------- |
| [docs/README.md](docs/README.md) | Documentation index and suggested reading order. |
| [docs/overview.md](docs/overview.md) | High-level explanation of ShelfStack.          |
| [docs/domain-model.md](docs/domain-model.md) | Core business concepts and relationships.  |
| [docs/architecture.md](docs/architecture.md) | Technical architecture and service structure. |
| [docs/roadmap.md](docs/roadmap.md) | Phase-by-phase development roadmap.            |
| [docs/implementation-guide.md](docs/implementation-guide.md) | Developer conventions and implementation guidance. |
| [docs/glossary.md](docs/glossary.md) | Definitions of recurring domain terms.         |
| [docs/schema-reference.md](docs/schema-reference.md) | Schema, index, and constraint reference.   |

AI coding agents should also read [AGENTS.md](AGENTS.md).

---

## Technical Stack

| Layer                 | Tool                                              |
| --------------------- | ------------------------------------------------- |
| Application framework | Ruby on Rails 8.1                               |
| Language              | Ruby 3.4                                          |
| Database              | PostgreSQL 17                                     |
| Authentication        | `has_secure_password` (bcrypt)                    |
| Authorization         | Role/permission service (`Authorization`)         |
| Background jobs       | Solid Queue                                       |
| Cache                 | Solid Cache                                       |
| Action Cable          | Solid Cable                                       |
| Frontend              | Rails views, Hotwire (Turbo + Stimulus), Propshaft |
| Testing               | Minitest (Rails default), Capybara for system tests |
| Development           | Docker Compose                                    |

---

## Setup

Development runs in Docker. See [DOCKER.md](DOCKER.md) for full instructions.

Quick start:

```bash
git clone <repository-url>
cd ShelfStack_v0.03
docker compose up --build
```

In another terminal, prepare the database:

```bash
./dev/rails-docker bin/rails db:create db:migrate
./dev/rails-docker bin/rails shelfstack:seeds:validate
./dev/rails-docker bin/rails db:seed
```

Optional: skip BISAC during seed (`SKIP_BISAC_SEED=1`) or include it in test (`SEED_BISAC=1`). See [docs/implementation/csv-seeds.md](docs/implementation/csv-seeds.md).

Then visit:

```text
http://localhost:3000
```

On first seed, the terminal prints the development **admin** password (`admin` / `ChangeMe###`). First login flow: assign workstation (if needed) → log in → **change password** (when `force_password_change`) → **set PIN** (required) → dashboard. See [DOCKER.md](DOCKER.md) and [docs/operations/foundation-runbook.md](docs/operations/foundation-runbook.md).

Use `./dev/rails-docker` to run Rails, Bundler, and other commands inside the `web` container. Examples:

```bash
./dev/rails-docker bin/rails console
./dev/rails-docker bin/rubocop
./dev/rails-docker bin/rails test
```

---

## Development Workflow

1. Review the relevant phase roadmap, functional specification, data model, and test plan in [docs/](docs/).
2. Implement migrations and models.
3. Implement services.
4. Implement setup screens.
5. Add permissions and audit events.
6. Add or update seed data.
7. Add tests.
8. Update documentation.

A phase is not complete when tables exist. A phase is complete when the behavior is implemented, permission-controlled, audited, seeded, tested, and documented.

See [docs/implementation-guide.md](docs/implementation-guide.md) for naming conventions, seed rules, testing expectations, and service patterns.

---

## Current Scope

**Implemented:** Phases 1–8, 6.5, and 7A–7C. See [docs/implementation/](docs/implementation/) for completion records and verification steps.

**In review:** Phase 8.5-1 structured POS discounts (reasons, applications, allocations, eligibility, stacking). See [phase-8.5-1-completion.md](docs/implementation/phase-8.5-1-completion.md).

**Next (roadmap):** Phase 8.5 operational cleanup (tax exceptions, tender/customer), then Phase 9 reporting and accounting. See [docs/roadmap.md](docs/roadmap.md).

### Workspaces

| Workspace | Path | Purpose |
| --------- | ---- | ------- |
| Items | `/items` | Catalog, products, variants, add-item flows |
| Setup | `/setup` | Admin reference data, users, tax, discount reasons |
| Inventory | `/inventory` | Balances, adjustments, locations |
| Orders | `/orders` | Purchasing, receiving, vendor returns |
| POS | `/pos` | Register, transactions, settlement, receipts |
| Buybacks | `/buybacks` | Used buyback sessions |
| Customers | `/customers` | Demand, stored value, customer records |

---

## License

To be determined.

---

## Maintainers

To be determined.
