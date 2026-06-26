# Phase TBD — Comprehensive UI/UX Expansion

## Purpose

This phase implements the broader ShelfStack UI/UX vision that was intentionally deferred from Phase 9a.

Phase 9a establishes the minimum user-interface and semantic foundation needed for reports. Phase 9b implements initial reports. This later phase returns to the larger application experience: POS workflow modernization, item cockpit redesign, app-wide modal and drawer patterns, keyboard-first interaction standards, command shortcuts, progressive disclosure, and consistency across operational pages.

The goal is to make ShelfStack feel like a cohesive, fast, operational bookstore system rather than a collection of Rails CRUD screens.

## Working Phase Name Options

Possible names:

```text
Phase TBD — Comprehensive UI/UX Expansion
Phase TBD — Operational Interface Modernization
Phase TBD — ShelfStack Interaction System
Phase TBD — Workflow UX and Command Interface
Phase TBD — Frontline UX Expansion
```

Recommended name:

```text
Phase TBD — Comprehensive UI/UX Expansion
```

## Relationship to Phase 9a and Phase 9b

### Phase 9a — UX Foundation for Reporting

Phase 9a standardizes the minimum necessary foundations:

* Page headers
* Buttons
* Forms
* Selects
* Tables
* Metric cards
* Report view contract
* Message taxonomy
* Money/percentage/quantity/date formatting
* Reporting semantics

### Phase 9b — Reports

Phase 9b uses those standards to build initial operational reports.

### This Phase

This phase completes the larger interaction vision:

* POS transaction-first workspace
* Full POS command and shortcut behavior
* Improved POS line editing
* Modal and drawer system
* Item cockpit and operations drawer
* Item setup modals
* Customer request and purchasing workflow UX cleanup
* App-wide keyboard/focus conventions
* Progressive disclosure across complex records
* Broader interaction consistency for Turbo/Stimulus workflows

This phase should not block reports.

---

# Problem Statement

ShelfStack has strong domain coverage, but the interface currently feels uneven because related workflows use different layout, action, field, message, and interaction patterns.

Recurring issues:

* Similar fields look different across screens.
* Select lists sometimes feel like raw browser controls.
* Buttons are overused and often carry too much visual weight.
* Some pages are visually dense without clear hierarchy.
* POS scan entry feels strong, but line modification feels more like admin form editing.
* Customer request pages contain useful information but are hard to navigate.
* `/items` exposes many correct relationships, but the overview can feel like a data dump.
* Buyback and POS pages use different dashboard/header patterns.
* Turbo/Stimulus interactions exist, but they are workflow-specific rather than standardized.
* Modals and drawers are useful but not yet a shared system.
* Keyboard/focus behavior is present in some places, but not consistently defined.

This phase should turn the existing visual direction into a coherent application interaction system.

---

# Target UX Feel

ShelfStack should feel:

```text
Operational, not decorative.
Fast, not flashy.
Dense enough for bookstore work, but not cramped.
Keyboard-friendly by default.
Predictable from screen to screen.
Calm even when records are interconnected.
Clear about the next action.
Summary-first, with detail available on demand.
Brand-aware, but not visually noisy.
```

## Practical Meaning

| Principle              | Meaning                                                                                               |
| ---------------------- | ----------------------------------------------------------------------------------------------------- |
| Operational            | Screens answer staff questions and support real work.                                                 |
| Fast                   | Search, scan, add, edit, save, and complete flows minimize clicks and page changes.                   |
| Predictable            | Similar actions, fields, messages, and focus behavior work the same way everywhere.                   |
| Calm                   | Typography, spacing, cards, and hierarchy reduce overwhelm.                                           |
| Keyboard-first         | POS and workflow screens support keyboard/scan-driven operation.                                      |
| Progressive disclosure | Summary appears first; advanced detail is available through tabs, drawers, modals, and expanded rows. |
| Context-preserving     | Bounded edits happen without forcing users to leave the current workflow.                             |

---

# Goals

This phase should:

1. Implement the broader ShelfStack UI/UX vision beyond reporting.
2. Make POS a keyboard-first transaction workspace.
3. Redesign `/items` around an item cockpit, operations drawers, and setup modals.
4. Standardize modals, drawers, expanded rows, and inline editors.
5. Extend keyboard/focus rules across operational workflows.
6. Reduce button-heavy screens by distinguishing actions, filters, tabs, badges, and utilities.
7. Make complex record relationships easier to understand through summaries and progressive disclosure.
8. Improve customer requests, purchasing, receiving, buybacks, POS, and item workflows.
9. Continue using the Phase 9a design system rather than inventing new page-specific UI.
10. Keep reporting screens compatible with the broader interface direction.

---

# Non-Goals

This phase does not include:

* Rebuilding the entire application frontend from scratch
* Replacing Rails/Turbo/Stimulus with a SPA framework
* Full RubyUI/DaisyUI migration unless separately approved
* Offline POS
* New reporting engine
* Data warehouse
* Advanced analytics/report builder
* Accounting/GL export
* Mobile-native app
* Complete redesign of every setup/admin page
* Changing core business rules without separate domain approval

---

# Major Workstreams

## Workstream 1 — Interaction System and Component Completion

### Purpose

Extend the Phase 9a UI foundation into a full application interaction system.

### Scope

Standardize and implement:

```text
Modal system
Drawer system
Toast system
Expanded row pattern
Inline edit pattern
Lookup/search component
Command field pattern
Shortcut strip
Focus restoration helper
Keyboard event scoping
Turbo Frame/Stream target conventions
```

### Required Components

#### Modal

Classes/patterns:

```text
ss-modal
ss-modal-overlay
ss-modal-dialog
ss-modal-dialog--sm
ss-modal-dialog--md
ss-modal-dialog--lg
ss-modal-dialog--pos
ss-modal-header
ss-modal-title
ss-modal-body
ss-modal-footer
ss-modal-toolbar
ss-modal-close
```

Behavior:

* Trap focus while open.
* Focus first meaningful control.
* Escape closes only when safe.
* Validation errors remain inside modal.
* Successful save updates affected panels via Turbo.
* Closing restores focus to opener.
* Background scroll is prevented.
* Modals are used only for bounded tasks.

Good uses:

* Add identifier
* Edit price
* Customer lookup
* Supervisor authorization
* Gift card activation
* Stored value balance inquiry
* Tax exemption
* Cash drawer action
* Confirm void/remove/delete

Avoid using modals for:

* Full receiving workflow
* Full purchase order creation
* Full buyback intake
* Full catalog editing
* Complex multi-section setup

#### Drawer

Classes/patterns:

```text
ss-drawer
ss-drawer-overlay
ss-drawer-panel
ss-drawer-panel--right
ss-drawer-header
ss-drawer-title
ss-drawer-body
ss-drawer-footer
```

Behavior:

* Preserve the current page state.
* Restore focus to opener on close.
* Support read-only detail and light editing.
* Include link to full record when deeper work is needed.
* Do not replace full workflows.

Good uses:

* Item/variant detail
* Customer detail
* Session summary
* Transaction history
* Receipt/source detail
* Purchase order line detail
* Inventory movements
* Stored value account detail
* Customer demand detail

#### Toast

Classes/patterns:

```text
ss-toast-region
ss-toast
ss-toast--success
ss-toast--info
ss-toast--warning
ss-toast--error
```

Behavior:

* Use for minor, non-blocking confirmations.
* Do not use for blockers.
* Do not use for field validation.
* Do not use for transaction safety warnings.

Good uses:

* Price updated
* Note added
* Line saved
* Copied SKU
* Filter saved

Bad uses:

* Cannot complete sale
* Tax validation failed
* Tender insufficient
* Supervisor approval required
* Inventory posting failed

#### Expanded Row

Classes/patterns:

```text
ss-expand-row
ss-expand-row--active
ss-row-detail
ss-row-detail__header
ss-row-detail__body
ss-row-detail__footer
```

Uses:

* POS line editing
* Receipt line detail
* Purchase order line detail
* Inventory adjustment line detail
* Customer request line detail
* Buyback line detail

Behavior:

* Expanded detail remains visually attached to the parent row.
* Save/cancel are local.
* Destructive actions are separated.
* After save, collapse and restore focus predictably.

---

## Workstream 2 — POS Keyboard-First Transaction Workspace

### Purpose

Make POS feel like a fast register workspace rather than a dashboard or form-heavy admin area.

### Direction

The guiding model:

```text
Command field is home base.
Cart is the working surface.
Line edits happen inline.
Related detail opens in drawers.
Bounded decisions happen in modals.
Readiness appears where completion happens.
Function keys and commands make common actions fast.
```

## Scope

### 2.1 POS Landing Behavior

Implement transaction-first routing when a register session is open.

Recommended behavior:

| Condition                                         | Behavior                                                |
| ------------------------------------------------- | ------------------------------------------------------- |
| Register session open and one active draft exists | Redirect to active draft transaction                    |
| Register session open and no draft exists         | Create new sale transaction and redirect to edit screen |
| Register session open and multiple drafts exist   | Show compact draft/held sale selector                   |
| No register session open                          | Show focused open-register workflow                     |
| No POS permission                                 | Show permission-aware POS screen                        |

The goal:

```text
When the register is open, POS should open directly to the active selling workspace.
```

### 2.2 POS Transaction Layout

Standard structure:

```text
Top context bar
  Store
  Register/workstation
  Cashier
  Session status
  Utility menu

Command field
  Scan/search/command input
  Main focus target

Mode controls
  Sale
  Return
  Pickup
  Open ring

Cart/work area
  Transaction lines
  Quantity controls
  More/Edit action
  Inline modification rows

Sidebar
  Totals
  Discounts/tax adjustments
  Readiness
  Settlement action

Modal layer
  Settlement
  Customer lookup
  Gift card activation
  Stored value inquiry
  Supervisor authorization
  Tax exemption
  Cash drawer action

Shortcut strip
  Function keys
  Command help
```

### 2.3 Command Field

The command field should support:

* SKU
* ISBN
* Barcode
* Receipt number
* Gift card/store credit identifier
* `/command`
* Amount-like input where context allows

Initial command ideas:

```text
/customer
/openring
/discount
/taxexempt
/giftcard
/balance
/return
/pickup
/cash 20
/card
/check
/storecredit
/hold
/session
/cashdrop
/cashin
/cashout
/close
/reports
/help
```

### 2.4 Command Registry

Create a centralized command registry.

Each command defines:

```text
Name
Aliases
Description
Permission requirement
Valid session states
Valid transaction states
Target behavior
  - route
  - modal
  - drawer
  - inline panel
  - transaction mutation
Focus target after completion
Unavailable/error message
```

Commands should not be scattered through conditional JavaScript.

### 2.5 Function Keys

Initial shortcut set:

| Key | Action                      |
| --- | --------------------------- |
| F2  | Customer lookup             |
| F3  | Open ring                   |
| F4  | Discount                    |
| F7  | Cash drawer / cash movement |
| F8  | Settlement                  |
| F9  | Print last receipt          |
| F10 | Lock register               |

Avoid relying on function keys that frequently conflict with browsers or operating systems unless testing confirms reliability.

### 2.6 POS Focus Rules

Required behavior:

| Situation                  | Expected behavior                                    |
| -------------------------- | ---------------------------------------------------- |
| Transaction page loads     | Focus command field                                  |
| Item added successfully    | Return focus to command field                        |
| Lookup selected            | Add/select result, then return focus                 |
| Modal closes               | Restore focus to opener or command field             |
| Drawer closes              | Restore focus to opener or command field             |
| Invalid command            | Keep focus in command field and show inline guidance |
| Transaction completes      | New transaction opens with command field focused     |
| Esc with modal/drawer open | Close modal/drawer if safe                           |
| Esc with command text      | Clear command field                                  |
| Enter in command field     | Route command/add item/lookup                        |

### 2.7 Cart and Line Editing

Use inline expanded rows for bounded line edits.

Line edit should support:

* Quantity
* Unit price where editable
* Line discount
* Existing discount removal
* Tax override
* Return disposition
* Line note
* Remove line

Rules:

* The edited line remains visible.
* Edit panel is visually scoped to the line.
* Save and Cancel are local.
* Destructive actions are separated.
* After save, collapse and return focus to command field or row.
* Routine success does not show a large alert.

### 2.8 Settlement Modal

Settlement remains a modal.

It should show:

```text
Settlement title
Transaction/customer/register context
Remaining balance
Change due
Tender rows
Add tender buttons
Secondary actions
Final complete action
Readiness blockers
```

Rules:

* F8 opens settlement.
* First focus goes to likely tender field.
* `/cash 20` opens settlement and preloads cash tender.
* Change due updates live.
* Completion disabled until readiness passes.
* Blocking issues appear inside/near settlement.
* After completion, a new transaction opens with command field focused.

### 2.9 POS Session and Utility Access

Move secondary POS tasks out of the main landing path.

Access through:

* Utility menu
* Session drawer
* Commands
* Dedicated full-page workflows where appropriate

Session status should open session summary drawer.

Commands:

```text
/session
/close
/cashdrop
/cashin
/cashout
/reports
```

---

## Workstream 3 — Item Cockpit and Operations UX

### Purpose

Make `/items` feel like a unified item workspace rather than a database relationship viewer.

The item page should answer:

```text
What is this?
Can we sell it?
Do we have it?
Can we order it?
Who is waiting for it?
What needs attention?
What should staff do next?
```

### Scope

### 3.1 Item Overview Cockpit

Recommended overview structure:

```text
Item hero
  Title
  Subtitle
  Contributors
  Primary identifier
  Format/type
  Cover/image
  Lifecycle/sellable status

Attention panel
  Only actionable or persistent issues

Summary cards
  Sellable status
  Availability
  Orders & demand
  Catalog/setup completeness

Sellable SKU summary
  Compact variant table
  Price
  Tracking
  On hand
  Available
  On order
  Last received
  Warnings

Open activity summary
  TBO
  PO lines
  Holds
  Customer requests
  Recent receiving

Sidebar
  Quick actions
  Subjects/categories
  Description
  Related command hints
```

The overview should be a cockpit, not a full data dump.

### 3.2 Recommended Tabs

Use or migrate toward:

```text
Overview
Availability
Selling & SKUs
Orders & Demand
Catalog Details
Activity
```

If existing tab names remain temporarily, they should still follow these jobs.

### 3.3 Item Operations Tab

Use a summary table plus drawer pattern.

Operations tab should summarize:

* Variant availability
* Reserved quantity
* On hand
* On order
* Ready for pickup
* Open TBO
* Pending PO
* Preferred vendor
* Vendor source status
* Customer demand
* Recent receiving
* RTV activity

Drawer detail candidates:

* Variant demand
* Customer requests
* Open POs
* Receiving history
* Inventory movements
* Vendor source details
* Buyback/source history

### 3.4 Item Setup Modals

Use modals for bounded setup edits.

Good modal candidates:

* Add identifier
* Edit identifier
* Add variant
* Edit price
* Edit tax category
* Add vendor source
* Edit display location
* Edit status
* Add note

Use full pages for:

* Full catalog metadata editing
* Complex product setup
* Complex vendor/pricing setup
* Bulk variant creation

### 3.5 Used/Bulk/Behavior-Aware UX

Item screens should adapt to behavior profiles.

Rules:

* Vendor-source warnings apply only to vendor-orderable variants.
* Used/buyback variants should not be marked incomplete because they lack vendor source records.
* Non-inventory items should not show inventory-specific warnings.
* Gift card/stored-value items should not look like ordinary merchandise SKUs.
* Café/service items should expose relevant POS/reporting setup, not bibliographic detail.

### 3.6 Item Commands

Possible future item command examples:

```text
/tbo
/vendor
/hold
/receive
/po
/price
/tag
/history
```

Commands should follow the same registry/scoping rules as POS if implemented.

---

## Workstream 4 — Customer Request UX Rework

### Purpose

Make customer request screens easier to navigate and less button-heavy.

### Problems to Solve

* Index filters feel like too many equal-weight buttons.
* Detail page has useful information but unclear hierarchy.
* Actions, status, metadata, request lines, customer contact, and audit information compete visually.
* Row actions and next actions can be redundant.

### Scope

### 4.1 Customer Request Index

Recommended layout:

```text
Page header
  Title
  Description
  Primary action: New request

Filter/search area
  Search
  Status filter
  Request type filter
  Ready/not ready
  Assigned user if available

Results table
  Request
  Customer
  Item
  Status
  Age
  Next action
  Availability
  Assigned user
```

Rules:

* Inactive filters should be quiet.
* Active filters should be visible but not primary-button-heavy.
* New request should be the clear primary action.
* Each row should have one clear primary row action.

### 4.2 Customer Request Detail

Recommended layout:

```text
Record header
  Request number
  Status
  Customer
  Source
  Primary next action

Status strip
  Lines
  Unmatched
  Ready
  Completed
  Waiting

Main content
  Request lines
  Current action
  Availability/demand state

Sidebar
  Customer contact
  Request facts
  Related records

Audit/activity
  Collapsed or secondary
```

Rules:

* The page should distinguish record summary, current workflow state, line action, customer contact, and supporting facts.
* Request lines should not mix too many nested tasks in one card.
* Routine updates should not become large page alerts.

---

## Workstream 5 — Purchasing, Receiving, and Build PO UX

### Purpose

Make purchasing workflows feel like operational tasks rather than raw form/table screens.

### Scope

### 5.1 Build Purchase Order from TBO

Recommended structure:

```text
Build Purchase Order from TBO

Step 1 — Choose grouping
  Vendor-first
  Suggested vendor

Step 2 — Filter demand
  Department
  Format
  Vendor
  Store
  Request type

Step 3 — Review TBO lines
  Item
  Variant
  Quantity
  Suggested vendor
  Existing stock
  On order
  Customer demand
  Action

Step 4 — Build PO
  Confirm vendor
  Confirm selected lines
  Create draft PO
```

Rules:

* Select lists should use standard field styling.
* Display mode toggles should not look like primary submit buttons.
* Vendor choice should feel like part of a guided workflow.
* TBO line review should use a consistent table/line-entry pattern.

### 5.2 Purchase Order and Receiving Line UX

Improve:

* Lookup fields
* Quantity fields
* Cost/price fields
* Discount percent fields
* Exception/rejection controls
* Warning placement
* Add-line behavior
* Keyboard flow

Rules:

* Money inputs use decimal dollars.
* Discounts use decimal percentages.
* Accepted/rejected/received quantities are visually grouped.
* Warnings are inline or section-level, not random alerts.
* After adding a line, focus moves to the next expected input.

---

## Workstream 6 — Buyback UX Expansion

### Purpose

Align buyback pages with the same workflow, metric, and message standards.

### Scope

### 6.1 Buybacks Index

Improve:

```text
Page header
Metric strip
Recent sessions table
Needs review queue
Primary action: New buyback
```

The header should visually connect to the body. Metrics should use the shared metric-card pattern.

### 6.2 Buyback Session Workflow

Refine:

* Stepper
* Current action panel
* Proposal/decision/payout panels
* Line entry
* Line details
* Review-needed messages
* Payout summary
* Completion readiness

Rules:

* Buyback remains a full workflow, not a modal.
* Line detail may use expanded rows or drawer.
* Routine success should use workflow message or toast.
* Blocking issues belong in the workflow panel.
* Accepted buyback lines should connect clearly to inventory intake.

---

## Workstream 7 — Global Keyboard, Focus, and Command Standards

### Purpose

Make keyboard behavior deliberate across ShelfStack.

### Scope

Define global rules:

| Situation             | Behavior                                                    |
| --------------------- | ----------------------------------------------------------- |
| Index/search page     | Focus search field when useful                              |
| POS transaction       | Focus command/scan field                                    |
| Form validation error | Focus first invalid field                                   |
| Workflow line add     | Return focus to add/scan field                              |
| Lookup selection      | Focus next required field                                   |
| Modal opens           | Focus first meaningful control                              |
| Modal closes          | Restore focus to opener                                     |
| Drawer closes         | Restore focus to opener                                     |
| Escape                | Close modal/drawer where safe; otherwise clear scoped field |
| Enter in scan/search  | Submit lookup/add line                                      |
| Enter in textarea     | Insert newline                                              |

Implement shared Stimulus helpers where appropriate:

```text
focus_controller
modal_controller
drawer_controller
keyboard_scope_controller
command_controller
lookup_controller
line_entry_controller
toast_controller
```

Shortcuts must be scoped. Keyboard speed should not reduce transaction safety.

---

## Workstream 8 — Turbo and Stimulus Interaction Standards

### Purpose

Move from one-off Turbo/Stimulus behavior to shared interaction contracts.

### Scope

Standard Turbo targets:

```text
flash
toast_region
modal
drawer
workflow_status
workflow_lines
workflow_summary
lookup_results
item_attention
variant_table
pos_cart
pos_totals
pos_readiness
```

Standard Turbo update patterns:

* Replace changed row
* Replace summary/totals panel
* Replace readiness/attention panel
* Append toast
* Close modal
* Close drawer
* Restore focus
* Re-render validation errors in place

Rules:

* Server remains source of truth.
* Stimulus handles focus, formatting, keyboard, previews, and UI state.
* Stimulus should not own tax, pricing, inventory, or permission logic.
* Turbo validation errors stay in the frame/modal/workflow where the user is working.

---

# Suggested Implementation Order

## Phase TBD-A — Interaction Infrastructure

```text
1. Modal shell and controller
2. Drawer shell and controller
3. Toast region and component
4. Focus restoration helper
5. Keyboard scope helper
6. Expanded row pattern
7. Turbo target conventions
```

## Phase TBD-B — POS Workspace

```text
1. POS transaction-first landing behavior
2. POS context bar
3. Command field focus and behavior
4. Shortcut strip
5. Cart line edit redesign
6. Settlement modal standardization
7. POS readiness/message placement
8. Session drawer
9. Function keys
10. Command registry
```

## Phase TBD-C — Items Cockpit

```text
1. Overview cockpit cleanup
2. Summary cards and attention panel refinement
3. Sellable SKU table simplification
4. Operations tab summary table
5. Variant/demand drawer
6. Setup modals for bounded edits
7. Behavior-aware warnings
8. Item command ideas if approved
```

## Phase TBD-D — Workflow Pages

```text
1. Customer requests index/detail
2. Build PO from TBO
3. Purchase order line UX
4. Receiving line UX
5. Buyback index and session workflow
6. Inventory adjustment line UX
```

## Phase TBD-E — Polish and Consistency Sweep

```text
1. Remove one-off button/filter/table styles
2. Replace raw selects/inputs
3. Normalize empty states
4. Normalize status badges
5. Normalize row actions
6. Verify keyboard/focus behavior
7. Verify responsive behavior
8. Verify print/report compatibility
```

---

# Acceptance Criteria

This phase is complete when:

* POS opens into the correct register workspace state when a session is open.
* POS command field is the primary focus target.
* POS line edits use a polished expanded-row pattern.
* POS settlement uses the standardized modal system.
* POS readiness blockers appear where the user can act on them.
* POS supports documented keyboard/focus behavior.
* POS command registry or approved subset is implemented.
* `/items` overview behaves like a cockpit, not a data dump.
* `/items` operations use summary tables plus drawer detail.
* `/items` setup uses modals for bounded edits.
* Used/buyback variants do not show inappropriate vendor-source warnings.
* Customer request index is no longer button-heavy.
* Customer request detail separates record summary, current action, line detail, customer contact, and audit/history.
* Build PO from TBO feels like a guided workflow, not raw controls.
* Purchase order and receiving fields use standard money/percent/quantity controls.
* Buyback index uses consistent header, metric, and table layout.
* App-wide modal, drawer, toast, expanded-row, and focus patterns are documented and reusable.
* Keyboard/focus behavior is intentional for major workflows.
* Routine confirmations no longer appear as disruptive full-page alerts.
* No new page-specific UI pattern is introduced without being added to the shared UI/component standard.

---

# Deferred After This Phase

Possible later work:

* Advanced analytics dashboards
* Saved report views
* Full report builder
* Full command language outside POS/items
* Offline POS
* Mobile-specific workflows
* Touchscreen-specific POS mode
* Full framework migration
* User-customizable keyboard shortcuts
* Role-specific dashboard personalization
* Cross-store comparative analytics
* Automated workflow suggestions

---

# Risks

## Scope Creep

This phase is intentionally broad. It should be broken into sub-phases or PRs. POS, items, and global interaction infrastructure should not all be implemented in one large change.

## Keyboard Shortcut Reliability

Function keys may conflict with browsers or operating systems. Shortcuts should be tested in the expected deployment environment.

## Too Many Modals

Modals should remain limited to bounded tasks. Full workflows should stay full-page or use drawers for supporting detail.

## Command Discoverability

Commands are powerful but hidden. Provide visible controls, shortcut strips, `/help`, and command suggestions.

## Accessibility

Modal focus traps, drawer close behavior, keyboard shortcuts, focus rings, contrast, and screen-reader labels must be implemented carefully.

## Regression Risk

Changing shared components can affect many screens. Migrate incrementally and keep aliases for existing classes during transition.

## User Training

A keyboard-first interface is faster but may require visible hints and gradual adoption. Mouse-friendly controls should remain available.

---

# Developer Notes

Recommended implementation approach:

* Keep using Rails, Turbo, and Stimulus.
* Continue standardizing the `ss-*` design system.
* Avoid introducing a full framework migration during this phase unless separately approved.
* Prefer shared partials and helpers over one-off markup.
* Keep server-side business logic authoritative.
* Use Stimulus for focus, keyboard behavior, formatting, previews, and UI state.
* Use Turbo Streams for targeted panel updates.
* Document each reusable component as it is introduced.
* Preserve old class aliases temporarily where needed to reduce migration risk.

## Suggested Documentation

Create or update:

```text
docs/specifications/phase-tbd-comprehensive-ui-ux-expansion.md
docs/specifications/ui-components.md
docs/specifications/view-contracts.md
docs/specifications/keyboard-and-focus.md
docs/specifications/modal-and-drawer-patterns.md
docs/specifications/pos-keyboard-workspace.md
docs/specifications/item-cockpit.md
```
