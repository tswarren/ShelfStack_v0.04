# Phase 10-C — POS Keyboard-First Transaction Workspace

**Status:** Planned

**Parent:** [Phase-x10-comprehensive-ux-expansion.md](Phase-x10-comprehensive-ux-expansion.md)

**Depends on:** [phase-10a-interaction-infrastructure.md](phase-10a-interaction-infrastructure.md)

**Spec:** [phase-10c-pos-keyboard-workspace-spec.md](../specifications/phase-10c-pos-keyboard-workspace-spec.md)

**Prerequisite code:** Phase 6 POS foundation, Phase 7B settlement/stored value, Phase 8.5-1/2 discounts and tax

**Visual reference:** [shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html). POS view contract in [shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html).

---

## Purpose

Make POS feel like a fast, focused register workspace rather than a dashboard or collection of Rails forms. This is a **UX refinement of the existing POS foundation**, not a full rebuild.

Priorities:

* Scan-first transaction entry
* Keyboard navigation wherever practical
* Fast line modification
* Clear settlement and readiness feedback
* Minimal page changes during active cashier work
* Modals and drawers for bounded tasks
* Commands and function keys for common actions
* Transaction screen as primary POS landing when a register session is open

---

## Guiding Model

```text
Command field is home base.
Cart is the working surface.
Line edits happen inline.
Related detail opens in drawers.
Bounded decisions happen in modals.
Readiness appears where completion happens.
Function keys and commands make common actions fast.
```

---

## Existing Foundation

| Area | Current artifact |
| ---- | ---------------- |
| POS home | `Pos::HomeController`, `app/views/pos/home/_open_dashboard.html.erb`, `_action_buttons.html.erb` |
| Command bar | `pos_command_bar_controller.js`, `app/views/pos/transactions/_command_bar.html.erb` |
| Transaction workspace | `pos_transaction_edit_controller.js`, cart/line/settlement/supervisor controllers |
| Draft vs held | `PosTransaction` scopes `drafts` / `suspended`; home lists both separately |
| Reports | Canonical `/reports` hub (Phase 9b); legacy `/pos/reports/*` redirects |

---

## POS Landing Behavior

### Current Issue

When a register session is open, `/pos` acts as an action launcher (Continue/New Transaction, Manage Session, Cash In/Out, Reports, Check Balance). Cashiers usually need to scan or enter an item next — the menu step adds friction.

### Proposed Routing

Implement via `Pos::LandingRouter` (or equivalent in `Pos::HomeController#show`):

| Condition | Behavior |
| --------- | -------- |
| No POS permission | Permission-aware screen / locked out |
| No register session open | Focused open-register workflow |
| Session open, one draft (current cashier + workstation) | Redirect to that draft transaction |
| Session open, multiple drafts | Compact draft picker (not full dashboard) |
| Session open, no drafts | Create new sale transaction → redirect to edit |
| Suspended (held) sales | **Do not auto-resume** — access via held-sale list, `/hold`, or session drawer |

Draft ownership matches today: drafts scoped to **current cashier + workstation**; suspended sales are **workstation-scoped**.

Held sales are distinct from accidental drafts.

### Closed Session

When no register session is open:

```text
Register closed

Primary: Open Register
Secondary: Session history, Reports, Stored value balance lookup (if allowed)
```

After opening register, route to new transaction with command field focused.

---

## Transaction Workspace Layout

```text
Top context bar
  Store, register/workstation, cashier, session status, utility menu

Command field
  Scan/search/command — main keyboard focus target

Mode controls
  Sale, Return, Pickup, Open ring

Cart/work area
  Lines, quantity controls, More/Edit, inline modification rows

Sidebar
  Totals, discounts/tax adjustments, readiness, settlement action

Modal layer
  Customer lookup, gift card activation, balance inquiry, supervisor auth,
  tax exemption, settlement, cash drawer actions

Shortcut strip
  F-key actions, command help
```

See mockup screens: Register workspace, Item modification expanded row, Settlement modal.

---

## Command Field

Existing command bar supports SKU, ISBN, barcode, receipt number, `/giftcard`, `/balance`, amount-like input. Formalize as POS command interface.

### Focus Rules

| Situation | Behavior |
| --------- | -------- |
| Transaction page loads | Focus command field |
| Item added | Return focus to command field |
| Lookup selected | Add/select, then return focus |
| Modal/drawer closes | Restore focus to opener or command field |
| Invalid command | Keep focus; show inline guidance |
| Transaction completes | New transaction; command field focused |
| Esc, no modal/drawer | Clear command field |
| Enter in command field | Route command / add item / lookup |

---

## Command Registry

Centralize commands (recommend Ruby-side `Pos::CommandRegistry` consumed by JS for testability):

```text
Pos::CommandRegistry.define(:customer, permission: "...", states: [...], target: :modal)
```

Each command defines: name, aliases, description, permission, valid session/transaction states, target behavior (route/modal/drawer/panel/mutation), focus after completion, unavailable message.

### Initial Command Set

| Command | Action |
| ------- | ------ |
| `/customer` | Customer lookup modal |
| `/openring` or `/open` | Open-ring entry |
| `/discount` | Transaction discount panel/modal |
| `/taxexempt` | Tax exemption modal |
| `/giftcard` | Gift card sale line/modal |
| `/balance` | Stored value balance inquiry |
| `/return` | Return mode or receipt lookup |
| `/pickup` | Pickup/customer request context |
| `/cash 20` | Settlement + cash tender prefill |
| `/card` | Settlement + card tender |
| `/check` | Check tender |
| `/storecredit` | Store credit tender |
| `/hold` | Hold current transaction |
| `/session` | Session summary drawer |
| `/cashdrop`, `/drop` | Cash drop modal |
| `/cashin`, `/cashout` | Cash movement modals |
| `/close` | Close register workflow |
| `/reports` | Navigate to `/reports` (see below) |
| `/drawer` | Cash drawer action |
| `/help` | Command and shortcut help |

### Reports from POS

When an in-progress draft exists, `/reports` and utility-menu report links show a **confirm dialog**. On confirm, navigate same tab to `/reports`. On cancel, restore focus to command field. Draft transaction remains on server.

---

## Function Keys

Initial set (avoid F1, F5, F6, F11, F12 — browser/OS reserved):

| Key | Action |
| --- | ------ |
| F2 | Customer lookup |
| F3 | Open ring |
| F4 | Discount (transaction if no line selected; line if line selected) |
| F7 | Cash drawer / cash movement |
| F8 | Settlement |
| F9 | Print last receipt |
| F10 | Lock register |

Shortcuts scoped to POS context. Esc: close modal/drawer first, then clear command field.

Visible shortcut strip and `/help` required for discoverability.

---

## Modals

Bounded tasks only: settlement, customer lookup, supervisor authorization, gift card activation, balance inquiry, tax exemption, cash drawer actions, confirm void/remove.

Each modal: focus trap, first meaningful control focused, Esc when safe, validation inside modal, Turbo panel updates, focus restore on close.

---

## Drawers

Inspection and light context: item detail, customer detail, session summary, transaction history, return source detail, stored value account detail. Not full workflows.

---

## Cart and Line Editing

Use inline expanded rows (10-A pattern). Current cart supports qty, price, return disposition, line discount, tax override — refine styling and focus.

| Task | Pattern |
| ---- | ------- |
| Qty change | Inline controls on row |
| Price, discount, tax override, return disposition | Expanded row |
| Remove line | Separated destructive action |
| Deeper history | Drawer |

After Save/Cancel: collapse row; return focus to command field or More button.

---

## Settlement

Remain a modal. F8 opens settlement. Show remaining balance, change due, tender rows, add-tender actions, readiness blockers, complete action.

Rules: `/cash 20` and `/card` open settlement with tender prefilled; fill-remaining on non-cash rows; completion disabled until readiness passes; after completion, new transaction with command field focused.

---

## Readiness Placement

| Readiness type | Placement |
| -------------- | --------- |
| Completion blocker | Near settlement action and inside settlement modal |
| Register session issue | Header/session area and readiness panel |
| Gift card activation needed | Cart line and readiness panel with action |
| Supervisor approval | Readiness panel with Request Auth |
| Tender insufficient | Settlement modal |
| Inactive item warning | Readiness panel with confirm |

Do not use global flash for routine POS blockers.

---

## Session and Utility Access

Secondary tasks (session management, cash movements, reports) via utility menu, commands, session drawer — not primary landing path.

---

## Implementation Phases (PR slices)

| Phase | Deliverable | 10-A dependency |
| ----- | ----------- | --------------- |
| 1 Landing and focus | `/pos` routing, command autofocus, refocus after line add | Minimal |
| 2 Function keys | POS keyboard controller, F2–F10, shortcut strip | Keyboard scope |
| 3 Command registry | Aliases, permissions, `/help`, core commands | — |
| 4 Modal standardization | Settlement, customer, auth, tax, cash drawer on shared shell | **Required** |
| 5 Cart line UX | Expanded row polish, Save/Cancel focus | **Required** |
| 6 Session drawer | Session summary, reports link with confirm | **Required** |

---

## Keyboard/Focus Acceptance Criteria

* Transaction load focuses command field
* Line add returns focus to command field
* Enter routes command; Esc closes modal/drawer before clearing command
* Modals trap and restore focus
* Expanded line edit focuses first editable field
* Settlement focuses likely tender field
* Complete sale opens next transaction focused
* Function keys documented visually
* Shortcuts disabled in inappropriate form fields
* Visible focus indicators
* Touch targets ~44px minimum on expanded row and settlement actions

---

## Acceptance Criteria

Phase 10-C is complete when:

* `/pos` routes to transaction workspace when session is open (per landing rules above)
* Command field is primary focus target
* Line edits use polished expanded-row pattern
* Settlement uses standardized modal system
* Readiness blockers appear where user can act
* Documented keyboard/focus behavior passes acceptance list
* Command registry (or approved subset) implemented with permission checks
* `/reports` confirms before navigate when draft exists
* POS item-detail drawer reuses 10-A drawer shell where applicable

---

## Related Documents

```text
docs/specifications/phase-10c-pos-keyboard-workspace-spec.md
docs/specifications/pos-keyboard-workspace.md
docs/roadmap/phase-10a-interaction-infrastructure.md
docs/roadmap/phase-10b-item-cockpit-completion.md
docs/samples/phase-10-mockups/shelfstack_pos_mockups.html
```
