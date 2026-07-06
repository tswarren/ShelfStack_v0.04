# Expanded Row

| Field | Value |
| ----- | ----- |
| Status | Partial exists / legacy CSS |
| Current partial | `app/views/shared/interaction/_expanded_row.html.erb` |
| Current CSS | Legacy `shelfstack.css` (`.ss-expand-row*`, `.ss-row-detail*`) |
| Target CSS home | `shelfstack.components.disclosure.css`, `shelfstack.components.tables.css`, or domain CSS depending on usage |
| Related | Table, Disclosure, POS cart line, Dialog, Drawer |
| Design-system priority | Priority 3 interaction shell |

Expanded rows reveal inline detail or editing controls directly below a table/list row while keeping the user in context.

---

## Purpose

Use expanded rows when the user needs to inspect or edit supporting row-level detail without leaving the table or opening a separate overlay.

Expanded rows should answer:

```text
What extra detail belongs to this row?
Can I work on it without losing table context?
Is the expanded area active for keyboard scope?
```

---

## Use for

| Use case | Example |
| -------- | ------- |
| POS cart line editing | Edit discount, quantity, or line detail below the cart line |
| PO/receipt line detail | Review source/cost/discrepancy details inline |
| Inventory adjustment detail | Enter reason or supporting data for a line |
| Table-row inspection | Show row-specific operational detail without navigation |

---

## Do not use for

| Avoid using Expanded Row for | Use instead |
| ---------------------------- | ----------- |
| Full edit workflow | Dedicated page |
| Complex multi-section form | Drawer or page |
| Small confirmation | Alert Dialog |
| Passive record detail | Drawer / Card / Summary |
| Page-level warning | Alert / Attention Panel |
| Non-tabular content | Disclosure / Card / List |

---

## Current partial

```text
app/views/shared/interaction/_expanded_row.html.erb
```

Current locals:

```ruby
open: false
colspan: 1
line_id:
target:
keyboard_action:
```

The current partial emits:

```css
.ss-expand-row
.ss-expand-row--active
```

It also wires `keyboard-scope` state through data attributes when active.

---

## Current CSS status

The partial exists, but durable styling has not yet been extracted into modular CSS.

Current styling lives in legacy CSS and may include:

```css
.ss-expand-row
.ss-expand-row--active
.ss-row-detail
.ss-row-detail__actions
.ss-row-detail__section
```

Treat this as a migration bridge, not a stable modular contract.

---

## Accessibility requirements

1. Expanded row content must be associated with the row it expands.
2. Hidden expanded rows must not expose active keyboard scope.
3. Controls inside the expanded row must be reachable in logical order.
4. The trigger row/control must communicate expanded/collapsed state when practical.
5. Do not hide blocking validation inside a collapsed expanded row after submit.
6. Use clear labels for row-detail forms and actions.

---

## Examples

### Current partial usage

```erb
<%= render "shared/interaction/expanded_row",
      open: line.editing?,
      colspan: 6,
      line_id: line.id,
      target: "editRow",
      keyboard_action: "keydown->pos-cart-line#handleEditKeydown" do %>
  <div class="ss-row-detail">
    <div class="ss-row-detail__section">
      ...
    </div>
  </div>
<% end %>
```

### Manual target shape

```erb
<tr class="ss-expand-row ss-expand-row--active">
  <td colspan="6">
    <div class="ss-row-detail">
      <p class="ss-muted">Line detail goes here.</p>
    </div>
  </td>
</tr>
```

---

## Migration notes

Expanded row is an interaction-shell pattern with a partial, but its CSS is still legacy. Extract reusable row expansion structure into `shelfstack.components.tables.css` or `shelfstack.components.disclosure.css` only if it remains generic across domains. Keep POS-specific editing layout in `shelfstack.domain.pos.css`.
