# v0.04-8 Sourcing and Vendor Responses — Functional Specification

## Status

**In review** — Slice A/B/C implemented on branch `v0.04-8-sourcing-and-vendor-responses`. CI passing. Depends on [v0.04-7 completion](../../implementation/v0.04-7-completion.md) (merged).

Companion documents: [data-model.md](data-model.md), [test-plan.md](test-plan.md).

---

## Implementation slices

v0.04-8 is delivered in three implementation slices. Each slice should leave the app runnable and tested before the next begins.

### Slice A — Sourcing foundation

* Schema: `sourcing_runs`, `sourcing_attempts`, `vendor_responses`; extend `demand_allocations` for `vendor_backorder`
* `Sourcing::Eligibility`, `Sourcing::UnresolvedQuantity`
* `Sourcing::StartRun`, `Sourcing::CreateAttempt`, `Sourcing::SubmitAttempt`
* `Sourcing::SuggestVendors` (wraps `Purchasing::SuggestedVendorResolver`)
* Permissions seeds (`sourcing.*`)
* Verifier skeleton (`shelfstack:v0048:verify_sourcing`)
* Model and service tests for slice A

### Slice B — Vendor response effects

* `Sourcing::RecordVendorResponse` with quantity split validation
* Attempt/run status recalculation (derived from final responses)
* Confirmed + linked eligible PO line → `DemandAllocations::AllocateInboundPurchaseOrder`
* Accepted backorder → `DemandAllocations::AllocateVendorBackorder` (new)
* Extend `DemandLines::RecalculateAllocationStatus` for `vendor_backorder` active qty
* Demand cancel/expire → sourcing run/attempt cleanup cascade
* No `Inventory::Post`; no PO quantity lifecycle change

### Slice C — Buyer review and workflow UI

* `Sourcing::Cascade`, `Sourcing::CancelAttempt`, `Sourcing::CloseRun`
* `/sourcing` workspace (index + show)
* `/demand/:id` sourcing panel
* Item drawer: unresolved demand count + link only
* Stock consideration link/action from `needs_review` (link only — no new stock-consideration domain)
* Completion note, roadmap advance to v0.04-9

---

## Job

Introduce the v0.04 sourcing layer:

```text
Demand
  → Allocation
    → Sourcing run
      → Sourcing attempt
        → Vendor response
          → confirmed / backordered / unavailable / failed / cascaded
            → [v0.04-9] PO quantity model / receiving / fulfillment
```

v0.04-6 created demand lines.

v0.04-7 created allocations against current stock and existing inbound PO lines.

v0.04-8 models **vendor availability as attempts and responses**, not as an assumption made when staff decides to order.

---

## Purpose

v0.04-8 answers:

* Which unresolved demand needs vendor sourcing?
* Which vendor did staff try?
* Why was that vendor chosen?
* What quantity was requested from that vendor?
* What did the vendor say?
* How much was confirmed, backordered, unavailable, canceled, or failed?
* Should unresolved quantity cascade to another vendor?
* Which demand remains unresolved after sourcing responses?
* What should the buyer review next?

---

## Core rule

**Sourcing does not post inventory.**

```text
Sourcing runs, sourcing attempts, and vendor responses must not call Inventory::Post.

Vendor responses may create or update demand allocations only through approved v0.04 allocation services.

PO and receipt quantity lifecycle changes are deferred to v0.04-9.
```

| Layer | Affects `quantity_on_hand` | Affects `quantity_reserved` / `quantity_available` |
| ----- | -------------------------- | -------------------------------------------------- |
| Sourcing run / attempt / response | No | No |
| `on_hand` demand allocation | No (directly) | **Yes** (via cache rebuild) |
| `inbound_purchase_order` allocation | No | No |
| `vendor_backorder` allocation | No | **No** |

---

## Source documents

```text
AGENTS.md
docs/design/VERSION_0.04.md
docs/roadmap/v0.04-delivery-roadmap.md
docs/v0.04/v0.04-5-used-variant-rules/spec.md
docs/v0.04/v0.04-6-demand-foundation/spec.md
docs/v0.04/v0.04-7-allocations-and-reservations/spec.md
docs/v0.04/v0.04-7-allocations-and-reservations/data-model.md
docs/implementation/v0.04-7-completion.md
```

---

## Hard gates

1. **No inventory posting.** No sourcing service may call `Inventory::Post`.
2. **No receipt posting changes.** Receipt conversion belongs to v0.04-9.
3. **No full PO quantity lifecycle redesign.** Requested/confirmed/backordered/canceled/short/received PO quantity fields belong to v0.04-9.
4. **No automatic PO line creation.** v0.04-8 may link to existing eligible PO lines only.
5. **No automatic vendor cascade by default.** Cascade requires buyer/staff review unless a later spec adds vendor-level auto-cascade rules.
6. **No used-wanted vendor sourcing.** Used-wanted demand does not enter vendor sourcing.
7. **No unavailable used demand → new item conversion.**
8. **No legacy customer request, special order, TBO, or purchase request writes.**
9. **No legacy `purchase_order_line_allocations` writes.**
10. **No legacy `receipt_line_allocations` writes.**
11. **Product variant remains sourcing grain.**
12. **Demand line remains need grain.**
13. **Vendor response is not the same as receipt.** A vendor may confirm quantity that is later short, damaged, substituted, or canceled.
14. **Vendor response is not the same as invoice.** AP/invoice reconciliation remains out of scope.
15. **External API / EDI / Pubnet automation is deferred.** v0.04-8 supports manual response capture and prepares fields for later import/API channels.
16. **No substitute catalog workflow.** Record `substitute_offered` only; matching/creation/customer acceptance deferred.
17. **No new demand-line status for sourcing.** Sourcing state lives on runs/attempts/responses.

---

## Settled decisions

| Decision | v0.04-8 answer |
| -------- | -------------- |
| Auto-create PO lines? | **No** |
| Link to existing PO line? | **Yes — manual same-store/same-variant link** |
| Add `vendor_backorder` allocation kind? | **Yes** |
| Does `vendor_backorder` affect availability cache? | **No** |
| Does `vendor_backorder` count toward demand allocated status? | **Yes** |
| Auto-submit cascade? | **No** |
| Substitute workflow? | **Record only; matching/creation deferred** |
| Add sourcing status to demand lines? | **No** |
| Vendor responses append-only? | **Yes** |
| Manual response first? | **Yes** |
| Attempt status set manually by staff? | **No — derived from workflow + final response** |

---

## Legacy posture

| Legacy / existing concept | v0.04-8 behavior |
| ------------------------- | ---------------- |
| Customer request / special order / TBO ordering paths | Do not expand; v0.04 demand is source of truth |
| Existing purchase orders | May be linked to sourcing attempts where useful |
| Existing PO line quantity fields | Use current model only; do not redesign in v0.04-8 |
| Existing vendor/product source records | Preserve and extend for sourcing priority/snapshots |
| Legacy PO line allocations | Read-only if needed for availability math; no writes |
| Legacy receipt allocations | No v0.04-8 writes |
| Vendor availability assumptions | Replaced by explicit sourcing attempts and responses |

---

## Reuse (existing services)

| Existing | v0.04-8 use |
| -------- | ----------- |
| `Purchasing::SuggestedVendorResolver` | `Sourcing::SuggestVendors` — variant → product → preferred vendor chain |
| `DemandAllocations::AllocateInboundPurchaseOrder` | Confirmed response + linked eligible PO line |
| `DemandAllocations::InboundAvailability` | Eligibility for inbound link |
| `DemandAllocations::AllocationQuantities` | Base for demand allocation sums; extend for sourcing unresolved |
| `ProductVariants::OperationalPolicy` | Vendor-orderable / used-like gates |
| `DemandLines::RecalculateAllocationStatus` | Extend active allocation math for `vendor_backorder` |
| `DemandLines::Cancel` / `DemandLines::Expire` | Trigger sourcing cleanup cascade |

---

## Concepts

### Demand line

A committed customer or store need (v0.04-6).

**Demand status remains allocation/fulfillment state only:**

```text
captured
open
partially_allocated
allocated
fulfilled
canceled
expired
```

Sourcing state belongs to `sourcing_runs`, `sourcing_attempts`, and `vendor_responses` — not to `demand_lines.status`.

A demand line is **eligible for sourcing** when:

```text
status is open or partially_allocated
product_variant_id is present
unresolved_for_sourcing > 0
variant is vendor-orderable (ProductVariants::OperationalPolicy)
capture_intent is not used_wanted
demand is not terminal
```

### Unresolved demand quantity (normative)

**`Sourcing::UnresolvedQuantity`** is the authoritative service for how much quantity may enter sourcing.

```text
unresolved_for_sourcing =
  demand_line.quantity_requested
  - fulfilled_allocation_qty
  - active_on_hand_allocation_qty
  - active_inbound_purchase_order_allocation_qty
  - active_vendor_backorder_allocation_qty
  - in_flight_sourcing_attempt_qty
```

Floor at zero. Do not source more than `unresolved_for_sourcing` unless a later override rule is explicitly added.

**`in_flight_sourcing_attempt_qty`:**

```text
quantity on pending/submitted attempts
that has not been covered by a final vendor response
and has not been cascaded/canceled/closed
```

Rules:

* **Pending/submitted attempts** reduce quantity available for new attempts on the same demand line.
* **Final vendor response** closes the in-flight quantity on that attempt (quantity split must account for full `quantity_requested` on the attempt when `final_response = true`).
* **Cascaded attempts** — predecessor attempt quantity no longer counts as in-flight once marked `cascaded`.
* **Confirmed without linked PO line** does not become inbound allocation. It remains response evidence and moves the run/attempt to buyer review until staff links an eligible PO line (v0.04-8) or creates PO workflow in v0.04-9.

### `vendor_backorder` and demand allocation status

Active `vendor_backorder` allocations count toward **`active_allocated_quantity`** for demand-line allocation status recalculation, but they **do not** affect `inventory_balances.quantity_reserved` or `quantity_available`.

Example:

```text
Customer requested 2 copies; vendor backordered both.

demand_line.status = allocated
allocation_kind = vendor_backorder (×2 or one row qty 2)
inventory availability unchanged
```

This is consistent with v0.04-7: on-hand allocations affect the reserved/available cache; inbound and vendor-backorder allocations do not.

### Sourcing run

A sourcing run groups one or more vendor attempts for one demand line and one product variant.

**Active run statuses:**

```text
open
partially_resolved
needs_review
```

**Terminal run statuses:**

```text
resolved
canceled
```

One demand line may have multiple sourcing runs over time, but **only one active run** (`open`, `partially_resolved`, or `needs_review`) may exist per demand line unless an explicit override is added later.

Starting a new run when an active run exists → reject or require closing the prior run first.

### Sourcing attempt

A sourcing attempt is a request to one vendor for a quantity.

Examples:

```text
Try preferred wholesaler for 3 copies.
Try publisher direct for 1 copy.
Try sideline manufacturer for 6 units.
```

A sourcing attempt may be created from:

```text
manual buyer action
special order demand
manual TBO / buyer replenishment demand
notify/hold demand that cannot be satisfied from stock or inbound supply
failed prior sourcing attempt
cascade from prior attempt
```

**PO line linkage (v0.04-8):**

```text
v0.04-8 may link a sourcing attempt or vendor response to an existing purchase_order_line_id
when staff manually selects an eligible same-store, same-variant PO line.

v0.04-8 does not create purchase order headers, create purchase order lines,
or redesign PO line quantity lifecycle.
```

### Vendor response

A vendor response records what the vendor said about the attempt. **Append-only facts.**

Examples:

```text
confirmed 2
backordered 1
unavailable 1
canceled by vendor
no response / failed
substitute offered
```

Vendor response is operational evidence. It does not mean stock exists in the store.

**Attempt status is derived/cached workflow state** based on:

```text
pending/submitted workflow state
latest final vendor response
cascade/cancel/close actions
```

Staff must **not** manually set an attempt to `confirmed` or `backordered`. They record a vendor response; `Sourcing::RecordVendorResponse` derives attempt status.

---

## Sourcing lifecycle

### `sourcing_runs.status`

```text
open
partially_resolved
resolved
needs_review
canceled
```

| Status | Meaning |
| ------ | ------- |
| `open` | Run exists and unresolved quantity remains |
| `partially_resolved` | Some quantity confirmed/backordered/allocated, but some remains unresolved |
| `resolved` | All run quantity is resolved by allocation, cancellation, or staff closure |
| `needs_review` | Staff must decide whether to cascade, cancel, or leave unresolved |
| `canceled` | Sourcing run was canceled by staff |

### `sourcing_attempts.status`

```text
pending
submitted
confirmed
partially_confirmed
backordered
canceled
failed
cascaded
```

| Status | Meaning |
| ------ | ------- |
| `pending` | Attempt is prepared but not submitted |
| `submitted` | Vendor has been contacted / order sent / request submitted |
| `confirmed` | Full requested quantity confirmed (via final response) |
| `partially_confirmed` | Some confirmed, with backorder/canceled/unavailable/failed remainder |
| `backordered` | Vendor backordered full requested quantity |
| `canceled` | Vendor or staff canceled attempt |
| `failed` | No usable response, technical failure, or vendor unavailable |
| `cascaded` | Unresolved quantity was moved to another attempt |

### `vendor_responses.response_status`

```text
confirmed
partially_confirmed
backordered
unavailable
canceled
failed
substitute_offered
mixed
```

Optional response fields (when known): `expected_ship_date`, `expected_arrival_date`, `vendor_reference`, `message`.

---

## Quantity model

### Attempt quantity

Each sourcing attempt stores `quantity_requested`.

Vendor response stores:

```text
quantity_confirmed
quantity_backordered
quantity_unavailable
quantity_canceled
quantity_failed
quantity_substitute_offered
```

Response quantity sum must not exceed `sourcing_attempt.quantity_requested`.

For **final** responses (`final_response = true`), the response must account for the full attempted quantity:

```text
quantity_confirmed
+ quantity_backordered
+ quantity_unavailable
+ quantity_canceled
+ quantity_failed
+ quantity_substitute_offered
= quantity_requested
```

Allow draft/partial response entry only when `final_response = false`.

**Whole-attempt failure:** `response_status = failed` with `quantity_failed = quantity_requested` (other quantity buckets zero) is valid.

### Confirmed quantity

Confirmed quantity may create an `inbound_purchase_order` demand allocation **only when an eligible existing purchase order line is linked** at response time (or pre-linked on the attempt).

If there is no eligible PO line, confirmed quantity remains on the vendor response and the sourcing run moves to **`needs_review`**:

```text
Vendor confirmed quantity, but no eligible PO line exists.
Buyer must link PO line in v0.04-8 or create PO workflow in v0.04-9.
```

### Backordered quantity

Backordered quantity may create a **`vendor_backorder`** demand allocation when staff accepts the backorder wait.

A `vendor_backorder` allocation:

```text
claims vendor-backordered supply
does not affect inventory_balances.quantity_reserved
does not affect quantity_available
does not require purchase_order_line_id
must reference sourcing_attempt_id and/or vendor_response_id
may expire or be canceled
may later convert to inbound_purchase_order when vendor confirms shipment or PO lifecycle is implemented (v0.04-9+)
```

### Unavailable / canceled / failed quantity

Unavailable, canceled, or failed quantity returns to unresolved sourcing quantity and requires buyer review.

Staff may:

```text
cascade to next vendor
cancel that portion of demand
leave unresolved
link to stock consideration (Slice C — link/action only)
record manual note
```

### Substitute offered quantity

```text
substitute_offered quantity is recorded on vendor_response.

Original demand remains unresolved unless staff explicitly creates/matches a substitute variant in a later workflow.

v0.04-8 does not implement substitute catalog creation, product matching, or customer acceptance workflow.
```

---

## Vendor cascade policy

Default policy: **buyer-reviewed cascade**.

A vendor response may suggest unresolved quantity for cascade, but it must **not** automatically submit the next attempt.

### Cascade flow

```text
Attempt 1 submitted to vendor A
Vendor A confirms partial quantity
System records response
Confirmed quantity becomes inbound allocation if eligible PO line exists
Backordered quantity becomes vendor_backorder allocation if accepted
Unavailable quantity becomes unresolved
Run status becomes needs_review
Buyer selects next vendor
System creates Attempt 2 in pending status
Buyer submits Attempt 2
```

### Cascade source

Each cascaded attempt should reference:

```text
previous_sourcing_attempt_id
cascade_reason
created_by_user_id
created_at
```

### Cascade reasons

```text
unavailable
partial_confirmation
vendor_backorder_rejected
vendor_failed
manual_buyer_choice
substitute_rejected
```

---

## Sourcing hierarchy

Vendor suggestion order:

```text
product_variant_vendors
  → product_vendors
  → variant/product preferred_vendor
  → manual buyer override
```

Implement via `Purchasing::SuggestedVendorResolver` wrapped by `Sourcing::SuggestVendors`.

### Manual override

Allowed with audit. Record:

```text
vendor_id
override_reason
override_authorized_by_user_id
override_authorized_at
```

Requires `sourcing.vendor_override`.

---

## Vendor source snapshot (minimum v0.04-8)

Sourcing attempts snapshot operational vendor assumptions at **submit** time:

```text
vendor_id
vendor_name_snapshot
vendor_item_number_snapshot
source_level_snapshot       # variant_vendor | product_vendor | preferred | manual
source_record_type
source_record_id
vendor_priority_snapshot
estimated_unit_cost_cents_snapshot
returnability_snapshot
```

**Deferred** unless already cheap from existing source records:

```text
minimum_order_quantity_snapshot
lead_time_days_snapshot
availability_method_snapshot
```

Do not rely on live vendor-source records for historical attempts after submission.

---

## Intent-specific sourcing behavior

| Capture intent | Eligible for sourcing? | Notes |
| -------------- | ---------------------: | ----- |
| `hold` | yes, if `unresolved_for_sourcing > 0` and variant vendor-orderable | Source only remaining unresolved quantity |
| `notify` | yes, if staff chooses to source | Notify does not auto-source by default |
| `special_order` | yes | Primary customer-order sourcing path |
| `used_wanted` | **no** | Used demand waits for used intake/on-hand stock |
| `manual_tbo` | yes | Store replenishment sourcing |
| `buyer_replenishment` | yes | Store replenishment sourcing |
| `research` | no until matched | Must match product variant first |

---

## Demand cancel / expire integration

When `DemandLines::Cancel` or `DemandLines::Expire` transitions a demand line to terminal, **active sourcing runs** and **pending/submitted attempts** for that demand line must be canceled or closed through v0.04-8 sourcing services.

Do not leave active sourcing attempts for terminal demand.

Mirror v0.04-7 allocation cascade on cancel/expire:

```text
DemandLines::Cancel / Expire
  → Sourcing::CancelRun or Sourcing::CloseRun (as appropriate)
  → cancel pending/submitted attempts
  → audit events
  → no Inventory::Post
```

---

## Services

### `Sourcing::Eligibility`

Determines whether a demand line can be sourced. Reject:

```text
terminal demand
captured/research demand without variant
used_wanted demand
used-like / non-vendor-orderable variants
quantity with no unresolved sourcing need
active run already exists (unless override)
```

### `Sourcing::UnresolvedQuantity`

Authoritative unresolved quantity for sourcing (see [Unresolved demand quantity](#unresolved-demand-quantity-normative)).

### `Sourcing::StartRun`

Creates a sourcing run for eligible demand.

Rules:

```text
one active run per demand line by default
quantity_requested on run cannot exceed unresolved_for_sourcing at start
audit event required
```

### `Sourcing::SuggestVendors`

Returns candidate vendors in priority order via `Purchasing::SuggestedVendorResolver`.

Include warnings:

```text
no vendor source
inactive vendor
missing vendor item number
minimum order quantity not met (when data available)
used variant not vendor-orderable
```

### `Sourcing::CreateAttempt`

Creates a pending attempt.

Rules:

```text
attempt quantity cannot exceed run unresolved quantity
vendor must be active
variant must be vendor-orderable
manual override requires reason + sourcing.vendor_override
snapshots vendor source fields on submit (not create)
```

### `Sourcing::SubmitAttempt`

Moves attempt from `pending` to `submitted`.

Rules:

```text
submitted_by_user_id required
submitted_at required
snapshots vendor source fields at submit
audit event required
does not assume availability
does not create inventory allocation
does not post inventory
```

### `Sourcing::RecordVendorResponse`

Records vendor response and applies response effects.

Effects:

```text
create vendor_response (append-only)
derive sourcing_attempt status from final response
create inbound_purchase_order allocation for confirmed qty only if eligible PO line linked
create vendor_backorder allocation for accepted backorder qty
mark unresolved qty for buyer review when needed
recalculate sourcing_run status
call DemandLines::RecalculateAllocationStatus when allocations created
audit response and quantity split
```

### `Sourcing::Cascade`

Creates next attempt from unresolved quantity.

Rules:

```text
previous attempt must have unresolved/cascade-eligible quantity
buyer action required (sourcing.attempts.cascade)
new attempt starts pending — not auto-submitted
previous attempt may become cascaded
audit event required
```

### `Sourcing::CancelAttempt`

Cancels pending/submitted attempt.

Rules:

```text
requires reason
does not delete vendor response history
in-flight quantity returns to unresolved pool
audit event required
```

### `Sourcing::CloseRun` / `Sourcing::CancelRun`

Closes or cancels sourcing run.

Rules:

```text
resolved or canceled terminal states
requires reason when unresolved quantity remains on close
audit event required
```

### `DemandAllocations::AllocateVendorBackorder` (new)

Creates active `vendor_backorder` allocation linked to sourcing attempt/response.

Rules:

```text
does not call Inventory::Post
does not rebuild on-hand availability cache
calls DemandLines::RecalculateAllocationStatus
audit demand_allocation.vendor_backorder_created
```

---

## UI scope

### `/sourcing` (Slice C)

Primary buyer-facing sourcing workspace.

Filters:

```text
needs_review
open
submitted
partially_resolved
vendor
capture_intent
customer demand vs store replenishment
```

### `/sourcing/:id` (Slice C)

Run detail:

```text
demand summary
unresolved_for_sourcing
allocation summary
attempt timeline
vendor responses
cascade suggestions
audit
```

Actions:

```text
create attempt
submit attempt
record response
link PO line
cascade
cancel attempt
close run
stock consideration link (needs_review)
```

### `/demand/:id` (Slice C)

Sourcing panel:

```text
unresolved_for_sourcing
active sourcing run
attempt status
latest vendor response
start sourcing action
```

### Item drawer / item operations

Do not add complex sourcing UI in v0.04-8. At most:

```text
Show unresolved demand count
Show active sourcing count
Link to /sourcing or /demand
```

### Vendor/source setup

v0.04-8 may expose minimal source-priority fields if necessary; no full vendor management redesign.

---

## Audit events

```text
sourcing_run.created
sourcing_run.status_changed
sourcing_run.closed
sourcing_run.canceled
sourcing_attempt.created
sourcing_attempt.submitted
sourcing_attempt.canceled
sourcing_attempt.cascaded
vendor_response.recorded
vendor_response.quantity_split
demand_allocation.vendor_backorder_created
sourcing.manual_vendor_override
```

Audit details should include:

```text
demand_number
sourcing_run_id
sourcing_attempt_id
vendor_id
quantity_requested
quantity_confirmed
quantity_backordered
quantity_unavailable
quantity_canceled
quantity_failed
cascade_reason
manual_override_reason
```

---

## Permissions

Seed idempotent permissions:

```text
sourcing.access
sourcing.runs.create
sourcing.attempts.create
sourcing.attempts.submit
sourcing.responses.record
sourcing.attempts.cascade
sourcing.attempts.cancel
sourcing.runs.close
sourcing.vendor_override
```

Optional later:

```text
sourcing.import_response
sourcing.api_response
```

---

## Verification

Add rake:

```text
shelfstack:v0048:verify_sourcing
alias: shelfstack:v0048_verify_sourcing
```

STRICT checks:

```text
sourcing_runs table exists
sourcing_attempts table exists
vendor_responses table exists
demand_allocations supports vendor_backorder
v0.04-8 sourcing services do not call Inventory::Post
v0.04-8 sourcing services do not write legacy customer request / special order / TBO tables
v0.04-8 sourcing services do not write legacy purchase_order_line_allocations or receipt_line_allocations
used_wanted demand has zero sourcing attempts
vendor_backorder allocations do not affect inventory_balances.quantity_reserved
vendor response quantity sums do not exceed attempt quantity
final response quantity split equals attempt quantity_requested
confirmed response creates inbound allocation only when eligible PO line linked
confirmed response without PO line does not create inbound allocation
cascade-created attempts are pending, not auto-submitted
manual vendor overrides have reason + actor + audit
demand cancel/expire cancels or closes active sourcing runs
```

---

## Definition of done

### Slice A

1. Schema for `sourcing_runs`, `sourcing_attempts`, `vendor_responses`; `demand_allocations` extended for `vendor_backorder` FK columns.
2. Eligibility blocks terminal, captured, used-wanted, and non-vendor-orderable demand.
3. `Sourcing::UnresolvedQuantity` is authoritative and tested.
4. Start run, create attempt, submit attempt services with audit.
5. Permissions seeded; slice A tests pass; verifier skeleton passes non-strict checks.

### Slice B

6. `RecordVendorResponse` with quantity split and derived attempt status.
7. Confirmed + linked PO → inbound allocation via existing allocate service.
8. Accepted backorder → `vendor_backorder` allocation; no availability cache change.
9. `vendor_backorder` counts in `RecalculateAllocationStatus` active allocated qty.
10. Demand cancel/expire sourcing cleanup.
11. Slice B service tests pass; STRICT verifier inventory/legacy checks pass.

### Slice C

12. Cascade, cancel attempt, close/cancel run services.
13. `/sourcing` workspace and `/demand` sourcing panel.
14. Permissions enforced on all mutating actions.
15. Full Rails test suite passes.
16. Completion note written; roadmap advances to v0.04-9.

---

## Manual smoke (end-to-end)

1. Create special-order demand for a new vendor-orderable variant with no stock.
2. Start sourcing run.
3. Create attempt for preferred vendor.
4. Submit attempt.
5. Record partial final response: confirmed 1, backordered 1, unavailable 1.
6. Confirm:
   * attempt becomes `partially_confirmed`
   * confirmed quantity creates inbound allocation **only if** eligible PO line linked
   * backordered quantity creates `vendor_backorder` allocation when accepted
   * unavailable quantity leaves run `needs_review`
7. Cascade unavailable quantity to second vendor.
8. Confirm second attempt starts `pending`, not submitted.
9. Cancel demand line; confirm active sourcing run/attempts closed.
10. Run `STRICT=1 bin/rails shelfstack:v0048:verify_sourcing`.
11. Confirm no inventory ledger entries were created.

---

## Explicit deferrals

| Capability | Defer to |
| ---------- | -------- |
| PO line creation / PO quantity lifecycle fields | v0.04-9 |
| Receipt allocation conversion | v0.04-9 |
| `vendor_backorder` → inbound conversion on ship confirm | v0.04-9+ |
| Substitute match / catalog create / customer acceptance | Later |
| EDI / API / Pubnet response import | Later (`sourcing.import_response`) |
| Automatic vendor cascade | Later vendor-profile rules |
| Full stock consideration domain | Later (v0.04-8 link only) |
| Legacy route/table removal | v0.04-10 |
