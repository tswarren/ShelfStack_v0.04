# Phase 7C Test Plan

Functional spec: [phase-7c-used-buyback-spec.md](phase-7c-used-buyback-spec.md)

Roadmap §16 and §17 exit criteria apply.

---

# Required coverage

- Customer required; seller fields block completion when missing
- `sub_department.buyback_allowed` and `product_condition.buyback_eligible` gates
- Non-buyback conditions (`new`, `signed_copy`, etc.) rejected
- Intake creates catalog_item, product, variant with `source = buyback_intake`, `needs_review = true`
- Pricing rule precedence; overrides require permission and reason
- Payout branching: cash-only, trade-credit-only, donation-only (never both payouts)
- `buyback_number` assigned at completion from workstation sequence
- Cash movement with `BuybackSession` source
- Trade credit issue with `StoredValueReasonCode` record; identifier for redemption
- Donation: zero cost, `no_value_donation`, no payout records
- Inventory `used_buyback` posting; variant selling price set before post
- Void: `buyback_voids` row; `BuybackVoid` inventory source; negated `used_buyback` lines
- Completion rollback on failure
- Receipt renders `buyback_number` and payout details

# Test files

```text
test/models/buyback_*_test.rb
test/services/buybacks/*_test.rb
test/integration/buybacks_workflow_test.rb
test/support/phase7c_test_helper.rb
```
