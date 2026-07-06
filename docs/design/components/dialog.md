# Dialog

| Field | Value |
| :---- | :---- |
| Status | Partial exists |
| CSS | `app/assets/stylesheets/shelfstack.components.overlays.css` |
| Current partial | `app/views/shared/interaction/_modal.html.erb` |
| Target classes | `.ss-dialog*` while legacy `.ss-modal*` remains during migration |
| Related | Alert Dialog, Drawer, Button |
| Design-system priority | Priority 1 |

See also — other classes in `shelfstack.components.overlays.css`:

| Spec | Covers |
| :---- | :---- |
| [Drawer](drawer.md) | `.ss-drawer*` (partial exists) |
| [Sheet / Popover](sheet-popover.md) | `.ss-sheet*`, `.ss-popover*`, scaffold overlays |

Dialogs support bounded tasks without leaving the current workflow.

## Purpose

Use dialogs for focused interactions that need context but should not require full-page navigation.

## Use for

| Use case | Example |
| :---- | :---- |
| Quick edit | Edit price |
| Add related record | Add identifier |
| Lookup/select | Attach customer |
| Lightweight setup | Create vendor source |
| Confirmation with form | Add discrepancy reason |

## Do not use for

| Avoid using Dialog for | Use instead |
| :---- | :---- |
| Full workflow | Page |
| Long complex forms | Page / Drawer |
| High-risk confirmation | Alert Dialog |
| Passive details | Drawer / card |
| Toast-like result | Toast |

## CSS

### Target (`shelfstack.components.overlays.css`)

```css
.ss-dialog
.ss-dialog__backdrop
.ss-dialog__panel
.ss-dialog__header
.ss-dialog__body
.ss-dialog__footer
```

Structure tokens only. Positioning, open/close behavior, and focus trap are not yet wired to `.ss-dialog*`.

### Current (`shared/interaction/_modal.html.erb` + legacy `shelfstack.css`)

```css
.ss-modal
.ss-modal-overlay
.ss-modal-dialog
.ss-modal-dialog--sm
.ss-modal-dialog--md
.ss-modal-dialog--lg
.ss-modal-dialog--pos
.ss-modal-header
.ss-modal-body
.ss-modal-footer
```

Use modal classes for new work until the dialog migration is executed.

## Current partial

```
<%= render "shared/interaction/modal", id: "edit-price-modal", title: "Edit Price", size: :md do %>
  ...
<% end %>
```

## Accessibility requirements

1. Dialog must trap focus while open.  
2. Focus should return to trigger on close.  
3. Escape should close unless blocked by required decision.  
4. Dialog must have an accessible title.  
5. Background content should not be interactable.  
6. Initial focus should land on the first meaningful control.  
7. Do not use dialogs for content that needs a shareable URL.

## Example

```
<button type="button"
        class="ss-btn ss-btn-secondary"
        data-action="modal#open"
        data-modal-target-id-param="edit-price-modal">
  Edit Price
</button>

<%= render "shared/interaction/modal", id: "edit-price-modal", title: "Edit Price", size: :md do %>
  <%= form_with model: @variant, class: "ss-form" do |form| %>
    <%= render layout: "shared/forms/field",
          locals: { f: form, record: @variant, field: :price } do %>
      <%= form.text_field :price, class: "ss-input", inputmode: "decimal" %>
    <% end %>

    <div class="ss-form-actions">
      <%= form.submit "Save Price", class: "ss-btn ss-btn-primary" %>
    </div>
  <% end %>
<% end %>
```

## Migration notes

Current implementation uses `shared/interaction/modal`. Do not create a parallel dialog partial until the modal/dialog naming migration is planned.  