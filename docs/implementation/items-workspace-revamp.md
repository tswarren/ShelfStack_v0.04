# Items Workspace Revamp — Implementation Progress

This document tracks delivery of the Items workspace revamp across stacked PR phases.

## Phase 1 — Tab reorg

- Tab keys: `overview`, `operations`, `item_setup`, `activity` (UI label **Item setup**).
- Legacy `catalog`, `selling`, and `display` content composed in `_item_setup.html.erb`.
- `Items::ReturnPath` defaults updated to `item_setup`.
- Branch: `feature/items-workspace/phase-1-tabs`.

## Phase 2 — Operational overview

- `Purchasing::LastReceivedLookup` for posted receipt lines with accepted quantity.
- `Items::ItemOperationsPresenter` with rollup metrics, variant matrix rows, and header actions.
- Overview uses Orders metric strip and enriched SKU table.
- Branch: `feature/items-workspace/phase-2-overview`.

## Phase 3 — Operations tab

- `Items::ItemOperationsTabPresenter` for open TBO/PO lines, receipts, and RTVs.
- Operations tab with collapsible document sections and `variant_id` drilldown.
- Branch: `feature/items-workspace/phase-3-operations`.

## Phase 4 — Needs Attention + Activity

- `Items::ItemAttentionPresenter` on Overview and Operations.
- `Items::ItemDocumentTrailBuilder` for item-scoped purchasing document trail.
- Activity tab: document trail → inventory movements → collapsed audit timeline.
- Branch: `feature/items-workspace/phase-4-attention`.

## Phase 5 — Index operational signals

- `Items::IndexOperationalSummary` batches avail/TBO/on-order/last-received per search result.
- Items index **Stock / Orders** column and permission-gated quick actions.
- Branch: `feature/items-workspace/phase-5-index`.

## Related specs

- [UI/UX concept §8](../specifications/ui-ux-concept.md)
- [Phase 3 completion](phase-3-completion.md)
- [Phase 5 completion](phase-5-completion.md)
