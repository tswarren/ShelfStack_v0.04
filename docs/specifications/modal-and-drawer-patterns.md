# Modal and Drawer Patterns

**Status:** Phase 10-A implemented

When to use modals vs drawers vs full pages vs expanded rows.

## Modal

**Use for:** bounded decisions that preserve parent context.

Examples: add identifier, edit price, customer lookup, supervisor authorization, gift card activation, balance inquiry, tax exemption, cash drawer action, settlement, confirm void/remove.

**Behavior:**

* Trap focus while open
* Focus first meaningful control
* Esc closes only when safe (dirty/submitting/validation guard)
* Validation errors stay inside modal
* Turbo updates affected panels on save
* Restore focus to opener on close
* Prevent background scroll (stack-aware body lock)

**Avoid for:** full receiving, full PO creation, full buyback intake, full catalog editing.

## Drawer

**Use for:** related detail useful during work but not required for immediate entry.

Examples: variant demand, customer context, session summary, transaction history, stored value detail.

**Behavior:**

* Preserve page state
* Restore focus to opener on close
* Read-only or light editing
* Link to full record for deeper work
* Stack-aware body lock (`body.ss-drawer-open`)

**Avoid for:** replacing full workflows.

## Expanded row

**Use for:** line-level bounded edits attached to a table row (POS cart, PO lines).

## Full page

**Use for:** complex multi-section setup, full catalog metadata, workflow pages (buyback session, receiving).

## Shared partial API

Render shell with stable id; openers target by id:

```erb
<%= render "shared/interaction/drawer",
      id: "item-demand-drawer",
      title: "Customer demand",
      close_on_escape: true,
      close_on_backdrop: true do %>
  ...
<% end %>

<button type="button"
        data-action="item-customer-demand-drawer#prepareOpen drawer#open"
        data-drawer-target-id-param="item-demand-drawer"
        data-drawer-key="hold"
        ...>
  Hold for customer
</button>
```

Close policy values: `data-drawer-close-on-escape-value`, `data-drawer-close-on-backdrop-value`, `data-drawer-dirty-guard-value` (same pattern for modal).

Implicit close (Escape, backdrop) respects dirty guard and applies only to the topmost overlay in the stack. Explicit close buttons call `drawer#close` / `modal#close`, which force-close. Drawers that populate fields on open should reset the dirty baseline after programmatic setup (see item customer demand pilot); reset form state on `drawer:closed` when cancel should discard edits.

## CSS classes

```text
ss-modal, ss-modal-overlay, ss-modal-dialog, ss-modal-dialog--pos, ...
ss-drawer, ss-drawer-overlay, ss-drawer-panel, ...
ss-expand-row, ss-row-detail, ...
ss-toast-region, ss-toast, ss-toast--success, ...
```

## Mockup references

* Items setup modal: [shelfstack_items_mockups.html](../samples/phase-10-mockups/shelfstack_items_mockups.html)
* Items demand drawer: same file, operations screen
* POS settlement modal: [shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html)

## Roadmap

[phase-10a-interaction-infrastructure.md](../roadmap/phase-10a-interaction-infrastructure.md)

## Test plan

[phase-10a-test-plan.md](phase-10a-test-plan.md)
