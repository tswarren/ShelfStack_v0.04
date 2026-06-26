# Phase 10-A — Interaction Infrastructure

**Status:** Planned

**Parent:** [Phase-x10-comprehensive-ux-expansion.md](Phase-x10-comprehensive-ux-expansion.md)

**Spec:** [phase-10a-interaction-infrastructure-spec.md](../specifications/phase-10a-interaction-infrastructure-spec.md)

**Visual reference:** [shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html) — principles, view contracts, message/focus sections, screen checklist. Drawer, modal, expanded row, and shortcut strip patterns also appear in [shelfstack_items_mockups.html](../samples/phase-10-mockups/shelfstack_items_mockups.html) and [shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html).

---

## Purpose

Extend the Phase 9a UI foundation into a shared application interaction system. Phase 10-B (items), 10-C (POS), and 10-D (workflows) depend on these components.

Implementation maps patterns to existing `ss-*` classes in `app/assets/stylesheets/shelfstack.css`. Mockup HTML is inspiration only — do not copy mockup CSS verbatim.

---

## Scope

Standardize and implement:

```text
Modal system
Drawer system
Toast system
Expanded row pattern
Inline edit pattern
Lookup/search component
Shortcut strip (generic legend/help chrome only)
Focus restoration helper
Keyboard event scoping
Turbo Frame/Stream target conventions
```

**10-A does not implement:** POS command parsing, `Pos::CommandRegistry`, command permission rules, or workspace-specific command routing. Those belong to **10-C**. The scope item “command field pattern” means reusable scan/input field styling and focus behavior for bounded contexts (e.g. item lookup), not a POS command language.

---

## Required Components

### Modal

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

Good uses: add identifier, edit price, customer lookup, supervisor authorization, gift card activation, stored value balance inquiry, tax exemption, cash drawer action, confirm void/remove/delete.

Avoid: full receiving, full PO creation, full buyback intake, full catalog editing, complex multi-section setup.

### Drawer

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

Good uses: item/variant detail, customer detail, session summary, transaction history, receipt/source detail, PO line detail, inventory movements, stored value account detail, customer demand detail.

### Toast

Classes/patterns:

```text
ss-toast-region
ss-toast
ss-toast--success
ss-toast--info
ss-toast--warning
ss-toast--error
```

Use for minor, non-blocking confirmations. Do not use for blockers, field validation, or transaction safety warnings.

### Expanded Row

Classes/patterns:

```text
ss-expand-row
ss-expand-row--active
ss-row-detail
ss-row-detail__header
ss-row-detail__body
ss-row-detail__footer
```

Uses: POS line editing, receipt line detail, PO line detail, inventory adjustment line detail, customer request line detail, buyback line detail.

Behavior: detail attached to parent row; local save/cancel; destructive actions separated; predictable focus after collapse.

---

## Stimulus Controllers

Implement shared helpers:

```text
focus_controller
modal_controller
drawer_controller
keyboard_scope_controller
lookup_controller
line_entry_controller
toast_controller
```

Do **not** add a generic `command_controller` in 10-A. POS command routing stays in existing `pos_command_bar_controller.js` and future `Pos::CommandRegistry` (10-C).

Shortcuts must be scoped. Keyboard speed must not reduce transaction safety.

---

## Global Keyboard and Focus Rules

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

See [keyboard-and-focus.md](../specifications/keyboard-and-focus.md) and [modal-and-drawer-patterns.md](../specifications/modal-and-drawer-patterns.md).

---

## Turbo Target Conventions

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

Standard update patterns:

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
* Stimulus must not own tax, pricing, inventory, or permission logic.
* Turbo validation errors stay in the frame/modal/workflow where the user is working.

---

## Migration Inventory

| Existing pattern | File | 10-A action |
| ---------------- | ---- | ----------- |
| Ad-hoc drawer | `app/javascript/controllers/item_customer_demand_drawer_controller.js` | **Pilot migration** to shared drawer shell |
| Ad-hoc drawer | `app/javascript/controllers/buyback_line_drawer_controller.js` | Migrate when buyback touched in 10-D |
| POS panels | `pos_command_bar_controller.js`, settlement/supervisor controllers | Keep; wrap in shared modal/focus helpers in 10-C |
| Body class | `body.ss-drawer-open` in `shelfstack.css` | Formalize in `ss-drawer` component |

---

## Implementation Checklist

```text
1. Modal shell and controller
2. Drawer shell and controller
3. Toast region and component
4. Focus restoration helper
5. Keyboard scope helper
6. Expanded row pattern
7. Turbo target conventions
8. Pilot: item customer demand drawer → shared drawer
```

### Pilot success checklist

The item customer demand drawer pilot is successful when:

* One existing ad-hoc drawer is replaced with the shared drawer shell
* Open/close/focus behavior is covered by tests
* Page state is preserved while the drawer is open
* Turbo update works while the drawer is open
* The pattern is documented in [ui-components.md](../specifications/ui-components.md) for 10-B reuse

---

## Acceptance Criteria

Implementation-ready criteria are in [phase-10a-interaction-infrastructure-spec.md](../specifications/phase-10a-interaction-infrastructure-spec.md). Summary:

* Shared modal, drawer, toast, and expanded-row components are documented in [ui-components.md](../specifications/ui-components.md).
* Modal focus trap and focus restoration on close are implemented and tested.
* Drawer preserves page state and restores focus to opener.
* Turbo target naming conventions are documented and used in pilot migration.
* Item customer demand drawer uses shared drawer shell (pilot).
* View contracts summarized in [view-contracts.md](../specifications/view-contracts.md).
* Accessibility: focus trap, visible focus rings, Esc behavior documented.

---

## Test Plan

See [phase-10a-interaction-infrastructure-spec.md](../specifications/phase-10a-interaction-infrastructure-spec.md#test-plan).

---

## Related Documents

```text
docs/specifications/phase-10a-interaction-infrastructure-spec.md
docs/specifications/ui-components.md
docs/specifications/view-contracts.md
docs/specifications/keyboard-and-focus.md
docs/specifications/modal-and-drawer-patterns.md
docs/samples/phase-10-mockups/README.md
docs/implementation/phase-10a-completion.md  (created at completion)
```
