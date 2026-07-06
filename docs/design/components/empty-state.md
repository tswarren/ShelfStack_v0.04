# Empty State

| Field | Value |
| :---- | :---- |
| Status | Partial exists |
| CSS | `app/assets/stylesheets/shelfstack.components.feedback.css` |
| Current partial | `app/views/reports/shared/_empty_state.html.erb` |
| Related | [Flash](flash.md), [Toast](toast.md), [Alert](alert.md), Table |
| Design-system priority | Priority 2 (feedback module) |

Empty states explain that a list, report, or panel has no rows yet.

## Purpose

Use empty states when the surrounding workflow is valid but there is nothing to show.

## Use for

| Use case | Example |
| :---- | :---- |
| Report with no rows | No tax collected in range |
| Filtered index | No matching items |
| Optional panel | No related records |

## Do not use for

| Avoid using Empty State for | Use instead |
| :---- | :---- |
| Error after failed action | [Flash](flash.md) or [Alert](alert.md) |
| Permission block | [Access Notice](access-notice.md) |
| Loading | Progress / skeleton |
| Field validation | [Field error](field.md) |

## CSS

### Implemented

```css
.ss-empty-state
.ss-empty-state__title
.ss-empty-state__message
.ss-empty-state__actions
```

Reports partial and the planned `shared/ui/_empty_state` both use `.ss-empty-state__message`.

## Rails partial

```
app/views/reports/shared/_empty_state.html.erb
```

Locals: `title:`, `message:`

## Accessibility requirements

1. State the situation plainly (“No results for this date range”).  
2. Offer a next action when one exists (change filters, create record).  
3. Do not use empty state for errors that require correction.  
4. Keep copy short; put detail in linked help if needed.

## Examples

### Via reports partial

```
<%= render "reports/shared/empty_state",
      title: "No tax collected",
      message: "Try a wider date range or confirm the store filter." %>
```

### Inline markup

```
<div class="ss-empty-state">
  <p class="ss-empty-state__title">No purchase orders</p>
  <p class="ss-empty-state__message">Submit a draft PO from the buyer workbench.</p>

  <div class="ss-empty-state__actions">
    <%= link_to "Open buyer workbench", orders_buyer_workbench_path, class: "ss-btn ss-btn-secondary ss-btn--small" %>
  </div>
</div>
```

## Migration notes

Extract a generic `shared/ui/_empty_state.html.erb` only after report and index empty patterns converge. Until then, copy the reports partial pattern or use inline markup with documented classes.
