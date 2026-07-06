# Metric Cards / Metric Strips / Stats

| Field | Value |
| ----- | ----- |
| Status | CSS only / domain partials exist |
| CSS | `app/assets/stylesheets/shelfstack.components.metrics.css` |
| Current partials | `app/views/reports/shared/_metric_strip.html.erb`, `app/views/orders/shared/_metric_strip.html.erb` |
| Planned generic partials | `shared/ui/_metric_card.html.erb`, `shared/ui/_metric_strip.html.erb` |
| Related | Card / Surface, Summary, Table, Reports |
| Design-system priority | Priority 2 |

Metrics highlight important numbers. Metric strips group related metrics for fast operational review.

---

## Purpose

Use metric cards when users need a quick read before reviewing detail.

A metric should answer:

```text
What number matters here?
What does it represent?
Does it need review?
```

---

## Use for

| Use case | Example |
| -------- | ------- |
| Reports | Gross sales, net sales, tax collected |
| Register session | Cash expected, cash counted, variance |
| Inventory | On hand, inventory value |
| Orders | Ordered, received, backordered |
| Demand | Open demand, allocated, overdue |

---

## Do not use for

| Avoid using Metric for | Use instead |
| ---------------------- | ----------- |
| Detailed row data | Table |
| Long explanation | Card / Alert |
| Single label-value detail | Summary |
| Status only | Badge / Status Badge |
| Warning requiring action | Alert / Attention Panel |
| Decorative number | Plain text |

---

## Implemented CSS

```css
.ss-metric-strip
.ss-metric-card
.ss-metric-card--warning
.ss-metric-card__label
.ss-metric-card__value
.ss-metric-card__detail

.ss-stat
.ss-stat__label
.ss-stat__value
.ss-stat__description
```

### Notes

- `.ss-metric-strip` is a responsive grid.
- `.ss-metric-card` and `.ss-stat` share card-like styling.
- `.ss-metric-card--warning` should be used when the metric itself needs review.
- Use `.ss-tabular` with monetary/count values when useful.
- The CSS uses `__detail`, not `__hint`.

---

## Rails partials

Current domain/shared partials exist for reports and orders. Do not force a generic partial until the common API is clear across reports, POS/register sessions, orders, and inventory.

Suggested future APIs:

```erb
<%= render "shared/ui/metric_card",
      label: "Net Sales",
      value: number_to_currency(@summary.net_sales),
      detail: "After returns and discounts" %>

<%= render "shared/ui/metric_strip", metrics: @metrics %>
```

---

## Accessibility requirements

1. Label and value must be presented together.
2. Do not rely on color alone for warning/positive/negative meaning.
3. Use readable labels, not only abbreviations.
4. Use tabular numerals for monetary/count values when helpful.
5. Avoid overloading a page with too many metric cards.
6. Link metrics to detail only when the interaction is obvious.

---

## Examples

### Metric card

```erb
<section class="ss-metric-card">
  <span class="ss-metric-card__label">Net Sales</span>
  <span class="ss-metric-card__value ss-tabular"><%= number_to_currency(@summary.net_sales) %></span>
  <span class="ss-metric-card__detail">After returns and discounts</span>
</section>
```

### Warning metric

```erb
<section class="ss-metric-card ss-metric-card--warning">
  <span class="ss-metric-card__label">Drawer Variance</span>
  <span class="ss-metric-card__value ss-tabular"><%= number_to_currency(@variance) %></span>
  <span class="ss-metric-card__detail">Review before closing</span>
</section>
```

### Metric strip

```erb
<div class="ss-metric-strip">
  <section class="ss-metric-card">
    <span class="ss-metric-card__label">On Hand</span>
    <span class="ss-metric-card__value ss-tabular"><%= @stock.on_hand %></span>
  </section>

  <section class="ss-metric-card">
    <span class="ss-metric-card__label">On Order</span>
    <span class="ss-metric-card__value ss-tabular"><%= @stock.on_order %></span>
  </section>
</div>
```

---

## Migration notes

Report and order metric partials may remain domain-specific until a generic metric API is justified. Put reusable visual treatment in `shelfstack.components.metrics.css`; domain-specific metric selection belongs in presenters/partials for that workflow.
