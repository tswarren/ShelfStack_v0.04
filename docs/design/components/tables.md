# Tables

| Field | Value |
| ----- | ----- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.tables.css` |
| Planned partial | Optional; do not create until repeated APIs stabilize |
| Related | Data Tables, Badges, Summary, Row/Table Actions |
| Design-system priority | Priority 2 |

Tables display structured rows and columns of operational data.

---

## Purpose

Use tables when users need to compare multiple records across consistent columns.

A table should make it easy to answer:

```text
What is this row?
What state is it in?
What numbers matter?
What action can I take?
```

---

## Use for

| Use case | Example |
| -------- | ------- |
| Setup indexes | Users, stores, departments, tax rates |
| Inventory rows | Stock balances, movements |
| Purchasing | PO lines, receipt lines |
| POS | Completed transaction lines, tender rows |
| Reports | Register summary, tax lines, sales breakdowns |
| Item detail | Variants, identifiers, vendor sources |

---

## Do not use for

| Avoid using Table for | Use instead |
| --------------------- | ----------- |
| One record’s label/value details | Summary |
| Small card-style search results | List / Card |
| KPI totals only | Metric Card / Metric Strip |
| Workflow warning | Alert / Attention Panel |
| Pure layout | CSS grid/flex utilities |
| Mobile-only simple content where comparison is not needed | List rows |

---

## Implemented CSS

```css
.ss-table
.ss-table-scroll
.ss-table--compact
.ss-table--dense
.ss-table--sticky
.ss-table-row--highlight
.ss-table-row--selected
.ss-table-row--warning
.ss-table-row--error
.ss-table--tree
.ss-tree-name-cell
.ss-tree-row--root
.ss-table-actions
```

### Notes

- `.ss-table-scroll` is the horizontal overflow wrapper.
- `.ss-table--compact` and `.ss-table--dense` share compact cell padding.
- `.ss-table--sticky` makes table headers sticky.
- `.ss-table--tree` supports indentation through `--tree-depth` on tree rows.
- `.ss-table-actions` is the modular row-action class.
- Legacy `.ss-row-actions` may still appear in older views; do not add new usages unless an alias is intentionally added.

---

## Accessibility requirements

1. Use real `<table>`, `<thead>`, `<tbody>`, `<th>`, and `<td>` for tabular data.
2. Use `<th scope="col">` for column headers.
3. Use `<th scope="row">` when the first cell identifies the row.
4. Do not use tables for pure layout.
5. Numeric columns should align consistently and use tabular numerals when helpful.
6. Row actions should be grouped and clearly labeled.
7. Horizontally scrollable tables should preserve key identifying columns when practical.

---

## Examples

### Basic table

```erb
<div class="ss-table-scroll">
  <table class="ss-table">
    <thead>
      <tr>
        <th scope="col">Variant</th>
        <th scope="col">On hand</th>
        <th scope="col">Price</th>
        <th scope="col">Status</th>
      </tr>
    </thead>
    <tbody>
      <% @variants.each do |variant| %>
        <tr>
          <th scope="row"><%= variant.name %></th>
          <td class="ss-tabular"><%= variant.on_hand %></td>
          <td class="ss-tabular"><%= number_to_currency(variant.price) %></td>
          <td><span class="ss-status-badge status-active">Active</span></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

### Compact table

```erb
<table class="ss-table ss-table--compact">
  ...
</table>
```

### Row actions

```erb
<td class="ss-table-actions">
  <%= link_to "View", item_path(item), class: "ss-btn ss-btn-tertiary ss-btn--small" %>
</td>
```

### Tree table row

```erb
<tr class="ss-tree-row--root" style="--tree-depth: 1">
  <th scope="row" class="ss-tree-name-cell">Fiction</th>
  <td>Active</td>
</tr>
```

---

## Migration notes

Use `.ss-table-scroll` for tables that may exceed the page width. Reusable table styling belongs in `shelfstack.components.tables.css`; workflow-specific column sizing or editable line-entry behavior belongs in the relevant domain CSS file.
