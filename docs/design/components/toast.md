# Toast

| Field | Value |
| :---- | :---- |
| Status | Partial exists / interaction shell |
| CSS | `app/assets/stylesheets/shelfstack.components.feedback.css` (+ legacy bridge in `shelfstack.css`) |
| Current partials | `app/views/shared/interaction/_toast.html.erb`, `_toast_region.html.erb` |
| Related | Flash, Alert |
| Design-system priority | Priority 1 |

See also — other classes in `shelfstack.components.feedback.css`:

| Spec | Covers |
| :---- | :---- |
| [Empty State](empty-state.md) | `.ss-empty-state*` |
| [Progress / Skeleton](progress-skeleton.md) | `.ss-progress*`, `.ss-skeleton` |

Toasts are temporary, non-blocking confirmations for inline actions.

## Purpose

Use toasts for small results that happen without leaving the current screen.

## Use for

| Use case | Example |
| :---- | :---- |
| Inline save | Draft saved |
| Copy action | Copied |
| POS support action | Customer attached |
| Turbo update | Quantity updated |
| View preference | View changed |
| Background refresh | Gift card balance refreshed |

## Do not use for

| Avoid using Toast for | Use instead |
| :---- | :---- |
| Redirect result | Flash |
| Persistent warning | Alert |
| Blocking error | Alert / inline error |
| Field validation | Field error |
| Destructive confirmation | Alert Dialog |
| Critical POS completion result | Flash or POS-specific result panel |

## CSS

### Implemented in `shelfstack.components.feedback.css`

```css
.ss-toast-region
.ss-toast
.ss-toast--success
.ss-toast--warning
.ss-toast--error
```

Success, warning, and error variants share color rules with `.ss-flash--*` in the same file.

### Legacy bridge (`shelfstack.css`)

The toast partial also emits these classes, which are **not yet** in modular feedback CSS:

```css
.ss-toast--info
.ss-toast__message
.ss-toast__dismiss
```

They work today because legacy `shelfstack.css` loads after the component layer. New toast work should assume these move into `shelfstack.components.feedback.css` during Phase 10-E extraction.

## Behavior

```
Auto-dismiss: yes
Manual dismiss: preferred
Steals focus: no
Blocks workflow: no
Safe to miss: yes
```

## Accessibility requirements

1. Use polite live-region behavior.  
2. Do not move focus to the toast.  
3. Toast text must be brief.  
4. Errors that require action should not be toast-only.  
5. User must not need the toast to continue safely.

## Examples

### Toast region

```
<%= render "shared/interaction/toast_region" %>
```

### Toast item

```
<%= render "shared/interaction/toast",
      message: "Customer attached.",
      variant: :success %>
```

## Migration notes

Do not convert flash messages to toasts just to reduce visual weight. First decide whether the message is page-level, inline, or persistent.

Extract `.ss-toast--info`, `.ss-toast__message`, and `.ss-toast__dismiss` from legacy CSS into `shelfstack.components.feedback.css` when touching toast styling.
