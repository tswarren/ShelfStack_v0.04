# Access Notice

| Field | Value |
| :---- | :---- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.access.css` |
| Planned partial | `app/views/shared/ui/_access_notice.html.erb` |
| Related | Alert, Session Card |
| Design-system priority | Priority 1 |

Access notices explain why a user cannot access a workspace, page, or action.

## Purpose

Use access notices for permission, workstation, session, or readiness blocks.

## Use for

| Use case | Example |
| :---- | :---- |
| Permission denied | You do not have access to Setup |
| POS unavailable | No register session is open |
| Workstation missing | Select a workstation to continue |
| Role-limited area | Inventory access required |
| Locked workflow | Session must be unlocked |

## Do not use for

| Avoid using Access Notice for | Use instead |
| :---- | :---- |
| Form validation | Field error / Alert |
| Page-level success/failure | Flash |
| Small inline denial | Toast or disabled action explanation |
| Static permission badge | Badge |
| Login/unlock form | Session Card |

## CSS

```css
.ss-access-notice
.ss-access-notice__title
.ss-access-notice__body
.ss-access-notice__actions
```

## Accessibility requirements

1. State the problem clearly.  
2. Provide next steps when available.  
3. Do not expose internal permission details unless useful to staff/admin.  
4. Keep blocked actions non-interactive.  
5. Use heading structure so the notice is easy to scan.

## Example

```
<section class="ss-access-notice" aria-labelledby="access-notice-title">
  <h1 id="access-notice-title" class="ss-access-notice__title">
    POS access required
  </h1>

  <p class="ss-access-notice__body">
    You do not have permission to open the register from this workstation.
  </p>

  <div class="ss-access-notice__actions">
    <%= link_to "Return to Dashboard", root_path, class: "ss-btn ss-btn-tertiary" %>
  </div>
</section>
```

## Migration notes

Use this for whole-page access/readiness blocks. Use inline alerts for local blockers inside otherwise accessible pages.
