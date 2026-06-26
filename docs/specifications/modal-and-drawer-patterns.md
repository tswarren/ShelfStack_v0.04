# Modal and Drawer Patterns

**Status:** Planned (Phase 10-A)

When to use modals vs drawers vs full pages vs expanded rows.

## Modal

**Use for:** bounded decisions that preserve parent context.

Examples: add identifier, edit price, customer lookup, supervisor authorization, gift card activation, balance inquiry, tax exemption, cash drawer action, settlement, confirm void/remove.

**Behavior:**

* Trap focus while open
* Focus first meaningful control
* Esc closes only when safe
* Validation errors stay inside modal
* Turbo updates affected panels on save
* Restore focus to opener on close
* Prevent background scroll

**Avoid for:** full receiving, full PO creation, full buyback intake, full catalog editing.

## Drawer

**Use for:** related detail useful during work but not required for immediate entry.

Examples: variant demand, customer context, session summary, transaction history, stored value detail.

**Behavior:**

* Preserve page state
* Restore focus to opener on close
* Read-only or light editing
* Link to full record for deeper work

**Avoid for:** replacing full workflows.

## Expanded row

**Use for:** line-level bounded edits attached to a table row (POS cart, PO lines).

## Full page

**Use for:** complex multi-section setup, full catalog metadata, workflow pages (buyback session, receiving).

## CSS classes

```text
ss-modal, ss-modal-overlay, ss-modal-dialog, ss-modal-dialog--pos, ...
ss-drawer, ss-drawer-overlay, ss-drawer-panel, ...
ss-expand-row, ss-row-detail, ...
```

## Mockup references

* Items setup modal: [shelfstack_items_mockups.html](../samples/phase-10-mockups/shelfstack_items_mockups.html)
* Items demand drawer: same file, operations screen
* POS settlement modal: [shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html)

## Roadmap

[phase-10a-interaction-infrastructure.md](../roadmap/phase-10a-interaction-infrastructure.md)
