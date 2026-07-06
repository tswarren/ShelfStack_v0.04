# Card / Surface

| Field | Value |
| :---- | :---- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.cards.css` |
| Planned partial | `app/views/shared/ui/_card.html.erb` |
| Related | Page Header, Alert, Metric Card |
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

```css
.ss-card
.ss-card__header
.ss-card__body
.ss-card__footer
.ss-surface
.ss-surface--muted
.ss-surface--strong
```

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

## Migration notes

Do not wrap every component in a card. Use cards where grouping improves comprehension.  