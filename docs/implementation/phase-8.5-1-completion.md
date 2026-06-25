# Phase 8.5-1 — Completion Record

Completed: 2026-06-25

## Summary

Phase 8.5-1 introduces structured, auditable, stackable POS discounts while preserving existing cached aggregate fields for register and report compatibility.

Discount applications are the source of truth; `Pos::DiscountRecalculator` rebuilds allocations and cached cents. A legacy bridge preserves pre-application discount behavior when no active applications exist.

## Deliverables

### Schema

```text
discount_reasons
pos_discount_applications
pos_discount_allocations
discountable on departments, sub_departments, products, product_variants
```

### Services

```text
Pos::DiscountEligibilityResolver
Pos::DiscountRecalculator
Pos::DiscountApplicationService
Pos::VoidDiscountApplication
```

### POS UI

* Line and transaction discount forms with reason, note, and authorization support
* Discount detail lists with void/remove before completion
* `/d` and `/dt` command bar shortcuts

### Setup

* Discount reasons CRUD at `/setup/discount_reasons`
* Catalog `discountable` toggles on departments, subdepartments, products, and variants

### Seeds & backfill

* `Seeds::Phase85DiscountReasons` — idempotent reason keys including `legacy_unspecified`
* `Seeds::Phase85Permissions` — `pos.discounts.void`, `setup.discount_reasons.*`
* Backfill migration for historical line and transaction discounts

## Verification

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails test test/models/discount_reason_test.rb test/models/pos_discount_application_test.rb test/models/pos_discount_allocation_test.rb
./dev/rails-docker bin/rails test test/services/pos/discount_eligibility_resolver_test.rb test/services/pos/discount_recalculator_test.rb
./dev/rails-docker bin/rails test test/services/pos/discount_application_service_test.rb test/services/pos/discount_activity_query_test.rb
./dev/rails-docker bin/rails test test/services/pos/recalculate_transaction_test.rb test/services/pos/return_line_pricing_test.rb
./dev/rails-docker bin/rails test test/services/pos/report_transaction_metrics_test.rb
```

## Known gaps / deferred

| Item | Status |
| --- | --- |
| Promotion/coupon/loyalty engines | Future |
| Full discount activity report UI | Future (data model ready) |
| Tax-exempt / tax-override | Phase 8.5 Epic 2 |
| Tender/customer cleanup | Phase 8.5 Epic 3 |

## Related documents

- [phase-8.5-1-pos-discount-spec.md](../specifications/phase-8.5-1-pos-discount-spec.md)
- [phase-8.5-1-data-model.md](../specifications/phase-8.5-1-data-model.md)
- [phase-8.5-1-test-plan.md](../specifications/phase-8.5-1-test-plan.md)
- [phase-8.5-operational-cleanup.md](../roadmap/phase-8.5-operational-cleanup.md)
