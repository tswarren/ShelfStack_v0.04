# Filter Chip

| Field | Value |
| ----- | ----- |
| Status | Planned / missing modular CSS |
| Target CSS home | `app/assets/stylesheets/shelfstack.components.data-tables.css` or future `shelfstack.components.filters.css` |
| Planned partial | `app/views/shared/ui/_filter_chip.html.erb` only after CSS exists |
| Related | Data Tables, Badges, Buttons, Navigation |
| Design-system priority | Priority 3 pattern cleanup |

Filter chips represent applied filters, selectable queue filters, or removable search refinements.

---

## Current reality

`filter-chip` is a named pattern in the design guidance, but modular CSS is not currently defined for `.ss-filter-chip`.

Do not treat filter chips as implemented until CSS exists.

---

## Purpose

Use filter chips to make filter state visible and easy to adjust.

A filter chip should answer:

```text
Which filter is active?
Can I remove or toggle it?
How is this different from a badge, tab, or button?
```

---

## Use for

| Use case | Example |
| -------- | ------- |
| Applied filter | `Status: Open` |
| Removable search refinement | `Vendor: Ingram ×` |
| Queue filter | `Needs review` |
| Compact filter state | `Used only`, `Backordered` |

---

## Do not use for

| Avoid using Filter Chip for | Use instead |
| --------------------------- | ----------- |
| Static metadata | Badge / Pill |
| Page or section navigation | Tabs / Nav |
| Primary action | Button |
| POS sale/return/pickup mode | POS mode switch domain component |
| Domain status | Status Badge |
| Long filter forms | Filter Bar / Form |

---

## Relationship to nearby patterns

| Pattern | Meaning |
| ------- | ------- |
| Badge | Static metadata/state |
| Status Badge | Domain/business lifecycle state |
| Filter Chip | Applied or selectable filter state |
| Tab | Page/section navigation |
| Button | Action |

---

## Planned CSS contract

Add modular CSS before using this class in new markup:

```css
.ss-filter-chip
.ss-filter-chip--active
.ss-filter-chip--removable
.ss-filter-chip__label
.ss-filter-chip__remove
```

Optional future states, only if needed:

```css
.ss-filter-chip--disabled
.ss-filter-chip--warning
```

---

## Planned Rails partial

Suggested future API:

```erb
<%= render "shared/ui/filter_chip",
      label: "Status: Open",
      active: true,
      removable: true,
      remove_url: items_path(params.except(:status)) %>
```

Do not introduce the partial until the CSS contract exists and at least two workflows need the same markup.

---

## Accessibility requirements

1. Removable chips must expose a clear accessible label, such as `Remove Status: Open filter`.
2. Selectable chips must expose selected state with `aria-pressed` or a suitable filter/listbox pattern.
3. Do not rely on color alone to show active state.
4. Chip text must be short enough to scan.
5. Removing a chip should update the filtered results and preserve focus predictably.

---

## Examples

### Planned removable chip

```erb
<span class="ss-filter-chip ss-filter-chip--active ss-filter-chip--removable">
  <span class="ss-filter-chip__label">Status: Open</span>
  <%= link_to "×",
        items_path(params.except(:status)),
        class: "ss-filter-chip__remove",
        aria: { label: "Remove Status: Open filter" } %>
</span>
```

### Planned selectable chip

```erb
<button type="button"
        class="ss-filter-chip ss-filter-chip--active"
        aria-pressed="true">
  Needs review
</button>
```

---

## Migration notes

This is a documentation placeholder until CSS is implemented. The recommended implementation home is `shelfstack.components.data-tables.css` if chips remain tied to filters/data-table work. Use a separate `shelfstack.components.filters.css` only if filter patterns become broad enough to justify a new component file.
