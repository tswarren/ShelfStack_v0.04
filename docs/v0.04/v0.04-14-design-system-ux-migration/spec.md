# v0.04-14 Design System UX Migration — Functional Specification

## Status

**Active** — next ShelfStack release milestone after v0.04-13.

Companion documents:

* [data-model.md](data-model.md) — no core schema changes
* [test-plan.md](test-plan.md) — enabling-layer and surface migration gates
* [../../design/ux-migration-build-plan.md](../../design/ux-migration-build-plan.md) — detailed PR slices and partial APIs
* [../../roadmap/phase-10e-ux-migration.md](../../roadmap/phase-10e-ux-migration.md) — Phase 10-E roadmap summary
* `docs/implementation/v0.04-14-completion.md` (created at milestone close)

---

## Milestone identity

| Field | Value |
| ----- | ----- |
| Release milestone | **v0.04-14** |
| Implementation track | **Phase 10-E** (consistency sweep) |
| Type | Cross-cutting UX / design-system migration |
| Domain model | **No change** — [VERSION_0.04.md](../../design/VERSION_0.04.md) semantics unchanged |

v0.04-14 is the **version number** for this release. Phase 10-E is the **delivery phase** name. Both refer to the same work.

---

## Job

Migrate legacy and inconsistent views to the documented design system:

* modular `shelfstack.components.*.css` and `shelfstack.domain.*.css`
* shared enabling partials (`shared/ui/*`)
* documented feedback, page-header, table, and shell patterns

**Prerequisite (merged):** modular CSS component library, app shell contract, and component spec catalog (`design/css-component-library`).

**Strategy:** Small enabling layer first → one low-risk pilot surface → repeat surface-by-surface. Do **not** build a partial for every component. Do **not** start with POS, purchasing, receiving, or item operations.

---

## Resolved decisions

| Decision | Choice |
| -------- | ------ |
| Milestone type | App-wide UX consistency — not domain redesign |
| Schema | No new core tables |
| Partial scope | Seven enabling pieces only (button, page_header, alert, empty_state, errors, field, status badge helper) |
| Pilot surface | `setup/vendors` index + show |
| Auth layout | Login, unlock, workstation assignment, change password → `layouts/auth` |
| PIN layout | Set/change PIN → `application` shell |
| Filter chip | CSS in modular layer before new uses; no partial yet |
| Modal/dialog | Keep `shared/interaction/_modal` transitional; no `shared/ui/_dialog` fork |
| POS / domain last | Phase 6 of build plan after setup and operational surfaces |

---

## Implementation phases (summary)

| Phase | Focus |
| ----- | ----- |
| 0 | Filter-chip CSS, `.ss-empty-state__message`, auth shell docs |
| 1 | `shared/ui` button, page_header, alert |
| 2 | `_errors`, `_field`, empty_state, `ss_status_badge` |
| 3 | Pilot: setup vendors |
| 4 | Remaining setup CRUD surfaces |
| 5 | Customers, items, reports, demand |
| 6 | POS, purchasing, receiving, inventory ops, buybacks |

Full detail: [ux-migration-build-plan.md](../../design/ux-migration-build-plan.md).

---

## Out of scope

* v0.04 domain milestones (v0.04-3 product groups, vendor EDI/API automation)
* Full POS keyboard workspace redesign (Phase 10-C complete; styling migration only)
* New domain services or demand/PO/receiving rule changes
* `shared/ui/_data_table`, `_form`, `_filter_chip` partials (deferred)
* Complete legacy `shelfstack.css` deletion in one pass (extract incrementally)

---

## Acceptance criteria (milestone complete)

1. Enabling partials and helpers from the build plan implemented and tested.
2. Setup surfaces through Phase 4 order migrated to documented patterns.
3. Operational surfaces (Phase 5) use consistent headers, tables, empty states, badges, and feedback classes.
4. High-risk domain workspaces (Phase 6) use extracted domain CSS without new monolithic legacy rules.
5. Phase 9b report regression checklist passes.
6. [ux-review-checklist.md](../../design/ux-review-checklist.md) passes on representative pages per workspace.
7. Phase 10 marked complete when 10-E acceptance criteria in [phase-10e-ux-migration.md](../../roadmap/phase-10e-ux-migration.md) are met.
