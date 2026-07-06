# UX Migration Build Plan (v0.04-14 / Phase 10-E)

| Field | Value |
| ----- | ----- |
| Milestone | **v0.04-14** — single release (integration branch) |
| Status | Active build guide |
| Integration branch | `v0.04-14/ux-migration` |
| Parent | [v0.04-14 spec](../v0.04/v0.04-14-design-system-ux-migration/spec.md) · [Phase 10-E UX migration](../roadmap/phase-10e-ux-migration.md) |
| Component contracts | [components.md](components.md) |
| Review gate | [ux-review-checklist.md](ux-review-checklist.md) |
| CSS rules | [../../app/assets/stylesheets/README.md](../../app/assets/stylesheets/README.md) |

This document is the **execution plan** for migrating legacy views to the documented design system. It defines phases, PR slices, partial APIs, tests, and surface order.

**Goal:**

```text
Make the most repeated page/action/feedback patterns safe to reuse,
then migrate one low-risk surface to prove the pattern,
then proceed surface-by-surface.
```

Do **not** build a partial for every documented component. Do **not** start with POS, purchasing, receiving, or item operations.

---

## Prerequisites

1. Modular CSS component library merged to `main` (done).
2. Milestone **planning docs** live on `main`; **implementation** lands on `v0.04-14/ux-migration` until the full release merges.
3. Read before coding:
   - [ux-guide.md](ux-guide.md)
   - [app-shell-and-pos-shell.md](app-shell-and-pos-shell.md)
   - [components.md](components.md) — especially [migration stragglers](components.md#known-migration-stragglers)
   - [ux-review-checklist.md](ux-review-checklist.md)

---

## Principles

| Do | Do not |
| -- | ------ |
| Use modular `shelfstack.components.*.css` and documented `.ss-*` classes | Add new rules to monolithic `shelfstack.css` |
| Extract legacy CSS when touching a domain workspace | Fork a second modal/dialog partial system |
| Migrate one setup surface fully before sweeping | Rewrite every status table when adding `ss_status_badge` |
| Use `shared/ui/*` for repeated chrome patterns | Build `_data_table`, `_form`, or `_filter_chip` partials yet |
| Run the UX review checklist on each migrated surface | Change POS/purchasing domain rules during styling work |

---

## Release branching (single v0.04-14 release)

v0.04-14 ships as **one release** to `main`. Implementation accumulates on an integration branch; slice PRs do not merge to `main` until the milestone is complete.

```text
main                         (stable — planning docs only until release)
  └── v0.04-14/ux-migration  (integration branch — all implementation)
        ├── v0.04-14/pr0-prep       → merge into integration branch
        ├── v0.04-14/pr1-core-ui    → merge into integration branch
        ├── v0.04-14/pr2-forms      → …
        └── v0.04-14/pr3-vendors    → …

Release:  v0.04-14/ux-migration → main  (single PR) + tag v0.04-14
```

| Rule | Detail |
| ---- | ------ |
| Integration branch | `v0.04-14/ux-migration` |
| Slice branch naming | `v0.04-14/<slice>` (e.g. `v0.04-14/pr1-core-ui`) |
| Slice PR target | Merge into `v0.04-14/ux-migration`, not `main` |
| New slice base | Branch from **integration branch** after prior slice merged |
| Stay current | Periodically merge `main` → integration branch if other work lands on `main` |
| Release | One PR integration branch → `main`; tag `v0.04-14`; write `v0.04-14-completion.md` |

Planning and milestone-tracking docs may land on `main` early. CSS, partials, helpers, and view migrations stay on the integration branch until release.

---

# Phase 0 — Prep slice

**Goal:** Remove small blockers before shared partial work.

### 0.1 Add filter-chip CSS (no partial)

**File:** `app/assets/stylesheets/shelfstack.components.data-tables.css`

```css
.ss-filter-chip
.ss-filter-chip--active
.ss-filter-chip--removable
.ss-filter-chip__label
.ss-filter-chip__remove
```

See [components/filter-chip.md](components/filter-chip.md). CSS only — partial deferred.

### 0.2 Add empty-state message element

**File:** `app/assets/stylesheets/shelfstack.components.feedback.css`

```css
.ss-empty-state__message
```

Supports `message:` on the planned `shared/ui/_empty_state` partial.

### 0.3 Auth shell decision (docs)

**Focused auth layout** (`layouts/auth`): login, unlock, workstation assignment, **change password**.

**Application shell** (`layouts/application`): set/change PIN and all normal app pages.

Auth screens use shared form, alert, flash, and session-card patterns where appropriate — not the global header/nav. See [app-shell-and-pos-shell.md](app-shell-and-pos-shell.md#auth-layout-exception).

---

# Phase 1 — Core shared UI partials

**Goal:** Smallest reusable layer needed for safe migration.

**PR:** `PR 1 — Core UI partials`

### 1.1 `shared/ui/_button.html.erb`

**Spec:** [components/button.md](components/button.md)

| Local | Values |
| ----- | ------ |
| `label` | required |
| `variant` | `:primary`, `:secondary`, `:tertiary`, `:ghost`, `:danger`, `:link` |
| `size` | `nil`, `:small`, `:large` |
| `type` | `:button`, `:submit`, `:reset` |
| `url`, `method`, `disabled`, `data`, `aria`, `form`, `form_class` | optional |
| `class` | extra classes |
| `full_width` | maps to `.ss-btn--full` |
| `icon` | maps to `.ss-btn--icon` when needed |

| Input | Render |
| ----- | ------ |
| `url` + GET/nil method | `link_to` |
| `url` + non-GET method | `button_to` |
| no `url` | `button_tag` |
| `variant: :link` | `.ss-btn-link` only |
| disabled link | non-link element with `aria-disabled="true"` |

`:link` is for low-emphasis action-like controls in action rows — **not** normal navigation.

### 1.2 `shared/ui/_page_header.html.erb`

**Spec:** [components/page-header.md](components/page-header.md)

| Local | Purpose |
| ----- | ------- |
| `title` | required |
| `eyebrow`, `description`, `actions` | optional |
| block | optional actions; **block wins over `actions:`** |

### 1.3 Delegate `shared/forms/_page_header.html.erb`

Thin wrapper delegating to `shared/ui/page_header`. Preserves existing form-page call sites.

### 1.4 `shared/ui/_alert.html.erb`

**Spec:** [components/alert.md](components/alert.md)

Variants: `:info`, `:success`, `:warning`, `:error` only. Do **not** support `:neutral` until `.ss-alert--neutral` exists in CSS.

Supports `title`, `message`, and block content.

### Phase 1 tests

| Case | Assertion |
| ---- | --------- |
| button primary / danger | correct `.ss-btn*` classes |
| button disabled link | non-link + `aria-disabled` |
| `variant: :link` | `.ss-btn-link` only |
| page_header | `h1`, `.ss-page-actions` |
| alert | `.ss-alert--warning`, `.ss-alert--error` |

---

# Phase 2 — Forms, empty states, badges

**Goal:** Clean validation, empty, and status patterns before page migration.

**PR:** `PR 2 — Forms and feedback`

### 2.1 Revise `shared/forms/_errors.html.erb`

Replace `.flash.flash-alert` with `shared/ui/alert`. Use a **list**, not `to_sentence`. Keep `record` as the local name.

```erb
<% if record.errors.any? %>
  <%= render "shared/ui/alert",
        variant: :error,
        title: "Please correct the following fields" do %>
    <ul>
      <% record.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  <% end %>
<% end %>
```

Form-level summary only — field-level errors stay in `_field`.

**Update tests:** `test/controllers/passwords_controller_test.rb`, `test/integration/setup_workstations_controller_test.rb`.

### 2.2 Revise `shared/forms/_field.html.erb`

**Spec:** [components/field.md](components/field.md)

Add or confirm: `help:`, `warning:`, `required:`, `label:`.

| State | Output |
| ----- | ------ |
| help | `.ss-help` |
| warning | `.ss-field-warning` |
| error | `.ss-field-error`, `.ss-field--error` |
| required | `.ss-required` in label |

Add helpers (do not inline ID logic in the partial):

```ruby
ss_field_dom_id(record, field, suffix)
ss_field_describedby_ids(record, field, help:, warning:, error:)
ss_field_warning(record, field, message:)
```

### 2.3 `shared/ui/_empty_state.html.erb`

**Spec:** [components/empty-state.md](components/empty-state.md)

Locals: `title:`, `message:`. Optional block for `.ss-empty-state__actions`.

### 2.4 Delegate `reports/shared/_empty_state.html.erb`

Delegate to generic partial or match the same markup contract.

### 2.5 `ss_status_badge` helper

Add to `UiHelper` (included in `ApplicationHelper`). Helper first — not a partial.

```ruby
def ss_status_badge(label, status:)
  key = status.to_s
  tag.span(label, class: ["ss-status-badge", "status-#{key}"])
end
```

Do **not** use `dasherize` or `parameterize`. CSS uses underscores (`status-partially_received`).

Use on the pilot surface first. Legacy `status_class` / bare `.status-active` spans may remain until opportunistic migration.

### Phase 2 tests

| Case | Assertion |
| ---- | --------- |
| `_errors` | `.ss-alert--error`, list items |
| `_field` warning | `.ss-field-warning` |
| `_field` describedby | `aria-describedby` when help/warning/error present |
| `ss_status_badge` | `ss-status-badge status-partially_received` |
| `empty_state` | title, message, actions block |

---

# Phase 3 — Pilot migration

**Goal:** Prove contracts on one low-risk surface.

**PR:** `PR 3 — Pilot: setup vendors`

### Recommended pilot

```text
setup/vendors/index
setup/vendors/show
```

Alternative: `setup/tax_categories/index` + `show` (simpler domain).

Avoid `departments` / `sub_departments` first — classification tree adds noise.

### Pilot success criteria

1. `shared/ui/page_header` for page title and actions
2. `shared/ui/button` for primary actions (not inline `ss-btn` on raw `link_to` in `h1`)
3. `shared/ui/empty_state` when `@vendors` is empty (index currently has no empty branch)
4. `ss_status_badge` for status on index/show
5. `.ss-table` or documented data-table shell consistently
6. `shared/forms/*` on new/edit forms
7. No new `shelfstack.css` rules
8. No new `.flash-alert` patterns
9. Pass [ux-review-checklist.md](ux-review-checklist.md) for shell, page header, feedback, accessibility

### Pilot tests

At least one request or system test asserting:

```text
.ss-page-header
.ss-table
.ss-status-badge
.ss-empty-state   (when fixture has no rows)
```

---

# Phase 4 — Low-risk setup migration

After pilot, repeat the same pattern on similar setup surfaces.

**Order:**

```text
1. setup/vendors          (pilot — done in PR 3)
2. setup/tax_categories
3. setup/formats
4. setup/discount_reasons
5. setup/stores
6. setup/users
7. setup/sub_departments
8. setup/departments      (most complex — last in setup wave)
```

**Optional add-on:** migrate `demand/locked_out` and `sourcing/locked_out` to `.ss-access-notice` per [components/access-notice.md](components/access-notice.md).

**Per-surface pattern:**

```text
Page Header → Table / Data Table shell → Empty State → Status Badge
→ Form sections/fields → Alert for workflow conditions → Button partial for actions
```

Do not migrate removed resources (`accounting_mappings`, `merchandise_classes`).

---

# Phase 5 — Operational surfaces (non-POS)

```text
1. customers index/detail
2. items index
3. item detail (layout already partially migrated)
4. reports index/views
5. demand queues
```

Add `shared/ui/_metric_card` and `shared/ui/_summary` only when repetition proves the API — likely during reports/detail work.

**Defer:** buyer workbench until filter-chip CSS is proven and workbench patterns stabilize.

---

# Phase 6 — High-risk domain workspaces

Migrate last, with domain CSS extraction:

```text
POS
purchasing / receiving
inventory adjustments
item operations
buybacks (dynamic workbench patterns)
```

**Domain CSS homes:**

```text
shelfstack.domain.pos.css
shelfstack.domain.orders.css
shelfstack.domain.items.css
shelfstack.domain.inventory.css
```

Do not force POS-, receiving-, or purchasing-specific controls into generic components unless truly reusable.

**Interaction shell:** keep `shared/interaction/_modal`, `_drawer`, `_expanded_row`, `_shortcut_strip`. Extract styling from legacy CSS; do not fork partials.

---

# Deferred partials and patterns

| Item | Reason |
| ---- | ------ |
| `shared/ui/_form` | `shared/forms/*` is sufficient |
| `shared/ui/_data_table` | Too much variation across indexes/reports/workbenches |
| `shared/ui/_filter_chip` | CSS first; partial after repeated usage |
| `shared/ui/_dialog` | `_modal` is the active transitional implementation |
| `shared/ui/_metric_card` | Wait for reports/dashboard migration |
| `shared/ui/_summary` | Direct `<dl class="ss-summary">` until repetition proves need |
| expanded-row / shortcut-strip replacements | Partials exist; CSS extraction is the gap |

---

# PR sequence summary

Slice PRs merge into **`v0.04-14/ux-migration`**. Only the final release PR merges the integration branch to `main`.

```text
Integration branch: v0.04-14/ux-migration

PR 0 — Prep  (merged)
  filter-chip CSS
  empty-state __message CSS
  auth/password shell docs

PR 1 — Core UI partials
  branch: v0.04-14/pr1-core-ui
  shared/ui/_button
  shared/ui/_page_header
  shared/ui/_alert
  forms/_page_header delegates
  Phase 1 tests

PR 2 — Forms and feedback
  branch: v0.04-14/pr2-forms
  forms/_errors revised
  forms/_field warning + describedby
  shared/ui/_empty_state
  reports/_empty_state aligns
  ss_status_badge helper
  Phase 2 tests

PR 3 — Pilot
  branch: v0.04-14/pr3-vendors
  setup/vendors index + show
  pilot test

PR 4+ — Setup surfaces (tax_categories, formats, …)

Later — Operational and domain workspaces

Release — v0.04-14/ux-migration → main + tag v0.04-14
```

---

# Definition of done (per migrated surface)

1. Uses documented component classes and enabling partials where applicable.
2. No new legacy flash patterns (`.flash.flash-*`).
3. No new rules in monolithic `shelfstack.css`.
4. [ux-review-checklist.md](ux-review-checklist.md) sections for touched areas pass.
5. Tests updated for changed feedback markup.
6. Report view contract unchanged when touching report shells ([report-view-contract.md](../specifications/report-view-contract.md)).

---

# Related documents

| Document | Role |
| -------- | ---- |
| [components.md](components.md) | Catalog, stragglers, Phase 10-E alignment |
| [components/button.md](components/button.md) | Button hierarchy and variants |
| [components/page-header.md](components/page-header.md) | Page header contract |
| [components/alert.md](components/alert.md) | Alert vs flash vs toast |
| [components/field.md](components/field.md) | Field error/warning contract |
| [components/empty-state.md](components/empty-state.md) | Empty state markup |
| [components/filter-chip.md](components/filter-chip.md) | Filter chip CSS contract |
| [components/access-notice.md](components/access-notice.md) | Locked-out pages |
| [../specifications/ui-components.md](../specifications/ui-components.md) | Modal, drawer, toast, expanded row |
| [../roadmap/Phase-x10-comprehensive-ux-expansion.md](../roadmap/Phase-x10-comprehensive-ux-expansion.md) | Phase 10 parent; report regression checklist |
