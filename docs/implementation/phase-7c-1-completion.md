# Phase 7C-1 Buyback Refinement — Completion Record

Completed: 2026-06-23 (review fixes: 2026-06-24)

Authority: [docs/roadmap/phase-7c-1-buyback-refinement.md](../roadmap/phase-7c-1-buyback-refinement.md)

## Summary

Phase 7C-1 refactors buyback from a resolve→accept→complete shortcut into a staged counter workflow. No irreversible cash, trade-credit, or inventory effects occur before `Buybacks::CompleteSession`.

```text
draft → UpdateProposalLine → SaveProposal (quoted) → RecordCustomerDecision (decision) → payout → CompleteSession (completed)
```

## Deliverables

### Schema (`20250704120000_create_phase7c1_buyback_refinement`)

- `buyback_lines`: `proposed_*`, split override flags/reasons, `base_price_cents`, `base_price_source`, `customer_decision_at`
- `buyback_sessions`: `proposal_saved_at`, `proposal_printed_at`, `customer_decision_at`, `payout_selected_at`, `decision` status
- Migrated line/session statuses and outcomes in place

### Services

```text
Buybacks::UpdateProposalLine
Buybacks::SaveProposal
Buybacks::ProposalBuilder
Buybacks::DecisionTotalsBuilder
Buybacks::OpenCustomerDecision
Buybacks::RecordCustomerDecision
Buybacks::AcceptAllLines / DeclineAllLines / DonateDeclinedLines
Buybacks::RemoveLine
Buybacks::PricingFieldSync
Buybacks::TradeCreditIssuanceSlipPresenter (PR1)
```

Refactored: `CompleteSession` (decision gate, accepted snapshot derivation inside transaction, buyback number no longer assigned at completion), `CreateIntakeItem` (defer variant creation), `PriceLine`, `ApplyOfferOverride`, `ApplyPriceOverride`, `RejectLine`.

Removed: `AcceptLine` payout acceptance behavior and `lines#accept` route.

### UI

Staged session screen sections: Seller, Intake, Work items, Proposal, Customer decision, Payout, Complete/Void.

**Counter UX (guided workflow):**

- `Buybacks::SessionWorkflowPresenter` drives stepper, next-action panel, disabled states, queue summary, and sticky footer
- Seven-step horizontal progress: Seller → Intake → Price items → Proposal → Customer decision → Payout → Complete
- Work items table is read-mostly with status chips, filter chips, and **Work item** drawer for line editing
- Suggested vs proposed pricing layout with conditional override reason fields (`buyback-line-pricing` Stimulus)
- Per-line **Accept / Decline / Donate** buttons (no decision dropdown); batch actions with clearer labels and donate confirmation
- Seller requirements checklist (✓/✗ per field)
- Proposal summary card with print staleness warning
- Payout choice cards (cash / trade credit / no-value donation) with decision-oriented totals
- Scanner-friendly intake: autofocus, `/` and Ctrl+K shortcuts, `N` for next item needing work
- Sticky footer with session totals and primary action

Legacy inline details also retained in drawer partials:

- Separate cash/trade-credit proposal columns
- Proposal save/print with `buybacks.proposal.*` permissions
- Customer decision per-line and batch actions
- Decision-aware payout totals (accepted cash/trade credit, donation/decline/reject counts)
- Trade-credit issuance slip (full identifier) vs masked receipt
- Line removal for draft/intake lines (`destroy`)
- Seller edit/customer links
- Hint when repricing clears a recorded customer decision

### Permissions

```text
buybacks.proposal.save
buybacks.proposal.print
buybacks.decisions.update
buybacks.decisions.batch_update
buybacks.trade_credit_slip.print
```

Mutating controller actions halt on failed `authorize_buyback!` (`return unless` inline; `before_action` helpers on sessions and trade-credit slip).

### Correctness fixes (PR1)

- Stored-value issue/void `source:` passthrough to buyback session / buyback void
- Void inventory mapping by original ledger `line_number`
- Catalog-without-product intake creates buyback-intake product
- `Format.order(:name)` fallback

### Review fixes (post-7C-1)

- **Authorization halting:** `authorize_buyback!` returns `true/false`; mutating actions halt before service calls
- **Donation payout:** donated lines always get `accepted_offer_cents = 0`; cash/trade payout sums only `accepted_by_customer`; `no_value_donation` requires all posting lines donated
- **Atomic completion:** `derive_accepted_snapshots!` runs inside `BuybackSession.transaction` with payout and inventory posting
- **Override enforcement:** `UpdateProposalLine` requires `buybacks.price_override` and reason when proposed values differ from suggested; form exposes override reason fields
- **Trade-credit slip security:** `show` and `print` require `buybacks.trade_credit_slip.print`; full identifier via audited `StoredValue::RevealIdentifier`
- **Terminal store rejection:** `RejectLine` sets `status: decided` for all outcomes including `rejected_by_store`
- **Stale decision clearing:** repricing via `UpdateProposalLine` or `ApplyPriceOverride` clears `outcome` and `customer_decision_at`
- **Resale override base:** `ApplyPriceOverride` sets `base_price_cents` / `manual_resale_price`; `PriceLine` accepts `resale_override_cents`
- **Line removal:** `RemoveLine` service and `lines#destroy` for pending/resolved/priced lines

### Fresh review fixes (2026-06-24)

- **Variant price policy:** `VariantPricePolicy` prevents mutating existing variant `selling_price_cents` when the store has on-hand stock unless the variant was created by the current buyback session; applies in `FindOrCreateGradedUsedVariant` and `PostInventory`
- **Draft-only intake:** new lines and line removal only while `session.draft?`; completion blocks unresolved `pending`/`resolved`/`priced`/`offered` lines without outcomes
- **Batch decisions:** `AcceptAllLines` / `DeclineAllLines` only process `offered` lines; repriced (`priced`) lines must be re-saved via proposal first
- **Override re-save:** `UpdateProposalLine` preserves existing override reasons when values unchanged; form pre-fills reason fields
- **RejectLine guards:** service enforces session editability, blocks posted/voided lines, and restricts outcomes to rejection types only
- **Posting order:** `PostInventory` orders lines by `line_number`

### Pricing note (7C-1 MVP)

`PriceLine` uses fixed base-price precedence on the line: `base_price_cents` → product list price → variant selling price → proposed/suggested values. `BuybackPricingRule#base_price_source` is schema-ready but not yet authoritative; rule-driven base selection is deferred.

## Verification

```bash
docker compose run --rm web bin/rails db:migrate
docker compose run --rm web bin/rails test test/services/buybacks test/controllers/buybacks test/integration/buybacks_staged_workflow_integration_test.rb
```

Full suite (975 tests) green after review fixes.

Key review-fix test files:

```text
test/services/buybacks/complete_session_review_fixes_test.rb
test/services/buybacks/fresh_review_fixes_test.rb
test/services/buybacks/apply_price_override_test.rb
test/presenters/buybacks/session_workflow_presenter_test.rb
test/services/buybacks/seller_requirements_checklist_test.rb
test/controllers/buybacks/trade_credit_issuance_slips_controller_test.rb
test/controllers/buybacks/sessions_print_proposal_test.rb
test/services/buybacks/proposal_builder_test.rb
```

## Phase 7C-2: Printable Buyback Proposal (2026-06-24)

Authority: [docs/phase-7c-2-printed-proposal.md](../phase-7c-2-printed-proposal.md)

Letter-size **Buyback Proposal & Seller Election** print document:

- Dedicated [`app/views/layouts/print.html.erb`](../../app/views/layouts/print.html.erb) (no app chrome)
- Print CSS for US letter in `shelfstack.css` (`.buyback-proposal-print`, `@page buyback-proposal`)
- [`print_proposal`](../../app/controllers/buybacks/sessions_controller.rb) renders structured sections: header, seller verification, offered/not-accepted tables, totals, seller election, unaccepted disposition, signatures, internal-use block
- [`ProposalBuilder`](../../app/services/buybacks/proposal_builder.rb) exposes `offered_lines` and `not_accepted_lines` (totals from offered lines only)
- Print allowed for `quoted`, `decision`, and `completed` sessions; records `proposal_printed_at` and `buyback.proposal.printed` audit

## Deferred (unchanged)

- Setup CRUD for pricing rules / reject reasons
- External catalog lookup in resolve
- Split payouts, copy-level inventory, customer merge
- Rule-driven `base_price_source` in `PriceLine`
