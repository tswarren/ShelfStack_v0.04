# Input

| Field | Value |
| :---- | :---- |
| Status | CSS only (base class implemented) |
| CSS | `app/assets/stylesheets/shelfstack.components.forms.css` |
| Planned partial | Usually unnecessary; use Rails form helpers with `.ss-input` |
| Related | Field, Form, Select |
| Design-system priority | Priority 1 |

Inputs collect typed values.

## Purpose

Use inputs for short, typed values such as names, identifiers, quantities, money, dates, and search terms.

## Use for

| Use case | Example |
| :---- | :---- |
| Text | Title, vendor name |
| Search | ISBN/SKU/title lookup |
| Number | Quantity, reorder point |
| Money | Price, cost, tender amount |
| Password | Login, PIN/password setup |
| Date | Report date, receipt date |

## Do not use for

| Avoid using Input for | Use instead |
| :---- | :---- |
| Long notes | Textarea |
| Fixed choice lists | Select / radio group |
| Boolean choice | Checkbox / switch |
| Searchable entity lookup | Combobox / lookup panel |
| Static values | Summary text |

## CSS

### Implemented

```css
.ss-input
```

Base `.ss-input` shares styling with `.ss-form input`, `.ss-field input`, and search-form inputs in `shelfstack.components.forms.css`.

### Planned modifiers (not in CSS yet)

```css
.ss-input--search
.ss-input--money
.ss-input--compact
.ss-input--invalid
```

Do not use planned modifier classes in new markup until they are added to `shelfstack.components.forms.css`. Until then:

- Use base `.ss-input` plus `type`, `inputmode`, and `placeholder` as needed.
- Use domain CSS (for example POS table sizing) for workflow-specific density.
- Rely on `.ss-field--error` and `.ss-field-error` for validation, not input-level invalid modifiers.

## Accessibility requirements

1. Every input needs a label.  
2. Use the correct input type.  
3. Use `autocomplete` where helpful for account/session fields.  
4. Use `inputmode` for scanner/money/number-heavy fields when helpful.  
5. Non-obvious formats need help text.  
6. Invalid state must not rely on color alone.

## Examples

### Text input

```
<%= form.text_field :name, class: "ss-input" %>
```

### Search input

```
<%= text_field_tag :q,
      params[:q],
      class: "ss-input",
      placeholder: "ISBN, SKU, title, creator…" %>
```

### Money input

```
<%= form.text_field :price,
      class: "ss-input",
      inputmode: "decimal" %>
```

### POS scanner input

```
<%= text_field_tag :scan,
      nil,
      class: "ss-input",
      placeholder: "Scan or search…",
      autocomplete: "off" %>
```

## Migration notes

Do not add one-off input sizing classes unless the pattern is domain-specific. Put reusable input variants in `shelfstack.components.forms.css`; put POS/receiving table sizing in domain CSS.
