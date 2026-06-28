# Phase 10-C — Manual QA Checklist

**Status:** Phase 10-C marked **Complete** 2026-06-26. This checklist remains useful for regression passes before merge to `main` or after POS changes.

**Branch:** `phase-10c-pos-keyboard-workspace` (or after merge to `main`)

**Spec:** [phase-10c-pos-keyboard-workspace-spec.md](../specifications/phase-10c-pos-keyboard-workspace-spec.md)

**Completion record:** [phase-10c-completion.md](phase-10c-completion.md)

**Runbook:** [foundation-runbook.md](../operations/foundation-runbook.md#pos-register-operations-phase-6--phase-10-c)

Use this checklist for regression verification. Test on a **register workstation** with at least two roles: **pos_cashier** and **pos_lead** or **pos_manager**.

**Suggested browsers:** Chrome plus one of Safari or Firefox (keyboard/focus behavior differs).

**Automated coverage map:** [below](#automated-coverage-map) — maps each checklist row to test files and coverage level.

---

## Setup

- [ ] Register session open on workstation **001 Front Register**
- [ ] Test user has `pos.access` and typical cashier permissions
- [ ] At least one sellable SKU in stock (scan test)
- [ ] Gift card classification + `pos.gift_cards.issue` available
- [ ] Stored value account with known balance (gift card + store credit)
- [ ] Second cashier account for cross-cashier / resume-other tests
- [ ] No stray drafts/suspended transactions on workstation before starting each section (or note starting state)

---

## 1. Landing and active draft

| # | Step | Expected | Pass |
|---|------|----------|------|
| 1.1 | Go to `/pos` with register **closed** | Open-register workflow; no draft created | ☐ |
| 1.2 | Open register, land on `/pos` | Idle workspace; **command field focused**; no draft until action | ☐ |
| 1.3 | Scan SKU from idle | Draft created/resumed; line added; focus returns to command | ☐ |
| 1.4 | Navigate away, return to `/pos` with active draft | Returns to same draft (not idle) | ☐ |
| 1.5 | Start empty draft (New sale), leave, return `/pos` | Still on empty draft until cancel/hold/complete | ☐ |
| 1.6 | `/hold` current draft, return `/pos` | Idle workspace (active slot cleared) | ☐ |
| 1.7 | Create legacy/conflict scenario (if testable) | Conflict picker; no silent second draft | ☐ |
| 1.8 | Different cashier on same workstation with another's draft | Conflict/resume UI; no silent takeover | ☐ |

---

## 2. Command field and two-lane parser

| # | Step | Expected | Pass |
|---|------|----------|------|
| 2.1 | Type `20` (no slash) from idle | Failed lookup message; **no draft** | ☐ |
| 2.2 | Type receipt-shaped number from idle | Failed lookup; suggests `/return`; no draft | ☐ |
| 2.3 | Type random text from idle | Failed lookup; no draft | ☐ |
| 2.4 | `/help` or `?` | Help modal; categorized commands; no draft | ☐ |
| 2.5 | `/foo` | Unknown command message; no draft | ☐ |
| 2.6 | `/cash` from idle | No-active-transaction message; **no empty draft** | ☐ |
| 2.7 | `/tender 20` | Rejects amount; helpful message | ☐ |
| 2.8 | `/cashdrop` | Planned/disabled message; no movement | ☐ |

---

## 3. Transaction-starting commands (idle → draft)

| # | Step | Expected | Pass |
|---|------|----------|------|
| 3.1 | `/op 10` from idle | Draft + open-ring panel; $10 prefilled | ☐ |
| 3.2 | `/gc 50` from idle | Draft + gift card sale line $50; focus → command | ☐ |
| 3.3 | `/gc` without amount | Amount panel focused; submit adds line | ☐ |
| 3.4 | `/return` from idle | Return drawer opens; no draft until line commit | ☐ |
| 3.5 | `/pickup` from idle | Pickup drawer opens | ☐ |
| 3.6 | `/customer Smith` from idle | Customer lookup; attach/start-sale explicit; no auto-draft | ☐ |

---

## 4. Transactionless commands (with active draft)

| # | Step | Expected | Pass |
|---|------|----------|------|
| 4.1 | `/balance` with empty draft open | Balance modal; draft unchanged | ☐ |
| 4.2 | `/session` with draft open | Session drawer; draft unchanged | ☐ |
| 4.3 | `/held` with draft open | Drawer scrolls to held sales; draft unchanged | ☐ |
| 4.4 | `/help` with draft open | Help modal; draft unchanged | ☐ |
| 4.5 | `/cashin 10` with draft open | Cash-in modal; posts; returns to workspace | ☐ |
| 4.6 | `/reports` with draft open | Confirm dialog; cancel keeps draft on server | ☐ |
| 4.7 | `/close` with active draft | Blocked with clear message | ☐ |

---

## 5. Session drawer and held sales (slice 10)

| # | Step | Expected | Pass |
|---|------|----------|------|
| 5.1 | `/session` from idle | Drawer opens; session summary visible | ☐ |
| 5.2 | **Session** button on idle workspace | Same drawer | ☐ |
| 5.3 | Suspend a sale (`/hold`), `/held` | Held list shows transaction; **not auto-resumed** | ☐ |
| 5.4 | **Held sales (N)** button when N > 0 | Opens drawer on held section | ☐ |
| 5.5 | **Resume** on own held sale | Returns to editable draft | ☐ |
| 5.6 | Resume another cashier's held sale (no permission) | No access / blocked | ☐ |
| 5.7 | Resume with `pos.transactions.resume.other_cashier` | Works for lead/manager | ☐ |
| 5.8 | Esc / backdrop close drawer | Focus returns to command field | ☐ |

---

## 6. Cart and line editing (slice 9)

| # | Step | Expected | Pass |
|---|------|----------|------|
| 6.1 | **More** menu on cart line | Edit / discount / tax panels | ☐ |
| 6.2 | Expand row → edit qty/price | First field focused; Save/Cancel work | ☐ |
| 6.3 | After Save/Cancel | Row collapses; focus restored sensibly | ☐ |
| 6.4 | `/ld` or `/d` | Line discount on previous discountable line | ☐ |
| 6.5 | `/discount` or `/dt` | Transaction discount **modal** (not line panel) | ☐ |
| 6.6 | `/d` does **not** open transaction discount | Confirms command split | ☐ |
| 6.7 | Transaction discount modal | Preview total updates; apply works | ☐ |
| 6.8 | `/tx` | Tax exemption modal | ☐ |

---

## 7. Return and pickup

| # | Step | Expected | Pass |
|---|------|----------|------|
| 7.1 | `/return` on sale-only draft | Return drawer; can add return lines | ☐ |
| 7.2 | Mixed sale + return lines | Exchange totals behave correctly | ☐ |
| 7.3 | Add tender, then `/return` | Blocked until settlement cleared | ☐ |
| 7.4 | Receipted return via `/rt <receipt>` | Receipt prefilled/lookup runs | ☐ |
| 7.5 | No-receipt return tab | Scan adds return line | ☐ |
| 7.6 | `/pickup` → fulfill ready request | Pickup line added; draft created if needed | ☐ |

---

## 8. Tender workspace (slice 9B)

### Open and type selection

| # | Step | Expected | Pass |
|---|------|----------|------|
| 8.1 | `/tender` on active sale | Settlement modal; no type preselected | ☐ |
| 8.2 | `/cash` | Cash selected; amount prefilled to **remaining due** | ☐ |
| 8.3 | `/card 20` | Card selected; $20 prefilled | ☐ |
| 8.4 | `/check`, `/giftredeem`, `/storecredit` | Correct type; prefill remaining | ☐ |
| 8.5 | Hotkeys **1–4** in modal | Select cash / card / check / stored value | ☐ |
| 8.6 | Modal summary | Amount due / tendered / remaining update live | ☐ |

### Save, partial tender, remove

| # | Step | Expected | Pass |
|---|------|----------|------|
| 8.7 | Save partial cash (less than due) | Row saved; remaining due shown; **not auto-complete** | ☐ |
| 8.8 | Save second tender to cover balance | **Ready to complete** state | ☐ |
| 8.9 | Remove saved tender row | Row gone after save/sync; totals update | ☐ |
| 8.10 | Invalid card (no brand) → Save | Error in flash/modal; draft preserved | ☐ |
| 8.11 | Enter on amount field | Saves active tender detail | ☐ |
| 8.12 | Escape on active detail | Cancels detail; no phantom row | ☐ |
| 8.13 | Escape with no active detail | Closes modal; saved rows kept | ☐ |
| 8.14 | Enter on Cancel/Save buttons | Native button activation (not double-submit) | ☐ |

### Stored value tender

| # | Step | Expected | Pass |
|---|------|----------|------|
| 8.15 | `/giftredeem` → lookup gift card | Resolves to gift card type after lookup | ☐ |
| 8.16 | `/storecredit` → lookup store credit | Resolves to store credit type | ☐ |
| 8.17 | Amount > account balance | Capped or validation error | ☐ |
| 8.18 | Invalid identifier | Cannot save until valid lookup | ☐ |

### Split tender and change

| # | Step | Expected | Pass |
|---|------|----------|------|
| 8.19 | Cash + card split | Both rows saved; totals correct | ☐ |
| 8.20 | Cash overpay | Change due calculated correctly | ☐ |
| 8.21 | Refund transaction (return) | Negative tenders behave correctly | ☐ |

---

## 9. Completion and completed workspace (slice 9B)

| # | Step | Expected | Pass |
|---|------|----------|------|
| 9.1 | Ready to complete → explicit **Complete** | Transaction completes | ☐ |
| 9.2 | Enter from ready state | Completes (when not on button/link) | ☐ |
| 9.3 | After complete | Redirect to **completed workspace** (not editable cart) | ☐ |
| 9.4 | Completed workspace | Trans #, total, tendered, change shown | ☐ |
| 9.5 | **Print receipt** | Receipt link works | ☐ |
| 9.6 | Gift card sale complete | Stored value slip link visible | ☐ |
| 9.7 | Gift receipt placeholder | Shown as optional/non-blocking | ☐ |
| 9.8 | **New Sale** (primary) | Idle workspace; command field focused | ☐ |
| 9.9 | Enter on completed workspace | Starts new sale (or focuses required slip first) | ☐ |
| 9.10 | Required unprinted SV slip | Enter focuses slip action, not New Sale | ☐ |
| 9.11 | Secondary: View summary | Read-only transaction detail | ☐ |

---

## 10. Register utilities

| # | Step | Expected | Pass |
|---|------|----------|------|
| 10.1 | `/close` with no active draft | Close-register workflow opens | ☐ |
| 10.2 | Close with held sales on workstation | Warning/list per policy | ☐ |
| 10.3 | `/drawer` | Drawer guidance modal | ☐ |
| 10.4 | `/cashin` vs `/cash` | Distinct UX (movement vs sale tender) | ☐ |
| 10.5 | Complete sale → void from summary | Void still works; inventory reverses | ☐ |

---

## 10-C-11 Workspace layout (slice 11)

| # | Step | Expected | Pass |
|---|------|----------|------|
| 11.1 | Open active transaction | Shared header: POS \| store \| workstation \| register \| business date \| **Actions** | ☐ |
| 11.2 | Actions menu (register open) | Balance, Session, Cash In/Out, Close, Reports, Drawer available per permissions | ☐ |
| 11.3 | Close register → idle | Header shows **Closed**; balance action works; Cash In disabled with message | ☐ |
| 11.4 | Customer strip | None + Link / attached name + Remove; detach updates strip via turbo | ☐ |
| 11.5 | Status panel | Transaction discount list + Add discount; tax exempt summary + Apply; no adjustments `<details>` | ☐ |
| 11.6 | Cart columns | Qty \| Item \| Discount (line/trans split) \| Total \| Tax (subtle amount) \| More | ☐ |
| 11.7 | Totals panel | Tax rows show amount + subtle rate/base; items sold/returned counts | ☐ |
| 11.8 | Flash notice | Auto-clears ~5s; Dismiss works; command field focus not stolen | ☐ |
| 11.9 | Flash error | Persists until dismissed | ☐ |
| 11.10 | Complete Transaction | Opens settlement modal; Suspend/Cancel on right rail | ☐ |
| 11.11 | Structural blocker | Single alert above Complete (no full readiness checklist in main column) | ☐ |
| 11.12 | Idle workspace | Open Ring / Gift Card buttons; Held sales chip when suspended exist; no New sale/Session primary row | ☐ |
| 11.13 | Completed → View receipt → Back | Returns to completed workspace | ☐ |

---

## 11. Keyboard and focus (cross-cutting)

| # | Step | Expected | Pass |
|---|------|----------|------|
| 11.1 | After Turbo cart update | Command field refocuses when no modal open | ☐ |
| 11.2 | Modal open (discount, tax, tender) | Command field does **not** steal focus | ☐ |
| 11.3 | Close modal/drawer | Focus restored to opener or command | ☐ |
| 11.4 | Tab trap inside modal | Cannot tab to background | ☐ |
| 11.5 | Mouse-only path | All primary actions reachable without keyboard | ☐ |
| 11.6 | Touch targets on cart More / settlement | ~44px; usable on touch screen | ☐ |

---

## 12. Regression smoke (prior phases)

| # | Step | Expected | Pass |
|---|------|----------|------|
| 12.1 | Standard sale → inventory | On-hand decrements | ☐ |
| 12.2 | Gift card sale at complete | SV ledger issued | ☐ |
| 12.3 | Gift card redeem tender | Balance decrements | ☐ |
| 12.4 | Transaction + line discounts | Totals and cached cents correct | ☐ |
| 12.5 | Tax exemption + line override | Applied tax source snapshots correct | ☐ |
| 12.6 | Customer pickup with reservation | Reservation chain honored | ☐ |
| 12.7 | Inactive item sell | Warning + confirm path | ☐ |

---

## Known deferred (log as expected gap, not failure)

- `/cashdrop` execution
- Function-key bindings / F-key legend
- Discount amount on command line (`/ld 10%`)
- Gift receipt printing (placeholder only)
- `/cash` or hotkey **1** reopening existing partial cash row (optional follow-up)
- Tax panel server-side error reopen with preserved values

---

## Quick smoke path (~15 min)

1.2 → 2.1 → 3.1 → 8.1–8.8 → 9.1–9.8 → 5.3–5.5

---

## Automated coverage map

Maps manual QA checklist rows to automated tests on branch `phase-10c-pos-keyboard-workspace`.

**Legend**

| Symbol | Meaning |
|--------|---------|
| **Auto** | Primary behavior covered by automated test(s) |
| **Partial** | Domain/routing/API covered; browser UX, focus, or edge case still manual |
| **Manual** | No meaningful automated coverage — checklist row required |

**Summary (checklist rows only):** ~45% **Auto**, ~30% **Partial**, ~25% **Manual**. Keyboard/focus (§11) and visual/touch checks remain mostly manual by design.

**Run scaffolded browser tests:**

```bash
docker compose exec -T web bin/rails test \
  test/system/pos/ \
  test/integration/pos_held_sales_lifecycle_test.rb \
  test/integration/pos_completed_workspace_test.rb \
  test/integration/pos_workspace_landing_test.rb \
  test/integration/pos_transaction_route_command_test.rb
```

### §1 Landing and active draft

| # | Coverage | Test file(s) | Notes |
|---|----------|--------------|-------|
| 1.1 | Partial | `landing_router_test.rb` (`closed`); `pos_home_controller_test.rb` (closed register) | Open-register workflow UI not system-tested |
| 1.2 | Partial | `pos_workspace_landing_test.rb` (idle command field); `landing_router_test.rb` (`idle`) | Focus-on-load is manual |
| 1.3 | Partial | `pos_workspace_landing_test.rb` (scan → draft + line); `root_command_router_test.rb` | Focus return after Turbo is manual (§11.1) |
| 1.4 | Auto | `pos_workspace_landing_test.rb` (`active session-scoped draft redirects to edit`) | |
| 1.5 | Partial | `pos_draft_lifecycle_test.rb` (resume existing draft); `active_draft_resolver_test.rb` | Empty-draft persistence via navigation not system-tested |
| 1.6 | Auto | `pos_held_sales_lifecycle_test.rb` (`hold command suspends draft…`) | `/hold` routes to suspend; JS PATCH follows route payload |
| 1.7 | Auto | `pos_workspace_landing_test.rb` (legacy conflict picker); `active_draft_resolver_test.rb` (`legacy_found`) | |
| 1.8 | Partial | `active_draft_resolver_test.rb` (workstation/cashier scope, conflict); `pos_home_controller_test.rb` (queue tables) | Cross-cashier takeover UX manual |

### §2 Command field and two-lane parser

| # | Coverage | Test file(s) | Notes |
|---|----------|--------------|-------|
| 2.1 | Auto | `pos_workspace_landing_test.rb`; `root_command_router_test.rb`; `command_parser_test.rb` | |
| 2.2 | Auto | `pos_workspace_landing_test.rb` (`receipt-shaped input`) | |
| 2.3 | Auto | `pos_workspace_landing_test.rb` (`failed lookup`) | |
| 2.4 | Auto | `pos_workspace_landing_test.rb` (`/help`, `?`); `command_registry_test.rb` (help metadata) | Modal display manual |
| 2.5 | Auto | `pos_workspace_landing_test.rb`; `root_command_router_test.rb` | |
| 2.6 | Auto | `pos_workspace_landing_test.rb`; `root_command_router_test.rb` | |
| 2.7 | Partial | `command_registry_test.rb` (`/tender` rejects amount via route builder message) | Idle-path integration not dedicated |
| 2.8 | Auto | `command_registry_test.rb` (`cashdrop` planned); `root_command_router_test.rb` | |

### §3 Transaction-starting commands (idle → draft)

| # | Coverage | Test file(s) | Notes |
|---|----------|--------------|-------|
| 3.1 | Partial | `pos_workspace_landing_test.rb` (open ring drawer offer); `root_command_router_test.rb` (`/op`) | Draft + $10 prefill via carry-forward manual |
| 3.2 | Auto | `pos_workspace_landing_test.rb` (`/gc 50`); `root_command_router_test.rb` | |
| 3.3 | Partial | `root_command_router_test.rb` (`/gc` carry-forward); `pos_workspace_landing_test.rb` | Amount panel focus manual |
| 3.4 | Auto | `pos_workspace_landing_test.rb`; `root_command_router_test.rb` | |
| 3.5 | Auto | `pos_workspace_landing_test.rb`; `root_command_router_test.rb` | |
| 3.6 | Partial | `pos_customer_workspace_test.rb` (`start_sale`); `root_command_router_test.rb` | `/customer` lookup modal UX manual |

### §4 Transactionless commands (with active draft)

| # | Coverage | Test file(s) | Notes |
|---|----------|--------------|-------|
| 4.1 | Partial | `command_bar_router_test.rb`; `root_command_router_test.rb` (`/balance` routing) | Modal open with active draft manual |
| 4.2 | Auto | `pos_transaction_route_command_test.rb`; `pos_workspace_landing_test.rb` | |
| 4.3 | Auto | `pos_transaction_route_command_test.rb`; `pos_workspace_landing_test.rb` (focus payload) | Scroll-to-held UX manual |
| 4.4 | Partial | `pos_transaction_route_command_test.rb` (implicit via transaction route tests) | Help modal with draft open manual |
| 4.5 | Auto | `pos_transaction_route_command_test.rb` (`/cashin`); `pos_cash_movements_controller_test.rb` | Modal workflow manual |
| 4.6 | Auto | `pos_transaction_route_command_test.rb` (`/reports` confirm) | |
| 4.7 | Auto | `pos_transaction_route_command_test.rb`; `pos_workspace_landing_test.rb` (return blocked with settlement) | |

### §5 Session drawer and held sales

| # | Coverage | Test file(s) | Notes |
|---|----------|--------------|-------|
| 5.1 | Partial | `pos_workspace_landing_test.rb`; `pos_home_controller_test.rb` (drawer shell) | Drawer open animation/focus manual |
| 5.2 | Manual | — | Session button click not system-tested |
| 5.3 | Partial | `pos_held_sales_lifecycle_test.rb`; `suspended_transactions_lookup_test.rb` | `/held` command + list content manual |
| 5.4 | Manual | — | Held sales (N) button not system-tested |
| 5.5 | Auto | `pos_held_sales_lifecycle_test.rb` (`cashier resumes own held sale`) | |
| 5.6 | Auto | `pos_held_sales_lifecycle_test.rb`; `pos_helper_test.rb` (`pos_can_resume_transaction?`) | |
| 5.7 | Auto | `pos_held_sales_lifecycle_test.rb`; `pos_helper_test.rb` | |
| 5.8 | Manual | — | Esc/backdrop focus restore manual (see §11) |

### §6 Cart and line editing

| # | Coverage | Test file(s) | Notes |
|---|----------|--------------|-------|
| 6.1 | Partial | `pos_cart_expanded_row_test.rb` (More menu panels) | Full panel UX manual |
| 6.2 | Partial | `pos_cart_expanded_row_test.rb`; `phase6_pos_polish_integration_test.rb` (update line) | First-field focus manual |
| 6.3 | Partial | `pos_cart_expanded_row_test.rb` (collapsed after save) | Focus restore manual |
| 6.4 | Auto | `command_bar_router_test.rb` (`/d`, `/ld`); `command_registry_test.rb` | |
| 6.5 | Auto | `command_bar_router_test.rb` (`/discount`, `/dt`); `pos_transaction_discount_modal_test.rb` | |
| 6.6 | Auto | `command_registry_test.rb` (`/d` → linediscount, not transaction discount) | |
| 6.7 | Auto | `pos_transaction_discount_modal_test.rb` (integration + system); `pos_line_discount_workspace_test.rb` | Preview total in browser partial |
| 6.8 | Partial | `pos_tax_exemption_modal_test.rb` (integration) | `/tx` command routing + modal UX manual |

### §7 Return and pickup

| # | Coverage | Test file(s) | Notes |
|---|----------|--------------|-------|
| 7.1 | Partial | `pos_workspace_landing_test.rb`; `root_command_router_test.rb` | Drawer UX manual |
| 7.2 | Partial | `phase6_pos_polish_integration_test.rb` (returns/exchange) | Mixed exchange totals manual |
| 7.3 | Auto | `pos_workspace_landing_test.rb`; `root_command_router_test.rb` (settlement blocks return) | |
| 7.4 | Partial | `root_command_router_test.rb` (`/rt` receipt prefill) | Receipted return flow manual |
| 7.5 | Partial | `phase6_pos_polish_integration_test.rb` (no-receipt return) | Tab UX manual |
| 7.6 | Manual | — | Pickup fulfillment end-to-end manual |

### §8 Tender workspace

| # | Coverage | Test file(s) | Notes |
|---|----------|--------------|-------|
| 8.1 | Partial | `pos_transaction_route_command_test.rb` (`/tender`); `tender_workspace_test.rb` (via `/tender` hotkey test) | No-type-preselected assertion partial |
| 8.2 | Auto | `tender_workspace_test.rb`; `pos_transaction_route_command_test.rb` (`/cash`) | |
| 8.3 | Auto | `pos_transaction_route_command_test.rb` (`/card 20`) | Browser prefill manual |
| 8.4 | Partial | `pos_transaction_route_command_test.rb` (`/giftredeem`); `settlement_sync_test.rb` | `/check`, `/storecredit` browser manual |
| 8.5 | Auto | `tender_workspace_test.rb` (hotkey 2 → card); cash hotkey implicit in `/cash` test | Hotkeys 3–4 manual |
| 8.6 | Partial | `tender_workspace_test.rb` (partial save shows remaining); `readiness_preview_test.rb` | Live summary updates in browser partial |
| 8.7 | Auto | `tender_workspace_test.rb`; `settlement_sync_test.rb` (partial cash) | |
| 8.8 | Partial | `settlement_sync_test.rb` (split tender); `tender_workspace_test.rb` (full cash ready) | Two-tender browser flow manual |
| 8.9 | Auto | `settlement_sync_test.rb` (`destroy` row) | Browser remove row manual |
| 8.10 | Partial | `settlement_sync_test.rb` (validation) | Flash/modal error display manual |
| 8.11 | Manual | — | Enter-on-amount-field save not system-tested |
| 8.12 | Auto | `tender_workspace_test.rb` (`escape cancels active detail`) | |
| 8.13 | Manual | — | Escape closes modal with saved rows manual |
| 8.14 | Manual | — | Enter on Cancel/Save buttons manual |
| 8.15 | Partial | `pos_transaction_route_command_test.rb` (`/giftredeem`) | Lookup → resolve type in browser manual |
| 8.16 | Partial | `phase7b_settlement_integration_test.rb`; stored-value service tests | Lookup UX manual |
| 8.17 | Partial | `settlement_sync_test.rb`; `phase7b_settlement_integration_test.rb` | Cap/error display manual |
| 8.18 | Partial | `phase7b_settlement_integration_test.rb` | Invalid identifier UX manual |
| 8.19 | Auto | `settlement_sync_test.rb` (split cash + card) | Browser split flow manual |
| 8.20 | Auto | `settlement_sync_test.rb` (cash overpay change); `phase6_pos_polish_integration_test.rb` | |
| 8.21 | Auto | `settlement_sync_test.rb` (refund tenders) | Browser refund modal manual |

### §9 Completion and completed workspace

| # | Coverage | Test file(s) | Notes |
|---|----------|--------------|-------|
| 9.1 | Auto | `tender_workspace_test.rb` (Complete button); `pos_completed_workspace_test.rb` | |
| 9.2 | Manual | — | Enter-to-complete from ready state not system-tested |
| 9.3 | Auto | `tender_workspace_test.rb`; `pos_completed_workspace_test.rb` | |
| 9.4 | Partial | `pos_completed_workspace_test.rb` (HTML assertions) | Tendered/change display manual |
| 9.5 | Partial | `pos_receipts_controller_test.rb` | Print from completed workspace manual |
| 9.6 | Partial | `pos_stored_value_issuance_slips_controller_test.rb`; `post_gift_card_sale_ledger_test.rb` | Slip link on completed page manual |
| 9.7 | Manual | — | Gift receipt placeholder visual |
| 9.8 | Partial | `completed_workspace_test.rb` (system, focus); `pos_completed_workspace_test.rb` | Idle landing + command focus manual |
| 9.9 | Auto | `completed_workspace_test.rb` (Enter → new draft) | |
| 9.10 | Manual | — | Required SV slip focus priority not system-tested |
| 9.11 | Partial | `pos_completed_workspace_test.rb` (View summary link in HTML) | Navigation manual |

### §10 Register utilities

| # | Coverage | Test file(s) | Notes |
|---|----------|--------------|-------|
| 10.1 | Partial | `root_command_router_test.rb` (`/close` idle) | Close workflow UI manual |
| 10.2 | Auto | `pos_register_close_test.rb` (suspended warning) | |
| 10.3 | Partial | `root_command_router_test.rb` (`/drawer`) | Modal UX manual |
| 10.4 | Partial | `pos_transaction_route_command_test.rb` (`/cashin` vs `/cash`) | Distinct UX manual |
| 10.5 | Partial | `phase6_pos_polish_integration_test.rb`; `void_transaction_test.rb`; `post_void_inventory_test.rb` | Void from completed workspace manual |

### §11 Keyboard and focus (cross-cutting)

| # | Coverage | Test file(s) | Notes |
|---|----------|--------------|-------|
| 11.1 | Manual | — | Turbo refocus after cart update |
| 11.2 | Manual | — | Modal vs command field focus steal |
| 11.3 | Partial | `modal_drawer_shell_test.rb` (interaction shell fixture) | POS-specific restore paths manual |
| 11.4 | Partial | `modal_drawer_shell_test.rb` (tab trap) | POS settlement/discount modals manual |
| 11.5 | Manual | — | Mouse-only path |
| 11.6 | Manual | — | Touch target sizing |

### §12 Regression smoke (prior phases)

| # | Coverage | Test file(s) | Notes |
|---|----------|--------------|-------|
| 12.1 | Auto | `post_inventory_test.rb`; `phase6_pos_polish_integration_test.rb` | |
| 12.2 | Auto | `post_gift_card_sale_ledger_test.rb`; `phase7b_pos_stored_value_test.rb` | |
| 12.3 | Auto | `post_stored_value_ledger_test.rb`; `phase7b_settlement_integration_test.rb` | |
| 12.4 | Auto | `pos_transaction_discount_modal_test.rb`; `pos_line_discount_workspace_test.rb`; discount service tests | |
| 12.5 | Auto | `pos_tax_exemption_modal_test.rb`; tax recalculator tests | |
| 12.6 | Partial | Phase 7A integration tests | Pickup POS line manual (§7.6) |
| 12.7 | Auto | `phase6_pos_polish_integration_test.rb` (inactive variant confirm) | |

### Key test file index

| File | Primary checklist sections |
|------|---------------------------|
| `test/system/pos/tender_workspace_test.rb` | §8, §9.1, §9.3 |
| `test/system/pos/completed_workspace_test.rb` | §9.8–9.9 |
| `test/system/pos/transaction_discount_modal_test.rb` | §6.7 |
| `test/integration/pos_held_sales_lifecycle_test.rb` | §1.6, §5.3, §5.5–5.7 |
| `test/integration/pos_workspace_landing_test.rb` | §1–§4 (idle/routing) |
| `test/integration/pos_transaction_route_command_test.rb` | §4, §8.1–8.4 |
| `test/integration/pos_completed_workspace_test.rb` | §9.3–9.4, §9.11 |
| `test/services/pos/settlement_sync_test.rb` | §8.7–8.9, §8.19–8.21 |
| `test/services/pos/command_bar_router_test.rb` | §2, §6.4–6.5 |
| `test/services/pos/root_command_router_test.rb` | §2–§4 (idle routing) |
| `test/services/pos/landing_router_test.rb` | §1.1–1.2 |
| `test/services/pos/active_draft_resolver_test.rb` | §1.4–1.8 |
| `test/helpers/pos_helper_test.rb` | §5.6–5.7 (`pos_can_resume_transaction?`) |

---

## Sign-off

| Item | Name | Date |
|------|------|------|
| QA lead | | |
| Browser(s) tested | | |
| Blockers found | | |
| Ready to mark 10-C **Complete** | ☐ Yes ☐ No | |
