# Phase 7A Completion Record

**Phase:** Customer Demand (7A)  
**Status:** Implemented — UX/QA pending  
**Date:** 2026-06-21

---

## Delivered Scope

Phase 7A implements customer demand workflows: customers, customer requests, special orders, inventory reservations, PO/receipt allocations, ready-for-pickup queues, contact logging, and POS pickup fulfillment.

### New tables

```text
customers
customer_request_sequences
customer_requests
customer_request_lines
special_orders
inventory_reservations
purchase_order_line_allocations
receipt_line_allocations
customer_contact_events
```

### Schema changes

- `inventory_balances.quantity_reserved` — cached on-hand holds
- `quantity_available = quantity_on_hand - quantity_reserved`
- `pos_transactions.customer_id` (nullable)
- `pos_transaction_lines` FKs: `customer_request_line_id`, `special_order_id`, `inventory_reservation_id`

### Workstreams

| Slice | Delivered |
| --- | --- |
| 7A-A | Customers workspace (`/customers`), CRUD, request headers/lines, queues, permissions |
| 7A-B | On-hand holds, `quantity_reserved`, availability/integrity/rebuild extensions, expire job rake task |
| 7A-C | `CustomerRequests::MatchVariant`, catalog search handoff on request show |
| 7A-D | Special orders, create/approve/cancel, request-line conversion |
| 7A-E | PO line allocations, `BuildPurchaseOrder` special-order merge, incoming reserves |
| 7A-F | Receipt allocations atomic with `PostReceipt`, notify queue (no auto-hold) |
| 7A-G | Ready-for-pickup / notify queues, contact events |
| 7A-H | POS reservation lines, fulfillment on complete, void reversal, reserved-stock sell warning |

### Key services

```text
CustomerRequests::Create, AddLine, MatchVariant, HeaderStatusResolver, TransitionStatus, Cancel, MarkUnfillable
SpecialOrders::CreateFromRequestLine, Approve, AttachToPurchaseOrderLine, Cancel
InventoryReservations::ReserveOnHand, ReserveIncoming, ConvertIncomingToOnHand, Release, Expire, FulfillAtPos, ReverseFulfillment, RebuildReservedQuantities
Purchasing::AllocateCustomerDemandToPoLine
Receiving::AllocateCustomerDemandFromReceipt
Pos::AddReservationLine, CompleteReservationFulfillment, ReverseReservationFulfillment
```

Extended: `Inventory::BalanceUpdater`, `Availability`, `RebuildBalances`, `BalanceIntegrityCheck`, `Purchasing::OrderQuantityLookup`, `BuildPurchaseOrder`, `PostReceipt`, `Pos::CompleteTransaction`, `VoidTransaction`, `SellabilityValidator`

### Admin tasks

```text
rails shelfstack:inventory:rebuild_reservations
rails shelfstack:inventory:expire_reservations
```

---

## Verification

```bash
docker compose run --rm web bin/rails db:migrate
docker compose run --rm web bin/rails test
```

Manual smoke:

1. `/customers` — create customer and multi-line request
2. Match line via Items search; create hold or special order
3. Build PO from approved special order; receive; verify ready-for-pickup queue
4. POS pickup via reservation line; void and confirm reservation reopens

---

## Known gaps / deferrals

- Deposits, automated customer notifications, CRM
- Gift-card / store-credit pickup tenders
- Auto-hold / auto-reserve on notify (manual notify queue by design)

## Gap closure (2026-06-21)

Closed in gap-closure pass:

- Orders PO line customer/stock breakdown on purchase order show
- Receiving customer-reserved warnings and posted receipt allocation panel
- POS customer pickup panel, reservation line entry, enriched scan lookup
- POS `sell_reserved_stock_override` supervisor auth via readiness panel
- Add Item wizard match banner/return paths and identify shortcut
- `CustomerRequests::SurfaceNotifyLines` + availability-based notify queue filter
- Solid Queue nightly `InventoryReservations::ExpireJob` (+ rake fallback)
- Customer search trigram indexes on `display_name`, `email`, `phone`

### Correctness pass (post-gap-closure)

- `ConvertIncomingToOnHand` splits incoming reserves on partial receipt so cached `quantity_reserved` stays aligned with active on-hand reservations
- `Pos::ReverseReservationFulfillment` reverses partial pickups when reservation is still `ready`/`active`
- `release_reason` and `customer_contact_events.status` enums aligned with data model spec
- Store/vendor/draft guards on `AttachToPurchaseOrderLine` and store/variant guards on `AllocateCustomerDemandToPoLine`

### UX pass (dashboard)

- `/customers` is a Customer Demand dashboard with operational queue cards, preview rows, and open-request metric
- Request index shows operational columns, multi-field search, and queue nav count badges
- Shared `CustomerRequests::QueueScope`, `SearchQuery`, and `NextActionResolver` services
- Request show uses line workflow cards with per-line next action strip, status trail, sidebar contact panel, and live hold validation

### Final Phase 7A review closure

- Ready-for-pickup queue now uses line/reservation readiness, not only request header status.
- Request show supports multiple active reservations per line.
- Item customer-demand drawer keeps quantity/timing visible for linked customers.
- Receipt allocations link to converted on-hand reservations.
- POS pickup lookup supports snapshot-only customer requests.
- Special-order `quantity_ready` is maintained on pickup fulfillment and void reversal.
- Item drawer hold validation scoped to hold requests; availability synced explicitly on drawer open.
- Request show Ready metric and expiring-hold urgency label aligned with reservation-aware UI.

---

## Documentation

Normative specs:

- [phase-7a-customer-demand-spec.md](../specifications/phase-7a-customer-demand-spec.md)
- [phase-7a-data-model.md](../specifications/phase-7a-data-model.md)
- [phase-7a-test-plan.md](../specifications/phase-7a-test-plan.md)

Roadmap: [phase-7a-customer-demand.md](../roadmap/phase-7a-customer-demand.md)
