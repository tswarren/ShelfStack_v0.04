# Field

| Field | Value |
| :---- | :---- |
| Status | Partial exists |
| CSS | `app/assets/stylesheets/shelfstack.components.forms.css` |
| Current partial | `app/views/shared/forms/_field.html.erb` |
| Planned generic partial | Not yet; current form partial remains preferred |
| Related | Form, Input, Select, Alert |
| Design-system priority | Priority 1 |

A field groups one input with its label, help text, and validation feedback.

## Purpose

Fields make form input understandable and correctable.

A field should answer:

```
What is this value?
What format is expected?
Is it required?
What went wrong?
```

## Use for

| Use case | Example |
| :---- | :---- |
| Text input | Vendor name, SKU, ISBN |
| Select | Department, tax category |
| Money input | Price, cost, tender amount |
| Checkbox | Include inactive, taxable, returnable |
| Date input | Report start date, business date |
| Textarea | Notes, receipt discrepancy reason |

## Do not use for

| Avoid using Field for | Use instead |
| :---- | :---- |
| Static label-value data | Summary / definition list |
| Table cells | Table-specific controls |
| Read-only status | Badge / alert |
| Action groups | Form Actions / Button Group |

## CSS

```css
.ss-field
.ss-field--required
.ss-field--invalid
.ss-field-label
.ss-field-help
.ss-field-error
```

## Rails partial

Current path:

```
app/views/shared/forms/_field.html.erb
```

## Accessibility requirements

1. The label must be programmatically associated with the input.  
2. Help text should be connected with `aria-describedby` when possible.  
3. Error text should be connected with `aria-describedby`.  
4. Invalid fields should use `aria-invalid="true"` when practical.  
5. Do not rely on color alone to indicate error.  
6. Required fields should be visible and consistent.

## Examples

### Basic field

```
<%= render "shared/forms/field", form: form, attribute: :name do %>
  <%= form.text_field :name, class: "ss-input" %>
<% end %>
```

### Field with help

```
<div class="ss-field">
  <%= form.label :sku, "SKU", class: "ss-field-label" %>
  <%= form.text_field :sku, class: "ss-input", aria: { describedby: "sku-help" } %>
  <p id="sku-help" class="ss-field-help">Use the store SKU or scan code.</p>
</div>
```

### Invalid field

```
<div class="ss-field ss-field--invalid">
  <%= form.label :price_cents, "Price", class: "ss-field-label" %>
  <%= form.text_field :price_cents, class: "ss-input", aria: { invalid: true, describedby: "price-error" } %>
  <p id="price-error" class="ss-field-error">Price is required.</p>
</div>
```

## Migration notes

When touching legacy forms, move validation from generic `.flash-alert` blocks toward field-specific errors plus an optional form-level alert.  