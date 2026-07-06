# Field

| Field | Value |
| :---- | :---- |
| Status | Partial exists |
| CSS | `app/assets/stylesheets/shelfstack.components.forms.css` (error border via legacy `shelfstack.css` until extracted) |
| Current partial | `app/views/shared/forms/_field.html.erb` |
| Planned generic partial | Not yet; current form partial remains preferred |
| Related | Form, Input, Select, Alert |
| Design-system priority | Priority 1 |

A field groups one input with its label, help text, warning/error text, and validation feedback.

## Purpose

Fields make form input understandable and correctable.

A field should answer:

```text
What is this value?
What format is expected?
Is it required?
Is there a warning?
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
| Form-level warning | Alert |
| Workflow-level warning | Attention Panel |

## CSS

### Implemented (`shelfstack.components.forms.css`)

```css
.ss-field
.ss-field--inline
.ss-label
.ss-help
.ss-hint
.ss-field-error
.ss-field-warning
```

| Class | Role |
| :---- | :---- |
| `.ss-field` | Wrapper grid for label, control, help, warning, and error |
| `.ss-label` | Label text (what `_field.html.erb` emits) |
| `.ss-help` / `.ss-hint` | Muted help copy below the control |
| `.ss-field-warning` | Non-blocking field-level caution |
| `.ss-field-error` | Per-field validation failure text |

`.ss-field-label` is styled in forms CSS for compatibility, but **`_field.html.erb` emits `ss-label`**, not `ss-field-label`.

### Helper-emitted / legacy-styled (`shelfstack.css` until extracted)

```css
.ss-field--error
.ss-required
```

| Class | Role |
| :---- | :---- |
| `.ss-field--error` | Added by `ss_field_css` when the record has errors; error borders on nested inputs |
| `.ss-required` | Asterisk abbr inside required labels (`ss_required_label`) |

Prefer `ss-field--error` for new markup. Legacy `.ss-field--invalid` exists in monolithic CSS only; do not add new usages.

## Warning vs error vs alert

| Pattern | Use when |
| ------- | -------- |
| `.ss-field-warning` | The field value is allowed but needs caution or review. |
| `.ss-field-error` | The field value is invalid and blocks save/submit/post. |
| `.ss-alert` | The warning/error applies to the form or workflow, not one field. |
| `.ss-attention-panel` | Multiple related warnings need grouped review. |

Examples of field warnings:

```text
Price is below target margin.
Quantity exceeds on-hand but negative stock is allowed.
Vendor source is missing a preferred discount.
```

## Rails partial

Current path:

```text
app/views/shared/forms/_field.html.erb
```

Locals:

```ruby
f:       form builder
record:  model instance (for errors)
field:   attribute name
label:   optional override
required: boolean
help:    optional help string
```

Use as a layout partial:

```erb
<%= render layout: "shared/forms/field",
      locals: { f: f, record: @vendor, field: :name, required: true } do %>
  <%= f.text_field :name, class: "ss-input" %>
<% end %>
```

## Accessibility requirements

1. The label must be programmatically associated with the input.
2. Help text should be connected with `aria-describedby` when possible.
3. Warning/error text should be connected with `aria-describedby` when practical.
4. Invalid fields should use `aria-invalid="true"` when practical.
5. Do not rely on color alone to indicate warning or error.
6. Required fields should be visible and consistent (`ss-required` abbr).
7. Field warnings should not be announced as blocking errors.

## Examples

### Field via partial

```erb
<%= render layout: "shared/forms/field",
      locals: { f: f, record: @vendor, field: :name, required: true } do %>
  <%= f.text_field :name, class: "ss-input" %>
<% end %>
```

### Field with help

```erb
<div class="ss-field">
  <%= form.label :sku, "SKU", class: "ss-label" %>
  <%= form.text_field :sku, class: "ss-input", aria: { describedby: "sku-help" } %>
  <p id="sku-help" class="ss-help">Use the store SKU or scan code.</p>
</div>
```

### Field warning

```erb
<div class="ss-field">
  <%= form.label :price_cents, "Price", class: "ss-label" %>
  <%= form.text_field :price_cents, class: "ss-input", aria: { describedby: "price-warning" } %>
  <p id="price-warning" class="ss-field-warning">Price is below target margin but can be saved.</p>
</div>
```

### Invalid field

```erb
<div class="ss-field ss-field--error">
  <%= form.label :price_cents, "Price", class: "ss-label" %>
  <%= form.text_field :price_cents, class: "ss-input", aria: { invalid: true, describedby: "price-error" } %>
  <p id="price-error" class="ss-field-error">Price is required.</p>
</div>
```

## Migration notes

When touching legacy forms, move validation from generic `.flash-alert` blocks toward field-specific errors plus an optional form-level alert. Replace legacy `.ss-field--invalid` with `.ss-field--error` when editing nearby markup.

Use `.ss-field-warning` only for non-blocking field-level caution. Use `.ss-alert--warning` for form/workflow warnings.
