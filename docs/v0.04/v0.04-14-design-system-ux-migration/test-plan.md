# v0.04-14 Design System UX Migration — Test Plan

## Status

**Active** — companion to [spec.md](spec.md) and [ux-migration-build-plan.md](../../design/ux-migration-build-plan.md).

Implementation runs on integration branch **`v0.04-14/ux-migration`**. Slice PRs merge there; the merge gate below applies at **release** (integration branch → `main`).

---

## Merge gate (milestone complete)

Run on **`v0.04-14/ux-migration`** before opening the release PR to `main`:

```bash
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails test:system test/system/app_shell_contract_test.rb
```

Per-slice: run the same test command on the integration branch after each slice merge.

Plus Phase 9b report regression (manual or automated where available):

* `/reports` hub
* Register summary (render + print)
* Tax collected report
* Customer request queue report

Prior v0.04 verifiers must remain green; this milestone does not change domain rules.

---

## PR-stage gates

### PR 0 — Prep (complete on integration branch)

* `.ss-filter-chip*` rules exist in `shelfstack.components.data-tables.css`
* `.ss-empty-state__message` exists in `shelfstack.components.feedback.css`
* [app-shell-and-pos-shell.md](../../design/app-shell-and-pos-shell.md) documents auth vs PIN layout

Slice merged to `v0.04-14/ux-migration` via `v0.04-14/pr0-prep`.

### PR 1 — Core UI partials (complete on integration branch)

| Test area | Assertion |
| --------- | --------- |
| Button helper/view | primary, danger, disabled link, `variant: :link` → `.ss-btn-link` |
| Page header | `h1`, `.ss-page-actions` |
| Alert | `.ss-alert--warning`, `.ss-alert--error`; no `:neutral` until CSS exists |
| Forms page header | delegates to `shared/ui/page_header` |

Slice merged to `v0.04-14/ux-migration` via `v0.04-14/pr1-core-ui`.

### PR 2 — Forms and feedback (complete on integration branch)

| Test area | Assertion |
| --------- | --------- |
| `_errors` | `.ss-alert--error` with list items; not `.flash-alert` |
| `_field` | `.ss-field-warning`, `aria-describedby` when help/warning/error |
| `ss_status_badge` | `ss-status-badge status-partially_received` (underscore preserved) |
| Empty state | title, message, optional actions block |
| Reports empty state | delegates or matches generic contract |

Update legacy tests that assert `.flash-alert` on form errors:

* `test/controllers/passwords_controller_test.rb`
* `test/integration/setup_workstations_controller_test.rb`

Slice merged to `v0.04-14/ux-migration` via `v0.04-14/pr2-forms`.

### PR 3 — Pilot (setup vendors) (complete on integration branch)

| Test area | Assertion |
| --------- | --------- |
| Vendors index | `.ss-page-header`, `.ss-table`, `.ss-status-badge` |
| Vendors index (empty) | `.ss-empty-state` |
| Vendors show | page header (secondary → primary), status badge, danger zone delete |
| Vendors forms | primary submit left, cancel tertiary right |
| Integration | `test/integration/setup_vendors_ux_contract_test.rb` |

Canonical setup detail pattern documented in [button.md](../../design/components/button.md#action-order-shelfstack-standard) and [ux-migration-build-plan.md](../../design/ux-migration-build-plan.md).

Slice merged to `v0.04-14/ux-migration` via `v0.04-14/pr3-vendors` + pilot refinements.

### PR 4+ — Setup surfaces

Repeat pilot assertions per migrated setup index/show.

### Phase 6 — Domain workspaces

* `test/system/app_shell_contract_test.rb` still passes after POS touches
* POS workspace layout tests unchanged in behavior
* No new rules added to monolithic `shelfstack.css` for migrated surfaces

---

## UX review gate

For each migrated surface, run [ux-review-checklist.md](../../design/ux-review-checklist.md) sections:

* Shell (if touched)
* Page header
* Feedback naming (flash vs alert vs field error)
* Tables / data display
* Accessibility (labels, focus, describedby)

---

## Definition of done (per surface)

1. Uses documented classes and enabling partials.
2. No new `.flash.flash-*` patterns.
3. No new `shelfstack.css` rules.
4. Tests updated for changed markup.
5. Checklist sections pass for touched areas.
