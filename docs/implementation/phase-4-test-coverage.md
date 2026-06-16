# Phase 4 Test Coverage Matrix

## Purpose

This document maps Phase 4 test plan areas to implemented automated tests. It supports the [Phase 4 completion record](phase-4-completion.md).

Normative test requirements: [../specifications/phase-4-test-plan.md](../specifications/phase-4-test-plan.md).

**Current suite:** 363 tests, 1221 assertions (Minitest).

---

## Coverage Summary

| Area | Coverage |
| ---- | -------- |
| Model validations | Covered |
| Eligibility and cost estimation | Covered |
| Posting and balance updates | Covered |
| Adjustment lifecycle | Covered |
| Authorization (inventory + setup) | Covered |
| Read surfaces (index, ledger, admin) | Partial |
| Audit events | Covered |
| Seed idempotency | Covered |
| Rake tasks | Covered |
| Enterprise / negative exceptions UI | Partial (authorization only) |

---

## Test Files

| File | Focus |
| ---- | ----- |
| `test/models/inventory_reason_code_test.rb` | Reason key and name uniqueness |
| `test/models/inventory_location_test.rb` | Per-store short name uniqueness |
| `test/models/inventory_adjustment_test.rb` | Types, status immutability |
| `test/models/inventory_adjustment_line_test.rb` | Inactive FK guards, line numbers |
| `test/models/inventory_balance_test.rb` | Store + variant uniqueness |
| `test/services/inventory/eligibility_test.rb` | `standard_physical` gate |
| `test/services/inventory/cost_estimator_test.rb` | Manual, margin, unknown cost |
| `test/services/inventory/post_test.rb` | Atomic post, idempotency, negative on hand |
| `test/services/inventory/post_adjustment_test.rb` | Multi-line, balance correction movement |
| `test/services/inventory/balance_updater_test.rb` | Negative and cleared-negative audit |
| `test/services/inventory/rebuild_balances_test.rb` | Rebuild from ledger |
| `test/services/inventory/balance_integrity_check_test.rb` | Mismatch detection |
| `test/services/inventory/availability_test.rb` | Eligibility-aware availability and product rollup |
| `test/services/inventory/balances_query_test.rb` | Pagination and search |
| `test/services/inventory/variant_lookup_test.rb` | SKU lookup |
| `test/services/inventory/admin_task_authorization_test.rb` | Rake permission gate |
| `test/integration/inventory_adjustments_integration_test.rb` | Draft/post/cancel, multi-line, show |
| `test/integration/inventory_balances_controller_test.rb` | Index columns and shortcuts |
| `test/integration/inventory_admin_controller_test.rb` | Rebuild and integrity check UI |
| `test/integration/inventory_variant_lookups_controller_test.rb` | Lookup endpoint |
| `test/integration/phase4_authorization_test.rb` | Permission matrix and store scoping |
| `test/integration/setup_inventory_reason_codes_controller_test.rb` | Setup create + audit |
| `test/integration/setup_inventory_locations_controller_test.rb` | Setup create + audit |
| `test/tasks/inventory_rake_test.rb` | Rebuild and integrity rake tasks |
| `test/models/seed_test.rb` | Phase 4 seed idempotency |

---

## Phase 4 Test Plan Mapping

### Sections 2–3: Reason codes and locations

| Test plan topic | Status | Notes |
| --------------- | ------ | ----- |
| Create with audit | Covered | Setup integration tests |
| Uniqueness | Covered | Model tests |
| Inactive FK guards | Covered | `inventory_adjustment_line_test` |

### Sections 4–10: Adjustments, eligibility, posting

| Test plan topic | Status | Notes |
| --------------- | ------ | ----- |
| Draft/post/cancel | Covered | Integration + model tests |
| Multi-line adjustment | Covered | `post_adjustment_test`, integration |
| Eligibility rejection | Covered | `post_test`, `eligibility_test` |
| Cost estimation | Covered | `cost_estimator_test` |
| Balance integrity | Covered | `balance_integrity_check_test`, rake test |

### Section 11: Authorization

| Test plan topic | Status | Notes |
| --------------- | ------ | ----- |
| Inventory access | Covered | `phase4_authorization_test` |
| Per-permission gates | Covered | `phase4_authorization_test` |
| Store scoping | Covered | `phase4_authorization_test` |
| Admin rebuild | Covered | `admin_controller_test`, rake test |

### Sections 12–15: Audit, read surfaces, integrity, seeds

| Test plan topic | Status | Notes |
| --------------- | ------ | ----- |
| Adjustment lifecycle audit | Covered | Integration tests |
| Negative balance audit | Covered | `balance_updater_test` |
| Integrity/rebuild audit | Covered | Service and rake tests |
| Store index | Covered | `inventory_balances_controller_test` |
| Items integration | Partial | Via `availability_test`; no dedicated Items controller test |
| Seed idempotency | Covered | `seed_test` |

---

## Regression Gaps (acceptable for Phase 4 sign-off)

- Dedicated controller tests for negative exceptions and enterprise rollup content
- System/browser (Capybara) flows for multi-line Stimulus form
- Full setup CRUD matrix (inactivate, reactivate, delete) for inventory setup resources
