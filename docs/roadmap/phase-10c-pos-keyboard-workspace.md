# Phase 10-C — POS Keyboard-First Transaction Workspace

**Status:** In progress — see [phase-10c-completion.md](../implementation/phase-10c-completion.md) (slices 1–7 delivered; 8–10 pending)

**Parent:** [Phase-x10-comprehensive-ux-expansion.md](Phase-x10-comprehensive-ux-expansion.md)

**Depends on:** [phase-10a-interaction-infrastructure.md](phase-10a-interaction-infrastructure.md) (**hard** — modal, drawer, expanded row, focus); [phase-10b-item-cockpit-completion.md](phase-10b-item-cockpit-completion.md) **complete per delivery order** (proves shared interaction patterns on Items before POS-heavy modal/drawer work)

**Spec:** [phase-10c-pos-keyboard-workspace-spec.md](../specifications/phase-10c-pos-keyboard-workspace-spec.md) — aligned with this roadmap

**Prerequisite code:** Phase 6 POS foundation, Phase 7B settlement/stored value, Phase 8.5-1/2 discounts and tax

**Visual reference:** [shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html). POS view contract in [shelfstack_ux_direction_visual.html](../samples/phase-10-mockups/shelfstack_ux_direction_visual.html).

---

## Purpose

Make POS feel like a fast, focused register workspace rather than a dashboard, action launcher, or collection of Rails forms.

Phase 10-C changes the POS entry point from a “new transaction page” into a **keyboard-first POS workspace**. The workspace should be useful even before a transaction exists: a cashier should be able to scan an item, start an open-ring sale, check a gift card balance, look up a customer, review the session, perform a cash movement, or open reports from the same command field.

This is a **UX refinement of the existing POS foundation**, not a full rebuild. POS domain rules (tax, discount eligibility, inventory posting, settlement math, stored value ledger behavior) do not change in 10-C.

Priorities:

* Idle POS workspace when a register session is open and no active draft exists
* Command field as the conceptual center of the workspace
* Scan-first transaction entry for sellable items
* Explicit slash commands for workflows (no implicit intent guessing)
* Reliable browser-safe command aliases — **not** function-key dependency
* One active draft per register session + workstation + cashier once a transaction begins
* Keyboard navigation, focus restoration, and 10-A modal/drawer patterns throughout
* Fast line modification via expanded rows
* Clear settlement and readiness feedback
* Minimal page changes during active cashier work

---

## Final Phase 10-C Rules

```text
1. Idle landing exists only when no active draft exists (scoped to register session + workstation + cashier).
2. An existing active draft always wins on /pos landing.
3. Slash commands route workflows through the command registry.
4. Non-slash input performs scan/catalog lookup only.
5. Failed lookup never creates a draft.
6. Line discount and transaction discount are separate commands.
7. Gift card sale/reload and gift card redemption are separate commands.
8. Cash tender and cash register movements are separate commands.
9. Pickup and return open drawers with mouse-accessible equivalents.
10. Function keys are out of scope for 10-C completion.
```

---

## Guiding Model

```text
Command field is home base.
Idle workspace does not create a draft.
Transaction-starting input creates or resumes the active draft.
Transactionless commands do not create drafts and work while a draft is active.
Cart is the working surface once a transaction exists.
Line edits happen inline.
Related detail opens in drawers.
Bounded decisions happen in modals.
Readiness appears where completion happens.
Commands and aliases make common actions fast.
```

Function keys are **not** part of the Phase 10-C completion target. Browser and operating system behavior make most function keys unreliable across Chrome, Safari, and Firefox. Phase 10-C uses command aliases and visible controls as the primary keyboard acceleration mechanism.

---

## Architecture: Shared POS Workspace Shell

Phase 10-C is **not** just `Pos::LandingRouter` redirect logic. It introduces a shared POS workspace shell used for both idle and active-transaction states.

```text
POS workspace shell
├── context bar (store, register/workstation, cashier, session status, utility menu)
├── command field (always present; primary keyboard focus target)
├── command feedback area (inline errors, suggestions, no-active-transaction messages)
├── idle content OR transaction cart / sidebar
├── settlement/readiness sidebar when transaction active
└── modal / drawer regions (10-A shells)
```

**Idle workspace** and **transaction-active workspace** share the same command field and command registry. The difference is whether an active draft transaction is currently bound to the workstation/cashier/register session.

Implementation notes:

* Today the command bar lives only on transaction edit (`route_command_pos_transaction_path(transaction)`). 10-C needs a **root-level command endpoint** on the workspace shell that can run transactionless commands and create/resume drafts with carry-forward.
* Evolve `Pos::CommandBarRouter` into `Pos::CommandRegistry` (Ruby-side registry consumed by JS for testability), with permission checks, valid states, and normalized aliases.
* **PR 1** should deliver the workspace shell + active draft resolver + intent boundary + carry-forward together. An idle shell without the intent boundary is too incomplete to QA.

---

## Existing Foundation

| Area | Current artifact | 10-C change |
| ---- | ---------------- | ----------- |
| POS home | `Pos::HomeController`, `_open_dashboard.html.erb`, `_action_buttons.html.erb` | Becomes idle workspace shell; stop auto-creating drafts on landing |
| Command routing | `Pos::CommandBarRouter`, `pos_command_bar_controller.js` | Two-lane parser; explicit commands; registry |
| Command bar UI | `_command_bar.html.erb` | Shared shell; remove implicit-intent placeholder copy |
| Transaction workspace | `pos_transaction_edit_controller.js`, cart/settlement controllers | Embedded in shared shell when draft active |
| Draft vs held | `PosTransaction` scopes `drafts` / `suspended` | One active draft enforcement; hold clears active slot |
| Cash movements | `Pos::CashMovementsController`, `paid_in` / `paid_out` on register session | Modal workflows from workspace; see cash movement notes |
| Settlement/stored value | Phase 7B | Unchanged domain; command entry to settlement modal |
| Discounts/tax | Phase 8.5 | Unchanged domain; separate line vs transaction discount commands |
| Pickup | `pos-pickup-panel`, `?mode=pickup` | Drawer-based pickup workflow |
| Return | Receipt pattern in router, inline receipt panel | Drawer-based return workflow |
| Reports | Canonical `/reports` hub | Confirm before navigate when active draft exists |

---

## Command Parser: Two-Lane Model

Phase 10-C replaces implicit workflow guessing in `Pos::CommandBarRouter` with an explicit two-lane parser.

```text
Slash-prefixed input  → command registry
Non-slash input       → scan/catalog/product lookup only
Failed lookup         → no draft; show helpful suggestion
```

### Keep (implicit scan/add)

| Input | Behavior |
| ----- | -------- |
| ISBN / SKU / barcode that resolves to a sellable variant | Create/resume active draft and add line (or show lookup choices, then add) |

### Remove (assumed intents)

| Input | Current behavior | New behavior |
| ----- | ---------------- | ------------ |
| Bare amount (`20`, `$20.00`) | Open-ring offer | Failed lookup; suggest `/op 20` |
| Receipt-number pattern | Return receipt lookup | Failed lookup; suggest `/return <receipt>` |
| Unmatched text | Open-ring offer | Failed lookup; suggest `/op`, `/return`, or `/help` |

Recommended failed-lookup message:

```text
No matching item. Use /op for open ring, /return for receipt lookup, or /help.
```

**Failed lookup must not create a draft** even when input looks like an amount, receipt number, or open-ring description. This makes removal of legacy heuristics unmistakable.

### Parsing rules

* Commands are matched case-insensitively.
* Aliases normalize to a canonical command before permission checks, routing, audit, and help display.
* Aliases and legacy aliases must be **unique across the full registry** and must not collide with another canonical command or alias.
* Slash-prefixed tokens are required for commands, except `?` may open help without a slash.
* Unrecognized slash commands show a helpful error and suggest `/help`.
* Commands never bypass permissions, approvals, confirmations, or register-state rules.
* Amount arguments accept `20`, `20.00`, `$20`, `$20.00` where documented below.

---

## POS Landing and Active Draft Policy

### Current issue

Today, `POST /pos/transactions` creates a draft immediately and `/pos` home acts as an action launcher (`New Transaction`, `Continue`, etc.). That creates unnecessary drafts for transactionless work (`/balance`, `/reports`, session utilities).

### Target landing behavior

When a register session is open, `/pos` uses `Pos::LandingRouter` (or equivalent in `Pos::HomeController#show`):

| Condition | Behavior |
| --------- | -------- |
| No POS permission | Permission-aware screen / locked out |
| No register session open | Focused open-register workflow |
| Register open, **no active draft** | **Idle POS workspace** — command field focused; no draft created |
| Register open, **one active draft** (cashier + workstation + session) | Return to active draft workspace |
| Register open, **multiple draft candidates** | Draft conflict picker; do not create another draft |
| Held/suspended transactions exist | Show held-sale access; **never auto-resume** |

After opening a register, land on the idle workspace. No draft is created until a transaction-starting action.

**New sale** remains a visible mouse-accessible control (explicit draft creation) but is **not** the conceptual center of the landing page. The command field is home base.

### Active draft definition

**Active draft** = the one draft POS transaction currently assigned to the active transaction slot for **register session + workstation + cashier**.

Operational rule for Phase 10-C:

```text
One active draft per register session + workstation + cashier.
```

Initial resolver (no new DB column required for MVP):

```text
most recent draft for register session + workstation + cashier
where status = draft (not suspended, completed, voided, or cancelled)
```

Longer term, an explicit binding (`pos_workstations.active_pos_transaction_id` or session state object) may be cleaner.

**Cross-cashier conflict:** If a different cashier signs into the same workstation while another cashier’s draft is still active for that session/workstation, the system must show a conflict/resume/manager action. It must not silently create a new draft or take over the other cashier’s draft.

### Stricter draft rules

| Rule | Behavior |
| ---- | -------- |
| At most one active draft | Service layer prevents a second active draft for the same register session + workstation + cashier |
| Resume, don’t duplicate | Transaction-starting input resumes the active draft |
| Hold/suspend | Clears the active slot; workspace may return to idle |
| Complete / void / cancel | Clears the active slot |
| Empty draft | Still an active draft; `/pos` returns to it until cashier cancels, holds, completes, or voids |
| Multiple legacy drafts | Picker resolves conflict; steady state should not create new multiples |

**No auto-cancel for empty drafts in 10-C.** Auto-cancel introduces audit and cashier-surprise risk. Cashiers who want idle landing after accidentally starting an empty sale must cancel or hold explicitly.

### Transactionless commands while a draft is active

Transactionless commands **do not require idle workspace**. They must not create a second draft or replace the active draft.

Examples while an active draft (including empty) exists:

```text
/balance   → open balance inquiry modal; draft stays active
/session   → open session drawer; draft stays active
/help      → open help; draft stays active
/reports   → confirm before navigate; draft remains on server if cancelled
```

Only **landing routing** and **transaction-starting** behavior depend on whether an active draft exists. Utility commands remain available in both states.

Transactionless commands may be **temporarily blocked only by modal/dirty-form state** (10-A dirty guard), not by the mere existence of an active draft.

---

## Transaction Intent Boundary

A draft is created or resumed only when input crosses the **transaction intent boundary**.

| Input / action | Creates/resumes draft? | Behavior |
| -------------- | ---------------------- | -------- |
| Scan / lookup → add sellable variant | Yes | Create/resume draft; add line |
| `/openring`, `/op`, `/open` (+ optional amount) | Yes | Create/resume draft; open-ring workflow with amount prefilled when provided |
| `/giftcard`, `/gc` (+ optional amount) | Yes | Create/resume draft; **with amount** → add gift card sale line; **without amount** → amount panel (focus there) |
| Explicit **New sale** / **Start sale** control | Yes | Create/resume empty draft explicitly |
| `/return`, `/rt` (+ optional receipt) | Not immediately | Open return drawer; draft starts when return lines selected |
| `/pickup`, `/pu` | Not immediately | Open pickup drawer; draft starts when fulfillment adds lines |
| `/customer`, `/cu` | Not immediately | Customer lookup modal/drawer; attach/start-sale are explicit actions |
| `/linediscount`, `/ld`, legacy `/d` | Requires active draft | Open line discount workflow |
| `/discount`, `/di`, legacy `/dt` | Requires active draft | Open transaction discount workflow |
| `/taxexempt`, `/tx` | Requires active draft | Tax exemption modal |
| `/tender`, `/tn` | Requires active draft | Settlement modal; no tender selected |
| `/cash`, `/card`, `/check`, `/giftredeem`, `/storecredit` (+ aliases) | Requires active draft | Settlement modal; tender selected/prefilled |
| `/hold`, `/ho` | Requires active draft | Suspend current transaction; clear active slot |
| `/balance`, `/bl` | No | Balance inquiry modal |
| `/session`, `/se` | No | Session summary drawer |
| `/reports`, `/rp` | No | Navigate to reports (confirm if active draft) |
| `/drawer`, `/dr` | No | Cash drawer action per permission/policy |
| `/cashin`, `/ci` | No | Miscellaneous cash-in modal |
| `/cashout`, `/co` | No | Miscellaneous cash-out modal |
| `/cashdrop`, `/drop`, `/dp` | No | **Planned/disabled in 10-C** — see cash drop note |
| `/close`, `/cl` | No | Close register workflow (see close rules) |
| `/help`, `/?`, `?` | No | Command help |

### Command carry-forward

When transaction-starting input originates from idle workspace, carry the original input into the new draft context:

```text
/op 10        → create/resume draft → open-ring with $10 prefilled
/gc 50        → create/resume draft → add gift card sale line for $50
/gc           → create/resume draft → gift card amount panel (blank)
scan barcode  → create/resume draft → resolve and add first line
```

The cashier must not re-enter the command or rescan after draft creation.

### Tender commands without active draft

If a tender command is entered with no active draft, **do not** create an empty draft:

```text
No active transaction to tender. Scan an item or enter /openring to begin a sale.
```

---

## Closed Session Behavior

When no register session is open:

```text
Register closed

Primary: Open Register
Secondary: Session history, Reports, Stored value balance lookup if allowed
```

After opening a register, land on idle workspace. No draft until a transaction-starting action.

---

## Workspace Layout

```text
Top context bar
  Store, register/workstation, cashier, session status, utility menu

Command field
  Scan / command — main keyboard focus target

Command feedback
  Inline guidance, lookup failures, permission/state messages

Primary work area
  Idle: quick actions, held-sale access, session hints
  Active: cart lines, qty controls, More/Edit, expanded modification rows

Sidebar (when transaction active)
  Totals, discounts/tax adjustments, readiness, settlement action

Modal layer
  Settlement, customer lookup, gift card issue/reload, balance inquiry,
  supervisor authorization, tax exemption, cash movements, cash drawer,
  confirm void/remove

Drawer layer
  Return workflow, pickup/customer requests, item detail, customer detail,
  session summary, transaction history, stored value account detail,
  held transaction list

Help strip
  Command help and mouse-accessible equivalents (no F-key legend required)
```

See mockups: Register workspace, item modification expanded row, settlement modal.

---

## Command Registry

Centralize commands in `Pos::CommandRegistry` (evolution of `Pos::CommandBarRouter`):

```ruby
Pos::CommandRegistry.define(:openring, aliases: %w[op open], ...)
```

Each command defines: canonical name, aliases, legacy aliases, description, permission keys, valid register/transaction states, handler target (modal/drawer/route/mutation), and unavailable message.

### Canonical commands and aliases

| Canonical | Alias | Legacy | Arguments | Action |
| --------- | ----: | -----: | --------- | ------ |
| `/customer` | `/cu` | — | search text optional | Customer lookup modal/drawer |
| `/openring` | `/op` | `/open` | amount optional | Open-ring entry |
| `/linediscount` | `/ld` | `/d` | amount/percent optional† | Line discount |
| `/discount` | `/di` | `/dt` | amount/percent optional† | Transaction discount |
| `/taxexempt` | `/tx` | — | none | Tax exemption modal |
| `/giftcard` | `/gc` | — | amount optional | Gift card issue/reload modal |
| `/giftredeem` | `/gr` | — | amount optional | Gift card redemption tender |
| `/balance` | `/bl` | — | lookup optional | Stored value balance inquiry |
| `/return` | `/rt` | — | receipt optional | Return drawer |
| `/pickup` | `/pu` | — | lookup optional | Pickup / customer request drawer |
| `/tender` | `/tn` | — | none | Settlement modal (neutral) |
| `/cash` | `/cs` | — | amount optional | Cash tender |
| `/card` | `/cd` | — | amount optional | Card tender |
| `/check` | `/ck` | — | amount optional | Check tender |
| `/storecredit` | `/sc` | — | amount optional | Store credit tender |
| `/hold` | `/ho` | — | none | Suspend current transaction |
| `/session` | `/se` | — | none | Session summary drawer |
| `/cashdrop` | `/dp`, `/drop` | — | amount optional | **Planned/disabled**‡ |
| `/cashin` | `/ci` | — | amount optional | Miscellaneous cash in |
| `/cashout` | `/co` | — | amount optional | Miscellaneous cash out |
| `/close` | `/cl` | — | none | Close register workflow |
| `/reports` | `/rp` | — | report key optional | Navigate to Reports |
| `/drawer` | `/dr` | — | reason optional | Cash drawer action (open/log) |
| `/help` | `/?`, `?` | — | command optional | Command help |

† **Discount amount/percent on the command line** (e.g. `/ld 10%`) is a follow-up enhancement. **Must-have for 10-C:** correct command opens the correct discount workflow; legacy `/d` and `/dt` keep working.

‡ **`/cashdrop` deferred for initial 10-C:** `PosCashMovement` currently supports only `paid_in` and `paid_out`; Phase 6 documents `cash_drop` as not yet modeled. Register `/cashdrop`, `/drop`, and `/dp` in the command registry and help as **planned/disabled** with message: `Cash drop is not available yet.` Shipped in 10-C: `/cashin` → `paid_in` and `/cashout` → `paid_out` modals. A future slice may add `cash_drop` movement type + modal when domain extension is approved.

### Discount commands (separate, not context-ambiguous)

| Command | Behavior |
| ------- | -------- |
| `/linediscount`, `/ld`, legacy `/d` | Discount previous discountable line (enhancement: selected line when cart selection exists) |
| `/discount`, `/di`, legacy `/dt` | Transaction-level discount |

If no line is eligible for line discount:

```text
No discountable line selected. Use /discount for a transaction discount.
```

### Tender commands

`/tender` and `/tn`:

* Require active draft
* Open settlement modal
* Do not select tender type or prefill amount
* Reject amount arguments:

```text
/tender does not accept an amount. Use /cash 20, /card 20, /check 20, /giftredeem 20, or /storecredit 20.
```

Specific tender commands (`/cash`, `/card`, etc.):

* Require active draft
* Open settlement modal with tender selected
* Prefill amount when provided; otherwise prefill balance due
* Never complete payment without cashier confirmation

### Gift card commands

**Sale/reload** (`/giftcard`, `/gc`) and **redemption** (`/giftredeem`, `/gr`) are separate commands.

#### Gift card issue/reload

```text
/gc       → create/resume draft if needed → amount panel, amount blank; focus amount field
/gc 50    → create/resume draft if needed → add gift card sale line for $50; return focus to command
```

* **With amount:** add `gift_card_sale` line immediately (same as explicit amount entry + submit).
* **Without amount:** open amount panel; Enter/submit adds line and returns focus to command field.
* Issue vs reload is determined after card/account lookup on the cart activation row (new card → issue; existing account → reload).
* Completion requires transaction completion; liability posts at completion per Phase 7B.

#### Gift card redemption

```text
/gr       → requires active draft → settlement modal, gift card tender selected
/gr 25    → requires active draft → settlement modal, $25 prefilled (subject to balance validation)
```

### Cash tender vs cash movements

These must remain visually and semantically distinct in help:

| Command | Meaning |
| ------- | ------- |
| `/cash 20` | Cash **tender on a sale** |
| `/cashin 20` | Miscellaneous cash **received** into drawer |
| `/cashout 20` | Miscellaneous cash **paid out** |
| `/cashdrop 100` | Drawer-to-safe **drop** *(planned/disabled in 10-C)* |

Cash movement modals collect amount, reason/category, optional note, confirmation, and audit context (cashier, register session, workstation). They do **not** navigate away to the register session page as the primary UX.

### Customer lookup

`/customer` and `/cu` are **transactionless** lookup commands.

* If a draft is active, the modal may offer **Attach to transaction**.
* If idle, lookup/details only — selecting a customer does **not** create a draft.
* Offer explicit **Start sale with this customer** to cross the transaction intent boundary.

### Return drawer

`/return` and `/rt` open the return drawer (mouse equivalent: **Return**).

```text
/rt                          → open return drawer
/rt 001-001-000042           → open return drawer with receipt lookup prefilled/run
```

Drawer supports: receipt lookup, receipt line selection, no-receipt return, reason/disposition. Draft is created or resumed when return lines are committed.

**Return behavior when an active draft already exists:**

| Active draft state | `/return` behavior |
| ------------------ | ------------------ |
| Empty draft | Return drawer may add return lines to it |
| Sale lines only | Return lines may be added; `Pos::DeriveTransactionType` yields **exchange** when mixed signs exist |
| Tender rows / settlement started | Block return line addition until tender rows are cleared |
| Completed / voided / cancelled | Not active; normal landing rules apply |
| Suspended / held | Must be resumed explicitly first |

Return lines may be committed into the active draft unless the draft has tender rows, settlement activity, or another incompatible state. In incompatible states, prompt the cashier to complete, cancel, hold, or clear settlement before adding return lines.

### Pickup drawer

`/pickup` and `/pu` open the pickup/customer-request drawer (mouse equivalent: **Pickup** / **Customer pickup**).

```text
/pu  → search/select ready requests
     → fulfillment creates/resumes draft only when adding pickup lines
```

Replaces the promoted `?mode=pickup` panel as the primary pickup UX. Fulfillment still uses reservation/pickup line services.

### Hold

`/hold` and `/ho` suspend the current draft (`status: suspended`). **Hold labels/names are out of scope for initial 10-C** unless a field is added deliberately.

### Close register (`/close`, `/cl`)

| State | `/close` behavior |
| ----- | ----------------- |
| No active draft | Open close-register workflow |
| Active draft exists | Block; instruct cashier to complete, cancel, or hold first |
| Held transactions exist | Warn / show held list before close (store policy) |

Suggested message when blocked:

```text
Cannot close register while a transaction is active. Complete, cancel, or hold the current transaction first.
```

### Help

`/help`, `/?`, and `?` open command help showing canonical command, aliases, arguments, description, permission-gated availability, and examples. No F-key legend required.

---

## Modals

Bounded tasks only:

* settlement
* customer lookup
* gift card issue/reload
* gift card redemption (within settlement)
* balance inquiry
* supervisor authorization
* tax exemption
* cash drawer action
* cash in / cash out
* confirm void/remove

Each modal uses 10-A shell behavior: focus trap, first meaningful control focused, Esc when safe (dirty guard), validation inside modal, Turbo updates, focus restoration, mouse-accessible controls.

---

## Drawers

Drawers are for inspection and bounded multi-step context, not full page replacement.

* return workflow
* pickup / customer requests
* item detail
* customer detail
* session summary
* transaction history
* stored value account detail
* held transaction list

---

## Cart and Line Editing

Use 10-A expanded rows. Current cart supports quantity, price, return disposition, line discount, and tax override; 10-C refines styling, focus, and keyboard behavior.

| Task | Pattern |
| ---- | ------- |
| Quantity change | Inline controls on row |
| Price, discount, tax override, return disposition | Expanded row |
| Remove line | Separated destructive action |
| Deeper item/customer/history context | Drawer |

After Save/Cancel: collapse row; restore focus to command field or triggering More/Edit button.

---

## Settlement

Settlement remains a modal showing remaining balance, change due, tender rows, add-tender actions, readiness blockers, and complete action.

* Completion disabled until readiness passes
* After completion, workspace returns to **idle** with command field focused and no active draft

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
| No active transaction for tender command | Command feedback area |

Do not use global flash for routine POS blockers.

---

## Session and Utility Access

Transactionless utilities must not force draft creation. `/reports` confirms before navigating away when an active draft exists (draft remains on server if cancelled).

---

## Out of Scope for Phase 10-C

* Required function-key bindings or F-key legend
* Browser-specific shortcut maps
* Implicit workflow guessing (bare amounts, receipt patterns, unmatched text → open ring)
* Auto-cancel of empty drafts
* Hold name/label fields (unless explicitly added)
* **`/cashdrop` execution** (command registered as planned/disabled until `cash_drop` movement type exists)
* POS domain rule changes (tax, discount, inventory posting)
* Offline POS; full POS rebuild
* Completing payments, issuing/reloading stored value, redeeming stored value, moving cash, or closing register without confirmation and audit
* Command aliases bypassing permissions or approval rules

---

## Implementation Phases / PR Slices

| Slice | Deliverable | Dependency |
| ----- | ----------- | ---------- |
| **1** | **Shared POS workspace shell + landing router + active draft resolver + intent boundary + command carry-forward** | Phase 6 POS |
| 2 | Two-lane parser; remove implicit intents from router | Slice 1 |
| 3 | `Pos::CommandRegistry`: aliases, permissions, states, `/help` | 10-A |
| 4 | Transaction commands: scan/add, open ring, gift card modal, explicit new sale | POS line services |
| 5 | Return drawer and pickup drawer | 10-A drawers |
| 6 | Tender commands → settlement modal | Phase 7B |
| 7 | Utility commands: balance, session, reports, drawer, cash in/out; `/cashdrop` planned/disabled | Session/cash services |
| 8 | Modal standardization (settlement, customer, tax, gift card, balance, cash) | 10-A |
| 9 | Cart expanded-row polish, focus restoration | 10-A |
| 10 | Session drawer, held-sale access, tests, docs sync | All above |

### Implementation progress

| Slice | Status |
| ----- | ------ |
| 1–5 | Merged — shell, parser, registry, transaction commands, return/pickup drawers |
| 6 | Merged — tender commands → settlement modal |
| 7 | Merged — utility commands (`/session`, `/reports`, `/close`, cash in/out, `/drawer`) |
| 8–10 | Pending |

Interim record: [phase-10c-completion.md](../implementation/phase-10c-completion.md)

---

## Keyboard/Focus Acceptance Criteria

### Required

* `/pos` with open session and no active draft → idle workspace; command field focused
* `/pos` with active draft → active draft workspace (including empty draft)
* Transactionless commands work while active draft exists without creating a second draft (blocked only by modal/dirty state)
* Line add and command submit return focus to command field when appropriate
* Enter routes slash commands or performs lookup/add
* Esc closes modal/drawer when safe; otherwise clears command field
* Modals/drawers trap and restore focus per 10-A
* Expanded line edit focuses first editable field; focus restored after Save/Cancel
* Settlement reachable via visible controls and commands — not function keys
* After completed sale → idle workspace, command field focused
* Touch targets ~44px on expanded row and settlement actions
* Mouse-accessible equivalents for all primary actions

### Not required

* Function-key bindings
* Browser-specific keyboard maps
* F-key legend in help
* Discount amount arguments on command line (enhancement)

---

## Test Plan Highlights

See [phase-10c-pos-keyboard-workspace-spec.md](../specifications/phase-10c-pos-keyboard-workspace-spec.md#test-plan) for full detail.

### Landing and active draft

* Session closed → open-register workflow
* Session open, no active draft → idle workspace; no `PosTransaction` created without user action
* Session open, one active draft (session + workstation + cashier) → return to draft
* Session open, multiple draft candidates → conflict picker
* Empty active draft → `/pos` still returns to draft until cancel/hold/complete/void
* Cross-cashier workstation conflict → conflict UI; no silent takeover

### Two-lane parser

* Bare `20`, receipt-shaped input, unmatched text → failed lookup; no draft
* Scan/SKU/ISBN → lookup/add; creates/resumes draft when line added

### Discount command split

* `/d` opens line discount workflow
* `/ld` opens line discount workflow
* `/dt` opens transaction discount workflow
* `/di` opens transaction discount workflow
* `/discount` opens transaction discount workflow
* `/d` does **not** open transaction discount

### Return, close, cashdrop

* `/return` with sale-only active draft → exchange allowed
* `/return` with tender rows on draft → blocked with prompt
* `/close` with active draft → blocked with message
* `/cashdrop` → planned/disabled message; no movement posted

### Transactionless with active draft

* `/balance` with empty active draft → modal opens; draft unchanged

---

## Acceptance Criteria Summary

See [phase-10c-pos-keyboard-workspace-spec.md](../specifications/phase-10c-pos-keyboard-workspace-spec.md#acceptance-criteria) for test-plan detail.

* Opening `/pos` with open session and no active draft does not create a draft
* `/pos` with active draft always returns to that draft (including empty)
* `/balance`, `/session`, `/help`, cash movement commands, etc. do not create drafts and work while a draft is active
* Scan from idle creates/resumes draft and adds item with carry-forward
* `/op 10` from idle create/resume draft and carry prefilled amount into open-ring workflow
* `/gc 50` from idle create/resume draft and add gift card sale line; focus returns to command
* `/gc` without amount opens amount panel with focus there; submit adds line and returns to command
* `/tender` and specific tender commands from idle show no-active-transaction message; do not create empty draft
* `/tender` rejects amount arguments; specific tender commands accept optional amounts when draft active
* `/linediscount` and `/discount` are separate; legacy `/d` and `/dt` still work
* `/d` and `/ld` open line discount; `/dt`, `/di`, and `/discount` open transaction discount (`/d` must not open transaction discount)
* `/return` and `/pickup` open drawers; draft starts on line selection/fulfillment
* `/return` blocked when active draft has tender rows; exchange allowed for sale-only drafts
* `/close` blocked while active draft exists
* `/cashdrop` shows planned/disabled message in 10-C
* Bare amounts, receipt patterns, and unmatched text do not infer workflows
* One active draft per register session + workstation + cashier enforced at creation time
* Hold clears active slot; held sales resume only explicitly
* Command aliases normalize before permission checks and routing
* `/reports` confirms before navigate when active draft exists
* Line edits use 10-A expanded-row pattern; settlement uses 10-A modal shell
* Required keyboard/focus criteria met without function keys

---

## Related Documents

```text
docs/specifications/phase-10c-pos-keyboard-workspace-spec.md
docs/specifications/phase-10c-test-plan.md
docs/specifications/pos-keyboard-workspace.md
docs/specifications/keyboard-and-focus.md
docs/specifications/view-contracts.md
docs/roadmap/phase-10a-interaction-infrastructure.md
docs/roadmap/phase-10b-item-cockpit-completion.md
docs/roadmap/Phase-x10-comprehensive-ux-expansion.md
docs/samples/phase-10-mockups/shelfstack_pos_mockups.html
```
