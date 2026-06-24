# Phase 7C Test Plan

Functional spec: [phase-7c-used-buyback-spec.md](phase-7c-used-buyback-spec.md)

Workflow refinement: [phase-7c-1-buyback-refinement.md](../roadmap/phase-7c-1-buyback-refinement.md)

Roadmap §16 and §17 exit criteria apply.

---

# Required coverage

- Customer required; seller fields block completion when missing
- `sub_department.buyback_allowed` and `product_condition.buyback_eligible` gates
- Non-buyback conditions (`new`, `signed_copy`, etc.) rejected
- Intake creates catalog_item and product with `source = buyback_intake`, `needs_review = true`; variant deferred to `UpdateProposalLine`
- Pricing rule precedence; overrides require permission and reason; split cash/trade/resale override flags
- Staged workflow: `SaveProposal` rejects unresolved lines; `CompleteSession` requires `decision` status
- `proposed_*` vs `accepted_*` snapshot derivation inside `CompleteSession` transaction per payout mode
- Payout branching: cash, trade credit, donation; mixed accepted+donated posting allowed; donated lines zero cost in all modes
- `no_value_donation` rejects sessions with any `accepted_by_customer` posting line
- Override edits: `UpdateProposalLine` requires `buybacks.price_override` + reason when proposed ≠ suggested
- Store-rejected lines terminal (`decided`) and do not block completion; repricing clears customer decision
- Authorization: unauthorized users cannot mutate via controller; trade-credit slip `show` requires print permission
- Decision-aware payout totals via `DecisionTotalsBuilder`
- Resale override recalculates offers from overridden base (`ApplyPriceOverride` / `resale_override_cents`)
- Sticky footer with session totals and primary action
- Counter UX presenter tests and session show integration coverage
- Line removal for draft/intake lines
- Variant price policy: do not mutate existing variant selling price when store has on-hand stock
- Draft-only line intake; completion blocks unresolved pending/resolved lines
- Batch accept/decline limited to `offered` status; override reasons preserved on re-save
- `RejectLine` enforces session editability; `PostInventory` orders by `line_number`
- `buyback_number` assigned at proposal save from workstation sequence
- Cash movement with `BuybackSession` source
- Trade credit issue with `StoredValueReasonCode` and `source: BuybackSession`; issuance slip vs masked receipt
- Donation: zero cost, `no_value_donation`, no payout records
- Inventory `used_buyback` posting; variant selling price set before post
- Void: `buyback_voids` row; `BuybackVoid` inventory source; negated `used_buyback` lines mapped by ledger `line_number`
- SV void reversal `source: BuybackVoid`
- Completion rollback on failure
- Receipt renders `buyback_number` and payout details

# Test files

```text
test/models/buyback_*_test.rb
test/services/buybacks/*_test.rb
test/services/buybacks/complete_session_review_fixes_test.rb
test/services/buybacks/fresh_review_fixes_test.rb
test/services/buybacks/apply_price_override_test.rb
test/controllers/buybacks/*_test.rb
test/presenters/buybacks/session_workflow_presenter_test.rb
test/services/buybacks/seller_requirements_checklist_test.rb
test/integration/buybacks_staged_workflow_integration_test.rb
test/integration/buybacks_external_lookup_match_test.rb
test/support/phase7c_test_helper.rb
```

## Workflow UX (7C-1 follow-up)

- Proposal revision from `quoted` / `decision` without new session status (`proposal_revision_needed?`, repriced `priced` lines)
- Presenter next-action keys, save/open-decision disabled reasons, stale-print warnings
- Turbo Stream session updates for line mutations and proposal/decision batch actions
- Turbo-frame line detail drawer (`lines#detail`)
- `Buybacks::SelectVariant` service tests
- `Buybacks::LineMatchContext` + Add Item / external lookup return path integration
- `SaveProposal` revision from decision clears `customer_decision_at` and sets `quoted`
