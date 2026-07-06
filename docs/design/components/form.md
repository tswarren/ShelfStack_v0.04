# Form

| Field | Value |
| :---- | :---- |
| Status | Partial exists |
| CSS | `app/assets/stylesheets/shelfstack.components.forms.css` |
| Current partials | `app/views/shared/forms/_section.html.erb`, `_field.html.erb`, `_page_header.html.erb`, `_errors.html.erb` |
| Planned generic partial | `app/views/shared/ui/_form.html.erb` only if needed later |
| Related | Field, Input, Select, Alert, Page Header |
| Design-system priority | Priority 1 |

See also — other classes in `shelfstack.components.forms.css`:

| Spec | Covers |
| :---- | :---- |
| [Textarea](textarea.md) | `.ss-textarea` |
| [Fieldset](fieldset.md) | `.ss-fieldset*` |
| [Choice controls](choice-controls.md) | Checkbox, radio, choice lists |

Forms collect, validate, and submit user input.

## Purpose

Use forms for creating, editing, filtering, posting, or configuring records.

ShelfStack forms should support:

```text
clear grouping
visible validation
predictable submit/cancel placement
keyboard-friendly entry
dense operational workflows
```

## Use for

| Use case | Example |
| :---- | :---- |
| Setup CRUD | Stores, tax rates, departments |
| Item setup | Product metadata, identifiers, variant settings |
| Purchasing | PO lines, receipt lines, vendor sources |
| POS support | Tender entry, customer lookup, open-ring line |
| Reports | Filters and date ranges |
| Session/account | Login, unlock, password, PIN |

## Do not use for

| Avoid using Form for | Use instead |
| :---- | :---- |
| Static display | Card / Summary |
| Read-only status | Badge / alert / panel |
| One-off inline command | Button |
| Table-only display | Table / Data Table |
| Navigation choice | Link / tabs / nav |

## Structure

Recommended order:

```text
Page header
Form-level alert/errors
Sections
Fields
Inline help
Actions
```

## CSS

```text
app/assets/stylesheets/shelfstack.components.forms.css
```

### Implemented (`shelfstack.components.forms.css`)

```css
.ss-form
.ss-form-card
.ss-form-card-header
.ss-form-card-body
.ss-form-grid
.ss-form-actions
.ss-form-actions--end
.ss-form-actions--between
.ss-inline-form
.ss-field
.ss-field-error
.ss-field-warning
.ss-label
.ss-help
.ss-input
.ss-select
.ss-textarea
```

### Helper-emitted / legacy-styled (`shelfstack.css` until extracted)

```css
.ss-field--error
```

Emitted by `ss_field_css` when the record has errors on that field. Error-border styling for nested inputs is not yet in modular forms CSS. See [field.md](field.md).

### Legacy only

```css
.ss-form-section
```

`shared/forms/_section.html.erb` emits **`.ss-form-card`**, not `.ss-form-section`. `.ss-form-section` exists only in legacy `shelfstack.css`; do not use it in new markup.

## Inline form

Use `.ss-inline-form` for Rails `button_to` forms that must sit inline inside another component, such as dropdown menu rows, footer utilities, compact table actions, and small action clusters.

Do not use `.ss-inline-form` for normal data-entry forms.

Good uses:

```text
logout inside user menu
Lock Session in footer
small destructive row action
button_to inside dropdown menu
```

Avoid:

```text
full setup form
filter form
receipt posting form with fields
multi-field workflow form
```

## Rails partials

Current active form partials:

```text
app/views/shared/forms/_page_header.html.erb
app/views/shared/forms/_section.html.erb
app/views/shared/forms/_field.html.erb
app/views/shared/forms/_errors.html.erb
```

Prefer these for form-heavy setup and workflow pages.

## Accessibility requirements

1. Every input must have an associated label.
2. Required fields must be visually and semantically clear.
3. Validation errors must be close to the affected field.
4. Form-level errors should use inline alert treatment, not global flash.
5. Submit button text should describe the result.
6. Cancel/back actions should be links or tertiary buttons.
7. Keyboard tab order should follow visual order.
8. Inline forms must not disrupt menu/list semantics.

## Examples

### Standard form shell

```erb
<%= form_with model: @vendor, class: "ss-form" do |form| %>
  <%= render "shared/forms/errors", object: @vendor %>

  <%= render "shared/forms/section", title: "Vendor details" do %>
    <%= render layout: "shared/forms/field",
          locals: { f: form, record: @vendor, field: :name, required: true } do %>
      <%= form.text_field :name, class: "ss-input" %>
    <% end %>
  <% end %>

  <div class="ss-form-actions">
    <%= form.submit "Save Vendor", class: "ss-btn ss-btn-primary" %>
    <%= link_to "Cancel", setup_vendors_path, class: "ss-btn ss-btn-tertiary" %>
  </div>
<% end %>
```

### Inline form inside a dropdown menu

```erb
<%= button_to "Logout",
      logout_path,
      method: :delete,
      class: "ss-dropdown-menu__item ss-dropdown-menu__item--danger",
      form: { class: "ss-inline-form" } %>
```

### Inline form in the footer

```erb
<%= button_to "Lock Session",
      session_lock_path,
      method: :post,
      class: "ss-btn ss-btn-ghost ss-btn--small",
      form: { class: "ss-inline-form ss-footer__lock-form" } %>
```

## Migration notes

Keep `shared/forms/*` as the current form foundation. Do not invent a parallel `shared/ui/form` API until the current form partials are either promoted or replaced.

When touching compact `button_to` markup inside menus, footers, or row actions, add `.ss-inline-form` to prevent Rails’ generated form wrapper from disrupting layout.
