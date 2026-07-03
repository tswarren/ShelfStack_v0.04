# v0.04-13 Demand-to-Fulfillment Continuity — Test Plan

## Status

**Planned** — companion to [spec.md](spec.md) and [data-model.md](data-model.md).

### Milestone tiers

* **MVP (`V00413_SLICE=final`)** — store-stock manual ordering; required for v0.04-13 merge.
* **Readiness (`V00413_SLICE=readiness`)** — vendor-direct conversion, external references, fulfill UI; optional within v0.04-13 or in a **later roadmap cycle** (not assumed to follow v0.04-13 immediately).

---

## Merge gate (MVP — milestone complete)

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails db:seed
./dev/rails-docker bin/rails test

docker compose exec -e STRICT=1 web bin/rails shelfstack:v0046:verify_demand_foundation
docker compose exec -e STRICT=1 web bin/rails shelfstack:v0047:verify_allocations
docker compose exec -e STRICT=1 web bin/rails shelfstack:v0048:verify_sourcing
docker compose exec -e STRICT=1 web bin/rails shelfstack:v0049:verify_po_receiving
docker compose exec -e V00410_PHASE=g2 -e STRICT=1 web bin/rails shelfstack:v00410:verify_legacy_ordering_retired
docker compose exec -e STRICT=1 web bin/rails shelfstack:v00411:verify_documentation_schema_cleanup
docker compose exec -e V00412_SLICE=final -e STRICT=1 web bin/rails shelfstack:v00412:verify_demand_ordering_ux
docker compose exec -e V00413_SLICE=final -e STRICT=1 web bin/rails shelfstack:v00413:verify_demand_fulfillment_continuity
```

### Readiness gate (optional — not required for v0.04-13 merge)

Run when readiness slices (B, E2, R) ship — may be post-merge or a later milestone:

```bash
docker compose exec -e V00413_SLICE=readiness -e STRICT=1 web bin/rails shelfstack:v00413:verify_demand_fulfillment_continuity
```

Per-PR: run prior verifiers + `V00413_SLICE=<slice>` for current slice.

---

## v00413 slice stages

| Stage | Scope |
| ----- | ----- |
| `slice_0` | Spec bundle, data-model, test-plan, verifier skeleton |
| `slice_a` | Vendor capability columns, resolver, setup UI, seeds |
| `slice_c` | `Sourcing::NextActionPresenter`, attempt capability snapshots |
| `slice_d` | `purchase_order_line_demand_plans`, create from demand PO bridge |
| `slice_d2` | PO `order_purpose`, `ship_to_type`, gates; `vendor_direct_fulfillment` in allocation enum |
| `slice_e` | **Inbound conversion only** (`ConvertDemandCoveragePlansToInbound`) |
| `slice_f` | Receipt origin fields, vendor-shipment entry |
| `slice_g` | `receipt_line_matches`, suggest/apply, match UI |
| `slice_h` | Pre-post demand impact preview (store path) |
| `final` | MVP STRICT checks — **milestone merge gate** |
| `slice_b` | `external_references` + attach/find/idempotency (**readiness**) |
| `slice_e2` | Vendor-direct conversion services (**readiness**) |
| `slice_r` | `ship_to_snapshot`, `FulfillVendorDirect`, `receipt_cartons` (**readiness**) |
| `readiness` | Readiness STRICT checks — optional; may run after merge or later cycle |

---

## Verifier checks

### MVP tier (`V00413_SLICE=final`) — required for merge

1. Vendor capability/channel columns present with controlled enums
2. Capability snapshot columns on `sourcing_attempts`
3. `purchase_order_line_demand_plans` table present with `fulfillment_route`
4. Planned coverage does not affect `InboundAvailability` / availability cache
5. PO `order_purpose` and `ship_to_type` present; mixed PO rejected
6. `fulfillment_route = inbound_to_store` converts to `inbound_purchase_order` only when eligible
7. Customer-direct PO / `vendor_direct_to_customer` plan **gated** — not receivable via store receipt; no inbound allocation; no inventory post
8. `vendor_direct_fulfillment` present in allocation kind enum (schema gate)
9. Receipt origin fields present
10. Shipment-first receiving does not require header PO
11. `receipt_line_matches` supports multi-PO shipment
12. Receipt posting posts only accepted quantity (v0.04-9 regression)
13. No writes to retired v0.03 ordering/allocation tables
14. Idempotency on inbound conversion and match application services
15. Required MVP audit event names registered

Advisory (WARN, not FAIL): `receipt_cartons` absent; `vendor_availability_snapshots` absent; `external_references` absent until readiness.

### Readiness tier (`V00413_SLICE=readiness`) — optional

1. `fulfillment_route = vendor_direct_to_customer` converts to `vendor_direct_fulfillment` only
2. `vendor_direct_fulfillment` excluded from inventory post and inbound→on_hand conversion (service-level)
3. `external_references` table and uniqueness index present
4. Customer-direct PO requires `ship_to_snapshot` on submit
5. `FulfillVendorDirect` completes demand without inventory
6. Readiness audit events registered

---

## Test matrix

Tests are grouped by **tier**. Only **MVP** sections are required for `V00413_SLICE=final` milestone merge.

### MVP — model tests

* Vendor capability enum validation
* `PurchaseOrderLineDemandPlan` — fulfillment_route, status, store/variant consistency
* PO rejects `order_purpose = mixed`
* `ReceiptLineMatch` quantity and status validation
* `DemandAllocation` — `vendor_direct_fulfillment` enum present; validations defined (row creation deferred to readiness)

### Readiness — model tests

* PO `ship_to_type = customer` requires `ship_to_snapshot` on submit (slice R)
* `ExternalReference` uniqueness and polymorphic referencable

### MVP — service tests

#### Vendor capability

* `Vendors::CapabilityResolver` returns vendor defaults
* Resolver interface accepts optional product/vendor args without error (override deferred)

#### Sourcing

* `Sourcing::NextActionPresenter` — check_before_order → “Check availability”
* `Sourcing::NextActionPresenter` — order_to_confirm → “Order to confirm”
* `Sourcing::NextActionPresenter` — manual_review → “Record manual response”
* Submit attempt snapshots capability fields

#### Planned coverage

* `CreateDemandCoveragePlans` from `DemandCoveragePlanner` output
* Idempotent create by demand line + PO line + idempotency key
* Planned rows do not change `quantity_available`
* `ReleaseDemandCoveragePlan` — customer coverage requires reason
* Draft PO qty reduction triggers reconciliation requirement

#### Inbound conversion (Slice E)

* `ConvertDemandCoveragePlansToInbound` — only `inbound_to_store`, only when PO eligible
* Retry inbound conversion does not duplicate allocations
* Plan row links `converted_to_demand_allocation_id`

#### Receiving

* `PoLineMatchCandidates` — same vendor/store/variant; open to receive > 0
* Candidate sort — customer fulfillment before shelf replenishment
* `SuggestReceiptLineMatches` — multi-PO split quantities
* `ApplyReceiptLineMatches` — idempotent; sum matched ≤ accepted
* `ReceiptDemandImpactPreview` — customer-ready vs shelf split

### Readiness — service tests

#### Vendor-direct (slices E2/R)

* `ConvertDemandCoveragePlansToVendorDirect` — only `vendor_direct_to_customer`
* `AllocateVendorDirectFulfillment` — no availability cache impact
* `FulfillVendorDirect` — terminalizes allocation and demand line; attaches tracking ref
* Fulfill does not call `Inventory::Post`

#### External references (slice B)

* `ExternalReferences::Attach` — creates row
* `FindDuplicate` — detects active duplicate
* `IdempotencyGuard` — blocks duplicate processing

### MVP — integration tests

* Manual vendor: demand → draft PO → planned coverage visible on PO line
* Holding order: draft PO retains plans without inbound allocation
* Submit stock PO → plans convert to inbound allocations
* Vendor response updates PO buckets; receipt matches multi-PO shipment
* Post receipt → inventory + inbound→on_hand conversion
* Pre-post preview shows customer names

#### Gates and regression

* Customer-direct planned coverage on draft PO does not create inbound allocation
* Attempt to receive against customer-direct PO is rejected
* Availability evidence does not create allocation
* Customer-direct shipment notice (simulated manual) does not create receipt
* Unmatched accepted line on vendor shipment
* Rejected-not-replaceable and closed-short paths (v0.04-9 regression)
* Legacy v0.04-12 demand ordering UX flows still pass

### Readiness — integration tests

* Vendor with `vendor_direct_to_customer` supported
* Create customer-direct PO from demand with ship-to snapshot
* Submit → `vendor_direct_fulfillment` allocation; not inbound
* Store receipt workflow blocked for customer-direct PO
* Manual fulfill with tracking → demand fulfilled; inventory unchanged
* External reference duplicate prevention

### MVP — authorization tests

* Vendor capability setup permissions
* Demand plan release permission
* Receipt match override permission
* Vendor-direct fulfill permission *(readiness)*

### MVP — seed tests

* Reference wholesaler vendor seed (Ingram-like profile) idempotent
* Default vendors backfilled with manual capabilities

---

## Slice acceptance criteria

### Slice A

* Vendors editable in Setup with workflow + channels + fulfillment methods
* Seed includes at least one wholesaler profile with `consolidated_shipment`, `holding_order`, optional `vendor_direct_to_customer`

### Slice C

* Sourcing queue shows capability-driven next action
* No business state change from presenter alone

### Slice D + D2 (MVP)

* Build PO from demand creates plan rows with correct `fulfillment_route` and `coverage_kind`
* PO show displays planned coverage per line
* Customer-direct PO blocked from store receiving (gate); ship-to snapshot deferred to readiness

### Slice E (MVP — inbound only)

* Submit stock PO triggers inbound conversion for `inbound_to_store` plans only
* Draft PO never converts prematurely
* Customer-direct plans remain unconverted until readiness slice E2

### Slice B (readiness)

* Staff can attach tracking number external ref to PO, receipt, demand allocation

### Slice E2 + R (readiness)

* Submit customer-direct PO converts to `vendor_direct_fulfillment`
* Customer-direct PO requires `ship_to_snapshot` on submit
* `FulfillVendorDirect` from demand detail
* `receipt_cartons` table migrates cleanly (empty UI OK)

### Slice F + G

* New vendor shipment receipt without header PO
* Match panel suggests multi-PO lines; staff confirms matches
* PostReceipt uses confirmed matches

### Slice H (MVP)

* Pre-post preview distinguishes customer-ready vs shelf stock

### Slice H / R (readiness)

* Customer-direct PO show shows fulfillment preview, not receipt impact

---

## Regression scope

Always run:

```text
v0.04-6 demand foundation
v0.04-7 allocations
v0.04-8 sourcing
v0.04-9 PO/receiving
v0.04-10 legacy ordering retired
v0.04-12 demand ordering UX
```

Focus regression files:

```text
test/services/purchasing/build_purchase_order_from_demand_test.rb
test/services/purchasing/add_demand_to_purchase_order_test.rb
test/services/purchasing/post_receipt_test.rb
test/services/demand_allocations/convert_inbound_from_receipt_test.rb
test/services/sourcing/record_vendor_response_test.rb
test/presenters/demand/demand_line_workflow_presenter_test.rb
```

---

## Out of test scope (deferred)

* X12 parse/generate round-trip
* ipage / FTP / web service import
* Carton license-plate scan UI
* Mixed-destination PO
* `vendor_availability_snapshots` population
* Automatic vendor cascade
