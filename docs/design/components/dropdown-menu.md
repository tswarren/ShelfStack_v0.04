# Dropdown Menu

| Field | Value |
| :---- | :---- |
| Status | Implemented |
| CSS | `app/assets/stylesheets/shelfstack.components.overlays.css` |
| Current usage | Global user menu, POS Actions menu |
| Planned partial | `app/views/shared/ui/_dropdown_menu.html.erb` if repetition grows |
| Related | Button, Link, Popover |
| Design-system priority | Priority 1 |

See also — other overlays in the same CSS file:

| Spec | Covers |
| :---- | :---- |
| [Drawer](drawer.md) | Side panel partial |
| [Sheet / Popover](sheet-popover.md) | Sheet, popover, hover card, context menu tokens |

Dropdown menus present a compact list of related actions.

## Purpose

Use dropdown menus for secondary actions that do not need to be permanently visible.

## Use for

| Use case | Example |
| :---- | :---- |
| User account menu | Change password, Set PIN, Logout |
| POS actions | Register/session actions |
| Row actions | More actions |
| Compact page actions | Print, export, duplicate |

## Do not use for

| Avoid using Dropdown Menu for | Use instead |
| :---- | :---- |
| Primary page action | Visible button |
| Complex form | Dialog / Popover |
| Large navigation tree | Sidebar / nav |
| Current state display | Badge / panel |
| Destructive confirmation | Alert Dialog |

## CSS

```css
.ss-dropdown
.ss-dropdown-trigger
.ss-dropdown-menu
.ss-dropdown-menu__item
.ss-dropdown-menu__item--danger
.ss-dropdown-menu__separator
.ss-dropdown-menu__section-label
.ss-dropdown-submenu
.ss-dropdown-submenu__trigger
.ss-dropdown-submenu__menu
```

## Accessibility requirements

1. Trigger must be keyboard reachable.  
2. Menu items must be links or buttons based on behavior.  
3. Dangerous menu items should be visually distinct.  
4. Do not use full `.ss-btn` styling for menu rows.  
5. Submenus must support click/tap and keyboard behavior.  
6. Escape/blur behavior should be predictable when JS is added.

## Example

```
<details class="ss-dropdown">
  <summary class="ss-dropdown-trigger">Actions</summary>

  <div class="ss-dropdown-menu" role="menu">
    <%= link_to "Print", print_path, class: "ss-dropdown-menu__item", role: "menuitem" %>

    <div class="ss-dropdown-menu__separator" role="separator"></div>

    <%= button_to "Cancel PO",
          cancel_purchase_order_path(@purchase_order),
          method: :patch,
          class: "ss-dropdown-menu__item ss-dropdown-menu__item--danger",
          form: { class: "ss-inline-form" } %>
  </div>
</details>
```

## Migration notes

Use dropdown items inside menus, not `.ss-btn`. Keep primary workflow actions visible outside dropdowns.
