# Appearance Switcher

| Field | Value |
| ----- | ----- |
| Status | Partial exists / CSS only styling |
| CSS | `app/assets/stylesheets/shelfstack.components.appearance.css` |
| Current partial | `app/views/shared/ui/_appearance_switcher.html.erb` |
| Related | App Shell, Dropdown Menu, Button, User Menu |
| Design-system priority | Priority 2 |

The appearance switcher lets users choose a ShelfStack view mode.

---

## Purpose

Use the appearance switcher to expose supported user-facing view modes:

```text
Standard View
Accessible View
Compact View
```

The switcher controls view mode. View mode maps to body data attributes for typeface, density, and color-mode plumbing through helpers and user settings.

---

## Use for

| Use case | Example |
| -------- | ------- |
| User preference menu | View mode submenu under active user |
| Accessibility preference | Accessible View |
| Dense operational preference | Compact View |
| Standard baseline | Standard View |

---

## Do not use for

| Avoid using Appearance Switcher for | Use instead |
| ---------------------------------- | ----------- |
| Per-page filters | Filter Bar / Data Table controls |
| Temporary zoom | Browser zoom / OS accessibility tools |
| POS mode selection | POS mode switch domain component |
| Theme design experimentation | Tokens/color-mode docs |
| Admin defaults | Setup/settings workflow |

---

## Implemented CSS

```css
.ss-appearance-switcher
.ss-appearance-switcher__title
.ss-appearance-switcher__options
.ss-appearance-switcher__form
.ss-appearance-switcher__option
.ss-appearance-switcher__option.is-active
```

The active option renders a checkmark through `::before`.

---

## Current partial

```text
app/views/shared/ui/_appearance_switcher.html.erb
```

The partial supports optional title rendering:

```erb
<%= render "shared/ui/appearance_switcher" %>
<%= render "shared/ui/appearance_switcher", show_title: false %>
```

Use `show_title: false` when rendering inside a labeled menu/submenu.

---

## Accessibility requirements

1. The switcher group should have an accessible label.
2. Each option should communicate selected state with `aria-pressed`.
3. Do not rely on the checkmark alone; selected state should also be reflected in class/ARIA.
4. Options must be keyboard reachable.
5. Changing view mode should provide page-level feedback or otherwise clearly apply.
6. The switcher must work inside the user menu without trapping focus unexpectedly.

---

## Examples

### Standalone switcher

```erb
<%= render "shared/ui/appearance_switcher" %>
```

### User-menu submenu

```erb
<details class="ss-dropdown-submenu">
  <summary class="ss-dropdown-menu__item ss-dropdown-submenu__trigger" role="menuitem" aria-haspopup="menu">
    View mode
  </summary>
  <div class="ss-dropdown-submenu__menu" role="menu">
    <%= render "shared/ui/appearance_switcher", show_title: false %>
  </div>
</details>
```

---

## Migration notes

Do not add new appearance controls outside the active user menu without a clear use case. Keep user-facing language at the view-mode level; typeface/density/color-mode internals belong in helpers, body attributes, and CSS profile files.
