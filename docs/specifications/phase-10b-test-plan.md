# Phase 10-B — Item Cockpit Test Plan

**Status:** In progress

**Spec:** [phase-10b-item-cockpit-spec.md](phase-10b-item-cockpit-spec.md)

---

## PR 1 — Behavior-aware warnings

| Area | Test file |
|------|-----------|
| Order eligibility | `test/services/purchasing/order_eligibility_resolver_test.rb` |
| Overview vendor source | `test/presenters/items/item_overview_presenter_test.rb` |
| Operational warnings | `test/services/items/operational_warning_builder_test.rb` |

Cases: new vs used vs non-inventory vs financial/service product types; vendor sourcing warnings only when applicable.

---

## PR 2A — Read-only variant operations drawer

| Area | Test file |
|------|-----------|
| Presenter | `test/presenters/items/variant_operations_drawer_presenter_test.rb` |
| Integration | `test/integration/items_variant_operations_drawer_integration_test.rb` |
| System | `test/system/items/variant_operations_drawer_test.rb` |

---

## PR 2B — Operations consolidation

| Area | Test file |
|------|-----------|
| Integration | demand create from drawer, anchor placeholders |
| System | panel removal, form reset, drawer refresh |
| Regression | `test/integration/items_item_overview_contract_test.rb` |

---

## PR 3–4 — Setup modals

Shared modal contract per family: success (refresh section + toast + close + focus), validation (modal stays open).

| Modal | Integration test |
|-------|------------------|
| Identifier | `test/integration/items_setup_modal_identifier_test.rb` |
| Price | `test/integration/items_setup_modal_price_test.rb` |
| Vendor / classification | `test/integration/items_setup_modal_vendor_classification_test.rb` |

---

## Regression (every PR)

```bash
bin/rails test test/integration/items_item_overview_contract_test.rb
```
