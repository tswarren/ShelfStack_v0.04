# Phase 7C Used Buyback Functional Specification

Roadmap summary: [phase-7c-used-buyback.md](../roadmap/phase-7c-used-buyback.md)

Data model: [phase-7c-data-model.md](phase-7c-data-model.md)

Test plan: [phase-7c-test-plan.md](phase-7c-test-plan.md)

---

# 1. Purpose

Used buyback is a separate operational workflow (not a POS return) for evaluating used items, offering cash or trade credit, accepting inventory, and paying sellers.

# 2. Locked decisions

- Graded used variants with existing Phase 3 condition keys
- Dual eligibility: `sub_department.buyback_allowed` AND `product_condition.buyback_eligible`
- Single payout mode per session: `cash`, `trade_credit`, or `no_value_donation`
- Customer required; no anonymous sellers
- Void via `buyback_voids` (separate inventory source from completion)
- Trade-credit redemption at POS: identifier lookup or explicit account selection only

# 3. Services

```text
Buybacks::Eligibility
Buybacks::StartSession
Buybacks::ResolveItem
Buybacks::CreateIntakeItem
Buybacks::FindOrCreateGradedUsedVariant
Buybacks::PriceLine
Buybacks::AcceptLine / RejectLine
Buybacks::CompleteSession
Buybacks::VoidSession
Buybacks::PostVoidInventory
Buybacks::BuybackNumberAssigner
Buybacks::SellerRequirements
Buybacks::ReceiptBuilder
Buybacks::ReportBuilder
```

# 4. Completion

Atomic transaction:

1. Validate seller, payout mode, lines, eligibility
2. Assign `buyback_number`
3. Payout branch (exactly one): cash paid_out, trade_credit issue, or no payout for donation
4. Always post inventory for accepted/donated lines via `Inventory::Post`
5. Snapshot seller; mark completed

# 5. Void

Create `buyback_voids`; reverse inventory (`buyback_void` posting), cash (`paid_in`), and stored value as applicable.

# 6. UI

Workspace at `/buybacks` with session screen, receipt, and register session link for cash payouts.

Trade-credit completion must issue or display identifier for POS redemption.

Full detail: roadmap §7–12.
