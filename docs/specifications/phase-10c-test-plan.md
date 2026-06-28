# Phase 10-C — POS Keyboard Workspace Test Plan

**Status:** Delivered on integration branch — see [phase-10c-completion.md](../implementation/phase-10c-completion.md)

**Manual QA coverage map:** [phase-10c-manual-qa.md#automated-coverage-map](../implementation/phase-10c-manual-qa.md#automated-coverage-map)

**Spec:** [phase-10c-pos-keyboard-workspace-spec.md](phase-10c-pos-keyboard-workspace-spec.md)

**Roadmap:** [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md)

**Slice 9A:** [phase-10c-9a-transaction-discount-modal.md](../roadmap/phase-10c-9a-transaction-discount-modal.md)

**Slice 9B:** [phase-10c-9b-tender-workspace-and-completion.md](../roadmap/phase-10c-9b-tender-workspace-and-completion.md)

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
| Draft stamping at create | New draft from idle/command sets `pos_register_session_id`, `business_date`, `user_session_id`, workstation, cashier |
| Legacy nil-session draft | Pre-10-C draft without register session → conflict/fallback path; not silent session adoption |

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
| `/gc 50` from idle | Draft + gift card sale line for $50; command focus returns |
| `/gc` from idle | Draft + amount panel; focus amount field |
| `/gc 50` on active transaction | Gift card sale line added; command focus returns |
| `/cash 20` from idle | No draft; no-active-transaction message |
| `/cashdrop` | Planned/disabled message; no `PosCashMovement` created |
| `/cashin`, `/cashout` | Modal workflow when permitted; Escape dismisses modal |
| `/session`, `/reports`, `/close`, `/drawer` | Per slice 7 utility command tests |

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
| Transaction discount modal (slice 9A) | See [phase-10c-9a-transaction-discount-modal.md](../roadmap/phase-10c-9a-transaction-discount-modal.md#suggested-tests) |
| Tender workspace UX (slice 9B) | See [phase-10c-9b-tender-workspace-and-completion.md](../roadmap/phase-10c-9b-tender-workspace-and-completion.md#suggested-tests) |
| Readiness blockers | Extend `Pos::CompletionReadiness` tests + system |
| `/reports` with active draft | Confirm dialog; same-tab navigate on confirm |

---

## Keyboard and focus

Per [keyboard-and-focus.md](keyboard-and-focus.md) and spec acceptance criteria:

* Command field focus after workspace Turbo updates when no blocking panel/modal is open
* Open gift card amount panel, cash movement modal, and help modal skip command focus until closed
* Modal/drawer trap and restore
* Settlement reachable without function keys
* Touch targets ~44px on expanded row and settlement actions

Suggested: system tests where practical; integration for focus-restore hooks where Stimulus is heavy.

---

## Slice 11 — Workspace layout cleanup

| Area | Test file(s) |
| ---- | ------------ |
| Header actions presenter | `test/presenters/pos/header_actions_presenter_test.rb` |
| Tax/totals/cart display helpers | `test/helpers/pos_workspace_display_test.rb` |
| Shared workspace header | `test/integration/pos_workspace_header_test.rb` |
| Customer attach/detach | `test/integration/pos_customer_workspace_test.rb` |
| Status panel (discount/tax) | `test/integration/pos_status_panel_test.rb` |
| Receipt return path | `test/integration/pos_receipt_return_path_test.rb` |
| Layout / flash / Complete CTA | `test/system/pos/workspace_layout_test.rb` |
| Balance without register | `test/services/pos/command_registry_test.rb` (balance availability) |

Manual QA: [phase-10c-manual-qa.md](../implementation/phase-10c-manual-qa.md) — section **10-C-11 Workspace layout**.

---

## Regression guardrails

* Do not regress Phase 6 completion, void, inventory posting, or tender validation
* Do not regress Phase 7B stored-value tender and gift card sale ledger paths
* Do not regress Phase 8.5 discount and tax recalculation behavior
