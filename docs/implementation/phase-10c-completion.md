# Phase 10-C — POS Keyboard Workspace

**Status:** Near complete (slices 1–10 delivered; pending full manual QA before marking **Complete**)

**Spec:** [phase-10c-pos-keyboard-workspace-spec.md](../specifications/phase-10c-pos-keyboard-workspace-spec.md)

**Roadmap:** [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md)

**Slice 9A (transaction discount modal):** [phase-10c-9a-transaction-discount-modal.md](../roadmap/phase-10c-9a-transaction-discount-modal.md)

**Slice 9B (tender/completion):** [phase-10c-9b-tender-workspace-and-completion.md](../roadmap/phase-10c-9b-tender-workspace-and-completion.md)

**Test plan:** [phase-10c-test-plan.md](../specifications/phase-10c-test-plan.md)

Integration branch: `phase-10c-pos-keyboard-workspace`. Mark **Complete** only after full manual QA and merge to `main`.

---

## Delivered (slices 1–8)

### Slice 1 — Workspace shell, landing, draft lifecycle

- Idle/active POS workspace shell; `Pos::LandingRouter`, `Pos::ActiveDraftResolver`, `Pos::DraftCreator`
- Register session + workstation + cashier scoped active draft; conflict picker
- Command carry-forward from idle into transaction edit
- Root `POST /pos/route_command` via `Pos::WorkspaceCommandsController`

### Slice 2 — Two-lane parser

- `Pos::CommandParser` lanes: slash → registry; non-slash → catalog lookup only
- Removed implicit open-ring/receipt/amount guessing from routing

### Slice 3 — Command registry and help

- `Pos::CommandRegistry` with aliases, permissions, register/transaction state, planned/disabled commands
- `/help`, `/?`, `?` categorized help modal

### Slice 4 — Transaction commands

- Scan/add, `/openring` / `/op`, `/giftcard` / `/gc`, explicit new sale
- `/gc` with amount adds gift card sale line; without amount opens amount panel (focus there; Enter saves)

### Slice 5 — Return and pickup drawers

- `/return`, `/pickup` inline drawers from idle and active transaction
- Idle drawers without upfront draft (draft on line commit)
- No-receipt return tab; help modal cheat sheet

### Slice 6 — Tender commands → settlement

- `/tender`, `/cash`, `/card`, `/check`, `/giftredeem`, `/storecredit` open settlement modal
- Idle tender commands → no-active-transaction message (no empty draft)
- `route_command` gated on `pos.transactions.update`; registry enforces tender permissions

### Slice 7 — Utility commands

- `/session` — register session drawer (slice 10: shared 10-A drawer with held sales)
- `/held` — held/suspended transactions drawer section
- `/reports` — navigate to `/reports`; confirm when active draft exists
- `/close` — close-register workflow; blocked when active draft exists
- `/cashin`, `/cashout` — cash movement modal (Escape dismisses); posts via `Pos::CashMovementsController` with return-to-workspace redirect
- `/drawer` — cash drawer guidance modal
- `/balance` — redirect on idle; inline panel on active transaction
- `/cashdrop` — planned/disabled

### Slice 8 — Modal standardization

- Settlement, customer lookup, tax exemption, gift card, balance inquiry, and cash movement modals on shared 10-A interaction shells
- Supervisor authorization modal wiring for readiness blockers

### Focus and keyboard (cross-cutting)

- `pos-workspace-focus` restores command field after Turbo workspace updates when no blocking panel/modal is open
- Gift card panel, cash movement modal, and other inline panels skip command focus while open

---

## Delivered (slice 9)

- Cart line **More** menu with task-specific panels (edit, discount, tax)
- Floating menu positioning (not clipped by cart table)
- Expanded-row focus restore; `/linediscount` opens discount panel
- Consistent discount/tax note fields (dynamic required marker, single-line input)

---

## Delivered (slice 9A)

- Transaction discount modal (`/discount`, `/di`, `/dt`) with command prefill
- Estimated total preview in modal; sidebar launcher via document event
- Tax exemption modal in-modal validation errors
- Integration + system tests for discount modal

---

## Delivered (slice 9B)

**Branch:** `phase-10c-9b-tender-workspace`

- Completed transaction workspace at `/pos/transactions/:id/completed` with New Sale primary action
- Complete action redirects to completed workspace
- Tender modal restructure: summary (amount due/tendered/remaining), hotkey type selector, active detail panel
- Save tender via `sync_tenders` without auto-complete; Enter/Escape keyboard behavior
- Ready-to-complete state when tenders cover balance
- Stored value tender type resolved after identifier lookup (`/giftredeem`, `/storecredit` → unified stored value entry)

---

## Delivered (slice 10)

- Register session drawer (`/session`, `/held`) on shared 10-A drawer shell
- Held sales table with permission-aware resume links
- Idle workspace **Session** and **Held sales (N)** actions
- `Pos::SuspendedTransactionsLookup` shared query
- Foundation runbook POS section refreshed
- Acceptance tests: session/held routing, suspended lookup, tender route commands, completed workspace New Sale

---

## Verification (slices 1–10)

```bash
docker compose exec -T web bin/rails test test/services/pos/
docker compose exec -T web bin/rails test test/integration/pos_workspace_landing_test.rb
docker compose exec -T web bin/rails test test/integration/pos_transaction_route_command_test.rb
docker compose exec -T web bin/rails test test/integration/pos_completed_workspace_test.rb
docker compose exec -T web bin/rails test test/services/pos/root_command_router_test.rb
docker compose exec -T web bin/rails test test/services/pos/command_bar_router_test.rb
docker compose exec -T web bin/rails test test/services/pos/suspended_transactions_lookup_test.rb
```

---

## Spec changes recorded

| Topic | Original spec | Implemented (slices 1–7) |
| ----- | ------------- | ------------------------ |
| `/gc` with amount | Modal with prefilled amount; no auto-post (original spec) | **Adopted after QA:** adds `gift_card_sale` line immediately; command focus returns. `/gc` without amount opens amount panel. Documented as intentional spec change. |
| `/gc` without amount | Open modal | Opens amount panel; focus amount field; submit returns to command |
| Cash in/out UX | Modal (not register session page) | Modal posts with `return_path` back to workspace |
| Transaction discount entry | Adjustments `<details>` panel | **Slice 9A:** transaction discount modal with preview total; adjustments panel is launcher + list |
| Post-completion landing | Idle workspace immediately | **Slice 9B:** `/completed` workspace with New Sale primary action |

---

## Deferred / follow-on

- `/cashdrop` execution until `cash_drop` movement type exists
- Function-key bindings and F-key legend
- Merge to `main` after full manual QA
- Gift receipt printing (placeholder in slice 9B completed workspace)
- Tax panel server-side error reopen with preserved values (follow-up from slice 9)
