# Phase 7A Test Plan

Normative behavior: [phase-7a-customer-demand-spec.md](phase-7a-customer-demand-spec.md)

Data model: [phase-7a-data-model.md](phase-7a-data-model.md)

Roadmap: [phase-7a-customer-demand.md](../roadmap/phase-7a-customer-demand.md)

---

# 1. Test Categories

| Category | Focus |
| --- | --- |
| Model tests | Validations, controlled values, quantity constraints, associations |
| Service tests | Availability math, reservations, allocations, state transitions, concurrency |
| Authorization | `customers.*`, `customer_requests.*`, `special_orders.*`, `inventory_reservations.*`, POS fulfillment permissions; store scoping |
| Request/controller | Customers workspace CRUD, queues, Orders allocation display, POS pickup endpoints |
| Integration | End-to-end workflows A–E; receipt atomicity; void reversal |
| Audit | Lifecycle events per functional spec §17 |
| Seeds | Idempotent Phase 7A permissions |
| Regression | Phase 5 TBO/PO/receipt; Phase 6 POS unchanged for non-reservation sales |

---

# 2. Test Layout

```text
test/models/customer*
test/models/customer_request*
test/models/special_order*
test/models/inventory_reservation*
test/models/purchase_order_line_allocation*
test/models/receipt_line_allocation*
test/models/customer_contact_event*

test/services/customer_requests/header_status_resolver*
test/services/special_orders/*
test/services/inventory_reservations/*
test/services/purchasing/allocate_customer_demand*
test/services/receiving/allocate_customer_demand*
test/services/pos/add_reservation_line*
test/services/pos/complete_reservation_fulfillment*
test/services/pos/reverse_reservation_fulfillment*

test/integration/customers_*
test/integration/phase7a_customer_demand_workflow_test.rb
test/integration/phase7a_pos_pickup_test.rb
test/integration/phase7a_receipt_allocation_test.rb

test/presenters/items/item_operations_presenter_test.rb  (extend)
test/services/inventory/availability_test.rb               (extend)
test/services/inventory/balance_updater_test.rb            (extend)
test/services/inventory/balance_integrity_check_test.rb    (extend)
test/services/inventory/rebuild_balances_test.rb             (extend)
test/services/purchasing/build_purchase_order_test.rb        (extend)
test/services/purchasing/post_receipt_test.rb                (extend)
test/services/purchasing/order_quantity_lookup_test.rb        (extend)

test/support/phase7a_test_helper.rb
db/seeds/phase7a_permissions.rb
```

---

# 3. Key Scenarios

## 3.1 Customers and requests

1. Create customer with required fields; inactivate; block delete when referenced
2. Create request with customer_id; create request with snapshots only (no customer record)
3. Request number assigned `REQ-{store_number}-{sequence}`; unique per store; sequential
4. Multi-line request; line numbers unique per request
5. Provisional line without variant; validation blocks hold/SO until matched
6. Header/line status transitions via `CustomerRequests::TransitionStatus`
7. `HeaderStatusResolver` derives header from lines; manual override limited to terminal statuses
8. Cancel request line; cancelled_quantity updated
9. Mark unfillable with reason; audit events recorded

## 3.2 Matching and research

10. `MatchVariant` sets catalog/product/variant links; status → `matched`
11. Match from Add Item return context preserves request line reference
12. External lookup handoff does not duplicate import pipeline (integration smoke)

## 3.3 Availability and on-hand holds

13. `quantity_available = quantity_on_hand - quantity_reserved` after hold
14. Hold rejected when `quantity_available` insufficient
15. Over-reserve override sets override columns (not pos_authorizations); audit `override_used`
16. Release hold restores available quantity; release_reason controlled value stored
17. Expire job transitions expired holds; releases reserved qty
18. Default `expires_at` = reserved_at + 14 days; staff override respected
19. `Inventory::BalanceUpdater` preserves reserved count on receive/sale posting
20. `RebuildBalances` recomputes reserved and available from reservations
21. `BalanceIntegrityCheck` fails when cached reserved ≠ sum of active reservations
22. `Inventory::Availability.on_order_available` subtracts incoming reserves
23. Concurrent hold attempts: second fails or waits (row lock); no over-reserve without override

## 3.4 Special orders and PO allocations

24. Create special order from matched line; approve
25. Build PO from special orders auto-merges same variant + vendor into one line
26. PO allocation requires `special_order_id`; customer_request_line_id matches when present
27. Multiple allocations on one PO line sum to line quantity
28. TBO + customer on same PO: TBO FK path unchanged; TBO line not merged with customer allocations unless safe
29. Incoming reserve created on order; does not affect `quantity_reserved`
30. PO show presenter displays customer / TBO / stock breakdown
31. Cancel allocation after PO submit requires permission; releases incoming reserve

## 3.5 Receipt allocations

32. Post receipt allocates accepted qty FIFO to open PO allocations
33. Receipt + allocation + reservation conversion in single transaction
34. Rollback on allocation failure leaves receipt draft and inventory unchanged
35. Partial receipt: partial allocation; line → `partially_filled` / SO `partially_received`
36. Incoming reserve converts to `special_order_reserve` or `on_hand_hold`; increments reserved
37. Notify line surfaces in Notify Customer queue on receipt (no auto-hold, no reservation created)
38. Multiple active reservations for one special order handled correctly on partial receipt

## 3.6 Queues and contacts

39. Ready-for-pickup queue includes holds and special orders in ready state
40. Notify Customer queue shows matched notify lines when stock available
41. Expiring-holds queue shows holds within window
42. Contact event created; `last_contacted_at` updated on request
43. Contact requires `customer_requests.contact` permission

## 3.7 POS fulfillment

44. Line lookup returns `quantity_available` and reserved count
45. Sale blocked/warned when on_hand > 0 but available = 0 without reservation context
46. Pickup line validates consistent reservation / special_order / request_line links
47. Pickup sale with reservation link completes; reservation → fulfilled
48. Partial pickup updates fulfilled quantities; line partially_filled until complete
49. Request/special order → completed when fully fulfilled
50. Reserved-stock override requires `pos_authorizations` + permission (distinct from over-reserve)
51. Void partial pickup adjusts fulfilled quantities correctly (§11.5)
52. Void full pickup reverses reservation to `ready`; SO/request → `ready_for_pickup`
53. Void unrelated sale does not touch reservations
54. Customer return of fulfilled item does not reopen special order or request

## 3.8 Store consistency and authorization

55. Store mismatch between request, reservation, PO, receipt, or POS rejected
56. Customers workspace gated by `customers.access`
57. Each mutating action enforces correct permission key
58. Store-scoped user cannot access another store's requests
59. Audit events for create, match, hold, PO attach, receipt allocate, fulfill, void reverse

## 3.9 Regression

60. TBO → PO → receive without customer allocations unchanged
61. Normal POS sale without reservation unchanged
62. Phase 5 PO submit snapshots unchanged

---

# 4. Exit Criteria Mapping

Each roadmap exit criterion maps to tests:

| # | Exit criterion | Primary tests |
| --- | --- | --- |
| 1 | Create/edit lightweight customers | §3.1 scenarios 1–2; customers controller |
| 2 | Create requests with multiple lines | §3.1 scenarios 3–4 |
| 3 | Provisional lines before matching | §3.1 scenario 5 |
| 4 | Match via catalog lookup/import | §3.2 scenarios 10–12 |
| 5 | Convert to hold, incoming reserve, or special order | §3.3, §3.4 scenarios 24–31 |
| 6 | On-hand reservations update reserved/available | §3.3 scenarios 13–14 |
| 7 | Incoming reserves reduce on-order available only | §3.3 scenario 22; §3.4 scenario 29 |
| 8 | Canonical availability service | §3.3 scenarios 13, 19, 22 |
| 9 | Item pages show full availability metrics | ItemOperationsPresenter extend |
| 10 | Customer demand on PO without replacing TBO | §3.4 scenarios 25–28, 60 |
| 11 | PO screens show allocation breakdown | §3.4 scenario 30 |
| 12 | Receipt allocates in same transaction as post | §3.5 scenarios 32–34 |
| 13 | Incoming → on-hand reserve on receive | §3.5 scenarios 36, 38 |
| 14 | Ready-for-pickup queue | §3.6 scenario 39 |
| 15 | Record contact attempts | §3.6 scenarios 42–43 |
| 16 | POS fulfill with links | §3.7 scenarios 46–49 |
| 17 | POS warns on reserved stock | §3.7 scenario 45 |
| 18 | Override requires auth + audit | §3.7 scenario 50 |
| 19 | Void reverses fulfillment | §3.7 scenarios 51–52 |
| 20 | Returns do not reopen request | §3.7 scenario 54 |
| 21 | Rebuild and integrity checks | §3.3 scenarios 20–21 |
| 22 | Permission-controlled and audited | §3.8 |
| 23 | All tests pass | CI green |

---

# 5. Integration Flows (minimum)

## Flow 1 — On-hand hold → POS pickup → void

```text
Create customer → request + hold line → ReserveOnHand
  → ready queue → POS pickup complete → fulfilled
  → void transaction → reservation ready again
```

## Flow 2 — Special order → PO → receipt → pickup

```text
Match variant → special order → build PO with allocation + incoming reserve
  → submit PO → post partial receipt → allocation + reserve conversion
  → ready queue → POS pickup → completed
```

## Flow 3 — Notify → manual hold

```text
Notify line matched → no reservation while waiting
  → receive stock → Notify Customer queue (no auto-hold)
  → staff contacts customer → manual hold → ready queue → POS pickup
```

## Flow 4 — TBO regression

```text
TBO line → build PO via existing path → receive → no allocation rows required
```

---

# 6. Manual QA Checklist

- [ ] Customers nav visible with permission
- [ ] Create request from counter with phone customer (snapshot)
- [ ] ISBN lookup from request line → match → hold
- [ ] Notify line appears in Notify Customer queue after receive (no auto-reserve)
- [ ] Manual hold from notify queue works
- [ ] Item Operations tab shows reserved/available/on-order-available
- [ ] Build PO with two customer orders same ISBN merges to one line
- [ ] Receive flags customer-reserved copies
- [ ] Ready-for-pickup queue actionable
- [ ] POS pickup from queue; receipt shows customer context
- [ ] Attempt sell reserved copy without context → warning + override
- [ ] Void pickup restores ready state
- [ ] Run `rails shelfstack:inventory:rebuild_reservations` on seeded data

---

# 7. Deferred Test Coverage

Not required for Phase 7A exit:

- Automated SMS/email delivery
- Customer deposits / store credit
- Manual receipt allocation UI (non-FIFO)
- Inter-store fulfillment
- Copy-level serialization
- Performance/load tests on queue indexes

---

# 8. Coverage Matrix Location

After implementation, maintain `docs/implementation/phase-7a-test-coverage.md` mapping scenarios to test files (mirror Phase 5 pattern).
