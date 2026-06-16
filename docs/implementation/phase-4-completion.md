# Phase 4 Completion Record

## Status

**Phase 4 (Inventory Foundation) is complete** as of 2026-06-16 on branch `phase-4-inventory-foundation`.

Phase 4 delivered the inventory ledger, store-level balances, opening inventory and manual adjustments (including multi-line drafts), balance corrections, valuation snapshots, read surfaces, Items integration, setup for reason codes and locations, admin integrity tooling, permissions, audit events, and bookstore-oriented seeds.

Normative requirements remain in:

```text
docs/roadmap/phase-4-inventory-foundation.md
docs/specifications/phase-4-inventory-foundation-spec.md
docs/specifications/phase-4-data-model.md
docs/specifications/phase-4-test-plan.md
```

Test coverage matrix: [phase-4-test-coverage.md](phase-4-test-coverage.md).

---

## Delivered Capabilities

### Database

Migration: `db/migrate/20250618120000_create_phase4_inventory_foundation.rb`

| Table | Purpose |
| ----- | ------- |
| `inventory_reason_codes` | Global adjustment reason codes |
| `inventory_locations` | Store-scoped optional location context |
| `inventory_adjustments` | Draft/posted/cancelled adjustment headers |
| `inventory_adjustment_lines` | Per-variant quantity and cost lines |
| `inventory_postings` | Immutable posting records per source |
| `inventory_ledger_entries` | Quantity and value effects per posting line |
| `inventory_balances` | Cached store + variant balance projections |

Also restored `sub_departments.default_margin_target_bps` for margin-based cost estimation.

### Services

| Service | Responsibility |
| ------- | -------------- |
| `Inventory::Eligibility` | `standard_physical` variant gate |
| `Inventory::CostEstimator` | Manual cost, margin estimate, unknown fallback |
| `Inventory::Post` | Atomic posting, ledger entries, balance updates |
| `Inventory::PostAdjustment` | Draft adjustment post workflow |
| `Inventory::BalanceUpdater` | Balance mutation with negative/cleared-negative audit |
| `Inventory::Availability` | On-hand, available, product rollup helpers |
| `Inventory::Valuation` | Store and enterprise value totals |
| `Inventory::VariantLookup` | SKU/barcode/name lookup for adjustment entry |
| `Inventory::BalancesQuery` | Paginated store balance index query |
| `Inventory::RebuildBalances` | Recompute all balances from ledger |
| `Inventory::BalanceIntegrityCheck` | Compare cached balances to ledger sums |
| `Inventory::AdminTaskAuthorization` | Rake task permission gate |

### Inventory workspace (`/inventory`)

- Store balances index with search, pagination, cost column, and totals
- Variant ledger history
- Negative on-hand exceptions
- Enterprise rollup (permission-gated)
- Adjustments: draft create/edit (multi-line), post, cancel, posted detail with posting summary and audit timeline
- Variant lookup (scan/search) for adjustment lines
- Admin tools: rebuild balances, integrity check, balance correction shortcut

### Setup workspace

- Inventory reason codes CRUD with audit timeline
- Store inventory locations CRUD with audit timeline
- Setup home cards for both resources

### Items integration (read-only)

- Item overview: eligibility-aware per-variant availability and product total on hand
- Variant show: on-hand for current store and link to inventory ledger (permission-gated)

### Permissions

Seeded via `db/seeds/phase4_permissions.rb`:

- `inventory.access`, `inventory.balances.view`, `inventory.adjustments.*`, `inventory.ledger.view`
- `inventory.negative_exceptions.view`, `inventory.enterprise.view`, `inventory.admin.rebuild_balances`
- `setup.inventory_reason_codes.*`, `setup.inventory_locations.*`

### Seeds

`db/seeds/phase4_inventory.rb` (idempotent):

- Six inventory reason codes
- Subdepartment margin defaults (CSV column + pricing-model fallback)
- Sample inventory locations per store (Sales Floor, Back Room)

`sub_departments.csv` includes optional `default_margin_target_bps` column (see [seed-data-spec.md](../specifications/seed-data-spec.md)).

### Rake tasks

```bash
USERNAME=<user> ./dev/rails-docker bin/rails shelfstack:inventory:rebuild_balances
./dev/rails-docker bin/rails shelfstack:inventory:check_integrity
```

`rebuild_balances` requires `USERNAME` with global `inventory.admin.rebuild_balances`. `check_integrity` uses system user when `USERNAME` is omitted.

---

## Verification

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails db:seed
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails shelfstack:inventory:check_integrity
```

Expected: full Minitest suite passes (363 tests).

### Manual QA checklist

- [ ] Post opening inventory for a physical variant; confirm balance and ledger
- [ ] Create multi-line manual adjustment; post; confirm multiple balances update
- [ ] Drive balance negative and back to zero; confirm `inventory_balance.negative` and `inventory_balance.cleared_negative` audit events
- [ ] View adjustment posted detail: posting block, ledger links, audit timeline
- [ ] Items overview and variant show display stock with permission checks
- [ ] Setup: create reason code and store location; confirm audit events
- [ ] Admin tools: run integrity check and rebuild balances
- [ ] Balance correction adjustment (admin only) posts with `correction` movement type

---

## Deferred (unchanged)

- Purchasing, receiving, POS sales/returns, transfers, holds
- Location-level balance invariants
- Reservations and committed quantity beyond `quantity_available = quantity_on_hand`
- Average cost / COGS, copy-level inventory
- Reversal posting UI

---

## Documentation

- [phase-4-inventory-foundation-spec.md](../specifications/phase-4-inventory-foundation-spec.md)
- [phase-4-data-model.md](../specifications/phase-4-data-model.md)
- [phase-4-test-plan.md](../specifications/phase-4-test-plan.md)
- [phase-4-test-coverage.md](phase-4-test-coverage.md)
