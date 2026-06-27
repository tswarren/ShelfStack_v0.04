# Phase 10-C — POS Keyboard Workspace Test Plan

**Status:** Planned

**Spec:** [phase-10c-pos-keyboard-workspace-spec.md](phase-10c-pos-keyboard-workspace-spec.md)

**Roadmap:** [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md)

---

## PR 1 — Workspace shell, landing, draft resolver, intent boundary

| Area | Suggested test location |
| ---- | ----------------------- |
| Landing router | `test/services/pos/landing_router_test.rb` (new) |
| Active draft resolver | `test/services/pos/active_draft_resolver_test.rb` (new) |
| Idle workspace — no silent draft | Integration/system POS landing tests |
| Active draft wins (including empty) | Integration/system POS landing tests |
| Cross-cashier conflict UI | Integration/system POS landing tests |
| Multiple draft candidates → picker | Integration/system POS landing tests |
| Suspended not auto-resumed | Integration/system POS landing tests |

---

## Two-lane parser and intent boundary

| Case | Expected |
| ---- | -------- |
| Bare amount (`20`) from idle | No draft; helpful message |
| Receipt-shaped string from idle | No draft; helpful message |
| Unmatched text from idle | No draft; helpful message |
| SKU/ISBN scan | Lookup/add; draft when line added |
| Scan from idle with carry-forward | Draft created/resumed; item added |

Suggested: extend or replace `Pos::CommandBarRouter` tests → `Pos::CommandRegistry` tests.

---

## Command registry — discounts

| Command | Opens |
| ------- | ----- |
| `/d`, `/ld`, `/linediscount` | Line discount workflow |
| `/dt`, `/di`, `/discount` | Transaction discount workflow |
| `/d` | Must **not** open transaction discount |

---

## Command registry — gift card, tender, cash

| Case | Expected |
| ---- | -------- |
| `/gc 50` from idle | Draft + modal with $50 prefilled; line **not** auto-posted |
| `/cash 20` from idle | No draft; no-active-transaction message |
| `/cashdrop` | Planned/disabled message; no `PosCashMovement` created |
| `/cashin`, `/cashout` | Modal workflow when permitted |

---

## Return, pickup, close

| Case | Expected |
| ---- | -------- |
| Active sale-only draft + `/return` | Return drawer; exchange path allowed |
| Active draft with tender rows + `/return` | Blocked with prompt |
| Active draft + `/close` | Blocked with message |
| `/pickup` | Drawer workflow; draft on fulfillment |

---

## Transactionless with active draft

| Case | Expected |
| ---- | -------- |
| `/balance` with empty active draft | Modal opens; draft unchanged |
| `/session`, `/help` with active draft | Work; draft unchanged |
| Blocked when modal dirty | Implicit close blocked per 10-A shell rules |

---

## Settlement, readiness, line edit

| Area | Suggested test location |
| ---- | ----------------------- |
| Expanded-row line edit | System test — POS cart line edit |
| Settlement modal shell | Integration/system — settlement entry |
| Readiness blockers | Extend `Pos::CompletionReadiness` tests + system |
| `/reports` with active draft | Confirm dialog; same-tab navigate on confirm |

---

## Keyboard and focus

Per [keyboard-and-focus.md](keyboard-and-focus.md) and spec acceptance criteria:

* Command field focus on idle and active workspace load
* Focus after line add
* Modal/drawer trap and restore
* Settlement reachable without function keys
* Touch targets ~44px on expanded row and settlement actions

Suggested: system tests where practical; integration for focus-restore hooks where Stimulus is heavy.

---

## Regression guardrails

* Do not regress Phase 6 completion, void, inventory posting, or tender validation
* Do not regress Phase 7B stored-value tender and gift card sale ledger paths
* Do not regress Phase 8.5 discount and tax recalculation behavior
