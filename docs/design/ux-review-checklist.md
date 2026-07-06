# ShelfStack UX Review Checklist

*Created: 2026-07-05*

Use this checklist during PR review for new screens, major view changes, workflow changes, and component/CSS changes.

For the broader rationale, see [ux-guide.md](ux-guide.md). For feedback class names and migration rules, see [components.md](components.md#feedback-naming-standard).

## Required review outcome

A UX review should identify one of three outcomes:

- **Approved** — the screen follows the guide and needs no UX changes.
- **Approved with follow-up** — the screen is acceptable, but specific UX cleanup should be tracked.
- **Needs revision** — the screen introduces confusion, risk, inconsistency, or workflow friction that should be corrected before merge.

## 1. Orientation

- [ ] The page clearly identifies where the user is.
- [ ] The record, workflow, or queue status is visible near the top.
- [ ] Store, workstation, register session, customer, or document context is visible when relevant.
- [ ] The screen makes clear whether the user is viewing, editing, posting, completing, voiding, or reviewing.
- [ ] The page title uses operational language, not generic CRUD language.

## 2. User task fit

- [ ] The layout supports the actual user task.
- [ ] The screen does not feel like a generic database editor unless it is truly a setup/admin table.
- [ ] Common tasks require minimal navigation and minimal repeated typing.
- [ ] Scanner/keyboard workflows are supported where relevant.
- [ ] The most important information is visible before lower-priority details.

## 3. Action hierarchy

- [ ] There is one clear primary action per page/form/section.
- [ ] Secondary actions are visually lower priority than the primary action.
- [ ] Cancel, back, close, logout, and lock session use tertiary or link treatment.
- [ ] Destructive actions use danger styling only when the action is actually risky or irreversible.
- [ ] The screen does not rely on button order alone to communicate action importance.
- [ ] Row actions are consistent with similar tables elsewhere in the app.

## 4. Safety and confirmation

- [ ] Posting, voiding, cancelling, reversing, closing, deleting, inactivating, or force-closing actions are confirmed.
- [ ] Confirmation copy explains what will change.
- [ ] Inventory consequences are explicit when inventory changes.
- [ ] Tender, stored-value, refund, or drawer consequences are explicit when money changes.
- [ ] Irreversible or hard-to-reverse actions are clearly identified.
- [ ] Audit/history-preserving behavior is explained where it matters.

## 5. Information hierarchy

- [ ] Summaries appear before details.
- [ ] Warnings and exceptions are easy to find.
- [ ] Details are grouped into meaningful sections.
- [ ] Dense information uses tables, cards, sections, metrics, or collapsibles rather than unstructured text.
- [ ] Supporting context is in a sidebar, sheet, tab, or secondary section rather than mixed into the primary task flow.
- [ ] Critical warnings are not hidden inside collapsed sections.

## 6. Components and CSS

- [ ] Existing ShelfStack components are used before adding new classes.
- [ ] New classes follow `.ss-component`, `.ss-component__element`, `.ss-component--variant` naming.
- [ ] UI state uses `.is-*` classes.
- [ ] Business status uses `.status-*` classes.
- [ ] Generic patterns go in generic component CSS.
- [ ] Domain-specific patterns go in the appropriate `shelfstack.domain.*.css` file.
- [ ] New feature styles are not added to `shelfstack.css` or `shelfstack.legacy.css` (see [app/assets/stylesheets/README.md](../../app/assets/stylesheets/README.md)).
- [ ] Experimental CSS is not imported by `application.css`.

## 7. Forms

- [ ] Every input has a visible label or equivalent accessible label.
- [ ] Helper text is present where the field needs explanation.
- [ ] Validation errors are displayed near the affected field.
- [ ] Related fields are grouped with fieldsets or clear sections.
- [ ] Form actions are visually separated from form content.
- [ ] Required fields are clear without relying on color alone.
- [ ] The primary submit action appears once.
- [ ] Cancel/back actions are tertiary or link-style.

## 8. Tables and queues

- [ ] Long lists have filtering or search where useful.
- [ ] Data tables have a clear summary of what is being shown.
- [ ] Numeric values are aligned and easy to scan.
- [ ] Status is shown with consistent labels/badges.
- [ ] Row actions are discoverable and consistent.
- [ ] Empty states explain what happened and what the user can do next.
- [ ] Pagination or scrolling behavior is appropriate for expected list size.
- [ ] Important exceptions are visible in the row or table summary.

## 9. Alerts, flash, toast, and dialogs

- [ ] Persistent page warnings use `.ss-alert` / `.ss-alert--*` (not page-level flash).
- [ ] Server responses after navigation/submission use `.ss-flash--*` via `flash_region` (not legacy `.flash-alert`).
- [ ] Form validation uses field errors or `.ss-alert--error` near the form (not a generic flash block).
- [ ] Temporary inline/Turbo feedback uses `.ss-toast--*` via `toast_region`.
- [ ] POS workspace warnings use `.ss-pos-alert` where appropriate (separate from global flash).
- [ ] Focused modal tasks use dialog/modal partials (`shared/interaction/_modal`).
- [ ] Risky confirmations use alert dialogs.
- [ ] The screen does not use a modal when an inline section, sheet, or page flow would be clearer.

## 10. POS-specific review

- [ ] The POS header shows session/register details on the left and actions on the right.
- [ ] The command bar is its own row.
- [ ] The transaction mode is visually associated with the command input.
- [ ] Quick actions such as Open Ring and Gift Card are on a separate row.
- [ ] Totals, tender state, readiness, and warnings are easy to scan.
- [ ] Scanner and keyboard workflows are not blocked by layout or focus issues.
- [ ] Destructive POS actions require confirmation.
- [ ] POS remains calm and operational, without unnecessary decorative complexity.

## 11. Inventory, demand, and purchasing review

- [ ] Posted inventory effects are clear before posting.
- [ ] Quantity changes and accepted/rejected/damaged/backordered states are distinguishable.
- [ ] Document status is visible and consistent.
- [ ] Vendor source warnings are visible where relevant.
- [ ] Demand state is clear: open, allocated, ordered, ready for pickup, fulfilled, cancelled, or expired.
- [ ] Special order / TBO / stock consideration language is used consistently.
- [ ] The workflow explains what happens next.

## 12. Reports and print review

- [ ] Report title, generated date/time, and scope are visible.
- [ ] Filters and assumptions are shown.
- [ ] Summary metrics appear before detail tables.
- [ ] Exception notes are visible.
- [ ] Print views hide app chrome and interactive-only controls.
- [ ] Print views include enough context to stand alone.
- [ ] Letter-size reports and receipt/slip layouts fit their intended format.

## 13. Accessibility review

- [ ] Keyboard navigation works for the main workflow.
- [ ] Focus states are visible.
- [ ] Buttons, links, and controls have clear text labels.
- [ ] State is not communicated through color alone.
- [ ] Text contrast is readable.
- [ ] Accessible View remains usable.
- [ ] Compact View remains understandable.
- [ ] Touch targets are large enough for register and tablet use where relevant.
- [ ] There are no right-click-only workflows.

## 14. Responsive review

- [ ] Header content wraps cleanly on smaller screens.
- [ ] Action rows wrap without losing meaning.
- [ ] Tables scroll or adapt appropriately.
- [ ] Cards collapse to a readable one-column layout.
- [ ] POS command rows stack cleanly on narrow screens.
- [ ] No important action disappears at smaller widths.

## 15. Copy review

- [ ] Labels use plain bookstore operations language.
- [ ] Buttons describe the action, not just `Submit` or `Process`.
- [ ] Risky actions describe the consequence.
- [ ] Empty states are helpful and specific.
- [ ] Status labels are consistent with the domain.
- [ ] The screen avoids vague labels such as `Manage`, `Update record`, `Proceed`, or `Do it` unless the context is unmistakable.

## 16. Anti-pattern check

- [ ] No unrelated multiple primary actions.
- [ ] No page-specific button hierarchy rules.
- [ ] No new one-off CSS where a component exists.
- [ ] No destructive action without confirmation.
- [ ] No critical warning hidden below the fold or inside a collapsed section.
- [ ] No badges that look clickable but are not.
- [ ] No context-menu-only workflows.
- [ ] No dense table without filter/summary/empty-state support.
- [ ] No POS screen using unreviewed back-office density assumptions.

## PR reviewer notes

When leaving UX feedback, prefer actionable comments:

```text
Move this warning above the table so staff see it before posting.
Use `.ss-btn-tertiary` for Cancel; Save should be the only primary action.
This should be an Alert Dialog because it posts inventory.
The empty state should explain whether no records exist or filters removed them.
This lookup result needs SKU, condition, on-hand, and inactive warning before selection.
```

Avoid vague feedback:

```text
Make this cleaner.
This feels off.
Needs polish.
Use better UI.
```
