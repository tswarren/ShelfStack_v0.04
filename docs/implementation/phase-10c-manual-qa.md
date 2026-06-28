# Phase 10-C — Manual QA Checklist

**Branch:** `phase-10c-pos-keyboard-workspace` (or after merge to `main`)

**Spec:** [phase-10c-pos-keyboard-workspace-spec.md](../specifications/phase-10c-pos-keyboard-workspace-spec.md)

**Completion record:** [phase-10c-completion.md](phase-10c-completion.md)

**Runbook:** [foundation-runbook.md](../operations/foundation-runbook.md#pos-register-operations-phase-6--phase-10-c)

Use this checklist before marking Phase 10-C **Complete**. Test on a **register workstation** with at least two roles: **pos_cashier** and **pos_lead** or **pos_manager**.

**Suggested browsers:** Chrome plus one of Safari or Firefox (keyboard/focus behavior differs).

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

## Sign-off

| Item | Name | Date |
|------|------|------|
| QA lead | | |
| Browser(s) tested | | |
| Blockers found | | |
| Ready to mark 10-C **Complete** | ☐ Yes ☐ No | |
