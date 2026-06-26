# Phase 8.5-4 Test Plan

Spec: [phase-8.5-4-item-data-quality-spec.md](phase-8.5-4-item-data-quality-spec.md)

---

## 1. Thumbnail

- `CatalogItem` attachment validation (type, size)
- `Items::ThumbnailResolver` — product override, catalog fallback, placeholder
- Helper renders resolved attachment on index and overview

## 2. Operational warnings

- Builder categories and severities for selling, ordering, inventory, data_quality
- Batch `for_variants` / `for_items` parity with single-variant rules
- `worst_severity` and `counts_by_severity`
- Item-level open TBO and identifier warnings
- Retired `ItemAttentionPresenter` cases covered

## 3. Index batching

- `Items::VariantOperationalSnapshot` aggregates across variants
- `Items::IndexOperationalSummary` does not instantiate N × `ItemOperationsPresenter`
- `Items::IndexWarningSummary` worst severity per row

## 4. Overview

- `Items::ItemOverviewPresenter` summary cards and variant matrix fields
- Integration smoke: contract regions present on overview (`#warnings`, `#variant-matrix`, etc.)

## 5. History

- `Items::SalesHistoryLookup` store scope, limit, last_sold_at, rollups
- `Items::ReceivingHistoryLookup` batch rows and receipt links
- Permission gate for sales history

## 6. Performance

- Query-count tests for items index and show (overview) with multi-variant fixtures

## 7. Operations tab

- Overview tab does not duplicate full attention/metric strip on operations when navigated from overview contract
