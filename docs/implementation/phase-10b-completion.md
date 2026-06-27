# Phase 10-B — Item Cockpit Completion

**Completed:** 2026-06-26

**Spec:** [phase-10b-item-cockpit-spec.md](../specifications/phase-10b-item-cockpit-spec.md)

**Test plan:** [phase-10b-test-plan.md](../specifications/phase-10b-test-plan.md)

---

## Deliverables

### PR 1 — Behavior-aware warnings

- `Purchasing::OrderEligibilityResolver#vendor_sourcing_warnings_applicable?` skips vendor-source warnings for used, non-orderable, and financial/service variants
- `Items::ItemOverviewPresenter#vendor_source_status` returns `:not_applicable` when sourcing warnings do not apply
- `Items::OperationalWarningBuilder` suppresses non-merchandise selling warnings, preferred-vendor warnings when not applicable, and `:non_inventory` info noise; `:non_inventory_with_stock` reads physical balance when snapshot omits on-hand
- Tests across all three warning sources; [phase-10b-test-plan.md](../specifications/phase-10b-test-plan.md) added

### PR 2A/2B — Variant operations drawer

- `Items::VariantOperationsDrawerPresenter` + `GET /items/variant_operations_drawer`
- Unified `item-variant-ops-drawer` shell with server-rendered Turbo Frame body
- **Details** button per variant row (keyboard-accessible)
- Operations consolidation: demand create, recommended purchasing actions, and variant-scoped readouts live in drawer; page-level collapsible panels removed
- `#receiving-history` anchor placeholder preserved on Operations tab
- Demand form merged into unified drawer with 10-A reset-on-close behavior
- Turbo Stream refresh of drawer body on successful demand create

### PR 3/4 — Setup modals

- Shared `Interaction::ModalStreamable` contract: section refresh + toast + modal close on success; modal body replace on validation error
- Narrow quick forms under `app/views/items/setup_modals/`
- `Items::SetupModalsController` for identifier, price, product vendor, variant vendor, and classification quick edits
- Classification modal: **Derived tax category preview** via server-only `classification_tax_preview` endpoint
- Full-page edit escape hatches retained on every modal

### Contract preservation

- Tab URLs unchanged (`tab=overview|operations|item_setup|activity`)
- Drill-down anchors preserved: `#warnings`, `#variant-matrix`, `#sales-history`, `#receiving-history`, `#vendor-sourcing`
- `items_item_overview_contract_test.rb` passes

---

## Verification

```bash
docker compose run --rm -e RAILS_ENV=test web bin/rails test test/integration/items_item_overview_contract_test.rb
docker compose run --rm -e RAILS_ENV=test web bin/rails test test/integration/items_customer_demand_drawer_integration_test.rb
docker compose run --rm -e RAILS_ENV=test web bin/rails test test/integration/items_variant_operations_drawer_integration_test.rb
docker compose run --rm -e RAILS_ENV=test web bin/rails test test/integration/items_setup_modals_integration_test.rb
docker compose run --rm -e RAILS_ENV=test web bin/rails test test/services/purchasing/order_eligibility_resolver_test.rb
docker compose run --rm -e RAILS_ENV=test web bin/rails test test/services/items/operational_warning_builder_test.rb
docker compose run --rm -e RAILS_ENV=test web bin/rails test test/presenters/items/item_overview_presenter_test.rb
docker compose run --rm -e RAILS_ENV=test web bin/rails test test/presenters/items/variant_operations_drawer_presenter_test.rb
docker compose run --rm -e RAILS_ENV=test web bin/rails test test/system/items/customer_demand_drawer_test.rb
```

---

## Deferred / follow-on

- POS item-detail drawer pattern (Phase 10-C)
- Shared `resetDirtyBaseline(form)` helper extraction if modal forms prove the need
- Retire legacy `item_customer_demand_drawer_controller.js` once confirmed unused in production flows
