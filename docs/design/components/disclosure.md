# Disclosure / Accordion / Details

| Field | Value |
| ----- | ----- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.disclosure.css` |
| Planned partials | `shared/ui/_collapsible_panel.html.erb`, `_accordion.html.erb` only after behavior stabilizes |
| Related | Navigation, Card / Surface, Drawer, Table |
| Design-system priority | Priority 2 |

Disclosure components show and hide supporting content while keeping the user on the same page.

---

## Purpose

Use disclosure when secondary content is helpful but does not need to be visible all the time.

Disclosure should answer:

```text
What can I expand for more detail?
What is currently open?
Is anything hidden that blocks the workflow?
```

---

## Use for

| Pattern | Use case | Example |
| ------- | -------- | ------- |
| Collapsible panel | Optional supporting detail | advanced filters, audit details |
| Accordion | Multiple related expandable groups | grouped warnings, setup groups |
| Details | Native details/summary style content | operational notes, line details |

---

## Do not use for

| Avoid using Disclosure for | Use instead |
| -------------------------- | ----------- |
| Required blocking warning | Alert / Attention Panel visible by default |
| Primary workflow content | Normal page content |
| Modal task | Dialog / Drawer |
| Full navigation | Tabs / Sidebar |
| Table row expansion with editing | Domain row-detail pattern |

Do not hide required errors, blocking warnings, or primary actions inside collapsed content by default.

---

## Implemented CSS

```css
.ss-collapsible-panel
.ss-collapsible-panel__summary
.ss-collapsible-panel__body

.ss-accordion
.ss-accordion-item
.ss-accordion-trigger
.ss-accordion-panel

.ss-details
.ss-details__summary
.ss-details__body
```

Native summary elements inside `.ss-collapsible-panel` are also styled.

---

## Accessibility requirements

1. Prefer native `<details>` / `<summary>` when simple disclosure is enough.
2. Trigger text must describe the hidden content.
3. Keyboard users must be able to open and close the disclosure.
4. Do not hide content that is required to complete the current workflow.
5. Accordions with custom JS should expose expanded/collapsed state.
6. Opening one panel should not unexpectedly close another unless the accordion pattern documents that behavior.

---

## Examples

### Native details

```erb
<details class="ss-details">
  <summary class="ss-details__summary">Receiving notes</summary>
  <div class="ss-details__body">
    <p>Review rejected quantities before posting.</p>
  </div>
</details>
```

### Collapsible panel

```erb
<details class="ss-collapsible-panel">
  <summary>Advanced filters</summary>
  <div class="ss-collapsible-panel__body">
    <%= render "reports/shared/advanced_filters" %>
  </div>
</details>
```

### Accordion

```erb
<div class="ss-accordion">
  <section class="ss-accordion-item">
    <button type="button" class="ss-accordion-trigger" aria-expanded="false">
      Vendor source issues
    </button>
    <div class="ss-accordion-panel" hidden>
      ...
    </div>
  </section>
</div>
```

---

## Migration notes

Keep simple disclosure native. Add JS behavior only when the page needs coordinated accordion state, keyboard roving behavior, or Turbo-aware expansion. Domain-specific expanded-row editing should live in the relevant domain CSS/interaction pattern, not generic disclosure.
