# v0.04-10 Retire v0.03 Ordering UI — Test Plan

## Status

**Complete** — merged 2026-07-02. See [completion note](../../implementation/v0.04-10-completion.md).

Companion to [spec.md](spec.md).

---

## Test categories

| Category | Focus |
| -------- | ----- |
| Service | `Pos::DemandPickupLookup`, `Pos::AddDemandAllocationLine`, fulfill on complete |
| Queue | `DemandLines::QueueScope` per queue definition |
| Request / integration | Redirects, nav absence, report replacement |
| Authorization | Permission mapping after seed update |
| Verifier | `shelfstack:v00410:verify_legacy_ordering_retired` G1 and G2 |
| System / smoke | End-to-end acceptance scenarios |

---

## Acceptance scenarios (smoke)

These are the **v0.04-10 smoke tests** (manual or system-level).

### 1. On-hand pickup path

```text
Customer show → New demand (hold) → auto on_hand allocation
→ POS pickup lookup → add line → complete transaction
→ demand_allocation fulfilled, demand_line fulfilled, inventory sold
```

### 2. Inbound → receipt → pickup path

```text
Special-order demand → sourcing → vendor confirm → inbound allocation
→ PO receipt (v0.04 convert inbound → on_hand)
→ ready_for_pickup queue includes demand
→ POS pickup → complete → fulfilled
```

### 3. Manual TBO without purchase_request

```text
Item drawer → Manual TBO demand → appears on /demand (manual_tbo intent)
→ start sourcing from demand show
→ no purchase_requests row created
```

### 4. Receipt post without legacy allocations

```text
PO-backed receipt with v0.04 inbound allocations only
→ post receipt
→ no receipt_line_allocations rows created
→ ConvertInboundFromReceipt idempotent
```

### 5. Report redirect

```text
GET /reports/customer_requests → 302 to demand queue report
Report rows use demand_number, link to /demand/:id and item overview
```

### 6. Nav / route retirement (G1)

```text
No staff nav link to customer_requests, purchase_requests, from_tbo
GET /customers/customer_requests → redirect /demand
GET /orders/purchase_requests → redirect filtered /demand
```

---

## Slice C — POS pickup tests

| Test | Assertion |
| ---- | --------- |
| Pickup lookup by customer | Returns active on_hand allocations only |
| Pickup lookup by demand number | Filters correctly |
| Expired allocation excluded | Not in lookup results |
| Add demand allocation line | Sets `demand_allocation_id`, variant, qty |
| Complete transaction | `DemandAllocations::Fulfill` called; reference set |
| Complete does not double-post inventory | Ledger sold qty matches POS only |
| Void before complete | Line removed; allocation still active |
| Legacy reservation pickup | Removed or 404 after G1 (no new tests on legacy path) |

---

## Slice A — Queue tests

For each operational queue key, fixture demand lines + allocations + sourcing states:

| Queue | Positive fixture | Negative fixture |
| ----- | ---------------- | ---------------- |
| `ready_for_pickup` | active on_hand, not expired | expired; inbound only |
| `expiring_holds` | expires_at within window | no expires_at |
| `notify_customer` | notify intent + on_hand allocated | notify intent only, no allocation |
| `needs_research` | status captured | status open matched |
| `awaiting_response` | sourcing needs_review | ready_for_pickup excludes |
| `approved_to_order` | special_order, no inbound | already inbound |
| `on_order` | active inbound allocation | vendor_backorder only |
| `vendor_backorder` | active vendor_backorder allocation | inbound only |

Dashboard presenter: queue counts match `QueueScope.count`.

---

## Slice B — TBO retirement tests

| Test | Assertion |
| ---- | --------- |
| `purchase_requests` routes | 404 or redirect; no CRUD |
| `from_tbo` routes | redirect |
| Item drawer | no TBO/Order header actions |
| `CreateSingleLine` service | unreachable from staff UI (may delete in G2) |

---

## Slice D — Presenter / post receipt tests

| Test | Assertion |
| ---- | --------- |
| Receipt show presenter | Shows demand allocation projection |
| PO line demand breakdown | Links to demand lines |
| PostReceipt | does not invoke `Receiving::AllocateCustomerDemandFromReceipt` (G1+) |
| PostReceipt v0.04 path | still converts inbound on post |

---

## Slice E — Report tests

| Test | Assertion |
| ---- | --------- |
| Registry | demand queue report registered |
| Permission | unauthorized user blocked |
| Query | uses `DemandLines::QueueScope` |
| Legacy redirect | `/reports/customer_requests` → new path |

Integration: `test/integration/reports/customer_requests_controller_test.rb` → rewrite or replace.

---

## Slice F — Match flow tests

| Test | Assertion |
| ---- | --------- |
| Add item from captured demand | match banner uses demand context |
| Match variant | redirects to demand show, status open |
| Item index | no customer_request match links |

---

## Verifier tests

`test/lib/shelfstack/v00410_verify_test.rb`

**G1 mode**

* Routes redirect check (static route audit)
* No legacy controller references in views (optional grep fixture)
* PostReceipt source does not reference legacy allocator
* POS line schema includes `demand_allocation_id`

**G2 mode (STRICT=1 after drop)**

* Legacy tables missing from schema
* Legacy models not loadable
* InboundAvailability source free of `purchase_order_line_allocations`

---

## Legacy test migration

Plan to **delete or rewrite** (not maintain dual paths):

```text
test/integration/customers_request_* 
test/services/customer_requests/*
test/presenters/customer_requests/*
test/services/purchase_requests/*
test/services/pos/complete_reservation_fulfillment_test.rb  → demand fulfill
test/helpers/pos_helper_pickup_summary_test.rb
test/integration/pos_workspace_lines_controller_test.rb  (reservation → allocation)
```

Keep until slice that removes the behavior; delete in G2 batch.

---

## Verification commands (merge gate)

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails shelfstack:seeds:validate

STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v0046:verify_demand_foundation
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v0047:verify_allocations
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v0048:verify_sourcing
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v0049:verify_po_receiving
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v00410:verify_legacy_ordering_retired
```

After G2:

```bash
./dev/rails-docker bin/rails db:seed
# re-run full suite + STRICT verifiers
```

---

## Manual smoke checklist (reviewers)

- [ ] Scenario 1 — on-hand POS pickup
- [ ] Scenario 2 — inbound receipt pickup
- [ ] Scenario 3 — manual TBO without purchase_request
- [ ] Scenario 4 — receipt post no legacy allocations
- [ ] Scenario 5 — report redirect
- [ ] Scenario 6 — nav / legacy route redirects
- [ ] Reseed after G2 produces usable demo demand queues
