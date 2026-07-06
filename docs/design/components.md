# ShelfStack Component Catalog and Implementation Status

ShelfStack uses a native **ERB + `.ss-*` CSS** component system. This document is the component inventory and migration roadmap. It is not a claim that every listed partial already exists.

For UX principles and shell rules, start with:

- [ux-guide.md](ux-guide.md)
- [app-shell-and-pos-shell.md](app-shell-and-pos-shell.md)
- [layout-width-model.md](layout-width-model.md)
- [ux-review-checklist.md](ux-review-checklist.md)

---

## Status legend

| Status | Meaning |
| ------ | ------- |
| **Implemented** | Markup/CSS/behavior are in active use and should be treated as current contract. |
| **Partial exists** | A shared ERB partial exists and should be preferred for new compatible markup. |
| **CSS only** | CSS conventions exist; no standard partial exists yet. Use documented classes directly. |
| **Mixed / legacy** | New and legacy names coexist. Use the target names for new work and migrate opportunistically. |
| **Planned** | Useful component but not yet standardized. Do not assume a partial exists. |

---

## Naming and file conventions

| Layer | Convention |
| ---- | ---------- |
| CSS classes | `.ss-component`, `.ss-component__element`, `.ss-component--variant` |
| UI state | `.is-active`, `.is-open`, `.is-disabled`, `.is-loading` |
| Business status | `.status-draft`, `.status-posted`, `.status-active`, `.status-inactive` |
| Rails partials | `shared/ui/_component_name.html.erb` when generic and stable |
| Domain partials | `shared/<domain>/_component_name.html.erb` when tied to ShelfStack workflow semantics |
| Optional future ViewComponent | `Ui::ComponentNameComponent` after ERB partial API stabilizes |

**Button size and danger modifiers:** CSS accepts both legacy hyphen forms (`.ss-btn-small`, `.ss-btn-danger`) and BEM modifiers (`.ss-btn--small`, `.ss-btn--danger`, `.ss-btn--large`, `.ss-btn--ghost`). Both work during migration. **Prefer BEM `--` modifiers for new markup.** A future `shared/ui/_button` partial should emit one canonical form.

---

## Priority 1 implementation status

These components have the highest copy/paste risk and should be standardized first.

| Component | Status | Current contract / target path | Notes |
| --------- | ------ | ------------------------------ | ----- |
| Button | CSS only | `.ss-btn`, `.ss-btn-primary`, `.ss-btn-secondary`, `.ss-btn-tertiary`, `.ss-btn-ghost`, `.ss-btn-danger` / `.ss-btn--danger`, `.ss-btn-small` / `.ss-btn--small`; planned `shared/ui/_button.html.erb` | Prefer `--` modifiers for new markup; thin partial should be next. |
| Link | CSS only | `.ss-link`, `.ss-link--quiet`, `.ss-link--danger`, `.ss-btn-link`; planned `shared/ui/_link.html.erb` | Keep normal navigation as links; do not over-buttonize. |
| Form | Partial exists | `shared/forms/_section`, `shared/forms/_field`, `shared/forms/_page_header`, `shared/forms/_errors`; CSS in `shelfstack.components.forms.css` | Existing `shared/forms/*` is the active form foundation. |
| Field | Partial exists | `shared/forms/_field`; `.ss-field`, `.ss-field--invalid` | Prefer the existing form partial instead of inventing `shared/ui/_field` now. |
| Input | CSS only | `.ss-input`, `.ss-input--search`, `.ss-input--money`, `.ss-input--compact` | Usually emitted through form helpers/partials. |
| Select / Native Select | CSS only | `.ss-select`, native `select` rules in `shelfstack.components.forms.css` | Enhanced select/combobox remains planned. |
| Alert | Mixed / legacy | Target: `.ss-alert`, `.ss-alert--info`, `.ss-alert--success`, `.ss-alert--warning`, `.ss-alert--error`; planned `shared/ui/_alert.html.erb` | Migrate form errors and old `.flash-alert` blocks toward inline alerts where appropriate. |
| Flash | Partial exists | `shared/feedback/_flash_region.html.erb`; `.ss-flash`, `.ss-flash--success`, `.ss-flash--warning`, `.ss-flash--error`, `.ss-flash--info` | Server-driven page-level results after navigation/redirect. |
| Toast | Partial exists / interaction shell | `shared/interaction/_toast`, `shared/interaction/_toast_region`; `.ss-toast-region`, `.ss-toast`, `.ss-toast--success`, `.ss-toast--warning`, `.ss-toast--error`, `.ss-toast--info` | Inline non-blocking feedback; auto-dismiss behavior lives in JS. |
| Access Notice | CSS only | `.ss-access-notice`, `.ss-access-notice__actions`; planned `shared/ui/_access_notice.html.erb` | Used for locked-out/permission-required pages. |
| Session Card | Mixed / legacy | `.ss-session-card` in `shelfstack.components.session.css`; `.ss-auth-box` still in legacy `shelfstack.css` | Auth layout (`layouts/auth`) is outside the global shell; see [app-shell-and-pos-shell.md](app-shell-and-pos-shell.md). |
| Card / Surface | CSS only | `.ss-card`, `.ss-card__header`, `.ss-card__body`, `.ss-surface`; planned `shared/ui/_card.html.erb` | Good candidate for thin partial after Button. |
| Page Header | Mixed / partial exists | Existing `shared/forms/_page_header`; target generic `shared/ui/_page_header.html.erb`; `.ss-page-header` | Current partial name is form-oriented; generic page header should be extracted later. |
| Dropdown Menu | Implemented | `.ss-dropdown`, `.ss-dropdown-trigger`, `.ss-dropdown-menu`, `.ss-dropdown-menu__item`; layout/user menu partials | Used by global user menu and POS actions. |
| Dialog | Partial exists | **Current:** `shared/interaction/_modal` + `.ss-modal*` (styles in legacy `shelfstack.css`). **Target:** `.ss-dialog*` in `shelfstack.components.overlays.css` after markup migration. | Phase 10 interaction shell. |
| Alert Dialog | CSS only / planned | `.ss-alert-dialog`, `.ss-alert-dialog--danger`; planned partial | Use for interruptive confirmation, post/void/destructive actions. |

---

## Feedback naming standard

Use these names for new work. Legacy selectors remain only for migration compatibility.

| Pattern | Meaning | Target classes | Current status |
| ------- | ------- | -------------- | -------------- |
| Flash | Page-level server result after navigation/redirect. | `.ss-flash-region`, `.ss-flash`, `.ss-flash--success`, `.ss-flash--warning`, `.ss-flash--error`, `.ss-flash--info` | Partial exists. Legacy `.flash-*` remains in auth/forms until migrated. |
| Toast | Lightweight inline/Turbo result without navigation. | `.ss-toast-region`, `.ss-toast`, `.ss-toast--success`, `.ss-toast--warning`, `.ss-toast--error`, `.ss-toast--info` | Interaction partials exist. |
| Alert | Persistent in-page condition near the affected workflow. | `.ss-alert`, `.ss-alert--info`, `.ss-alert--success`, `.ss-alert--warning`, `.ss-alert--error` | CSS exists; partial planned. |
| POS local alert | POS-workspace-specific state or warning. | `.ss-pos-alert`, `.ss-pos-alert--error` | Domain CSS exists; keep separate from global flash. |
| Field error | Field-specific validation feedback. | `.ss-field-error`, `.ss-field--invalid` | CSS/form partials exist; continue migration from generic flash blocks. |

Decision rule:

```text
Did the action navigate or redirect?          -> Flash
Did something small happen inline?           -> Toast
Is the condition still true on this screen?  -> Alert
Is it specific to POS workspace state?       -> POS local alert
Is it about one form field?                  -> Field error
```

---

## Known migration stragglers

These files still use legacy markup. Migrate them during Phase 10-E or when touching adjacent UI. Do not copy their patterns into new screens.

| File | Issue | Target |
| ---- | ----- | ------ |
| `app/views/layouts/auth.html.erb` | Inline `.flash.flash-*` blocks; no global shell | `flash_region` partial or session-scoped `.ss-alert*`; keep focused auth layout (no header/nav) |
| `app/views/shared/forms/_errors.html.erb` | `.flash.flash-alert` for validation summary | `.ss-alert--error` near the form, or per-field `.ss-field-error` / `.ss-field--invalid` |
| `app/views/shared/interaction/_modal.html.erb` | `.ss-modal*` markup and classes | eventual `.ss-dialog*` aligned with `shelfstack.components.overlays.css` |
| Monolithic `shelfstack.css` | POS workspace header, modal, and other rules not yet extracted | Move durable rules into `shelfstack.domain.*.css` or `shelfstack.components.*.css`; delete from legacy |

Shell contract enforcement: `test/system/app_shell_contract_test.rb` (global header, nav, body attributes, flash dismiss). Component class names are convention-only unless covered by a view or system test.

---

## Component catalog by layer

### Foundation

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Design Tokens | Implemented | `shelfstack.tokens.css`, `--color-*`, `--space-*`, `--layout-*`, `--z-*` |
| Typography | CSS only | `shelfstack.typography.css`, `.ss-heading`, `.ss-muted`, `.ss-eyebrow`, `.ss-tabular` |
| Link | CSS only | `shelfstack.components.links.css`, `.ss-link`, `.ss-btn-link` |
| Button | CSS only | `shelfstack.components.buttons.css`, `.ss-btn*` |
| Separator | Planned | `.ss-separator`, `.ss-separator--vertical` |
| Icon | Planned | `.ss-icon`, `.ss-icon--status` |
| Avatar | Planned | `.ss-avatar`, `.ss-avatar--initials` |

### App shell and layout

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| App Shell | Implemented | `layouts/application`, `layouts/pos`, `shelfstack_body_attributes` |
| Header | Implemented | `layouts/_header`, `.ss-header`, `.ss-header__search`, `.ss-header__actions` |
| Navigation Bar | Implemented | `layouts/_nav`, `.ss-nav`, `.ss-nav__item--active`, `.ss-nav__item--disabled` |
| Footer | Implemented | `layouts/_footer`, `.ss-footer`, `.ss-footer__version`, `.ss-footer__copyright`, `.ss-footer__actions` |
| Main Container | Implemented | `.ss-main`, `.ss-main--readable`, `.ss-main--items`, `.ss-main--wide`, `.ss-main--narrow` |
| Sidebar | CSS only | `.ss-sidebar`, `.ss-sidebar__section`, `.ss-sidebar__item` |
| Page Header | Mixed / partial exists | `.ss-page-header`; generic partial planned |
| Section Header | CSS only | `.ss-section-header`, `.ss-section-actions` |
| Card / Surface | CSS only | `.ss-card`, `.ss-surface` |
| Stack / Grid / Action Row | CSS only | `shelfstack.utilities.css`, `.ss-stack`, `.ss-grid`, `.ss-action-row` |

### Forms and inputs

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Form | Partial exists | `shared/forms/*`, `.ss-form`, `.ss-form-card` |
| Form Actions | CSS only | `.ss-form-actions`, `.ss-form-actions--end` |
| Field | Partial exists | `shared/forms/_field`, `.ss-field`, `.ss-field--invalid` |
| Fieldset / Label / Help Text | CSS only | `.ss-fieldset`, `.ss-label`, `.ss-help`, `.ss-hint` |
| Field Error | Mixed / legacy | `.ss-field-error`, `.ss-field--invalid`; migrate old `.flash-alert` error summaries |
| Input / Textarea / Select | CSS only | `.ss-input`, `.ss-textarea`, `.ss-select` |
| Checkbox / Radio / Toggle Groups | CSS only | `.ss-checkbox`, `.ss-radio-group`, `.ss-toggle-group` |
| Combobox / Lookup Panel | Planned | `.ss-combobox`, `.ss-lookup-panel` |
| Date Picker / File Input / Masked Input | Planned | `.ss-date-picker`, `.ss-file-input`, `.ss-input-mask` |

### Feedback, status, and messaging

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Alert | CSS only | `shelfstack.components.alerts.css`, `.ss-alert*` |
| Flash | Partial exists | `shared/feedback/_flash_region`, `.ss-flash*` |
| Toast | Partial exists / interaction shell | `shared/interaction/_toast*`, `.ss-toast*` |
| Empty State | CSS only | `.ss-empty-state`, `.ss-empty-state__actions` |
| Access Notice | CSS only | `.ss-access-notice`, `.ss-access-notice__actions` |
| Progress / Skeleton / Copy State | CSS only | `.ss-progress`, `.ss-skeleton`, `.ss-copy-button--copied` |
| Badge / Status Badge / Pill / Status Dot | CSS only | `.ss-badge`, `.ss-status-badge`, `.ss-pill`, `.ss-status-dot` |

### Dialogs, overlays, and menus

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Modal / Dialog | Partial exists | **Current:** `shared/interaction/_modal` + `.ss-modal*` (legacy CSS). **Target:** `.ss-dialog*` in `overlays.css` |
| Drawer / Sheet | Partial exists | `shared/interaction/_drawer`, `.ss-drawer`, `.ss-sheet` |
| Alert Dialog | CSS only | `.ss-alert-dialog`, `.ss-alert-dialog--danger` |
| Dropdown Menu | Implemented | `.ss-dropdown`, `.ss-dropdown-menu`, `.ss-dropdown-menu__item` |
| Popover / Hover Card / Context Menu | CSS only / planned | `.ss-popover`, `.ss-hover-card`, `.ss-context-menu` |
| Clipboard / Copy Button | CSS only | `.ss-copy-button`, `.ss-copy-button--copied` |

### Navigation and disclosure

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Breadcrumbs | CSS only | `.ss-breadcrumbs` |
| Tabs | CSS only | `.ss-tabs`, `.ss-tab`, `.ss-tab--active` |
| Accordion / Collapsible | CSS only | `.ss-accordion`, `.ss-collapsible-panel` |
| Pagination | CSS only | `.ss-pagination`, `.ss-pagination__summary` |
| Steps | CSS only | `.ss-steps`, `.ss-step`, `.ss-step--active` |
| Shortcut Key | CSS only | `.ss-shortcut-key`, `.ss-kbd` |
| Command Palette | Planned | `.ss-command`, `.ss-command-palette` |

### Data display

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Table | CSS only | `.ss-table`, `.ss-table--compact`, `.ss-table-scroll` |
| Data Table | CSS only | `.ss-data-table`, `.ss-data-table-toolbar`, `.ss-data-table-pagination` |
| Row Actions | CSS only | `.ss-row-actions`, `.ss-row-actions--dropdown` |
| Metric Card / Strip | CSS only | `.ss-metric-card`, `.ss-metric-strip`, `.ss-stat` |
| List / Timeline | CSS only | `.ss-list`, `.ss-list-row`, `.ss-timeline` |
| Summary / Definition List | CSS only | `.ss-summary`, `.ss-summary--compact` |
| Code Block | CSS only | `.ss-code`, `.ss-code-block` |
| Carousel | Planned | `.ss-carousel`, `.ss-carousel-item` |

### Domain-specific ShelfStack components

These are not generic UI-library components. They should usually live in `shelfstack.domain.*.css` and `shared/<domain>/` partials when extracted.

| Workspace | Components | Status |
| --------- | ---------- | ------ |
| Items/catalog | Item Hero, Variant Card, Availability Badge, Identifier List, Metadata Panel, Vendor Source Card | Mixed / domain CSS in progress |
| Inventory | Stock Summary, Stock Movement Row, Quantity Badge, Inventory Warning Panel | CSS only / domain CSS in progress |
| POS | POS Workspace, POS Command Bar, Cart Line, Tender Panel, Totals Panel, Receipt Template | Mixed / largest legacy overlap |
| Purchasing/orders | Document Header, Line Entry Table, Document Status Badge, Receiving Quantity Fields, Receipt Match Card, Vendor Cascade Timeline | CSS only / domain CSS in progress |
| Demand/customers | Demand Card, Allocation Card, Customer Profile Header, Activity Timeline, Stored Value Balance Card | CSS only / domain CSS in progress |
| Buybacks | Buyback Workspace, Buyback Line Card, Offer Summary | CSS only / domain CSS in progress |
| Print | Print Page, Print Header, Print Section, Receipt/Slip Layout | CSS only / print CSS separated |

---

## Phase 10-E alignment

[Phase 10-E](../roadmap/Phase-x10-comprehensive-ux-expansion.md) (consistency sweep) maps directly to this catalog:

1. Migrate [known migration stragglers](#known-migration-stragglers) (auth flash, form errors, modal naming).
2. Extract POS/header/cart CSS from `shelfstack.css` into `shelfstack.domain.pos.css`.
3. Add Priority 1 thin partials where copy/paste risk is highest: Button, Alert, generic Page Header.
4. Normalize views to documented feedback classes (`.ss-flash--*`, `.ss-alert--*`, `.ss-toast--*`).
5. Run [ux-review-checklist.md](ux-review-checklist.md) on touched workspaces; keep report view contracts stable.

---

## Recommended implementation priority

### Priority 1 — must formalize first

Button, Link, Form, Field, Input, Select / Native Select, Alert, Flash, Toast, Access Notice, Session Card, Card / Surface, Page Header, Dropdown Menu, Dialog, Alert Dialog.

### Priority 2 — high operational value

Data Table, Pagination, Empty State, Combobox, Lookup Panel, Sheet / Drawer, Tabs, Breadcrumbs, Status Badge, Metric Card, Document Header, Line Entry Table.

### Priority 3 — workflow polish

Steps, Progress, Skeleton, Tooltip, Collapsible, Accordion, Timeline, Switch, Toggle Group, File Input, Date Picker, Masked Input.

### Priority 4 — useful later

Avatar, Hover Card, Clipboard / Copy Button, Shortcut Key, Command Palette, Context Menu, Popover, Carousel, Theme Toggle.

---

## Next component spec pages

Do not write full spec pages for all components yet. Create focused specs only for Priority 1 components as they become implementation contracts.

**Location:** one file per component under `docs/design/components/`, for example `docs/design/components/button.md`. Keep `components.md` as the inventory and status index; link out to spec pages when they exist.

Use this template:

```text
## Button

Purpose:
Use for:
Do not use for:
Variants:
CSS:
Rails partial:
Accessibility requirements:
Examples:
Migration notes:
```

The next high-value spec pages are: Button, Alert, Flash/Toast, Page Header, Dropdown Menu, and Dialog/Alert Dialog.
