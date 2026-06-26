# Phase 10-C — POS Keyboard Workspace Specification

**Status:** Planned

**Roadmap:** [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md)

**Mockup reference:** [shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html)

**Depends on:** Phase 10-A

---

## Scope

POS landing routing, command field focus, command registry, function keys, expanded-row line edit, settlement modal, readiness placement, session drawer, reports navigation with confirm.

## Non-Goals

* POS domain rule changes (tax, discount, inventory posting)
* Offline POS
* Full POS rebuild
* Redesigning Phase 9 report screens

## Resolved Decisions

* Reports from active draft: confirm dialog, then same-tab navigate to `/reports`
* Held (`suspended`) sales: no auto-resume on landing
* Draft auto-continue: current cashier + workstation only

## Acceptance Criteria

See [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md#acceptance-criteria).

## Test Plan

* Landing router: session open/closed, single/multiple drafts, no auto-resume suspended
* Command registry permission tests (Ruby-side registry)
* Keyboard/focus integration tests
* Settlement modal and readiness placement
* Reports confirm-before-navigate

## Related

* [pos-keyboard-workspace.md](pos-keyboard-workspace.md)
* [phase-10a-interaction-infrastructure-spec.md](phase-10a-interaction-infrastructure-spec.md)
