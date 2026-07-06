# Drawer

| Field | Value |
| :---- | :---- |
| Status | Partial exists |
| CSS | `app/assets/stylesheets/shelfstack.components.overlays.css` (tokens) + legacy `shelfstack.css` (live behavior) |
| Current partial | `app/views/shared/interaction/_drawer.html.erb` |
| Target classes | `.ss-drawer*` aligned with `overlays.css` after extraction |
| Related | [Dialog](dialog.md), [Sheet](sheet-popover.md), [Dropdown Menu](dropdown-menu.md) |
| Design-system priority | Priority 2 (overlays module) |

Drawers present secondary workflow content without leaving the current page.

## Purpose

Use drawers for contextual detail, multi-field side workflows, and operational panels that need more space than a dialog but less than full navigation.

## Use for

| Use case | Example |
| :---- | :---- |
| Variant operations | Item variant ops drawer |
| POS utility panel | Register session drawer |
| Related record detail | Customer attach/history |
| Multi-section review | Staged workflow side panel |

## Do not use for

| Avoid using Drawer for | Use instead |
| :---- | :---- |
| Simple confirm | [Alert Dialog](alert-dialog.md) |
| Quick single-field edit | [Dialog](dialog.md) |
| Full-page workflow | Dedicated page |
| Passive toast result | [Toast](toast.md) |

## CSS

### Current (`shared/interaction/_drawer` + legacy `shelfstack.css`)

```css
.ss-drawer
.ss-drawer-overlay
.ss-drawer-panel
.ss-drawer-panel--right
.ss-drawer-header
.ss-drawer-title
.ss-drawer-body
.ss-drawer-footer
.ss-drawer-close
.ss-drawer-section
.ss-drawer-section-title
```

The partial emits `.ss-drawer` with Stimulus `drawer` controller, focus trap, dirty guard, and body lock (`body.ss-drawer-open`).

### Modular tokens (`shelfstack.components.overlays.css`)

```css
.ss-drawer
.ss-drawer--right
.ss-drawer--left
```

Positioning and panel chrome remain in legacy CSS until Phase 10-E extraction.

## Rails partial

```
<%= render "shared/interaction/drawer",
      id: "variant-ops-drawer",
      title: "Variant operations" do %>
  ...
<% end %>
```

Optional locals: `footer:`, `close_label:`, `close_on_escape:`, `close_on_backdrop:`, `dirty_guard:`, `title_html_options:`

## Accessibility requirements

1. Drawer uses `role="dialog"` and `aria-modal="true"`.  
2. Must trap focus while open (interaction shell).  
3. Must have an accessible title (`aria-labelledby`).  
4. Close control needs an accessible name.  
5. Focus should return to the trigger on close.  
6. Escape closes unless blocked by dirty guard / required decision.

## Examples

### Open from a button

```
<button type="button"
        class="ss-btn ss-btn-secondary"
        data-action="drawer#open"
        data-drawer-target-id-param="variant-ops-drawer">
  Operations
</button>

<%= render "items/items/variant_operations_drawer", variant: @variant %>
```

## Migration notes

Drawers are the Phase 10 interaction-shell counterpart to modals. Do not fork a second drawer partial. Extract legacy `.ss-drawer*` rules into `overlays.css` when touching drawer styling.

See also `docs/specifications/modal-and-drawer-patterns.md` for focus/close behavior.
