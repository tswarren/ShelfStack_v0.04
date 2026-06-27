# Phase 10-C — POS Keyboard Workspace Specification

**Status:** Planned — **implementation source of truth**

**Roadmap:** [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md)

**Mockup reference:** [shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html)

**Depends on:** Phase 10-A (modal, drawer, expanded row, focus helpers), Phase 10-B (interaction patterns)

---

## Scope

Shared POS workspace shell (idle + active), landing router, active draft resolver, two-lane command parser, `Pos::CommandRegistry`, drawer-based return/pickup, settlement modal entry via commands, cash in/out modals, expanded-row line edit, readiness placement, session drawer, reports navigation with confirm.

## Non-Goals

* POS domain rule changes (tax, discount eligibility, inventory posting, settlement math)
* Offline POS; full POS rebuild
* Redesigning Phase 9 report screens
* Silent auto-create of draft sales
* Function-key bindings as a completion requirement
* **`/cashdrop` execution** in initial 10-C (registered as planned/disabled)
* Hold name/label fields
* Auto-cancel of empty drafts

---

## Resolved Decisions

| Topic | Decision |
| ----- | -------- |
| **Landing** | Idle POS workspace when register open and no active draft; command field is home base |
| **Active draft scope** | One active draft per **register session + workstation + cashier** |
| **Active draft wins** | `/pos` always returns to active draft (including empty) until complete/cancel/void/hold |
| **Cross-cashier conflict** | Different cashier on same workstation → conflict/resume/manager UI; no silent takeover |
| **Parser** | Slash → command registry; non-slash → scan/catalog lookup only |
| **Implicit intents** | Removed: bare amounts, receipt patterns, unmatched text → open ring/return |
| **Failed lookup** | Never creates a draft, even when input looks like amount/receipt/description |
| **Transactionless commands** | Available while active draft exists; blocked only by modal/dirty state |
| **Line vs transaction discount** | `/linediscount` (`/ld`, legacy `/d`) vs `/discount` (`/di`, legacy `/dt`) — separate commands |
| **Gift card sale vs redeem** | `/giftcard` (`/gc`) vs `/giftredeem` (`/gr`); `/gc` modal-first, no auto-post with amount |
| **Return / pickup** | Drawer workflows; draft on line commit/fulfillment |
| **Return on active draft** | Allowed for empty/sale drafts (exchange); blocked when tender rows exist |
| **`/close`** | Blocked while active draft exists |
| **`/cashdrop`** | Planned/disabled until `cash_drop` movement type exists; `/cashin` and `/cashout` ship |
| **Held sales** | No auto-resume; explicit resume only |
| **Reports from POS** | Confirm when active draft exists; same-tab navigate on confirm |
| **Function keys** | Out of scope for 10-C completion |

Future auto-create on session open is out of scope unless explicitly approved.

---

## Architecture

Phase 10-C introduces a **shared POS workspace shell** with one command field and registry for idle and active states. Root-level command endpoint required (today `route_command` is transaction-scoped only).

Evolve `Pos::CommandBarRouter` → `Pos::CommandRegistry` (Ruby-side, permission/state gated, consumed by JS).

**PR 1:** workspace shell + landing router + active draft resolver + intent boundary + carry-forward.

---

## Landing Routing (`Pos::LandingRouter`)

| Condition | Behavior |
| --------- | -------- |
| No POS permission | Locked out / permission screen |
| No register session | Open-register workflow |
| Register open, no active draft | Idle workspace; command field focused |
| Register open, one active draft (session + workstation + cashier) | Return to active draft |
| Register open, multiple draft candidates | Conflict picker; do not create another |
| Held/suspended exist | Show access; never auto-resume |

After open register → idle workspace until transaction-starting action.

---

## Active Draft Resolver

```text
active draft =
  most recent PosTransaction with status = draft
  for current register session + workstation + cashier
```

Service layer **prevents** creating a second active draft for the same scope.

Empty drafts remain active until cancel, hold, complete, or void.

---

## Two-Lane Parser

| Lane | Input | Behavior |
| ---- | ----- | -------- |
| Command | Slash-prefixed token | Command registry |
| Lookup | Non-slash | `LineLookup` / scan-add only |

Failed lookup message:

```text
No matching item. Use /op for open ring, /return for receipt lookup, or /help.
```

---

## Return Drawer — Active Draft States

| Active draft state | `/return` behavior |
| ------------------ | ------------------ |
| Empty draft | Return lines may be added |
| Sale lines only | Return lines may be added; exchange via `Pos::DeriveTransactionType` |
| Tender rows / settlement started | Block until tenders cleared |
| Completed / voided / cancelled | Not active |
| Suspended / held | Resume explicitly first |

Prompt when blocked: complete, cancel, hold, or clear settlement before adding return lines.

---

## Close Register (`/close`, `/cl`)

| State | Behavior |
| ----- | -------- |
| No active draft | Open close-register workflow |
| Active draft | Block with message |
| Held transactions | Warn / show held list per store policy |

```text
Cannot close register while a transaction is active. Complete, cancel, or hold the current transaction first.
```

---

## Cash Drop (Deferred)

`/cashdrop`, `/drop`, `/dp` appear in registry and help as **planned/disabled**.

```text
Cash drop is not available yet.
```

`PosCashMovement` supports `paid_in` and `paid_out` only. Future work: `cash_drop` movement type + modal.

---

## Acceptance Criteria

### Landing and workspace

* `/pos` follows landing table; no silent draft creation
* Active draft always wins on landing (including empty)
* Command field is primary focus in idle and active states
* Cross-cashier conflict handled without silent takeover

### Parser and drafts

* Failed lookup never creates draft (amount, receipt pattern, unmatched text)
* Scan/add creates/resumes draft with carry-forward from idle
* Tender commands from idle show no-active-transaction message; no empty draft
* One active draft enforced at creation time

### Commands

* `Pos::CommandRegistry` with permission and state checks
* `/help` and mouse equivalents for discoverability
* `/reports` confirms before navigate when active draft exists
* Transactionless commands work with active draft (blocked only by modal/dirty state)
* `/gc` opens modal; does not auto-post line when amount provided
* `/cashdrop` shows planned/disabled message

### Discount split

* `/d`, `/ld` → line discount workflow
* `/dt`, `/di`, `/discount` → transaction discount workflow
* `/d` does not open transaction discount

### Return and close

* Return drawer; exchange on sale-only active draft
* Return blocked when tender rows present
* `/close` blocked with active draft

### Line edit and settlement

* Cart line edits use 10-A expanded-row pattern
* Settlement uses 10-A modal shell
* Readiness blockers near settlement and inside modal

### Keyboard/focus — required

* Per [keyboard-and-focus.md](keyboard-and-focus.md) and roadmap
* Settlement reachable without function keys
* Touch targets ~44px on expanded row and settlement actions

### Not required

* Function-key bindings or F-key legend
* Discount amount arguments on command line (enhancement)

---

## Documentation Layering

| Document | Role |
| -------- | ---- |
| [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md) | Command → surface mapping, draft gating, PR slices, policy tables |
| This spec | Resolved decisions, acceptance criteria |
| [phase-10c-test-plan.md](phase-10c-test-plan.md) | Test cases by area |
| [phase-10a-interaction-infrastructure-spec.md](phase-10a-interaction-infrastructure-spec.md), [modal-and-drawer-patterns.md](modal-and-drawer-patterns.md) | Shell mechanics only |
| Phase 6 / 7B / 8.5 specs | Domain rules — reference, do not duplicate |

Field-level drawer layouts and exact modal field order are deferred to implementation slices unless this spec calls them out explicitly.

---

## Test Plan

See [phase-10c-test-plan.md](phase-10c-test-plan.md) for the full checklist. Summary:

### Landing router

* Session closed → open-register workflow
* Session open, no active draft → idle; no `PosTransaction` without user action
* Session open, one active draft → return to draft
* Session open, multiple drafts → picker
* Empty draft → `/pos` returns to draft
* Suspended not auto-resumed on landing
* Draft scope: register session + workstation + cashier
* Cross-cashier conflict → conflict UI

### Two-lane parser

* `20`, receipt-shaped string, unmatched text → no draft; helpful message
* SKU/ISBN scan → lookup/add; draft when line added

### Command registry — discount aliases

* `/d` opens line discount workflow
* `/ld` opens line discount workflow
* `/dt` opens transaction discount workflow
* `/di` opens transaction discount workflow
* `/discount` opens transaction discount workflow
* `/d` does **not** open transaction discount

### Return and close

* Active sale draft + `/return` → exchange path allowed
* Active draft with tender rows + `/return` → blocked
* Active draft + `/close` → blocked with message

### Transactionless with active draft

* `/balance` with empty active draft → modal; draft unchanged

### Cashdrop

* `/cashdrop` → planned/disabled message; no `PosCashMovement` created

### Gift card

* `/gc 50` from idle → draft + modal with $50 prefilled; line not auto-posted

### Tender from idle

* `/cash 20` from idle → no draft; no-active-transaction message

### Settlement and readiness

* Blockers visible; completion disabled until ready

### Keyboard/focus integration

* Required criteria (system/integration tests where practical)

---

## Related

* [phase-10c-test-plan.md](phase-10c-test-plan.md)
* [pos-keyboard-workspace.md](pos-keyboard-workspace.md)
* [keyboard-and-focus.md](keyboard-and-focus.md)
* [view-contracts.md](view-contracts.md)
* [phase-10a-interaction-infrastructure-spec.md](phase-10a-interaction-infrastructure-spec.md)
