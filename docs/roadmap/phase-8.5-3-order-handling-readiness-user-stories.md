# Phase 8.5-3 User Stories — Order Handling Readiness

Recommended path:

```text
docs/specifications/phase-8.5-3-user-stories.md
```

## Phase goal

As a bookstore operator, I need ShelfStack to connect demand, ordering, receiving, and allocation so that buyers can place reliable purchase orders, receivers can allocate incoming stock correctly, and future reports can trust the ordering records.

---

# Epic 1 — Vendor and ordering readiness

## Story 1.1 — Set preferred vendor on product

**As an inventory manager,**
I want to set a preferred vendor on a product,
**so that variants of that product can inherit a sensible default ordering vendor.**

### Acceptance criteria

* Product form includes nullable `preferred_vendor_id`.
* User can select, change, or clear the preferred vendor.
* Preferred vendor is optional.
* Inactive vendors cannot be selected for new assignments.
* Existing products without a preferred vendor remain valid.
* Product detail/item overview displays the product preferred vendor when present.

---

## Story 1.2 — Set preferred vendor on variant

**As an inventory manager,**
I want to set a preferred vendor directly on a product variant,
**so that a specific SKU can use a different vendor than the parent product.**

### Acceptance criteria

* Variant form includes nullable `preferred_vendor_id`.
* Variant preferred vendor overrides product preferred vendor.
* User can select, change, or clear the variant preferred vendor.
* Inactive vendors cannot be selected for new assignments.
* Variant overview clearly shows whether the preferred vendor came from:

  * variant,
  * product,
  * vendor source,
  * or no source.

---

## Story 1.3 — Resolve default ordering vendor

**As a buyer,**
I want ShelfStack to suggest the most appropriate vendor for an item,
**so that I do not have to manually choose the vendor every time I order.**

### Acceptance criteria

* System resolves preferred vendor using this order:

  1. variant preferred vendor,
  2. product preferred vendor,
  3. active variant vendor source marked preferred/default,
  4. active product vendor source marked preferred/default,
  5. no vendor.
* Resolver returns both the vendor and the source of the decision.
* If no vendor is found, the ordering UI shows a warning.
* Resolver can be used by:

  * item overview,
  * TBO creation,
  * special order creation,
  * PO line creation,
  * future order builder.

---

## Story 1.4 — Show ordering warnings on item overview

**As a frontline bookseller,**
I want item pages to show clear ordering warnings,
**so that I know whether an item can be reordered before promising it to a customer.**

### Acceptance criteria

* Item overview shows ordering warnings from a centralized warning builder.
* Warnings are grouped by category:

  * sale readiness,
  * ordering readiness,
  * inventory readiness,
  * data quality.
* Warnings have severity:

  * blocking,
  * warning,
  * info.
* Suggested warnings include:

  * no preferred vendor,
  * no active vendor source,
  * used variant cannot be vendor ordered,
  * variant inactive,
  * product inactive,
  * discontinued item,
  * missing cost,
  * missing external identifier.
* Warning text is actionable and consistent across screens.

---

## Story 1.5 — Configure Ingram preferred vendor import behavior

**As an import operator,**
I want the Ingram import to optionally set Ingram as preferred vendor,
**so that imported items are immediately easier to order.**

### Acceptance criteria

* Import includes option: “Set Ingram as preferred vendor for imported/updated products and variants.”
* When a product is created, Ingram can be set as product preferred vendor.
* When a variant is created, Ingram can be set as variant preferred vendor.
* Existing manually selected preferred vendors are not overwritten by default.
* User may explicitly choose to overwrite existing preferred vendors.
* Vendor source records are created or updated when Ingram item data is available.
* Import summary reports how many preferred vendor assignments were created, skipped, or overwritten.

---

# Epic 2 — Order eligibility

## Story 2.1 — Block non-orderable variants from normal vendor POs

**As a buyer,**
I want ShelfStack to prevent non-orderable items from being added to normal vendor purchase orders,
**so that purchase orders do not contain invalid lines.**

### Acceptance criteria

* Used variants are blocked from normal vendor POs.
* Gift card variants are blocked.
* Service variants are blocked.
* Inactive variants are blocked.
* Variants linked to inactive products are blocked.
* Non-inventory variants are blocked unless explicitly orderable.
* Blocking reason is shown to the user.
* Blocked items may still support other workflows if appropriate, such as TBO review.

---

## Story 2.2 — Warn but allow missing vendor source

**As a buyer,**
I want ShelfStack to warn me when an item has no vendor source,
**so that I can still order manually when necessary without losing visibility into the data issue.**

### Acceptance criteria

* Missing vendor source produces a warning, not a hard block.
* User can continue by manually choosing a vendor.
* Warning is visible on:

  * item overview,
  * PO line entry,
  * demand-to-PO workflow.
* PO line records that no vendor source was used.
* PO line source snapshot preserves the manual context.

---

## Story 2.3 — Warn but allow missing cost

**As a buyer,**
I want ShelfStack to warn me when expected cost is missing,
**so that I can enter a manual cost before submitting the order.**

### Acceptance criteria

* Missing cost produces a warning.
* User can add the item to a draft PO.
* Order submission requires either:

  * expected unit cost,
  * manager override,
  * or explicit allowed zero/unknown-cost policy.
* Manual cost entry sets `manual_cost_override`.
* Cost source is stored as `manual` when entered manually.

---

## Story 2.4 — Require override for discontinued items

**As a manager,**
I want discontinued items to require confirmation or override before ordering,
**so that buyers do not accidentally order items that may no longer be available.**

### Acceptance criteria

* Discontinued product or variant produces blocking or override-required result.
* Policy can distinguish:

  * hard block,
  * manager override,
  * warning only.
* Override action records:

  * user,
  * timestamp,
  * reason/note.
* PO line snapshot records that item was discontinued at order time.

---

# Epic 3 — PO line economics

## Story 3.1 — Edit PO line list price

**As a buyer,**
I want to edit the vendor or publisher list price on a purchase order line,
**so that supplier discount and expected cost can be calculated from the correct basis.**

### Acceptance criteria

* PO line form includes editable list price.
* List price is stored as `list_price_cents`.
* Changing list price recalculates expected unit cost when supplier discount is present.
* Changing list price does not change expected retail price.
* Manual list price changes update source/override state appropriately.
* List price is included in PO line snapshot for later reporting.

---

## Story 3.2 — Edit supplier discount

**As a buyer,**
I want to edit supplier discount on a PO line,
**so that expected cost reflects the terms of the order.**

### Acceptance criteria

* PO line form includes editable supplier discount.
* Supplier discount is displayed as a percent.
* Supplier discount is stored as basis points.
* Changing discount recalculates expected unit cost when list price exists.
* Manual discount entry sets `manual_cost_override`.
* Supplier discount is preserved on the PO line after order submission.

---

## Story 3.3 — Edit expected unit cost

**As a buyer,**
I want to edit expected unit cost directly,
**so that I can handle vendor quotes, net-cost items, imports, and exceptions.**

### Acceptance criteria

* PO line form includes editable expected unit cost.
* Expected unit cost is stored as `expected_unit_cost_cents`.
* Changing expected unit cost recalculates supplier discount when list price exists.
* If list price does not exist, supplier discount remains blank.
* Manual cost entry sets `manual_cost_override`.
* Cost source is set to `manual` when entered manually.
* Expected line cost recalculates immediately.

---

## Story 3.4 — Edit expected retail price

**As a buyer,**
I want to edit expected retail price on a PO line,
**so that projected margin can reflect the store’s intended selling price.**

### Acceptance criteria

* PO line form includes editable expected retail price.
* Expected retail price is stored as `expected_retail_price_cents`.
* Changing expected retail price recalculates margin.
* Changing expected retail price does not change expected unit cost.
* Manual retail price entry sets `manual_price_override`.
* Price source is stored.
* Expected retail price is preserved for future expected-margin reporting.

---

## Story 3.5 — Recalculate PO line totals immediately

**As a buyer,**
I want PO line totals and margin to update immediately as I edit quantity, price, discount, or cost,
**so that I can make ordering decisions without manually calculating margin.**

### Acceptance criteria

* Changing quantity recalculates:

  * expected line cost,
  * expected line retail,
  * expected margin.
* Changing list price, discount, cost, or retail price recalculates applicable derived fields.
* Calculations are consistent between frontend preview and backend persistence.
* Backend calculation service is the source of truth.
* Invalid values show clear validation errors.

---

## Story 3.6 — Preserve manual overrides

**As a buyer,**
I want manual cost and price overrides to be preserved,
**so that later vendor-source updates do not silently change my purchase order assumptions.**

### Acceptance criteria

* Manual cost changes set `manual_cost_override = true`.
* Manual retail price changes set `manual_price_override = true`.
* Manual overrides are visibly labeled on the PO line.
* Re-selecting vendor source does not overwrite manual fields unless user explicitly chooses to recalculate.
* User can clear manual override and recalculate from source.
* PO line snapshot records source values and final selected values.

---

## Story 3.7 — Store expected margin for reporting

**As an owner or manager,**
I want PO lines to preserve expected cost, expected retail, and expected margin,
**so that future purchasing reports can compare expected profitability against actual receiving and sales.**

### Acceptance criteria

* PO line stores:

  * expected unit cost,
  * expected retail price,
  * expected line cost,
  * expected line retail,
  * expected margin,
  * expected margin percent.
* Stored values do not change when product price changes later.
* Stored values do not change when vendor source changes later.
* Reports can use PO line snapshots without relying on current product/vendor data.

---

# Epic 4 — Purchase demand foundation

## Story 4.1 — Create TBO demand from item page

**As a bookseller,**
I want to mark a single item as To Be Ordered from the item page,
**so that buyer demand can be captured quickly without creating a purchase order.**

### Acceptance criteria

* User can create TBO for exactly one product variant.
* Quantity defaults to `1`.
* Quantity can be greater than `1`.
* Vendor is optional.
* Customer is optional.
* Preferred vendor is prefilled when known.
* TBO status starts as `open`.
* TBO stores:

  * variant,
  * quantity requested,
  * source,
  * creator,
  * note,
  * needed-by date if provided.

---

## Story 4.2 — Prevent multi-line TBOs

**As a buyer,**
I want each TBO to represent one item only,
**so that demand records stay simple and easy to convert into orders later.**

### Acceptance criteria

* TBO creation form does not support multiple line items.
* Each TBO creates one purchase demand record.
* Existing multi-line TBOs, if any, are migrated into separate demand records.
* TBO list displays each item as an independent demand row.

---

## Story 4.3 — Create special order demand

**As a frontline bookseller,**
I want to create customer-linked special order demand,
**so that items requested by customers can be ordered and fulfilled separately from normal stock.**

### Acceptance criteria

* User can create special order demand for one variant.
* Customer is required.
* Quantity defaults to `1`.
* Preferred vendor is prefilled when known.
* Demand type is `special_order`.
* Status starts as `open`.
* Demand preserves customer link.
* Special order is not considered fulfilled until receipt allocation occurs.

---

## Story 4.4 — Require customer for special orders

**As a manager,**
I want special orders to require a customer,
**so that staff can identify who the item is being ordered for when it arrives.**

### Acceptance criteria

* Special order demand cannot be saved without customer.
* TBO demand can be saved without customer.
* Error message clearly explains that special orders require customer linkage.
* Customer link is visible in demand list, PO assignment, and receipt allocation.

---

## Story 4.5 — Filter purchase demand

**As a buyer,**
I want to filter open demand by vendor, item, customer, status, and demand type,
**so that I can build orders efficiently.**

### Acceptance criteria

* Demand list supports filters for:

  * demand type,
  * status,
  * preferred/resolved vendor,
  * customer,
  * item/variant,
  * needed-by date.
* Demand list shows:

  * item,
  * quantity requested,
  * quantity ordered,
  * quantity allocated,
  * customer,
  * preferred vendor,
  * status,
  * warnings.
* Filters can be combined.
* Open demand is easy to distinguish from ordered, fulfilled, and cancelled demand.

---

## Story 4.6 — Cancel purchase demand

**As a buyer or manager,**
I want to cancel demand that should no longer be ordered,
**so that order-building screens remain accurate.**

### Acceptance criteria

* Open demand can be cancelled.
* Partially ordered demand can be cancelled for remaining unfulfilled quantity if allowed.
* Cancelled demand stores:

  * cancelled timestamp,
  * cancelling user,
  * reason/note.
* Cancelled demand is excluded from default order-building views.
* Cancelled demand remains reportable.

---

# Epic 5 — Demand-to-PO assignment

## Story 5.1 — Build PO line from one demand record

**As a buyer,**
I want to create a purchase order line from an open demand record,
**so that captured demand can become an actual order.**

### Acceptance criteria

* User can select open demand and add it to a purchase order.
* System resolves vendor before creating the line.
* System runs order eligibility before creating the line.
* PO line quantity defaults to demand remaining quantity.
* PO line links back to the demand record.
* Demand status updates to `ordered` when fully assigned.

---

## Story 5.2 — Combine multiple demand records into one PO line

**As a buyer,**
I want multiple demand records for the same variant/vendor to roll up into one PO line,
**so that purchase orders are clean and vendor-friendly.**

### Acceptance criteria

* User can select multiple compatible demand records.
* Compatible records can be grouped by:

  * vendor,
  * variant,
  * order eligibility.
* One PO line can link to multiple demand records.
* Join records preserve assigned quantity by demand.
* Demand statuses update individually.
* Special order/customer details remain visible from the PO line.

---

## Story 5.3 — Partially assign demand to a PO line

**As a buyer,**
I want to assign only part of a demand quantity to a purchase order,
**so that partial ordering and staged ordering are possible.**

### Acceptance criteria

* User can assign less than the remaining demand quantity.
* Demand status becomes `partially_ordered`.
* Remaining quantity stays open.
* Assigned quantity is visible on the demand record.
* System prevents over-assignment unless future override policy allows it.

---

## Story 5.4 — Keep demand unfulfilled until receipt allocation

**As a manager,**
I want demand assignment to a PO to be separate from fulfillment,
**so that special orders are not treated as satisfied before stock actually arrives.**

### Acceptance criteria

* Assigning demand to a PO line does not mark demand fulfilled.
* Demand fulfillment requires receipt allocation.
* Demand list distinguishes:

  * open,
  * ordered,
  * partially allocated,
  * fulfilled.
* Special order reports can show ordered-but-not-received demand.

---

## Story 5.5 — Preserve demand history

**As a manager,**
I want demand-to-order relationships to be auditable,
**so that we can explain why an item was ordered.**

### Acceptance criteria

* PO line shows linked demand records.
* Demand record shows linked PO lines.
* Link includes assigned quantity.
* Link includes user and timestamp.
* Historical links are preserved even after receiving or fulfillment.

---

# Epic 6 — Receiving allocation

## Story 6.1 — Allocate received quantity to special orders

**As a receiving clerk,**
I want to allocate received copies to linked special orders,
**so that customer orders are fulfilled from actual received stock.**

### Acceptance criteria

* Receiving screen shows linked special order demand for receipt line.
* User can allocate accepted quantity to special order demand.
* Allocation creates receipt allocation record.
* Allocation stores:

  * receipt line,
  * purchase demand,
  * customer,
  * quantity,
  * user,
  * timestamp.
* Special order demand updates quantity allocated.
* Demand becomes fulfilled only when fully allocated.

---

## Story 6.2 — Prevent allocation beyond accepted quantity

**As a receiving clerk,**
I want ShelfStack to prevent over-allocation of received items,
**so that the system never promises more copies than actually arrived.**

### Acceptance criteria

* Total allocations for a receipt line cannot exceed accepted quantity.
* Damaged/rejected quantity cannot be allocated.
* Error message shows accepted quantity and already allocated quantity.
* Partial allocation is allowed.
* Unallocated accepted quantity remains available for stock or later allocation.

---

## Story 6.3 — Handle partial receipts for special orders

**As a buyer,**
I want partial receipts to partially fulfill linked demand,
**so that remaining demand stays visible and actionable.**

### Acceptance criteria

* If fewer copies arrive than ordered, only received/accepted copies can be allocated.
* Allocated demand updates to partially allocated or fulfilled.
* Unallocated demand remains ordered/unfulfilled.
* Remaining unfulfilled demand appears in demand list or backorder view.
* System does not mark all linked demand fulfilled just because the PO line was partially received.

---

## Story 6.4 — Allocate extra received quantity to stock

**As a receiving clerk,**
I want extra received copies to be allocated to stock,
**so that non-customer copies become available for sale.**

### Acceptance criteria

* User can allocate accepted quantity to stock.
* Stock allocation does not require customer or demand.
* Stock allocation quantity can be posted to inventory.
* Special order allocations and stock allocations can exist on the same receipt line.
* Allocation totals must equal or be less than accepted quantity.

---

## Story 6.5 — Preserve customer link through receipt

**As a frontline bookseller,**
I want customer-linked special orders to remain identifiable after receiving,
**so that staff know which customer should receive the item.**

### Acceptance criteria

* Receipt allocation for special order stores customer link.
* Receiving screen displays customer name for special order allocations.
* Item/customer relationship remains visible after allocation.
* Future pickup/notification workflow can use the receipt allocation record.

---

# Epic 7 — Future-ready order building

These stories are mostly **foundation only** for Phase 8.5-3.

## Story 7.1 — Prepare demand model for sales-based reorder suggestions

**As a future buyer,**
I want sales-based reorder suggestions to create purchase demand records,
**so that future replenishment logic uses the same order-building workflow as TBOs and special orders.**

### Acceptance criteria

* `PurchaseDemand` supports `demand_type = sales_reorder`.
* Demand source fields can link to a future sales/reorder rule.
* No automatic sales reorder engine is required in this phase.
* Sales reorder demand can later be assigned to PO lines using the same demand-to-PO process.

---

## Story 7.2 — Prepare demand model for frontlist buying

**As a future buyer,**
I want frontlist candidates to use purchase demand records,
**so that new-release ordering can eventually use the same PO workflow.**

### Acceptance criteria

* `PurchaseDemand` supports `demand_type = frontlist`.
* Demand source fields can link to a future import/review source.
* Phase 8.5-3 requires existing product variant before frontlist demand can be created.
* Provisional catalog items without variants are out of scope.

---

## Story 7.3 — Preserve path for future cascading orders

**As a buyer,**
I want demand records to remain separate from PO lines,
**so that future workflows can reassign unfilled demand between vendors without losing history.**

### Acceptance criteria

* Demand is not deleted when PO line is cancelled.
* Cancelling or removing PO assignment can return demand to open/partially ordered status.
* Demand-to-PO links are auditable.
* True cascading order automation is out of scope.
* Moving submitted PO lines between vendors is out of scope.

---

## Story 7.4 — Preserve path for receiving across multiple purchase orders

**As a receiving clerk,**
I want the receiving model to support future multi-PO receiving,
**so that one vendor shipment can later be reconciled against multiple orders.**

### Acceptance criteria

* Receipt line can reference a specific PO line.
* Receipt model does not permanently assume one receipt equals one PO.
* Phase 8.5-3 UI may still receive against one PO at a time.
* Receive-across-PO user interface is out of scope.
* Future shipment/packing-slip workflow remains possible.

---

# Suggested implementation sequence

| Order | Story group                             |
| ----: | --------------------------------------- |
|     1 | Preferred vendor fields and resolver    |
|     2 | Operational warning builder             |
|     3 | Order eligibility resolver              |
|     4 | PO line economics and override behavior |
|     5 | Purchase demand model                   |
|     6 | TBO creation                            |
|     7 | Special order demand creation           |
|     8 | Demand list/filtering                   |
|     9 | Demand-to-PO assignment                 |
|    10 | Receipt allocation foundation           |

