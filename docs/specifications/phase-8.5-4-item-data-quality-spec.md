# Phase 8.5-4 — Item Data Quality and Operational Item Pages

Roadmap: [phase-8.5-4-item-data-quality.md](../roadmap/phase-8.5-4-item-data-quality.md)

Data model: [phase-8.5-4-data-model.md](phase-8.5-4-data-model.md)

Test plan: [phase-8.5-4-test-plan.md](phase-8.5-4-test-plan.md)

**Prerequisite:** Phase 8.5-3 merged.

---

## 1. Purpose

Make `/items` the operational landing page for staff and Phase 9 report drill-down. Presentation and batching only — no reordering of 8.5-3 data foundations.

---

## 2. Report drill-down contract

Item overview (`tab=overview`) exposes:

| Surface | Requirement |
| ------- | ----------- |
| Stable identity | Title, identifier, format/creator, resolved thumbnail above the fold |
| Warning summary | Grouped by severity with counts and corrective links |
| Sellability | Active, priced, subdepartment/tax signals per variant |
| Ordering readiness | `OrderEligibilityResolver` + vendor source status |
| Inventory | Store-scoped on hand, available, reserved, on order, TBO |
| Recent context | Compact sales and receiving panels (8.5-4c) |
| Source links | POS, PO, receipt links when permitted |

Link params: `catalog_item_id`, `product_id`, or `product_variant_id` + optional `tab=overview`.

Anchors: `#warnings`, `#variant-matrix`, `#sales-history`, `#receiving-history`.

Index rows may show batched worst warning severity only (not full text).

---

## 3. Services

### 3.1 `Items::ThumbnailResolver`

Resolves display attachment per data-model resolution order.

### 3.2 `Items::OperationalWarningBuilder`

Extended from 8.5-3 ordering subset.

**Warning shape:** `severity`, `category`, `code`, `message`, `variant_id`, `corrective_path`, `corrective_label`, `source`

**Categories:** `selling`, `ordering`, `inventory`, `data_quality`

**APIs:**

```ruby
OperationalWarningBuilder.call(product_variant:, contexts:, store:, vendor:)  # 8.5-3 compat
OperationalWarningBuilder.for_item(item:, store:, user:, contexts:, snapshot:)
OperationalWarningBuilder.for_variants(store:, variants:, contexts:, preloaded:)
OperationalWarningBuilder.for_items(store:, items:, user:, contexts:)
OperationalWarningBuilder.worst_severity(warnings)
OperationalWarningBuilder.counts_by_severity(warnings)
```

Ordering warnings delegate to `Purchasing::OrderEligibilityResolver` (`context: :item_page` on item pages).

### 3.3 `Items::VariantOperationalSnapshot`

Page-level batch of variant quantities, vendors, and last received for index and overview.

### 3.4 `Items::IndexWarningSummary`

Batched worst severity (+ counts) per index row presenter.

### 3.5 `Items::SalesHistoryLookup`

Batched POS line history for completed, non-voided transactions. Permission: `pos.transactions.view`.

Net line sales: `extended_price_cents - line_discount_cents - transaction_discount_cents`.

### 3.6 `Items::ReceivingHistoryLookup`

Batched posted receipt lines with `quantity_accepted > 0`.

### 3.7 `Items::ItemOverviewPresenter`

Overview-tab orchestrator composing warnings, summary cards, variant matrix, and compact history.

---

## 4. Tab roles

| Tab | Role |
| --- | ---- |
| Overview | Six operational questions, variant matrix, compact history |
| Operations | Document drill-down; no duplicate metric/attention strip from overview |
| Item setup | Edit + vendor sourcing anchors |
| Activity | Audit + trail (unchanged) |

---

## 5. Performance

- Index and overview batch variant lookups; no per-row resolver calls in views.
- History panels capped at 5–10 rows on overview; 20 on operations tab.

---

## 6. Out of scope

Full Items UX revamp, variant image overrides, Phase 9 analytics, re-implementing 8.5-3 schema/import.
