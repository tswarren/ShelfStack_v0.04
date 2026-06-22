# Phase 7A Customer Demand Functional Specification

## Purpose

This specification defines functional behavior for ShelfStack Phase 7A.

Phase 7A establishes customer records, customer requests, special orders, inventory reservations (holds), purchase-order and receipt allocations, ready-for-pickup workflows, and POS fulfillment. Customer demand affects **availability**, not inventory ledger quantity.

Inventory still enters and leaves stock only through existing source-document posting (`Purchasing::PostReceipt`, `Pos::CompleteTransaction`, `Pos::VoidTransaction`, adjustments, RTV).

See also:

```text
docs/specifications/phase-7a-data-model.md
docs/specifications/phase-7a-test-plan.md
docs/roadmap/phase-7a-customer-demand.md
```

---

# 1. Core Principles

- Customer demand is a **first-class operational workflow**, not an annotation on catalog or PO records.
- A customer request may begin **before** catalog/product/variant matching (provisional lines).
- Reservations, special-order fulfillment, PO allocation, receipt allocation, and POS pickup operate at **product variant** grain once matched.
- **Reservations do not create inventory ledger entries.** They affect `quantity_reserved` and derived availability only.
- **Internal TBO** (`purchase_requests` / `purchase_request_lines`) remains unchanged. Customer-backed demand uses **allocation tables**, not direct FKs on `purchase_order_lines` or `receipt_lines`.
- **Availability reads** must go through `Inventory::Availability` (canonical). POS, Items, Customers, and Orders surfaces must not recalculate independently.
- Controllers coordinate; business rules live in services (see §17).

---

# 2. Availability Model

Phase 7A changes the meaning of available quantity.

## 2.1 On-hand formulas

```text
quantity_on_hand     = authoritative physical stock from inventory ledger (unchanged)

quantity_reserved      = sum of open quantity on active on-hand reservations
                         (reservation_type in on_hand_hold, special_order_reserve
                          and status in active, ready)

quantity_available     = quantity_on_hand - quantity_reserved
```

`Inventory::BalanceUpdater` must preserve `quantity_reserved` when ledger postings change `quantity_on_hand`, then recompute `quantity_available`.

## 2.2 On-order formulas

```text
on_order               = open PO line quantity not yet received or cancelled
                         (existing Purchasing::OrderQuantityLookup semantics)

reserved_incoming      = sum of open quantity on active incoming_reserve rows
                         tied to open PO lines

on_order_available     = on_order - reserved_incoming
```

Incoming reserves do **not** increment `quantity_reserved` or reduce current `quantity_available`.

## 2.3 Display example

```text
On hand: 3
Reserved: 1
Available: 2
On order: 5
Reserved incoming: 2
On order available: 3
```

---

# 3. Customer Records

## 3.1 Purpose

Lightweight customer records for counter workflow. **Not** a full CRM.

## 3.2 Capabilities

- Search and create customers
- Record display name, phone, email, preferred contact method, notes
- View open requests, active holds, ready-for-pickup items, recent contact history
- Optional `home_store_id` for reference; operational fulfillment is store-scoped via `customer_requests.store_id`

## 3.3 Rules

- Customers may be referenced by `customer_id` on requests, or captured as **snapshots** on the request header when no customer record exists yet.
- Prefer inactivation (`active = false`) over hard delete when history exists.
- Hard delete only when no requests, reservations, or contact events reference the customer.

---

# 4. Customer Requests

## 4.1 Header

A `customer_request` is store-scoped customer intent with one or more lines.

**Request number format:** `REQ-{store_number}-{sequence}`

- Store-scoped sequence (zero-padded, e.g. `REQ-001-000042`)
- Assigned at create; immutable
- Readable at counter and over the phone

**Header statuses:**

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

Header status is derived by `CustomerRequests::HeaderStatusResolver` from line states (see §4.4). Manual override via `CustomerRequests::TransitionStatus` is limited to terminal or workflow-control statuses (`cancelled`, `unfillable`, explicit `completed` when closing administratively) — not arbitrary drift from line states.

**Source values:** `in_store`, `phone`, `email`, `web`, `pos`, `staff`

## 4.2 Lines

**Request types:**

| Type | Meaning |
| --- | --- |
| `research` | Staff must identify/match item; no commitment yet |
| `notify` | Customer wants notification when available; **does not reserve inventory** while waiting |
| `hold` | Reserve on-hand copy for customer |
| `special_order` | Customer-backed commitment to acquire stock |

**Line statuses:**

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

**Quantity fields:** `requested_quantity`, `approved_quantity`, `ordered_quantity`, `filled_quantity`, `cancelled_quantity` — integers ≥ 0; service layer enforces consistency.

**Provisional fields** (when unmatched): `provisional_title`, `provisional_creator`, `provisional_identifier`, `provisional_format`, line `notes`.

**Matched links:** `catalog_item_id`, `product_id`, `product_variant_id` (variant required before hold, special order, PO allocation, or POS fulfillment).

**Pricing hints (optional):** `quoted_price_cents`, `max_customer_price_cents`

## 4.3 Research and matching

Phase 7A **does not** introduce a separate external catalog workflow.

Matching reuses:

1. Items search / variant lookup
2. Phase 6.5 external ISBN lookup and Add Item import (`ExternalCatalog::LookupByIsbn`, `/items/add_item`)
3. `CustomerRequests::MatchVariant` to set links and transition line to `matched`

Return context from Add Item must restore the originating customer request line.

## 4.4 Header status derivation

`CustomerRequests::HeaderStatusResolver` computes header status from non-cancelled lines:

| Line pattern | Header status |
| --- | --- |
| All lines `completed` | `completed` |
| All lines `cancelled` | `cancelled` |
| Any line `unfillable` and none active | `unfillable` (or `partially_filled` if mixed) |
| Any line `ready_for_pickup` | `ready_for_pickup` |
| Any line `ordered` or `partially_filled` | `ordered` or `partially_filled` |
| Any line `approved` / `awaiting_customer_response` | matching header status |
| Any line `researching` / `matched` | `researching` or `new` |
| Mixed terminal + active | `partially_filled` |

Call resolver after line status changes. Header manual override only for terminal/workflow statuses (see §4.1).

---

# 5. Request Type Behaviors

## 5.1 Research

- Line may remain provisional through `researching`.
- No reservation or PO allocation until matched and converted to another type or special order.

## 5.2 Notify

- **While waiting:** no reservation; does not affect `quantity_reserved` or on-order availability.
- **When stock becomes available** (receipt posting or other on-hand increase for matched variant): line appears in **Notify Customer** queue with available quantity context. **No automatic hold.**
- Staff contacts customer manually (contact events). If customer wants a copy held, staff creates an on-hand hold via normal hold workflow (`InventoryReservations::ReserveOnHand`).
- Line status moves to a notify-ready state (e.g. `matched` with notify flag in queue, or dedicated sub-state via queue query: open `notify` lines where variant has `quantity_available > 0` and `filled_quantity < requested_quantity`).
- Automated SMS/email is deferred.

## 5.3 Hold (on-hand)

- Requires matched variant.
- `InventoryReservations::ReserveOnHand` creates `on_hand_hold` with default `expires_at = reserved_at + 14 days` (staff may override).
- Increments `quantity_reserved`; reduces `quantity_available`.
- Default rule: hold allowed only when `quantity_available > 0` for requested quantity.
- **Over-reserve override (Customers workspace):** `inventory_reservations.override` permission; record `override_authorized_by_user_id`, `override_authorized_at`, `override_reason`; set `over_reserved = true`; audit `inventory_reservation.override_used`. **Do not use `pos_authorizations` for this path.**

## 5.4 Special order

- Requires matched variant (special order record may briefly be `pending_match` only during conversion UI, not for fulfillment).
- `SpecialOrders::CreateFromRequestLine` + `Approve` creates commitment record.
- May attach to PO via allocations (§7) and create `incoming_reserve` when PO is submitted/ordered.

---

# 6. Special Orders

Thin commitment record — **not** a duplicate PO system.

**Statuses:**

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

**Quantity tracking:** `quantity_committed`, `quantity_ordered`, `quantity_received`, `quantity_ready`, `quantity_completed`, `quantity_cancelled`

`quantity_ready` is the current open ready-for-pickup quantity (operational), not cumulative; it increases when stock is received and decreases when picked up at POS, restoring on void reversal.

Links: customer, customer_request_line, product_variant, vendor (optional until PO), allocations, reservation, POS line.

---

# 7. Inventory Reservations

Unified model; user-facing labels may say "hold" or "reserve".

## 7.1 Types

| Type | Affects `quantity_reserved`? | Meaning |
| --- | --- | --- |
| `on_hand_hold` | Yes | Physical copy set aside |
| `incoming_reserve` | No | Claim against expected PO/receipt qty |
| `special_order_reserve` | Yes (once on hand) | Copy assigned to special order after receipt or assignment |

## 7.2 Statuses

```text
active
ready
fulfilled
released
expired
cancelled
```

## 7.3 Quantities

`quantity_reserved`, `quantity_fulfilled`, `quantity_released` — services maintain `open_quantity = quantity_reserved - quantity_fulfilled - quantity_released`.

## 7.4 Expiration

- Default hold duration: **14 days** from `reserved_at`
- Staff may set or clear `expires_at` on create/edit
- `InventoryReservations::Expire` (nightly Solid Queue job + manual rake task) transitions expired `active`/`ready` on-hand holds to `expired`, releases reserved qty, audits `inventory_reservation.expired`
- Expiring-holds queue shows reservations with `expires_at` within configurable window (default 3 days)

## 7.5 Concurrency

Lock `inventory_balances` row (`SELECT FOR UPDATE` on `store_id` + `product_variant_id`) for:

```text
create on-hand hold
release / expire hold
convert incoming → on-hand reserve
complete POS pickup
void POS pickup
rebuild reserved quantity
```

Recalculate `quantity_reserved` and `quantity_available` while lock is held.

## 7.6 Release reasons

Controlled `release_reason` values when releasing or expiring:

```text
customer_cancelled
customer_declined
expired
staff_release
fulfilled_elsewhere
order_cancelled
unfillable
manager_override
data_correction
other
```

---

# 8. Purchase Order Allocations

## 8.1 Purpose

Connect portions of PO lines to customer demand without direct customer FK on `purchase_order_lines`.

Table: `purchase_order_line_allocations`

Each customer-backed allocation **requires** `special_order_id`. Optional `customer_request_line_id` may be denormalized for queries; when present it must equal `special_order.customer_request_line_id`.

Supports:

```text
PO line: 8 copies
  → 2 Customer A (special_order allocation)
  → 1 Customer B (special_order allocation)
  → 5 shelf stock (unallocated quantity on PO line)
```

## 8.2 PO build rules

`Purchasing::BuildPurchaseOrder` accepts three sources:

1. Manual stock lines (unchanged)
2. Internal TBO lines via `purchase_request_line_id` FK (**unchanged; not migrated to allocation rows**)
3. Customer-backed special orders → **auto-merge** customer allocations with same `product_variant_id` + vendor into **one PO line** with summed `quantity_ordered` and multiple allocation rows

**TBO + customer merge rules (Phase 7A):**

- Phase 7A does **not** merge multiple TBO lines into allocation rows.
- Customer-backed allocations may merge with other customer-backed allocations and with manual stock quantity on the same variant + vendor.
- Customer allocations may be added to an existing **draft** PO line only when variant + vendor match and total quantity is increased safely.
- **Do not** merge a TBO-backed PO line (with `purchase_request_line_id` set) with customer allocations unless implementation explicitly supports increasing that line's quantity while preserving the TBO FK — otherwise keep TBO-backed lines separate.
- TBO path must not regress existing tests.

## 8.3 Attach to existing draft PO

`SpecialOrders::AttachToPurchaseOrderLine` may add allocations to an existing draft PO line for the same variant + vendor.

## 8.4 PO display

PO line detail shows:

```text
quantity_ordered
quantity_received
customer_allocated_quantity
internal_tbo_quantity (via purchase_request_line_id when present)
stock / unallocated quantity
customer names / request numbers (from allocations)
```

## 8.5 Cancellation after submit

Cancelling customer-backed ordered items after PO submit requires manager permission; allocation status → `cancelled`; incoming reserve released.

---

# 9. Receipt Allocations

## 9.1 Purpose

Connect accepted receipt quantity to customer PO allocations and drive reservation conversion.

Table: `receipt_line_allocations`

## 9.2 Atomic posting

Inside existing `Purchasing::PostReceipt` transaction, **after** `Inventory::Post` and `UpdatePoLineQuantities`:

```text
Receiving::AllocateCustomerDemandFromReceipt
  1. Distribute accepted qty to open PO allocations (FIFO by allocation created_at — Phase 7A MVP)
  2. Create receipt_line_allocation rows
  3. Convert incoming_reserve → special_order_reserve or on_hand_hold as appropriate
  4. Update quantity_reserved / quantity_available
  5. Transition special orders / request lines toward ready_for_pickup when filled
  6. Flag matched notify lines for Notify Customer queue when variant gains available stock (no auto-hold)
```

If any step fails, **entire receipt transaction rolls back** (including inventory posting).

## 9.3 Notify on stock arrival

When posting increases on-hand for a variant, open matched `notify` lines for that store appear in **Notify Customer** queue. Staff decides whether to create a hold. **No reservation is created automatically.**

## 9.4 Receiving UI

Flag lines: "N copies are reserved for customers" when allocations exist on the PO line.

---

# 10. Operational Queues

## 10.1 Ready for pickup

Queue entry when:

- Relevant quantity is on hand
- Quantity is reserved for the customer (`ready` or `active` on-hand reservation, or special order in `ready_for_pickup`)
- Request/line/special order not cancelled, expired, unfillable, or completed

**Queue fields:** request number, customer name, preferred contact method, item title/variant name, quantity ready, ready at, hold expiration, last contacted, assigned staff

## 10.2 Notify customer

Queue entry when:

- Line `request_type = notify`, matched variant, not completed/cancelled/unfillable
- `quantity_available > 0` (or stock just arrived — surfaced after receipt)
- No active reservation yet for unfilled quantity

Staff actions: record contact, create hold if customer wants copy.

## 10.3 Expiring holds

Reservations with `expires_at` within window (default 3 days).

Staff may record contact attempts from queues (→ `customer_contact_events`).

---

# 11. Partial Fulfillment

Request lines and special orders support partial progress across receive and pickup.

## 11.1 Quantity rules

```text
open_line_quantity = requested_quantity - filled_quantity - cancelled_quantity
```

Services reject operations that exceed open quantity.

## 11.2 Partial receipt

Example: requested 3, PO allocation 3, accepted 1 on first receipt:

- Allocation `quantity_received` += 1
- Special order `partially_received`; line `partially_filled`
- One unit converted to on-hand reserve; ready queue shows qty 1

## 11.3 Partial pickup

Example: requested 3, reserved 3, POS pickup qty 1:

- Reservation `quantity_fulfilled` += 1; reservation stays `active`/`ready` if open qty remains
- Line `filled_quantity` += 1; `partially_filled` until fully picked up

## 11.4 Partial cancel

Staff may cancel remaining quantity (`cancelled_quantity`) on open lines; releases proportional reservations.

## 11.5 Void partial pickup

Voiding one pickup transaction reverses only that line's fulfilled quantity on linked reservation/special order/request; remaining fulfilled units stay closed.

---

# 12. Store Consistency

Linked records must belong to the same operational store. Enforce in services (not all rules are DB constraints):

```text
customer_request.store_id == special_order.store_id
customer_request.store_id == inventory_reservation.store_id
customer_request.store_id == purchase_order.store_id (via PO line allocation chain)
customer_request.store_id == receipt.store_id (via receipt allocation chain)
pos_transaction.store_id == inventory_reservation.store_id
customer_request_line.product_variant store context == request.store_id (variant sellable at store via existing store scoping)
```

Cross-store operations are rejected with clear errors.

---

# 13. Customer Contact Events

Manual records only in Phase 7A.

**Methods:** `phone`, `email`, `sms`, `in_person`, `other`

**Directions:** `outbound`, `inbound`

**Statuses:** `attempted`, `reached`, `left_message`, `no_answer`, `failed`, `not_needed`

Updating `customer_requests.last_contacted_at` when an outbound contact is recorded is recommended.

---

# 14. POS Fulfillment

## 14.1 Entry points

- Find customer, request number, or ready-for-pickup item
- Scan variant SKU with reservation context
- Select reservation/special order for pickup

## 14.2 Line links

**Normal sale lines:** all three FKs nullable.

**Reservation pickup lines:**

| Field | Rule |
| --- | --- |
| `inventory_reservation_id` | **Required** |
| `special_order_id` | Required when reservation linked to special order |
| `customer_request_line_id` | Populated when available (query convenience) |

When multiple links present, `Pos::AddReservationLine` and completion services **must validate** they refer to the same customer demand chain (reservation → special order → request line → customer).

Optional header: `pos_transactions.customer_id` for pickup context (line links remain authoritative).

## 14.3 Lookup and sell rules

`Pos::LineLookupPresenter` exposes `quantity_on_hand`, `quantity_available`, `quantity_reserved`.

| Condition | Behavior |
| --- | --- |
| `quantity_available > 0` | Normal sale allowed |
| `quantity_on_hand > 0` and `quantity_available <= 0` | Warn: reserved stock |
| Cashier selected matching reservation | Pickup sale allowed |
| No reservation context | Release reservation or manager override required |

Override uses **`pos_authorizations`** with `authorization_type = sell_reserved_stock_override`; permission `pos.sell_reserved_stock_override`. (Distinct from reservation over-reserve override in §5.3.)

Example message: "No available copies. 1 copy is reserved for customer pickup."

## 14.4 Completion

`Pos::CompleteReservationFulfillment` on transaction complete:

- Reservation → `fulfilled`
- Special order / request line quantities updated
- Header/line statuses → `completed` when fully fulfilled; `partially_filled` when partial (§11)

## 14.5 Void reversal

When voiding a transaction with linked reservation lines:

- Inventory reverses via existing `Pos::VoidTransaction` / `PostVoidInventory`
- `InventoryReservations::ReverseFulfillment`: reservation `fulfilled` → `ready`
- Special order `completed` → `ready_for_pickup` or `partially_received` per quantities reverted (§11.5)
- Customer request → `ready_for_pickup` when applicable
- Audit `inventory_reservation.fulfillment_reversed`

Applies only when voided line has direct reservation/special-order link.

## 14.6 Returns of fulfilled special orders

Completed special order **stays completed** when customer later returns item.

Return uses normal POS return flow; `return_to_stock` posts inventory via existing customer_return movement.

**Do not** auto-reopen request or re-reserve. New demand requires new request/special order.

---

# 15. Negative On-Hand

Phase 4 allows negative on-hand.

- On-hand holds require `quantity_available > 0` (not merely `quantity_on_hand > 0`) unless manager override.
- Incoming reserves allowed when on-hand is zero or negative.
- `special_order_reserve` increments `quantity_reserved` only when stock is actually on hand (after receipt conversion).

---

# 16. User Interface

## 16.1 Workspaces

```text
/customers   — customer demand (primary)
/orders        — PO/receipt allocation visibility (extend Phase 5)
/items         — variant demand section (extend)
/pos           — pickup fulfillment (extend)
```

Do **not** add top-level `/requests`.

## 16.2 Customers workspace

Queues (filter-driven indexes):

```text
open requests
needs research
awaiting customer response
approved to order
on order
notify customer
ready for pickup
expiring holds
completed / cancelled / unfillable
```

Document show: Phase 5 progressive-disclosure pattern (header, metrics, lines, sidebar trail, audit).

## 16.3 Items workspace

Variant/product Operations tab — Customer Demand section:

```text
active holds
incoming reserves
special orders
open customer requests
reserved / available / on-order-available metrics
ready-for-pickup quantity
```

Actions: Hold for customer, Create special order, Attach to open PO (when permitted).

---

# 17. Services

## 17.1 New services

```text
CustomerRequests::Create
CustomerRequests::AddLine
CustomerRequests::MatchVariant
CustomerRequests::HeaderStatusResolver
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

## 17.2 Extended services

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

## 17.3 Admin tasks

```text
rails shelfstack:inventory:rebuild_reservations
rails shelfstack:inventory:expire_reservations
```

---

# 18. Permissions

Customers workspace: `customers.access`, `customers.create`, `customers.update`

Customer requests: `customer_requests.access`, `.create`, `.update`, `.cancel`, `.mark_unfillable`, `.contact`

Special orders: `special_orders.create`, `.approve`, `.attach_to_po`, `.cancel`

Reservations: `inventory_reservations.create`, `.release`, `.override`, `.expire`

POS: `pos.fulfill_customer_reservation`, `pos.sell_reserved_stock_override`

Manager authorization:

| Action | Mechanism |
| --- | --- |
| Sell reserved stock without reservation (POS) | `pos_authorizations` + `pos.sell_reserved_stock_override` |
| Over-reserve on-hand hold (Customers) | Reservation override columns + `inventory_reservations.override` |
| Release ready-for-pickup special-order reservation | Permission + audit |
| Cancel customer-backed lines after PO submit | Manager permission |
| Void pickup reversing fulfillment | Existing void authorization |

---

# 19. Audit Events

Dot-separated names; details include request number, customer id, store id, variant id, quantities, prior/new status, actor.

See roadmap § Audit Events for full list. Minimum:

```text
customer.created / customer.updated
customer_request.created / .status_changed / .cancelled / .completed
customer_request_line.matched_variant / .status_changed
special_order.created / .approved / .attached_to_po / .ready_for_pickup / .completed
inventory_reservation.created / .fulfilled / .fulfillment_reversed / .released / .expired
purchase_order_line_allocation.created / .received
receipt_line_allocation.created
customer_contact_event.created
```

---

# 20. Workflow Summary

## A — Customer asks for something not in stock

```text
Create customer (or snapshot) → customer_request + provisional line
  → researching → match variant (catalog / ISBN lookup / Add Item)
  → awaiting_customer_response or approved
  → special_order + PO allocation OR unfillable
  → ordered → receipt → ready_for_pickup → POS pickup → completed
```

## B — Hold on-hand copy

```text
Matched variant → hold line → ReserveOnHand → ready_for_pickup → POS pickup
```

## C — Special order on PO

```text
Approved special_order → PO allocation + incoming_reserve → ordered
  → receipt allocation → convert to on-hand reserve → ready_for_pickup
```

## D — Receiving customer-backed stock

Atomic flow in §9.2.

## E — POS pickup

```text
Find reservation → add line with links → complete → fulfill reservation
Void → reverse fulfillment state (§12.5)
```

## F — Notify when available

```text
Notify line matched → no reservation while waiting
  → stock arrives → Notify Customer queue
  → staff contacts customer → optional manual hold → ready_for_pickup → POS pickup
```

---

# 21. Deferred

```text
customer deposits / prepayments
store credit / gift card ledgers
loyalty / marketing preferences
automated SMS/email
customer web portal
vendor EDI
copy-level serialized inventory
inter-store transfer fulfillment
buybacks / consignment / cycle counts / damaged inventory workflows
full CRM
TBO → allocation migration
notify auto-hold / auto_reserve flag (deferred — manual notify queue in 7A)
```

---

# 22. Exit Criteria

Phase 7A is complete when all exit criteria in [phase-7a-test-plan.md](phase-7a-test-plan.md) §4 pass, including notify queue usage (§3.6 scenario 40).
