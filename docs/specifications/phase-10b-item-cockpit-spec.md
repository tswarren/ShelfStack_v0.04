# Phase 10-B — Item Cockpit Specification

**Status:** Planned — **implementation source of truth**

**Roadmap:** [phase-10b-item-cockpit-completion.md](../roadmap/phase-10b-item-cockpit-completion.md)

**Mockup reference:** [shelfstack_items_mockups.html](../samples/phase-10-mockups/shelfstack_items_mockups.html)

**Prerequisite:** Phase 8.5-4 complete

---

## Scope

Complete item cockpit gaps on 8.5-4: setup modals, operations summary + demand drawer, behavior-aware warnings.

## Hard dependencies on 10-A

10-B may start when these 10-A deliverables land (other 10-A work may continue in parallel):

* Shared drawer shell
* Shared modal shell
* Focus restoration on modal/drawer close

## Non-Goals

* Greenfield overview redesign
* Tab renames (preserve URLs/anchors from [drill-down contract](../handoff/phase-9-item-drill-down-contract.md))
* Add Item wizard redesign
* Item command language (`/tbo`, `/vendor`, `⌘K`)

---

## Acceptance Criteria

Phase 10-B is complete when:

1. **Setup modals** — bounded edits for identifier, price, vendor source, and tax category use 10-A modal shell; validation stays inside modal.
2. **Operations drawer** — variant operations summary table + demand drawer on shared 10-A drawer shell (replaces ad-hoc demand drawer controller).
3. **Drill-down contract** — `#warnings`, `#variant-matrix`, link conventions unchanged; `items_item_overview_contract_test.rb` passes.
4. **Behavior-aware warnings** — used/buyback variants do not show inappropriate vendor-source warnings.
5. **Reuse** — drawer shell ready for 10-C POS item-detail drawer pattern.

---

## Test Plan

### Integration

* `test/integration/items_item_overview_contract_test.rb` — anchors, tab links, contract surfaces
* Setup modal: save, cancel, inline validation, focus restore on close
* Operations drawer: open from variant row, close, focus restore, page state preserved

### Services / presenters

* Behavior-aware warnings: used vs new vs non-inventory vs gift card variants

### Regression

* Existing 8.5-4 item overview and operations presenter tests remain green

---

## Related

* [phase-10a-interaction-infrastructure-spec.md](phase-10a-interaction-infrastructure-spec.md)
* [phase-9-item-drill-down-contract.md](../handoff/phase-9-item-drill-down-contract.md)
