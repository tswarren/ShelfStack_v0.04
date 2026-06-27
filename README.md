# ShelfStack

ShelfStack is a bookstore-focused catalog, inventory, stock, and point-of-sale management application.

It is designed for independent bookstores and similar retailers that sell a mix of metadata-heavy products, such as books, periodicals, recorded music, videos, calendars, and audiobooks, alongside simpler retail items such as sidelines, gifts, food and beverage items, services, donations, and gift cards.

ShelfStack separates descriptive catalog metadata from store-facing products and sellable SKUs. This allows the application to support detailed bibliographic records where needed while still remaining practical for day-to-day retail operations.

---

## Project Status

ShelfStack is developed in phases. **Phases 1–8**, **6.5**, **7A–7C**, **8.5 (mostly)**, **9a/9b**, and **Phase 10-A/10-B** are **complete**.

| Phase | Focus | Status |
| ----- | ----- | ------ |
| 1–6 | Foundation through POS | **Complete** |
| 6.5 | External catalog lookup (ISBNdb) | **Complete** |
| 7A | Customer demand | **Complete** |
| 7B | Customer credit (settlement, stored value) | **Complete** |
| 7C | Used buyback | **Complete** |
| 8 | Inventory eligibility and tracking | **Complete** |
| 8.5 | POS discounts, tax exceptions, order readiness, item data quality | **Complete** (8.5-4); 8.5-1/2/3 completion records — some branches may still be in review |
| 9a / 9b | Report UX foundation and operational reports | **Complete** |
| 9c | GL-shaped financial layer | **Deferred** |
| 10-A / 10-B | Interaction infrastructure; item cockpit | **Complete** |
| 10-C | POS keyboard workspace | **Current priority** |
| 10-D / 10-E | Workflow polish; consistency sweep | Planned |

```text
Implemented: Phases 1–8, 6.5, 7A–7C, 8.5 slices (see completion records), 9a/9b, 10-A, 10-B
Current:     Phase 10-C — POS Keyboard Workspace
Deferred:    Phase 9c GL-shaped financial layer
```

See [docs/roadmap.md](docs/roadmap.md), [AGENTS.md](AGENTS.md), and [docs/implementation/](docs/implementation/) for completion records.

Recent: [Phase 10-B](docs/implementation/phase-10b-completion.md) · [Phase 9b](docs/implementation/phase-9b-completion.md) · [Phase 10-C spec](docs/specifications/phase-10c-pos-keyboard-workspace-spec.md)

---

## Core Concepts

ShelfStack is organized around a layered model:

```text
Catalog Item → Product → Product Variant/SKU → Inventory/POS Activity
```

* **Catalog item** — descriptive metadata record (book, calendar, media item, sideline, and so on).
* **Product** — store-facing product grouping; may or may not link to a catalog item.
* **Product variant** — the actual sellable SKU (new copy, used condition, size/color, and so on).

Inventory, purchasing, receiving, POS, buyback, stored value, and operational reporting workflows operate at the **product variant** level (with structured POS discounts, tax exceptions, and inventory tracking gates in later phases).

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
| [docs/schema-reference.md](docs/schema-reference.md) | Schema index and phase data model guide.   |
| [docs/architecture-map.md](docs/architecture-map.md) | Domain → tables → services → workspace map. |
| [docs/security.md](docs/security.md) | Auth, permissions, sessions, audit overview. |
| [docs/testing.md](docs/testing.md) | Test strategy and phase test plan index.   |

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

**Implemented:** Phases 1–8, 6.5, 7A–7C, 8.5 (mostly), 9a/9b, 10-A, 10-B. See [docs/implementation/](docs/implementation/).

**Current priority:** Phase 10-C — POS keyboard workspace (idle workspace, command registry, two-lane parser). See [docs/roadmap/phase-10c-pos-keyboard-workspace.md](docs/roadmap/phase-10c-pos-keyboard-workspace.md).

**Deferred:** Phase 9c GL-shaped financial layer. Operational reports in 9b remain authoritative for store reconciliation.

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
| Reports | `/reports` | Operational reports (Phase 9b) |

---

## License

To be determined.

---

## Maintainers

To be determined.
