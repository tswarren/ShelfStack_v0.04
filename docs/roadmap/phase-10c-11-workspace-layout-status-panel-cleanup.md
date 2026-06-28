Draft spec for the final Phase 10-C cleanup slice:

# Phase 10-C 11 — POS Workspace Layout and Status Panel Cleanup

## Status

**Complete** (2026-06-26)

## Parent Phase

Phase 10-C — POS Keyboard Workspace

## Purpose

Finalize the Phase 10-C POS workspace by aligning the visible transaction screen with the command-driven, modal-based, keyboard-friendly workflow introduced in earlier Phase 10-C slices.

Earlier Phase 10-C work added:

* Active draft resolution
* Root and transaction command routing
* Command registry and help
* Return and pickup drawers
* Modalized customer, tax exemption, transaction discount, gift card, balance inquiry, and tender workflows
* Cart line More menu with task-specific panels
* Completed transaction workspace
* Session drawer and held sales access

This slice cleans up the main POS transaction workspace so the screen reflects those newer workflows instead of retaining older inline forms, redundant buttons, and completion panels.

The goal is not to add new domain behavior. The goal is to make the POS workspace coherent, scannable, and ergonomic for front-line bookstore use.

## Summary

This slice updates the active and idle POS workspace layout:

* Move register/session/cash/report actions into a header action menu.
* Keep the command box as the primary input.
* Keep only high-value line-start buttons near the command box.
* Move transaction discount and tax exemption state into a right-side status panel.
* Place customer link/remove in the command row (not the status panel).
* Convert transaction discount and tax exemption status blocks into modal launchers.
* Make customer state visible and removable from the transaction workspace.
* Revise cart columns to better match transaction summary needs.
* Show line tax amounts and totals-panel tax bases/rates with primary/subtle hierarchy for quick reconciliation.
* Remove outdated readiness/completion workflow panels from the active transaction screen.
* Make flashes manually dismissible and auto-clearing.
* Keep balance inquiry available when the register/session is closed.
* Ensure receipt preview returns to the completed transaction workspace.

## Visual Reference

Active transaction layout (loose wireframe): [phase-10c-11-pos-mockup.png](../samples/phase-10-mockups/phase-10c-11-pos-mockup.png).

Use the mockup for spatial hierarchy and scan order. This document remains authoritative for behavior, permissions, and empty states.

## Design Direction

The transaction workspace should be organized around four core areas:

```text
Header bar
Command area
Cart
Right-side totals/status panel
```

Recommended high-level layout:

```text
POS | Workstation 001 | Open | Business Date: Sun Jun 28, 2026        Actions

Flash message [dismiss]

[command bar]                                          [Sale] [Return] [Pickup]

[Open Ring] [Gift Card]

Cart                                                   Totals
Qty | SKU/Description | Tax | Discount | Total | More   Subtotal
                                                        Discounts
                                                        Tax
                                                        Total

                                                        Status
                                                        Customer
                                                        Transaction Discount
                                                        Tax Exempt

                                                        [Complete Transaction]
```

## Goals

* Make the active POS transaction screen easier to scan.
* Reduce duplicated navigation and action buttons.
* Make mouse/touch equivalents available for key commands without cluttering the workspace.
* Surface customer, discount, and tax-exempt state without requiring the cashier to open hidden panels.
* Preserve keyboard-first command behavior.
* Preserve existing modals and services where possible.
* Keep the cart focused on operationally important line information.
* Keep completion/tendering as a separate focused workflow.

## Non-Goals

This slice does not implement:

* Grouped discounts, such as buy 2 get 1 free.
* Promotion engine changes.
* New pricing calculation behavior.
* Full customer create/edit CRUD from POS.
* Customer profile management.
* Cash pickup reporting category.
* Used buyback cash-out reporting category.
* Buyback workflow redesign.
* Cash movement accounting/reporting redesign.
* Receipt template redesign beyond return-path cleanup.
* New receipt printer integration.
* New tender types.

## Explicitly Deferred Work

The following items are intentionally deferred to later phases:

| Item                                               | Deferred To                     | Reason                                                                      |
| -------------------------------------------------- | ------------------------------- | --------------------------------------------------------------------------- |
| Grouped discounts / BOGO                           | Promotions/pricing phase        | Requires discount engine behavior, eligibility rules, and allocation logic. |
| Full add/edit customer path from POS               | POS customer workflow phase     | Linking/removing customer belongs here; full customer management is larger. |
| Remove/reclassify cash in/out from session details | Reporting/session cleanup phase | Changes reporting semantics.                                                |
| Cash pickup reporting category                     | Cash management/reporting phase | New reporting/accounting category.                                          |
| Used buyback cash-out reporting category           | Buyback/cash reporting phase    | Tied to buyback workflow and drawer reporting.                              |

## Header Bar

The POS header should become the persistent state anchor for the workspace.

### Header Content

Display:

```text
POS | Workstation Name | Register Status | Business Date
```

Example:

```text
POS | Register 001 | Open | Business Date: Sun Jun 28, 2026
```

The header replaces redundant text above the command bar such as:

```text
Register Open - Business Date
```

The cashier already has this information in the header.

### Header Actions Menu

Add an **Actions** menu in the header.

The menu should provide visible mouse/touch equivalents for utility commands:

| Menu Item                    | Equivalent Command |
| ---------------------------- | ------------------ |
| Stored Value Balance Inquiry | `/balance`         |
| Session                      | `/session`         |
| Cash In                      | `/cashin`          |
| Cash Out                     | `/cashout`         |
| Close Register               | `/close`           |
| Reports                      | `/reports`         |
| Drawer                       | `/drawer`          |

### Closed Register Behavior

Balance inquiry should remain available even when the register/session is closed.

In closed state:

* Header still shows POS/workstation/register status.
* Actions menu still includes **Stored Value Balance Inquiry**.
* Actions that require an open register should be disabled or route to the existing “open register first” behavior.
* Balance inquiry should not require an active draft transaction.

## Idle Workspace Cleanup

The idle workspace should be minimal.

Remove redundant large buttons:

* New Sale
* Cash In/Out
* Reports

These actions are now available through:

* Command bar
* Header Actions menu
* Scanning/lookup behavior

The idle workspace should keep only high-value sale-start mouse equivalents.

Recommended idle command area:

```text
[command bar]

[Open Ring] [Gift Card]
```

### Idle Button Behavior

| Button    | Behavior                                                         |
| --------- | ---------------------------------------------------------------- |
| Open Ring | Equivalent to `/openring`; opens open-ring line workflow.        |
| Gift Card | Equivalent to `/giftcard`; opens gift card sale/reload workflow. |

Do not show large duplicate utility buttons for actions already in the header menu.

## Command Area

The command box remains the primary POS interaction point.

The command area should include:

* Command input
* Return mode / mode toggle, if still part of active transaction workflow
* Compact mouse equivalents for Open Ring and Gift Card
* Command feedback message area

The command area should not repeat register state already shown in the header.

## Active Customer Status

The active transaction workspace should show customer attachment state prominently.

### No Customer Attached

Display:

```text
Customer
None attached

[Link customer]
```

The **Link customer** action opens the same customer lookup modal used by `/customer`.

### Customer Attached

Display:

```text
Customer
Smith, Jane

[Remove]
```

The status block should show:

* Customer display name
* Optional customer identifier or request context if useful
* Remove action

### Remove Customer

Add a remove/detach customer action from the POS workspace.

Behavior:

* Removes the customer from the current editable transaction.
* Re-renders the workspace.
* Does not affect transaction lines, tenders, discounts, or tax exemptions.
* Is not available after completion.

### Customer Permissions

The visible customer link/remove actions should follow the same POS customer permissions used by the `/customer` workflow.

For this slice:

* Linking existing customer is in scope.
* Removing customer is in scope.
* Creating/editing customer records is out of scope.

## Transaction Discount Status

Transaction discount should move out of the hidden/inline adjustments form and into the right-side status panel.

### Inactive State

Display:

```text
Transaction Discount
None

[Add discount]
```

The block or button opens the transaction discount modal introduced in Phase 10-C 9A.

### Active State

Display active transaction-level discounts:

```text
Transaction Discount

Promo      -$5.00    [Remove]
Loyalty    -$3.00    [Remove]

[Add discount]
```

Rules:

* The status panel lists active transaction discount applications.
* Each active discount has a remove action when the cashier has permission.
* Clicking **Add discount** opens the transaction discount modal.
* Clicking the transaction discount block may also open the modal.
* The old inline transaction discount form should not be shown in the adjustments panel.

### Cash Rounding

Remove the cash rounding field from the POS transaction workspace for this slice.

Cash rounding may return later as a focused workflow if needed, but it should not remain inside the discount/status area.

## Tax Exemption Status

Tax exemption should follow the same status-panel pattern as transaction discount.

### Inactive State

Display:

```text
Tax Exempt
Not applied

[Apply]
```

The block or button opens the tax exemption modal introduced in Phase 10-C 8/9A.

### Active State

Display:

```text
Tax Exempt
Applied: Nonprofit exemption
Certificate: 12345

[Remove]
```

Rules:

* Active tax exemption is clearly indicated.
* Remove action is shown when permitted.
* Clicking **Apply** opens the tax exemption modal.
* The old inline tax exemption form should not remain in the adjustments panel.
* The status block may be visually highlighted when active.

## Right-Side Totals and Status Panel

The right side of the transaction workspace should contain:

1. Totals panel
2. Status panel
3. Complete Transaction action

### Totals Panel

Show compact transaction totals:

* Subtotal
* Discounts
* Tax subtotal by rate/category when useful — each row shows category/rate label, **tax amount**, and (subtly) **taxable base** and **rate** where applicable
* Total
* Items sold
* Items returned

Tax breakdown rows use a two-level presentation:

* **Primary (scannable):** category or rate short name and tax amount (right-aligned).
* **Subtle (secondary):** taxable base amount and rate detail — smaller or muted type, inline in parentheses, or on a secondary line — so cashiers can reconcile tax without competing with the amount due.

Example:

```text
Total: $24.32

Subtotal                    $25.98
Discounts                   -$2.50
Taxable 6.00%    ($8.50)     $0.51
Food/Beverage 8.25% ($4.00)   $0.33

Items Sold                      4
Items Returned                  —
```

In the example above, `($8.50)` and `($4.00)` are the **taxable bases** for that rate/category; `6.00%` / `8.25%` are the **rates**; `$0.51` / `$0.33` are the **tax amounts**. Bases and rates use subtle styling relative to the tax amount column.

Rules:

* Omit taxable base when zero or not applicable (e.g. non-taxable-only transactions).
* Group by the same tax snapshot dimensions already used in POS tax totals reporting (`tax_totals` / line tax snapshots).
* Do not add new tax calculation behavior; display only from existing transaction line tax snapshots.

### Status Panel

Show operational state:

* Customer
* Transaction Discount
* Tax Exempt

Example:

```text
Customer
Smith, Jane [remove]

Transaction Discount
Promo      -$5.00 [remove]
Loyalty    -$3.00 [remove]

Tax Exempt
Applied [remove]
```

### Complete Transaction

Keep a clear **Complete Transaction** action in the right-side panel.

This action opens or submits into the settlement/tender workflow as already implemented in Phase 10-C 9B.

Do not show the old persistent readiness/completion workflow panel.

## Remove Persistent Completion Workflow Panel

Remove or significantly reduce the panel that permanently shows checklist-style readiness items such as:

```text
Register is open
Add lines
All items active
Enter tender amounts
```

Readiness information should be contextual:

* Show blockers when the cashier attempts to tender/complete.
* Show warnings only when something needs attention.
* Keep the right rail focused on totals and transaction status.

Acceptable retained behavior:

* A compact warning if completion is currently blocked by an actionable issue.
* Readiness details inside the tender/settlement modal.
* Existing supervisor authorization behavior when required.

## Cart Layout

Revise cart columns to align with transaction-summary use.

### Recommended Columns

```text
Qty | SKU / Description | Tax | Discount | Line Total | More
```

### Column Behavior

#### Qty

Display quantity with plus/minus controls where applicable.

Example:

```text
[-] 2 [+]
```

Rules:

* Plus/minus controls update quantity.
* Return lines should remain understandable.
* Gift card sale lines and other special lines should follow existing quantity edit rules.

#### SKU / Description

Show the identifying and descriptive information currently shown in cart lines:

* SKU / barcode / variant identifier
* Product or variant description
* Pickup/return context
* Customer request number, if applicable
* Relevant line metadata

Example:

```text
PICKUP 9780123456789-UG-XX
The Name of the Item
Pickup for customer Request REQ-001-000008
```

#### Tax

Show:

* Tax label / category / rate short name (primary)
* Line **tax amount** (subtle — secondary/muted typography so the column supports reconciliation without pulling focus from item, discount, and line total)

Example:

```text
Taxable
($0.51)
```

Or inline:

```text
Taxable ($0.51)
```

In both patterns, the **category label** is primary and the **tax amount** is subtle.

Rules:

* Show `—` when the line is non-taxable or tax is zero.
* Use existing line tax snapshot fields (`applied_tax_source`, tax category label, `tax_cents`); do not join live catalog tax tables in the cart view.
* Line tax indicator letter/badge in the description column may remain; the Tax column is the amount-focused view.

#### Discount

Show line and transaction discount impact.

Example:

```text
-$2.50
Line: $1.25
Trans: $1.25
```

Rules:

* Show nothing or `—` if no discount applies.
* Make it clear when transaction discount allocation affects the line.
* Do not require the cashier to open More just to see that a discount exists.

#### Line Total

Show the final line total after line-level and transaction-level discount allocation where applicable. For rows with quantity > 1, include per unit price.

Example:

```text
$8.50
```

#### More

Keep the existing Phase 10-C 9 More menu behavior.

Expected menu items:

* Change quantity/price
* Discount line
* Change tax
* Remove line

The More menu should remain task-specific and should not reopen the old oversized expanded row.

### Price Column

A separate Price column is optional.

Preferred direction:

* Remove the standalone Price column from the default cart view.
* Keep unit price visible in the line detail text underneath the line total.
* Add it back only if manual QA shows cashiers need it constantly visible.

## Flash Messages

Flash messages should be manually dismissible and auto-clearing.

Rules:

* Flash appears in a consistent location below the header.
* User can dismiss manually.
* Non-critical notices auto-clear after a short delay.
* Errors and blocking alerts may persist longer or require manual dismissal.
* Auto-clear should not remove focus from the command box.
* Auto-clear should not close modals/drawers or interrupt active input.

Suggested timing:

| Flash Type  | Behavior                                                               |
| ----------- | ---------------------------------------------------------------------- |
| Notice      | Auto-clear after 4–6 seconds.                                          |
| Success     | Auto-clear after 4–6 seconds.                                          |
| Alert/Error | Remain until dismissed, or use longer timeout if clearly non-blocking. |

## Receipt Preview Return Path

Clean up receipt preview navigation so it supports the completed transaction workflow introduced in Phase 10-C 9B.

Rules:

* Receipt preview opened from a completed transaction should return to the completed transaction workspace.
* The primary post-transaction path remains the completed workspace.
* Receipt preview should not send cashiers to the generic transaction show page as the main continuation path.
* The completed workspace remains the place where cashier completes receipt/slip follow-up and starts the next sale.

Recommended behavior:

```text
Completed workspace
→ View/Print Receipt
→ Receipt preview
→ Back
→ Completed workspace
```

## Header Actions Behavior

### Stored Value Balance Inquiry

* Opens the balance inquiry modal.
* Available even when register is closed.
* Does not create a draft transaction.

### Session

* Opens the session drawer.
* Available when a register session exists.
* If no session exists, show a clear message or disabled menu item.

### Cash In / Cash Out

* Opens cash movement modal.
* Requires open register.
* Uses existing `/cashin` and `/cashout` behavior.
* Should not be duplicated as large idle buttons.

### Close Register

* Runs existing `/close` behavior.
* Blocks active draft.
* May warn/show held sales according to existing policy.

### Reports

* Navigates to reports.
* Confirms when leaving an active draft, as already implemented.

### Drawer

* Opens cash drawer guidance modal.
* Uses existing `/drawer` behavior.

## Permissions

All visible mouse/touch actions should use the same permission model as the corresponding command.

Examples:

| UI Action                   | Permission Source                      |
| --------------------------- | -------------------------------------- |
| Link customer               | Same as `/customer`                    |
| Add transaction discount    | Same as `/discount`                    |
| Remove transaction discount | Existing discount void permission      |
| Apply tax exemption         | Same as `/taxexempt`                   |
| Remove tax exemption        | Existing tax exemption void permission |
| Cash In / Cash Out          | Same as `/cashin` and `/cashout`       |
| Close Register              | Same as `/close`                       |
| Reports                     | Same as `/reports`                     |
| Drawer                      | Same as `/drawer`                      |

Do not show actionable controls that will fail for permission reasons unless they are intentionally shown disabled with an explanation.

## Accessibility and Keyboard Expectations

* Header Actions menu must be keyboard accessible.
* Menu items must be reachable by tab and arrow key behavior if using a menu pattern.
* Command box remains primary focus after non-blocking actions.
* Modals and drawers keep existing 10-A focus trapping/restore behavior.
* Status panel buttons must have clear accessible labels.
* Cart plus/minus buttons must have line-specific accessible labels.
* Auto-clearing flashes must not steal focus.
* Modal launchers from status panel should restore focus predictably after close.

## Acceptance Criteria

### Header and Actions

* POS header shows workstation/register identifier, register status, and business date.
* Redundant “Register Open - Business Date” text above command bar is removed.
* Header includes Actions menu.
* Actions menu includes:

  * Stored Value Balance Inquiry
  * Session
  * Cash In
  * Cash Out
  * Close Register
  * Reports
  * Drawer
* Actions route to the same workflows as their slash commands.
* Balance inquiry remains available when register/session is closed.
* Register-required actions are disabled or return a clear open-register message when closed.

### Idle Workspace

* Idle workspace no longer shows large redundant New Sale, Cash In/Out, and Reports buttons.
* Idle workspace keeps command input as the primary interaction.
* Idle workspace keeps Open Ring and Gift Card mouse equivalents.
* Idle Open Ring and Gift Card actions behave like their slash commands.

### Customer Status

* Active transaction shows attached customer when present.
* No-customer state shows Link customer action.
* Link customer opens the existing customer lookup modal.
* Attached customer state shows remove action.
* Remove customer detaches customer from editable transaction and refreshes workspace.
* Customer actions are not available after completion.

### Transaction Discount Status

* Transaction discount appears in the right-side status panel.
* Inactive state shows Add discount action.
* Add discount opens transaction discount modal.
* Active transaction discounts are listed with amounts.
* Active discounts have remove actions when permitted.
* Old inline transaction discount form is removed from the adjustments panel.
* Cash rounding field is removed from the POS workspace.

### Tax Exemption Status

* Tax exemption appears in the right-side status panel.
* Inactive state shows Apply action.
* Apply opens tax exemption modal.
* Active tax exemption is visibly indicated.
* Active tax exemption has remove action when permitted.
* Old inline tax exemption form is removed from the adjustments panel.

### Totals Panel

* Totals panel shows subtotal, discounts, tax breakdown, total, and item counts.
* Each tax breakdown row shows tax amount as the primary value.
* Taxable base and rate appear on the same row with subtle styling (e.g. `Taxable 6.00% ($8.50) $0.51`).

### Cart Layout

* Cart columns are revised to:

  * Qty
  * SKU / Description
  * Tax
  * Discount
  * Line Total
  * More
* Qty column supports existing plus/minus behavior where applicable.
* SKU/Description preserves current line context, including pickup/return details.
* Tax column shows tax category label (primary) and line tax amount (subtle).
* Discount column shows line and transaction discount impact when applicable.
* Line Total shows final line total.
* More menu retains task-specific panels for quantity/price, discount, tax, and remove.

### Completion/Readiness

* Persistent completion readiness panel is removed or reduced to contextual warnings only.
* Complete Transaction remains visible and opens/continues the tender workflow.
* Readiness blockers still appear when attempting tender/completion.
* Supervisor authorization behavior remains intact.

### Flash Messages

* Flash messages are manually dismissible.
* Notice/success flashes auto-clear after a short delay.
* Alert/error flashes persist or use a longer non-disruptive timeout.
* Flash auto-clear does not steal focus from command input.
* Flash auto-clear does not close active modals/drawers.

### Receipt Preview

* Receipt preview opened from completed workspace returns to completed workspace.
* Receipt preview does not make the generic transaction show page the primary post-completion continuation.
* Completed workspace remains the main place to finish document actions and start a new sale.

## Suggested Tests

### Integration Tests

* Header actions render according to permissions and register state.
* Balance inquiry is available from closed POS state.
* Cash In/Cash Out actions require open register.
* Customer can be attached from POS workspace.
* Customer can be removed from editable transaction.
* Transaction discount status panel lists active discounts.
* Remove transaction discount updates status panel.
* Tax exemption status panel shows active exemption.
* Remove tax exemption updates status panel.
* Receipt preview back path returns to completed workspace.

### System Tests

* Command input remains focused after flash auto-clear.
* Header Actions menu can open balance inquiry modal.
* Header Actions menu can open session drawer.
* Header Actions menu can open cash movement modal.
* Link customer opens customer modal.
* Removing customer updates visible customer status.
* Add discount opens transaction discount modal.
* Apply tax exempt opens tax exemption modal.
* Cart More menu still opens task-specific panels.
* Complete Transaction still opens tender workflow.
* Completed transaction receipt preview returns to completed workspace.

### Helper/Service Tests

* Cart line discount display distinguishes line and transaction discount allocation.
* Cart line tax display shows category label (primary) and line tax amount (subtle).
* Cart line tax display distinguishes non-taxable and zero-tax lines.
* Totals panel tax rows show tax amount, taxable base, and rate with primary/subtle hierarchy.
* Status panel helper returns correct customer/discount/tax state.
* Header action availability helper matches command registry permissions.

## Implementation Notes

* Prefer reusing existing command registry permission logic for header action visibility.
* Prefer extracting header action availability into a helper rather than duplicating permission checks in views.
* Keep transaction discount and tax exemption modals as the only form surfaces for those workflows.
* Convert existing adjustments panel into a status/list panel or replace it entirely with the new status panel.
* Keep cart More menu behavior from Phase 10-C 9.
* Keep tender/completion behavior from Phase 10-C 9B.
* Keep session drawer behavior from Phase 10-C 10.
* Avoid adding new pricing, reporting, or accounting semantics in this slice.

## Completion Criteria

This slice is complete when:

* The POS workspace matches the updated layout direction.
* Command, mouse, and keyboard workflows are consistent.
* Redundant legacy buttons and panels are removed.
* Customer, discount, and tax-exempt state are visible without opening hidden forms.
* Active cart lines are easier to scan.
* Header actions provide clear access to register/session utilities.
* Full Phase 10-C manual QA passes.
