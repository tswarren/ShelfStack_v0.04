# Phase 8.5-4 — Item Data Quality and Operational Item Pages

**Status:** Complete

**Branch:** `phase-8.5-4-item-data-quality`

## Deliverables

### 8.5-4a — Presentation foundation

- `CatalogItem#primary_thumbnail` (Active Storage) with validation
- `Items::ThumbnailResolver` and helper integration
- Extended `Items::OperationalWarningBuilder` with batch APIs and full categories
- Retired `Items::ItemAttentionPresenter`
- `Items::VariantOperationalSnapshot` for batched variant operational data
- `Items::IndexWarningSummary` and refactored `Items::IndexOperationalSummary`
- Index Signals column with worst warning severity
- `Purchasing::SourcingLookup.for_variants` for batched vendor source resolution

### 8.5-4b — Overview reorganization

- `Items::ItemOverviewPresenter` orchestrating summary cards and variant readiness matrix
- Redesigned overview tab with `#warnings`, `#variant-matrix`, summary cards
- Slimmed operations tab (removed duplicate attention/metric strip; variant-grouped warnings + full sales history)
- Catalog thumbnail upload on catalog item form
- Item setup vendor sourcing callout (preferred vendor vs vendor source)

### 8.5-4c — History and contract completion

- `Items::SalesHistoryLookup` and `Items::ReceivingHistoryLookup`
- Compact sales/receiving panels on overview; 30-day sales rollup on activity card
- `Purchasing::OrderEligibilityResolver.for_variants` with `:item_page` context
- `ItemOperationsPresenter` refactored to reuse `VariantOperationalSnapshot`
- Phase 9 handoff: [docs/handoff/phase-9-item-drill-down-contract.md](../handoff/phase-9-item-drill-down-contract.md)

## Verification

```bash
./dev/rails-docker bin/rails test \
  test/integration/items_item_overview_contract_test.rb \
  test/integration/items_items_controller_test.rb \
  test/models/catalog_item_primary_thumbnail_test.rb \
  test/presenters/items/item_operations_presenter_test.rb \
  test/presenters/items/item_overview_presenter_test.rb \
  test/services/items/ \
  test/services/purchasing/order_eligibility_resolver_test.rb \
  test/services/purchasing/sourcing_lookup_test.rb
```

## Known gaps (deferred)

- Item cockpit completion (setup modals, operations drawer): [Phase 10-B](../roadmap/phase-10b-item-cockpit-completion.md)
- Add Item wizard redesign (future phase)
- Variant-level image overrides
- Item command language (future phase)
