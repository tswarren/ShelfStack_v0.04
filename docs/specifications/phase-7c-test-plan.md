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
- `proposed_*` vs `accepted_*` snapshot derivation at completion per payout mode
- Payout branching: cash, trade credit, donation; mixed accepted+donated posting allowed
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
test/controllers/buybacks/*_test.rb
test/integration/buybacks_staged_workflow_integration_test.rb
test/support/phase7c_test_helper.rb
```
