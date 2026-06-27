# Keyboard and Focus Standards

**Status:** Phase 10-A implemented

Global keyboard and focus behavior for ShelfStack operational UI.

## Global rules

| Situation | Behavior |
| --------- | -------- |
| Index/search page | Focus search when useful |
| POS transaction | Focus command/scan field |
| Form validation error | Focus first invalid field |
| Workflow line add | Return focus to add/scan field |
| Lookup selection | Focus next required field |
| Modal opens | Focus first meaningful control |
| Modal closes | Restore focus to opener |
| Drawer closes | Restore focus to opener |
| Escape | Close modal/drawer if safe; else clear scoped field |
| Enter in scan/search | Submit lookup/add |
| Enter in textarea | Insert newline |

## Modal and drawer safe close

Shared `modal_controller` / `drawer_controller` honor:

* `closeOnEscape` — default true; respects dirty guard when form is not clean
* `closeOnBackdrop` — drawer default true; modal configurable; respects dirty guard
* `dirtyGuard` — block **implicit** close (Escape, backdrop) when form is dirty, submitting, or showing validation errors
* **Explicit close** — Close button and Cancel call `drawer#close` / `modal#close` with force, bypassing dirty guard
* **Disconnect cleanup** — Turbo removal calls `cleanupOverlay`, force-releasing body lock and listeners without dirty guard
* **Overlay stack** — Escape and focus trap apply only to the topmost open overlay; nested modal-over-drawer closes the modal first

Body scroll lock is reference-counted via `overlay_lock.js` so nested modal-over-drawer does not unlock early.

## POS-specific

See [phase-10c-pos-keyboard-workspace-spec.md](phase-10c-pos-keyboard-workspace-spec.md).

### Required

* Command field focus on transaction edit
* Enter/Esc behavior as specified in 10-C roadmap
* Focus restoration after modal/drawer and line edit
* Visible shortcut/help affordances; mouse-accessible fallbacks for all primary actions

### Enhancement (non-blocking for 10-C)

Function keys F2–F4, F7–F10 where reliable. Avoid F1, F5, F6, F11, F12. Settlement and other primary actions must work without F-keys.

## Scoping

Shortcuts must be scoped to context. `keyboard_scope_controller` ignores keydown originating from focused inputs/textareas unless explicitly intended.

## Accessibility

* Visible focus indicators
* Modal/drawer focus trap (`focus_trap.js`)
* `role="dialog"`, `aria-modal="true"`, `aria-labelledby` on shells
* Screen-reader labels on close buttons
* Touch targets ~44px minimum on POS line edit and settlement (keyboard-first ≠ mouse-hostile)

## Mockup reference

[shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html) — focus section

## Implementation

Stimulus: `keyboard_scope_controller`, `focus_controller`, `modal_controller`, `drawer_controller`, `toast_controller`.

Utilities: `app/javascript/shelfstack/focus_trap.js`, `focus_restore.js`, `overlay_lock.js`.

Roadmap: [phase-10a-interaction-infrastructure.md](../roadmap/phase-10a-interaction-infrastructure.md)

Test plan: [phase-10a-test-plan.md](phase-10a-test-plan.md)
