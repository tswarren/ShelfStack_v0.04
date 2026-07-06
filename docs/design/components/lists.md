# Lists / List Rows / Timelines

| Field | Value |
| ----- | ----- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.lists.css` |
| Planned partials | `shared/ui/_list_row.html.erb`, `shared/ui/_timeline.html.erb` only after usage stabilizes |
| Related | Card / Surface, Table, Summary, Badges |
| Design-system priority | Priority 2 |

Lists show a small set of related records or events when a table would be too heavy.

---

## Purpose

Use list rows when users need to scan items vertically, especially when each item has a title, metadata, and a small action set.

Use timelines when the ordering and sequence of events matter.

---

## Use for

| Pattern | Use case | Example |
| ------- | -------- | ------- |
| List | Small related record groups | recent activity, related customers, source matches |
| List row | Card-like row with title/meta/actions | customer demand row, setup option row |
| Timeline | Time-ordered events | audit trail, POS session activity, receiving history |

---

## Do not use for

| Avoid using List for | Use instead |
| -------------------- | ----------- |
| Large comparable datasets | Table / Data Table |
| Label-value facts | Summary |
| Dense editable line entry | Domain line-entry table |
| Metrics | Metric Card / Metric Strip |
| Static prose | Plain content / Card |

---

## Implemented CSS

```css
.ss-list
.ss-list-row
.ss-list-row--selected
.ss-list-row--warning
.ss-list-row__title
.ss-list-row__meta
.ss-list-row__actions

.ss-timeline
.ss-timeline-item
.ss-timeline-marker
.ss-timeline-meta
```

---

## Accessibility requirements

1. Use semantic lists (`ul`, `ol`) when the content is truly a list.
2. Use clear headings/titles for each row when rows contain multiple pieces of information.
3. Keep row actions grouped and keyboard reachable.
4. Do not make the entire row clickable unless the interaction is obvious and accessible.
5. Timeline entries should include readable timestamps or sequence labels.
6. Do not rely on the timeline marker alone to convey meaning.

---

## Examples

### List rows

```erb
<div class="ss-list">
  <% @customers.each do |customer| %>
    <article class="ss-list-row">
      <div>
        <div class="ss-list-row__title"><%= customer.name %></div>
        <div class="ss-list-row__meta"><%= customer.email %></div>
      </div>

      <div class="ss-list-row__actions">
        <%= link_to "View", customer_path(customer), class: "ss-btn ss-btn-tertiary ss-btn--small" %>
      </div>
    </article>
  <% end %>
</div>
```

### Selected row

```erb
<article class="ss-list-row ss-list-row--selected">
  ...
</article>
```

### Warning row

```erb
<article class="ss-list-row ss-list-row--warning">
  <div>
    <div class="ss-list-row__title">Cost discrepancy</div>
    <div class="ss-list-row__meta">Review before posting receipt.</div>
  </div>
</article>
```

### Timeline

```erb
<ol class="ss-timeline">
  <% @events.each do |event| %>
    <li class="ss-timeline-item">
      <span class="ss-timeline-marker" aria-hidden="true"></span>
      <div>
        <div><%= event.description %></div>
        <div class="ss-timeline-meta"><%= display_time(event.created_at) %></div>
      </div>
    </li>
  <% end %>
</ol>
```

---

## Migration notes

Use lists for small related collections and timelines for sequence. Do not replace tables with lists when row/column comparison matters.
