# ShelfStack

ShelfStack is a bookstore-focused catalog, inventory, stock, and point-of-sale management application.

It is designed for independent bookstores and similar retailers that sell a mix of metadata-heavy products, such as books, periodicals, recorded music, videos, calendars, and audiobooks, alongside simpler retail items such as sidelines, gifts, food and beverage items, services, donations, and gift cards.

ShelfStack separates descriptive catalog metadata from store-facing products and sellable SKUs. This allows the application to support detailed bibliographic records where needed while still remaining practical for day-to-day retail operations.

---

## Project Status

ShelfStack has **complete Phase 1–4 implementations** and complete Phase 1–4 **documentation**. Active development priority is **Phase 5** (purchasing and receiving, per roadmap).

| Phase         | Focus                                                                                                                                         | Documentation | Implementation |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | -------------- |
| Phase 1       | Foundation: users, roles, permissions, stores, workstations, sessions, and audit events.                                                      | Complete      | **Complete**   |
| Phase 2       | Classification and taxes: departments, tax categories, store tax rates, and effective-dated tax mappings.                                     | Complete      | **Complete**   |
| Phase 3       | Catalog, products, and product variants: catalog metadata, identifiers, products, SKUs, variants, conditions, display locations, and vendors. | Complete      | **Complete**   |
| Phase 4       | Inventory foundation: ledger, balances, adjustments, valuation, read surfaces, and integrity tooling.                                          | Complete      | **Complete**   |
| Future phases | Purchasing, receiving, POS, reporting, and accounting workflows.                                                                                | Roadmap only  | Not started    |

Completion records: [Phase 1](docs/implementation/phase-1-completion.md) · [Phase 2](docs/implementation/phase-2-completion.md) · [Phase 3](docs/implementation/phase-3-completion.md) · [Phase 4](docs/implementation/phase-4-completion.md).

---

## Core Concepts

ShelfStack is organized around a layered model:

```text
Catalog Item → Product → Product Variant/SKU → Inventory/POS Activity
```

* **Catalog item** — descriptive metadata record (book, calendar, media item, sideline, and so on).
* **Product** — store-facing product grouping; may or may not link to a catalog item.
* **Product variant** — the actual sellable SKU (new copy, used condition, size/color, and so on).

Future POS, inventory, purchasing, receiving, and reporting workflows operate at the product variant level.

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

**Phases 1–4 are implemented.** See completion records under [docs/implementation/](docs/implementation/).

Current design and implementation focus:

1. **Phase 5** — purchasing and receiving (next, per roadmap)

Operational catalog work uses **Items** (`/items`); admin reference data uses **Setup** (`/setup`); store inventory uses **Inventory** (`/inventory`).

---

## License

To be determined.

---

## Maintainers

To be determined.
