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
| Vendors show | page header (secondary → primary), status badge, tertiary back link, danger zone delete |
| Vendors forms | primary submit left, cancel tertiary right |
| Integration | `test/integration/setup_vendors_ux_contract_test.rb` |

Canonical setup detail pattern documented in [button.md](../../design/components/button.md#action-order-shelfstack-standard) and [ux-migration-build-plan.md](../../design/ux-migration-build-plan.md).

Slice merged to `v0.04-14/ux-migration` via `v0.04-14/pr3-vendors` + pilot refinements.

### PR 4+ — Setup surfaces

Repeat pilot assertions per migrated setup index/show.

| Surface | Status on integration branch |
| ------- | ---------------------------- |
| `setup/tax_categories` | Complete |
| `setup/formats` | Complete (branch `v0.04-14/pr4-setup-surfaces`) |
| `setup/discount_reasons` | Complete (branch `v0.04-14/pr4-setup-surfaces`) |
| `setup/stores` | Complete (branch `v0.04-14/pr4-setup-surfaces`) |
| `setup/users` | Complete (branch `v0.04-14/pr4-setup-surfaces`) |
| `setup/sub_departments` | Complete (branch `v0.04-14/pr4-setup-surfaces`) |
| `setup/departments` | Complete (branch `v0.04-14/pr4-setup-surfaces`) |

Integration tests: `setup_vendors_ux_contract_test.rb`, `setup_tax_categories_ux_contract_test.rb`, `setup_pr4_surfaces_ux_contract_test.rb` (remaining six surfaces), `setup_home_ux_contract_test.rb` (setup landing).

### PR 4B — Remaining setup CRUD (Batch A + B)

| Surface | Status on integration branch |
| ------- | ---------------------------- |
| `setup/roles` | Complete |
| `setup/permissions` | Complete (index only) |
| `setup/workstations` | Complete |
| `setup/product_conditions` | Complete |
| `setup/display_locations` | Complete |
| `setup/inventory_reason_codes` | Complete |
| `setup/stored_value_reason_codes` | Complete |
| `setup/tax_exception_reasons` | Complete |
| `setup/store_tax_rates` | Complete |
| `setup/store_tax_category_rates` | Complete |

Integration tests: `setup_pr4b_surfaces_ux_contract_test.rb`. Button partial defaults `ss-inline-form` for non-GET `button_to` wrappers.

### PR 4C — Nested setup and link tables (Batch C + D)

| Surface | Status on integration branch |
| ------- | ---------------------------- |
| `setup/category_schemes` | Complete |
| `setup/category_nodes` | Complete (tree index preserved) |
| `setup/bisac_subjects` | Complete (import show page) |
| `setup/audit_events` | Complete (read-only) |
| `setup/product_vendors` | Complete |
| `setup/product_variant_vendors` | Complete |
| `setup/inventory_locations` | Complete |
| `setup/store_display_locations` | Complete |

Polish: `setup/home/locked_out` (`.ss-access-notice`), `setup/users/_role_assignments`, `setup/external_data_sources` health-check button.

Integration tests: `setup_pr4c_surfaces_ux_contract_test.rb`.

### PR 4½ — Setup landing (complete on branch)

| Test area | Assertion |
| --------- | --------- |
| Setup home | `.ss-page-header`, `.ss-setup-home`, `.ss-card--clickable` nav cards |
| Permission filter | Links hidden without matching `*.view` permission |
| Service | `Setup::HomeNavigation` filters sections and links |
| CSS | `.ss-setup-section` rules in `shelfstack.domain.setup.css` only |

### Phase 5 — Operational surfaces

| Surface | Status on integration branch |
| ------- | ---------------------------- |
| `customers/customers` index/show/forms | Complete (branch `v0.04-14/pr5-customers`) |
| `items` index | Complete (branch `v0.04-14/pr5-items-index`) |
| item detail | Complete (branch `v0.04-14/pr5-items-detail`) |
| `reports` index/views | Complete (branch `v0.04-14/pr5-reports`) |
| demand queues | Complete (branch `v0.04-14/pr5-demand-queues`) |

Integration tests: `customers_customers_ux_contract_test.rb`, `items_index_ux_contract_test.rb`, `items_item_ux_contract_test.rb`, `demand_queues_ux_contract_test.rb`, `reports_ux_contract_test.rb`.

### PR polish — Pre–Phase 6 contract fixes

| Test area | Assertion |
| --------- | --------- |
| `page_header` / `empty_state` | block content wins over `actions:` local |
| Item overview | no nested `main.ss-item-main`; uses `section.ss-item-main` |
| Customers index filter | `label.ss-sr-only` for search field |
| Demand index filters | `label.ss-sr-only` for status and search fields |

Integration/view tests: `ui_partials_test.rb` (block precedence), `customers_customers_ux_contract_test.rb`, `demand_queues_ux_contract_test.rb`, `items_item_ux_contract_test.rb`.

### Phase 6 — Domain workspaces (next)

Add per-slice integration tests following Phase 5 / setup contract patterns. Track surfaces in [ux-migration-build-plan.md](../../design/ux-migration-build-plan.md#phase-6-tracking-checklist).

| Workspace | Contract test (add when slice lands) |
| --------- | ------------------------------------ |
| POS | page header/actions; no layout behavior change |
| Purchasing / receiving | tables, badges, bounded line UX |
| Inventory ops | lifecycle header + danger zone |
| Item operations | drawer actions; legacy admin routes |
| Buybacks | index + workflow show patterns |

**Later (not Phase 6 gate):** field `aria-describedby` mass wiring, items filter partial, `shared/ui/_filter_chip` partial — see build plan Later backlog.

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
