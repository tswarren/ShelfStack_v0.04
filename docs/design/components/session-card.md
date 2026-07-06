# Session Card

| Field | Value |
| :---- | :---- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.session.css` |
| Planned partial | `app/views/shared/ui/_session_card.html.erb` |
| Related | Access Notice, Form, Button |
| Design-system priority | Priority 1 |

Session cards are focused authentication/session surfaces.

## Purpose

Use session cards for login, unlock, PIN, password, and workstation assignment workflows.

## Use for

| Use case | Example |
| :---- | :---- |
| Login | Username/password |
| Unlock | PIN/password unlock |
| Set PIN | User PIN setup |
| Change password | Password update |
| Workstation assignment | Select workstation |
| Locked session | Unlock or logout |

## Do not use for

| Avoid using Session Card for | Use instead |
| :---- | :---- |
| General setup forms | Form / Card |
| Access denied page | Access Notice |
| POS register session panel | POS workspace component |
| Dashboard cards | Card / Surface |

## CSS

```css
.ss-session-card
.ss-auth-box
.ss-session-card__title
.ss-session-card__body
.ss-session-card__actions
```

## Accessibility requirements

1. Keep the page focused on one session task.  
2. Use clear heading and form labels.  
3. Support password managers where appropriate.  
4. Do not hide critical session errors in toast.  
5. Primary action should be obvious.

## Example

```
<section class="ss-session-card" aria-labelledby="session-title">
  <h1 id="session-title">Unlock Session</h1>

  <%= form_with url: session_unlock_path, class: "ss-form" do |form| %>
    <div class="ss-field">
      <%= form.label :pin, "PIN", class: "ss-field-label" %>
      <%= form.password_field :pin, class: "ss-input", autocomplete: "current-password" %>
    </div>

    <div class="ss-form-actions">
      <%= form.submit "Unlock", class: "ss-btn ss-btn-primary" %>
      <%= button_to "Logout", logout_path, method: :delete, class: "ss-btn ss-btn-tertiary" %>
    </div>
  <% end %>
</section>
```

## Migration notes

Auth/session layouts may still use legacy flash markup. Migrate toward shared flash for page-level results and inline alert for persistent form/session errors.