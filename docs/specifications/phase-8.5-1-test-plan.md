# Phase 8.5-1 POS Discount Model & Calculation — Test Plan

Functional spec: [phase-8.5-1-pos-discount-spec.md](phase-8.5-1-pos-discount-spec.md)

Data model: [phase-8.5-1-data-model.md](phase-8.5-1-data-model.md)

Roadmap: [phase-8.5-1-pos-discount-mdel](../roadmap/phase-8.5-1-pos-discount-mdel)

---

# 1. Scope

Phase 8.5-1 tests cover discount reasons, applications, allocations, eligibility, recalculation (including legacy bridge), POS UI/controller flows, and report regression.

---

# 2. Model tests

## 2.1 `DiscountReason`

File: `test/models/discount_reason_test.rb`

| Case | Expected |
| --- | --- |
| missing `reason_key` | invalid |
| missing `name` | invalid |
| duplicate `reason_key` | invalid |
| key normalization | lowercase snake_case |
| inactive reason | not selectable for new manual discount via service |
| reason requiring note | service enforces note |

## 2.2 `PosDiscountApplication`

File: `test/models/pos_discount_application_test.rb`

| Case | Expected |
| --- | --- |
| missing transaction | invalid |
| line scope without line | invalid |
| transaction scope with line id | invalid per model rules |
| amount method without `entered_amount_cents` | invalid |
| percent method without `entered_percent_bps` | invalid |
| price override without `target_price_cents` | invalid |
| missing `discount_reason_id` | invalid (all sources) |
| completed transaction mutation | rejected |

## 2.3 `PosDiscountAllocation`

File: `test/models/pos_discount_allocation_test.rb`

| Case | Expected |
| --- | --- |
| allocation line on different transaction | invalid |
| negative `allocated_discount_cents` | invalid |
| negative `allocation_base_cents` | invalid |

---

# 3. Service tests — eligibility

File: `test/services/pos/discount_eligibility_resolver_test.rb`

| Scenario | Expected |
| --- | --- |
| normal variant line | discountable |
| gift card sale line | not discountable |
| return line | not discountable |
| department non-discountable | not discountable |
| subdepartment non-discountable | not discountable |
| product non-discountable | not discountable |
| variant non-discountable | not discountable |
| open-ring line in discountable subdepartment | discountable |
| open-ring line in non-discountable subdepartment | not discountable |

---

# 4. Service tests — recalculator

File: `test/services/pos/discount_recalculator_test.rb`

| Scenario | Expected |
| --- | --- |
| one line amount discount | line discount cache updated |
| one line percent discount | line discount cache updated |
| two stacked line discounts | second applies to remaining amount |
| transaction amount discount | allocated across eligible lines |
| transaction percent discount | allocated across eligible subtotal |
| transaction discount with gift card line | gift card receives zero allocation |
| transaction discount with non-discountable line | non-discountable line receives zero allocation |
| transaction discount with rounding remainder | total allocations equal application amount |
| discount exceeds eligible subtotal | capped |
| void one discount in stack | remaining allocations recalculate |
| allocation snapshots written | text snapshot columns populated |
| zero active applications | legacy bridge delegates to `Pos::DiscountCalculator` |

---

# 5. Service tests — application

File: `test/services/pos/discount_application_service_test.rb`

| Case | Expected |
| --- | --- |
| inactive reason | rejected |
| reason requires note, blank note | rejected |
| reason requires authorization, missing auth | rejected |
| valid application | creates application, invokes recalculator |
| stack order assignment | sequential per transaction |

---

# 6. Controller / UI tests

File: `test/integration/pos_discounts_controller_test.rb` (or equivalent)

| Case | Expected |
| --- | --- |
| `/d` command | routes to previous-line discount workflow |
| `/dt` command | opens transaction discount workflow |
| line discount without reason | rejected |
| transaction discount without reason | rejected |
| reason requiring note, blank note | rejected |
| reason requiring authorization, missing auth | rejected |
| gift card line discount attempt | friendly error |
| non-discountable line discount attempt | friendly error |
| void discount | totals update; requires `pos.discounts.void` |

---

# 7. Permission tests

| Permission | Case | Expected |
| --- | --- | --- |
| `pos.discounts.line.apply` | missing on line discount | forbidden |
| `pos.discounts.transaction.apply` | missing on transaction discount | forbidden |
| `pos.discounts.override_limit` | threshold override without permission | rejected |
| `pos.discounts.void` | void without permission | forbidden |
| `setup.discount_reasons.*` | reason admin CRUD | enforced in Setup |

---

# 8. Regression tests

Preserve current report and recalculation behavior:

| Case | Expected |
| --- | --- |
| `line_discount_cents` | still feeds line discount metrics |
| `transaction_discount_cents` | still feeds order/transaction discount metrics |
| `extended_price_cents` | reflects net line amount after discounts |
| tax calculation | runs after discounts |
| completed transactions | discount records immutable |
| transaction with no applications | `Pos::DiscountCalculator` path unchanged |

Files: extend `test/services/pos/discount_calculator_test.rb`, `test/services/pos/recalculate_transaction_test.rb`, `test/integration/pos_reports_controller_test.rb` as needed.

---

# 9. Backfill tests

File: `test/tasks/phase_8_5_1_discount_backfill_test.rb` (or migration test)

| Case | Expected |
| --- | --- |
| line with `line_discount_cents > 0` | legacy application + allocation |
| transaction with `transaction_discount_cents` sum > 0 | legacy application + per-line allocations |
| `legacy_unspecified` reason | used for all backfill rows |
| historical totals | unchanged after backfill |

---

# 10. Full regression

```bash
bin/rails test test/models/discount_reason_test.rb test/models/pos_discount_application_test.rb test/models/pos_discount_allocation_test.rb test/services/pos/discount_eligibility_resolver_test.rb test/services/pos/discount_recalculator_test.rb test/services/pos/discount_application_service_test.rb test/services/pos/discount_calculator_test.rb test/services/pos/recalculate_transaction_test.rb test/integration/pos_discounts_controller_test.rb
```

Existing POS completion, void, and report integration tests must pass unchanged.
