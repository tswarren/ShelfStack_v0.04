# Phase 4 Completion Record

## Status

Phase 4 Inventory Foundation implemented on branch `phase-4-inventory-foundation`.

## Delivered

- Inventory schema: postings, ledger entries, balances, adjustments, reason codes, locations
- Restored `sub_departments.default_margin_target_bps` for margin-based cost estimation
- Services: `Inventory::Eligibility`, `CostEstimator`, `Post`, `PostAdjustment`, `BalanceUpdater`, `Availability`, `Valuation`, `RebuildBalances`, `BalanceIntegrityCheck`
- Permissions and idempotent seeds for reason codes
- Inventory workspace: store balances, negative exceptions, variant ledger, adjustments draft/post/cancel, enterprise rollup
- Setup CRUD for inventory reason codes and store inventory locations
- Items detail stock availability rollup (on hand for current store)
- Rake tasks: `shelfstack:inventory:rebuild_balances`, `shelfstack:inventory:check_integrity`

## Verification

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails shelfstack:inventory:check_integrity
```

## Deferred (unchanged)

- Purchasing, receiving, POS, transfers, holds, location balances, average cost/COGS, copy-level inventory

## Documentation

- [phase-4-inventory-foundation-spec.md](../specifications/phase-4-inventory-foundation-spec.md)
- [phase-4-data-model.md](../specifications/phase-4-data-model.md)
- [phase-4-test-plan.md](../specifications/phase-4-test-plan.md)
