# Alert

| Field | Value |
| :---- | :---- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.alerts.css` |
| Planned partial | `app/views/shared/ui/_alert.html.erb` |
| Related | Flash, Toast, Field Error, POS local alert |
| Design-system priority | Priority 1 |

Alerts communicate a condition that is true **right now** on the current screen.

## Purpose

Use alerts for persistent, contextual information that should remain visible until the condition is resolved.

```
Flash = what happened after navigation
Toast = what happened inline
Alert = what is true now
```

## Use for

| Use case | Example |
| :---- | :---- |
| Missing setup | No tax rate configured |
| Posting blocker | Receipt has rejected lines |
| Operational warning | Negative on-hand quantity |
| Permission context | You can view but not post |
| Data quality issue | Missing primary identifier |
| Risk notice | Closing register with variance |

## Do not use for

| Avoid using Alert for | Use instead |
| :---- | :---- |
| Redirect result | Flash |
| Small inline success | Toast |
| Field-level error | Field error |
| Static status | Badge |
| Destructive confirmation | Alert Dialog |
| POS-only workspace state | POS local alert when appropriate |

## Variants

```css
.ss-alert
.ss-alert--info
.ss-alert--success
.ss-alert--warning
.ss-alert--error
.ss-alert--neutral
```

## Rails partial

Current status:

```
Status: CSS only
```

Planned path:

```
app/views/shared/ui/_alert.html.erb
```

Suggested future API:

```
<%= render "shared/ui/alert",
      variant: :warning,
      title: "Missing vendor source",
      message: "This variant can be ordered, but no vendor source is configured." %>
```

## Accessibility requirements

1. Use alert semantics for urgent errors only.  
2. Non-urgent alerts should not steal focus.  
3. Alert title should be concise.  
4. Actionable alerts should include a clear next action.  
5. Do not rely on color alone.  
6. Alerts should be near the affected workflow.

## Examples

### Warning alert

```
<div class="ss-alert ss-alert--warning">
  <strong>Missing vendor source.</strong>
  Add a vendor source before relying on automatic purchasing defaults.
</div>
```

### Error alert

```
<div class="ss-alert ss-alert--error" role="alert">
  Receipt cannot be posted until rejected quantities include a reason.
</div>
```

### Alert with action

```
<div class="ss-alert ss-alert--warning">
  <div>
    <strong>No workstation assigned.</strong>
    Select a workstation before opening POS.
  </div>
  <%= link_to "Assign workstation", new_workstation_assignment_path, class: "ss-btn ss-btn-secondary ss-btn--small" %>
</div>
```

## Migration notes

Migrate legacy `.flash-alert` blocks used for persistent page conditions into `.ss-alert--error` or `.ss-alert--warning`.  