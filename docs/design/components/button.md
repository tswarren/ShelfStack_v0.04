# Button

| Field | Value |
| :---- | :---- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.buttons.css` |
| Planned partial | `app/views/shared/ui/_button.html.erb` |
| Related | `.ss-button-group`, `.ss-button-group--segmented`, `.ss-dropdown-menu__item`, `.ss-pos-mode-switch__btn`, `.ss-pos-complete-btn` |
| Design-system priority | Priority 1 |

Buttons trigger actions. They are used when the user is asking ShelfStack to **do something**, such as save, submit, post, void, open a modal, add a line, tender a payment, or close a register session.

Buttons should make action hierarchy clear:

```
Primary action     = what the user is most likely trying to complete
Secondary action   = important alternate action
Tertiary action    = lower-emphasis support action
Ghost action       = persistent utility action with very low visual weight
Danger action      = destructive, irreversible, or high-risk action
Link action        = inline or very low-emphasis action
```

`.ss-btn` without a variant currently renders with **primary styling** because `.ss-btn` and `.ss-btn-primary` share the same base rule. For new markup, always add an explicit variant class so intent is clear in code review.

---

## Purpose

Use buttons for actions that change state, submit data, start a workflow, open an interaction, or run a command.

ShelfStack buttons must support dense operational workflows, keyboard/scanner-heavy use, and clear risk hierarchy. A bookseller should be able to distinguish routine actions from irreversible posting, voiding, register, or inventory-affecting actions without reading surrounding code.

---

## Use for

Use a button when the user action changes state, starts a workflow, opens an interaction, or submits data.

| Use case | Example |
| :---- | :---- |
| Submit a form | Save Item, Create Vendor, Update Tax Rate |
| Move a workflow forward | Submit PO, Receive All, Post Receipt |
| Trigger a POS action | Add Open Ring, Add Gift Card, Complete Sale |
| Open an overlay | Edit Price, Attach Customer, Add Identifier |
| Confirm a risky operation | Void Transaction, Close Register |
| Run a command | Search, Apply Filters, Recalculate Totals |
| Utility action | Lock Session |

---

## Do not use for

Do not use buttons for passive information, static status, normal navigation that should read as a link, or specialized controls that have their own component pattern.

| Avoid using Button for | Use instead |
| :---- | :---- |
| Static status labels | Badge or status badge |
| “Active,” “Posted,” “Closed” | `.ss-status-badge` / `.status-*` |
| Normal navigation inside text | Link |
| Metadata chips | Pill or badge |
| Inline explanatory text | Plain text or help text |
| Current filter labels | Pill or filter chip |
| Dropdown/menu row actions | `.ss-dropdown-menu__item` |
| Filter tabs / queue chips | `.ss-filter-chip` (used in views; **CSS not defined yet**) or the relevant filter component |
| POS sale/return/pickup mode | `.ss-pos-mode-switch__btn` |
| Segmented mutually exclusive modes | `.ss-button-group--segmented` or toggle group |
| Non-action table values | Text, badge, or link |

Avoid making every link look like a button. Button styling should be reserved for actions that need clear action affordance.

---

## Variants

### Primary

Use for the single most important action in a page, form, dialog, or workflow section.

```
<%= button_tag "Save Item", class: "ss-btn ss-btn-primary" %>
```

Examples:

```
Save Item
Create Customer
Post Receipt
Complete Sale
Submit PO
```

Rule:

```
One primary button per immediate decision area.
```

A page can have more than one primary button only when actions are in clearly separate regions, such as a main form and an unrelated sidebar card.

---

### Secondary

Use for important alternate actions that are not the main path.

```
<%= link_to "Preview Receipt", receipt_path, class: "ss-btn ss-btn-secondary" %>
```

Examples:

```
Preview
Receive Selected
Add Another
Print
Reopen Draft
```

Secondary buttons should not compete with the primary action.

---

### Tertiary

Use for low-emphasis support actions, especially cancel/back/close actions.

```
<%= link_to "Cancel", items_root_path, class: "ss-btn ss-btn-tertiary" %>
```

Examples:

```
Cancel
Back
Close
Clear Filters
Return to Item
```

Tertiary is still visually button-like, but it should not dominate the action row.

---

### Ghost

Use for persistent utilities that must remain accessible but should not compete with page content.

```
<%= button_to "Lock Session",
      session_lock_path,
      method: :post,
      params: { return_to: request.fullpath },
      class: "ss-btn ss-btn-ghost ss-btn--small",
      form: { class: "ss-inline-form" } %>
```

Examples:

```
Lock Session
Dismiss Panel
Show Details
Hide Details
```

Ghost buttons are especially useful in the app shell, footer, and supporting panels.

---

### Danger

Use for destructive, irreversible, or high-risk actions.

```
<%= button_to "Void Transaction",
      pos_transaction_path(transaction),
      method: :delete,
      class: "ss-btn ss-btn--danger" %>
```

Examples:

```
Void Transaction
Delete Draft
Cancel PO
Close Register with Variance
Remove Role
Deactivate Store
```

Danger buttons should be visually distinct and clearly worded. Avoid vague labels such as “Confirm” or “OK” for destructive actions.

#### Confirmation pattern by risk level

| Risk level | Pattern |
| :---- | :---- |
| Low/medium risk, reversible, narrow blast radius | `data: { turbo_confirm: "..." }` may suffice |
| High risk, irreversible, inventory-affecting, money-affecting, register-affecting | Use Alert Dialog once available; do not rely only on browser confirm |

Examples of high-risk ShelfStack actions:

```
Post Receipt
Void Transaction
Close Register
Inactivate record with dependent workflow effects
Reverse tender
Post inventory adjustment
```

Until the Alert Dialog partial exists, use the strongest available confirmation pattern and keep the danger action visually distinct.

---

### Link button

Use for very low-emphasis inline actions that still trigger behavior.

```
<%= button_tag "Use suggested price", type: "button", class: "ss-btn-link" %>
```

Examples:

```
Use suggested price
Copy
Reset
Clear
Show more
```

`ss-btn-link` is standalone. Do **not** combine `.ss-btn-link` with `.ss-btn`, `.ss-btn-primary`, `.ss-btn-secondary`, or other button variant classes.

Use sparingly. Do not use link buttons for primary workflow actions.

---

### Small

Use in dense operational areas, table rows, compact cards, menus, and footers.

```
<%= link_to "Edit", edit_item_path(item), class: "ss-btn ss-btn-tertiary ss-btn--small" %>
```

Small is a size modifier, not a hierarchy. It should be combined with another variant.

Prefer BEM-style modifier aliases in new documentation where they exist:

```
ss-btn--small
ss-btn--danger
ss-btn--ghost
ss-btn--full
ss-btn--icon
```

Hyphen-form classes remain valid during migration:

```
ss-btn-small
ss-btn-danger
ss-btn-ghost
ss-btn-full
ss-btn-icon
```

---

## Domain extensions

Domain workspaces may add classes for layout, sizing, or workflow-specific emphasis.

POS examples:

```
.ss-pos-complete-btn
.ss-pos-settlement-complete-btn
```

Domain classes should extend button primitives, not replace them, unless the domain component explicitly documents a separate control pattern.

Good:

```
<%= button_tag "Complete Sale",
      type: "button",
      class: "ss-btn ss-btn-primary ss-pos-complete-btn ss-pos-settlement-complete-btn" %>
```

Acceptable when a domain component explicitly owns the control:

```
<button type="button" class="ss-pos-mode-switch__btn">
  Return
</button>
```

`.ss-pos-mode-switch__btn` is **not** a Button variant. It is a POS mode-switch control pattern.

---

## Related layout utilities

Use `.ss-button-group` to lay out related actions.

```
<div class="ss-button-group">
  <%= link_to "Cancel", items_root_path, class: "ss-btn ss-btn-tertiary" %>
  <%= button_tag "Save Item", class: "ss-btn ss-btn-primary" %>
</div>
```

Use `.ss-button-group--segmented` only when the actions represent a grouped mode or mutually related choice.

```
<div class="ss-button-group ss-button-group--segmented">
  <%= button_tag "Open", type: "button", class: "ss-btn ss-btn-secondary" %>
  <%= button_tag "Closed", type: "button", class: "ss-btn ss-btn-tertiary" %>
</div>
```

Do not use segmented button groups for unrelated page actions.

---

## CSS

Primary button styles live in:

```
app/assets/stylesheets/shelfstack.components.buttons.css
```

Current button classes:

```css
.ss-btn
.ss-btn-primary
.ss-btn-secondary
.ss-btn-tertiary
.ss-btn-ghost
.ss-btn-danger
.ss-btn-small
.ss-btn-large
.ss-btn-full
.ss-btn-icon
.ss-btn-link
```

Migration aliases may exist temporarily:

```css
.ss-btn--danger
.ss-btn--small
.ss-btn--ghost
.ss-btn--full
.ss-btn--icon
```

### Required class pattern

Use this pattern for normal buttons:

```
class: "ss-btn ss-btn-primary"
```

Do not rely on `.ss-btn` alone unless primary/default styling is intentional.

### Preferred hierarchy

| Intent | Class |
| :---- | :---- |
| Primary action | `ss-btn ss-btn-primary` |
| Secondary action | `ss-btn ss-btn-secondary` |
| Tertiary action | `ss-btn ss-btn-tertiary` |
| Ghost utility | `ss-btn ss-btn-ghost` or `ss-btn ss-btn--ghost` |
| Destructive action | `ss-btn ss-btn-danger` or `ss-btn ss-btn--danger` |
| Inline low-emphasis action | `ss-btn-link` |
| Compact action | add `ss-btn--small` or `ss-btn-small` |

---

## Rails partial

### Current status

```
Status: CSS only
```

There is not yet a required shared button partial. New markup may use direct Rails helpers with documented classes.

### Planned partial

Target path:

```
app/views/shared/ui/_button.html.erb
```

Suggested future API:

```
<%= render "shared/ui/button",
      label: "Save Item",
      variant: :primary,
      type: :submit %>
```

Suggested options:

```
label:
variant: :primary | :secondary | :tertiary | :ghost | :danger | :link
size: nil | :small | :large
type: :button | :submit | :reset
url:
method:
disabled:
data:
aria:
form:
form_class:
```

Rendering behavior:

```
url:          # renders link_to when method is nil or :get
method:       # renders button_to when method is non-GET
type:         # renders button_tag for local form or Stimulus actions
form:         # passed to button_to as form options
form_class:   # convenience wrapper for form: { class: ... }
```

The partial should be introduced only after the class contract is stable.

---

## Accessibility requirements

Buttons must be keyboard reachable, visibly focusable, and accurately labeled.

### Required

1. Use a real `<button>` for form submission or JavaScript-triggered actions.  
2. Use a link only when the action navigates.  
3. Provide visible text unless the button is icon-only.  
4. Icon-only buttons must include an accessible label.  
5. Non-submit actions, including Stimulus actions and modal/drawer triggers, must use `type="button"` so they do not accidentally submit a parent form.  
6. Disabled actions must use real disabled semantics when possible.  
7. Dangerous actions must be visually distinct and clearly worded.  
8. Button text should describe the action, not just say “OK” or “Submit” when context is unclear.

### Good icon-only button

```
<button type="button"
        class="ss-btn ss-btn-tertiary ss-btn--icon"
        aria-label="Dismiss message">
  <span aria-hidden="true">×</span>
</button>
```

### Avoid

```
<button class="ss-btn">
  ×
</button>
```

The second example has no accessible name.

### Disabled buttons

For real buttons:

```
<%= button_tag "Post Receipt",
      class: "ss-btn ss-btn-primary",
      disabled: true %>
```

For unavailable navigation/actions rendered as non-links:

```
<span class="ss-btn ss-btn-tertiary is-disabled" aria-disabled="true">
  Post Receipt
</span>
```

Prefer real `disabled` on `<button>` and `aria-disabled` on custom controls. The `<span class="... is-disabled">` pattern is for non-button elements only.

Do not render a disabled-looking link that still navigates.

---

## Examples

### Form action row

```
<div class="ss-form-actions">
  <%= button_tag "Save Item", type: "submit", class: "ss-btn ss-btn-primary" %>
  <%= link_to "Cancel", items_root_path, class: "ss-btn ss-btn-tertiary" %>
</div>
```

---

### Page header actions

Inline `.ss-page-header` examples are illustrative until a generic `shared/ui/_page_header.html.erb` partial exists.

```
<div class="ss-page-header">
  <div>
    <h1>Purchase Order</h1>
    <p class="ss-page-description">Review vendor order lines before submitting.</p>
  </div>

  <div class="ss-page-actions">
    <%= link_to "Print", purchase_order_path(@purchase_order, format: :pdf), class: "ss-btn ss-btn-secondary" %>
    <%= button_to "Submit PO", submit_purchase_order_path(@purchase_order), method: :patch, class: "ss-btn ss-btn-primary" %>
  </div>
</div>
```

For form-specific pages, prefer the existing form page header partial when compatible.

```
<%= render "shared/forms/page_header",
      title: "Edit Vendor",
      description: "Update supplier defaults, terms, and purchasing behavior." %>
```

---

### Destructive action with simple confirmation

Use this for lower-risk destructive actions where browser/Turbo confirmation is sufficient.

```
<div class="ss-section-actions">
  <%= button_to "Delete Draft",
        draft_path(@draft),
        method: :delete,
        class: "ss-btn ss-btn--danger",
        data: { turbo_confirm: "Delete this draft?" } %>
</div>
```

For posting, voiding, closing register, inventory-affecting, or money-affecting actions, move to Alert Dialog when that component is available.

---

### Footer utility

```
<%= button_to "Lock Session",
      session_lock_path,
      method: :post,
      params: { return_to: request.fullpath },
      class: "ss-btn ss-btn-ghost ss-btn--small",
      form: { class: "ss-inline-form ss-footer__lock-form" } %>
```

---

### Table row action

```
<td class="ss-row-actions">
  <%= link_to "View", item_path(item), class: "ss-btn ss-btn-tertiary ss-btn--small" %>
  <%= link_to "Edit", edit_item_path(item), class: "ss-btn ss-btn-secondary ss-btn--small" %>
</td>
```

---

### POS quick action

```
<%= button_tag "Open Ring",
      type: "button",
      class: "ss-btn ss-btn-secondary ss-btn--small",
      data: { action: "pos-command-bar#openRing" } %>
```

---

### POS complete action with domain extension

```
<%= button_tag "Complete Sale",
      type: "button",
      class: "ss-btn ss-btn-primary ss-pos-complete-btn ss-pos-settlement-complete-btn" %>
```

---

### Dropdown menu action

Do not style dropdown menu rows as normal buttons. Use dropdown menu item classes.

```
<div class="ss-dropdown-menu" role="menu">
  <%= link_to "Change password", edit_password_path, class: "ss-dropdown-menu__item", role: "menuitem" %>

  <%= button_to "Logout",
        logout_path,
        method: :delete,
        class: "ss-dropdown-menu__item ss-dropdown-menu__item--danger",
        form: { class: "ss-inline-form" } %>
</div>
```

---

## Do / Don’t

| Do | Don’t |
| :---- | :---- |
| Use one primary action per decision area | Put three primary buttons in one toolbar |
| Use danger for destructive actions | Use danger for normal cancellation |
| Use ghost for persistent low-emphasis utilities | Use secondary for footer utilities like Lock Session |
| Use links for navigation | Make every navigation link a button |
| Give icon-only buttons an `aria-label` | Rely on `×`, `✕`, or icon text alone |
| Add `type="button"` for non-submit button actions | Let modal/drawer buttons accidentally submit forms |
| Disable unavailable actions semantically | Use a disabled-looking link that still works |
| Keep button labels specific | Use vague labels like “Go” or “Submit” where context is unclear |
| Use dropdown item classes inside menus | Use full button styling for every menu row |
| Treat POS mode switch as its own pattern | Treat `.ss-pos-mode-switch__btn` as a button variant |

---

## Migration notes

### Current state

Buttons are currently a **CSS-class convention**, not a required partial.

The active CSS source is:

```
app/assets/stylesheets/shelfstack.components.buttons.css
```

The old monolithic CSS file may still contain overlapping button styles during the legacy bridge period.

### Rules for new work

1. Do not add new button styles to `shelfstack.css`.  
2. Do not add new button styles to `shelfstack.legacy.css`.  
3. Add reusable button variants to `shelfstack.components.buttons.css`.  
4. Add domain-specific button placement/layout to the appropriate `shelfstack.domain.*.css` file.  
5. Use `ss-btn-ghost` or `ss-btn--ghost` for low-emphasis persistent utilities such as **Lock Session**.  
6. Use `ss-btn-danger` or `ss-btn--danger` only for destructive/high-risk actions.  
7. Prefer explicit variant classes even though `.ss-btn` alone renders primary.  
8. Prefer direct class usage until the shared partial is introduced.

### Legacy classes to phase out

Avoid adding new usages of ambiguous or older patterns such as:

```css
.btn
.button
.primary
.secondary
.flash button
.pos-button
```

When touching existing markup, migrate toward:

```css
.ss-btn
.ss-btn-primary
.ss-btn-secondary
.ss-btn-tertiary
.ss-btn-ghost
.ss-btn-danger
.ss-btn--small
.ss-btn-link
```

### Suggested next migration step

Create a thin shared partial after button usage stabilizes:

```
app/views/shared/ui/_button.html.erb
```

Then migrate only high-repetition areas first:

```
form actions
page headers
dialog footers
POS action rows
footer utilities
row actions
```

Do not attempt a full app-wide button partial migration in one pass.