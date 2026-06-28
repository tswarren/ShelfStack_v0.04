# Phase 10-C 9A — Transaction Discount Modal Ergonomics

## Status

Planned

## Parent Phase

Phase 10-C — POS Keyboard Workspace

## Purpose

Move transaction-level discount/adjustment into a focused modal so `/discount` and related commands take the cashier directly to the task.

Today, `/discount`, `/di`, and `/dt` open the **Discount/Adjustment** `<details>` panel on the transaction workspace. That panel works as a fallback but is too hidden for keyboard-first POS use. Cashiers should not tab through the page or hunt for a collapsed panel after entering a command.

This slice does **not** change discount domain rules, allocation math, or authorization requirements. It changes **where and how** transaction discount is applied in the POS workspace.

## Summary

```text
Transaction discount / adjustment → modal
Line discount                    → More menu / inline row panel (slice 9)
Tendering                        → modal (slice 9B)
```

Transaction discount is a **transaction-level action**, not a cart-line action. It belongs alongside other focused task modals:

| Command | Surface |
| ------- | ------- |
| `/discount`, `/di`, `/dt` | Transaction discount modal |
| `/linediscount`, `/ld`, legacy `/d` | Current line discount panel |
| `/tender`, tender shortcuts | Tender modal (9B) |
| `/customer` | Customer lookup modal |
| `/taxexempt`, `/tx` | Tax exemption modal |

## Design Decision: Modal vs Drawer vs Inline Panel

**Modal** is the right surface for transaction discount.

* The workflow is short and focused: open → reason → amount → authorize if needed → apply.
* A drawer would keep cart context visible longer than needed for this task.
* The existing adjustments `<details>` panel is too low-visibility for command-driven entry.

**Do not remove** the adjustments panel in this slice. Convert it into a secondary entry point that lists existing transaction discounts and offers a button to open the modal.

## Goals

* `/discount` opens a transaction discount modal immediately.
* Focus lands on the first meaningful field (Reason by default).
* Modal includes enough summary context that the cashier does not need the underlying page.
* Show a **preview total after discount** before apply.
* Enter applies when valid; Escape closes without applying.
* Manager authorization success returns to Apply or auto-submits when appropriate (same pattern as line discount).
* Reuse existing discount fields, validation, and `Pos::DiscountApplicationService`.
* Preserve line discount in the cart More menu / inline panel (slice 9).

## Non-Goals

* Redesigning line discount UX (slice 9).
* Tender workspace or post-completion flow (slice 9B).
* New discount domain rules or stacking behavior.
* Removing legacy `Pos::DiscountCalculator` bridge paths unless already planned elsewhere.
* Command-line amount parsing beyond documented aliases (optional enhancement).

## Current State (pre-9A)

* `_adjustments_panel.html.erb` hosts the transaction discount form inside a `<details>` summary panel.
* `Pos::CommandBarRouter` / registry route `/discount` → `transaction_discount_offer`.
* `pos_command_bar_controller.js` calls `openTransactionDiscountPanel(true)`, which opens the `<details>` element and scrolls it into view.
* Form reuses `_discount_fields.html.erb` and `pos-discount-input` controller.
* Apply posts to `apply_transaction_discount`.

## Target Modal Layout

```text
Transaction Discount

Eligible discount base:     $42.17
Current transaction discount: $0.00
Current total:              $42.17
Preview total after discount: $37.95

Reason: [__________]
Discount: [%] [$] [____]
Note: [__________]
Manager authorization, if needed

[Apply Discount] [Cancel]
```

The preview total is required for cashier confidence before apply.

## Command Behavior

### `/discount`

```text
/discount
→ open Transaction Discount modal
→ focus: Reason
```

### Amount on command line (enhancement)

Support convenience prefill where unambiguous:

```text
/dt 10%     → modal open, percent mode, 10 prefilled/highlighted
/di 5       → modal open, amount mode, $5.00 prefilled/highlighted
```

Bare `/discount 10` is ambiguous (percent vs amount). Prefer explicit aliases above. If `/discount` receives an amount argument, document chosen convention or reject with a helpful message.

### Line vs transaction command split (unchanged)

```text
/ld, /linediscount, /d   → line discount panel (slice 9)
/dt, /di, /discount       → transaction discount modal (this slice)
```

`/d` must **not** open transaction discount.

## Keyboard and Authorization

| Key | Behavior |
| --- | -------- |
| `Enter` | Apply discount when form is valid |
| `Escape` | Close modal without applying |
| Manager auth success | Return focus to Apply Discount, or auto-submit if cashier had clicked Authorize while applying (match line discount flow) |

While the modal is open, command-bar focus must not steal focus from modal fields.

## Adjustments Panel After 9A

The existing Discount/Adjustment area becomes a **summary + launcher**, not the primary form host:

```text
Discount/Adjustment
  Eligible base / current transaction discount summary
  [Apply Transaction Discount]   → opens modal
  Existing transaction discount applications + void/remove
  Cash rounding (unchanged)
```

The apply form itself lives in the modal.

## Implementation Notes

* Add modal shell to `pos/shared/_workspace_modals.html.erb` (same 10-A pattern as tax exemption and customer lookup).
* Extract modal body partial from adjustments panel form; keep shared `_discount_fields`.
* Replace `openTransactionDiscountPanel` with modal open + focus Reason (or amount when prefilled from command).
* Server-side error handling should reopen modal with submitted values and invalid field highlights (align with line discount `@line_panel_error` pattern or transaction-scoped equivalent).
* Preview total may require a lightweight recalc endpoint or client-side estimate from eligible base + entered discount — prefer server-authoritative preview if easy to reuse existing recalc paths.
* Update `pos_workspace_focus_controller.js` skip list to include transaction discount modal while open.

## Acceptance Criteria

### Modal entry

* `/discount`, `/di`, and `/dt` open the transaction discount modal (not the adjustments `<details>` panel).
* Visible **Apply Transaction Discount** control in adjustments panel opens the same modal.
* Modal uses shared 10-A interaction shell (focus trap, Escape, backdrop close when safe).

### Focus and keyboard

* `/discount` focuses Reason field on open.
* Prefilled command amounts focus/highlight the amount field appropriately.
* Enter applies when valid; Escape closes without applying.
* Command bar does not reclaim focus while modal is open.

### Context and preview

* Modal shows eligible discount base, current transaction discount, current total, and preview total after discount.
* Preview updates when discount type/value changes (debounced if server-backed).

### Apply and errors

* Successful apply closes modal, refreshes workspace totals, restores focus to command bar.
* Validation errors keep modal open with field highlights.
* Manager authorization required reasons follow the same authorize-then-apply pattern as line discount.

### Adjustments panel

* Adjustments panel no longer hosts the primary apply form inline.
* Existing transaction discount list and void/remove actions remain accessible.
* Cash rounding section unchanged.

### Command separation

* `/ld` and `/linediscount` still open line discount panel only.
* `/d` still opens line discount only (legacy).
* `/discount` does not open line discount.

## Suggested Tests

### Router / command tests

* `/discount` on active transaction → `transaction_discount_offer` with modal target (not panel scroll).
* `/dt 10%` → offer includes percent prefill payload when implemented.
* `/di 5` → offer includes amount prefill payload when implemented.
* `/d` → line discount offer, not transaction discount.

### Integration tests

* `/discount` response opens modal markup / turbo update includes modal visible state.
* Apply transaction discount via modal posts successfully and updates totals.
* Invalid apply reopens modal with submitted values.
* Authorization-required reason blocks apply until authorized, then succeeds.
* Adjustments panel launcher opens same modal.

### System / interaction tests

* `/discount` → Reason focused.
* Enter applies valid discount.
* Escape closes modal without apply.
* Preview total visible and changes with input.

## Related Documents

```text
docs/roadmap/phase-10c-pos-keyboard-workspace.md
docs/roadmap/phase-10c-9b-tender-workspace-and-completion.md
docs/specifications/phase-10c-pos-keyboard-workspace-spec.md
docs/specifications/phase-10c-test-plan.md
docs/implementation/phase-10c-completion.md
docs/specifications/phase-8.5-1-pos-discount-spec.md
```
