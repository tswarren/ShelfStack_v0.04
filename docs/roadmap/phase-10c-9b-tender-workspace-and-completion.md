# Phase 10-C 9B — Tender Workspace and Completion Ergonomics

## Status

Planned — follows slice **9A** (transaction discount modal); precedes slice **10**.

## Parent Phase

Phase 10-C — POS Keyboard Workspace

## Purpose

Refine the POS tendering and transaction completion workflow so checkout feels fast, intentional, keyboard-friendly, and operationally clear.

Earlier Phase 10-C slices introduced command routing for `/tender`, `/cash`, `/card`, `/check`, `/giftredeem`, and `/storecredit`, but the tendering workflow itself remained close to the prior settlement form behavior. This slice corrects that by treating tendering as a focused transaction-level workspace.

The goal is not to redesign payment architecture. The goal is to make existing tendering and completion behavior ergonomic for front-line bookstore use.

## Summary

This slice keeps tendering in a modal, but redesigns the modal as a keyboard-first tender workspace:

* Tender type selection uses hotkeys.
* Only one tender detail form is active at a time.
* Tender amount defaults are predictable.
* Enter saves the active tender detail form.
* Escape cancels the active tender detail form, or closes the modal when no detail form is active.
* Saving a sufficient tender does not automatically complete the transaction.
* Completion remains an explicit final action.
* After completion, the cashier lands on a completed transaction workspace with document actions and one primary next step: New Sale.

## Design Decision: Modal vs Drawer

Tendering remains a modal for Phase 10-C 9B.

Tendering is a transaction-level closing workflow, not a line-level edit. Once the cashier begins tendering, the system should enter a focused checkout mode where the cashier can:

1. Review the balance due.
2. Select tender type.
3. Enter tender details.
4. Save tender.
5. Complete the transaction.

A drawer would preserve more cart context, but it would also make tendering feel secondary. Cart changes should generally happen before tendering. If the cashier needs to edit the cart, they can close the tender modal, make changes, and tender again.

## Goals

* Make tendering faster and clearer for keyboard-heavy POS use.
* Make tender commands consistent.
* Reduce visual clutter in the settlement UI.
* Support split tender without showing all tender fields at once.
* Make completion an explicit cashier action.
* Improve post-completion ergonomics for receipt printing, stored value slips, future gift receipt printing, summaries, and next-sale flow.
* Preserve existing POS transaction and tender domain behavior unless a small controller/service adjustment is needed for the UX.

## Non-Goals

This slice does not implement:

* Payment processor integration.
* Card-present authorization.
* Signature capture.
* Offline payment capture.
* Receipt printer driver integration.
* Full refund tender redesign.
* Accounting export changes.
* Advanced tender reconciliation.
* Full gift receipt printing.
* Advanced stored value issuance rules beyond the refund restriction described below.
* Major schema redesign.

## Tender Modal Structure

The tender modal should behave as a focused tender workspace.

Recommended layout:

```text
Tender Transaction

Amount due:   $42.17
Tendered:      $0.00
Remaining:    $42.17

[1 Cash] [2 Card] [3 Check] [4 Stored Value]

Active tender detail panel
--------------------------------
Cash
Amount: [$42.17]
[Save Tender] [Cancel]

Saved tenders
--------------------------------
Cash        $20.00       [Remove]
Card        $22.17       [Remove]

[Complete Sale]
```

The modal has three conceptual zones:

1. **Transaction tender summary**

   * Total due
   * Tendered amount
   * Remaining due
   * Change due, when applicable

2. **Tender type selection**

   * Hotkey-driven tender type choices

3. **Tender detail panel**

   * Shows only the fields for the currently selected tender type

Saved tender rows are shown separately from the active tender detail panel.

## Tender Type Hotkeys

While the tender modal is open:

| Key | Tender Type  |
| --- | ------------ |
| `1` | Cash         |
| `2` | Card         |
| `3` | Check        |
| `4` | Stored Value |

Hotkeys apply only while the tender modal is active.

Hotkeys should not interfere with normal typing in text inputs unless no active detail input has focus.

## Tender Commands

Tender commands open the tender modal and preselect the relevant tender type.

| Command        | Behavior                                                          |
| -------------- | ----------------------------------------------------------------- |
| `/tender`      | Open tender modal with no tender type selected.                   |
| `/cash`        | Open tender modal, select Cash, default amount to remaining due.  |
| `/cash 20`     | Open tender modal, select Cash, prefill amount as `20.00`.        |
| `/card`        | Open tender modal, select Card, default amount to remaining due.  |
| `/card 20`     | Open tender modal, select Card, prefill amount as `20.00`.        |
| `/check`       | Open tender modal, select Check, default amount to remaining due. |
| `/check 20`    | Open tender modal, select Check, prefill amount as `20.00`.       |
| `/giftredeem`  | Open tender modal, select Stored Value.                           |
| `/storecredit` | Open tender modal, select Stored Value.                           |

Root/idle tender commands must not create a draft transaction. If there is no active transaction, they return a clear no-active-transaction message.

## Tender Detail Forms

### Cash

Fields:

* Amount

Behavior:

* Amount defaults to remaining due.
* If an amount is passed from the command, use that amount.
* Cursor starts in Amount.
* Amount value is highlighted for quick overwrite.
* `Enter` saves the cash tender.
* `Escape` cancels the unsaved cash tender detail form.

Fast paths:

```text
/cash
Enter
Enter
```

For exact cash:

1. `/cash` opens Cash with remaining due.
2. First `Enter` saves the cash tender.
3. Second `Enter` completes the transaction.

```text
/cash 50
Enter
Enter
```

For cash over tender:

1. `/cash 50` opens Cash with `50.00`.
2. First `Enter` saves the tender.
3. The modal shows change due.
4. Second `Enter` completes the transaction.

### Card

Fields:

* Card type
* Amount
* Last four
* Authorization code

Behavior:

* Amount defaults to remaining due unless an amount was passed from the command.
* If Card type is required, cursor starts in Card type.
* If Card type has a default or is optional, cursor may start in Amount with value highlighted.
* Last four and authorization code may be optional or required based on store policy.
* `Enter` saves the card tender when required fields are valid.
* `Escape` cancels the unsaved card tender detail form.

### Check

Fields:

* Amount
* Check number

Behavior:

* Amount defaults to remaining due unless an amount was passed from the command.
* Cursor starts in Amount with value highlighted.
* Cashier can tab to Check number.
* Check number may be optional or required based on store policy.
* `Enter` saves the check tender when required fields are valid.
* `Escape` cancels the unsaved check tender detail form.

### Stored Value

Stored Value consolidates gift card redemption and store credit redemption into one tender workflow.

Fields:

* Identifier
* Stored value type display
* Balance display
* Amount
* Optional note

Behavior:

* Cursor starts in Identifier.
* After identifier lookup, display:

  * Stored value type, such as Gift Card or Store Credit
  * Current balance
  * Available balance
* Amount defaults to remaining due unless an amount was passed from the command.
* Amount may not exceed available stored value balance.
* `Enter` saves the stored value tender when identifier and amount are valid.
* `Escape` cancels the unsaved stored value tender detail form.

Refund rule:

* For refunds, only Store Credit can be issued.
* Gift Card refund issuance is not supported in this slice.
* Redemption and issuance should be presented distinctly where needed:

  * Stored Value redemption
  * Refund to Store Credit

## Enter and Escape Behavior

### When a Tender Detail Form Is Active

| Key      | Behavior                                         |
| -------- | ------------------------------------------------ |
| `Enter`  | Save active tender detail form if valid.         |
| `Escape` | Cancel active tender detail form without saving. |

Escape should not remove already-saved tender rows. It only cancels the unsaved active detail form.

### When No Tender Detail Form Is Active

| State               | Enter                                | Escape                                        |
| ------------------- | ------------------------------------ | --------------------------------------------- |
| Balance remains due | No-op or select focused tender type. | Close tender modal and return to transaction. |
| Fully tendered      | Complete transaction.                | Close tender modal and return to transaction. |
| Completion blocked  | Focus first blocking issue.          | Close tender modal and return to transaction. |

## Completion Behavior

Saving a tender never automatically completes the transaction.

When saved tenders equal or exceed the balance due, the modal enters a clear “Ready to Complete” state.

Example:

```text
Amount due:   $42.17
Tendered:     $50.00
Change due:    $7.83

Ready to complete

[Enter] Complete Sale
[Esc] Return to Transaction
```

Rules:

* Remaining due is zero.
* Change due is shown when tendered amount exceeds balance due.
* Complete Sale is visually emphasized.
* Focus moves to Complete Sale, or Enter completes when no tender detail form is active.
* Escape returns to the editable transaction without completing.
* The transaction is never automatically completed solely because a sufficient tender was saved.

## Saved Tender Rows

Saved tender rows remain visible in the modal.

Each saved tender row should show:

* Tender type
* Amount
* Key reference detail, when available:

  * Card last four
  * Check number
  * Stored value identifier
* Remove action
* Edit action, if already supported or simple to add

Advanced tender editing can be deferred if needed. Remove/re-add is acceptable for this slice if that keeps scope contained.

## Validation

Tender detail forms validate before saving.

General rules:

* Amount is required.
* Amount must be positive unless a later refund-specific rule allows otherwise.
* Tender amount cannot exceed allowed tender-type limits.
* Required tender detail fields must be present before saving.

Stored Value rules:

* Identifier must resolve to a valid stored value account.
* Balance must be displayed before saving.
* Redemption amount cannot exceed available balance.
* Refund issuance may only create Store Credit.

Card rules:

* Card type should be selected if required by store policy.
* Last four should be captured if required by store policy.
* Authorization code should be captured if required by store policy.

Check rules:

* Check number should be captured if required by store policy.

## Post-Completion Workspace

After successful completion, the cashier should not remain on the editable transaction view.

Instead, POS should show a completed transaction workspace optimized for handoff and next action.

Purpose:

1. Confirm the transaction completed.
2. Show the key financial result.
3. Handle relevant documents.
4. Start the next sale.

## Completed Transaction Workspace Layout

Recommended layout:

```text
SALE COMPLETE

Transaction #001-001-000070
Time: 2:14 PM
Cashier: Tom

Total:        $42.17
Tendered:     $50.00 Cash
Change due:    $7.83

Documents
✓ Receipt printed
! Stored value slip not printed
  [Print Stored Value Slip]

Gift receipt
  Coming in a future enhancement

Primary action:
[New Sale]

Secondary:
[Print Receipt] [Email Receipt] [View Summary] [POS Home]
```

The completed workspace should have one primary action:

```text
New Sale
```

Other document and navigation actions are secondary.

## Completed Workspace Summary

Show a compact receipt-like summary:

* Transaction number
* Transaction type:

  * Sale complete
  * Return complete
  * Exchange complete
* Completion time
* Cashier
* Subtotal
* Discounts
* Tax
* Total
* Tendered amount
* Change due, refund due, or store credit issued

The summary should be easy to scan, but not as large or detailed as the full transaction detail page.

## Document Checklist

The completed workspace should show a document checklist for artifacts relevant to the transaction.

| Artifact          | When shown                                                | Behavior                                                         |
| ----------------- | --------------------------------------------------------- | ---------------------------------------------------------------- |
| Customer receipt  | Always                                                    | Print automatically if configured; otherwise show Print Receipt. |
| Stored value slip | Stored value was issued, activated, reloaded, or adjusted | Show as a separate issued-value document action.                 |
| Refund receipt    | Refund or return transaction                              | Show when applicable.                                            |
| Gift receipt      | Future enhancement                                        | Optional and non-blocking if shown as placeholder.               |
| Exchange summary  | Exchange transaction                                      | Show when applicable.                                            |

Stored value slips are distinct from ordinary customer receipts because they represent issued or modified value.

Stored value redemption does not necessarily require a separate stored value slip. Redemption can usually appear on the normal receipt. The stored value slip is primarily for issued, activated, reloaded, or adjusted stored value.

## Receipt Printing Policy

Receipt behavior should support workstation/store configuration.

Suggested settings:

* Auto-print receipt after completion: yes/no
* Default receipt format: customer/gift/none
* Focus after completion: New Sale or first required document action

Initial recommendation:

* Auto-print customer receipt when configured.
* Always show reprint action.
* Do not block New Sale solely because ordinary customer receipt printing failed.
* Do draw attention to required unprinted stored value slips.

## Stored Value Slip Behavior

When stored value is issued, activated, reloaded, or adjusted, the completed workspace should show a stored value slip action.

Examples:

```text
Gift card issued
Card ending: 1234
Amount: $25.00
Balance: $25.00

[Print Stored Value Slip]
```

```text
Store credit issued
Credit memo: SC-000123
Amount: $14.82

[Print Stored Value Slip]
```

If store policy marks stored value slips as required, show the item as incomplete until printed.

## Gift Receipt Placeholder

Gift receipt printing is reserved for a future enhancement.

For this slice:

* Gift receipt may be shown as a disabled/planned action or omitted from the UI.
* Gift receipt is always optional.
* Gift receipt must not block New Sale.
* The `G` shortcut is reserved for future gift receipt printing.

## Completed Workspace Keyboard Behavior

Suggested shortcuts:

| Key      | Action                                                                                   |
| -------- | ---------------------------------------------------------------------------------------- |
| `Enter`  | New Sale, unless a required document action needs attention.                             |
| `P`      | Print/reprint receipt.                                                                   |
| `V`      | Print stored value slip, when stored value was issued, activated, reloaded, or adjusted. |
| `G`      | Reserved for gift receipt printing; optional future enhancement.                         |
| `S`      | View summary/details.                                                                    |
| `Escape` | POS idle/home.                                                                           |

If required artifacts are unprinted, Enter may first focus the required document action instead of starting a new sale.

For this slice, this blocking behavior should be limited to required issued-value documents, represented by the consolidated stored value slip. Ordinary customer receipt printing and future gift receipt printing are non-blocking.

## Routing Recommendation

Separate the cashier completion workspace from the permanent transaction detail/show page.

Immediately after completion, route to a completed POS workspace:

```text
/pos/transactions/:id/completed
```

or render the existing transaction page in a completed workspace mode.

The completed workspace is not an editable transaction state. Cart lines, discounts, tax overrides, and tenders are read-only after completion. Any correction workflow must use a later void, refund, or adjustment flow rather than reopening the completed transaction.

The regular transaction show page should remain informational and audit-focused:

* Lines
* Tenders
* Discounts
* Taxes
* Receipts/documents
* Audit trail

It should not be the main post-sale cashier workflow.

## New Sale Target

The completed workspace should not show competing primary actions such as “POS Menu” and “New Transaction.”

New Sale is the single primary target.

New Sale returns the cashier to the POS idle/new-sale state. Implementation may route to `/pos` and let the active draft resolver determine the correct workspace state.

## Interaction With Existing Commands

Tender commands continue to route through the Phase 10-C command registry.

Expected behavior:

* `/tender` opens modal.
* `/cash`, `/card`, `/check`, `/giftredeem`, `/storecredit` open modal with the proper tender type.
* Root tender commands return no-active-transaction message and do not create a draft.
* Command-bar focus does not steal focus while the tender modal is open.
* Closing the tender modal restores focus to the command bar.
* Completing the transaction moves to the completed workspace.

## Acceptance Criteria

### Tender Modal

* `/tender` opens the tender modal without selecting a tender type.
* `/cash` opens Cash with remaining balance prefilled and highlighted.
* `/cash 20` opens Cash with `20.00` prefilled and highlighted.
* `/card` opens Card with remaining balance prefilled unless a command amount is passed.
* `/card 20` opens Card with `20.00` prefilled.
* `/check` opens Check with remaining balance prefilled unless a command amount is passed.
* `/check 20` opens Check with `20.00` prefilled.
* `/giftredeem` and `/storecredit` open Stored Value tender flow.
* Hotkeys `1`, `2`, `3`, and `4` select tender types while the modal is open.
* Only the selected tender type’s detail fields are shown.
* Saved tender rows remain visible separately from the active tender detail panel.
* Root tender commands do not create a draft transaction.
* Command-bar focus does not steal focus while the tender modal is open.

### Tender Detail Save/Cancel

* Enter saves the active tender detail form when valid.
* Escape cancels the active tender detail form without saving.
* Escape closes the tender modal when no tender detail form is active.
* Escape does not remove already-saved tender rows.
* Invalid tender details keep focus inside the tender modal and show clear validation.

### Completion

* Saving a sufficient tender does not automatically complete the transaction.
* When balance due is fully covered, the modal shows a Ready to Complete state.
* Enter completes the transaction from Ready to Complete state.
* Escape returns to the editable transaction without completing.
* Completion creates the expected tender records and finalizes the transaction using existing completion services.

### Completed Workspace

* After completion, POS shows a completed transaction workspace rather than the editable transaction screen.
* Completed workspace shows transaction number, total, tendered amount, and change/refund/store credit result.
* Completed workspace shows relevant document actions:

  * customer receipt
  * stored value slip, when stored value was issued, activated, reloaded, or adjusted
  * refund receipt, when applicable
  * gift receipt placeholder, if shown, as a non-blocking future enhancement
* Completed workspace has one primary action: New Sale.
* New Sale returns to the POS idle/new-sale state.
* Enter starts a new sale when no required document action needs attention.
* If a required stored value slip is unprinted, Enter focuses that document action instead of starting a new sale.
* Gift receipt is always optional and non-blocking.
* Secondary actions include Print/Reprint Receipt, Email Receipt if supported, View Summary, and POS Home.
* Completed transactions are read-only from the completed workspace.

## Suggested Tests

### Service / Router Tests

* `/tender` routes to settlement modal with no selected tender type.
* `/cash` routes to Cash tender offer with `prefill_remaining`.
* `/cash 20` routes to Cash tender offer with `amount_cents`.
* `/card 20` routes to Card tender offer with `amount_cents`.
* `/check 20` routes to Check tender offer with `amount_cents`.
* `/giftredeem` and `/storecredit` route to Stored Value tender offer.
* Root `/cash` returns no-active-transaction message and does not create a draft.

### Integration Tests

* Active transaction `/cash` opens settlement response with cash payload.
* Active transaction `/card 20` opens settlement response with card amount payload.
* Saving exact tender marks modal as ready to complete but does not finalize immediately.
* Complete action finalizes transaction only after explicit completion.
* Escape/cancel tender detail does not create a tender row.
* Stored Value tender requires valid identifier before save.
* Stored Value amount cannot exceed available balance.
* Completion redirects or renders the completed workspace.
* Completed workspace is read-only.
* New Sale returns to the POS idle/new-sale state.

### System / Interaction Tests

* `/cash` opens tender modal, amount is highlighted.
* `1`, `2`, `3`, and `4` select tender types while modal is open.
* Enter saves active tender detail form.
* Escape cancels active tender detail form.
* Escape closes modal when no detail form is active.
* After sufficient tender, Enter completes transaction.
* After completion, completed workspace appears.
* New Sale from completed workspace returns to idle/new-sale state.
* Print Receipt is visible.
* Stored Value Slip is visible when stored value was issued, activated, reloaded, or adjusted.
* Gift receipt placeholder is optional and non-blocking if shown.
* Enter focuses required unprinted stored value slip action instead of starting a new sale.

## Implementation Notes

* Reuse existing command registry and route builder behavior where possible.
* Reuse existing tender models and completion service.
* Prefer improving the settlement panel/controller over introducing a parallel tender model.
* Keep stored value redemption and store credit issuance conceptually distinct even if the UI uses a shared Stored Value tender entry point.
* Avoid auto-completion on tender save.
* Keep completion explicit.
* Keep completed transaction workspace separate from editable transaction state.
* Treat completed transactions as read-only in the completed workspace.

## Related Documents

```text
docs/roadmap/phase-10c-pos-keyboard-workspace.md
docs/roadmap/phase-10c-9a-transaction-discount-modal.md
docs/specifications/phase-10c-pos-keyboard-workspace-spec.md
docs/specifications/phase-10c-test-plan.md
docs/implementation/phase-10c-completion.md
docs/samples/phase-10-mockups/shelfstack_pos_mockups.html
```
