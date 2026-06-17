# Phase 5 Purchasing and Receiving Functional Specification

## Purpose

This specification defines functional behavior for ShelfStack Phase 5.

Phase 5 establishes purchasing, receiving, supplier cost, returnability, and returns-to-vendor workflows. Inventory enters and leaves stock only through the Phase 4 ledger (`Inventory::Post`).

See also:

```text
docs/specifications/phase-5-data-model.md
docs/specifications/phase-5-test-plan.md
docs/roadmap/phase-5-purchasing-and-receiving.md
```

---

# 1. Core Principles

- Purchasing operates at **product variant** level.
- Purchase orders, receipts, and vendor returns are **source documents**; they do not mutate `inventory_balances` directly.
- Only `quantity_accepted` on receipt lines posts to inventory.
- Receipt cost overrides Phase 4 margin estimates; receiving updates **moving average cost**.
- Vendor = supplier relationship defaults; subdepartment = merchandise/pricing defaults; product/vendor sourcing = item-specific purchasing defaults.

---

# 2. Vendor Sourcing and Returnability

## 2.1 Sourcing tables

- `product_vendors` — product-level vendor relationship and defaults
- `product_variant_vendors` — variant-level overrides (vendor item number, discount, preferred flag)

## 2.2 Returnability

Controlled values: `returnable`, `non_returnable`, `conditional`, `unknown`.

Precedence (most specific wins):

1. `product_variant_vendors.returnability_status`
2. `product_vendors.returnability_status`
3. `product_variants.returnability_status`

Null on sourcing rows means no override at that level.

`Purchasing::ReturnabilityResolver` resolves effective returnability for a variant and optional vendor.

---

# 3. Purchase Requests (TBO)

Variant-level request lines grouped under a store-scoped header.

Line statuses: `open`, `sourcing_needed`, `ready_to_order`, `added_to_po`, `partially_ordered`, `cancelled`, `closed`.

TBO does **not** affect inventory.

Entry points: Items variant/product detail, inventory low/zero stock links.

---

# 4. Purchase Orders

Header statuses: `draft`, `submitted`, `partially_received`, `received`, `cancelled`, `closed`.

Line statuses: `open`, `partially_received`, `received`, `backordered`, `cancelled`, `closed_short`, `closed`.

On submit, PO lines snapshot: SKU, name, vendor item number, list price, supplier discount bps, unit cost, returnability.

UI warns when no vendor-source record exists for variant + vendor.

---

# 5. Receiving

Types: `po_backed`, `direct`.

Receipt statuses: `draft`, `posted`, `cancelled`.

Receipt line quantities: `quantity_expected`, `quantity_received`, `quantity_accepted`, `quantity_rejected`.

Posting creates:

```text
inventory_postings.posting_type = receiving
inventory_ledger_entries.movement_type = received
```

`Purchasing::PostReceipt` posts only accepted quantity per line and updates PO line quantities when PO-backed.

Discrepancies recorded in `receiving_discrepancies` when received ≠ expected.

---

# 6. Moving Average Cost

`inventory_balances.moving_average_unit_cost_cents` updated on positive receives.

Receipt `unit_cost_cents` drives ledger `cost_source = receipt_cost`.

Vendor returns use `moving_average` cost source when removing stock.

---

# 7. Returns to Vendor

RTV statuses: `draft`, `posted`, `cancelled`, `credited`, `closed`.

Posting creates:

```text
inventory_postings.posting_type = vendor_return
inventory_ledger_entries.movement_type = vendor_return
```

Returnability must allow return (not `non_returnable`). Credit tracking is optional; full AP deferred.

---

# 8. Permissions

Orders workspace (`/orders`) gated by `orders.access`.

Resource permissions: `orders.purchase_requests.*`, `orders.purchase_orders.*`, `orders.receipts.*`, `orders.returns_to_vendor.*`.

Sourcing setup: `setup.product_vendors.*`, `setup.product_variant_vendors.*`.

---

# 9. Audit Events

Examples:

```text
product_vendor.created
product_variant_vendor.created
purchase_request.created
purchase_order.submitted
receipt.posted
return_to_vendor.posted
```

---

# 10. Deferred

Accounts payable, invoice payment, GL, landed/freight allocation, EDI, automatic reorder, warehouse allocation, inter-store transfers.
