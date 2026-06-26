# Keyboard and Focus Standards

**Status:** Planned (Phase 10-A)

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

## POS-specific

See [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md) and [pos-keyboard-workspace.md](pos-keyboard-workspace.md).

Function keys F2–F4, F7–F10 in POS; avoid F1, F5, F6, F11, F12 (browser/OS conflicts).

## Scoping

Shortcuts must be scoped to context. Disable in inappropriate form fields unless explicitly intended.

## Accessibility

* Visible focus indicators
* Modal focus trap
* Screen-reader labels on modal/drawer chrome
* Touch targets ~44px minimum on POS line edit and settlement (keyboard-first ≠ mouse-hostile)

## Mockup reference

[shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html) — focus section

## Implementation

Stimulus: `keyboard_scope_controller`, `focus_controller`, `modal_controller`, `drawer_controller`.

Roadmap: [phase-10a-interaction-infrastructure.md](../roadmap/phase-10a-interaction-infrastructure.md)
