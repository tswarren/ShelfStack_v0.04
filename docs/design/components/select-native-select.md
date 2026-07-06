# Select / Native Select

| Field | Value |
| :---- | :---- |
| Status | CSS only (base class implemented) |
| CSS | `app/assets/stylesheets/shelfstack.components.forms.css` |
| Planned partial | `app/views/shared/ui/_select.html.erb` only after usage stabilizes |
| Related | Field, Combobox, Lookup Panel, Radio Group |
| Design-system priority | Priority 1 |

Selects choose one value from a known list.

## Purpose

Use native selects for small or moderate static lists where browser behavior is sufficient.

Use combobox/lookup patterns for large, searchable, or remote lists.

## Use for

| Use case | Example |
| :---- | :---- |
| Static setup choices | Department, tax category |
| Status filters | Active/inactive/all |
| Report filters | Store, tender type |
| Small enum fields | Returnable, condition, format |
| Known categories | Subdepartment when list is manageable |

## Do not use for

| Avoid using Select for | Use instead |
| :---- | :---- |
| Large searchable entity list | Combobox / Lookup Panel |
| Multi-select permission matrix | Checkbox group / permission matrix |
| Binary choice | Checkbox / switch |
| POS scan/search | Command bar / lookup panel |
| Hierarchical category tree | Tree select component |

## CSS

### Implemented

```css
.ss-select
```

Native `select` elements inside `.ss-form` and `.ss-field` receive the same base styling.

### Planned modifiers (not in CSS yet)

```css
.ss-select--native
.ss-select--compact
.ss-select--invalid
```

Do not use planned modifier classes until they are added to `shelfstack.components.forms.css`. Use base `.ss-select` and field-level error treatment (`.ss-field--error`, `.ss-field-error`) for now.

## Accessibility requirements

1. Native select must have a label.  
2. Include a blank/default option when no value is selected.  
3. Avoid placeholder-only labeling.  
4. For dependent selects, update the dependent field predictably.  
5. Use help text when the selected value has operational consequences.

## Examples

### Native select

```
<%= form.select :department_id,
      options_from_collection_for_select(@departments, :id, :name, form.object.department_id),
      { include_blank: "Select department" },
      class: "ss-select" %>
```

### Filter select

```
<%= select_tag :format_id,
      options_from_collection_for_select(@formats, :id, :name, params[:format_id]),
      include_blank: "All formats",
      class: "ss-select" %>
```

## Migration notes

Do not build a custom select for simple cases. Keep native selects where they work. Reserve combobox/lookup work for product/customer/vendor searches.
