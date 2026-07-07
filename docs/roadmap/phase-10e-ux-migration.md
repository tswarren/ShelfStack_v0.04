# Phase 10-E — UX Migration (Consistency Sweep)

| Field | Value |
| ----- | ----- |
| Release milestone | **v0.04-14** — [spec bundle](../v0.04/v0.04-14-design-system-ux-migration/spec.md) |
| Integration branch | `v0.04-14/ux-migration` (single release to `main` at milestone close) |
| Status | **Complete on integration branch** — release to `main` pending |
| Parent | [Phase-x10-comprehensive-ux-expansion.md](Phase-x10-comprehensive-ux-expansion.md) |
| Build plan | [../design/ux-migration-build-plan.md](../design/ux-migration-build-plan.md) |
| Component catalog | [../design/components.md](../design/components.md) |
| Review checklist | [../design/ux-review-checklist.md](../design/ux-review-checklist.md) |

Phase 10-A through 10-D are complete. Phase 10-E normalizes app-wide UI to the documented component library through a **small enabling layer** and **surface-by-surface migration** — not a big-bang restyle.

---

## Goal

```text
Shared UI partials + CSS contracts → pilot setup surface → repeat low-risk surfaces → operational → domain last
```

Do **not** build a partial for every component. Do **not** start with POS, purchasing, receiving, or item operations.

---

## Prerequisites

1. Modular CSS component library merged to `main` (design system branch).
2. Implementation on integration branch **`v0.04-14/ux-migration`**; slice PRs merge there, not to `main`.
3. Contributors read [ux-migration-build-plan.md](../design/ux-migration-build-plan.md) before opening migration PRs.

---

## Delivery phases (summary)

| Phase | Focus | PR |
| ----- | ----- | -- |
| 0 | Filter-chip CSS, empty-state `__message`, auth shell docs | PR 0 |
| 1 | `shared/ui` button, page_header, alert | PR 1 |
| 2 | `_errors`, `_field`, empty_state, `ss_status_badge` | PR 2 |
| 3 | Pilot: `setup/vendors` index + show | PR 3 |
| 4 | Remaining setup CRUD surfaces (4, 4B, 4C) | PR 4+ |
| polish | Pre–Phase 6 contract fixes (block precedence, nested main, filter labels) | PR polish |
| 5 | Customers, items, reports, demand | Complete |
| 6 | POS, purchasing, receiving, inventory ops, buybacks | **Complete** (integration branch) |

Full APIs, tests, surface order, and Phase 6 tracking checklist: [ux-migration-build-plan.md](../design/ux-migration-build-plan.md).

### Later backlog (not Phase 6 blockers)

Tracked in the build plan **Later backlog** section:

* `shared/forms/_field` aria yield + caller wiring (incremental)
* Strict button/alert variant validation in test/dev
* Items index filter layout partial / `shared/forms/field` adoption
* `shared/ui/_filter_chip`, `_metric_card`, `_summary` partials
* Customers stored-value admin migration
* Full workspace a11y audit at milestone close

---

## Enabling layer (minimum before broad migration)

```text
shared/ui/_button
shared/ui/_page_header
shared/ui/_alert
shared/ui/_empty_state
shared/forms/_errors          (revised)
shared/forms/_field           (warning + aria-describedby)
ss_status_badge helper
```

---

## Scope from parent Phase 10-E

From [Phase-x10-comprehensive-ux-expansion.md](Phase-x10-comprehensive-ux-expansion.md#phase-10-e--polish-and-consistency-sweep):

1. Remove one-off button/filter/table styles
2. Replace raw selects/inputs where forms partials apply
3. Normalize empty states
4. Normalize status badges
5. Normalize row actions
6. Verify keyboard/focus behavior
7. Verify responsive behavior
8. Verify print/report compatibility (Phase 9b regression)
9. Accessibility: focus rings, contrast, screen-reader labels
10. Touch targets on POS expanded row and settlement actions (Phase 6)

### Report regression checklist

After shared CSS or layout changes, verify:

* `/reports` hub and permission-union nav
* Register summary report (render + print)
* Tax collected report
* Customer request queue report with status badges
* No filter/button/table regressions on operational reports

---

## Legacy extraction (ongoing)

Migrate durable rules out of `shelfstack.css` into:

```text
shelfstack.components.*.css   — generic UI
shelfstack.domain.*.css       — workspace-specific
```

See [known migration stragglers](../design/components.md#known-migration-stragglers) and [stylesheets README](../../app/assets/stylesheets/README.md).

---

## Relationship to v0.04 core

v0.04-14 is the **release milestone** for this work; Phase 10-E is the **delivery phase** name. Domain milestones v0.04-0 … v0.04-12 are complete; **v0.04-13 is deferred** until after v0.04-14. v0.04-14 is **UI consistency on the existing codebase** and does not change [VERSION_0.04.md](../design/VERSION_0.04.md) domain semantics. New features should use the enabling partials and documented classes from the first PR that touches a workspace.

---

## Acceptance criteria

Phase 10-E is complete when:

1. Enabling partials and helpers from the build plan are implemented and tested.
2. Setup surfaces through Phase 4 order are migrated to the documented pattern.
3. Operational surfaces (Phase 5) use consistent page headers, tables, empty states, badges, and feedback classes.
4. High-risk domain workspaces (Phase 6) use extracted domain CSS without new monolithic legacy rules.
5. Phase 9b report regression checklist passes.
6. [ux-review-checklist.md](../design/ux-review-checklist.md) passes on representative pages per workspace.

**Status:** Criteria 1–4 met on **`v0.04-14/ux-migration`**. Criteria 5–6 are **release gate** items before merge to `main`.

Completion records: [v0.04-14-completion.md](../implementation/v0.04-14-completion.md) and [phase-10e-completion.md](../implementation/phase-10e-completion.md).
