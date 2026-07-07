# ShelfStack UX Guide

*Created: 2026-07-05*

ShelfStack is an operational system for booksellers. The interface should help staff move quickly, understand consequences, and avoid costly mistakes without overwhelming them.

This guide defines the core UX principles, page patterns, component usage rules, and design standards for ShelfStack.

## UX goals

ShelfStack should feel:

- **Clear** — users understand where they are, what they can do, and what will happen next.
- **Operational** — screens support real bookstore workflows, not generic admin CRUD.
- **Calm** — dense information is allowed, but visual noise is controlled.
- **Fast** — common tasks require minimal navigation, typing, and confirmation.
- **Safe** — destructive, financial, inventory-changing, and customer-impacting actions are explicit.
- **Consistent** — similar workflows look and behave the same way throughout the app.
- **Accessible** — staff can choose a comfortable view mode and navigate with keyboard, pointer, or scanner.

## Primary user contexts

### Frontline bookseller

Uses ShelfStack to search items, check availability, sell through POS, process returns, capture customer demand, check customer or stored-value information, and perform buybacks.

Prioritize speed, readable summaries, scanner-friendly interaction, and clear next actions.

### Buyer / inventory staff

Uses ShelfStack to review demand, source items, create purchase orders, receive inventory, manage vendor sources, review inventory issues, and process RTVs.

Prioritize queues, filters, exceptions, document status, and clear posting consequences.

### Manager / owner

Uses ShelfStack to review reports, approve exceptions, configure setup data, audit activity, and oversee register sessions and inventory value.

Prioritize traceability, summarized information, exception visibility, and drill-down paths.

### Admin / setup user

Uses ShelfStack to configure stores, users, roles, permissions, departments, tax, formats, vendors, and controlled vocabulary.

Prioritize consistency, safety, permission clarity, and recovery paths.

## Core design principles

### Show operational state first

Every major screen should answer:

1. What am I looking at?
2. What is its current state?
3. What needs attention?
4. What can I do next?

Examples:

- A purchase order should show whether it is Draft, Submitted, Partially Received, Received, Closed, or Cancelled.
- A variant should show on hand, available, on order, last received, and open demand.
- A POS transaction should show transaction mode, current total, tender status, and whether it can be completed.

### Make common actions obvious

Each page or section should have one clear primary action.

Use:

- **Primary** for the main forward-moving task.
- **Secondary** for important alternatives.
- **Tertiary** for cancel, back, close, logout, and lock session.
- **Danger** only for destructive or irreversible actions.

Do not rely on button order alone to communicate importance.

**Action order (ShelfStack standard):**

| Region | Order (left → right) |
| :---- | :---- |
| Page header / toolbar (`.ss-page-actions`) | Secondary and lifecycle actions first; **primary rightmost** |
| Form footer (`.ss-form-actions`) | **Primary first**; cancel/back **tertiary last** |
| Setup detail danger zone | Delete and irreversible actions only — not in the header |

Full detail: [components/button.md](components/button.md#action-order-shelfstack-standard).

### Keep risky actions explicit

Actions that post, void, cancel, reverse, close, delete, inactivate, or alter inventory/financial history should be deliberate.

Use an Alert Dialog for:

- posting receipts
- posting inventory adjustments
- closing a register session
- voiding a POS transaction
- cancelling a purchase order
- cancelling or voiding a buyback
- deleting or inactivating important setup records

The dialog should state what will happen, what cannot be undone, what records will be affected, and whether inventory, tenders, stored value, or audit history will change.

### Prefer workflow pages over generic CRUD

ShelfStack should not feel like a database editor.

| Generic CRUD | Preferred UX |
| --- | --- |
| Edit receipt | Receive inventory |
| Edit demand line | Review customer request |
| Edit POS transaction | Complete sale/refund |
| Edit product variant | Manage sellable variant |
| Edit vendor source | Manage sourcing details |
| Edit adjustment | Count/adjust inventory |

### Surface exceptions

ShelfStack should actively reveal problems:

- missing vendor source
- negative inventory
- no register session open
- unmatched receipt lines
- inactive variant
- missing tax category
- missing cost
- unposted document
- demand not allocated
- stored-value issue
- failed external lookup/import

Use alerts, status badges, warning panels, and exception queues.

### Keep dense screens structured

Bookstore operations require dense information. Density is acceptable when hierarchy is clear.

Use page headers, cards, data tables, section headers, badges, summary strips, collapsibles, sidebars, and sheets. Avoid unstructured walls of fields.

## Appearance and view modes

ShelfStack supports user-facing appearance modes.

| View mode | Purpose | Typeface | Density |
| --- | --- | --- | --- |
| Standard View | Default balanced view | Atkinson/system | Standard |
| Accessible View | Easier reading, more spacing | Lexend | Comfortable |
| Compact View | Higher-density operational work | System/compact | Compact |

The app applies appearance through body attributes:

```html
<body
  data-ss-typeface="..."
  data-ss-density="..."
  data-ss-color-mode="...">
```

Components should consume tokens such as `--font-ui`, `--line-body`, `--line-ui`, `--pad-ui-y`, `--pad-ui-x`, `--pad-card`, `--gap-ui`, and `--gap-section`.

Do not hard-code spacing or font choices inside individual page styles unless there is a clear operational reason.

## Navigation model

### Primary navigation

Primary navigation should be domain/workspace oriented.

Recommended top-level navigation:

```text
Dashboard
Items
Point of Sale
Buybacks
Inventory
Customers
Reports
Setup
```

Inventory operations may contain secondary navigation for stock overview, demand, sourcing, purchase orders, receiving, returns to vendor, stock adjustments, negative inventory, and inventory admin.

### Global search

The global search belongs in the application header.

| Area | Contents |
| --- | --- |
| Left | Logo + store/workstation context |
| Center | Search / scan items |
| Right | User menu + logout |

Search should support scanning and typing workflows and route users toward the item/product/variant workbench.

### POS navigation

POS should use a constrained operational layout.

| Row | Contents |
| --- | --- |
| Header row | Session/register details left, Actions menu right |
| Command row | Scan/command input + sale/refund/pickup mode |
| Quick row | Open Ring, Gift Card, and other quick actions |

POS should avoid decorative layout that competes with the transaction.

## Page patterns

### Index / queue pages

Use for customers, products, variants, demand lines, purchase orders, receipts, RTVs, inventory balances, setup records, and report lists.

Pattern:

```text
Page Header
Filter Bar
Data Table
Pagination
Empty State
```

Required elements: title, short description, primary action when applicable, filters/search, table summary, row actions, pagination, and empty state.

### Detail pages

Use for item detail, variant detail, customer detail, purchase order detail, receipt detail, demand line detail, buyback session detail, and register session detail.

Pattern:

```text
Page Header / Document Header
Status + Key Metrics
Primary Content
Supporting Sidebar or Tabs
Activity / Audit / History
```

A detail page should never force users to hunt for operational state.

### Workflow pages

Use for POS transaction, receiving, buyback intake, demand-to-PO, stock adjustment, import, and customer pickup.

Pattern:

```text
Workflow Header
Current Step / State
Primary Work Area
Live Summary
Warnings / Readiness
Submit/Post/Complete Action
```

Workflow pages should show live totals, validation, and readiness before the user commits.

### Setup pages

Setup pages should emphasize active/inactive state, whether the record is in use, whether inactivation is safe, and what downstream behavior the setup record controls.

### Locked-out pages

Use the shared Access Notice component. Do not create one-off locked-out page layouts.

### Session pages

Use a focused session pattern for login, unlock session, and workstation assignment. Use the normal app shell for change password and set/change PIN.

## Component usage guide

### Buttons

Use explicit button variants.

| Variant | Use |
| --- | --- |
| `.ss-btn-primary` | One main action per page/form/section |
| `.ss-btn-secondary` | Important alternate action |
| `.ss-btn-tertiary` | Cancel, back, close, logout, lock session |
| `.ss-btn-danger` / `.ss-btn--danger` | Destructive or irreversible action |
| `.ss-btn-link` | Low-emphasis inline action |
| `.ss-btn-small` / `.ss-btn--small` | Compact actions in tables, panels, and row menus |

Prefer BEM `--` modifiers (`.ss-btn--danger`, `.ss-btn--small`) for new markup. Both forms are valid during migration.

Avoid multiple primary buttons in one section, using color alone to communicate risk, danger styling for non-destructive actions, and making logout visually stronger than work actions.

### Cards and surfaces

Use cards for grouped information, not decoration. Avoid excessive nested cards.

Good uses include item summary, customer profile, vendor source, stock summary, setup section, report metric, and POS totals panel.

### Alerts, flash, toast, dialog

| Component | Use |
| --- | --- |
| Alert | Persistent in-page warning or callout |
| Flash | Server response after navigation/submission |
| Toast | Temporary feedback after inline/Turbo action |
| Dialog | Focused modal task |
| Alert Dialog | Confirmation for risky action |

These are not interchangeable.

For target CSS class names, the decision rule, and migration stragglers, see [components.md — Feedback naming standard](components.md#feedback-naming-standard).

### Badges and status

Use badges for compact status and metadata. Business statuses should use `.status-*` classes.

Do not use badges as buttons unless they are explicitly styled and labeled as interactive controls.

### Tables and data tables

Use Table for simple structured data. Use Data Table for searchable/filterable/sortable lists.

Tables should support readable row height, numeric alignment, status badges, row actions, empty states, and pagination for long lists.

### Forms

Every form field should have a label, control, optional helper text, and validation error area.

Use `.ss-form`, `.ss-form-card`, `.ss-field`, `.ss-fieldset`, `.ss-form-grid`, and `.ss-form-actions`.

### Lookup

Lookup is central to ShelfStack. Use combobox/lookup patterns for product variants, customers, vendors, category nodes, POS items, stored value, and returns.

Lookup results should show enough information to select confidently: title/name, identifier, status, availability/balance, warnings, and relevant secondary metadata.

### Dialogs and sheets

Use Dialog for contained tasks. Use Sheet/Drawer for supporting context. Use Alert Dialog for destructive or irreversible confirmation.

### Tabs, accordions, collapsibles

Use Tabs for peer sections, Accordion for multiple related expandable sections, and Collapsible for one optional section. Do not hide critical warnings inside collapsed sections.

## POS UX rules

POS should be fast and calm. Prioritize scanner input, transaction state, totals, tender readiness, warnings, and completion actions.

Avoid decorative surfaces, unnecessary animation, excessive modals, crowded side actions, and small touch targets.

The command bar should be structured as:

```text
Scan/command input + mode selector
Quick actions row
Feedback/choices/panels
```

Risky POS actions require confirmation, including void transaction, complete refund, close register, force close register, remove tender after payment, manager override, and cash drawer movement where required.

## Inventory and purchasing UX rules

The UX should reinforce that posted inventory events matter.

For posting actions, explain:

- what quantity changes
- what stock balance changes
- what cost/value changes
- what document status changes
- whether the action is reversible

Receiving should distinguish ordered, received, accepted, rejected, damaged, cancelled, and backordered quantities. Only accepted quantity should post to inventory.

Demand should distinguish customer special order, stock consideration, manual TBO, reserved on-hand stock, inbound/on-order allocation, and fulfilled demand.

## Reports and print UX

Reports should be screen-readable and print-clean.

Report pages should include report title, date/time generated, scope/filters, summary metrics, detail sections, notes/exceptions, and print action.

Printed versions should avoid sticky app chrome, hover-only controls, decorative shadows, hidden essential context, and excessive color dependence.

## Accessibility guidance

ShelfStack should support keyboard navigation, visible focus states, semantic headings, labels for all inputs, readable contrast, non-color status indicators, accessible view mode, and large enough hit targets.

Do not remove focus outlines. Do not communicate state through color alone.

## Copy and language

Use plain operational language.

Prefer:

```text
Post receipt
Close register
Create purchase order
Receive inventory
Return to vendor
Record buyback
Attach customer
Check stored value balance
```

Avoid vague labels:

```text
Submit
Process
Do it
Proceed
Manage
Update record
```

For risky actions, describe the consequence.

## Anti-patterns

Avoid:

- multiple unrelated primary actions
- mixing CRUD and workflow language
- one-off CSS for new screens
- page-specific button rules
- relying on first-child button styling
- hiding important warnings below the fold
- using modals for every small task
- right-click-only workflows
- dense tables without filters or summaries
- destructive actions without confirmation
- badges that look clickable but are not
- inconsistent status labels across domains
- print views that depend on app chrome
- POS screens that use general back-office density without review

## Implementation rule

When designing or revising a screen:

1. Start with the user’s task.
2. Choose the appropriate page pattern.
3. Use existing ShelfStack components.
4. Use explicit action hierarchy.
5. Surface warnings and operational state.
6. Add domain-specific CSS only when generic components are insufficient.
7. Update the component library if a reusable pattern emerges.

New screens should not introduce new CSS classes casually. If a new class is needed, decide whether it belongs in generic component CSS, domain component CSS, print CSS, the legacy bridge, or experimental CSS.

## North star

ShelfStack should feel like a thoughtful, purpose-built bookstore operations system.

The interface should help booksellers answer:

```text
What is this?
Do we have it?
Can we sell it?
Does someone want it?
Can we order it?
Has it arrived?
What should I do next?
```
