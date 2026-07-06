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

| Component | Status | Spec | Current contract / target path | Notes |
| --------- | ------ | ---- | ------------------------------ | ----- |
| Button | CSS only | [button.md](components/button.md) | `.ss-btn`, `.ss-btn-primary`, `.ss-btn-secondary`, `.ss-btn-tertiary`, `.ss-btn-ghost`, `.ss-btn-danger` / `.ss-btn--danger`, `.ss-btn-small` / `.ss-btn--small`; planned `shared/ui/_button.html.erb` | Prefer `--` modifiers for new markup; thin partial should be next. |
| Link | CSS only | [link.md](components/link.md) | `.ss-link`, `.ss-link--quiet`, `.ss-link--danger`, `.ss-btn-link`; planned `shared/ui/_link.html.erb` | Keep normal navigation as links; do not over-buttonize. |
| Form | Partial exists | [form.md](components/form.md) | `shared/forms/_section`, `shared/forms/_field`, `shared/forms/_page_header`, `shared/forms/_errors`; CSS in `shelfstack.components.forms.css` | Section partial emits `.ss-form-card`; inline `button_to` forms use `.ss-inline-form`. |
| Field | Partial exists | [field.md](components/field.md) | `shared/forms/_field`; `.ss-field`, `.ss-field--error`, `.ss-label`, `.ss-help`, `.ss-field-error`, `.ss-field-warning` | Partial uses `f`/`record`/`field` locals; warning vs error states documented. |
| Input | CSS only | [input.md](components/input.md) | `.ss-input` (base only); modifiers planned | Usually emitted through form helpers/partials. |
| Textarea | CSS only | [textarea.md](components/textarea.md) | `.ss-textarea` | Same forms CSS module as input. |
| Fieldset | CSS only | [fieldset.md](components/fieldset.md) | `.ss-fieldset`, `.ss-fieldset__legend`, `.ss-fieldset__description` | Semantic grouping; distinct from `.ss-form-card`. |
| Choice controls | CSS only | [choice-controls.md](components/choice-controls.md) | `.ss-checkbox-group`, `.ss-radio-group`, `.ss-choice-option`, etc. | Toggle/combobox hooks are scaffold only. |
| Select / Native Select | CSS only | [select-native-select.md](components/select-native-select.md) | `.ss-select` (base only); modifiers planned | Enhanced select/combobox remains planned. |
| Alert | Mixed / legacy | [alert.md](components/alert.md) | `.ss-alert`, `.ss-alert--*`; `.ss-attention-panel` | Attention panel partial for multi-issue warnings. |
| Flash | Partial exists | [flash.md](components/flash.md) | `shared/feedback/_flash_region`; see also [empty-state](components/empty-state.md) | Server-driven page-level results after navigation/redirect. |
| Toast | Partial exists / interaction shell | [toast.md](components/toast.md) | `shared/interaction/_toast*`; see also [empty-state](components/empty-state.md), [progress-skeleton](components/progress-skeleton.md) | `--info` via legacy bridge. |
| Access Notice | CSS only | [access-notice.md](components/access-notice.md) | `.ss-access-notice`, `__message`, `__actions`; planned `shared/ui/_access_notice.html.erb` | Used for locked-out/permission-required pages. |
| Session Card | Mixed / legacy | [session-card.md](components/session-card.md) | `.ss-session-card` in `shelfstack.components.session.css`; `.ss-auth-box` still in legacy `shelfstack.css` | Auth layout (`layouts/auth`) is outside the global shell; see [app-shell-and-pos-shell.md](app-shell-and-pos-shell.md). |
| Card / Surface | CSS only | [card-surface.md](components/card-surface.md) | `.ss-card*`, `.ss-surface*`, `.ss-summary*`, `.ss-sidebar-card`, `.ss-card-grid` | Summary and sidebar variants documented in card spec. |
| Page Header | Mixed / partial exists | [page-header.md](components/page-header.md) | Existing `shared/forms/_page_header`; target generic `shared/ui/_page_header.html.erb`; `.ss-page-header` | Title is plain `<h1>`, not `__title` class. |
| Dropdown Menu | Implemented | [dropdown-menu.md](components/dropdown-menu.md) | `.ss-dropdown`, `.ss-dropdown-trigger`, `.ss-dropdown-menu`, `.ss-dropdown-menu__item`; layout/user menu partials | Used by global user menu and POS actions. |
| Dialog | Partial exists | [dialog.md](components/dialog.md) | **Current:** `shared/interaction/_modal` + `.ss-modal*`. **Target:** `.ss-dialog*` | Phase 10 interaction shell. |
| Drawer | Partial exists | [drawer.md](components/drawer.md) | `shared/interaction/_drawer` + `.ss-drawer*` (legacy CSS) | Item variant ops, POS session drawer. |
| Sheet / Popover | CSS only (scaffold) | [sheet-popover.md](components/sheet-popover.md) | `.ss-sheet*`, `.ss-popover*`, `.ss-hover-card*`, `.ss-context-menu` | Tokens only; use drawer/dropdown for new work. |
| Alert Dialog | CSS only / planned | [alert-dialog.md](components/alert-dialog.md) | `.ss-alert-dialog`, `.ss-alert-dialog--danger`; planned partial | Use for interruptive confirmation. |

---

## Priority 2 implementation status

These components are already represented in modular CSS and now have dedicated implementation-oriented specs.

| Component | Status | Spec | Current contract / target path | Notes |
| --------- | ------ | ---- | ------------------------------ | ----- |
| Badges / Status Badges / Pills | CSS only | [badges.md](components/badges.md) | `.ss-badge`, `.ss-status-badge`, `.ss-pill`, `.ss-status-dot` | Use `.status-*` only for domain/business state. |
| Tables | CSS only | [tables.md](components/tables.md) | `.ss-table`, `.ss-table-scroll`, `.ss-table--compact`, `.ss-table-actions` | Modular row actions use `.ss-table-actions`; legacy `.ss-row-actions` still exists in old CSS. |
| Data Tables | CSS only | [data-tables.md](components/data-tables.md) | `.ss-data-table`, `.ss-data-table__toolbar`, `.ss-data-table__filters`, `.ss-data-table__pagination`, `.ss-filter-bar` | Use BEM element names; non-BEM data-table names are not defined. |
| Navigation | CSS only / app nav implemented | [navigation.md](components/navigation.md) | `.ss-nav`, `.ss-sidebar`, `.ss-breadcrumbs`, `.ss-tabs`, `.ss-steps`, `.ss-kbd` | Global nav lives in `layouts/_nav`; local nav uses sidebar/tabs/steps. |
| Metrics | CSS only / domain partials exist | [metrics.md](components/metrics.md) | `.ss-metric-card`, `.ss-metric-strip`, `.ss-stat` | Reports/orders have partials; generic UI partial deferred. |
| Lists / Timelines | CSS only | [lists.md](components/lists.md) | `.ss-list`, `.ss-list-row`, `.ss-timeline` | Use lists for small related collections, not comparable tabular data. |
| Disclosure | CSS only | [disclosure.md](components/disclosure.md) | `.ss-collapsible-panel`, `.ss-accordion`, `.ss-details` | Prefer native `<details>` where possible. |
| Appearance Switcher | Partial exists / CSS only styling | [appearance.md](components/appearance.md) | `shared/ui/_appearance_switcher`; `.ss-appearance-switcher*` | User-facing view-mode control. |
| Layout Shell | Implemented | [layout-shell.md](components/layout-shell.md) | `layouts/application`, `layouts/pos`, `.ss-header`, `.ss-main`, `.ss-footer` | Detailed app shell spec; broader shell rules remain in `app-shell-and-pos-shell.md`. |

---

## Priority 3 foundation and interaction-shell gaps

These are smaller but important contracts for primitives, legacy interaction-shell bridges, and planned patterns.

| Component | Status | Spec | Current contract / target path | Notes |
| --------- | ------ | ---- | ------------------------------ | ----- |
| Typography | CSS only | [typography.md](components/typography.md) | `shelfstack.typography.css`, `h1`–`h4`, `.ss-muted`, `.ss-eyebrow`, `.ss-tabular`, `.ss-code-block` | Semantic headings first; classes refine presentation. |
| Utilities | CSS only | [utilities.md](components/utilities.md) | `shelfstack.utilities.css`, `.ss-stack`, `.ss-grid`, `.ss-action-row`, `.ss-sr-only`, `.is-*` | Tiny helpers only; do not create undocumented components with utilities. |
| Expanded Row | Partial exists / legacy CSS | [expanded-row.md](components/expanded-row.md) | `shared/interaction/_expanded_row`; `.ss-expand-row*` in legacy CSS | Interaction-shell bridge; extraction target depends on generic vs domain use. |
| Shortcut Strip | Partial exists / legacy CSS | [shortcut-strip.md](components/shortcut-strip.md) | `shared/interaction/_shortcut_strip`; `.ss-shortcut-strip*` in legacy CSS | Visible shortcut legend; shortcut behavior lives elsewhere. |
| Filter Chip | Planned / missing modular CSS | [filter-chip.md](components/filter-chip.md) | Target `.ss-filter-chip*`; CSS not yet implemented | Do not use in new markup until CSS exists. |
| Design Tokens | Implemented | [../tokens.md](tokens.md) | `shelfstack.tokens.css`, `--color-*`, `--space-*`, `--layout-*`, `--z-*` | Tokens are foundation docs, not component docs. |

---

## Feedback naming standard

Use these names for new work. Legacy selectors remain only for migration compatibility.

| Pattern | Meaning | Target classes | Current status |
| ------- | ------- | -------------- | -------------- |
| Flash | Page-level server result after navigation/redirect. | `.ss-flash-region`, `.ss-flash`, `.ss-flash--success`, `.ss-flash--warning`, `.ss-flash--error`, `.ss-flash--info` | Partial exists. Legacy `.flash-*` remains in auth/forms until migrated. |
| Toast | Lightweight inline/Turbo result without navigation. | `.ss-toast-region`, `.ss-toast`, `.ss-toast--success`, `.ss-toast--warning`, `.ss-toast--error`, `.ss-toast--info` | Interaction partials exist. |
| Alert | Persistent in-page condition near the affected workflow. | `.ss-alert`, `.ss-alert--info`, `.ss-alert--success`, `.ss-alert--warning`, `.ss-alert--error` | CSS exists; partial planned. |
| POS local alert | POS-workspace-specific state or warning. | `.ss-pos-alert`, `.ss-pos-alert--error` | Domain CSS exists; keep separate from global flash. |
| Field error | Field-specific validation feedback. | `.ss-field-error`, `.ss-field--error` | CSS/form partials exist; continue migration from generic flash blocks. |

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
| `app/views/shared/forms/_errors.html.erb` | `.flash.flash-alert` for validation summary | `.ss-alert--error` near the form, or per-field `.ss-field-error` / `.ss-field--error` |
| `app/views/shared/interaction/_modal.html.erb` | `.ss-modal*` markup and classes | eventual `.ss-dialog*` aligned with `shelfstack.components.overlays.css` |
| `app/views/shared/interaction/_expanded_row.html.erb` | Partial exists but styling is still legacy | Extract generic structure into table/disclosure CSS or keep domain-specific rules in POS/orders CSS |
| `app/views/shared/interaction/_shortcut_strip.html.erb` | Partial exists but styling is still legacy | Extract generic strip styling into navigation/interaction CSS when usage stabilizes |
| Monolithic `shelfstack.css` | POS workspace header, modal, expanded row, shortcut strip, and other rules not yet extracted | Move durable rules into `shelfstack.domain.*.css` or `shelfstack.components.*.css`; delete from legacy |

Shell contract enforcement: `test/system/app_shell_contract_test.rb` (global header, nav, body attributes, flash dismiss). Component class names are convention-only unless covered by a view or system test.

---

## Component catalog by layer

### Foundation

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Design Tokens | Implemented | [tokens.md](tokens.md), `shelfstack.tokens.css`, `--color-*`, `--space-*`, `--layout-*`, `--z-*` |
| Typography | CSS only | [components/typography.md](components/typography.md), `shelfstack.typography.css`, `h1`–`h4`, `.ss-heading--page`, `.ss-page-title`, `.ss-muted`, `.ss-eyebrow`, `.ss-tabular` |
| Utilities | CSS only | [components/utilities.md](components/utilities.md), `shelfstack.utilities.css`, `.ss-stack`, `.ss-grid`, `.ss-action-row`, `.ss-sr-only`, `.is-*` |
| Link | CSS only | `shelfstack.components.links.css`, `.ss-link`, `.ss-btn-link`; [link.md](components/link.md) |
| Button | CSS only | `shelfstack.components.buttons.css`, `.ss-btn*`; [button.md](components/button.md) |
| Separator | Planned | `.ss-separator`, `.ss-separator--vertical` |
| Icon | Planned | `.ss-icon`, `.ss-icon--status` |
| Avatar | Planned | `.ss-avatar`, `.ss-avatar--initials` |

### App shell and layout

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Layout Shell | Implemented | [layout-shell.md](components/layout-shell.md); `layouts/application`, `layouts/pos`, `shelfstack_body_attributes` |
| Header | Implemented | [layout-shell.md](components/layout-shell.md); `layouts/_header`, `.ss-header`, `.ss-header__search`, `.ss-header__actions` |
| Navigation Bar | Implemented | [navigation.md](components/navigation.md); `layouts/_nav`, `.ss-nav`, `.ss-nav__item--active`, `.ss-nav__item--disabled` |
| Footer | Implemented | [layout-shell.md](components/layout-shell.md); `layouts/_footer`, `.ss-footer`, `.ss-footer__version`, `.ss-footer__copyright`, `.ss-footer__actions` |
| Main Container | Implemented | [layout-shell.md](components/layout-shell.md); `.ss-main`, `.ss-main--readable`, `.ss-main--items`, `.ss-main--wide`, `.ss-main--narrow` |
| Appearance Switcher | Partial exists | [appearance.md](components/appearance.md); `shared/ui/_appearance_switcher`, `.ss-appearance-switcher*` |
| Sidebar | CSS only | [navigation.md](components/navigation.md); `.ss-sidebar`, `.ss-sidebar__section`, `.ss-sidebar__item` |
| Page Header | Mixed / partial exists | [page-header.md](components/page-header.md); `.ss-page-header`; generic partial planned |
| Section Header | CSS only | [layout-shell.md](components/layout-shell.md); `.ss-section-header`, `.ss-section-actions` |
| Card / Surface | CSS only | [card-surface.md](components/card-surface.md) — includes summary, sidebar-card, card-grid |
| Stack / Grid / Action Row | CSS only | [utilities.md](components/utilities.md), `.ss-stack`, `.ss-grid`, `.ss-action-row` |

### Forms and inputs

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Form | Partial exists | `shared/forms/*`, `.ss-form`, `.ss-form-card`; [form.md](components/form.md) |
| Form Actions | CSS only | `.ss-form-actions`, `.ss-form-actions--end`; [form.md](components/form.md) |
| Inline Form | CSS only | `.ss-inline-form`; [form.md](components/form.md) |
| Field | Partial exists | `shared/forms/_field`; [field.md](components/field.md) |
| Fieldset / Label / Help Text | CSS only | `.ss-fieldset`, `.ss-label`, `.ss-help`; [fieldset.md](components/fieldset.md), [field.md](components/field.md) |
| Field Error / Warning | Mixed / legacy | `.ss-field-error`, `.ss-field-warning`, `.ss-field--error`; [field.md](components/field.md) |
| Input / Textarea / Select | CSS only | [input.md](components/input.md), [textarea.md](components/textarea.md), [select-native-select.md](components/select-native-select.md) |
| Checkbox / Radio / Toggle Groups | CSS only | [choice-controls.md](components/choice-controls.md) |
| Combobox / Lookup Panel | Planned | `.ss-combobox`, `.ss-lookup-panel` |
| Date Picker / File Input / Masked Input | Planned | `.ss-date-picker`, `.ss-file-input`, `.ss-input-mask` |

### Feedback, status, and messaging

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Alert | CSS only | [alert.md](components/alert.md), `.ss-alert*`, `.ss-attention-panel` |
| Flash | Partial exists | [flash.md](components/flash.md), `shared/feedback/_flash_region` |
| Toast | Partial exists | [toast.md](components/toast.md), `shared/interaction/_toast*` |
| Empty State | Partial exists | [empty-state.md](components/empty-state.md), `reports/shared/_empty_state` |
| Access Notice | CSS only | [access-notice.md](components/access-notice.md) |
| Progress / Skeleton / Copy State | CSS only (scaffold) | [progress-skeleton.md](components/progress-skeleton.md) |
| Badge / Status Badge / Pill / Status Dot | CSS only | [badges.md](components/badges.md); `.ss-badge`, `.ss-status-badge`, `.ss-pill`, `.ss-status-dot` |
| Copy Button | CSS only (state only) | [progress-skeleton.md](components/progress-skeleton.md), `.ss-copy-button--copied` only | Base copy-button styling is not a full component contract yet. |

### Dialogs, overlays, and menus

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Modal / Dialog | Partial exists | [dialog.md](components/dialog.md) — current `.ss-modal*`, target `.ss-dialog*` |
| Drawer / Sheet | Partial exists / scaffold | [drawer.md](components/drawer.md), [sheet-popover.md](components/sheet-popover.md) |
| Expanded Row | Partial exists / legacy CSS | [expanded-row.md](components/expanded-row.md), `shared/interaction/_expanded_row`, `.ss-expand-row*` |
| Alert Dialog | CSS only | [alert-dialog.md](components/alert-dialog.md) |
| Dropdown Menu | Implemented | [dropdown-menu.md](components/dropdown-menu.md) |
| Popover / Hover Card / Context Menu | CSS only (scaffold) | [sheet-popover.md](components/sheet-popover.md) |
| Clipboard / Copy Button | CSS only (state only) | `.ss-copy-button--copied`; see [progress-skeleton.md](components/progress-skeleton.md) |

### Navigation and disclosure

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Navigation | CSS only / app nav implemented | [navigation.md](components/navigation.md), `.ss-nav`, `.ss-sidebar`, `.ss-breadcrumbs`, `.ss-tabs`, `.ss-steps`, `.ss-kbd` |
| Breadcrumbs | CSS only | [navigation.md](components/navigation.md), `.ss-breadcrumbs` |
| Tabs | CSS only | [navigation.md](components/navigation.md), `.ss-tabs`, `.ss-tab`, `.ss-tab--active` |
| Accordion / Collapsible / Details | CSS only | [disclosure.md](components/disclosure.md), `.ss-accordion`, `.ss-collapsible-panel`, `.ss-details` |
| Pagination | CSS only | [data-tables.md](components/data-tables.md), `.ss-pagination`, `.ss-pagination__summary` |
| Steps | CSS only | [navigation.md](components/navigation.md), `.ss-steps`, `.ss-step`, `.ss-step--active` |
| Shortcut Key | CSS only | [navigation.md](components/navigation.md), `.ss-shortcut-key`, `.ss-kbd` |
| Shortcut Strip | Partial exists / legacy CSS | [shortcut-strip.md](components/shortcut-strip.md), `shared/interaction/_shortcut_strip`, `.ss-shortcut-strip*` |
| Command Palette | Planned | `.ss-command`, `.ss-command-palette` |

### Data display

| Component | Status | Target classes / files |
| --------- | ------ | ---------------------- |
| Table | CSS only | [tables.md](components/tables.md), `.ss-table`, `.ss-table--compact`, `.ss-table-scroll` |
| Data Table | CSS only | [data-tables.md](components/data-tables.md), `.ss-data-table`, `.ss-data-table__toolbar`, `.ss-data-table__filters`, `.ss-data-table__pagination`, `.ss-filter-bar` |
| Filter Chip | Planned / missing modular CSS | [filter-chip.md](components/filter-chip.md), target `.ss-filter-chip*` | Do not add new uses until CSS exists. |
| Row Actions | Mixed / legacy | [tables.md](components/tables.md), modular `.ss-table-actions`; legacy `.ss-row-actions`; `.ss-row-actions--dropdown` not defined |
| Metric Card / Strip | CSS only | [metrics.md](components/metrics.md), `.ss-metric-card`, `.ss-metric-strip`, `.ss-stat` |
| List / Timeline | CSS only | [lists.md](components/lists.md), `.ss-list`, `.ss-list-row`, `.ss-timeline` |
| Summary / Definition List | CSS only | `.ss-summary`, `.ss-summary--two-column`, `.ss-summary__label`, `.ss-summary__value`; [card-surface.md](components/card-surface.md) |
| Code Block | CSS only | `.ss-code`, `.ss-code-block`; [typography.md](components/typography.md) |
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

1. Migrate [known migration stragglers](#known-migration-stragglers) (auth flash, form errors, modal naming, expanded row, shortcut strip).
2. Extract POS/header/cart CSS from `shelfstack.css` into `shelfstack.domain.pos.css`.
3. Add Priority 1 thin partials where copy/paste risk is highest: Button, Alert, generic Page Header.
4. Normalize views to documented feedback classes (`.ss-flash--*`, `.ss-alert--*`, `.ss-toast--*`).
5. Add modular CSS before using planned `.ss-filter-chip*` classes.
6. Run [ux-review-checklist.md](ux-review-checklist.md) on touched workspaces; keep report view contracts stable.

---

## Recommended implementation priority

### Priority 1 — must formalize first

Button, Link, Form, Field, Input, Select / Native Select, Alert, Flash, Toast, Access Notice, Session Card, Card / Surface, Page Header, Dropdown Menu, Dialog, Alert Dialog.

### Priority 2 — high operational value

Data Table, Pagination, Empty State, Combobox, Lookup Panel, Sheet / Drawer, Tabs, Breadcrumbs, Status Badge, Metric Card, Document Header, Line Entry Table, Table, Navigation, Lists, Disclosure, Appearance Switcher, Layout Shell.

### Priority 3 — foundation, workflow polish, and interaction-shell bridges

Typography, Utilities, Expanded Row, Shortcut Strip, Filter Chip, Tokens, Steps, Progress, Skeleton, Tooltip, Collapsible, Accordion, Timeline, Switch, Toggle Group, File Input, Date Picker, Masked Input.

### Priority 4 — useful later

Avatar, Hover Card, Clipboard / Copy Button, Shortcut Key, Command Palette, Context Menu, Popover, Carousel, Theme Toggle.

---

## Component spec index

### Priority 1 — core contract

| Spec | File |
| ---- | ---- |
| Button | [components/button.md](components/button.md) |
| Link | [components/link.md](components/link.md) |
| Form | [components/form.md](components/form.md) |
| Field | [components/field.md](components/field.md) |
| Input | [components/input.md](components/input.md) |
| Select | [components/select-native-select.md](components/select-native-select.md) |
| Alert | [components/alert.md](components/alert.md) |
| Flash | [components/flash.md](components/flash.md) |
| Toast | [components/toast.md](components/toast.md) |
| Access Notice | [components/access-notice.md](components/access-notice.md) |
| Session Card | [components/session-card.md](components/session-card.md) |
| Card / Surface | [components/card-surface.md](components/card-surface.md) |
| Page Header | [components/page-header.md](components/page-header.md) |
| Dropdown Menu | [components/dropdown-menu.md](components/dropdown-menu.md) |
| Dialog | [components/dialog.md](components/dialog.md) |
| Alert Dialog | [components/alert-dialog.md](components/alert-dialog.md) |

### Forms module (`shelfstack.components.forms.css`)

| Spec | File |
| ---- | ---- |
| Textarea | [components/textarea.md](components/textarea.md) |
| Fieldset | [components/fieldset.md](components/fieldset.md) |
| Checkbox / Radio / Choice | [components/choice-controls.md](components/choice-controls.md) |

### Feedback/status module

| Spec | File |
| ---- | ---- |
| Badges / Status Badges / Pills | [components/badges.md](components/badges.md) |
| Empty State | [components/empty-state.md](components/empty-state.md) |
| Progress / Skeleton / Copy State | [components/progress-skeleton.md](components/progress-skeleton.md) |

### Overlays and interaction shell

| Spec | File |
| ---- | ---- |
| Drawer | [components/drawer.md](components/drawer.md) |
| Sheet / Popover / Hover / Context | [components/sheet-popover.md](components/sheet-popover.md) |
| Expanded Row | [components/expanded-row.md](components/expanded-row.md) |

### Layout, navigation, and shell

| Spec | File |
| ---- | ---- |
| Layout Shell | [components/layout-shell.md](components/layout-shell.md) |
| Navigation | [components/navigation.md](components/navigation.md) |
| Disclosure | [components/disclosure.md](components/disclosure.md) |
| Appearance Switcher | [components/appearance.md](components/appearance.md) |
| Shortcut Strip | [components/shortcut-strip.md](components/shortcut-strip.md) |

### Foundation

| Spec | File |
| ---- | ---- |
| Typography | [components/typography.md](components/typography.md) |
| Utilities | [components/utilities.md](components/utilities.md) |
| Tokens | [tokens.md](tokens.md) |

### Data display

| Spec | File |
| ---- | ---- |
| Tables | [components/tables.md](components/tables.md) |
| Data Tables | [components/data-tables.md](components/data-tables.md) |
| Metrics | [components/metrics.md](components/metrics.md) |
| Lists / Timelines | [components/lists.md](components/lists.md) |
| Filter Chip | [components/filter-chip.md](components/filter-chip.md) |

**Location:** one file per component under `docs/design/components/`. Keep `components.md` as the inventory and status index.

Use this template for new specs:

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
