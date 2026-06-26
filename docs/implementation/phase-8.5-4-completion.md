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

### 8.5-4b — Overview reorganization

- `Items::ItemOverviewPresenter` orchestrating summary cards and variant readiness matrix
- Redesigned overview tab with `#warnings`, `#variant-matrix`, summary cards
- Slimmed operations tab (removed duplicate attention/metric strip; grouped warnings + full sales history)
- Catalog thumbnail upload on catalog item form

### 8.5-4c — History and contract completion

- `Items::SalesHistoryLookup` and `Items::ReceivingHistoryLookup`
- Compact sales/receiving panels on overview
- `Purchasing::OrderEligibilityResolver.for_variants` with `:item_page` context
- Phase 9 handoff: [docs/handoff/phase-9-item-drill-down-contract.md](../handoff/phase-9-item-drill-down-contract.md)

## Verification

docs/implementation/phase-8.5-4-completion.md

## Known gaps

- Query-count performance budget tests deferred if CI environment lacks local bundle
- Item setup vendor source callout is via warnings + existing `#vendor-sourcing` anchor (no duplicate vendor table on overview)
