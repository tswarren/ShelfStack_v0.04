# v0.04-8 Sourcing and Vendor Responses — Test Plan

## Status

**Planned** — companion to [spec.md](spec.md) and [data-model.md](data-model.md).

---

## Test categories

| Category | Focus |
| -------- | ----- |
| Models | Run/attempt/response validations, quantity splits, FK consistency, snapshot fields |
| Services | Eligibility, unresolved qty, start/create/submit, record response, cascade, cancel/close |
| Transactions | Response + allocation + status recalc + audit in one transaction |
| Concurrency | Simultaneous attempts on same demand without over-committing in-flight qty |
| Demand integration | Cancel/expire sourcing cleanup; recalc includes vendor_backorder |
| Authorization | Granular `sourcing.*` permissions |
| Request/controller | `/sourcing` workspace, `/demand` sourcing panel, permissions |
| Audit | Events on runs, attempts, responses, overrides, cascade |
| Legacy isolation | No writes to legacy request/TBO/PO allocation/receipt allocation tables |
| Inventory invariant | No `Inventory::Post`; vendor_backorder does not change reserved/available cache |
| Store scope | Cross-store demand, vendor, PO line boundaries |
| Regression | v0.04-7 allocation availability and demand-only writes unchanged |

---

## Implementation slices (test order)

| Slice | Test focus |
| ----- | ---------- |
| **A** | Schema, eligibility, unresolved quantity, start run, create/submit attempt, suggest vendors, permissions, verifier skeleton |
| **B** | Record response, quantity split, inbound + vendor_backorder allocations, demand status recalc, cancel/expire sourcing cascade |
| **C** | Cascade, cancel attempt, close run, UI/request tests, stock consideration link, full verifier STRICT |
| **D** | End-to-end smoke, regression suite, completion verification |

---

## Intent matrix tests

One test per row in [spec intent table](spec.md#intent-specific-sourcing-behavior):

* `hold` — eligible when unresolved after allocations; not auto-sourced on create
* `notify` — eligible only when staff starts sourcing; no auto-source
* `special_order` — primary sourcing path
* `used_wanted` — **zero** sourcing attempts allowed
* `manual_tbo`, `buyer_replenishment` — eligible
* `research` / `captured` — rejected until matched

---

## Model tests

### `SourcingRun`

* Valid row with required FKs and status enum
* `quantity_requested > 0`
* Store/variant/product match demand line
* Cannot create when demand terminal
* At most one active run per demand line (DB constraint or model validation)

### `SourcingAttempt`

* Valid pending row
* `quantity_requested > 0`
* `sequence_number` unique per run
* Manual override requires reason + authorized actor
* Snapshots populated after submit (not blank on submitted attempts)
* PO line FK same store/variant when present

### `VendorResponse`

* Quantity fields >= 0
* Sum <= attempt `quantity_requested`
* Final response: sum equals `quantity_requested`
* Append-only behavior (no destroy in normal path)

### `DemandAllocation` (extended)

* Valid `vendor_backorder` requires sourcing_attempt_id or vendor_response_id
* `vendor_backorder` rejects purchase_order_line_id
* Existing `on_hand` / `inbound_purchase_order` rules unchanged

---

## Unresolved quantity tests (normative)

### `Sourcing::UnresolvedQuantity`

| Scenario | Expected |
| -------- | -------- |
| Open demand, no allocations, no attempts | = quantity_requested |
| 2 on_hand active of 3 requested | = 1 |
| 1 inbound active of 3 requested | = 2 |
| 2 vendor_backorder active of 3 requested | = 1 |
| Pending attempt qty 2 of 3 requested, no alloc | = 1 (3 - 2 in-flight) |
| Submitted attempt, no final response | in-flight subtracts full attempt qty |
| Final response confirmed 1 + backorder 1 + unavailable 1 on attempt qty 3 | in-flight 0 on that attempt; unavailable returns to unresolved unless backorder alloc accepted |
| Confirmed 2 without PO line | no inbound alloc; unresolved per run rules until review/close |
| Cascaded predecessor attempt | predecessor qty not in-flight |

Floor at zero; never negative.

---

## Status recalculation tests (demand — extend v0.04-7)

| Requested | Active on_hand | Active inbound | Active vendor_backorder | Fulfilled | Expected status |
| --------: | -------------: | -------------: | ----------------------: | --------: | --------------- |
| 2 | 0 | 0 | 2 | 0 | `allocated` |
| 2 | 1 | 0 | 1 | 0 | `allocated` |
| 2 | 0 | 1 | 0 | 0 | `partially_allocated` |
| 2 | 0 | 0 | 1 | 0 | `partially_allocated` |

Additional rules:

* Sourcing run state does **not** change demand status directly
* Idempotent recalc

---

## Service tests — Slice A

### `Sourcing::Eligibility`

* Open special_order with variant → eligible
* used_wanted → rejected
* Non-vendor-orderable variant → rejected
* Terminal demand → rejected
* captured → rejected
* Active run exists → rejected (second start)

### `Sourcing::StartRun`

* Creates run with audit `sourcing_run.created`
* quantity_requested <= unresolved at start
* Rejects when ineligible

### `Sourcing::SuggestVendors`

* Returns variant before product vendor
* Warns on inactive vendor / missing vendor item number
* Manual override path flagged

### `Sourcing::CreateAttempt`

* Creates pending attempt
* quantity <= run unresolved
* Rejects inactive vendor

### `Sourcing::SubmitAttempt`

* pending → submitted
* Snapshots vendor fields
* Audit `sourcing_attempt.submitted`
* Does not create allocations
* Does not call Inventory::Post

---

## Service tests — Slice B

### `Sourcing::RecordVendorResponse`

* Creates append-only vendor_response
* Derives attempt status from final response (not staff-set)
* Partial final: confirmed 1 + backordered 1 + unavailable 1 → `partially_confirmed`
* Full backorder → `backordered`
* Whole failure → `failed`, quantity_failed = quantity_requested

### Confirmed + PO line

* With linked eligible PO line → calls `AllocateInboundPurchaseOrder`
* Without PO line → **no** inbound allocation; run → `needs_review`

### Backorder acceptance

* Accepted backorder → `AllocateVendorBackorder`
* Audit `demand_allocation.vendor_backorder_created`
* Does **not** call `RebuildAvailabilityCache`
* `RecalculateAllocationStatus` → allocated when backorder covers remaining

### Run status

* Partial resolution → `partially_resolved`
* All accounted → `resolved`
* Unavailable remainder → `needs_review`

### Demand cancel/expire cascade

* `DemandLines::Cancel` → active runs closed/canceled; pending/submitted attempts canceled
* `DemandLines::Expire` → same
* No orphaned active attempts on terminal demand

---

## Service tests — Slice C

### `Sourcing::Cascade`

* Requires buyer permission
* Creates **pending** next attempt (not submitted)
* Predecessor → `cascaded`
* Audit `sourcing_attempt.cascaded`
* Cascade reason recorded

### `Sourcing::CancelAttempt`

* Pending/submitted → canceled
* In-flight qty returns to unresolved pool
* Vendor response history preserved

### `Sourcing::CloseRun` / `CancelRun`

* Close with unresolved requires reason
* Terminal run statuses only via service

---

## Attempt status derivation tests

Staff cannot PATCH attempt status to `confirmed` directly.

| Workflow | Final response | Expected attempt status |
| -------- | -------------- | ----------------------- |
| submitted → final all confirmed | confirmed = qty | `confirmed` |
| submitted → final split | mixed buckets | `partially_confirmed` |
| submitted → final all backorder | backorder = qty | `backordered` |
| submitted → failed | failed = qty | `failed` |
| cascade action | n/a | `cascaded` |

---

## UI / request tests (Slice C)

### `/sourcing` index

* Filters: needs_review, open, vendor, capture_intent
* Permission `sourcing.access` required

### `/sourcing/:id`

* Shows attempt timeline and responses
* create attempt, submit, record response actions gated

### `/demand/:id`

* Sourcing panel shows unresolved_for_sourcing, active run, latest response
* Start sourcing requires `sourcing.runs.create`

### Permissions matrix

| Action | Permission |
| ------ | ---------- |
| View workspace | `sourcing.access` |
| Start run | `sourcing.runs.create` |
| Create attempt | `sourcing.attempts.create` |
| Submit | `sourcing.attempts.submit` |
| Record response | `sourcing.responses.record` |
| Cascade | `sourcing.attempts.cascade` |
| Cancel attempt | `sourcing.attempts.cancel` |
| Close run | `sourcing.runs.close` |
| Vendor override | `sourcing.vendor_override` |

---

## Verifier tests

### `shelfstack:v0048:verify_sourcing`

Non-strict (Slice A):

* Tables exist
* Services load

STRICT (Slice B+):

* No `Inventory::Post` in sourcing service namespace
* No legacy table writes from sourcing services
* used_wanted demand has zero attempts
* vendor_backorder excluded from cache rebuild path
* Final response quantity sum rule
* Cascade creates pending only
* Manual override audit fields
* Demand cancel closes sourcing

Run in CI and locally:

```bash
STRICT=1 bin/rails shelfstack:v0048:verify_sourcing
STRICT=1 bin/rails shelfstack:v0047:verify_allocations
STRICT=1 bin/rails shelfstack:v0046:verify_demand_foundation
```

---

## Regression tests (v0.04-7)

* On-hand allocation still rebuilds availability cache
* Inbound allocation still uses InboundAvailability (legacy + v0.04 claims)
* Hold-from-item partial allocate unchanged
* Demand create paths write only `demand_lines`
* `vendor_backorder` does not increase `quantity_reserved` on balance row

---

## Audit tests

Assert events exist for:

```text
sourcing_run.created
sourcing_attempt.submitted
vendor_response.recorded
demand_allocation.vendor_backorder_created
sourcing.manual_vendor_override
sourcing_attempt.cascaded
```

Details include demand_number, quantities, vendor_id where applicable.

---

## Manual smoke

See [spec.md manual smoke](spec.md#manual-smoke-end-to-end).

Additional checks:

* Item drawer shows link/count only (no attempt form)
* Confirmed-without-PO shows needs_review, not inbound allocation
* Second vendor cascade attempt stays pending until explicit submit

---

## Definition of done (testing)

1. Slice A model + service tests green; verifier skeleton passes.
2. Slice B response/allocation/cascade-on-demand tests green; STRICT inventory/legacy checks pass.
3. Slice C UI/request tests green; full test suite green.
4. Manual smoke completed once before merge.
5. Completion note references test commands and STRICT verifier results.
