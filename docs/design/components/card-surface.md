# Card / Surface

| Field | Value |
| :---- | :---- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.cards.css` |
| Planned partial | `app/views/shared/ui/_card.html.erb` |
| Related | Page Header, Alert, Metric Card, Summary |
| Design-system priority | Priority 1 |

Cards and surfaces group related content.

## Purpose

Use cards for contained, scannable content blocks. Use surfaces for lower-level layout backgrounds that may not need full card structure.

## Use for

| Use case | Example |
| :---- | :---- |
| Setup panels | Tax settings, role details |
| Item sidebar | Status, vendor source summary |
| Dashboard blocks | Register state, inventory warnings |
| Form sections | Account settings |
| Summary panels | Customer balance, order status |

## Do not use for

| Avoid using Card for | Use instead |
| :---- | :---- |
| Page shell | App shell / main container |
| Every small piece of text | Plain layout |
| Table rows | Table / list row |
| Alerts | Alert |
| Metrics only | Metric Card |
| Modal body | Dialog body |

## CSS

All classes below are in `shelfstack.components.cards.css`.

### Card / surface

#### Implemented

```css
.ss-card
.ss-card--compact
.ss-card--strong
.ss-card--muted
.ss-card--clickable
.ss-card__header
.ss-card__body
.ss-card__footer
.ss-surface
.ss-surface--plain
.ss-surface--muted
.ss-surface--compact
.ss-surface--strong
```

### Layout variants (same module)

#### Implemented

```css
.ss-form-card
.ss-detail-panel
.ss-sidebar-card
.ss-side-card
.ss-card-grid
```

| Class | Use |
| :---- | :---- |
| `.ss-form-card` | Form section shell from `shared/forms/_section` |
| `.ss-detail-panel` | Dense detail block on show pages |
| `.ss-sidebar-card` | Secondary facts in a sidebar column |
| `.ss-side-card` | Alternate side column card alias |
| `.ss-card-grid` | Responsive grid of cards (setup home, sourcing) |

### Summary (definition list)

#### Implemented

```css
.ss-summary
.ss-summary--two-column
.ss-summary__label
.ss-summary__value
```

Use `dl.ss-summary` or `div.ss-summary` for label/value pairs on detail and setup screens. `--two-column` and native `dt`/`dd` children share the two-column grid.

## Related specs

Same CSS file, documented separately for clarity:

| Pattern | See |
| :---- | :---- |
| Form section card | [Form](form.md) |
| Collapsible panel | [Sheet / Popover](sheet-popover.md) (shares surface tokens in cards CSS) |

## Accessibility requirements

1. Use headings for card titles when they introduce meaningful content.  
2. Do not create excessive nested landmarks.  
3. Clickable cards must have clear link/button semantics.  
4. Card actions should be grouped predictably.

## Examples

### Basic card

```
<section class="ss-card">
  <div class="ss-card__header">
    <h2>Vendor source</h2>
  </div>

  <div class="ss-card__body">
    <p>Ingram · Preferred · Returnable</p>
  </div>
</section>
```

### Card with footer action

```
<section class="ss-card">
  <div class="ss-card__body">
    <h2>Stored value</h2>
    <p class="ss-muted">Customer has an active balance.</p>
  </div>

  <div class="ss-card__footer">
    <%= link_to "View account", customer_stored_value_path(@customer), class: "ss-btn ss-btn-secondary ss-btn--small" %>
  </div>
</section>
```

### Sidebar card

```
<div class="ss-sidebar-card">
  <h2>Document facts</h2>
  <%= render "orders/shared/sidebar_facts", record: @purchase_order %>
</div>
```

### Summary block

```
<dl class="ss-summary">
  <dt class="ss-summary__label">Vendor</dt>
  <dd class="ss-summary__value"><%= @purchase_order.vendor.name %></dd>

  <dt class="ss-summary__label">Status</dt>
  <dd class="ss-summary__value"><%= purchase_order_status_badge(@purchase_order) %></dd>
</dl>
```

### Card grid

```
<div class="ss-card-grid">
  <% @setup_links.each do |link| %>
    <section class="ss-card ss-card--clickable">
      ...
    </section>
  <% end %>
</div>
```

## Migration notes

Do not wrap every component in a card. Use cards where grouping improves comprehension.  