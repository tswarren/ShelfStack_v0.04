**Phase 5: Purchasing and Receiving**

**Purpose**

Phase 5 establishes purchasing, receiving, supplier cost, returnability, and returns-to-vendor workflows.

It answers:

> How do we know what needs to be ordered, which vendor can supply it, what did we order, what did we receive, what did it cost, and when does that inventory enter or leave stock?

**Core Design Principles**

Purchasing operates at the `product_variant` level.

Inventory still enters or leaves stock only through the Phase 4 ledger:

```text
Receipt / Return to Vendor
  -> Inventory::Post
  -> inventory_postings
  -> inventory_ledger_entries
  -> inventory_balances
```

Purchase orders, receipts, and vendor returns are source documents. They do not mutate inventory balances directly.

**Major Capabilities**

Phase 5 includes:

```text
purchase requests / TBO
product-vendor sourcing
variant-vendor sourcing
vendor item numbers
vendor purchasing defaults
purchase orders
purchase order lines
PO-backed receiving
direct receiving
receiving discrepancies
accepted/rejected received quantities
moving average cost
returnability rules
returns to vendor
purchasing/receiving audit events
```

**Vendor Cleanup**

Phase 5 removes vendor-level pricing strategy fields:

```text
remove vendors.default_pricing_model
remove vendors.default_margin_target_bps
keep vendors.default_supplier_discount_bps
```

Rule:

```text
Vendor = supplier relationship defaults
Subdepartment = merchandise/pricing defaults
Product/vendor source = item-specific purchasing defaults
```

**Returnability**

Add controlled returnability status.

Controlled values:

```text
returnable
non_returnable
conditional
unknown
```

Use it at three levels:

```text
product_variants.returnability_status
product_vendors.returnability_status
product_variant_vendors.returnability_status
```

Precedence:

```text
1. product_variant_vendors.returnability_status
2. product_vendors.returnability_status
3. product_variants.returnability_status
```

`product_vendors` and `product_variant_vendors` should allow null returnability so they only override when known.

**Recommended Tables**

```text
product_vendors
product_variant_vendors
vendor_terms
purchase_requests
purchase_request_lines
purchase_orders
purchase_order_lines
receipts
receipt_lines
receiving_discrepancies
returns_to_vendor
return_to_vendor_lines
```

**Purchase Requests / TBO**

TBO should be variant-level.

A purchase request line requires:

```text
product_variant_id
store_id
requested_quantity
request_reason
status
```

It can be created from product, variant, inventory, low-stock, zero-stock, or special-order views.

Suggested statuses:

```text
open
sourcing_needed
ready_to_order
added_to_po
partially_ordered
cancelled
closed
```

TBO does not affect inventory.

**Purchase Orders**

PO lines may reference either:

```text
product_variant_id + vendor_id
```

or:

```text
product_variant_vendor_id
```

The UI should warn when no vendor-source record exists.

PO line statuses should be explicit:

```text
open
partially_received
received
backordered
cancelled
closed_short
closed
```

PO and PO lines snapshot mutable data:

```text
variant_sku_snapshot
variant_name_snapshot
vendor_item_number_snapshot
unit_list_price_cents
supplier_discount_bps
unit_cost_cents
returnability_status_snapshot
```

**Receiving**

Support both:

```text
PO-backed receiving
direct receiving / invoice receiving
```

Receipt lines should track:

```text
quantity_expected
quantity_received
quantity_accepted
quantity_rejected
```

Only `quantity_accepted` posts to inventory.

Receiving creates:

```text
inventory_postings.posting_type = receiving
inventory_ledger_entries.movement_type = received
```

**Costing**

Store all three purchasing cost fields on PO and receipt lines:

```text
unit_list_price_cents
supplier_discount_bps
unit_cost_cents
```

Introduce moving average cost in Phase 5.

Receiving accepted quantity should update moving cost. Phase 5 should treat receipt cost as stronger than Phase 4 margin estimates.

Likely new/updated balance fields:

```text
inventory_balances.moving_average_unit_cost_cents
inventory_balances.inventory_cost_value_cents
```

**Returns to Vendor**

RTVs remove inventory when posted.

RTV posting creates:

```text
inventory_postings.posting_type = vendor_return
inventory_ledger_entries.movement_type = vendor_return
```

Suggested RTV statuses:

```text
draft
posted
cancelled
credited
closed
```

Inventory leaves on `posted`. Vendor credit tracking may be recorded, but full accounts payable is deferred.

**Deferred**

Phase 5 should not include:

```text
full accounts payable
invoice payment
GL posting
landed cost allocation
freight allocation
EDI ordering
automatic reorder algorithms
warehouse allocation
inter-store transfer workflows
```

**Exit Criteria**

Phase 5 is complete when:

1. Staff can mark variants TBO from operational views.
2. Product and variant vendor sourcing records can be maintained.
3. Vendor item numbers and supplier discounts can be stored.
4. Purchase orders can be created, updated, submitted, partially received, and closed.
5. Direct receiving is supported.
6. Receipt lines separate received, accepted, and rejected quantities.
7. Accepted received quantity posts into the inventory ledger.
8. Receiving updates moving average cost.
9. Returnability can be resolved from variant/vendor source rules.
10. Returns to vendor post negative inventory movement.
11. Vendor pricing strategy fields are removed from `vendors`.
12. Purchasing and receiving actions are audited.
