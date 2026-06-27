# Phase 10-A — Interaction Infrastructure Specification

**Status:** Complete — **implementation source of truth**

**Roadmap:** [phase-10a-interaction-infrastructure.md](../roadmap/phase-10a-interaction-infrastructure.md)

**Mockup reference:** [shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html)

---

## Scope

Shared modal, drawer, toast, expanded-row, focus restoration, keyboard scoping, shortcut-strip chrome, and Turbo target conventions for ShelfStack operational UI.

## Non-Goals

* SPA or framework migration
* POS command parsing, `Pos::CommandRegistry`, or command permission rules (**10-C**)
* Item setup modal content and flows (**10-B**)
* Redesigning Phase 9 report screens
* Generic `command_controller` — POS command routing remains in `pos_command_bar_controller.js` (10-C)

## Command / shortcut ownership

| Layer | 10-A | 10-C |
| ----- | ---- | ---- |
| Modal/drawer/focus | Yes | Uses 10-A shells |
| Keyboard scope helper | Yes | POS bindings |
| Shortcut strip UI chrome | Yes | POS labels/bindings |
| Command parsing & registry | No | Yes |
| Permission-gated commands | No | Yes |

---

## Acceptance Criteria

Phase 10-A is complete when:

1. **Modal** — `ss-modal*` implemented; focus trap; first meaningful control focused; Esc when safe; validation inside modal; focus restore on close; background scroll locked.
2. **Drawer** — `ss-drawer*` implemented; page state preserved; focus restore on close; `body.ss-drawer-open` formalized.
3. **Toast** — `ss-toast-region` and variants; used only for non-blocking confirmations.
4. **Expanded row** — `ss-expand-row*` / `ss-row-detail*` pattern documented and available for adopters.
5. **Focus & keyboard** — `focus_controller` and `keyboard_scope_controller`; global rules in [keyboard-and-focus.md](keyboard-and-focus.md).
6. **Turbo** — target naming documented; pilot uses standard targets.
7. **Pilot** — item customer demand drawer migrated to shared drawer shell (see pilot checklist in roadmap).
8. **Documentation** — [ui-components.md](ui-components.md), [view-contracts.md](view-contracts.md), [modal-and-drawer-patterns.md](modal-and-drawer-patterns.md) updated.
9. **Accessibility** — visible focus rings; modal trap tested.

---

## Pilot success checklist

* One ad-hoc drawer replaced with shared drawer shell
* Open/close/focus covered by tests
* Page state preserved while drawer open
* Turbo update works while drawer open
* Pattern documented for 10-B reuse

---

## Test Plan

### Modal

* Focus trap while open
* First control receives focus on open
* Esc closes when safe; does not close when unsafe (e.g. destructive confirm)
* Validation errors render inside modal
* Focus returns to opener on close
* Successful save triggers Turbo panel update without full-page redirect

### Drawer

* Overlay and panel render; body scroll locked
* Focus returns to opener on close
* Turbo stream can replace content behind drawer without losing drawer state inappropriately

### Toast

* Appends to `ss-toast-region`
* Does not steal focus for blockers

### Expanded row

* Save/cancel local to row
* Focus after collapse predictable

### Pilot integration

* Item demand drawer: open from operations table, close with Esc, focus restore, Turbo update while open

---

## Related

* [ui-components.md](ui-components.md)
* [view-contracts.md](view-contracts.md)
* [keyboard-and-focus.md](keyboard-and-focus.md)
* [modal-and-drawer-patterns.md](modal-and-drawer-patterns.md)
