# Design Tokens

| Field | Value |
| ----- | ----- |
| Status | Implemented |
| CSS | `app/assets/stylesheets/shelfstack.tokens.css` |
| Related CSS | `shelfstack.typefaces.css`, `shelfstack.density.css`, `shelfstack.color-modes.css` |
| Related docs | `components.md`, `layout-width-model.md`, `app-shell-and-pos-shell.md` |

Design tokens are ShelfStack’s shared CSS variables for color, spacing, typography, density, radius, shadow, layout width, and z-index.

Tokens are not components. They are the primitive values that components and domain styles consume.

---

## Purpose

Use tokens to keep app styling consistent and maintainable.

```text
Components should consume tokens.
Views should rarely reference tokens directly.
Domain CSS may consume tokens when composing workflow-specific UI.
```

---

## Token families

### Base colors and surfaces

```css
--color-base-100
--color-base-150
--color-base-200
--color-base-300
--color-base-content
--color-muted
--color-muted-subtle
--color-surface
--color-surface-glass
--color-surface-muted
```

### Brand and action colors

```css
--color-primary
--color-primary-hover
--color-primary-soft
--color-primary-content
--color-secondary
--color-secondary-hover
--color-secondary-soft
--color-secondary-content
--color-brand-gold
--color-brand-gold-soft
```

### Semantic colors

```css
--color-info
--color-info-content
--color-success
--color-success-content
--color-warning
--color-warning-content
--color-error
--color-error-content
--color-neutral
--color-neutral-content
```

Use semantic tokens through component classes whenever possible: alerts, flashes, badges, status badges, and field states.

### Radius

```css
--radius-sm
--radius-md
--radius-lg
--radius-pill
--radius-selector
--radius-field
--radius-box
```

### Border and shadow

```css
--border
--shadow-sm
--shadow-md
--shadow-lg
```

### Layout widths

```css
--layout-narrow
--layout-readable
--layout-standard
--layout-max
--layout-item-detail
--layout-wide
```

These drive `.ss-main`, width variants, and the layout width model.

### Spacing

```css
--space-1
--space-2
--space-3
--space-4
--space-5
--space-6
--gap-ui
--gap-section
```

### Typography

```css
--font-ui
--font-mono
```

Typeface profiles can override `--font-ui` through body attributes and typeface CSS.

### Density and padding

```css
--line-body
--line-ui
--line-compact
--pad-ui-y
--pad-ui-x
--pad-compact-y
--pad-compact-x
--pad-card
--pad-card-sm
--pad-card-lg
```

These support Standard, Accessible, and Compact view modes.

### Layering

```css
--z-header
--z-dropdown
--z-toast
--z-dialog
```

Use for global stacking order.

---

## Rules for new CSS

1. Prefer existing tokens before introducing new values.
2. Add new tokens only when a value is reused across components or domains.
3. Do not reference raw color values in views.
4. Component CSS should use tokens, not hardcoded brand/semantic values.
5. Domain CSS may use tokens when composing workflow-specific UI.
6. Token names should describe purpose, not a one-off component.
7. Layout tokens belong in `shelfstack.tokens.css`; usage rules belong in `layout-width-model.md` and component specs.
8. Typeface, density, and color-mode profile hooks belong in their dedicated CSS files.

---

## Example usage

```css
.ss-card {
  background: var(--color-surface);
  border: var(--border) solid var(--color-base-200);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-sm);
  padding: var(--pad-card);
}
```

```css
.ss-main {
  max-width: var(--layout-standard);
}
```

---

## Migration notes

Older CSS may contain raw colors, one-off spacing, or hardcoded widths. When touching those rules, replace repeated values with tokens and remove the old rule from the legacy layer when safe.
