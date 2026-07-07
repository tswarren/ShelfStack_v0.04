# v0.04-13 Demand-to-Fulfillment Continuity — Data Model

## Status

**Deferred** — scheduled after [v0.04-14](../v0.04-14-design-system-ux-migration/spec.md). Companion to [spec.md](spec.md). Depends on v0.04-6 (`demand_lines`), v0.04-7 (`demand_allocations`), v0.04-8 (sourcing), v0.04-9 (PO/receiving quantities), v0.04-12 (demand ordering UX).

---

## Schema policy

v0.04-13 adds **new core tables** for planned demand coverage, receipt line matching, and (in readiness tier) external references. It extends existing tables for vendor capabilities, PO destination, receipt origin, and allocation kinds.

### Delivery tiers

| Area | MVP (merge gate) | Readiness (optional) |
| ---- | ---------------- | -------------------- |
| `purchase_order_line_demand_plans` + `fulfillment_route` | Yes | — |
| `receipt_line_matches` | Yes | — |
| PO `ship_to_type` / gates | Yes | — |
| `vendor_direct_fulfillment` allocation kind | Enum in schema | Conversion services |
| `external_references` | — | Yes |
| `ship_to_snapshot` | — | Yes |
| `receipt_cartons` | — | Yes (schema; scan UI deferred) |

Readiness migrations may land in post-merge PRs or a later roadmap cycle — **not assumed immediately after v0.04-13**.

### Do not add

```text
purchase_requests
special_orders
inventory_reservations
receipt_line_allocations          # retired v0.03
purchase_order_line_allocations   # retired v0.03
purchase_demand
demand_fulfillment_routes         # deferred; use vendor_direct_fulfillment allocation kind
vendor_availability_snapshots     # deferred; document reserved shape below
```

---

## Extend `vendors`

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `availability_workflow` | string | no | default `manual_review` |
| `availability_source` | string | no | default `manual` |
| `order_submission_method` | string | no | default `manual` |
| `acknowledgment_method` | string | no | default `manual` |
| `shipment_notice_method` | string | no | default `none` |
| `invoice_method` | string | no | default `manual` |
| `technical_acknowledgment_method` | string | no | default `none` |
| `fulfillment_methods_supported` | string[] or JSONB | no | default `["ship_to_store"]` |

### Enum values

**`availability_workflow`:** `check_before_order`, `order_to_confirm`, `manual_review`

**`availability_source`:** `manual`, `ipage`, `stock_check_app`, `data_services_web_service`, `data_services_ftp`, `portal`, `email`, `file_import`, `edi_x12`, `api`, `none`

**`order_submission_method`:** `manual`, `ipage`, `portal`, `email`, `file_export`, `edi_x12`, `api`

**`acknowledgment_method`:** `manual`, `portal`, `email`, `file_import`, `edi_x12`, `api`, `none`

**`shipment_notice_method`:** `manual`, `portal`, `email`, `file_import`, `edi_x12`, `api`, `none`

**`invoice_method`:** `manual`, `email`, `paper`, `file_import`, `edi_x12`, `api`, `none`

**`technical_acknowledgment_method`:** `none`, `edi_x12`, `api`

**`fulfillment_methods_supported` elements:** `ship_to_store`, `vendor_direct_to_customer`, `consolidated_shipment`, `holding_order`

---

## Extend `sourcing_attempts`

Add capability snapshot columns (set at submit):

| Column | Type | Null |
| ------ | ---- | ---- |
| `availability_workflow_snapshot` | string | yes |
| `availability_source_snapshot` | string | yes |
| `order_submission_method_snapshot` | string | yes |
| `acknowledgment_method_snapshot` | string | yes |
| `shipment_notice_method_snapshot` | string | yes |
| `invoice_method_snapshot` | string | yes |
| `technical_acknowledgment_method_snapshot` | string | yes |
| `fulfillment_methods_supported_snapshot` | JSONB | yes |
| `vendor_capability_source_snapshot` | string | yes |

`vendor_capability_source_snapshot` values: `vendor`, `product_vendor`, `product_variant_vendor`, `system_default` (MVP: always `vendor`).

---

## Extend `purchase_orders`

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `order_purpose` | string | no | default `stock_order` |
| `ship_to_type` | string | no | default `store` |
| `ship_to_snapshot` | JSONB | yes | nullable in MVP; readiness submit validation when customer-direct submit is implemented |

**`order_purpose`:** `stock_order`, `customer_direct_fulfillment`, `mixed` (MVP validation rejects `mixed`)

**`ship_to_type`:** `store`, `customer`, `third_party`

### `ship_to_snapshot` JSON keys (normative)

```text
ship_to_name
ship_to_address_line1
ship_to_address_line2
ship_to_city
ship_to_region_code
ship_to_postal_code
ship_to_country_code
ship_to_phone
ship_to_email
gift_message
packing_slip_message
suppress_price_on_packing_slip
```

### Validation tiers

**MVP gate:**

* Customer-direct POs (`ship_to_type = customer`) may exist as draft/planned records.
* MVP **blocks** customer-direct POs from store receiving, inbound allocation, and inventory posting.
* MVP does **not** require `ship_to_snapshot` on submit unless readiness slice R implements customer-direct submit.

**Readiness validation (slice R):**

* When customer-direct PO submit is implemented, require `ship_to_snapshot` with minimum fields: name, line1, city, region, postal, country.
* Gift/temporary addresses must not rely on live customer profile alone.

---

## New table: `purchase_order_line_demand_plans`

**Grain:** one row = planned quantity from one demand line intended to be covered by one purchase order line.

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `id` | bigint | no | PK |
| `store_id` | FK stores | no | |
| `purchase_order_id` | FK purchase_orders | no | |
| `purchase_order_line_id` | FK purchase_order_lines | no | |
| `demand_line_id` | FK demand_lines | no | |
| `product_id` | FK products | no | must match demand line |
| `product_variant_id` | FK product_variants | no | must match demand line |
| `quantity_planned` | integer | no | > 0 |
| `fulfillment_route` | string | no | default `inbound_to_store` |
| `coverage_kind` | string | no | see below |
| `status` | string | no | see below |
| `created_by_user_id` | FK users | no | |
| `converted_to_demand_allocation_id` | FK demand_allocations | yes | set on conversion |
| `converted_at` | datetime | yes | |
| `converted_by_user_id` | FK users | yes | |
| `released_at` | datetime | yes | |
| `released_by_user_id` | FK users | yes | |
| `release_reason` | text | yes | |
| `idempotency_key` | string | yes | unique per store when present |
| `notes` | text | yes | |
| timestamps | | | |

**`fulfillment_route`:** `inbound_to_store`, `vendor_direct_to_customer`

**`coverage_kind`:** `customer_fulfillment`, `shelf_replenishment`, `frontlist_stock`, `display_stock`, `event_stock`, `preorder_fulfillment`, `backorder_fulfillment`, `replacement`, `other`

**`status`:** `planned`, `partially_converted`, `converted`, `released`, `canceled`, `superseded`

**Indexes:**

* `[purchase_order_line_id, demand_line_id, status]` — active plan lookup
* `[demand_line_id, status]`
* `[store_id, purchase_order_id]`
* unique partial: `[store_id, idempotency_key]` where `idempotency_key IS NOT NULL AND status IN ('planned', 'partially_converted')` (active plans only; converted history may share lineage keys)

**Rules:**

* Planned rows do not affect `quantity_available`, `quantity_reserved`, or inventory ledger.
* Store, product, variant must match across demand line and PO line.
* Active planned coverage on draft PO only until converted or released.

---

## Extend `demand_allocations`

**`allocation_kind` enum extension:**

```text
on_hand
inbound_purchase_order
vendor_backorder
vendor_direct_fulfillment    # new
```

### `vendor_direct_fulfillment` row rules

**Tier:** allocation kind enum and validations in **MVP**; rows created by conversion services in **readiness** slice E2.

| Field | Rule |
| ----- | ---- |
| `purchase_order_line_id` | required |
| `purchase_order_id` | required (denormalized or via line) |
| `quantity_allocated` | > 0 |
| Availability cache | excluded — same as `vendor_backorder` |
| `InboundAvailability` | excluded |
| Receipt conversion | never — terminalize via `FulfillVendorDirect` |
| `status` terminal | `fulfilled`, `released`, `canceled` |

Optional link back: `purchase_order_line_demand_plans.converted_to_demand_allocation_id`.

---

## New table: `external_references` (readiness tier)

**Not required for v0.04-13 MVP merge.** May ship in readiness slice B (post-merge or later cycle).

**Grain:** one external identifier attached to one ShelfStack domain record.

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `id` | bigint | no | PK |
| `store_id` | FK stores | yes | null for global vendor refs |
| `vendor_id` | FK vendors | yes | |
| `referencable_type` | string | no | polymorphic |
| `referencable_id` | bigint | no | |
| `reference_system` | string | no | see enums |
| `reference_kind` | string | no | see enums |
| `reference_value` | string | no | |
| `source_method` | string | no | |
| `source_payload_type` | string | yes | future import record |
| `source_payload_id` | bigint | yes | |
| `idempotency_key` | string | yes | |
| `active` | boolean | no | default true |
| `created_by_user_id` | FK users | yes | |
| timestamps | | | |

**`reference_system`:** `vendor`, `manual`, `portal`, `email`, `file_import`, `file_export`, `edi_x12`, `api`, `system`

**`reference_kind` (minimum):**

```text
buyer_purchase_order_number
vendor_order_number
vendor_acknowledgment_number
vendor_shipment_number
vendor_invoice_number
packing_slip_number
vendor_line_number
vendor_item_number
vendor_direct_order_number
vendor_direct_shipment_number
customer_tracking_number
carrier_tracking_number
packing_slip_reference
direct_to_home_reference
carton_identifier
license_plate_number
external_message_id
external_file_name
edi_interchange_control_number
edi_group_control_number
edi_transaction_control_number
other
```

**`source_method`:** `manual`, `portal`, `email`, `file_import`, `file_export`, `edi_x12`, `api`, `system`

**Unique index (where active):**

```text
[store_id, vendor_id, reference_system, reference_kind, reference_value, referencable_type]
```

**Allowed `referencable_type` (MVP):** `DemandLine`, `DemandAllocation`, `PurchaseOrder`, `PurchaseOrderLine`, `SourcingAttempt`, `VendorResponse`, `Receipt`, `ReceiptLine`, `ReceiptLineMatch`, `PurchaseOrderLineDemandPlan`

---

## Extend `receipts`

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `origin_method` | string | no | default `manual` |
| `receiving_mode` | string | no | default `vendor_shipment` |
| `vendor_shipment_destination` | string | no | default `store` |
| `vendor_shipment_reference` | string | yes | |
| `vendor_packing_slip_number` | string | yes | |
| `vendor_invoice_number` | string | yes | |
| `tracking_number` | string | yes | |
| `received_at` | datetime | yes | |
| `match_filter_purchase_order_id` | FK purchase_orders | yes | Optional candidate-scope filter for vendor-shipment receiving; not a header PO link |

**`match_filter_purchase_order_id` rules:**

* Must match receipt store and vendor.
* Must reference a receivable PO (`PurchaseOrder::RECEIVABLE_PO_STATUSES`).
* Does not set header `purchase_order_id` and does not make the receipt `po_backed`.

**`origin_method`:** `manual`, `purchase_order`, `vendor_shipment_notice`, `file_import`, `edi_x12`, `api`

**`receiving_mode`:** `vendor_shipment`, `single_po`, `direct`, `adjustment_review`

**`vendor_shipment_destination`:** `store` (MVP receiving), `customer` (reserved — must not create store receipt in MVP)

Validation: reject creating/posting store receipt when linked PO has `ship_to_type = customer`.

---

## Extend `receipt_lines`

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `origin_method` | string | yes | |
| `external_line_reference` | string | yes | |
| `vendor_line_reference` | string | yes | |
| `shipment_notice_quantity` | integer | yes | future 856 prefill |
| `receipt_carton_id` | FK receipt_cartons | yes | readiness tier |

`purchase_order_line_id` remains on receipt line for posting integration; matches table provides multi-PO linkage.

---

## New table: `receipt_line_matches`

**Grain:** one row = quantity from one receipt line matched to one purchase order line.

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `id` | bigint | no | PK |
| `store_id` | FK stores | no | |
| `receipt_id` | FK receipts | no | |
| `receipt_line_id` | FK receipt_lines | no | |
| `purchase_order_id` | FK purchase_orders | no | |
| `purchase_order_line_id` | FK purchase_order_lines | no | |
| `product_id` | FK products | no | |
| `product_variant_id` | FK product_variants | no | |
| `quantity_matched` | integer | no | > 0 |
| `match_status` | string | no | |
| `match_source` | string | no | |
| `matched_by_user_id` | FK users | yes | |
| `matched_at` | datetime | yes | |
| `released_by_user_id` | FK users | yes | |
| `released_at` | datetime | yes | |
| `release_reason` | text | yes | |
| `receipt_carton_id` | FK receipt_cartons | yes | readiness |
| `idempotency_key` | string | yes | |
| `notes` | text | yes | |
| timestamps | | | |

**`match_status`:** `proposed`, `confirmed`, `posted`, `released`, `rejected`

**`match_source`:** `auto`, `manual`, `override`, `file_import`, `edi_x12`, `api`

**Indexes:**

* `[receipt_line_id, purchase_order_line_id, match_status]`
* `[receipt_id, match_status]`
* unique partial: `[store_id, idempotency_key]` where `idempotency_key IS NOT NULL`

Sum of `quantity_matched` for active matches on a receipt line must not exceed line `quantity_accepted` at post time.

---

## New table: `receipt_cartons` (readiness tier — schema only in MVP)

**Grain:** one physical carton or license-plate unit within a vendor shipment receipt.

| Column | Type | Null | Notes |
| ------ | ---- | ---- | ----- |
| `id` | bigint | no | PK |
| `store_id` | FK stores | no | |
| `receipt_id` | FK receipts | no | |
| `vendor_id` | FK vendors | yes | |
| `carton_identifier` | string | yes | |
| `license_plate_number` | string | yes | |
| `tracking_number` | string | yes | |
| `carrier` | string | yes | |
| `shipment_reference` | string | yes | |
| `status` | string | no | default `open` |
| timestamps | | | |

MVP: table may exist; no scan UI. Staff may record carton/tracking via `external_references` or receipt header fields.

---

## Reserved: `vendor_availability_snapshots` (deferred)

Document for a **future vendor-integration milestone**; **no migration in v0.04-13**.

| Column | Notes |
| ------ | ----- |
| `vendor_id`, `product_id`, `product_variant_id` | |
| `identifier_value`, `vendor_item_number` | |
| `quantity_available`, `availability_status` | |
| `warehouse_code`, `expected_date`, `observed_at` | |
| `source_method`, `external_reference_id` | |

---

## Staff display model (extends v0.04-12)

Authoritative staff labels live in [spec.md — Staff-facing supply states](spec.md#staff-facing-supply-states). Summary:

| Internal | Staff label | Persistence |
| -------- | ----------- | ----------- |
| No active allocation / no active plan | Unallocated | Computed |
| Active planned demand plan on draft PO | Planned on order | `purchase_order_line_demand_plans` |
| `allocation_kind: inbound_purchase_order` active | On order | `demand_allocations` |
| `allocation_kind: vendor_direct_fulfillment` active | Direct ship to customer | `demand_allocations` *(readiness)* |
| `allocation_kind: on_hand` active | On hand | `demand_allocations` |
| `allocation_kind: vendor_backorder` active | Vendor backorder | `demand_allocations` |

**Planned on order** and **vendor direct** planned rows must not affect `InboundAvailability`.

---

## Service write boundaries

| Service | Writes |
| ------- | ------ |
| `Vendors::CapabilityResolver` | Read-only |
| `Purchasing::CreateDemandCoveragePlans` | `purchase_order_line_demand_plans` |
| `Purchasing::ConvertDemandCoveragePlansToInbound` | plans + `demand_allocations` (inbound) |
| `Purchasing::ConvertDemandCoveragePlansToVendorDirect` | plans + `demand_allocations` (vendor_direct) |
| `DemandAllocations::AllocateVendorDirectFulfillment` | `demand_allocations` |
| `DemandAllocations::FulfillVendorDirect` | terminalize allocation + demand line |
| `Receiving::ApplyReceiptLineMatches` | `receipt_line_matches` |
| `Purchasing::PostReceipt` | receipts, lines, matches (posted), inventory, inbound conversion |
| `ExternalReferences::Attach` | `external_references` |

---

## Migration notes

* Backfill existing vendors: `availability_workflow = manual_review`, channels = manual/none defaults, `fulfillment_methods_supported = ["ship_to_store"]`.
* Backfill existing POs: `order_purpose = stock_order`, `ship_to_type = store`.
* Backfill existing receipts: `origin_method = manual`, `receiving_mode = single_po` or `direct` based on `receipt_type`, `vendor_shipment_destination = store`.
* No backfill of demand plans from audit events required (dev reseed acceptable per v0.04 policy).
