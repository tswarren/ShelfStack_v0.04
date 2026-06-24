# Phase 8-3 / 8-4 / 8-5 — Completion Record

Completed: 2026-06-23

## Summary

Phase 8-3 through 8-5 complete the inventory tracking refactor: product defaults and variant overrides (8-3), staff-facing Inventory / Non-Inventory UI with SourceHint and POS tracking snapshots (8-4), and POS COGS with operational margin reporting (8-5).

## 8-3 — Product defaults and resolver chain

### Schema

- `products.default_inventory_tracking`
- `product_variants.inventory_tracking_override` (not backfilled)

### Services / tasks

- Extended `Inventory::TrackingResolver` resolution: override → behavior → product default → product_type
- `AddItem::InventoryTrackingMapper`
- `lib/tasks/shelfstack/inventory_tracking.rake` — backfill (DRY_RUN), mixed-product report, conflict report
- Add Item seeds `default_inventory_tracking` on product create

### Verification

```bash
bin/rails shelfstack:inventory_tracking:backfill DRY_RUN=true
bin/rails test test/services/inventory/tracking_resolver_test.rb test/services/add_item/inventory_tracking_mapper_test.rb
```

## 8-4 — UI, sync, SourceHint, tracking snapshot

### Services

- `Items::InventoryTrackingSync` — tracking selection + legacy behavior edit with preview
- `Inventory::SourceHint` — acquisition movements only; label "Last stock source"
- `Inventory::Eligibility.eligible_for_pos_line?` reads `inventory_tracking_snapshot` first

### UI

- Variant advanced form: Inventory / Non-Inventory for staff; legacy behavior in support section
- Variant show: tracking + last stock source hint
- Presenters/lookups expose `inventory_tracking`

### Schema

- `pos_transaction_lines.inventory_tracking_snapshot`

### Verification

```bash
bin/rails test test/services/items/inventory_tracking_sync_test.rb test/services/inventory/source_hint_test.rb test/integration/items_product_variants_controller_test.rb
```

## 8-5 — POS COGS and operational margin

### MAC decision

Extended `Inventory::BalanceUpdater` so positive inbound `buyback_offer` and `no_value_donation` update moving average (Option A).

### Schema

- `pos_transaction_lines`: `unit_cogs_cents`, `total_cogs_cents`, `cogs_source`, `costing_method_snapshot`, `revenue_treatment`, `cogs_estimated`

### Services

- `Pos::LineCogsCalculator` — pre-sale COGS at completion; signed `total_cogs_cents` on returns
- `Pos::OperationalMarginReport` — actual vs estimated margin; voided transactions excluded
- Wired into `Pos::CompleteTransaction` after tracking snapshot, before inventory post

### UI

- POS Reports → Operational margin

### Verification

```bash
bin/rails test test/services/pos/line_cogs_calculator_test.rb test/services/pos/complete_transaction_cogs_test.rb test/services/pos/operational_margin_report_test.rb test/services/inventory/balance_updater_test.rb test/integration/pos_reports_controller_test.rb
```

## Deferred / out of scope

- Removing `inventory_behavior` column
- Non-inventory receipt / PO policy
- Non-inventory COGS (MVP: null)
- Full GL export (Phase 9)

## Related documents

- [phase-8-data-model.md](../specifications/phase-8-data-model.md)
- [phase-8-inventory-eligibility-and-tracking-spec.md](../specifications/phase-8-inventory-eligibility-and-tracking-spec.md)
- [phase-8-test-plan.md](../specifications/phase-8-test-plan.md)
- [phase-8-1-8-2-completion.md](phase-8-1-8-2-completion.md)
