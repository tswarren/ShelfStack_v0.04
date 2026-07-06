# Session Card

| Field | Value |
| :---- | :---- |
| Status | Mixed / legacy |
| CSS | `app/assets/stylesheets/shelfstack.components.session.css` (target); `.ss-auth-box` in legacy `shelfstack.css` (current auth layout) |
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

### Implemented (target)

```css
.ss-session-screen
.ss-session-card
.ss-session-card__brand
.ss-session-card__title
.ss-session-card__description
.ss-session-card__context
.ss-session-card__actions
.ss-session-card__secondary-actions
```

Use `__description` or `__context` for supporting copy. There is no `__body` element class.

### Legacy (current auth layout)

```css
.ss-auth-box
.ss-auth-logo
.ss-auth-context
```

`layouts/auth.html.erb` still wraps session pages in `.ss-auth-box`, not `.ss-session-card`. New auth work should migrate toward session-card classes when touching that layout.

## Accessibility requirements

1. Keep the page focused on one session task.  
2. Use clear heading and form labels.  
3. Support password managers where appropriate.  
4. Do not hide critical session errors in toast.  
5. Primary action should be obvious.

## Example

```
<section class="ss-session-card" aria-labelledby="session-title">
  <h1 id="session-title" class="ss-session-card__title">Unlock Session</h1>

  <%= form_with url: session_unlock_path, class: "ss-form" do |form| %>
    <div class="ss-field">
      <%= form.label :pin, "PIN", class: "ss-label" %>
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

Auth/session layouts may still use legacy `.ss-auth-box` and inline `.flash.flash-*` blocks. Migrate toward `.ss-session-card` markup and shared flash for page-level results when editing auth screens.
