# Phase 5 Completion Record

## Status

**Phase 5 (Purchasing and Receiving) is complete** as of 2026-06-10 on branch `phase-5-purchasing-and-receiving`.

Phase 5 delivered vendor sourcing, purchase requests (TBO), purchase orders with submit snapshots, receiving with moving average cost, returns to vendor, the Orders workspace (`/orders`), setup sourcing CRUD, permissions, audit events, and demo seeds.

Normative requirements remain in:

```text
docs/roadmap/phase-5-purchasing-and-receiving.md
docs/specifications/phase-5-purchasing-and-receiving-spec.md
docs/specifications/phase-5-data-model.md
docs/specifications/phase-5-test-plan.md
```

Test coverage matrix: [phase-5-test-coverage.md](phase-5-test-coverage.md).

---

## Delivered Capabilities

### Database

Migration: `db/migrate/20250620120000_create_phase5_purchasing_and_receiving.rb`

| Table / change | Purpose |
| -------------- | ------- |
| `product_vendors` | Product-level vendor sourcing |
| `product_variant_vendors` | Variant-level vendor overrides |
| `vendor_terms` | Vendor payment terms |
| `purchase_requests` / `purchase_request_lines` | TBO demand (no inventory impact) |
| `purchase_orders` / `purchase_order_lines` | Committed vendor orders with snapshots; optional `purchase_request_line_id` links TBO lines |
| `receipts` / `receipt_lines` | Receiving workflow; `exception_reason` on receipt lines for exception-first UX |
| `receiving_discrepancies` | Over/short/damage tracking |
| `returns_to_vendor` / `return_to_vendor_lines` | Vendor returns |
| `product_variants.returnability_status` | Variant default returnability |
| `inventory_balances.moving_average_unit_cost_cents` | MAC on receive |
| `vendors` | Removed `default_pricing_model`, `default_margin_target_bps` |

### Services

| Service | Responsibility |
| ------- | -------------- |
| `Purchasing::ReturnabilityResolver` | Variant → product vendor → variant vendor precedence |
| `Purchasing::VendorCostCalculator` | List price + supplier discount → unit cost |
| `Purchasing::SourcingLookup` | Resolve preferred vendor source for a variant |
| `Purchasing::BuildPurchaseOrder` | Build draft PO from TBO lines or manual line attrs |
| `Purchasing::SubmitPurchaseOrder` | Lock PO line snapshots at submit |
| `Purchasing::ClosePurchaseOrder` | Close submitted/partial/received POs; resolve open lines |
| `Purchasing::SourcingWarnings` | Warn on PO lines missing vendor sourcing for selected vendor |
| `Purchasing::UpdatePoLineQuantities` | PO line/header status after receive |
| `Purchasing::OrderQuantityLookup` | On-order and pending qty from open PO lines |
| `Purchasing::LineLookup` | Purchasing-aware scan/search (SKU, ISBN, vendor item #, PO line in receive context) |
| `Purchasing::LineLookupPresenter` | Enriched lookup JSON (sourcing, on-hand, on-order, TBO, costs) |
| `Purchasing::BuildableTboLinesQuery` | Open TBO lines for vendor-first PO building |
| `Purchasing::TboQueueRowBuilder` | TBO queue rows with on-hand, on-order, remaining qty, filters |
| `Purchasing::SuggestedVendorResolver` | Preferred vendor suggestion per variant for TBO grouping |
| `Purchasing::BuildReceiptFromPurchaseOrder` | Draft PO-backed receipt with open lines preloaded |
| `Purchasing::PurchaseOrderSummary` | PO show totals (units, cost, retail, net discount) |
| `Purchasing::PurchaseOrderDocumentHub` | PO show cross-refs (TBO, receipts, discrepancies, line activity) |
| `Purchasing::ReceiptDocumentHub` | Receipt show cross-refs (PO alignment, discrepancies, posting) |
| `Purchasing::PurchaseRequestDocumentHub` | Purchase request show cross-refs (linked POs per line) |
| `Purchasing::ReturnToVendorDocumentHub` | RTV show totals and inventory posting reference |
| `Purchasing::DocumentTrailBuilder` | Vertical document trail nodes for PO/receipt/PR/RTV show sidebars |
| `Purchasing::DocumentAttention` | Needs-attention items for order document show pages |
| `Orders::*ShowPresenter` | View presenters for document show metrics, trail, and flags |
| `Purchasing::PostReceipt` | Post accepted qty via `Inventory::Post` (`receiving`) |
| `Purchasing::MovingAverageCost` | Update balance MAC on receive |
| `Purchasing::PostReturnToVendor` | Post vendor return via `Inventory::Post` (`vendor_return`) |

Extended Phase 4 services:

| Service | Extension |
| ------- | --------- |
| `Inventory::CostEstimator` | `receipt_cost`, `moving_average` sources |
| `Inventory::BalanceUpdater` | MAC recalculation; cost removal on RTV |
| `Inventory::Post` | `cost_source` on line payload |

### Orders workspace (`/orders`)

- Home with cards for purchase requests, purchase orders, receipts, returns to vendor
- Purchase request list/create/show/cancel
- Purchase order draft/edit/submit/show/**close**/**receive** with **progressive-disclosure document show** (metric strip, attention panel, lines-first layout, sidebar document trail, collapsible activity/discrepancies/audit)
- Purchase request show with **document hub** (linked purchase orders per line); same progressive-disclosure skeleton
- Receipt show with **document hub** (PO alignment, discrepancies, inventory posting); same progressive-disclosure skeleton
- Return to vendor show with **document hub** (totals, attention, posting sidebar); same progressive-disclosure skeleton
- Purchase order **Build from TBO** (multi-request vendor workbench with on-hand/on-order columns, editable order qty, department/format filters, suggested-vendor grouping, inline sourcing links)
- Receipt draft/post workflow (PO-backed and direct); **exception-first receiving** (received qty primary, optional exception qty/reason, derived accepting); **Receive** from PO preloads open lines
- Return to vendor draft/post workflow
- **Purchasing line table** workpad on PO, receipt, and RTV forms (scan entry, totals, duplicate merge); **primary columns** with collapsible per-line **details** row (vendor item, on-hand, list/discount, etc.); user-facing labels (Unit cost, Credit, Discount %, List price)
- RTV workpad is **inventory-aware**: on-hand and returnability per line, `rtv` lookup context, vendor-change refresh, qty vs on-hand warnings (posting still allows negative on-hand per Phase 4)
- `GET /orders/line_lookup` — enriched purchasing line lookup API
- `orders.access` permission gate and locked-out page

### Setup and Items integration

- Product vendor and product variant vendor CRUD under Setup
- Vendor forms cleaned up (supplier discount only; pricing model removed)
- Variant show: Mark TBO link, vendor sourcing context
- Items selling tab: Mark TBO per variant row
- Inventory balances: shortcuts into Orders, on-order/pending columns, zero/low stock filters, Mark TBO
- Inventory negative on-hand: Mark TBO link
- Items Display tab: product vendor sourcing list with Setup links; **variant vendor overrides** with add/edit from Items (returns to display tab)
- PO forms/show: sourcing warnings when lines lack vendor sourcing records

### Permissions and audit

Seeds: `db/seeds/phase5_permissions.rb` — `orders.*` and `setup.product_vendors.*` / `setup.product_variant_vendors.*`.

Representative audit events:

```text
purchase_request.created
purchase_order.submitted
purchase_order.closed
receipt.posted
return_to_vendor.posted
product_vendor.created
product_variant_vendor.created
```

### Items and inventory read surfaces

- `Purchasing::OrderQuantityLookup` — derives on-order (submitted PO) and pending (draft PO) per variant
- Items overview stock sidebar: Avail., Pending, Order columns
- Variant detail: on hand, on order, pending
- Inventory balances index: on order and pending columns

### Seeds

`db/seeds/phase5_inventory.rb` — idempotent demo sourcing rows for Ingram + first catalog variants.

---

## Verification

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails shelfstack:inventory:check_integrity
```

---

## Explicitly Deferred

Per roadmap:

* Accounts payable and invoice payment
* Landed/freight cost allocation
* EDI ordering and automatic reorder algorithms
* Warehouse allocation and inter-store transfers
* Full vendor credit / AP reconciliation

---

## Known Gaps / Follow-ups

* Vendor terms setup UI is schema-only (no CRUD screens yet)
* Receiving discrepancy resolution workflow (record display on document hubs; no resolution UI yet)
* Dollar/percent form inputs for list price and discount (cents/bps in table cells for now)
* Reserved / special-order quantities not shown on Items surfaces yet
* Items index search results do not include stock or on-order columns
