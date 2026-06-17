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
| `purchase_orders` / `purchase_order_lines` | Committed vendor orders with snapshots |
| `receipts` / `receipt_lines` | Receiving workflow |
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
- Purchase order draft/edit/submit/show/**close**
- Receipt draft/post workflow (PO-backed and direct)
- Return to vendor draft/post workflow
- `orders.access` permission gate and locked-out page

### Setup and Items integration

- Product vendor and product variant vendor CRUD under Setup
- Vendor forms cleaned up (supplier discount only; pricing model removed)
- Variant show: Mark TBO link, vendor sourcing context
- Items selling tab: Mark TBO per variant row
- Inventory balances: shortcuts into Orders, on-order/pending columns, zero/low stock filters, Mark TBO
- Inventory negative on-hand: Mark TBO link
- Items Display tab: product vendor sourcing list with Setup links
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
* Receiving discrepancy UI is service-backed but minimal in Orders views
* Reserved / special-order quantities not shown on Items surfaces yet
* Items index search results do not include stock or on-order columns
