# Utilities

| Field | Value |
| ----- | ----- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.utilities.css` |
| Planned partial | None |
| Related | Layout Shell, Typography, Tables, Forms |
| Design-system priority | Priority 3 foundation |

Utilities are small, generic helper classes for layout, visibility, text overflow, and temporary UI state.

---

## Purpose

Use utilities when a small, repeatable adjustment is needed and a full component class would be unnecessary.

Utilities should answer:

```text
Is this a tiny layout/state helper?
Would a component class be overkill?
Will this remain understandable in markup review?
```

---

## Use for

| Utility family | Use |
| -------------- | --- |
| Stack | Vertical rhythm between simple sibling elements |
| Grid | Small responsive/simple grids |
| Action row | Wrapping rows of related controls |
| Visibility | Hide content or expose screen-reader-only text |
| Text overflow | Prevent layout blowouts |
| UI state | Temporary visual states such as loading/selected/disabled |

---

## Do not use for

| Avoid using utilities for | Use instead |
| ------------------------- | ----------- |
| Reusable UI patterns | Component class/spec |
| Domain workflow styling | `shelfstack.domain.*.css` |
| Page-level shell/layout | Layout Shell classes |
| Button/form/table variants | Component variant classes |
| Complex responsive behavior | Component/domain CSS |
| Replacing semantic markup | Correct HTML structure |

Utilities are not a dumping ground. If a set of utilities appears together repeatedly, extract a component or domain class.

---

## Implemented CSS

### Stack

```css
.ss-stack
.ss-stack--xs
.ss-stack--sm
.ss-stack--md
.ss-stack--lg
.ss-stack--start
```

### Grid

```css
.ss-grid
.ss-grid--2
.ss-grid--3
.ss-grid--auto
.ss-grid--dense
```

### Action row

```css
.ss-action-row
.ss-action-row--start
.ss-action-row--end
.ss-action-row--between
.ss-action-row--loose
.ss-action-row--compact
```

### Visibility and overflow

```css
.ss-hidden
.ss-nowrap
.ss-truncate
.ss-full-width
.ss-sr-only
```

### Temporary UI state

```css
.is-disabled
.is-loading
.is-selected
```

Use `.is-*` for temporary UI state, not domain/business state. Use `.status-*` for domain/business state.

---

## Accessibility requirements

1. Use `.ss-sr-only` only for text that must remain available to assistive technology.
2. Do not hide focusable controls with `.ss-hidden` unless they are truly inactive/unavailable.
3. Do not use `.is-disabled` alone as a semantic disabled state; pair it with `disabled`, `aria-disabled`, or non-interactive markup as appropriate.
4. Truncated text must not hide critical information without another way to view it.
5. Utility classes must not replace semantic HTML.

---

## Examples

### Stack

```erb
<div class="ss-stack ss-stack--sm">
  <h2>Vendor source</h2>
  <p class="ss-muted">Default purchasing behavior for this variant.</p>
</div>
```

### Auto grid

```erb
<div class="ss-grid ss-grid--auto">
  <section class="ss-card">...</section>
  <section class="ss-card">...</section>
</div>
```

### Action row

```erb
<div class="ss-action-row ss-action-row--between">
  <%= link_to "Cancel", items_root_path, class: "ss-btn ss-btn-tertiary" %>
  <%= button_tag "Save", class: "ss-btn ss-btn-primary" %>
</div>
```

### Screen-reader-only label

```erb
<label for="global-search" class="ss-sr-only">Search ShelfStack</label>
<input id="global-search" class="ss-input" type="search">
```

### Disabled visual state on non-button element

```erb
<span class="ss-nav__item ss-nav__item--disabled is-disabled" aria-disabled="true">
  POS
</span>
```

---

## Migration notes

Do not add one-off utility classes for a single page. Prefer an existing utility, a component class, or a domain class. New utilities should be generic, obvious, and broadly reusable.
