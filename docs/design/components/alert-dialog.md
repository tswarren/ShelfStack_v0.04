# Alert Dialog

| Field | Value |
| :---- | :---- |
| Status | CSS only / planned |
| CSS | `app/assets/stylesheets/shelfstack.components.overlays.css` |
| Planned partial | `app/views/shared/ui/_alert_dialog.html.erb` |
| Related | Dialog, Button, Alert |
| Design-system priority | Priority 1 |

Alert dialogs require a deliberate decision before a risky action proceeds.

## Purpose

Use alert dialogs for destructive, irreversible, money-affecting, inventory-affecting, or register-affecting actions.

## Use for

| Use case | Example |
| :---- | :---- |
| POS risk | Void Transaction |
| Register risk | Close Register with Variance |
| Inventory risk | Post Adjustment |
| Receiving risk | Post Receipt |
| Purchasing risk | Cancel PO |
| Setup risk | Inactivate record with dependencies |

## Do not use for

| Avoid using Alert Dialog for | Use instead |
| :---- | :---- |
| Routine save | Button |
| Low-risk delete draft | `turbo_confirm` may suffice |
| Persistent warning | Alert |
| Informational modal | Dialog |
| Inline validation | Field error |

## Variants

### Implemented (`shelfstack.components.overlays.css`)

```css
.ss-alert-dialog
.ss-alert-dialog--danger
.ss-alert-dialog__backdrop
.ss-alert-dialog__panel
.ss-alert-dialog__header
.ss-alert-dialog__body
.ss-alert-dialog__footer
```

Structure tokens exist; no alert-dialog partial or live markup yet.

### Planned

```css
.ss-alert-dialog--warning
```

Not in CSS yet. Use `--danger` for high-risk confirmations until a warning variant is added.

## Risk pattern

| Risk level | Pattern |
| :---- | :---- |
| Low/medium, reversible, narrow scope | `data: { turbo_confirm: "..." }` may suffice |
| High-risk, irreversible, money/inventory/register effects | Alert Dialog |

## Planned partial API

```
<%= render "shared/ui/alert_dialog",
      id: "void-transaction-dialog",
      variant: :danger,
      title: "Void transaction?",
      confirm_label: "Void Transaction",
      cancel_label: "Keep Transaction" do %>
  This will reverse tenders and inventory effects.
<% end %>
```

## Accessibility requirements

1. Must have accessible title and description.  
2. Must trap focus.  
3. Initial focus should generally land on the safest action unless workflow dictates otherwise.  
4. Confirm action must be specific, not “OK.”  
5. Danger action must be visually distinct.  
6. Escape/cancel must be available unless action is mandatory.  
7. Alert dialog must not be used for routine information.

## Example target markup

```
<div class="ss-alert-dialog ss-alert-dialog--danger" role="alertdialog" aria-modal="true" aria-labelledby="void-title" aria-describedby="void-description">
  <div class="ss-alert-dialog__panel">
    <div class="ss-alert-dialog__header">
      <h2 id="void-title">Void transaction?</h2>
    </div>

    <div id="void-description" class="ss-alert-dialog__body">
      This will reverse tenders and inventory effects. This action should only be used when the transaction must be cancelled.
    </div>

    <div class="ss-alert-dialog__footer">
      <button type="button" class="ss-btn ss-btn-tertiary">Keep Transaction</button>
      <%= button_to "Void Transaction",
            pos_transaction_path(@transaction),
            method: :delete,
            class: "ss-btn ss-btn--danger" %>
    </div>
  </div>
</div>
```

## Migration notes

Do not rely on browser confirm long-term for posting, voiding, register closing, tender reversal, or inventory-affecting operations. Use `turbo_confirm` only as an interim/simple-risk pattern until Alert Dialog is implemented.
