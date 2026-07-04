# v0.04-13 Demand-to-Fulfillment Continuity and Vendor Integration Readiness — Functional Specification

## Status

**Complete in PR 18** — MVP store-stock path implemented; readiness slices remain deferred.

Companion documents:

* [data-model.md](data-model.md) — schema additions and enum vocabulary
* [test-plan.md](test-plan.md) — slice acceptance, integration tests, merge gate
* `docs/implementation/v0.04-13-completion.md` (created at milestone close)

Historical note: early design scratch lived in local `docs/drafts_temp/` (gitignored); this bundle is the authoritative spec.

---

## Relationship to v0.04-12

v0.04-12 was **Demand Ordering UX completion** — staff-facing flows on the existing v0.04-6–10 backend, with **no core schema redesign** and draft PO demand context at audit level only.

v0.04-13 is the **follow-on MVP** for manual, non-EDI ordering continuity. It is **not** a patch or extension of v0.04-12. Do not fold v0.04-13 scope back into v0.04-12 naming or verifiers.

```text
v0.04-12 = Demand Ordering UX completion
v0.04-13 = Manual Demand-to-Fulfillment Continuity MVP
post-v0.04-13 = vendor integration, EDI, Direct-to-Home automation, or other roadmap work (TBD)
```

### Roadmap note

Readiness-tier and deferred items in this spec (vendor-direct conversion UI, `external_references` management, ipage/EDI automation, carton scan, and similar) are **documented for future work** but **do not assume the next milestone after v0.04-13**. The project may schedule Phase 10-E, v0.04-3 product groups, catalog cleanup, or other priorities before any vendor-integration milestone. When integration work resumes, it should **call the same domain services** defined here — not redesign demand, PO, receiving, or fulfillment semantics.

---

## Job

v0.04-13 makes ShelfStack’s manual **store-stock** demand-to-ordering-to-receiving workflow continuous for staff, and **models** (but does not fully productize) vendor-direct-to-customer fulfillment so future integrations cannot mis-post inventory.

This milestone does **not** implement X12, SFTP, EDI parsing/generation, vendor API clients, automated polling, or invoice/AP processing. It defines domain semantics, durable traceability, and manual-first UX so future integrations call the same services.

**MVP staff value** is the `inbound_to_store` path (holding orders, planned draft PO coverage, consolidated receiving). Vendor-direct is **architecture readiness** — schema, gates, and optional readiness slices — not required for ordinary non-EDI ordering to work.

---

## Example walkthrough (MVP — customer special order, vendor ships to store)

1. Staff captures demand for one customer (special order / hold).
2. Buyer sees the line in the sourcing queue with a vendor-appropriate next action.
3. Buyer adds demand to a draft wholesaler PO (holding order).
4. PO line shows **planned customer coverage** — durable rows in `purchase_order_line_demand_plans`, not audit-only text.
5. Buyer submits the PO when ready.
6. Planned `inbound_to_store` coverage converts to **on order** (`inbound_purchase_order` allocation) — not before submit/eligibility.
7. Vendor shipment arrives covering several POs in one box.
8. Receiver starts **Receive vendor shipment**, scans the ISBN.
9. ShelfStack suggests PO line matches; **customer demand sorts first**.
10. Receiver confirms matches and posts; only **accepted** quantity hits inventory.
11. Inbound allocation converts to **on hand**; demand shows ready for pickup.
12. Staff completes pickup at POS.

Shelf replenishment on the same PO line follows the same path but sorts lower in match priority and becomes shelf stock instead of a named pickup.

---

## Staff-facing supply states

Frontline labels map to persistence as follows. Do not treat **Planned on order** or draft PO quantity as committed supply.

| Staff label | Meaning | Persistence |
| ----------- | ------- | ----------- |
| **Unallocated** | Need exists; no active claim on supply | No active `demand_allocations`; may have open sourcing |
| **Planned on order** | Draft PO line covers this need; not committed yet | Active `purchase_order_line_demand_plans` (`status = planned`) |
| **On order** | Committed inbound supply from a submitted/eligible PO | Active `demand_allocations`, `allocation_kind = inbound_purchase_order` |
| **Vendor backorder** | Vendor confirmed backorder; waiting on vendor | Active `demand_allocations`, `allocation_kind = vendor_backorder` |
| **On hand** | Stock claimed for this demand at the store | Active `demand_allocations`, `allocation_kind = on_hand` |
| **Direct ship to customer** | Vendor will ship to customer; no store inventory *(readiness tier)* | Active `demand_allocations`, `allocation_kind = vendor_direct_fulfillment` |

**Planned on order** must not affect `InboundAvailability`, `quantity_available`, or inventory ledger. v0.04-12 used audit-derived “planned” language; v0.04-13 makes planned coverage durable via demand plans.

See also [data-model.md — Staff display model](data-model.md#staff-display-model-extends-v004-12).

### Target workflows

**Store stock path (default):**

```text
DemandLine
  → sourcing / vendor capability workflow
  → vendor response or order-to-confirm process
  → draft PO planned coverage (fulfillment_route = inbound_to_store)
  → submitted/eligible PO inbound allocation
  → vendor shipment to store (may span multiple POs)
  → receipt line matching
  → receipt posting
  → inventory posting
  → inbound allocation conversion
  → on-hand reservation / shelf stock
  → POS pickup or normal sale
```

**Vendor-direct-to-customer path (e.g. Ingram Direct to Home) — readiness tier; not required for MVP merge:**

```text
DemandLine
  → sourcing
  → draft PO planned coverage (fulfillment_route = vendor_direct_to_customer)
  → submitted PO (ship_to_type = customer)
  → vendor_direct_fulfillment allocation   # readiness slice
  → vendor ships to customer (tracking attached)
  → staff confirms fulfillment             # readiness slice
  → demand fulfilled
  → no store receipt, no inventory posting
```

---

## Purpose

v0.04-13 answers:

* How does ShelfStack know whether a vendor supports stock checks, order-to-confirm, manual review, ipage, EDI, API, portal, email, Direct to Home, or holding-order behavior?
* How does demand move into a draft PO without pretending the draft PO is committed inbound supply?
* How can staff see which demand a draft PO line is intended to cover?
* How does a submitted PO become active inbound supply **or** vendor-direct fulfillment — not both?
* How can receiving start from a vendor shipment instead of a single PO?
* How can one vendor shipment be matched across multiple open POs?
* How can receiving prioritize customer demand, backorders, and shelf replenishment?
* How do we make future vendor documents safe to import without changing the core domain model?
* How do we prevent future EDI transport state from being confused with business state?

---

## Resolved decisions

| Decision | Choice |
| -------- | ------ |
| Milestone type | **Follow-on MVP** after v0.04-12 — not UX polish within v0.04-12 |
| Milestone framing | **Demand-to-fulfillment**, not receiving-only |
| Manual-first | All **MVP** paths operable without EDI/API/ipage automation |
| Draft PO coverage | Durable `purchase_order_line_demand_plans` — not audit-only |
| Planned vs committed | Draft plans do not affect `InboundAvailability`; conversion on PO submit/eligibility only |
| Fulfillment route | `inbound_to_store` (default) vs `vendor_direct_to_customer` on demand plans — **enum in MVP** |
| Vendor-direct modeling | `vendor_direct_fulfillment` allocation kind — **schema + gates in MVP**; conversion + fulfill UI in **readiness** |
| PO destination | `ship_to_type` / `order_purpose` — **gates in MVP**; customer-direct **submit** + `ship_to_snapshot` in **readiness** |
| Multi-PO receiving | `receipt_line_matches` — **MVP** (consolidated shipments) |
| External references | Thin table + services — **readiness**; not blocking MVP merge |
| Capability scope | Vendor-level fields in MVP; resolver interface accepts overrides for later |
| Availability evidence | Capability enums + manual/placeholder UI; cache table deferred |
| Carton/license-plate | Schema reserved; scan workflow deferred |
| Verifier | `shelfstack:v00413:verify_demand_fulfillment_continuity` — MVP tier required for merge; readiness checks may WARN |
| Post-MVP sequencing | Integration/automation milestones **TBD** — not assumed to be v0.04-14 immediately |
| Retired tables | Do not reintroduce v0.03 ordering/allocation tables |

### PO bridge commit point rule (carried from v0.04-12)

Demand-to-PO may record planned demand coverage on a draft PO, but must **not** create active `inbound_purchase_order` allocations until the PO line passes existing `DemandAllocations::InboundAvailability` rules (typically submitted/ordered PO, not draft).

### Vendor-direct commit point rule (new)

Demand plans with `fulfillment_route = vendor_direct_to_customer` must **not** create `inbound_purchase_order` allocations. They must never post store inventory or require a store receipt. Customer-direct POs must be blocked from store receiving workflows (**MVP gate**).

When readiness slices ship, those plans convert to `vendor_direct_fulfillment` allocations only (never inbound). Until then, staff may still create customer-direct planned coverage and POs; conversion and fulfill services are optional readiness work within or after v0.04-13.

---

## Non-goals

v0.04-13 does **not** include:

```text
X12 parsing or generation
SFTP mailbox polling
850 / 855 / 856 / 846 / 810 import or export
997 / 999 technical acknowledgment handling
ipage / Stock Check / FTP / web service automation
Vendor API integration or portal scraping
Automatic vendor cascade
Invoice payment or accounts payable
GL posting
Landed cost / freight allocation
Posted receipt reversal
Full reporting rewrite
Mixed-destination purchase orders
Full Direct to Home UI (labels, carrier rates, customer notifications)
Carton/license-plate scan receiving workflow
vendor_availability_snapshots cache table (reserved in data-model only)
```

---

## Core principles

### 1. Manual and integrated workflows use the same domain services

Future integrations must not become a parallel ordering system. Manual staff actions and future vendor documents must call the same services:

```text
DemandAllocations::AllocateInboundPurchaseOrder
DemandAllocations::AllocateVendorDirectFulfillment
Sourcing::RecordVendorResponse
Purchasing::SyncPoLineVendorQuantitiesFromSourcing
Purchasing::CreateDemandCoveragePlans
Purchasing::ConvertDemandCoveragePlansToInbound
Purchasing::ConvertDemandCoveragePlansToVendorDirect
Purchasing::BuildPurchaseOrderFromDemand
Purchasing::AddDemandToPurchaseOrder
Receiving::SuggestReceiptLineMatches
Receiving::ApplyReceiptLineMatches
Purchasing::PostReceipt
DemandAllocations::ConvertInboundFromReceipt
DemandAllocations::FulfillVendorDirect
Inventory::Post
ExternalReferences::Attach
```

### 2. Document semantics must remain separate

| Concept | Meaning | Must not be treated as |
| ------- | ------- | ---------------------- |
| Availability evidence | Vendor says stock may be available | Reservation, inbound supply, or inventory |
| Purchase order submission | Store asks vendor to supply goods | Vendor acceptance |
| Technical acknowledgment | File/message syntactically received | Business acceptance |
| Vendor acknowledgment | Vendor confirms, backorders, cancels, or rejects | Physical receipt or customer delivery |
| Shipment notice (store) | Vendor says goods are shipping to store | Posted receipt |
| Shipment notice (customer) | Vendor says goods ship to customer | Store receipt or inventory |
| Invoice | Vendor bills for goods/services | Physical receipt or inventory |
| Physical receipt | Store counts and accepts goods | Invoice approval |
| Vendor-direct fulfillment | Vendor ships to customer | Store inventory |

### 3. Inventory posting remains unchanged

Only accepted receipt quantity on **store-destination** receipts posts inventory via `Purchasing::PostReceipt` → `Inventory::Post`. Vendor-direct fulfillment must not call `Inventory::Post`.

### 4. Draft PO coverage is not inbound supply

```text
Draft PO line + planned demand plan
  → planned coverage only (visible, durable, no availability impact)

Submitted/eligible PO line + inbound_to_store plan
  → may create inbound_purchase_order allocation

Submitted/eligible PO line + vendor_direct_to_customer plan
  → may create vendor_direct_fulfillment allocation
```

### 5. Shipment-first receiving (store destination)

Receiving starts from what physically arrived or is expected from a vendor. A receipt may involve one PO, multiple POs, no PO, overages, shortages, substitutions, damaged items, or wrong items. Staff must not be required to know which PO a vendor fulfilled before beginning receiving.

### 6. Not all vendor orders are store receipts

Wholesalers such as Ingram may support **Direct to Home** (vendor ships to customer). That path uses fulfillment and tracking, not receiving and inventory.

---

## Vendor capability and channel model

### Operational workflow

Add to `vendors`:

```text
availability_workflow:
  check_before_order
  order_to_confirm
  manual_review
```

| Value | Meaning |
| ----- | ------- |
| `check_before_order` | Staff or integration may check availability before order submission |
| `order_to_confirm` | Store submits first; availability learned afterward |
| `manual_review` | Buyer manually determines next step |

### Communication channels (vendor-neutral, Ingram-aware values)

```text
availability_source:
  manual, ipage, stock_check_app, data_services_web_service, data_services_ftp,
  portal, email, file_import, edi_x12, api, none

order_submission_method:
  manual, ipage, portal, email, file_export, edi_x12, api

acknowledgment_method:
  manual, portal, email, file_import, edi_x12, api, none

shipment_notice_method:
  manual, portal, email, file_import, edi_x12, api, none

invoice_method:
  manual, email, paper, file_import, edi_x12, api, none

technical_acknowledgment_method:
  none, edi_x12, api
```

### Fulfillment methods supported

```text
fulfillment_methods_supported (array or normalized join):
  ship_to_store
  vendor_direct_to_customer
  consolidated_shipment
  holding_order
```

These describe how ShelfStack may eventually communicate with the vendor. They do not implement integration.

### Capability resolution

Minimum v0.04-13: store fields on `vendors` only.

Recommended future resolution order (interface only in MVP):

```text
product_variant_vendor → product_vendor → vendor → system default
```

### Capability snapshots

When a sourcing attempt is submitted, snapshot resolved capability on `sourcing_attempts` (workflow, channel fields, `fulfillment_methods_supported_snapshot`, `vendor_capability_source_snapshot`). Historical attempts must not depend on live vendor settings.

---

## Vendor-direct fulfillment

Some vendors support customer-direct fulfillment (Ingram Direct to Home is the reference case). **Model the seam in MVP; productize the workflow in readiness or a later milestone.**

### Delivery tier summary

| Piece | Tier |
| ----- | ---- |
| `fulfillment_route` enum on demand plans | **MVP** |
| PO `ship_to_type` / `order_purpose`; block customer PO from store receiving | **MVP** (gates) |
| `vendor_direct_fulfillment` allocation kind in schema | **MVP** (schema) |
| `ConvertDemandCoveragePlansToVendorDirect` + submit conversion | **Readiness** |
| `ship_to_snapshot` on customer-direct POs | **Readiness** |
| `FulfillVendorDirect` + minimal demand/PO UI | **Readiness** |
| Full Direct-to-Home UI, tracking, customer notifications | **Deferred** (future milestone — not necessarily next after v0.04-13) |

Ordinary non-EDI ordering (holding orders, stock POs, consolidated receiving) uses only `inbound_to_store`.

### Fulfillment route

On `purchase_order_line_demand_plans`:

```text
fulfillment_route:
  inbound_to_store              # default
  vendor_direct_to_customer
```

### PO destination

On `purchase_orders`:

```text
order_purpose:
  stock_order
  customer_direct_fulfillment
  mixed                        # enum present; MVP rejects mixed POs at validation

ship_to_type:
  store
  customer
  third_party                  # reserved
```

MVP rule: **one ship_to_type per PO**. Customer-direct fulfillment orders are separate POs from stock replenishment.

### Ship-to address snapshots

Column: `ship_to_snapshot` JSONB on `purchase_orders` (nullable in MVP).

Normative keys: name, address lines, city, region, postal, country, phone, email, `gift_message`, `packing_slip_message`, `suppress_price_on_packing_slip`.

Hard rule: do not rely on live customer profile alone — gift recipients and one-time addresses are common.

**MVP:** column may exist; customer-direct POs may be draft/planned only; no submit-time snapshot requirement until readiness slice R.

**Readiness (slice R):** require `ship_to_snapshot` when submitting a customer-direct PO (minimum: name, line1, city, region, postal, country).

### Vendor-direct behavior

Vendor-direct fulfillment:

* may satisfy customer demand;
* may attach tracking and external references;
* may support future invoice/cost review;
* must **not** post store inventory;
* must **not** create store receipt lines;
* must **not** convert inbound allocations to on-hand;
* must **not** be receivable via store receipt workflow.

Manual completion (**readiness tier**): `DemandAllocations::FulfillVendorDirect` when staff confirms vendor shipped/delivered.

### Allocation kind

Extend `demand_allocations.allocation_kind`:

```text
on_hand
inbound_purchase_order
vendor_backorder
vendor_direct_fulfillment    # new
```

`vendor_direct_fulfillment` rows:

* do not affect `InboundAvailability` or inventory availability cache;
* do not convert to on-hand on receipt post;
* terminalize as `fulfilled` via `FulfillVendorDirect` (not receipt conversion).

Revisit a separate `demand_fulfillment_routes` table only if a future fulfillment milestone requires multi-package tracking complexity.

---

## External references and idempotency

### Purpose

Generic traceability for vendor order numbers, shipment numbers, tracking numbers, carton/license-plate identifiers, and future idempotency — without cluttering every domain table.

See [data-model.md](data-model.md) for `external_references` grain and enums.

### Rules

1. External references are metadata; they do not directly mutate demand, PO, receipt, or inventory state.
2. Domain services remain responsible for business changes.
3. References support duplicate detection, audit, and troubleshooting.
4. Integration-ready services accept idempotency keys or dedupe on external reference uniqueness.

Integration-ready services (minimum idempotency):

```text
Purchasing::CreateDemandCoveragePlans
Purchasing::ConvertDemandCoveragePlansToInbound
Purchasing::ConvertDemandCoveragePlansToVendorDirect
Sourcing::RecordVendorResponse
Receiving::ApplyReceiptLineMatches
Purchasing::PostReceipt
DemandAllocations::FulfillVendorDirect
ExternalReferences::Attach
```

---

## Vendor availability evidence

Vendor availability helps buyers choose vendors and next actions. It is **not** committed supply.

```text
Availability evidence may suggest supply.
It must not reserve vendor stock.
It must not create inbound allocations.
It must not mark demand allocated.
It must not post inventory.
```

MVP: sourcing UI may show manual or placeholder availability. `vendor_availability_snapshots` table is deferred; capability `availability_source` defines future channel.

---

## Sourcing workflow updates

### Next action presenter

Add `Sourcing::NextActionPresenter` (complements `Demand::DemandLineWorkflowPresenter` for demand-side actions).

Inputs: demand line, optional sourcing run/attempt, vendor, resolved capability, unresolved quantity.

Outputs: `next_action_key`, label, description, warnings, eligible actions.

### Staff-facing action labels

| Vendor setup | Label | Meaning |
| ------------ | ----- | ------- |
| `availability_workflow = check_before_order` | Check availability | Check before committing to order |
| `availability_workflow = order_to_confirm` | Order to confirm | Submit/add to PO before availability known |
| `availability_workflow = manual_review` | Record manual response | Buyer records vendor result manually |
| Backorder path | Accept backorder | Demand allocated to vendor backorder |
| Failed/unavailable | Try next vendor | Buyer-reviewed cascade |
| No vendor | Choose vendor | Buyer selects source |

### Order-to-confirm vs check-before-order

For order-to-confirm vendors, a PO line is **requested supply**, not confirmed supply, until vendor response updates PO quantity buckets.

---

## Draft PO demand coverage

### Design principle

```text
Draft PO coverage = planned coverage (durable rows).
Submitted/eligible inbound_to_store coverage = inbound allocation.
Submitted/eligible vendor_direct_to_customer coverage = vendor_direct_fulfillment allocation.
```

### Table

`purchase_order_line_demand_plans` — see [data-model.md](data-model.md).

### Services

```text
Purchasing::CreateDemandCoveragePlans
Purchasing::UpdateDemandCoveragePlans
Purchasing::ReleaseDemandCoveragePlan
Purchasing::ConvertDemandCoveragePlansToInbound
Purchasing::ConvertDemandCoveragePlansToVendorDirect
Purchasing::PurchaseOrderLineDemandPlanSummary
```

Wire from existing `Purchasing::DemandCoveragePlanner` on:

* `BuildPurchaseOrderFromDemand`
* `AddDemandToPurchaseOrder`

### Draft PO quantity edits

If draft PO line quantity drops below active planned coverage, staff must reconcile: release coverage, reduce shelf replenishment, reduce newest plans, manually choose, or cancel edit. Customer fulfillment coverage requires explicit confirmation before release.

### Conversion rules

**Inbound path:**

```text
purchase_order_line_demand_plans (fulfillment_route = inbound_to_store)
  → DemandAllocations::AllocateInboundPurchaseOrder
  → demand_allocations.allocation_kind = inbound_purchase_order
```

**Vendor-direct path:**

```text
purchase_order_line_demand_plans (fulfillment_route = vendor_direct_to_customer)
  → DemandAllocations::AllocateVendorDirectFulfillment
  → demand_allocations.allocation_kind = vendor_direct_fulfillment
```

Conversion is idempotent per plan row; links `converted_to_demand_allocation_id`.

---

## Purchase order submission readiness

PO business status must not double as EDI transmission status.

Transmission/trace state may live in external references or future integration records:

```text
not_submitted, ready_to_submit, queued, transmitted,
technical_acknowledged, technical_rejected,
business_acknowledged, business_rejected
```

Core PO statuses remain vendor-neutral (submitted, acknowledged, confirmed, partially_confirmed, backordered, canceled, closed_short, received, posted).

MVP: manual submission only; vendor `order_submission_method` indicates preferred channel.

---

## Vendor-shipment receiving (store destination)

### Shipment notice rule (future)

A shipment notice is not a physical receipt. A future imported notice for **store** destination may prefill a draft receiving workpad. It must not post inventory or fulfill demand.

Shipment notices for **customer** destination may update fulfillment/tracking only — never create receipt lines.

### Receipt origin fields

Minimum on `receipts`:

```text
origin_method
vendor_shipment_destination   # store in MVP receiving paths
vendor_shipment_reference
vendor_packing_slip_number
vendor_invoice_number
tracking_number
received_at
```

Optional line-level trace fields on `receipt_lines` — see data-model.

### Receiving modes

```text
receiving_mode:
  vendor_shipment
  single_po
  direct
  adjustment_review
```

`vendor_shipment`: matching across multiple POs allowed; optional PO filter for candidate scoping (`match_filter_purchase_order_id`) — does not set `receipt.purchase_order_id` and does not make the receipt `po_backed`.

`single_po`: preserve simple PO show → receive shortcut.

Customer-direct POs (`ship_to_type = customer`) must not enter store receiving.

---

## Receipt line matching

Use **`receipt_line_matches`** (not retired v0.03 `receipt_line_allocations`).

One physical receipt line may match multiple PO lines. Matches are shipment-to-PO linkage only — they do not post inventory, reserve stock, or fulfill demand.

### Candidate criteria

Same store, same vendor, same variant; PO not canceled/closed; PO line open to receive > 0.

### Suggested sort priority

1. Customer fulfillment demand
2. Customer-paid or urgent demand
3. Preorder/backorder fulfillment
4. Older customer demand
5. Event/display demand
6. Older submitted PO lines
7. Confirmed vendor quantity
8. Shelf replenishment
9. General stock

### Services

```text
Receiving::PoLineMatchCandidates
Receiving::SuggestReceiptLineMatches
Receiving::ApplyReceiptLineMatches
Receiving::ReceiptDemandImpactPreview
```

`Purchasing::PostReceipt` validates confirmed matches inside the existing atomic transaction.

### Unmatched quantity

Staff may receive as direct/unplanned stock, search broader PO history, flag substitution/wrong item/damaged, or leave for buyer review. Unmatched accepted quantity posts only after resolving to an inventory-eligible variant.

---

## Receipt posting

`Purchasing::PostReceipt` remains the only receipt posting authority.

Atomic transaction (unchanged intent from v0.04-9):

```text
validate receipt draft and matches
validate line quantities and inventory eligibility
post accepted quantity via Inventory::Post
update PO line received/accepted quantities
convert inbound_purchase_order allocations to on_hand (FIFO)
update demand plans where applicable
rebuild availability cache
recalculate demand lines
mark receipt posted
audit events
```

Vendor-direct allocations are **out of scope** for receipt posting.

Short, rejected, and closed-short behavior follows v0.04-9 rules.

---

## Invoice and cost boundary

Invoices are cost/billing evidence, not receiving evidence. Future invoice import may flag cost mismatches; it must not post inventory, replace physical receiving, or convert inbound allocations.

---

## Future vendor document mapping

| Future document | ShelfStack target |
| --------------- | ----------------- |
| Availability / X12 846 | Availability evidence (not inventory) |
| PO / X12 850 | Outbound PO submission + external refs |
| PO acknowledgment / X12 855 | `vendor_responses` + PO vendor qty buckets |
| Shipment notice / X12 856 (store) | Draft receiving workpad |
| Shipment notice (customer) | Vendor-direct fulfillment + tracking |
| Invoice / X12 810 | Cost review (future) |
| Technical ack / 997, 999 | Transmission status only |

Avoid EDI-specific names in core workflow statuses (`edi_sent`, `x12_confirmed`, etc.).

---

## Services summary

| Area | Services |
| ---- | -------- |
| Vendor capability | `Vendors::CapabilityResolver`, `Sourcing::NextActionPresenter` |
| Planned coverage | `Purchasing::CreateDemandCoveragePlans`, `UpdateDemandCoveragePlans`, `ConvertDemandCoveragePlansToInbound`, `ConvertDemandCoveragePlansToVendorDirect`, `ReleaseDemandCoveragePlan`, `PurchaseOrderLineDemandPlanSummary` |
| Vendor-direct | `DemandAllocations::AllocateVendorDirectFulfillment`, `DemandAllocations::FulfillVendorDirect` |
| Receiving | `Receiving::PoLineMatchCandidates`, `SuggestReceiptLineMatches`, `ApplyReceiptLineMatches`, `ReceiptDemandImpactPreview` |
| External refs | `ExternalReferences::Attach`, `FindDuplicate`, `IdempotencyGuard` |

---

## UI scope

### Vendor setup

Expose workflow, channel methods, fulfillment methods supported. Staff-friendly labels (e.g. “Direct to Home capable”, “Consolidated shipments”, “Stock check via ipage”).

### Sourcing queue

Add: suggested vendor, availability workflow, availability source, next action, last response, unresolved after response.

### Demand detail

Extend timeline: planned on draft PO, converted to inbound or vendor-direct, received (store path), vendor-direct shipped, fulfilled.

### Purchase order show/edit

Per line: vendor quantity state, planned demand coverage (by route), active allocations, open to receive, external references.

Create-from-demand: fulfillment route selector when vendor supports `vendor_direct_to_customer` (**MVP** — default `inbound_to_store`; customer-direct submit UI in **readiness**).

Customer-direct PO: ship-to snapshot form (**readiness**); no “Receive” action (**MVP gate**).

### Receiving workpad

```text
Orders → Receipts → New vendor shipment
```

Vendor, packing slip, invoice, shipment reference, received at, optional PO filter (candidate scoping only), line scan/search, match panel with demand priority, unmatched qty, pre-post demand impact, post confirmation.

---

## Permissions

Minimum new keys (may reuse existing `orders.*` / `setup.vendors.*` where sufficient):

```text
setup.vendors.capabilities.view
setup.vendors.capabilities.update
external_references.view
external_references.manage
orders.purchase_orders.demand_plans.view
orders.purchase_orders.demand_plans.manage
orders.purchase_orders.demand_plans.release
orders.receipts.matches.view
orders.receipts.matches.manage
orders.receipts.matches.override
orders.receipts.unmatched.accept
demand.vendor_direct_fulfillment.complete
```

---

## Audit events

Minimum:

```text
vendor.capability_updated
sourcing_attempt.capability_snapshotted
external_reference.attached
external_reference.deactivated
purchase_order_line_demand_plan.created
purchase_order_line_demand_plan.updated
purchase_order_line_demand_plan.released
purchase_order_line_demand_plan.converted_to_inbound
purchase_order_line_demand_plan.converted_to_vendor_direct
demand_allocation.vendor_direct_fulfilled
receipt_line_match.proposed
receipt_line_match.confirmed
receipt_line_match.overridden
receipt_line_match.released
receipt.posted_with_demand_impact
```

---

## Hard gates

1. Do not implement X12 parsing/generation or SFTP polling in v0.04-13.
2. Do not reintroduce retired v0.03 ordering or allocation tables.
3. Do not create a parallel EDI ordering lifecycle.
4. Do not encode EDI-specific statuses into core demand, PO, receipt, or inventory state.
5. Do not make PO status double as transmission status.
6. Do not treat technical acknowledgment as business acknowledgment.
7. Do not treat vendor availability as reserved or committed supply.
8. Do not treat store shipment notices as posted receipts.
9. Do not treat invoices as receiving events.
10. Planned PO coverage must not affect inventory availability.
11. Draft PO lines must not create active inbound allocations.
12. Receipt matches must not post inventory.
13. Only accepted receipt quantity on store-destination receipts posts inventory.
14. Integration-ready services must be idempotent by external reference or idempotency key.
15. **Vendor-direct-to-customer fulfillment must not create store inventory.**
16. **Vendor-direct-to-customer must not require a store receipt.**
17. **Ship-to-customer PO/shipment events must not convert inbound allocations to on-hand.**
18. **ship_to_type must be distinguishable at PO level.**
19. **Shipment notices for ship-to-store may prefill receiving workpads (future only).**
20. **Shipment notices for ship-to-customer may update fulfillment/tracking only (future).**
21. **Direct-to-customer ship-to address must be snapshotted.**
22. **Holding orders: planned coverage on draft PO must not create inbound allocations until submit/eligible.**
23. **Only `fulfillment_route = inbound_to_store` plans convert to `inbound_purchase_order`.**
24. **Only `fulfillment_route = vendor_direct_to_customer` plans convert to `vendor_direct_fulfillment`.**
25. **Carton/license-plate/tracking refs live in `external_references` or `receipt_cartons` — not on product/inventory rows.**

---

## Implementation slices

Delivery tiers: **MVP (required for milestone merge)**, **Readiness (same milestone, optional PRs — may ship after MVP merge or in a later roadmap cycle)**, **Deferred (document only)**.

Readiness and deferred work **does not assume immediate follow-on** after v0.04-13 merge. Phase 10-E, v0.04-3, catalog cleanup, or other milestones may intervene.

### MVP core (store-stock manual ordering)

```text
0 Docs
→ A Capabilities (Ingram-aware enums; config only)
→ C Sourcing next actions
→ D Demand plans + fulfillment_route enum
→ D2 PO ship_to_type / order_purpose + customer-PO receiving gates
→ E Inbound conversion (inbound_to_store plans only)
→ F Store shipment receiving entry
→ G receipt_line_matches + matching services
→ H Demand impact preview (store path)
→ I Verifier (MVP tier)
```

### Readiness (optional within v0.04-13 or later)

```text
B  Thin external_references
E2 Vendor-direct conversion (vendor_direct_fulfillment)
R  ship_to_snapshot, FulfillVendorDirect, receipt_cartons migration
```

See [test-plan.md](test-plan.md) for per-slice acceptance. **`V00413_SLICE=final`** is sufficient for milestone merge; **`V00413_SLICE=readiness`** adds checks when readiness slices ship.

Individual slices A–H are **required parts of the MVP**; they do not each have a separate merge gate. Milestone merge requires **all MVP slices complete** plus Slice I verifier PASS (see [Definition of done](#definition-of-done)).

| Slice | Tier | Deliver |
| ----- | ---- | ------- |
| 0 | MVP | Spec bundle, roadmap entry, verifier skeleton |
| A | MVP | Vendor capability migration, resolver, setup UI, seeds |
| C | MVP | `Sourcing::NextActionPresenter`, queue labels, attempt snapshots |
| D | MVP | `purchase_order_line_demand_plans`, create/update from demand PO bridge |
| D2 | MVP | PO `order_purpose`, `ship_to_type`, validation gates; `vendor_direct_fulfillment` enum in schema |
| E | MVP | `ConvertDemandCoveragePlansToInbound` only; idempotent inbound plan → allocation |
| F | MVP | Receipt origin fields, vendor-shipment entry flow |
| G | MVP | `receipt_line_matches`, suggest/apply services, match UI |
| H | MVP | Pre-post preview (customer-ready vs shelf stock) |
| I | MVP | Verifier MVP tier — **milestone merge gate** |
| B | Readiness | `external_references` + attach/find/idempotency services |
| E2 | Readiness | `ConvertDemandCoveragePlansToVendorDirect`, `AllocateVendorDirectFulfillment` |
| R | Readiness | `ship_to_snapshot` submit validation, `FulfillVendorDirect`, `receipt_cartons` table (no scan UI) |

---

## Deferred (§22 — future work, sequencing TBD)

These items are specified so future work does not redesign core semantics. **The next milestone after v0.04-13 is not predetermined** — it may be Phase 10-E, v0.04-3, catalog cleanup, or a vendor-integration milestone when scheduled.

| Topic | When (indicative) |
| ----- | ----------------- |
| ipage / Stock Check / FTP / web service automation | Future vendor-integration milestone |
| X12 parse/generate/transmit | Future EDI milestone |
| 855/856/846/810 import | Future EDI milestone |
| `vendor_availability_snapshots` | Future vendor-integration milestone |
| Product/vendor capability overrides | Enhancement when needed |
| Full Direct to Home UI (labels, carrier, notifications) | Future fulfillment milestone |
| Carton/license-plate scan workflow | Future receiving milestone |
| Mixed-destination POs | Explicitly deferred |
| `demand_fulfillment_routes` separate table | Only if tracking complexity requires |
| Automatic vendor cascade | Sourcing automation milestone |
| AP / freight / receipt reversal | Accounting/costing milestones |

---

## Definition of done

### MVP merge gate (required)

v0.04-13 **MVP** is complete when:

1. Vendors configure operational capability, channels, and fulfillment methods supported.
2. Sourcing attempts snapshot vendor capability at submit.
3. Sourcing queue next actions reflect vendor capability.
4. Draft PO lines carry durable planned demand coverage with `fulfillment_route`.
5. Planned coverage does not affect inventory or availability.
6. `inbound_to_store` plans convert to inbound allocations only when eligible (Slice E).
7. Customer-direct POs and plans are **gated** — no store receiving, no inbound allocation, no inventory post.
8. Receiving starts from vendor shipment; optional PO filter scopes match candidates only (not a header PO link).
9. Consolidated shipments match across multiple POs via `receipt_line_matches`.
10. Receiving suggestions prioritize customer demand.
11. Demand impact preview shows customer-ready vs shelf stock.
12. Receipt posting remains atomic; only accepted qty posts inventory.
13. Inbound allocations convert to on-hand after accepted store receipt posting.
14. v0.04-9 short/reject/closed-short rules preserved.
15. No EDI/X12 implementation; no retired v0.03 tables written.
16. `V00413_SLICE=final STRICT=1 bin/rails shelfstack:v00413:verify_demand_fulfillment_continuity` passes **MVP tier**.
17. v0.04-6 through v0.04-12 verifiers pass.
18. Completion note written; roadmap records next priority (**not assumed to be vendor integration**).

### Readiness tier (optional — same milestone or later cycle)

When readiness slices ship (may be post-merge PRs or a later roadmap milestone):

* External references attach to core workflow records.
* `vendor_direct_to_customer` plans convert to `vendor_direct_fulfillment`.
* Customer-direct POs use `ship_to_snapshot` at submit.
* Staff may manually complete vendor-direct fulfillment with tracking ref.
* `V00413_SLICE=readiness` verifier checks pass (or WARN-only items promoted to PASS).

---

## Milestone outcome

After v0.04-13 **MVP**, manual staff workflows cover the **store-stock path**:

```text
Demand captured → vendor capability drives next action
→ draft PO with durable planned coverage (inbound_to_store)
→ submit → inbound allocation
→ consolidated receiving → inventory → pickup/shelf
→ unresolved demand remains in sourcing, backorder, or review
```

Vendor-direct paths are **modeled and gated** so Direct to Home cannot be mis-modeled as store inventory; full direct-ship UX and conversion may follow in readiness slices or a **later roadmap milestone**.

Future integrations (Ingram ipage, EDI, data services) — **when scheduled** — translate external documents into the same domain actions without bypassing demand, sourcing, purchasing, receiving, or inventory services.
