# Phase 8 Inventory Eligibility and Tracking — Test Plan

Functional spec: [phase-8-inventory-eligibility-and-tracking-spec.md](phase-8-inventory-eligibility-and-tracking-spec.md)

Roadmap: [phase-8-inventory-eligibility-and-tracking-refactor.md](../roadmap/phase-8-inventory-eligibility-and-tracking-refactor.md)

---

# 1. Scope

Phase 8-1 and 8-2 tests. No schema, UI, or COGS tests in this slice.

# 2. Resolver tests

File: `test/services/inventory/tracking_resolver_test.rb`

| Case | Expected |
| --- | --- |
| `standard_physical` variant | `inventory` |
| Each other `INVENTORY_BEHAVIORS` value | `non_inventory` |
| `"standard_physical"` string | `inventory` |
| `"inventory"` / `"non_inventory"` strings | respective tracking |
| `nil` with `inventory?` | `non_inventory` (fail-closed) |
| `nil` with `resolve!` | raises |
| unknown string with `inventory?` | `non_inventory` |
| unknown string with `resolve!` | raises |

# 3. Eligibility tests

File: `test/services/inventory/eligibility_test.rb`

| Case | Expected |
| --- | --- |
| `standard_physical` variant | eligible |
| Each non-`standard_physical` behavior | not eligible |
| `ensure_eligible!` message | includes tracking + `inventory_behavior` |
| POS line: inventory snapshot, non-inventory variant | eligible (snapshot wins) |
| POS line: blank snapshot, inventory variant | eligible |
| POS line: non-inventory snapshot, inventory variant | not eligible |

# 4. Buyback tests

File: `test/services/buybacks/eligibility_test.rb`

| Case | Expected |
| --- | --- |
| eligible variant + condition + subdepartment | passes |
| `buyback_allowed: false` | rejected |
| `inventory_behavior: non_inventory` | rejected |

# 5. POS posting tests

File: `test/services/pos/post_inventory_test.rb`

| Case | Expected |
| --- | --- |
| snapshot `standard_physical` | `eligible_line?` true |
| snapshot `non_inventory` | false |
| snapshot `digital_asset` | false |
| no snapshot, variant `standard_physical` | true |
| no snapshot, variant `non_inventory` | false |
| return-to-stock + inventory snapshot | true |
| return without return-to-stock disposition | false |
| non-inventory variant completes sale | no inventory posting |

# 6. Regression

Run:

```bash
bin/rails test test/services/inventory/ test/services/buybacks/ test/services/pos/post_inventory_test.rb
```

Existing receipt, RTV, adjustment, and buyback integration tests must pass unchanged.

# 7. Grep verification

No direct eligibility comparisons outside resolver/eligibility:

```bash
rg 'inventory_behavior\s*==\s*["'\'']standard_physical|["'\'']standard_physical["'\'']\s*==\s*.*inventory_behavior' app test
```

Allowed references: `TrackingResolver`, `InventoryBehaviorMapper`, snapshot writers, tests, docs, seeds.

---

# 8. Slice 8-3 tests

| File | Cases |
| --- | --- |
| `tracking_resolver_test.rb` | override chain, product default, product_type fallback, product default change isolation |
| `inventory_tracking_mapper_test.rb` | product_type → tracking |
| Rake tasks | backfill DRY_RUN, mixed products, conflicts |

# 9. Slice 8-4 tests

| File | Cases |
| --- | --- |
| `inventory_tracking_sync_test.rb` | inventory/non-inventory sync, legacy edit clears override, preview |
| `source_hint_test.rb` | acquisition only, ignores sold, trade-in fallback |
| `eligibility_test.rb` | `inventory_tracking_snapshot` read order |
| `items_product_variants_controller_test.rb` | tracking selection update |

# 10. Slice 8-5 tests

| File | Cases |
| --- | --- |
| `line_cogs_calculator_test.rb` | pre-sale MA, non-inventory null, return reversal, blind return, open-ring |
| `complete_transaction_cogs_test.rb` | tracking + COGS snapshots at completion |
| `operational_margin_report_test.rb` | margin totals, void exclusion |
| `balance_updater_test.rb` | buyback_offer MAC |

# 11. Full regression

```bash
bin/rails test test/services/inventory/ test/services/items/ test/services/pos/line_cogs_calculator_test.rb test/services/pos/complete_transaction_cogs_test.rb test/services/pos/operational_margin_report_test.rb test/integration/items_product_variants_controller_test.rb test/integration/pos_reports_controller_test.rb
```
