# Sheet / Popover / Hover Card / Context Menu

| Field | Value |
| :---- | :---- |
| Status | CSS only (structure tokens) |
| CSS | `app/assets/stylesheets/shelfstack.components.overlays.css` |
| Related | [Drawer](drawer.md), [Dialog](dialog.md), [Dropdown Menu](dropdown-menu.md) |
| Design-system priority | Priority 2–3 (overlays module) |

These overlay patterns share surface tokens in `overlays.css`. None have standard Rails partials yet.

## Sheet

Side or bottom anchored panel, often for mobile-friendly filters or auxiliary forms.

### Implemented tokens

```css
.ss-sheet
.ss-sheet__backdrop
.ss-sheet__panel
.ss-sheet--right
.ss-sheet--left
.ss-sheet--wide
```

`.ss-sheet__panel` shares panel styling with `.ss-drawer` in modular CSS. No `shared/interaction/_sheet` partial exists.

**Use [Drawer](drawer.md) for new side-panel work** until sheet behavior and partial API are defined.

---

## Popover

Floating panel anchored to a trigger.

### Implemented tokens

```css
.ss-popover
.ss-popover-content
```

Structure/color tokens only. No positioning, arrow, or Stimulus controller contract yet.

**Do not use for new work** without a dedicated spec and behavior implementation. Prefer [Dropdown Menu](dropdown-menu.md) for action lists.

---

## Hover Card

Rich preview on hover/focus.

### Implemented tokens

```css
.ss-hover-card
.ss-hover-card__content
```

Scaffold only. No live markup pattern in the app.

---

## Context Menu

Right-click or secondary-action menu.

### Implemented tokens

```css
.ss-context-menu
```

Scaffold only. Prefer [Dropdown Menu](dropdown-menu.md) for keyboard-reachable action menus today.

---

## Accessibility requirements (when implemented)

1. Sheet: same dialog expectations as [Drawer](drawer.md).  
2. Popover/hover card: must not trap focus unless modal; support Escape to dismiss.  
3. Context menu: keyboard reachable alternative required; do not rely on right-click only.  
4. All patterns: return focus to trigger on close.

## Migration notes

Do not invent parallel class names. When implementing sheet/popover, extend `overlays.css` and add a focused spec section here or split into standalone spec files.
