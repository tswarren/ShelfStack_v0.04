# Data Tables / Filter Bars / Pagination

| Field | Value |
| ----- | ----- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.data-tables.css` |
| Current partials | `app/views/reports/shared/_filter_bar.html.erb` (domain; reports filter shell) |
| Planned partials | `shared/ui/_data_table.html.erb`, `_filter_bar.html.erb`, `_pagination.html.erb` |
| Related | Tables, Empty State, Form, Button, Select, [report-view-contract.md](../../specifications/report-view-contract.md) |
| Design-system priority | Priority 2 |

Data tables combine tabular data with filtering, searching, result summaries, pagination, or bulk actions.

---

## Purpose

Use data tables for operational indexes and queues where users need to narrow, scan, compare, and act on many records.

Examples:

```text
Items
Demand queue
Inventory balances
Buyer workbench
Sourcing runs
Reports
Setup indexes
```

---

## Use for

| Use case | Example |
| -------- | ------- |
| Searchable index | Customers, Items |
| Operational queue | Demand, sourcing runs |
| Filtered report | Register summaries |
| Paginated setup list | Users, stores, vendors |
| Bulk-review table | Inventory balances |

---

## Do not use for

| Avoid using Data Table for | Use instead |
| -------------------------- | ----------- |
| Small static table | Table |
| Single record details | Summary |
| Metrics only | Metric Strip |
| Card-based search results | List / Card |
| Editable document line entry | Domain line-entry table |
| POS cart | POS Cart Line domain component |

---

## Implemented CSS

```css
.ss-data-table
.ss-data-table__toolbar
.ss-data-table__filters
.ss-data-table__summary
.ss-data-table__pagination
.ss-data-table__bulk-actions
.ss-data-table__empty
.ss-filter-bar
.ss-filter-group
.ss-items-index-filters
.ss-pagination
.ss-pagination__summary
.ss-pagination__links
.ss-pagination__link
.ss-pagination__link--active
.ss-pagination__link--disabled
```

### Notes

- Use BEM element classes: `__toolbar`, `__filters`, `__summary`, `__pagination`.
- Do not use non-BEM names such as `.ss-data-table-toolbar` or `.ss-data-table-pagination`; those are not defined in modular CSS.
- `.ss-items-index-filters` is a compatibility hook for the current Items index filter area.
- `.ss-filter-bar` is the reusable filter container. Apply it to the filter `<form>` (or equivalent wrapper), not a separate `.ss-filter-form` class — that name is not defined.
- `.ss-filter-actions` holds submit/reset controls beside filter fields. It is styled in legacy `shelfstack.css`, not modular `data-tables.css`. Reports use it via `reports/shared/_filter_bar.html.erb`.
- Date-range filter rows use `.ss-date-range` (scaffold in `shelfstack.components.forms.css`; see [report-view-contract.md](../../specifications/report-view-contract.md)).

---

## Structure

Recommended order:

```text
Page header
Filter/search toolbar
Result summary
Table
Pagination
Empty state when no results
```

---

## Accessibility requirements

1. Filter controls must have labels.
2. Search input should identify what it searches.
3. Pagination links must be reachable and descriptive.
4. Preserve table semantics inside the data table.
5. Empty filtered results should explain how to recover.
6. Bulk actions must make selected state clear.
7. Disabled pagination links should not be interactive.

---

## Examples

### Filter toolbar with table

```erb
<section class="ss-data-table">
  <div class="ss-data-table__toolbar">
    <%= form_with url: items_root_path, method: :get, class: "ss-filter-bar" do %>
      <div class="ss-filter-group">
        <%= label_tag :q, "Search" %>
        <%= text_field_tag :q, params[:q], class: "ss-input", placeholder: "Search items…" %>
      </div>
      <div class="ss-filter-actions">
        <%= submit_tag "Search", class: "ss-btn ss-btn-secondary" %>
      </div>
    <% end %>
  </div>

  <% if @items.any? %>
    <div class="ss-table-scroll">
      <table class="ss-table">
        ...
      </table>
    </div>
  <% else %>
    <div class="ss-data-table__empty">
      <section class="ss-empty-state">
        <p class="ss-empty-state__title">No items found</p>
      </section>
    </div>
  <% end %>
</section>
```

### Pagination

```erb
<nav class="ss-pagination" aria-label="Pagination">
  <div class="ss-pagination__summary">
    Showing 1–25 of 240
  </div>
  <div class="ss-pagination__links">
    <%= link_to "Previous", previous_path, class: "ss-pagination__link" %>
    <%= link_to "Next", next_path, class: "ss-pagination__link" %>
  </div>
</nav>
```

---

## Migration notes

Keep basic `.ss-table` separate from data-table shells. Domain workbenches may extend this pattern in domain CSS, but the generic filter/pagination shell should stay in `shelfstack.components.data-tables.css`.
