Here is a paste-ready draft for:
**Phase 7A: Customer Demand — Customer Requests, Special Orders, Holds, and Reservations**

**Purpose**

Phase 7A establishes customer demand workflows for ShelfStack.

It answers:

> What does a customer want, what are we doing about it, has it been researched, ordered, reserved, received, made ready for pickup, or completed at POS?

Phase 7A is the first slice of Phase 7. It focuses on customer-facing operational demand before later Phase 7 work such as transfers, cycle counts, buybacks, consignment, and damaged inventory workflows.

Customer demand connects directly to existing ShelfStack foundations:

```text
Catalog Item
  -> Product
  -> Product Variant
  -> Customer Request
  -> Special Order / Reservation
  -> Purchase Order Allocation
  -> Receipt Allocation
  -> Ready for Pickup
  -> POS Fulfillment
```

Phase 7A should make purchasing, receiving, inventory, and POS more useful by allowing staff to tie store activity to specific customer demand.

---

**Core Design Principles**

Customer demand should be a first-class operational workflow.

A customer request may begin before the item has been fully matched to a catalog item, product, or product variant. This supports real bookstore workflows where staff may start with only an ISBN, title, author, description, customer note, or phone request.

However, inventory reservations, special-order fulfillment, purchase-order allocation, receipt allocation, and POS fulfillment should operate at the `product_variant` level once the item is matched.

Reservations do **not** create inventory ledger entries.

Inventory still enters or leaves stock only through existing source-document posting workflows:

```text
Receipt
  -> Purchasing::PostReceipt
  -> Inventory::Post
  -> inventory_postings
  -> inventory_ledger_entries
  -> inventory_balances

POS Transaction
  -> Pos::CompleteTransaction
  -> Inventory::Post
  -> inventory_postings
  -> inventory_ledger_entries
  -> inventory_balances

POS Void
  -> Pos::VoidTransaction
  -> Inventory::Post
  -> inventory_postings reversal
  -> inventory_balances
```

Customer demand affects availability, not physical inventory quantity.

Phase 7A changes the meaning of available quantity from:

```text
quantity_available = quantity_on_hand
```

to:

```text
quantity_available = quantity_on_hand - quantity_reserved
```

Only active on-hand reservations should affect `quantity_reserved`.

Incoming reserves should affect on-order availability, not current on-hand availability.

Customer-backed purchasing should use allocation records rather than adding direct customer foreign keys to `purchase_order_lines` or `receipt_lines`.

Existing internal TBO behavior should remain intact. Phase 7A should not migrate existing purchase request / TBO behavior to allocations unless a later refactor justifies it.

---

**Major Capabilities**

Phase 7A includes:

```text
customer records
customer request headers
customer request lines
provisional requested-item capture
customer request research workflow
catalog/product/variant matching from requests
special orders
on-hand holds
incoming reserves
special-order reserves
reserved quantity
availability calculation changes
purchase order line allocations for customer-backed demand
receipt line allocations for customer-backed received quantity
ready-for-pickup queue
customer contact events
customer demand visibility on item/variant pages
customer allocation visibility on PO and receiving screens
POS pickup fulfillment
reserved-stock POS warnings and overrides
POS void reversal behavior for fulfilled reservations
customer request audit events
customer demand permissions
```

---

**Customer Records**

Phase 7A should introduce lightweight customer records.

This is not a full CRM phase.

Customer records should support routine bookseller workflows:

```text
look up customer
record customer name
record phone/email
record preferred contact method
see open requests
see active holds
see ready-for-pickup items
see recent contact history
```

Customer records should be sufficient for holds, special orders, notifications, and POS pickup context.

Deferred customer capabilities include loyalty, marketing preferences, customer account balances, store credit ledgers, and web portal access.

---

**Customer Requests**

A `customer_request` is the broad record of customer intent.

Examples:

```text
customer wants a book not currently in stock
customer asks staff to research availability
customer wants to be notified when an item is available
customer asks staff to special order a title
customer asks staff to hold an on-hand copy
```

Suggested header statuses:

```text
new
researching
awaiting_customer_response
approved_to_order
ordered
partially_filled
ready_for_pickup
completed
cancelled
unfillable
```

A customer request should have one or more request lines.

A request line may begin as provisional information:

```text
provisional_title
provisional_creator
provisional_identifier
provisional_format
customer_notes
```

Once matched, the request line may link to:

```text
catalog_item_id
product_id
product_variant_id
```

Request lines should support different demand types:

```text
research
notify
hold
special_order
```

Suggested line statuses:

```text
new
researching
matched
awaiting_customer_response
approved
ordered
partially_filled
ready_for_pickup
completed
cancelled
unfillable
```

A customer request should have a store-scoped, human-friendly `request_number`.

Suggested format:

```text
REQ-{store_number}-{sequence}
```

The exact format may follow ShelfStack’s existing numbering conventions, but it should be readable at the counter and over the phone.

---

**Research and Matching**

Customer request research should reuse existing catalog lookup and add-item behavior.

Phase 7A should not introduce a separate external catalog import workflow.

Expected flow:

```text
Customer request line
  -> staff enters ISBN / title / author / description
  -> staff searches existing catalog/product/variant records
  -> staff may use existing external catalog lookup/import path
  -> staff matches or creates catalog item/product/variant
  -> request line becomes variant-backed
```

Once a request line is matched to a variant, it may be converted into a hold, notification request, special order, or purchase allocation.

---

**Special Orders**

A `special_order` is a customer-backed commitment to obtain or assign stock for a customer.

A special order is not a purchase order and should not duplicate PO behavior.

It is a thin commitment record connecting customer demand to purchasing, receiving, reservation, and POS fulfillment.

A special order may link to:

```text
customer
customer_request_line
product_variant
vendor
purchase_order_line_allocation
receipt_line_allocation
inventory_reservation
pos_transaction_line
```

Suggested statuses:

```text
pending_match
approved
ordered
partially_received
ready_for_pickup
completed
cancelled
unfillable
```

Special orders should be variant-level before ordering or fulfillment. A customer request can be provisional, but a committed special order should be matched to a product variant as early as possible.

---

**Holds and Reservations**

Phase 7A should use a unified reservation model rather than a standalone `holds` table.

Recommended table:

```text
inventory_reservations
```

User-facing labels may still say “hold” or “reserve,” but the underlying model should support multiple reservation types.

Reservation types:

```text
on_hand_hold
incoming_reserve
special_order_reserve
```

Definitions:

| Type                    | Meaning                                                         | Affects `quantity_reserved`? |
| ----------------------- | --------------------------------------------------------------- | ---------------------------- |
| `on_hand_hold`          | A physically available copy is being held for a customer        | Yes                          |
| `incoming_reserve`      | An expected PO/receipt quantity is reserved for customer demand | No                           |
| `special_order_reserve` | Received or on-hand quantity is assigned to a special order     | Yes                          |

Suggested reservation statuses:

```text
active
ready
fulfilled
released
expired
cancelled
```

Reservations should track quantities:

```text
quantity_reserved
quantity_fulfilled
quantity_released
```

A reservation may link to:

```text
customer
customer_request_line
special_order
product_variant
purchase_order_line
receipt_line
pos_transaction_line
```

Reservations do not mutate inventory ledger entries.

They affect availability only.

---

**Availability and Reserved Quantity**

Phase 7A should add reserved quantity to the authoritative inventory balance model.

Recommended change:

```text
inventory_balances.quantity_reserved
```

Availability formulas:

```text
quantity_on_hand = physical stock according to inventory ledger

quantity_reserved = active on-hand reservations

quantity_available = quantity_on_hand - quantity_reserved
```

On-order formulas:

```text
on_order = open purchase order quantity not yet received or cancelled

reserved_incoming = active incoming reservations tied to open purchase order quantity

on_order_available = on_order - reserved_incoming
```

Example display:

```text
On hand: 3
Reserved: 1
Available: 2
On order: 5
Reserved incoming: 2
On order available: 3
```

`Inventory::Availability` should become the canonical source for availability reads.

POS, item pages, customer request screens, and order screens should not independently recalculate availability.

---

**Inventory Balance and Integrity Services**

Phase 7A must update existing inventory balance services rather than adding isolated reservation-only logic.

Expected service changes:

```text
Inventory::BalanceUpdater
Inventory::Availability
Inventory::RebuildBalances
Inventory::BalanceIntegrityCheck
Items::ItemOperationsPresenter
Purchasing::OrderQuantityLookup
```

`Inventory::BalanceUpdater` should preserve or recompute reservation-aware availability when inventory postings occur.

`Inventory::RebuildBalances` should rebuild physical on-hand and valuation from ledger entries, then recompute reserved and available quantities from active reservations.

`Inventory::BalanceIntegrityCheck` should verify:

```text
quantity_on_hand = SUM(inventory_ledger_entries.quantity_delta)

quantity_reserved = SUM(active on-hand reservation open quantity)

quantity_available = quantity_on_hand - quantity_reserved
```

A reservation rebuild task may be added, but it should be specified as part of the inventory balance integrity model rather than as an unrelated helper.

Suggested task:

```text
rails shelfstack:inventory:rebuild_reservations
```

or equivalent service-backed task.

---

**Negative On-Hand and Over-Reservation**

Phase 4 allows negative on-hand inventory.

Phase 7A should define clear reservation rules for edge cases.

Default rule:

```text
Staff may not create an on-hand hold unless quantity_available > 0.
```

If the store wants to override this:

```text
manager authorization required
reservation is marked as over_reserved
audit event recorded
```

Incoming reserves may be created even when current on-hand is zero or negative, because they are claims against expected supply, not current physical stock.

Special-order reserves should not increment `quantity_reserved` until stock is actually available or received.

---

**Purchase Order Allocations**

Customer-backed demand should use allocation records.

Recommended table:

```text
purchase_order_line_allocations
```

A purchase order line allocation connects some portion of a PO line to customer demand.

This supports consolidated purchasing:

```text
PO line: 8 copies ordered
  -> 2 copies for Customer A
  -> 1 copy for Customer B
  -> 5 copies for shelf stock
```

Phase 7A should not add a direct `customer_id` or `customer_request_line_id` to `purchase_order_lines`.

PO lines should remain vendor/source documents.

Allocation records should explain why some portion of a PO line exists.

Internal TBO should keep its existing Phase 5 path.

Phase 7A should support three PO-build sources:

```text
manual stock lines
internal TBO / purchase request lines
customer-backed special-order allocations
```

`Purchasing::BuildPurchaseOrder` should be extended carefully so customer-backed demand can merge into draft PO lines without breaking existing TBO behavior.

PO screens should show:

```text
ordered quantity
received quantity
customer allocated quantity
internal TBO quantity
stock/unallocated quantity
```

---

**Receipt Allocations**

Customer-backed receipt handling should use allocation records.

Recommended table:

```text
receipt_line_allocations
```

Receipt line allocations connect received accepted quantity to customer-backed PO allocations, special orders, and reservations.

Receipt allocation should run as part of the receipt posting transaction.

Expected flow:

```text
Purchasing::PostReceipt
  -> validate receipt
  -> post accepted quantity through Inventory::Post
  -> update purchase order received quantities
  -> allocate accepted quantity to customer-backed PO allocations
  -> convert incoming reserves to on-hand/special-order reserves
  -> update quantity_reserved and quantity_available
  -> mark customer requests / special orders ready when filled
  -> add items to ready-for-pickup queue
```

If receipt posting succeeds, reservation conversion should succeed.

If reservation conversion fails, receipt posting should roll back.

This prevents inventory, purchasing, and customer-demand state from drifting apart.

---

**Ready for Pickup**

Phase 7A should introduce a ready-for-pickup queue.

A request, hold, or special order becomes ready for pickup when:

```text
the relevant quantity is on hand
the quantity is reserved for the customer
the request or special order is not cancelled, expired, unfillable, or completed
```

The ready-for-pickup queue should be visible from the customer workflow area.

Recommended queue fields:

```text
request number
customer name
preferred contact method
item title / variant name
quantity ready
ready date/time
hold expiration
last contacted date/time
assigned staff member
```

Staff should be able to record contact attempts from this queue.

---

**Customer Contact Events**

Phase 7A should record customer contact history.

Recommended table:

```text
customer_contact_events
```

Contact methods:

```text
phone
email
sms
in_person
other
```

Directions:

```text
outbound
inbound
```

Suggested statuses:

```text
attempted
reached
left_message
no_answer
failed
not_needed
```

Contact events should be manual records in Phase 7A.

Automated SMS/email sending is deferred.

---

**POS Fulfillment**

POS should support fulfillment of held and special-order items.

Expected POS entry points:

```text
find customer
find request number
find ready-for-pickup queue item
scan held item
select reservation/special order for pickup
```

When staff adds a reserved item to a POS transaction, the line should link to the relevant customer-demand records:

```text
customer_request_line_id
special_order_id
inventory_reservation_id
```

Phase 7A may add nullable customer context to the transaction header:

```text
pos_transactions.customer_id
```

Line-level links remain authoritative for fulfillment. Header-level `customer_id` is for pickup context, receipt context, and later customer history.

POS lookup should show and enforce available quantity, not just on-hand quantity.

Expected behavior:

```text
If quantity_available > 0:
  normal sale allowed

If quantity_on_hand > 0 but quantity_available <= 0:
  warn that stock is reserved

If cashier selected the matching reservation:
  sale allowed as reservation pickup

If cashier did not select the matching reservation:
  release or manager override required
```

Reserved-stock override should use the existing POS authorization pattern.

Example warning:

```text
No available copies. 1 copy is reserved for customer pickup.
```

Override should record:

```text
requested_by_user_id
granted_by_user_id
authorization_type
reason/details
```

---

**POS Void Reversals**

Phase 7A must define reservation behavior when a fulfilled pickup sale is voided.

A completed POS pickup sale should:

```text
mark reservation fulfilled
mark special order completed if fully fulfilled
mark customer request completed if fully fulfilled
```

If that sale is voided:

```text
inventory reversal posts through existing POS void workflow
reservation fulfillment is reversed
special order/request state is reopened or returned to ready_for_pickup
audit event is recorded
```

Recommended default:

```text
fulfilled reservation -> ready
completed special order -> ready_for_pickup
completed customer request -> ready_for_pickup
```

This should only apply when the voided transaction line is directly linked to a reservation or special order.

---

**Returns of Fulfilled Special Orders**

Customer returns should not automatically reopen the original request.

Recommended rule:

```text
A completed special order remains completed when the customer later returns the item.
```

The return should be linked through POS history.

If the customer wants the item again, staff should create a new request or special order.

Return disposition continues to follow POS behavior:

```text
return_to_stock
damaged
defective
return_to_vendor_candidate
other
```

If disposition is `return_to_stock`, the item enters inventory through POS return posting.

It should not automatically become reserved again.

---

**User Interface**

Phase 7A should align with the existing workspace model.

Recommended navigation:

```text
/customers
/orders
/items
/pos
```

Do not introduce a separate top-level `/requests` workspace unless the UX concept is intentionally changed.

Customer demand queues should live under the Customers workspace.

Suggested Customers workspace areas:

```text
customer search
customer profile
open requests
needs research
awaiting customer response
approved to order
on order
ready for pickup
expiring holds
completed/cancelled/unfillable
contact history
```

Orders workspace should show customer-backed demand in purchasing and receiving contexts:

```text
PO line customer allocations
customer allocated quantity
internal TBO quantity
stock/unallocated quantity
receipt lines with customer-backed received quantity
receiving warnings for customer-reserved items
```

Item and variant pages should show operational demand:

```text
active holds
incoming reserves
special orders
open customer requests
reserved quantity
available quantity
on-order available quantity
ready-for-pickup quantity
```

POS should support:

```text
customer/request lookup
pickup fulfillment
reserved-stock warnings
manager override for selling reserved stock
automatic fulfillment state updates
```

---

**Recommended Tables**

Phase 7A should introduce:

```text
customers
customer_requests
customer_request_lines
special_orders
inventory_reservations
purchase_order_line_allocations
receipt_line_allocations
customer_contact_events
```

Phase 7A should update existing tables as needed:

```text
inventory_balances.quantity_reserved
pos_transaction_lines.customer_request_line_id
pos_transaction_lines.special_order_id
pos_transaction_lines.inventory_reservation_id
pos_transactions.customer_id nullable
```

Detailed fields, indexes, constraints, and enum values should live in:

```text
docs/specifications/phase-7a-data-model.md
```

---

**Services**

Phase 7A should centralize business logic in services.

Recommended new services:

```text
CustomerRequests::Create
CustomerRequests::AddLine
CustomerRequests::MatchVariant
CustomerRequests::TransitionStatus
CustomerRequests::Cancel
CustomerRequests::MarkUnfillable

SpecialOrders::CreateFromRequestLine
SpecialOrders::Approve
SpecialOrders::AttachToPurchaseOrderLine
SpecialOrders::Cancel

InventoryReservations::ReserveOnHand
InventoryReservations::ReserveIncoming
InventoryReservations::ConvertIncomingToOnHand
InventoryReservations::Release
InventoryReservations::Expire
InventoryReservations::FulfillAtPos
InventoryReservations::ReverseFulfillment
InventoryReservations::RebuildReservedQuantities

Purchasing::AllocateCustomerDemandToPoLine
Receiving::AllocateCustomerDemandFromReceipt
Pos::AddReservationLine
Pos::CompleteReservationFulfillment
Pos::ReverseReservationFulfillment
```

Recommended existing services to extend:

```text
Inventory::Availability
Inventory::BalanceUpdater
Inventory::RebuildBalances
Inventory::BalanceIntegrityCheck
Items::ItemOperationsPresenter
Purchasing::OrderQuantityLookup
Purchasing::BuildPurchaseOrder
Purchasing::PostReceipt
Pos::LineLookupPresenter
Pos::SellabilityValidator
Pos::CompleteTransaction
Pos::VoidTransaction
```

Controllers should coordinate requests and responses. They should not contain customer-demand state machines, reservation math, PO allocation rules, or POS fulfillment logic.

---

**Concurrency**

Reservation and POS fulfillment workflows must prevent overselling and over-reserving.

When creating, releasing, converting, fulfilling, or reversing a reservation, the implementation should lock the relevant inventory balance row:

```text
store_id + product_variant_id
```

Expected protected operations:

```text
create on-hand hold
release hold
expire hold
convert incoming reserve to on-hand reserve
complete POS pickup
void POS pickup
rebuild reserved quantity
```

Availability should be recalculated while the lock is held.

---

**Permissions**

Suggested permission keys:

```text
customers.access
customers.create
customers.update

customer_requests.access
customer_requests.create
customer_requests.update
customer_requests.cancel
customer_requests.mark_unfillable
customer_requests.contact

special_orders.create
special_orders.approve
special_orders.attach_to_po
special_orders.cancel

inventory_reservations.create
inventory_reservations.release
inventory_reservations.override
inventory_reservations.expire

pos.fulfill_customer_reservation
pos.sell_reserved_stock_override
```

Manager authorization should be required for:

```text
selling reserved stock to another customer
over-reserving on-hand stock
releasing ready-for-pickup special-order reservations
cancelling customer-backed ordered items after PO submission
voiding completed pickup sales when fulfillment state will be reversed
```

POS-related overrides should use `pos_authorizations`.

---

**Audit Events**

Phase 7A should create audit events for important lifecycle changes.

Suggested events:

```text
customer.created
customer.updated

customer_request.created
customer_request.updated
customer_request.status_changed
customer_request.cancelled
customer_request.marked_unfillable
customer_request.completed

customer_request_line.created
customer_request_line.matched_variant
customer_request_line.status_changed
customer_request_line.cancelled

special_order.created
special_order.approved
special_order.attached_to_po
special_order.ready_for_pickup
special_order.completed
special_order.cancelled
special_order.marked_unfillable

inventory_reservation.created
inventory_reservation.converted_from_incoming
inventory_reservation.ready
inventory_reservation.fulfilled
inventory_reservation.fulfillment_reversed
inventory_reservation.released
inventory_reservation.expired
inventory_reservation.cancelled
inventory_reservation.override_used

purchase_order_line_allocation.created
purchase_order_line_allocation.cancelled
purchase_order_line_allocation.received

receipt_line_allocation.created

customer_contact_event.created
```

Audit details should include relevant request numbers, customer id, store id, product variant id, quantity, prior status, new status, and acting user.

---

**Deferred**

Phase 7A should not include:

```text
customer deposits
customer prepayments
store credit accounts
gift card ledgers
loyalty programs
marketing preferences
automated SMS/email delivery
customer web portal
vendor EDI availability checks
automatic reorder algorithms
copy-level serialized inventory
inter-store transfer fulfillment
buyback workflows
consignment workflows
cycle counts
physical inventory
advanced cancellation fees
full CRM behavior
```

Deposit and prepayment behavior should wait until store credit, customer account balances, and financial liability handling are designed.

Transfers, counts, buybacks, consignment, and damaged inventory should be handled in later Phase 7 slices.

---

**Exit Criteria**

Phase 7A is complete when:

1. Staff can create and edit lightweight customer records.
2. Staff can create customer requests with one or more request lines.
3. Staff can create provisional request lines before catalog/product/variant matching.
4. Staff can match a request line to an existing or newly created product variant using existing catalog lookup/import paths.
5. Staff can convert a request line into an on-hand hold, incoming reserve, or special order.
6. On-hand reservations update `quantity_reserved` and reduce `quantity_available`.
7. Incoming reserves do not reduce current available stock, but do reduce on-order availability.
8. Inventory availability reads use the canonical reservation-aware availability service.
9. Item and variant pages show on-hand, reserved, available, on-order, reserved incoming, and on-order available quantities.
10. Customer-backed demand can be allocated to purchase order lines without replacing existing TBO behavior.
11. PO screens show customer allocated, internal TBO, stock, and unallocated quantities.
12. Receipt posting can allocate accepted received quantity to customer-backed demand in the same transaction as inventory posting.
13. Receiving customer-backed stock can convert incoming reserves into on-hand/special-order reserves.
14. Ready-for-pickup items appear in a customer workflow queue.
15. Staff can record customer contact attempts.
16. POS can fulfill a held or special-order item and link the POS line to the reservation/request/special order.
17. POS warns when staff attempts to sell reserved stock outside the reservation workflow.
18. Reserved-stock sale overrides require authorization and are audited.
19. POS voids reverse reservation fulfillment state when a fulfilled pickup sale is voided.
20. Customer returns of fulfilled special-order items do not automatically reopen the original request.
21. Reservation rebuild and integrity checks verify reserved quantity and availability.
22. Customer demand actions are permission-controlled and audited.
23. Tests pass per the Phase 7A test plan.

---

**Related Documents**

```text
docs/specifications/phase-7a-customer-demand-spec.md
docs/specifications/phase-7a-data-model.md
docs/specifications/phase-7a-test-plan.md
```

Update supporting documents:

```text
AGENTS.md
docs/roadmap.md
docs/domain-model.md
docs/glossary.md
docs/schema-reference.md
docs/README.md
```

Potential later Phase 7 roadmap slices:

```text
docs/roadmap/phase-7b-transfers-and-counts.md
docs/roadmap/phase-7c-buybacks-and-used-inventory.md
docs/roadmap/phase-7d-consignment.md
```
