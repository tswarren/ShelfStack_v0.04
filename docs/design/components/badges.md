# Badges / Status Badges / Pills

| Field | Value |
| ----- | ----- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.badges.css` |
| Planned partials | `app/views/shared/ui/_badge.html.erb`, `_status_badge.html.erb`, `_pill.html.erb` |
| Related | Alert, Table, Summary, Button |
| Design-system priority | Priority 2 |

Badges, status badges, pills, and status dots communicate compact metadata, state, counts, and classifications.

---

## Purpose

Use these components for small, scannable labels that help users understand state or category without interrupting the workflow.

```text
Badge        = compact metadata or count
Status badge = lifecycle/business state
Pill         = category, tag, or grouping label
Status dot   = very compact state indicator paired with text
```

---

## Use for

| Pattern | Use case | Example |
| ------- | -------- | ------- |
| Badge | Short metadata or count | `Used`, `3 open`, `Low stock` |
| Status badge | Operational/lifecycle state | `Draft`, `Posted`, `Closed`, `Active` |
| Pill | Category/filter/tag metadata | `Staff Picks`, `History`, `Ingram` |
| Status dot | Compact state marker next to text | active/inactive/warning/error indicator |

---

## Do not use for

| Avoid using Badge/Pill for | Use instead |
| -------------------------- | ----------- |
| Clickable primary action | Button |
| Persistent warning | Alert / Attention Panel |
| Full explanation | Help text / Card |
| Table cell action | Row/Table action |
| Current page title | Page Header |
| Form field value | Input / Select |
| Menu row action | Dropdown Menu item |

A badge can be inside a link or button when the surrounding component owns the interaction, but the badge itself should not become the action pattern.

---

## Implemented CSS

```css
.ss-pill
.ss-status-badge
.ss-badge

.ss-badge--success
.ss-badge--primary
.ss-badge--warning
.ss-badge--muted
.ss-badge--error

.ss-pill--primary
.ss-pill--gold

.ss-status-badge.status-active
.ss-status-badge.status-submitted
.ss-status-badge.status-posted
.ss-status-badge.status-warning
.ss-status-badge.status-partial
.ss-status-badge.status-partially_received
.ss-status-badge.status-partially_ordered
.ss-status-badge.status-inactive
.ss-status-badge.status-draft
.ss-status-badge.status-cancelled
.ss-status-badge.status-closed
.ss-status-badge.status-error

.ss-status-dot
.ss-status-dot--success
.ss-status-dot--warning
.ss-status-dot--error
.ss-status-dot--muted
```

Use `.status-*` only for business/domain states. Use `.is-*` for temporary UI state.

---

## Rails partials

Current status:

```text
Status: CSS only
```

Suggested future APIs:

```erb
<%= render "shared/ui/status_badge", label: "Posted", status: :posted %>
<%= render "shared/ui/badge", label: "Low stock", variant: :warning %>
<%= render "shared/ui/pill", label: "Staff Picks", variant: :primary %>
```

Do not introduce partials until helper usage stabilizes across items, orders, POS, and reports.

---

## Accessibility requirements

1. Badge text must communicate the state without relying on color alone.
2. Status badges should use clear text labels.
3. Do not use a dot without adjacent readable text unless the state is repeated elsewhere.
4. Keep badge labels short.
5. Do not use badges as buttons. If the label is interactive, wrap it in a link/button with clear semantics.

---

## Examples

### Simple badge

```erb
<span class="ss-badge">Used</span>
```

### Warning badge

```erb
<span class="ss-badge ss-badge--warning">Low stock</span>
```

### Status badge

```erb
<span class="ss-status-badge status-posted">Posted</span>
```

### Pill

```erb
<span class="ss-pill ss-pill--primary">Staff Picks</span>
```

### Status dot with text

```erb
<span class="ss-status-dot ss-status-dot--success" aria-hidden="true"></span>
<span>Active</span>
```

---

## Migration notes

Avoid inventing one-off status colors. Prefer existing badge/status classes and helper-level mapping. If a domain needs a new status, add a semantic `.status-*` mapping once and reuse it consistently.
