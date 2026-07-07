# v0.04-14 Design System UX Migration — Data Model

## Status

**Active** — presentation milestone; no core schema redesign.

---

## Schema policy

**No new core tables** for v0.04-14.

### Permitted additions (only if needed during implementation)

| Addition | Reason |
| -------- | ------ |
| None expected | Migration is views, partials, CSS, and helpers |

### Do not add

* Domain tables for demand, sourcing, PO, receiving, or catalog
* New authentication or session tables
* Component configuration tables (use ERB partials and CSS conventions)

---

## Presentation-layer contract

Authoritative references:

```text
docs/design/components.md
docs/design/components/*
app/assets/stylesheets/shelfstack.components.*.css
app/assets/stylesheets/shelfstack.domain.*.css
app/assets/stylesheets/README.md
```

Legacy `shelfstack.css` remains as a bridge until rules are extracted during surface migration.

---

## Enabling partials (v0.04-14 deliverables)

```text
app/views/shared/ui/_button.html.erb
app/views/shared/ui/_page_header.html.erb
app/views/shared/ui/_alert.html.erb
app/views/shared/ui/_empty_state.html.erb
shared/forms/_errors.html.erb          (revised)
shared/forms/_field.html.erb           (warning + aria-describedby)
ss_status_badge helper
```

`shared/forms/_page_header.html.erb` delegates to `shared/ui/page_header`.
