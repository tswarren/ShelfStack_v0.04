# Phase 10-B — Item Cockpit Completion

**Status:** Complete

**Completion record:** [phase-10b-completion.md](../implementation/phase-10b-completion.md)

**Parent:** [Phase-x10-comprehensive-ux-expansion.md](Phase-x10-comprehensive-ux-expansion.md)

**Depends on:** [phase-10a-interaction-infrastructure.md](phase-10a-interaction-infrastructure.md) (complete)

**Spec:** [phase-10b-item-cockpit-spec.md](../specifications/phase-10b-item-cockpit-spec.md)

**Prerequisite:** Phase 8.5-4 item data quality and operational item pages (**complete**)

**Visual reference:** [shelfstack_items_mockups.html](../samples/phase-10-mockups/shelfstack_items_mockups.html). Item overview wireframe also in [shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html).

---

## Purpose

Complete the `/items` cockpit on top of Phase 8.5-4 — not a greenfield redesign. The item page should answer:

```text
What is this?
Can we sell it?
Do we have it?
Can we order it?
Who is waiting for it?
What needs attention?
What should staff do next?
```

---

## Phase 8.5-4 Foundation (do not re-build)

| Surface | Shipped in 8.5-4 |
| ------- | ---------------- |
| Overview hero, cover, lifecycle | `Items::ItemOverviewPresenter`, `.ss-item-hero` |
| Attention / warnings | `#warnings`, `Items::OperationalWarningBuilder` |
| Summary cards | `.ss-item-summary-cards` |
| Variant readiness matrix | `#variant-matrix`, `Items::VariantOperationalSnapshot` |
| Compact sales/receiving | `#sales-history`, `#receiving-history`, lookup services |
| Index signals column | `Items::IndexWarningSummary` |
| Drill-down contract | [phase-9-item-drill-down-contract.md](../handoff/phase-9-item-drill-down-contract.md) |

Verification baseline: `test/integration/items_item_overview_contract_test.rb`

---

## 10-B Scope (gaps only)

| Mockup screen | Scope |
| ------------- | ----- |
| 1. Overview cockpit | **Mostly 8.5-4** — use mock to validate hierarchy/spacing; optional polish only |
| 2. Operations + drawer | **Core 10-B** — variant ops summary table + demand drawer (replace ad-hoc `item_customer_demand_drawer_controller`) |
| 3. Item setup + modal | **Core 10-B** — bounded setup modals (identifier, price, vendor source, tax category) |

Deliverables:

* Setup **modals** using 10-A shell for bounded edits
* Operations tab: **summary table + drawer** for variant/demand detail
* Behavior-aware warning rules (used/buyback vs vendor-orderable vs non-inventory vs gift card)
* Preserve tab URLs and anchors (`tab=overview`, `#variant-matrix`, etc.)

---

## Non-Goals

* Full tab restructure or tab label renames (optional polish; URLs/anchors must remain)
* Add Item wizard redesign (still deferred from 8.5-4)
* Item command language (`/tbo`, `/vendor`, mockup `⌘K`) — **deferred** unless scope expanded
* Items operations command bar from mockup — inspiration only

---

## Behavior-Aware UX Rules

* Vendor-source warnings apply only to vendor-orderable variants.
* Used/buyback variants must not be marked incomplete for lacking vendor source records.
* Non-inventory items must not show inventory-specific warnings.
* Gift card/stored-value items must not look like ordinary merchandise SKUs.
* Café/service items expose relevant POS/reporting setup, not bibliographic detail.

---

## Implementation Checklist

```text
1. Migrate item customer demand drawer to shared 10-A drawer shell
2. Operations tab: variant operations summary table
3. Demand drawer: customer requests, TBO, holds, recommended actions
4. Setup modals: add/edit identifier
5. Setup modals: edit price, vendor source, tax category (bounded)
6. Behavior-aware warning gaps (if any remain after 8.5-4)
7. Drill-down contract regression tests
```

---

## Acceptance Criteria

See [phase-10b-item-cockpit-spec.md](../specifications/phase-10b-item-cockpit-spec.md#acceptance-criteria).

---

## Test Plan

See [phase-10b-item-cockpit-spec.md](../specifications/phase-10b-item-cockpit-spec.md#test-plan).

---

## Related Documents

```text
docs/specifications/phase-10b-item-cockpit-spec.md
docs/handoff/phase-9-item-drill-down-contract.md
docs/implementation/phase-8.5-4-completion.md
docs/roadmap/phase-10a-interaction-infrastructure.md
docs/roadmap/phase-10c-pos-keyboard-workspace.md
docs/samples/phase-10-mockups/shelfstack_items_mockups.html
```
