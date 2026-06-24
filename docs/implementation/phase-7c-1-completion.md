# Phase 7C-1 Buyback Refinement — Completion Record

Completed: 2026-06-23

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
Buybacks::OpenCustomerDecision
Buybacks::RecordCustomerDecision
Buybacks::AcceptAllLines / DeclineAllLines / DonateDeclinedLines
Buybacks::PricingFieldSync
Buybacks::TradeCreditIssuanceSlipPresenter (PR1)
```

Refactored: `CompleteSession` (decision gate, accepted snapshot derivation, buyback number no longer assigned at completion), `CreateIntakeItem` (defer variant creation), `PriceLine`, `ApplyOfferOverride`, `ApplyPriceOverride`, `RejectLine`.

Removed: `AcceptLine` payout acceptance behavior (deprecated stub).

### UI

Staged session screen sections: Seller, Intake, Work items, Proposal, Customer decision, Payout, Complete/Void.

- Separate cash/trade-credit proposal columns
- Proposal save/print with `buybacks.proposal.*` permissions
- Customer decision per-line and batch actions
- Trade-credit issuance slip (full identifier) vs masked receipt
- Seller edit/customer links

### Permissions

```text
buybacks.proposal.save
buybacks.proposal.print
buybacks.decisions.update
buybacks.decisions.batch_update
buybacks.trade_credit_slip.print
```

### Correctness fixes (PR1)

- Stored-value issue/void `source:` passthrough to buyback session / buyback void
- Void inventory mapping by original ledger `line_number`
- Catalog-without-product intake creates buyback-intake product
- `Format.order(:name)` fallback

## Verification

```bash
docker compose run --rm web bin/rails db:migrate
docker compose run --rm web bin/rails test test/services/buybacks test/controllers/buybacks test/integration/buybacks_staged_workflow_integration_test.rb
```

## Deferred (unchanged)

- Setup CRUD for pricing rules / reject reasons
- External catalog lookup in resolve
- Split payouts, copy-level inventory, customer merge
