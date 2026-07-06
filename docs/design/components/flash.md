# Flash

| Field | Value |
| :---- | :---- |
| Status | Partial exists |
| CSS | `app/assets/stylesheets/shelfstack.components.feedback.css` |
| Current partial | `app/views/shared/feedback/_flash_region.html.erb` |
| Helper | `shelfstack_flash_class` in `ApplicationHelper` |
| Related | Toast, Alert, Field Error |
| Design-system priority | Priority 1 |

See also — other classes in `shelfstack.components.feedback.css`:

| Spec | Covers |
| :---- | :---- |
| [Empty State](empty-state.md) | `.ss-empty-state*` |
| [Progress / Skeleton](progress-skeleton.md) | `.ss-progress*`, `.ss-skeleton` |

Flash messages communicate page-level results after navigation or redirect.

## Purpose

Use flash for server-driven outcomes the user should see when the page loads.

```
Flash = what happened after navigation
Toast = what happened inline
Alert = what is true now
```

## Use for

| Use case | Example |
| :---- | :---- |
| Successful save | Vendor updated |
| Failed action | Could not post receipt |
| Permission denial after redirect | Access denied |
| Workflow completion | Purchase order submitted |
| Warning after redirect | Record saved with warnings |

## Do not use for

| Avoid using Flash for | Use instead |
| :---- | :---- |
| Inline Turbo result | Toast |
| Persistent page condition | Alert |
| Field validation on same page | Field error / form-level alert |
| POS workspace state | POS local alert |
| Auth layout (current) | Migrate to `flash_region` or session-scoped alert |

## CSS

### Implemented (`shelfstack.components.feedback.css`)

```css
.ss-flash-region
.ss-flash
.ss-flash__message
.ss-flash__dismiss
.ss-flash--success
.ss-flash--warning
.ss-flash--error
.ss-flash--info
```

Legacy `.flash`, `.flash-notice`, `.flash-warning`, and `.flash-alert` selectors remain in the same file for migration compatibility.

### Helper output

`shelfstack_flash_class` emits combined classes for transitional styling:

```
ss-flash ss-alert ss-alert--<variant> ss-flash--<variant>
```

Variants map from Rails flash keys: `notice`/`success` → success, `warning` → warning, `alert`/`error` → error.

## Rails partial

Current path:

```
app/views/shared/feedback/_flash_region.html.erb
```

Included from `layouts/application.html.erb` and `layouts/pos.html.erb`.

Reads flash keys: `notice`, `success`, `warning`, `alert`, `error`.

## Accessibility requirements

1. Flash region uses `role="status"` and `aria-live="polite"`.  
2. Dismiss control must have an accessible name (`aria-label="Dismiss message"`).  
3. Do not rely on flash as the only place critical errors appear; pair with field errors or alerts when the user must act.  
4. Keep messages concise and action-oriented.

## Examples

### Layout include

```
<%= render "shared/feedback/flash_region" %>
```

### Controller flash

```ruby
redirect_to setup_vendors_path, notice: "Vendor saved."
redirect_to setup_vendors_path, alert: "Vendor could not be saved."
```

## Migration notes

| File | Issue | Target |
| ---- | ----- | ------ |
| `layouts/auth.html.erb` | Inline `.flash.flash-*` | `flash_region` partial or `.ss-alert--*` |
| `shared/forms/_errors.html.erb` | `.flash.flash-alert` for validation summary | `.ss-alert--error` or per-field errors |

Do not convert flash to toast just to reduce visual weight. Flash is for post-navigation results; toast is for inline actions.
