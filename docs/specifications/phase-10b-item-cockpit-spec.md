# Phase 10-B — Item Cockpit Specification

**Status:** Planned

**Roadmap:** [phase-10b-item-cockpit-completion.md](../roadmap/phase-10b-item-cockpit-completion.md)

**Mockup reference:** [shelfstack_items_mockups.html](../samples/phase-10-mockups/shelfstack_items_mockups.html)

**Prerequisite:** Phase 8.5-4 complete

---

## Scope

Complete item cockpit gaps on 8.5-4 foundation: setup modals, operations summary + demand drawer, behavior-aware warnings.

## Non-Goals

* Greenfield overview redesign
* Tab renames (URLs/anchors must be preserved)
* Add Item wizard redesign
* Item command language (`/tbo`, `/vendor`, `⌘K`)

## Acceptance Criteria

See [phase-10b-item-cockpit-completion.md](../roadmap/phase-10b-item-cockpit-completion.md#acceptance-criteria).

## Test Plan

* `test/integration/items_item_overview_contract_test.rb`
* Setup modal integration tests
* Operations drawer integration tests
* Behavior-aware warning tests for used/buyback vs vendor-orderable variants

## Related

* [phase-9-item-drill-down-contract.md](../handoff/phase-9-item-drill-down-contract.md)
* [phase-10a-interaction-infrastructure-spec.md](phase-10a-interaction-infrastructure-spec.md)
