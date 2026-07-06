# Form

| Field | Value |
| :---- | :---- |
| Status | Partial exists |
| CSS | `app/assets/stylesheets/shelfstack.components.forms.css` |
| Current partials | `app/views/shared/forms/_section.html.erb`, `_field.html.erb`, `_page_header.html.erb`, `_errors.html.erb` |
| Planned generic partial | `app/views/shared/ui/_form.html.erb` only if needed later |
| Related | Field, Input, Select, Alert, Page Header |
| Design-system priority | Priority 1 |

Forms collect, validate, and submit user input.

## Purpose

Use forms for creating, editing, filtering, posting, or configuring records.

ShelfStack forms should support:

```
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

```
Page header
Form-level alert/errors
Sections
Fields
Inline help
Actions
```

## CSS

```
app/assets/stylesheets/shelfstack.components.forms.css
```

Target classes:

```css
.ss-form
.ss-form-card
.ss-form-section
.ss-form-actions
.ss-field
.ss-field--invalid
.ss-field-error
.ss-input
.ss-select
```

## Rails partials

Current active form partials:

```
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

## Examples

### Standard form shell

```
<%= form_with model: @vendor, class: "ss-form" do |form| %>
  <%= render "shared/forms/errors", object: @vendor %>

  <%= render "shared/forms/section", title: "Vendor details" do %>
    <%= render "shared/forms/field", form: form, attribute: :name do %>
      <%= form.text_field :name, class: "ss-input" %>
    <% end %>
  <% end %>

  <div class="ss-form-actions">
    <%= form.submit "Save Vendor", class: "ss-btn ss-btn-primary" %>
    <%= link_to "Cancel", setup_vendors_path, class: "ss-btn ss-btn-tertiary" %>
  </div>
<% end %>
```

## Migration notes

Keep `shared/forms/*` as the current form foundation. Do not invent a parallel `shared/ui/form` API until the current form partials are either promoted or replaced.
