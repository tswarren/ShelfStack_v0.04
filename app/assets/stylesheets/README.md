# ShelfStack CSS and Component Library

ShelfStack uses a native `.ss-*` CSS component system for app-wide visual consistency. The current structure introduces the definitive component-library files while preserving the existing production visual layer through `shelfstack.legacy.css` during migration.

## Import order

`application.css` should remain a thin manifest in this order:

1. Foundation tokens and appearance profiles
2. Base/global styles and typography
3. Layout and utilities
4. Generic UI components
5. Domain components
6. Print styles
7. Temporary legacy compatibility bridge
8. Temporary post-legacy migration overrides

```css
@import "shelfstack.tokens.css";
@import "shelfstack.typefaces.css";
@import "shelfstack.density.css";
@import "shelfstack.color-modes.css";
@import "shelfstack.base.css";
@import "shelfstack.typography.css";

@import "shelfstack.layout.css";
@import "shelfstack.utilities.css";

@import "shelfstack.components.buttons.css";
@import "shelfstack.components.links.css";
@import "shelfstack.components.forms.css";
@import "shelfstack.components.cards.css";
@import "shelfstack.components.alerts.css";
@import "shelfstack.components.badges.css";
@import "shelfstack.components.tables.css";
@import "shelfstack.components.data-tables.css";
@import "shelfstack.components.navigation.css";
@import "shelfstack.components.overlays.css";
@import "shelfstack.components.feedback.css";
@import "shelfstack.components.disclosure.css";
@import "shelfstack.components.metrics.css";
@import "shelfstack.components.lists.css";
@import "shelfstack.components.session.css";
@import "shelfstack.components.access.css";
@import "shelfstack.components.appearance.css";

@import "shelfstack.domain.items.css";
@import "shelfstack.domain.inventory.css";
@import "shelfstack.domain.orders.css";
@import "shelfstack.domain.demand.css";
@import "shelfstack.domain.customers.css";
@import "shelfstack.domain.buybacks.css";
@import "shelfstack.domain.pos.css";
@import "shelfstack.domain.reports.css";
@import "shelfstack.domain.setup.css";

@import "shelfstack.print.css";
@import "shelfstack.legacy.css";
@import "shelfstack.migration-overrides.css";
```

## Layout width model

ShelfStack uses a wide default app canvas because most screens combine operational content, side context, action rows, filters, summary cards, and tables.

The guiding distinction is:

```text
Page canvas width != readable content width
```

Default page content should have room for operational layouts. Text-heavy content, simple forms, and focused workflows should be constrained inside that canvas.

| Token | Value | Purpose |
| --- | ---: | --- |
| `--layout-narrow` | `42rem` | Focused forms, login/unlock/session/account cards |
| `--layout-readable` | `1180px` | Readable reports, text-heavy pages, simple detail pages |
| `--layout-standard` | `1440px` | Default application canvas for operational screens |
| `--layout-max` | `var(--layout-standard)` | Backward-compatible default alias |
| `--layout-item-detail` | `var(--layout-standard)` | Semantic alias for item detail pages |
| `--layout-wide` | `1500px` | POS, receiving, inventory grids, very dense workspaces |

Main layout classes:

| Class | Width |
| --- | --- |
| `.ss-main` | `--layout-standard` |
| `.ss-main--readable` | `--layout-readable` |
| `.ss-main--narrow` | `--layout-narrow` |
| `.ss-main--items` | `--layout-item-detail` |
| `.ss-main--wide` | `--layout-wide` |
| `.ss-main--full` | no max width |

Use internal constraints for content that should not stretch:

```css
.ss-readable {
  max-width: var(--layout-readable);
}

.ss-text-measure {
  max-width: 70ch;
}
```

## Naming conventions

Use ShelfStack-native class names:

```css
.ss-component
.ss-component__element
.ss-component--variant
```

Use `.is-*` for temporary UI state:

```css
.is-active
.is-disabled
.is-loading
.is-selected
.is-expanded
```

Use `.status-*` only for domain/business statuses:

```css
.status-draft
.status-posted
.status-cancelled
.status-active
.status-inactive
```

## Appearance model

Appearance is separated into independent profiles:

| Concern | Attribute | Example |
| --- | --- | --- |
| Typeface | `data-ss-typeface` | `system`, `atkinson`, `lexend`, `compact` |
| Density | `data-ss-density` | `comfortable`, `standard`, `compact` |
| Color mode | `data-ss-color-mode` | `light`, `dark` |

Recommended user-facing modes:

| View mode | Typeface | Density |
| --- | --- | --- |
| Standard View | `atkinson` or `system` | `standard` |
| Accessible View | `lexend` | `comfortable` |
| Compact View | `system` or future compact font | `compact` |

## File responsibilities

### Foundation

| File | Responsibility |
| --- | --- |
| `shelfstack.tokens.css` | Design tokens only: colors, surfaces, radii, shadows, layout widths, spacing, typography, density, z-index |
| `shelfstack.typefaces.css` | Typeface profiles and `--font-ui` assignments |
| `shelfstack.density.css` | Comfortable, standard, and compact spacing/line-height profiles |
| `shelfstack.color-modes.css` | Light/dark color-mode profile hooks |
| `shelfstack.base.css` | Global element defaults |
| `shelfstack.typography.css` | Headings, muted text, labels, numeric utilities, code blocks |

### Layout

| File | Responsibility |
| --- | --- |
| `shelfstack.layout.css` | App shell, header, main, footer, page headers, section headers, main width tiers |
| `shelfstack.utilities.css` | Small layout/state helpers such as stack, grid, action row, hidden, selected |

### Generic components

| File | Responsibility |
| --- | --- |
| `shelfstack.components.buttons.css` | Button hierarchy and button-like controls |
| `shelfstack.components.links.css` | Link variants, back links, skip links |
| `shelfstack.components.forms.css` | Forms, fields, fieldsets, inputs, select, choices, filters, combobox shells |
| `shelfstack.components.cards.css` | Cards, surfaces, summaries, card grids |
| `shelfstack.components.alerts.css` | Inline alerts and attention panels |
| `shelfstack.components.badges.css` | Badges, status badges, pills, status dots |
| `shelfstack.components.tables.css` | Basic tables, compact/dense/sticky tables, tree rows |
| `shelfstack.components.data-tables.css` | Filter bars, table toolbars, pagination, bulk action shells |
| `shelfstack.components.navigation.css` | Nav, sidebar, breadcrumbs, tabs, steps, shortcut keys |
| `shelfstack.components.overlays.css` | Dialogs, alert dialogs, sheets, drawers, dropdowns, popovers, hover cards |
| `shelfstack.components.feedback.css` | Flash region, toast region, empty states, progress, skeletons, copy button state |
| `shelfstack.components.disclosure.css` | Collapsible panels, accordions, details sections |
| `shelfstack.components.metrics.css` | Metric strips, metric cards, stats |
| `shelfstack.components.lists.css` | List rows and timelines |
| `shelfstack.components.session.css` | Login, unlock, PIN/password, workstation assignment surfaces |
| `shelfstack.components.access.css` | Locked-out/access-required notices |
| `shelfstack.components.appearance.css` | Appearance view-mode switcher |

### Domain components

| File | Responsibility |
| --- | --- |
| `shelfstack.domain.items.css` | Catalog/item/product/variant detail components |
| `shelfstack.domain.inventory.css` | Stock summary, quantity badges, inventory warnings, movement rows |
| `shelfstack.domain.orders.css` | PO/receipt/RTV/document headers, purchasing tables, receiving fields, vendor cascade |
| `shelfstack.domain.demand.css` | Demand cards, allocation cards, customer request states |
| `shelfstack.domain.customers.css` | Customer headers, activity, stored value, balances |
| `shelfstack.domain.buybacks.css` | Buyback workspace, buyback lines, offer summaries |
| `shelfstack.domain.pos.css` | Register/POS workspace, cart, tender, totals, receipt actions |
| `shelfstack.domain.reports.css` | Report bodies, sections, notes, summaries, totals |
| `shelfstack.domain.setup.css` | Admin/setup cards, settings rows, permission matrices |

### Output and migration

| File | Responsibility |
| --- | --- |
| `shelfstack.print.css` | Print-only and print-optimized styling |
| `shelfstack.legacy.css` | Temporary bridge importing the old CSS/preview stack |
| `shelfstack.migration-overrides.css` | Temporary post-legacy overrides while preview CSS remains imported |
| `shelfstack.experimental.css` | Branch/local experiments only; not imported by `application.css` |

## Button rules

Use explicit button variants in new markup:

```erb
<%= button_tag "Save", class: "ss-btn ss-btn-primary" %>
<%= link_to "Cancel", path, class: "ss-btn ss-btn-tertiary" %>
```

Do not rely on action-group order to determine the primary action.

| Variant | Use |
| --- | --- |
| `.ss-btn-primary` | One main action per page/form/section |
| `.ss-btn-secondary` | Important alternate action |
| `.ss-btn-tertiary` | Cancel, back, close, logout, lock session |
| `.ss-btn-danger` | Destructive or irreversible action |
| `.ss-btn-link` | Low-emphasis inline action |

## Migration rules

1. Do not add new feature CSS to `shelfstack.legacy.css`.
2. Move stable rules from old preview files into definitive component/domain files.
3. Prefer generic component classes before creating domain-specific classes.
4. Use domain files only when the component is meaningfully tied to ShelfStack workflows.
5. Keep `shelfstack.migration-overrides.css` temporary; move durable rules into definitive files when the legacy bridge is removed.
6. Remove `shelfstack.legacy.css` and `shelfstack.migration-overrides.css` imports after views are fully standardized.

## Preview files

The old preview files remain as source/reference material during migration:

- `shelfstack.visual-preview.css`
- `shelfstack.ux-improvements.css`
- `shelfstack.lexend.css`
- `shelfstack.lexend-density.css`
- `shelfstack.preview-atkinson.css`
- `shelfstack.preview-lexend.css`

They should not receive new production styles.
