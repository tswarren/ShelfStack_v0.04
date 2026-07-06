# Fieldset

| Field | Value |
| :---- | :---- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.forms.css` |
| Related | [Field](field.md), [Form](form.md), [Choice controls](choice-controls.md) |
| Design-system priority | Priority 1 (forms module) |

Fieldsets group related form controls under a shared legend.

## Purpose

Use fieldsets when several inputs belong to one decision area and should be announced together to assistive technology.

## Use for

| Use case | Example |
| :---- | :---- |
| Permission groups | Related checkbox cluster |
| Address blocks | Grouped optional fields |
| Filter sections | Related report filters |

## Do not use for

| Avoid using Fieldset for | Use instead |
| :---- | :---- |
| Visual card grouping only | [Form section](form.md) / `.ss-form-card` |
| Single field | [Field](field.md) |
| Read-only summary | [Summary](card-surface.md#summary) |

## CSS

### Implemented

```css
.ss-fieldset
.ss-fieldset__legend
.ss-fieldset__description
```

`.ss-fieldset__legend` shares label styling with `.ss-label` and `.ss-field-label`.

## Accessibility requirements

1. Every fieldset needs a `<legend>`.  
2. Use `fieldset` only when the group has semantic meaning.  
3. Do not nest fieldsets deeply.  
4. Optional group description can use `.ss-fieldset__description` or `.ss-help`.

## Examples

```
<fieldset class="ss-fieldset">
  <legend class="ss-fieldset__legend">Returnability</legend>
  <p class="ss-fieldset__description">Applies to this vendor source only.</p>

  <div class="ss-field">
    <%= form.label :returnability_status, "Status", class: "ss-label" %>
    <%= form.select :returnability_status, options, {}, class: "ss-select" %>
  </div>
</fieldset>
```

## Migration notes

Prefer `shared/forms/section` for visual form grouping on setup screens. Reserve `fieldset` for semantic clusters that screen readers should treat as one unit.
