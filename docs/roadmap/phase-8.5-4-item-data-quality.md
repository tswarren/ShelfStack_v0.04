# Phase 8.5-4 — Item Data Quality and Operational Item Pages

**Status:** Accepted

**Prerequisite:** Phase 8.5-3 (Order Handling Readiness) merged and stable.

Related:

```text
docs/roadmap/phase-8.5-3-order-handling-readiness.md
docs/roadmap/phase-8.5-operational-cleanup.md
docs/specifications/phase-8.5-3-order-handling-readiness-spec.md
```

---

## Purpose

Make `/items` the **trusted operational landing page** before Phase 9 reporting begins linking users into item detail.

This is a **preliminary reorganization**, not the full Items UX revamp. 8.5-4 improves how operational state is presented, batched, and linked — it does not redesign navigation, the Add Item wizard, or setup flows.

The key distinction from 8.5-3:

> **8.5-3 makes order handling safer. 8.5-4 makes item pages explain the item’s operational state clearly.**

`/items` already has the correct tab structure (`overview`, `operations`, `item_setup`, `activity`), operational rollups, attention presenters, and index signals. The problem is **layering and duplication**: the same facts appear in PR in multiple tabs, warnings are ad hoc, and overview does not yet answer ordering/readiness questions that 8.5-3 already computes elsewhere.

---

## Phase goal

**Make item pages reliable, warning-driven, and operationally useful enough to serve as report drill-down targets.**

At the end of 8.5-4, a bookseller should be able to open an item and immediately answer:

| Question                          | Page responsibility                                                                  |
| --------------------------------- | ------------------------------------------------------------------------------------ |
| What is this?                     | Catalog/product identity, identifiers, format, creator/publisher metadata, thumbnail |
| Can we sell it?                   | Active status, sellable SKU, price, tax/subdepartment, POS eligibility               |
| Can we order it?                  | Preferred vendor, vendor source, orderable flag, cost, returnability                 |
| Do we have it?                    | On hand, available, reserved, on order, TBO                                          |
| When did we last receive/sell it? | Receiving history and sales history panels                                           |
| Are there warnings?               | Centralized warnings with severity, category, and action links                       |

---

# 0. Overlap with Phase 8.5-3 (do not redo)

Phase 8.5-3 delivers the **ordering data foundation**. 8.5-4 **consumes and surfaces** that work; it must not re-implement it.

| Deliverable | Owner | 8.5-4 action |
| ----------- | ----- | ------------ |
| `products.preferred_vendor_id`, `product_variants.preferred_vendor_id` | 8.5-3 | Use in UI; no new migration |
| `product_variants.orderable` | 8.5-3 | Display in variant matrix and readiness cards |
| `Purchasing::SuggestedVendorResolver` (extended precedence) | 8.5-3 | Use for suggested vendor display |
| `Purchasing::OrderEligibilityResolver` | 8.5-3 | Delegate ordering warnings and “Can order?” cards |
| `Items::OperationalWarningBuilder` (ordering subset) | 8.5-3 | **Extend** to replace `ItemAttentionPresenter` |
| Ingram preferred vendor / vendor source import options | 8.5-3 | No duplicate import work unless gaps found in QA |
| Preferred vendor + orderable fields on item setup forms | 8.5-3 | Link from overview warnings; no duplicate editors |
| `Purchasing::SourcingWarnings` (Orders workspace) | 8.5-3 | Keep separate; item warnings use `Items::OperationalWarningBuilder` |

**Net-new in 8.5-4 (data model):**

* `catalog_items.primary_thumbnail` (Active Storage)
* Read-only sales/receiving history lookups and aggregates (`last_sold_at`, etc.)

Everything else in 8.5-4 is **presentation, batching, information architecture, and the report drill-down contract**.

---

# 1. Report drill-down contract

Phase 9 reporting will link from aggregate views into item detail. 8.5-4 defines what reports can rely on **without** building reporting itself.

## 1.1 Contract

A Phase 9 report may link to `/items` (unified item show, typically `overview` tab) and expect:

| Surface | Contract |
| ------- | -------- |
| **Stable identity** | Item title, primary identifier, format/creator summary, and resolved thumbnail (catalog → product override → placeholder) visible above the fold |
| **Warning summary** | Top-of-page attention strip grouped by severity (`blocking`, `warning`, `info`) with at least a count; expandable list with category and corrective links |
| **Sellability status** | Per-variant and item-level signal: active, priced, subdepartment/tax resolved, POS-eligible where applicable |
| **Ordering readiness** | Per-variant signal from `OrderEligibilityResolver` + suggested/preferred vendor + vendor source present/missing — not merely “vendor name filled in” |
| **Inventory availability** | Store-scoped on hand, available, reserved, on order, open TBO — consistent with `ItemOperationsPresenter` rollups |
| **Recent sales/receiving context** | Compact panels: last N sales rows and last N receipt rows for the item’s variants, store-scoped where appropriate |
| **Source document links** | Where a row originates from POS, PO, receipt, TBO, or special-order activity, a link to the source record is present when the user has permission |

## 1.2 Link conventions

Reports should use stable query parameters already supported by the Items workspace:

```text
/items/item?catalog_item_id=:id&tab=overview
/items/item?product_id=:id&tab=overview
/items/item?product_variant_id=:id&tab=overview
```

Optional anchors for drill-down within a tab (introduce as needed during D2/D3):

```text
#warnings
#variant-matrix
#sales-history
#receiving-history
```

## 1.3 Out of scope for the contract

Reports must **not** assume in 8.5-4:

* Full sales analytics, margin reporting, or export (Phase 9)
* Variant-level image overrides
* Unified `/items` navigation redesign
* Write actions from report links (read-only landing; user edits via setup or Orders)

## 1.4 Index contract (lightweight)

Reports listing many items may link to `/items` index with filters. The index may expose **batched** operational signals per row (see §2): available qty, TBO, on order, and **worst warning severity** — not full warning text per row.

---

# 2. Performance guardrails

`/items` index and overview are query-heavy by nature. 8.5-4 must batch reads and avoid per-row resolver or warning N+1 queries.

## 2.1 Principles

| Rule | Requirement |
| ---- | ----------- |
| **Batch by page** | Index and overview load data for all visible variants in one or few queries per concern |
| **No per-row resolvers in views** | `SuggestedVendorResolver`, `OrderEligibilityResolver`, and warning checks run in batch services/presenters — not inside ERB loops |
| **Preload associations** | Catalog, product, variants, balances, vendor sources, and attachments loaded via `includes` / dedicated lookup objects |
| **Cap history depth** | Sales and receiving panels default to 5–10 rows; aggregates (30/90-day) computed in SQL or single grouped query |
| **Index severity only** | Index rows show worst severity + optional count; full warning lists only on item detail |

## 2.2 Required batch services

Extend or add lookup objects that accept **`variant_ids:`** (or **`item_ids:`** for index) and return hashes keyed by id:

```ruby
# Existing — keep batch-oriented
Purchasing::LastReceivedLookup.for_variants(store:, variant_ids:)

# New in 8.5-4
Items::SalesHistoryLookup.for_variants(store:, variant_ids:, limit: 20)
Items::SalesHistoryLookup.last_sold_at_for_variants(store:, variant_ids:)
Items::SalesHistoryLookup.rollup_for_variants(store:, variant_ids:, days: [30, 90])

# Extend from 8.5-3 — must support batch, not single-variant only
Items::OperationalWarningBuilder.for_items(store:, items:, contexts: [...])
# or .for_variants(store:, variants:, contexts: [...])

Purchasing::SuggestedVendorResolver.batch_for_variants(variants)
Purchasing::OrderEligibilityResolver.batch_for_variants(store:, variants:, context: :item_page)
```

Receiving history on overview should reuse batched receipt-line queries (same pattern as operations tab, scoped to overview limit).

## 2.3 Index operational summary

`Items::IndexOperationalSummary` already batches availability, TBO, and on-order signals. Extend it (or a sibling `Items::IndexWarningSummary`) to batch:

* worst warning severity per catalog item / product row
* optional warning count by severity

Implementation sketch:

```text
1. Load index page of items (paginated, e.g. 25–50 rows)
2. Collect all variant_ids for those items in one pass
3. Run batch lookups (inventory, TBO, warnings, last_sold) once each
4. Presenters merge precomputed hashes — no model calls in views
```

## 2.4 Acceptance: performance

* Item **overview** action: no N+1 on variants, balances, vendors, warnings, or history lookups (verify with `bullet` in development or explicit query-count tests for representative fixtures).
* Item **index** action: warning severity and operational columns batched; query count does not scale linearly with variants per row beyond bounded preload.
* Adding a column to the variant matrix must not introduce a new per-row query pattern without a batch lookup.

---

# 3. Information architecture (tab roles)

Clarify tab responsibilities to reduce clutter. 8.5-4 reorganizes content; it does not add new tabs.

| Tab | Role after 8.5-4 |
| --- | ---------------- |
| **Overview** | Answers the six operational questions; variant readiness matrix; compact sales/receiving history; warning summary |
| **Operations** | Document-level drill-down only — open TBO/PO lines, full receipt list, RTV, holds, special orders; defers duplicate metric strips to overview |
| **Item setup** | Edit/catalog and selling configuration; vendor source editors; link targets for warning corrective actions |
| **Activity** | Audit events + document trail; inventory ledger remains but may move to collapsible section (no removal in 8.5-4 unless UX review agrees) |

**De-duplication rules:**

* Do not load full `ItemOperationsTabPresenter` dataset on overview once overview has compact history lookups.
* Stop repeating the same attention items on overview and operations with different formatting — one builder, two render modes (summary vs grouped drill-down).
* Vendor story on overview: **Preferred vendor** | **Source?** (yes / no / warning) | link to setup anchor — not a second full vendor table.

---

# 4. Data model work (8.5-4 only)

## 4.1 Catalog thumbnail

Attach primary thumbnail to the catalog layer; products and variants inherit it.

The current model has `has_one_attached :cover_image` on `Product`. `CatalogItem` does not yet have an attachment. Since catalog items are the descriptive metadata layer, the default image should live there.

### Add to `CatalogItem`

```ruby
has_one_attached :primary_thumbnail
```

Validation (align with product cover image):

```ruby
ALLOWED_THUMBNAIL_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
MAX_THUMBNAIL_SIZE = 5.megabytes
```

### Resolution order (display)

1. Product `cover_image` (existing override)
2. Catalog item `primary_thumbnail`
3. Placeholder by catalog item type / format

Variant-level image overrides are **deferred** (see §12).

## 4.2 Vendor concepts (reference — implemented in 8.5-3)

The item page must distinguish:

| Concept                       | Meaning                                                  |
| ----------------------------- | -------------------------------------------------------- |
| Preferred/default vendor      | “Use this vendor first” (`preferred_vendor_id`)          |
| Vendor source                 | Purchasing/source row on `product_vendors` / `product_variant_vendors` |
| Suggested vendor              | Resolved vendor after precedence (`SuggestedVendorResolver`) |
| Missing vendor source warning | Preferred/suggested vendor exists, but no usable source row |

Resolution precedence is defined in 8.5-3; 8.5-4 displays it consistently on overview and variant matrix.

---

# 5. Operational warning builder (extend 8.5-3)

Replace scattered `ItemAttentionPresenter` logic with an extended **`Items::OperationalWarningBuilder`**.

```ruby
Items::OperationalWarningBuilder.call(
  item:,
  store:,
  contexts: [:selling, :ordering, :inventory, :data_quality]
)
```

Batch entry point for index and variant matrix:

```ruby
Items::OperationalWarningBuilder.for_variants(
  store:,
  variants:,
  contexts: [...]
)
# => { variant_id => [Warning, ...] }
```

Delegate ordering rules to `Purchasing::OrderEligibilityResolver`. Do not duplicate `Purchasing::SourcingWarnings` — that service remains Orders-scoped.

## 5.1 Categories

| Category       | Examples                                                                                         |
| -------------- | ------------------------------------------------------------------------------------------------ |
| `selling`      | Missing price, inactive variant, missing tax/subdepartment                                       |
| `ordering`     | Missing preferred vendor, missing vendor source, non-orderable, missing cost, used variant PO    |
| `inventory`    | Non-inventory variant with stock, tracking mismatch                                              |
| `data_quality` | Missing identifier, invalid identifier, missing catalog image, missing required classification   |

## 5.2 Severities

| Severity   | Meaning                                 |
| ---------- | --------------------------------------- |
| `blocking` | User cannot complete normal workflow    |
| `warning`  | Workflow allowed, but item needs review |
| `info`     | Not urgent, but useful context          |

## 5.3 Warning object shape (for UI and index)

Each warning should expose at minimum:

```ruby
category:, severity:, code:, message:, variant_id: (optional),
corrective_path: (route + anchor), source: (symbol)
```

Index rows use **worst severity** and optional counts derived from the same builder in batch mode.

## 5.4 Specific warning logic

| Warning                          | Severity                              | Notes                                                                                |
| -------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------ |
| Missing vendor source            | Warning                               | Preferred/suggested vendor exists but no active matching vendor source row           |
| Missing preferred/default vendor | Warning/info                          | No resolved vendor from resolver                                                     |
| Non-orderable variant            | Warning on item page                  | `orderable == false`; blocking context is PO submit (8.5-3)                        |
| Non-inventory variant            | Info/warning                          | `Inventory::TrackingResolver.resolve(variant) == "non_inventory"`                  |
| Missing price                    | Blocking/warning                      | Per existing business rules                                                          |
| Missing cost                     | Warning                               | No source cost, no PO cost default, no moving average cost                          |
| Missing tax/subdepartment        | Blocking/warning                      | Variant lacks valid subdepartment or resolved tax category                           |
| Inventory tracking mismatch      | Warning                               | Product default, variant override, and behavior imply conflicting intent             |
| Preferred vendor inactive        | Blocking/warning                      | `preferred_vendor_id` points to inactive vendor                                      |
| Open TBO                         | Info                                  | Carried forward from current attention presenter                                     |
| Identifier issues                | Warning/info                          | Missing/invalid primary identifier                                                   |

---

# 6. Reorganized item overview (8.5-42)

The overview becomes a **question-based operational dashboard**, not a second operations tab.

## 6.1 Proposed layout

```text
[Thumbnail]  Title / Author / Format / Identifier / Status Badges

Warnings / Needs Attention
- Blocking | Warnings | Info  (counts + expandable list)

Operational Summary Cards
[Can sell?] [Can order?] [Stock] [Recent activity]

Variant Readiness Matrix
- Variant, SKU, Price, Tax/Subdepartment
- Inventory tracking, Orderable
- Preferred vendor, Vendor source status, Suggested vendor
- On hand / Available / On order
- Last received, Last sold
- Worst warning severity (icon) — detail on expand or link to #warnings

Compact Panels
1. Sales history (latest 5–10)
2. Receiving history (latest 5–10)
3. Open activity summary (counts + link to operations tab) — not full document lists
```

## 6.2 Summary cards

| Card | Data source |
| ---- | ----------- |
| Can sell? | Active variants, price, subdepartment/tax, POS eligibility, selling warnings |
| Can order? | `OrderEligibilityResolver` (batch), preferred/suggested vendor, vendor source, orderable |
| Stock | `ItemOperationsPresenter` rollups (existing) |
| Recent activity | Last sold + last received dates (batch lookups) |

## 6.3 Variant matrix columns (priority order)

Implement incrementally; each column must use batch lookups (§2):

1. Orderable + inventory tracking (Phase 8 + 8.5-3 fields)
2. Suggested vendor + vendor source present/missing
3. Last received (existing) + last sold (new)
4. Expected cost / returnability (from sourcing lookup, batched)
5. Worst warning severity per variant

Reuse Orders UI patterns where applicable: `metric_strip`, `attention_panel`, readiness badges consistent with TBO/PO screens.

---

# 7. Sales history panel (8.5-43)

Read-only, lightweight. Deeper reporting belongs in Phase 9.

## 7.1 Panel contents

| Column           | Notes                                                                |
| ---------------- | -------------------------------------------------------------------- |
| Date/time        | Transaction completed/posted time                                    |
| Store/register   | When multi-store/register context exists                             |
| Variant/SKU      | Required for multi-variant products                                  |
| Quantity         | Positive sale; negative return/refund where applicable                 |
| Net sales        | Align with existing POS conventions                                  |
| Transaction link | Link to POS transaction detail when permitted                        |

## 7.2 Service

```ruby
Items::SalesHistoryLookup.for_variants(store:, variant_ids:, limit: 20)
Items::SalesHistoryLookup.last_sold_at_for_variants(store:, variant_ids:)
```

Aggregates (batch only):

```ruby
units_sold_last_30_days
units_sold_last_90_days
net_sales_last_30_days_cents
net_sales_last_90_days_cents
```

---

# 8. Receiving history panel (8.5-43)

Move a **compact** version of operations-tab receipt data onto overview. Operations tab keeps full document depth.

## 8.1 Panel contents

| Column       | Notes                                        |
| ------------ | -------------------------------------------- |
| Receipt date | Posted date preferred; created date fallback   |
| Vendor       | From receipt                                 |
| Variant/SKU  | Variant received                             |
| Qty accepted | Quantity posted to inventory                 |
| Unit cost    | Receipt line unit cost                       |
| PO link      | If receipt came from PO                      |
| Receipt link | Link to receipt detail                       |

Limit: latest **5–10 rows** on overview; batched query shared with operations presenter pattern.

`Purchasing::LastReceivedLookup` remains the source for **last received** aggregates on the variant matrix.

---

# 9. Item setup (minimal changes)

8.5-3 already adds preferred vendor, orderable, and vendor source editing. 8.5-4 setup work is limited to:

* Catalog **primary thumbnail** upload on catalog item section of item setup
* Obvious **vendor source vs preferred vendor** labeling and “missing source” callout when they diverge
* Anchor targets (`#vendor-sourcing`, etc.) for warning corrective links from overview

Do not duplicate large setup forms on the overview tab.

---

# 10. Operations tab (slim, not second homepage)

Operations tab is the **deep drill-down** behind overview.

**Keep:**

* Open TBO lines, open PO lines, recent receipts, RTV lines
* Customer requests / holds / special orders (permission-gated)

**Change in 8.5-4:**

* Remove duplicate metric strip and attention formatting when overview shows the same data
* Add warning **grouped by variant** (from shared builder, drill-down render mode)
* Add full sales history section (overview keeps compact slice)
* Clearer links to source records (align with report drill-down contract)

**Do not add** new operational panels to overview that merely duplicate operations tab lists at full length.

---

# 11. Acceptance criteria

## Prerequisites

* Phase 8.5-3 merged; preferred vendor, orderable, resolvers, and ordering warning foundation available.

## Data model (8.5-4 only)

* Catalog items support `primary_thumbnail`.
* Products continue supporting image override via existing `cover_image`.
* Thumbnail resolution order documented and tested.

## Report drill-down contract

* Item overview exposes stable identity, warning summary, sellability, ordering readiness, inventory availability, compact sales/receiving context, and source links per §1.
* Link conventions documented for Phase 9 consumers.

## Performance

* Batch lookups for last_sold, sales history, warning severity, and index operational columns per §2.
* No per-row resolver or warning N+1 on index or overview (query-count or bullet verification).

## Warnings

* `ItemAttentionPresenter` replaced by extended `Items::OperationalWarningBuilder`.
* Warnings categorized and severitized; ordering rules delegate to `OrderEligibilityResolver`.
* Index shows worst severity (and optional counts) via batch builder.
* Corrective links route to setup anchors or appropriate workspace.

## Overview

* Answers: What is this? Can we sell? Can we order? Do we have it? Last receive/sell? Warnings?
* Variant matrix includes orderable, inventory tracking, vendor source status, last received, last sold.
* Overview does not duplicate full operations document lists.

## History panels

* Compact sales and receiving panels on overview; full sales list on operations tab.
* Store-scoped where appropriate; links to source documents when permitted.

## Tests

* Catalog thumbnail inheritance.
* `Items::SalesHistoryLookup` batch behavior and limits.
* Warning builder batch API and severity aggregation for index.
* Overview/index presenter query behavior (no N+1 regressions).
* Report contract smoke: fixture item renders all contract surfaces on overview.

---

# 12. Explicitly deferred

Do not implement in 8.5-4 unless explicitly rescoped:

* Full `/items` UX revamp (navigation, Add Item wizard, unified create flow)
* Variant-level image overrides
* Deep sales reporting, exports, or dashboards (Phase 9)
* Write actions triggered from report links
* Collapsing legacy routes (`/items/catalog_items/*`, etc.) — reduce prominence only
* Inventory ledger relocation from activity tab (optional polish; not required for contract)
* Re-implementing 8.5-3 migrations, Ingram import options, or PO economics

---

# 13. Suggested phase split

## 8.5-41 — Presentation foundation

* Catalog item `primary_thumbnail` migration + setup UI
* Extend `Items::OperationalWarningBuilder` (full categories); retire `ItemAttentionPresenter`
* Batch APIs for warnings, suggested vendor, order eligibility on item pages
* Index worst-severity column via batched warning summary
* Thumbnail resolution helper for overview hero

**Depends on 8.5-3.** No preferred vendor / orderable / Ingram work unless 8.5-3 gaps are found in QA.

## 8.5-42 — Overview reorganization

* Question-based overview layout and summary cards
* Variant readiness matrix (columns per §6.3)
* Tab de-duplication (overview vs operations vs setup links)
* Report drill-down anchors and contract documentation for Phase 9
* Reuse Orders UI components (`metric_strip`, `attention_panel`, badges)

## 8.5-43 — History and contract completion

* `Items::SalesHistoryLookup` + compact sales panel on overview
* Compact receiving history panel on overview (batched)
* `last_sold` on variant matrix; full sales history on operations tab
* Performance tests / query budgets for index and overview
* Phase 9 handoff note: link conventions and contract surfaces

This split keeps PRs reviewable and avoids combining data, IA, and history into one large change.

---

# 14. Sequencing

```text
1. Merge Phase 8.5-3
2. 8.5-41 — thumbnails, unified warnings, batch lookups, index severity
3. 8.5-42 — overview IA, variant matrix, tab de-duplication, drill-down contract
4. 8.5-43 — sales/receiving history panels, last_sold, performance verification
5. Phase 9 reporting — consume drill-down contract; build analytics elsewhere
6. Future — full Items UX revamp builds on stable overview contract
```
