# v0.04-6 Demand Foundation — Test Plan

## Status

**In review** — companion to [spec.md](spec.md). Core tests implemented; see [v0.04-6 completion](../../implementation/v0.04-6-completion.md) for verification commands.

---

## Test categories

| Category | Focus |
| -------- | ----- |
| Models | Validations, enums, product/variant consistency, store-scoped uniqueness |
| Services | Create, match, cancel, manual expire, eligibility, stock consideration convert/dismiss |
| Authorization | Permission keys, store scope |
| Request/controller | `/demand` workspace, item drawer cutover, customer workspace |
| Audit | Append-only events on mutating paths |
| Cutover | No legacy row creation; no inventory side effects |

---

## Eligibility matrix tests

One test per row in [spec eligibility matrix](spec.md#eligibility-matrix):

* Allowed paths create `demand_line` with expected source/purpose/capture_intent
* Blocked paths raise with clear message (vendor-orderable, customer required, used-like rules)
* Invalid `source` / `purpose` / `capture_intent` **combinations** rejected (e.g. `manual_tbo` intent with `customer_order` source)
* **No** `CustomerRequestLine`, `SpecialOrder`, or `PurchaseRequestLine` created in any case

---

## Model tests

### `DemandLine`

* Valid matched row with `quantity_requested`, enums, `demand_number`
* `product_variant_id` present ⇒ `product_id` matches variant.product_id
* `captured` allows nil variant with provisional fields
* `open` requires variant
* Rejects invalid source/purpose/status
* Store + demand_number uniqueness
* `demand_number` matches `{store_number}-D{sequence:06d}`

### `StockConsideration`

* Valid open row
* Terminal statuses require appropriate actor/timestamp/reason fields
* `converted_to_demand` requires `converted_by_user_id` and `converted_at`
* Exactly one `DemandLine` with matching `stock_consideration_id` after convert (no reciprocal FK on consideration)

---

## Service tests — demand lines

### `DemandLines::NumberAllocator`

* Sequential per store
* Immutable after assign
* Format `{store_number}-D{sequence:06d}`
* **Concurrency-safe:** parallel allocate calls produce unique numbers (row lock on sequence)

### `DemandLines::Create`

* Creates matched demand; audit `demand_line.created`
* Sets `product_id` from variant
* **Inventory unchanged** (ledger count, balance qty)

### `DemandLines::CreateFromProvisional`

* `status: captured` with provisional fields

### `DemandLines::MatchVariant`

* `captured` → `open`; sets `matched_by_user_id`, `matched_at`
* **Inventory unchanged**

### `DemandLines::StartFromItem`

* Each capture_intent from matrix — demand only, **no legacy rows**
* `hold` intent creates demand only — **no** `InventoryReservation`
* Drawer-equivalent test: does not call `CustomerRequests::Create`
* used_wanted requires customer or snapshot
* used-like + special_order / manual_tbo rejected

### `DemandLines::Cancel`

* Terminal cancel with reason, actor, timestamp; audit
* **Inventory unchanged**

### `DemandLines::Expire`

* Manual/staff expiry only; sets `expired_by_user_id`, `expired_at`
* **Inventory unchanged**
* No scheduled job in v0.04-6 (assert job class not enqueued if applicable)

### `DemandLines::EligibilityResolver`

* Matrix enforcement + `OperationalPolicy` delegation

---

## Service tests — stock considerations

### `StockConsiderations::ConvertToDemand`

* Creates exactly one `demand_line` with `stock_consideration_id` set
* Sets consideration `converted_to_demand` with `converted_by_user_id` / `converted_at`
* **Inventory unchanged**

### `StockConsiderations::Dismiss`

* Terminal dismiss; no demand row
* **Inventory unchanged**

---

## Inventory non-side-effect harness

For each mutating service above, assert **no inventory posting side effects**:

```text
No new inventory ledger entries created for the variant/store under test.
The authoritative inventory balance record for that variant/store is unchanged
(on_hand, reserved, and any cached quantity fields the balance model exposes).
```

Use a shared helper around a variant with existing `InventoryBalance` (or equivalent authoritative balance row) so assertions stay aligned with the current schema.

---

## Authorization tests

* `demand.access`, `demand.create`, `demand.cancel`, `demand.expire`, `demand.match_variant`
* `stock_considerations.*` keys
* Store-scoped role assignment

---

## Controller / integration tests

* `/demand` manual create persists demand line
* Item drawer creates demand via `DemandLines::StartFromItem`; **legacy drawer actions not rendered**
* Customer workspace lists customer demand lines
* New demand path does **not** increment `customer_requests`, `special_orders`, or `purchase_request_lines` counts

---

## Verify rake — `shelfstack:v0046_verify_demand_foundation`

| Check | STRICT |
| ----- | ------ |
| Tables exist | fail |
| Enum constants load | fail |
| demand_number format sample | fail |
| No demand service creates legacy demand rows (static grep / allowlist) | fail |
| Used-wanted: used-like variant + customer present | fail |
| Manual TBO on non-vendor-orderable variant count = 0 | fail |
| manual_tbo demand rows absent from purchase_request_lines (no FK bridge) | fail |

---

## Manual smoke

1. Item drawer: **Record hold request** → `demand_line` on `/demand`; no reservation; no legacy request.
2. Used wanted for used variant + customer — no PO/TBO linkage.
3. Manual TBO demand appears on `/demand` only — not legacy TBO build PO screen.
4. Stock consideration convert/dismiss — no inventory change.
5. Manual expire on open demand — status expired.

---

## Out of scope (v0.04-7+)

* Allocations, reservations, PO linkage, POS pickup
* Nightly expiry job
* Sourcing
* Legacy route removal
