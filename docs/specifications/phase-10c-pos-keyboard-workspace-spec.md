# Phase 10-C — POS Keyboard Workspace Specification

**Status:** Planned — **implementation source of truth**

**Roadmap:** [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md)

**Mockup reference:** [shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html)

**Depends on:** Phase 10-A (modal, drawer, expanded row, focus helpers)

---

## Scope

POS landing, compact register workspace, command field focus, `Pos::CommandRegistry`, expanded-row line edit, settlement modal, readiness placement, session drawer, reports navigation with confirm.

## Non-Goals

* POS domain rule changes (tax, discount, inventory posting)
* Offline POS; full POS rebuild
* Redesigning Phase 9 report screens
* Silent auto-create of draft sales

---

## Resolved decisions

| Topic | Decision |
| ----- | -------- |
| **No draft on landing** | Show compact POS workspace with explicit **New sale** primary action — **do not auto-create** a draft |
| **Single draft** | Auto-continue (redirect to edit) for exactly one in-progress `draft` (current cashier + workstation) |
| **Multiple drafts** | Compact draft/held-sale picker |
| **Held sales** | No auto-resume; access via list, `/hold`, or session drawer |
| **Reports from POS** | Confirm dialog when in-progress draft exists; same-tab navigate to `/reports` on confirm |
| **Function keys** | Enhancement-tier (F2–F10 where reliable); **not** blocking for 10-C completion |

Future auto-create on session open is out of scope unless explicitly approved.

---

## Landing routing (`Pos::LandingRouter`)

| Condition | Behavior |
| --------- | -------- |
| No POS permission | Locked out / permission screen |
| No register session | Open-register workflow |
| Session open, one draft (cashier + workstation) | Redirect to edit |
| Session open, multiple drafts | Compact picker |
| Session open, no drafts | Compact workspace; **New sale** focused — user creates draft explicitly |
| After open register | Compact workspace; **New sale** primary until user starts a sale |

---

## Acceptance Criteria

### Landing and workspace

* `/pos` follows landing table above; no silent draft creation
* Transaction edit screen: command field is primary focus target
* Utility/session/report access available without replacing selling surface as default landing

### Line edit and settlement

* Cart line edits use 10-A expanded-row pattern
* Settlement uses 10-A modal shell
* Readiness blockers appear near settlement and inside settlement modal with actionable controls

### Commands

* `Pos::CommandRegistry` (or approved subset) with permission checks
* `/help` and visible controls for discoverability
* `/reports` confirms before navigate when draft exists

### Keyboard/focus — required

* Command field focus on transaction edit load and after line add
* Enter/Esc behavior per [keyboard-and-focus.md](keyboard-and-focus.md)
* Modal/drawer focus trap and restore
* Expanded line edit: first field focused; focus after Save/Cancel
* Settlement reachable without function keys
* Touch targets ~44px on expanded row and settlement actions

### Keyboard/focus — enhancement (non-blocking)

* F2–F10 bindings in shortcut strip where reliable in target deployment

---

## Test Plan

### Landing router

* Session closed → open-register workflow
* Session open, no drafts → compact workspace, New sale present, **no** `PosTransaction` created without user action
* Session open, one draft → redirect to edit
* Session open, multiple drafts → picker
* Suspended sales not auto-resumed on landing
* Draft scope: cashier + workstation

### Command registry

* Ruby-side registry tests for permission and state gating
* `/reports` confirm/cancel behavior

### Keyboard/focus integration

* Required criteria above (system or integration tests where practical)

### Settlement and readiness

* Blockers visible in readiness panel and settlement modal
* Completion disabled until readiness passes

---

## Related

* [pos-keyboard-workspace.md](pos-keyboard-workspace.md)
* [phase-10a-interaction-infrastructure-spec.md](phase-10a-interaction-infrastructure-spec.md)
