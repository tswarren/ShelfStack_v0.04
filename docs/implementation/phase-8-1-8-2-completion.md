# Phase 8-1 / 8-2 — Completion Record

Completed: 2026-06-23

## Summary

Phase 8-1 and 8-2 centralize inventory posting eligibility via `Inventory::TrackingResolver` (value mapping) and `Inventory::Eligibility` (mutation gate). Behavior is unchanged: the same variants post to inventory, buyback, and POS as before.

No schema migrations, UI changes, COGS changes, or receipt-policy changes.

## Deliverables

### Services

```text
Inventory::TrackingResolver   # resolve, inventory?, resolve!, tracking_for_behavior
Inventory::Eligibility        # eligible?, ensure_eligible!, eligible_for_pos_line?
```

### Call site updates

| File | Change |
| --- | --- |
| `app/services/buybacks/eligibility.rb` | Uses `Inventory::Eligibility.eligible?(variant)` |
| `app/services/buybacks/resolve_item.rb` | Same |
| `app/services/pos/post_inventory.rb` | Uses `Inventory::Eligibility.eligible_for_pos_line?(line)` |

### Tests

- `test/services/inventory/tracking_resolver_test.rb` (new)
- `test/services/inventory/eligibility_test.rb` (expanded)
- `test/services/buybacks/eligibility_test.rb` (non-inventory rejection)
- `test/services/pos/post_inventory_test.rb` (snapshot matrix + integration)

## Verification

```bash
bin/rails test test/services/inventory/ test/services/buybacks/eligibility_test.rb test/services/pos/post_inventory_test.rb

rg 'inventory_behavior\s*==\s*["'\'']standard_physical|["'\'']standard_physical["'\'']\s*==\s*.*inventory_behavior' app test
```

38 tests, 63 assertions — all passing.

## Known gaps / deferred

| Item | Status |
| --- | --- |
| `inventory_behavior` column removal | Deferred until explicit scope |
| Non-inventory receipt policy | Separate product decision |
| Full GL export | Phase 9 |

Slices 8-3 through 8-5 completed — see [phase-8-3-4-5-completion.md](phase-8-3-4-5-completion.md).

## Related documents

- [phase-8-inventory-eligibility-and-tracking-refactor.md](../roadmap/phase-8-inventory-eligibility-and-tracking-refactor.md)
- [phase-8-inventory-eligibility-and-tracking-spec.md](../specifications/phase-8-inventory-eligibility-and-tracking-spec.md)
- [phase-8-test-plan.md](../specifications/phase-8-test-plan.md)
