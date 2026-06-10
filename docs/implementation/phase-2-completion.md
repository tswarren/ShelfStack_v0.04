# Phase 2 Completion Record

## Status

**Phase 2 (Departments, Categories, and Taxes) is complete** as of 2025-06-10.

Phase 2 delivered the classification and tax setup layer: global tax categories, store tax rates, effective-dated tax mappings, departments, categories with pricing/tax defaults, tax lookup service, setup UI, permissions, audit events, and bookstore-oriented seeds.

Normative requirements remain in:

```text
docs/roadmap/phase-2-departments-categories-taxes.md
docs/specifications/phase-2-classification-and-tax-spec.md
docs/specifications/phase-2-data-model.md
docs/specifications/phase-2-test-plan.md
```

---

## Delivered Capabilities

### Database

Migration: `db/migrate/20250611120000_create_phase2_classification_and_tax.rb`

| Table | Purpose |
| ----- | ------- |
| `tax_categories` | Global product taxability classifications |
| `store_tax_rates` | Store-specific tax rates (basis points) |
| `store_tax_category_rates` | Effective-dated store + tax category → rate mappings |
| `departments` | Global sales/reporting departments |
| `categories` | Product categories with default pricing/tax behavior |

### Services

| Service | Responsibility |
| ------- | -------------- |
| `TaxRateLookup` | Resolve exactly one applicable store tax rate for store, tax category, and date |
| `Authorization.accessible_stores` | List stores a user may manage for a store-scoped permission |

### Models

| Model | Notable behavior |
| ----- | ---------------- |
| `TaxCategory` | Globally unique name and short name |
| `StoreTaxRate` | Per-store uniqueness for name, short name, tax identifier; BPS 0–10000 |
| `StoreTaxCategoryRate` | Same-store FK rule; date range validation; active overlap prevention |
| `Department` | Three-digit zero-padded department numbers |
| `Category` | Department-scoped uniqueness; controlled pricing models; inactive department/tax category guards |

### Setup UI

Setup landing cards and CRUD for:

- Tax Categories
- Store Tax Rates (store-scoped authorization)
- Tax Mappings (store tax category rates)
- Departments (department number preview)
- Categories

Each resource supports create, edit, show, inactivate, reactivate, guarded delete, and audit timeline on detail pages.

### Permissions

30 Phase 2 permissions seeded via `db/seeds/phase2_permissions.rb` and granted to super administrator on seed.

### Seeds

`db/seeds/phase2_classification_tax.rb` (idempotent):

- 6 tax categories
- Non-Taxable + Taxable store rates per seeded store (600 bps store 001, 950 bps store 002)
- Effective-dated tax mappings from 2026-01-01
- 6 departments and bookstore-oriented categories

---

## Verification

```bash
docker compose up -d
./dev/rails-docker bin/rails db:migrate db:seed
./dev/rails-docker bin/rails test
```

Expected: **76 tests**, 0 failures.

Tax lookup smoke test (Rails console):

```ruby
store = Store.find_by!(store_number: "001")
books = TaxCategory.find_by!(name: "Books")
TaxRateLookup.call(store: store, tax_category: books, date: Date.new(2026, 6, 15))
```

---

## Test Coverage Summary

| Area | Tests |
| ---- | ----- |
| Model validations | `tax_category`, `store_tax_rate`, `store_tax_category_rate`, `department`, `category` |
| Tax lookup | `tax_rate_lookup_test` |
| Authorization | `authorization_accessible_stores_test`, `setup_phase2_authorization_test` |
| Setup controllers | `setup_tax_categories`, `setup_departments`, `setup_store_tax_rates` |
| Seeds | Idempotency and tax lookup for all seeded store/tax category pairs |

Integration/request tests only; browser system tests remain deferred (matches Phase 1 CI).

---

## Known Gaps vs Full Test Plan

The Phase 2 test plan describes additional scenarios (categories controller, tax mapping controller, overlap UI preview, full permission matrix) not yet covered by automated tests. Core exit criteria are implemented and tested.

---

## Deferred (Out of Phase 2 Scope)

- POS tax calculation at point of sale
- PostgreSQL exclusion constraints for mapping overlap
- Browser system tests in CI
- Store-specific category overrides

---

## Next Priority

**Phase 3:** Catalog, Products, and Product Variants per [roadmap/phase-3-catalog-products-variants.md](roadmap/phase-3-catalog-products-variants.md).
