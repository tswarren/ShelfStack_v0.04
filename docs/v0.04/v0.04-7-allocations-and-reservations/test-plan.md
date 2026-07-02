# v0.04-7 Allocations and Reservations — Test Plan

## Status

**Complete** — companion to [spec.md](spec.md) and [data-model.md](data-model.md).

---

## Test categories

| Category | Focus |
| -------- | ----- |
| Models | `DemandAllocation` validations, enums, FK consistency, terminal fields |
| Services | Allocate, release, cancel, expire, fulfill, availability, status recalc, cache rebuild |
| Transactions | All-or-nothing: allocation + status + cache + audit |
| Concurrency | Simultaneous on-hand / inbound claims without over-claim (unless override) |
| Demand integration | Cancel/expire cascade; hold-from-item partial allocate |
| Authorization | `demand.allocations.*`; override; expire-due operator vs system |
| Request/controller | `/demand` allocation UI, override UX, filters, customer show |
| Audit | Events on allocation mutations and status recalc |
| Legacy isolation | No writes to legacy reservation/PO allocation tables |
| Inventory invariant | No `Inventory::Post`; cache updates allowed (including negative availability under override) |
| Store scope | Cross-store demand, balance, and PO line boundaries |

---

## Implementation slices (test order)

| Slice | Test focus |
| ----- | ---------- |
| **A** | On-hand allocation, cache rebuild, hold drawer, status recalc, override |
| **B** | Inbound PO allocation, expire-due job/rake, system expiry actor |
| **C** | Fulfill, terminal demand guards, index/customer filters, UI presenters |
| **D** | Verify rake STRICT, cache consistency, integration smoke |

---

## Intent matrix tests

One test per row in [spec intent table](spec.md#intent-specific-allocation-behavior):

* `hold` on create → partial/full/none allocate per available stock; default `expires_at` 14 days
* `notify` on create → demand only, no allocation
* `special_order`, `manual_tbo`, `buyer_replenishment` → no auto-allocate on create
* `used_wanted` → no inbound PO auto-path; on-hand manual requires used-like variant
* `research` / `captured` → allocate rejected until matched

---

## Model tests

### `DemandAllocation`

* Valid `on_hand` row with required FKs and enums
* Valid `inbound_purchase_order` row requires `purchase_order_line_id`
* `on_hand` rejects PO line FK; inbound rejects missing PO line
* When demand line has variant, `product_id` equals demand line and variant product
* Variant/store must match demand line
* `quantity_allocated` > 0
* Terminal statuses require fields per [data-model terminal table](data-model.md)
* When `override_availability = true`: `override_authorized_by_user_id`, `override_authorized_at`, `override_reason` required
* `override_availability` only valid for `on_hand` kind (not inbound PO)
* `allocated_at` set by service on create

### `DemandLine` (extended statuses)

* Accepts `partially_allocated`, `allocated`, `fulfilled`
* `fulfilled` in `TERMINAL_STATUSES`
* `captured` cannot have allocations (service-level guard)

---

## Status recalculation table

Normative cases for `DemandLines::RecalculateAllocationStatus`:

| Requested | Fulfilled | Active | Expected status |
| --------: | --------: | -----: | --------------- |
| 2 | 0 | 0 | `open` |
| 2 | 0 | 1 | `partially_allocated` |
| 2 | 0 | 2 | `allocated` |
| 2 | 1 | 0 | `partially_allocated` |
| 2 | 1 | 1 | `allocated` |
| 2 | 2 | 0 | `fulfilled` |

Additional rules:

* Does not recalculate terminal demand unless owning service explicitly transitions
* Idempotent when called repeatedly

---

## Service tests — allocations

### `DemandAllocations::AllocateOnHand`

* Creates active allocation; audit `demand_allocation.created`
* Calls `DemandLines::RecalculateAllocationStatus`
* Calls `Inventory::RebuildAvailabilityCache` for store + variant
* Reduces `quantity_available` / increases `quantity_reserved` on balance (non-override path)
* **Does not** call `Inventory::Post` or create ledger entries
* **Does not** create `InventoryReservation`
* Rejects when demand terminal, `fulfilled`, or `captured`
* Rejects when quantity exceeds `available_for_allocation` without override
* With `demand.allocations.override_availability` + reason → succeeds; `override_availability = true`; audit override event
* Override path may leave `quantity_available` negative (see cache tests below)

### `DemandAllocations::AllocateInboundPurchaseOrder`

* Creates active inbound allocation; audit
* Recalculates demand status
* **Does not** change PO line quantities / header status
* **Does not** create `PurchaseOrderLineAllocation`
* Respects `available_inbound` minus legacy PO allocations
* Rejects double-claim beyond available inbound
* Rejects `override_availability` on inbound kind

### `DemandAllocations::Release` / `Cancel` / `Expire`

* Active → terminal allocation status with actor/reason (or system expiry — see below)
* Recalculates demand status
* On-hand paths rebuild availability cache
* **No** `Inventory::Post`
* Rejects mutating already-`fulfilled` allocation rows in v0.04-7 (no reversal service)

### `DemandAllocations::Fulfill`

* Active → `fulfilled`; optional fulfillment reference
* Recalculates demand status to `fulfilled` when quantities cover request
* On-hand fulfill rebuilds cache (releases reserved qty)
* **No** `Inventory::Post`

### `DemandAllocations::Availability`

* `available_for_allocation` = on_hand − legacy reserved − v0.04 active on_hand allocations, **floored at 0** for normal decisions
* `available_inbound` subtracts legacy and v0.04 inbound claims
* POS pending/suspended claims remain separate from allocation math (document if tested elsewhere)

### `Inventory::RebuildAvailabilityCache`

* Sums legacy `InventoryReservation.active_on_hand` and active v0.04 `on_hand` allocations (including override rows)
* Does not count inbound allocations toward `quantity_reserved`
* Scoped rebuild updates only affected store + variant
* **Override:** active on_hand allocations = 2, on_hand = 1 → `quantity_reserved = 2`, `quantity_available = -1` (allowed only when override authorized)
* **Non-override:** allocation cannot drive `available_for_allocation` below zero at decision time

---

## Transaction / rollback tests

Allocation services perform multiple steps atomically:

```text
create/update allocation
recalculate demand status
rebuild availability cache
audit event
```

For `AllocateOnHand`, `AllocateInboundPurchaseOrder`, `Release`, `Cancel`, `Expire`, `Fulfill`, and demand cancel/expire cascades:

* If cache rebuild fails → allocation not persisted, demand status unchanged, no audit event
* If audit persistence fails → entire transaction rolls back
* If status recalc raises → no partial allocation row left committed

Use transactional test patterns (stub failure mid-chain, assert counts unchanged).

---

## Concurrency tests

Required behavior — simultaneous operations must not over-claim unless override authorized:

* **On-hand:** two parallel allocate calls for last available unit — one succeeds, one fails (or service-level lock serializes); total active on_hand allocations ≤ available + authorized override excess only
* **Inbound PO:** two parallel inbound allocations on same PO line — cannot exceed `available_inbound`
* Implementation may use row locks on balance, PO line, or demand line; tests assert behavior, not a specific lock mechanism

---

## Service tests — demand line extensions

### `DemandLines::StartFromItem` (hold)

* 3 requested, 2 available → `partially_allocated`, allocation rows totaling 2
* 1 requested, 1 available → `allocated`
* 3 requested, 0 available → `open`, no allocation rows
* Default `expires_at` ≈ 14 days when not passed

### `DemandLines::Cancel`

* Cancels active allocations first (→ `canceled`)
* Then demand → `canceled`
* Rebuilds cache for released on-hand claims
* **Rejects** when demand already `fulfilled`

### `DemandLines::Expire` (manual)

* Expires active allocations first; sets `expired_by_user_id`
* Then demand → `expired`
* **Rejects** when demand already `fulfilled`

### `DemandLines::ExpireDue` / job / rake

* Selects demand with `expires_at <= now` (non-terminal)
* Expires allocations + demand
* Allocation `expired_by_user_id` **may be null**; `expired_at` required
* Audit `demand_line.expired_due` with system/job actor context
* **No** `Inventory::Post`
* Job/rake invoke service (unit + integration)
* **`demand.expire_due`** required for UI/admin-triggered expire-due actions only; scheduled job/rake runs in system context

### Terminal demand guards

* Cannot allocate to `fulfilled`, `canceled`, or `expired` demand
* `DemandLines::Cancel` rejects `fulfilled` demand
* Manual `DemandLines::Expire` rejects `fulfilled` demand
* Compensating workflows deferred — do not reopen `fulfilled` in v0.04-7

---

## Store scope tests

* Cannot allocate Store A demand using Store B inventory balance / availability
* Cannot allocate Store A demand to Store B PO line
* Cache rebuild scoped to correct store + variant only
* Store-scoped role denies cross-store allocation actions

---

## Inventory non-side-effect harness (extended)

For allocation services, assert:

```text
No new inventory ledger entries for store + variant under test.
quantity_on_hand unchanged.
quantity_reserved / quantity_available MAY change via RebuildAvailabilityCache
(including negative quantity_available when override authorized).
```

Shared helper: snapshot balance + ledger count before/after.

---

## Authorization tests

* `demand.allocations.create` required for allocate actions
* `demand.allocations.release`, `.cancel`, `.expire`, `.fulfill`
* `demand.allocations.override_availability` for over-allocate path
* `demand.expire_due` for **UI/admin-triggered** expire-due only (not system job)
* Store-scoped role assignment denies cross-store allocation

---

## Controller / integration tests

* `/demand/:id` shows allocation summary and table
* Manual allocate on-hand from demand show
* Manual allocate inbound PO when eligible line exists
* Index filter `allocation_state=unallocated` + `capture_intent=notify`
* Customer show displays allocation state labels
* Item drawer hold → messages for full / partial / none allocated
* Item availability presenter exposes v0.04 vs legacy reserved breakdown (slice C)

### Override (request level)

* Over-allocate without `demand.allocations.override_availability` → forbidden / validation error
* Over-allocate with permission but no reason → validation error
* Over-allocate with permission + reason → succeeds; UI shows override marker / over-allocated availability

---

## Verify rake — `shelfstack:v0047_verify_allocations`

| Check | STRICT |
| ----- | ------ |
| `demand_allocations` table exists | fail |
| Allocation / demand status enums load | fail |
| Allocation services avoid `Inventory::Post` (static) | fail |
| Allocation services avoid legacy reservation writes | fail |
| Allocation services avoid legacy PO/receipt allocation writes | fail |
| Availability cache matches legacy on-hand reservations + active v0.04 `on_hand` allocations (sample rows) | fail |
| `quantity_available = quantity_on_hand - quantity_reserved` on sample balances (POS claims outside cache documented if applicable) | fail |
| On-hand allocation overages have valid override authorization (see rule below) | fail |
| Inbound allocations ≤ eligible PO open qty | fail |
| Used-wanted inbound allocation count = 0 | fail |
| Terminal allocation rows have required timestamps/actors; system expiry may leave `expired_by_user_id` null | fail |
| Expire-due service exists | fail |

**Override overage rule (replaces “allocations ≤ on_hand”):**

```text
For each store + variant:
  IF active on_hand allocated quantity > quantity_on_hand
  THEN every allocation contributing to the excess must have:
    override_availability = true
    override_authorized_by_user_id present
    override_authorized_at present
    override_reason present
```

---

## Manual smoke

1. **Hold with stock** — drawer hold for in-stock variant → demand `allocated` or `partially_allocated`; `quantity_available` decreased.
2. **Hold without stock** — demand `open`; message explains no allocation; availability unchanged.
3. **Override hold** — authorized over-allocate → `quantity_available` may show negative / over-allocated in UI.
4. **Release** — release on-hand allocation → availability restored; demand status recalculated.
5. **Inbound PO** — manual allocate to open PO line; PO quantity unchanged; inbound available decreases.
6. **Expire due** — run rake on expired hold → allocations expired; cache rebuilt; system audit context.
7. **Legacy isolation** — after v0.04 flows, no new `inventory_reservations` or `purchase_order_line_allocations` rows.

---

## Out of scope (v0.04-8+)

* Sourcing, vendor responses, cascade
* PostReceipt allocation conversion
* POS `demand_allocation_id` column
* Legacy route removal
* Nightly production scheduler (optional)
* Reversal/reopen of `fulfilled` demand
