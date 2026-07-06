# Textarea

| Field | Value |
| :---- | :---- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.forms.css` |
| Related | [Field](field.md), [Input](input.md), [Form](form.md) |
| Design-system priority | Priority 1 (forms module) |

Textareas collect multi-line text.

## Purpose

Use textareas for notes, reasons, descriptions, and other longer free-text values that do not fit a single-line input.

## Use for

| Use case | Example |
| :---- | :---- |
| Notes | Receipt discrepancy reason, buyback note |
| Description | Vendor note, internal comment |
| Free text | Customer contact summary |

## Do not use for

| Avoid using Textarea for | Use instead |
| :---- | :---- |
| Short single-line values | [Input](input.md) |
| Structured metadata | Dedicated fields |
| Read-only display | Summary / plain text |

## CSS

### Implemented

```css
.ss-textarea
```

Shares base border, padding, focus, and color rules with `.ss-input` and `.ss-select`. Textareas use `border-radius: var(--radius-md)` instead of the pill radius used on single-line inputs.

Native `textarea` elements inside `.ss-form` and `.ss-field` receive the same styling without an extra class.

## Accessibility requirements

1. Every textarea needs a visible label.  
2. Use `rows` or CSS height to signal expected length.  
3. Connect help and error text with `aria-describedby` when practical.  
4. Do not use placeholder as the only label.

## Examples

### Basic textarea

```
<%= form.text_area :notes, class: "ss-textarea", rows: 4 %>
```

### With field partial

```
<%= render layout: "shared/forms/field",
      locals: { f: form, record: @receipt, field: :notes, help: "Visible on the posted receipt audit trail." } do %>
  <%= form.text_area :notes, class: "ss-textarea", rows: 3 %>
<% end %>
```

## Migration notes

Prefer `.ss-textarea` on explicit markup. Bare `textarea` inside `.ss-form` / `.ss-field` is acceptable when the form shell already provides field spacing.
