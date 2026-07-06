# Checkbox / Radio / Choice Controls

| Field | Value |
| :---- | :---- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.forms.css` |
| Related | [Field](field.md), [Form](form.md), [Fieldset](fieldset.md) |
| Design-system priority | Priority 1 (forms module) |

Choice controls let users pick one or more options from a short list.

## Purpose

Use checkbox and radio patterns for explicit boolean or enumerated choices where a native select is too heavy or not expressive enough.

## Use for

| Use case | Example |
| :---- | :---- |
| Boolean flag | Active, taxable, preferred vendor |
| Small enum set | Returnability, payout mode |
| Mutually exclusive options | Radio group with 2–5 choices |
| Multi-select flags | Permission checkboxes |

## Do not use for

| Avoid using Choice Controls for | Use instead |
| :---- | :---- |
| Long static lists | [Select](select-native-select.md) |
| Searchable entity pickers | Combobox / lookup panel (planned) |
| Segmented mode switch | [Button group](button.md) |
| On/off settings at page level | Toggle group (scaffold only today) |

## CSS

### Implemented

```css
.ss-choice-list
.ss-checkbox-group
.ss-radio-group
.ss-choice-option
.ss-check-field
.ss-checkbox-field
.ss-radio-field
```

Choice rows use a bordered card-like row (`flex` layout with gap) suitable for stacked options.

### Scaffold only (layout shell, no full component yet)

```css
.ss-toggle-group
```

`.ss-toggle-group` exists as a flex wrapper in forms CSS. Do not treat it as a finished switch/toggle component until dedicated styles and behavior are defined.

### Planned (selectors present, not a component contract)

```css
.ss-combobox
.ss-lookup-panel
.ss-upload-zone
.ss-date-range
.ss-filter-group
```

These are placeholder layout hooks in `forms.css`. Do not use for new work without a dedicated spec.

## Accessibility requirements

1. Every checkbox/radio needs a programmatic label.  
2. Radio groups sharing one name must be wrapped in `fieldset` + `legend` when practical.  
3. Do not rely on border color alone for selected state.  
4. Keep option text specific; avoid “Yes/No” without context.

## Examples

### Checkbox field

```
<div class="ss-checkbox-field">
  <%= form.check_box :active %>
  <%= form.label :active, "Active", class: "ss-label" %>
</div>
```

### Radio group

```
<fieldset class="ss-fieldset">
  <legend class="ss-fieldset__legend">Payout mode</legend>

  <div class="ss-radio-group">
    <label class="ss-radio-field">
      <%= form.radio_button :payout_mode, "cash" %>
      <span>Cash</span>
    </label>

    <label class="ss-radio-field">
      <%= form.radio_button :payout_mode, "trade_credit" %>
      <span>Trade credit</span>
    </label>
  </div>
</fieldset>
```

### Stacked choice options

```
<div class="ss-choice-list">
  <label class="ss-choice-option">
    <%= check_box_tag :include_inactive, "1", false %>
    <span>Include inactive records</span>
  </label>
</div>
```

## Migration notes

ShelfStack does not yet have a shared checkbox/radio partial. Use documented classes directly and keep groups small. For permission matrices and large multi-select surfaces, prefer table/checkbox patterns documented in workspace specs until a matrix component exists.
