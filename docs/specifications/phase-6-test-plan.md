# Phase 6 Test Plan

Normative behavior: [phase-6-pos-foundation-spec.md](phase-6-pos-foundation-spec.md)

Data model: [phase-6-data-model.md](phase-6-data-model.md)

---

## Categories

| Category | Focus |
| --- | --- |
| Model tests | Controlled values, associations, uniqueness (transaction number, one open session) |
| Service tests | Lookup, derive type, return qty, tax, discount, tender, post inventory, complete, void |
| Authorization | Full `pos.*` matrix, store scoping, cross-cashier resume |
| Integration | Sale → ledger; return → ledger; exchange mixed lines; void reversal |
| Audit | Register, transaction, void, authorization, receipt events |
| Seeds | Idempotent Phase 6 permissions |

---

## Key scenarios

### Register sessions

1. Open session sets `business_date` and opening cash.
2. Only one open session per workstation.
3. Force-close with permission; warning when suspended txns exist; close succeeds.
4. Reconcile records counted vs expected cash.

### Lookup (`POS::LineLookup`)

5. Exact variant SKU match wins.
6. Product SKU match when variant SKU absent.
7. Catalog identifier (ISBN-13) match when SKUs absent.
8. Normalized barcode input matches identifier.

### Transaction type (`POS::DeriveTransactionType`)

9. All positive variant/open_ring lines → `sale`.
10. All negative → `return`.
11. Mixed signs → `exchange`.
12. Tenders and discounts do not affect derivation.
13. Completion overwrites provisional draft type.

### Sellability

14. Missing subdepartment or tax blocks completion.
15. Inactive variant: warn path (system test) with confirm.
16. `inventory_behavior = non_inventory` completes without ledger lines.
17. Zero price allowed with price prompt flow.

### Tax

18. `ClassificationDefaultsResolver` + `TaxRateLookup` use transaction `business_date`.
19. Line tax rounding; transaction tax sum equals line sum.

### Returns (`POS::ReturnQuantityValidator`)

20. Partial return of receipt line succeeds.
21. Cumulative returns exceeding original sold qty fail.
22. Open-ring return without variant does not post inventory.
23. No-receipt return requires permission and authorization.

### Inventory (`POS::PostInventory`)

24. Completed sale posts `pos_transaction` with `movement_type = sold`.
25. Return with `return_to_stock` posts `customer_return`.
26. Exchange posts both movement types on one posting.
27. Open-ring without variant: no posting.
28. No `inventory_posting_id` on transaction; discover via source.
29. `ensure_eligible!` not invoked for ineligible lines passed to Post.

### Completion

30. Transaction number assigned at completion; format store-workstation-seq.
31. `receipt_number == transaction_number`.
32. Suspended txn completed under new register session uses new `business_date`.
33. Draft shows internal id only (request/system test).

### Tenders (`POS::TenderValidator`)

34. Tender total must equal transaction total.
35. `gift_card` and `store_credit` rejected in Phase 6.
36. Cash refund over threshold requires authorization.

### Void (`POS::VoidTransaction`)

37. Void marks transaction voided without line mutation.
38. Creates `pos_voids` row.
39. Posts `pos_void` with reversal FK to original posting.
40. Reversing tenders link via `reverses_tender_id`.
41. Void of txn without inventory posting creates no reversal posting.

### Permissions

42. `pos.access` gates workspace.
43. Each destructive action checks appropriate `pos.*` key.
44. Store-scoped role denies other stores.

### Reports

45. Sales report reads snapshots, not live variant price.
46. Drawer report reflects session tenders and cash movements.

---

## Test layout

```text
test/models/pos_*
test/services/pos/*
test/integration/pos_*
test/integration/phase6_authorization_test.rb
test/support/phase6_test_helper.rb
```

Suggested service test files:

```text
test/services/pos/line_lookup_test.rb
test/services/pos/derive_transaction_type_test.rb
test/services/pos/return_quantity_validator_test.rb
test/services/pos/post_inventory_test.rb
test/services/pos/tender_validator_test.rb
test/services/pos/complete_transaction_test.rb
test/services/pos/void_transaction_test.rb
test/services/pos/tax_calculator_test.rb
test/services/pos/discount_calculator_test.rb
```

---

## Phase 6 authorization integration test

`test/integration/phase6_authorization_test.rb` should verify:

- Cashier role can complete sale with allowed tenders.
- Cashier cannot void without `pos.transactions.void`.
- Cashier cannot force-close without `pos.register_sessions.force_close`.
- Manager grant path for authorization-backed override.

---

## Audit assertions

For complete, void, and force-close flows, assert audit events exist with:

- `actor_user_id`
- `store_id`
- `workstation_id`
- expected `event_name`

---

## Regression guards

- No direct `inventory_balances` updates from POS code.
- No use of `posting_type` `pos_sale` or `customer_return` in new POS services.
- Completed transaction records remain unchanged after void except status/timestamps.
