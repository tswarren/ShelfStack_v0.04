# Phase 8.5-3 Spec — Order Handling Readiness

**Status:** Draft

## Purpose

Make ShelfStack’s ordering workflow reliable, auditable, and report-ready before deeper reporting and advanced replenishment features are built.

Phase 8.5 is already focused on making operational records complete, consistent, auditable, and ready for reporting, including facts such as what was ordered, from which vendor, at what expected cost, which items are orderable, and which vendor should be used by default.

Phase 8.5-3 should establish the foundational chain:

```text
Purchase demand
  → Purchase order line
    → Receipt line
      → Receipt allocation
        → Stock / customer fulfillment
```

This phase should not attempt to build a full automated purchasing engine. The goal is to make the core ordering records trustworthy and flexible enough to support later features such as sales-based reorder suggestions, frontlist ordering, cascading orders, and receiving across multiple purchase orders.

---

# 1. Scope

## In scope

Phase 8.5-3 should deliver:

1. Preferred vendor fields on products and variants.
2. Centralized preferred vendor resolution.
3. Centralized ordering eligibility validation.
4. Centralized item operational warnings.
5. Editable purchase order line economics.
6. Manual price/cost override handling.
7. Purchase demand foundation for:

   * TBO,
   * special orders,
   * future sales demand,
   * future frontlist demand.
8. Demand-to-PO-line assignment.
9. Receipt allocation foundation for special orders and other demand.
10. Ingram import option to assign preferred vendor.
11. Tests for ordering eligibility, economics recalculation, demand conversion, and receipt allocation.

## Out of scope

Do **not** include these in Phase 8.5-3:

* automatic sales-based reorder suggestions,
* full min/max replenishment engine,
* full frontlist buying tool,
* provisional catalog items without variants,
* moving submitted PO lines between vendors,
* cascading orders between vendors,
* receive-across-multiple-PO user interface,
* customer notification workflow,
* special order deposit enforcement,
* pickup/abandoned-order workflow,
* full vendor performance reporting,
* full item page redesign.

These features should be enabled by the data model but implemented later.

---

# 2. Core design decisions

## 2.1 Separate demand from purchase orders

A TBO, special order, sales reorder suggestion, and frontlist candidate are all forms of **purchase demand**.

A purchase order line is different. It represents an actual buying decision:

> We are ordering this quantity from this vendor at this expected cost.

Therefore, the system should not make TBOs or special orders behave like mini purchase orders.

Recommended model:

```ruby
PurchaseDemand
```

User-facing terminology can still say:

* TBO,
* To Be Ordered,
* Special Order,
* Buyer Demand,
* Frontlist Candidate.

## 2.2 One demand record = one variant

Each purchase demand record should reference exactly one `product_variant`.

A demand record may request a quantity greater than one, but it should not contain multiple line items.

Correct:

```text
PurchaseDemand
  product_variant_id: 123
  quantity_requested: 3
```

Incorrect:

```text
TBO Header
  Line 1: Variant 123
  Line 2: Variant 456
  Line 3: Variant 789
```

## 2.3 Purchase demand may exist before ordering is allowed

A user may create demand for an item even if that item cannot be added to a normal vendor purchase order.

Examples:

| Item                | Demand allowed? | Normal vendor PO allowed? |
| ------------------- | --------------: | ------------------------: |
| New trade paperback |             Yes |                       Yes |
| Used book           |             Yes |                        No |
| Discontinued title  |             Yes |         Override or block |
| Gift card           |              No |                        No |
| Service item        |      Usually no |                        No |

The demand creation flow and the PO conversion flow should use different rules.

## 2.4 Special order fulfillment is receipt-based

A special order should not be considered fulfilled just because it was placed on a purchase order.

Correct lifecycle:

```text
Customer requests item
  → demand is created
  → demand is assigned to PO line
  → item is ordered
  → item is received
  → received copy is allocated to the customer
  → special order becomes fulfilled/ready
```

Only actual accepted receipt quantities may satisfy special order demand.

## 2.5 Receipt allocation should be explicit

Receiving stock and assigning stock to customer demand are related but distinct.

A receipt line answers:

> What arrived?

A receipt allocation answers:

> Where did the received quantity go?

Examples:

```text
Receipt line receives 5 copies
  → 2 allocated to customer special orders
  → 3 allocated to store stock
```

---

# 3. Terminology

| Term               | Meaning                                                                               |
| ------------------ | ------------------------------------------------------------------------------------- |
| Purchase demand    | A record that the store needs, may need, or intends to obtain a variant               |
| TBO                | A simple purchase demand record, usually internal and not customer-committed          |
| Special order      | Customer-linked purchase demand                                                       |
| Sales demand       | Future demand generated from sales/replenishment logic                                |
| Frontlist demand   | Future demand created from new-release/vendor catalog review                          |
| Preferred vendor   | The vendor the store usually expects to use for ordering an item                      |
| Vendor source      | Vendor-specific purchasing data for a product/variant                                 |
| Order eligibility  | Whether a variant can be added to a normal vendor purchase order                      |
| PO line economics  | List price, retail price, discount, expected cost, and margin data on a PO line       |
| Receipt allocation | Assignment of received quantity to stock, special order, hold, or another destination |

---

# 4. Data model

## 4.1 Products

Add:

| Field                 |   Type | Notes                    |
| --------------------- | -----: | ------------------------ |
| `preferred_vendor_id` | bigint | Nullable FK to `vendors` |

### Rules

* Nullable.
* May be set manually.
* May be set by import only when allowed by import settings.
* Should not overwrite an existing manually selected preferred vendor unless explicitly requested.

---

## 4.2 Product variants

Add:

| Field                 |    Type | Notes                                                                                                                      |
| --------------------- | ------: | -------------------------------------------------------------------------------------------------------------------------- |
| `preferred_vendor_id` |  bigint | Nullable FK to `vendors`                                                                                                   |
| `orderable`           | boolean | Default `true` for normal physical variants; false for gift cards/services/non-orderable records unless explicitly enabled |

### Rules

* `preferred_vendor_id` overrides product-level preferred vendor when present.
* `orderable` should be distinct from `inventory_behavior`.
* A variant may be inventory-tracked but not orderable.
* A future variant may be orderable but not inventory-tracked, if explicitly allowed.

---

## 4.3 Purchase order lines

Ensure purchase order lines support editable economics.

Recommended fields:

| Field                         |       Type | Notes                                                     |
| ----------------------------- | ---------: | --------------------------------------------------------- |
| `product_variant_id`          |     bigint | Required                                                  |
| `quantity_ordered`            |    integer | Required                                                  |
| `list_price_cents`            |    integer | Vendor/publisher list price snapshot                      |
| `expected_retail_price_cents` |    integer | Store selling price snapshot                              |
| `supplier_discount_bps`       |    integer | Nullable; 40% = `4000`                                    |
| `expected_unit_cost_cents`    |    integer | Expected net unit cost                                    |
| `expected_line_cost_cents`    |    integer | Cached calculated total                                   |
| `expected_line_retail_cents`  |    integer | Cached calculated total                                   |
| `expected_margin_cents`       |    integer | Cached calculated margin                                  |
| `expected_margin_percent_bps` |    integer | Cached margin percent                                     |
| `cost_source`                 |     string | `vendor_source`, `manual`, `import`, `default`, `unknown` |
| `price_source`                |     string | `variant`, `vendor_source`, `manual`, `import`, `unknown` |
| `manual_cost_override`        |    boolean | Default `false`                                           |
| `manual_price_override`       |    boolean | Default `false`                                           |
| `line_note`                   |       text | Optional                                                  |
| `source_snapshot`             | json/jsonb | Snapshot of source economics/vendor data                  |

### Notes

Use `supplier_discount_bps`, not decimal percent, to avoid floating-point ambiguity.

Examples:

| UI value | Stored value |
| -------: | -----------: |
|      40% |       `4000` |
|    46.5% |       `4650` |
|       0% |          `0` |

---

## 4.4 Purchase demands

Create:

```ruby
PurchaseDemand
```

### Purpose

Represents demand for one product variant.

### Fields

| Field                  |          Type | Notes                                                                                       |
| ---------------------- | ------------: | ------------------------------------------------------------------------------------------- |
| `product_variant_id`   |        bigint | Required                                                                                    |
| `quantity_requested`   |       integer | Required, default `1`                                                                       |
| `demand_type`          |        string | `tbo`, `special_order`, `sales_reorder`, `frontlist`, `manual`                              |
| `status`               |        string | `open`, `partially_ordered`, `ordered`, `partially_allocated`, `fulfilled`, `cancelled`     |
| `preferred_vendor_id`  |        bigint | Nullable FK to `vendors`                                                                    |
| `customer_id`          |        bigint | Required for special order; optional otherwise                                              |
| `source`               |        string | `manual`, `pos`, `item_page`, `customer_request`, `sales_history`, `frontlist_import`, etc. |
| `source_record_type`   |        string | Optional polymorphic source                                                                 |
| `source_record_id`     |        bigint | Optional polymorphic source                                                                 |
| `needed_by`            | date/datetime | Optional                                                                                    |
| `priority`             |       integer | Optional                                                                                    |
| `note`                 |          text | Optional                                                                                    |
| `created_by_user_id`   |        bigint | Required                                                                                    |
| `quantity_ordered`     |       integer | Cached/derived                                                                              |
| `quantity_allocated`   |       integer | Cached/derived                                                                              |
| `quantity_fulfilled`   |       integer | Cached/derived                                                                              |
| `cancelled_at`         |      datetime | Nullable                                                                                    |
| `cancelled_by_user_id` |        bigint | Nullable                                                                                    |
| `cancel_reason`        |          text | Nullable                                                                                    |
| `fulfilled_at`         |      datetime | Nullable                                                                                    |

### Demand types

| Type            | Meaning                                               |
| --------------- | ----------------------------------------------------- |
| `tbo`           | Internal “to be ordered” demand                       |
| `special_order` | Customer-linked demand                                |
| `sales_reorder` | Future sales/replenishment-generated demand           |
| `frontlist`     | Future new-release/vendor catalog demand              |
| `manual`        | Buyer-created demand that is not otherwise classified |

### Status rules

| Status                | Meaning                                               |
| --------------------- | ----------------------------------------------------- |
| `open`                | Demand exists but has not been assigned to an order   |
| `partially_ordered`   | Some requested quantity has been assigned to PO lines |
| `ordered`             | Full requested quantity has been assigned to PO lines |
| `partially_allocated` | Some received quantity has been allocated             |
| `fulfilled`           | Demand has been fully allocated/fulfilled             |
| `cancelled`           | Demand was cancelled                                  |

### Validations

* `product_variant_id` required.
* `quantity_requested` must be greater than zero.
* `demand_type` required.
* `status` required.
* `created_by_user_id` required.
* `customer_id` required when `demand_type = special_order`.
* Cancelled records require `cancelled_at`.
* Fulfilled records require `fulfilled_at`.

---

## 4.5 Purchase order line demands

Create join model:

```ruby
PurchaseOrderLineDemand
```

### Purpose

Links one or more demand records to one purchase order line.

This is better than storing only `purchase_order_line_id` on `purchase_demands`, because:

* one PO line may satisfy multiple special orders,
* one demand record may be partially ordered,
* demand may later need to be reassigned,
* order history remains auditable.

### Fields

| Field                       |     Type | Notes    |
| --------------------------- | -------: | -------- |
| `purchase_order_line_id`    |   bigint | Required |
| `purchase_demand_id`        |   bigint | Required |
| `quantity_assigned`         |  integer | Required |
| `created_by_user_id`        |   bigint | Required |
| `created_at` / `updated_at` | datetime | Standard |

### Rules

* `quantity_assigned` must be greater than zero.
* Assigned quantity may not exceed remaining open quantity unless manager override is introduced later.
* Assigning demand updates cached demand quantities.
* Demand status changes to `partially_ordered` or `ordered`.

---

## 4.6 Receipt lines

Receipt lines should remain the record of actual receipt.

Recommended fields or existing-field expectations:

| Field                    | Notes                             |
| ------------------------ | --------------------------------- |
| `receipt_id`             | Required                          |
| `purchase_order_line_id` | Nullable or line-specific         |
| `product_variant_id`     | Required                          |
| `quantity_received`      | What arrived                      |
| `quantity_accepted`      | What posts/allocates              |
| `quantity_damaged`       | Optional                          |
| `quantity_rejected`      | Optional                          |
| `unit_cost_cents`        | Actual or accepted receiving cost |
| `source_snapshot`        | Optional                          |

### Future compatibility

The model should not assume one receipt equals one purchase order forever.

Even if the Phase 8.5-3 UI receives against one PO at a time, the data model should eventually allow:

```text
One vendor receipt / packing slip
  → multiple purchase order lines
  → potentially multiple purchase orders
```

---

## 4.7 Receipt allocations

Create:

```ruby
ReceiptAllocation
```

### Purpose

Assigns accepted received quantity to stock, special order demand, hold, or another destination.

### Fields

| Field                       |     Type | Notes                                     |
| --------------------------- | -------: | ----------------------------------------- |
| `receipt_line_id`           |   bigint | Required                                  |
| `purchase_demand_id`        |   bigint | Nullable                                  |
| `allocation_type`           |   string | `stock`, `special_order`, `hold`, `other` |
| `customer_id`               |   bigint | Nullable; usually copied from demand      |
| `quantity_allocated`        |  integer | Required                                  |
| `allocated_by_user_id`      |   bigint | Required                                  |
| `allocated_at`              | datetime | Required                                  |
| `status`                    |   string | `allocated`, `released`, `fulfilled`      |
| `note`                      |     text | Optional                                  |
| `created_at` / `updated_at` | datetime | Standard                                  |

### Allocation types

| Type            | Meaning                                |
| --------------- | -------------------------------------- |
| `stock`         | Goes to normal store inventory         |
| `special_order` | Reserved/allocated for customer demand |
| `hold`          | Held for operational reason            |
| `other`         | Manual/exception case                  |

### Rules

* Allocated quantity may not exceed `receipt_line.quantity_accepted`.
* Special order allocation requires `purchase_demand_id`.
* Allocation to special order should copy/preserve `customer_id`.
* Receipt allocation should happen only from accepted quantity.
* Releasing an allocation should restore quantity to available allocation pool or normal stock workflow, depending on implementation.

---

# 5. Service objects

## 5.1 `Purchasing::PreferredVendorResolver`

### Purpose

Determine the best vendor to use for ordering a variant.

### Public API

```ruby
Purchasing::PreferredVendorResolver.call(product_variant:)
```

### Resolution order

1. Variant preferred vendor.
2. Product preferred vendor.
3. Active variant vendor source marked preferred/default.
4. Active product vendor source marked preferred/default.
5. No vendor.

### Result object

```ruby
Result = Data.define(
  :vendor,
  :source,
  :confidence,
  :warnings
)
```

### Example sources

| Source                  | Meaning                                            |
| ----------------------- | -------------------------------------------------- |
| `variant_preferred`     | Explicit preferred vendor on variant               |
| `product_preferred`     | Explicit preferred vendor on product               |
| `variant_vendor_source` | Vendor source selected from variant vendor records |
| `product_vendor_source` | Vendor source selected from product vendor records |
| `none`                  | No vendor found                                    |

---

## 5.2 `Purchasing::OrderEligibilityResolver`

### Purpose

Determine whether a variant can be added to a normal vendor purchase order.

### Public API

```ruby
Purchasing::OrderEligibilityResolver.call(
  product_variant:,
  vendor: nil,
  context: :purchase_order
)
```

### Result object

```ruby
Result = Data.define(
  :eligible,
  :requires_override,
  :blocking_reasons,
  :warnings,
  :infos
)
```

### Rules

| Condition                                  | Behavior                          |
| ------------------------------------------ | --------------------------------- |
| Used variant                               | Block normal vendor PO            |
| Gift card                                  | Block                             |
| Service                                    | Block                             |
| Non-inventory and not explicitly orderable | Block                             |
| Variant inactive                           | Block                             |
| Product inactive                           | Block                             |
| Vendor inactive                            | Block                             |
| Discontinued product/variant               | Block or require manager override |
| Missing vendor source                      | Warning, allow                    |
| Missing cost                               | Warning, allow manual cost        |
| Missing preferred vendor                   | Warning, allow vendor selection   |
| Missing external identifier                | Info/warning, allow               |

---

## 5.3 `Items::OperationalWarningBuilder`

### Purpose

Build consistent warnings for item overview, PO line creation, TBO creation, and future order-builder screens.

### Public API

```ruby
Items::OperationalWarningBuilder.call(
  product_variant:,
  contexts: [:sale, :ordering, :inventory, :data_quality]
)
```

### Warning object

```ruby
Warning = Data.define(
  :severity,
  :category,
  :code,
  :message,
  :action_label,
  :action_path
)
```

### Severities

| Severity   | Meaning                               |
| ---------- | ------------------------------------- |
| `blocking` | User cannot complete expected action  |
| `warning`  | Action allowed but likely problematic |
| `info`     | Useful operational note               |

### Categories

| Category       | Examples                                                |
| -------------- | ------------------------------------------------------- |
| `sale`         | no price, inactive, no tax category                     |
| `ordering`     | no preferred vendor, used item, no active vendor source |
| `inventory`    | stock inconsistency, no stock record                    |
| `data_quality` | missing external identifier, missing cost               |

---

## 5.4 `Purchasing::LineEconomicsCalculator`

### Purpose

Calculate and recalculate purchase order line economics.

### Public API

```ruby
Purchasing::LineEconomicsCalculator.call(
  list_price_cents:,
  expected_retail_price_cents:,
  supplier_discount_bps:,
  expected_unit_cost_cents:,
  quantity_ordered:,
  changed_field:
)
```

### Recalculation rules

| User edits            | System recalculates                     |
| --------------------- | --------------------------------------- |
| List price + discount | Expected unit cost                      |
| Supplier discount     | Expected unit cost                      |
| Expected unit cost    | Supplier discount, if list price exists |
| Expected retail price | Margin only                             |
| Quantity              | Line totals only                        |

### Formulas

```text
expected_unit_cost = list_price * (1 - supplier_discount)
expected_line_cost = expected_unit_cost * quantity
expected_line_retail = expected_retail_price * quantity
expected_margin = expected_line_retail - expected_line_cost
expected_margin_percent = expected_margin / expected_line_retail
```

### Rules

* Retail price does not change cost.
* List price affects discount math.
* Expected unit cost affects purchasing and receiving valuation.
* Quantity changes totals only.
* Manual overrides should be preserved unless user explicitly recalculates from vendor source.

---

## 5.5 `Purchasing::DemandAssignmentService`

### Purpose

Assign purchase demand records to purchase order lines.

### Public API

```ruby
Purchasing::DemandAssignmentService.call!(
  purchase_order_line:,
  purchase_demands:,
  quantities_by_demand_id:,
  actor:
)
```

### Responsibilities

* Validate demand records are open or partially ordered.
* Validate variant compatibility.
* Validate assigned quantity.
* Create `PurchaseOrderLineDemand` records.
* Update demand cached quantities.
* Update demand status.
* Preserve audit trail.

### Rules

* One PO line may satisfy multiple demand records.
* One demand record may be partially assigned.
* Demand assignment does not mean demand is fulfilled.
* Fulfillment requires receipt allocation.

---

## 5.6 `Receiving::ReceiptAllocationService`

### Purpose

Allocate accepted receipt quantities to demand or stock.

### Public API

```ruby
Receiving::ReceiptAllocationService.call!(
  receipt_line:,
  allocations:,
  actor:
)
```

Example allocation payload:

```ruby
[
  {
    allocation_type: "special_order",
    purchase_demand_id: 123,
    quantity_allocated: 1
  },
  {
    allocation_type: "stock",
    quantity_allocated: 3
  }
]
```

### Responsibilities

* Validate accepted quantity.
* Prevent over-allocation.
* Create `ReceiptAllocation` records.
* Update purchase demand allocated/fulfilled quantities.
* Mark demand fulfilled when fully allocated.
* Leave unallocated accepted quantity available for stock posting or later allocation, depending on workflow.

---

# 6. Workflows

## 6.1 Preferred vendor setup

### Product form

User may choose a nullable preferred vendor.

### Variant form

User may choose a nullable preferred vendor.

### Display

On item overview, show:

```text
Preferred vendor: Ingram
Source: Variant preferred vendor
```

If no vendor:

```text
Preferred vendor: None
Warning: No preferred vendor selected for ordering.
```

---

## 6.2 Ingram import preferred vendor behavior

Add import option:

> Set Ingram as preferred vendor for imported or updated products and variants.

### Rules

| Scenario                                          | Behavior                                                  |
| ------------------------------------------------- | --------------------------------------------------------- |
| Product created                                   | Set product preferred vendor to Ingram if option selected |
| Variant created                                   | Set variant preferred vendor to Ingram if option selected |
| Existing product/variant with no preferred vendor | Set if option selected                                    |
| Existing manually selected preferred vendor       | Do not overwrite                                          |
| User selects explicit overwrite                   | Replace existing preferred vendor                         |
| Ingram item data includes buying data             | Create/update vendor source                               |

### Required import settings

| Setting                               |                         Default |
| ------------------------------------- | ------------------------------: |
| `set_preferred_vendor`                |                         `false` |
| `overwrite_existing_preferred_vendor` |                         `false` |
| `create_or_update_vendor_sources`     | `true` when item data available |

---

## 6.3 Create TBO

### User flow

1. User opens item/variant.
2. User selects “Add TBO.”
3. System creates `PurchaseDemand`:

   * `demand_type: tbo`
   * `quantity_requested: 1` by default
   * preferred vendor prefilled when known
   * customer optional
4. User may edit quantity, vendor, needed-by date, and note.

### Rules

* One TBO = one variant.
* Vendor optional.
* Customer optional.
* Used variants may be TBO’d, but later PO conversion may be blocked.
* Gift cards and services should generally not be TBO eligible.

---

## 6.4 Create special order demand

### User flow

1. User selects item/variant.
2. User selects “Create Special Order.”
3. User must attach customer.
4. System creates `PurchaseDemand`:

   * `demand_type: special_order`
   * `customer_id` required
   * preferred vendor prefilled when known
   * status `open`

### Rules

* Customer is required.
* Demand is not fulfilled until receipt allocation.
* Deposit/payment workflow is out of scope for this phase.
* Customer notification is out of scope for this phase.

---

## 6.5 Build PO from demand

### User flow

1. User opens open purchase demands.
2. User filters by:

   * vendor,
   * demand type,
   * status,
   * customer,
   * item.
3. User selects demand records.
4. System groups compatible demand by:

   * preferred/resolved vendor,
   * product variant,
   * ordering eligibility.
5. System creates or appends PO lines.
6. System creates `PurchaseOrderLineDemand` records.
7. Demand status becomes `ordered` or `partially_ordered`.

### Rules

* PO creation must run `Purchasing::OrderEligibilityResolver`.
* Missing vendor source warns but does not block.
* Missing cost warns and requires manual cost before order submission.
* Used variants block normal vendor PO.
* Multiple demand records for the same variant/vendor may roll up into one PO line.
* Demand assignment should be visible from the PO line.

---

## 6.6 Edit PO line economics

### User flow

On a PO line, user may edit:

* list price,
* supplier discount,
* expected unit cost,
* expected retail price,
* quantity,
* line note.

### UI requirements

The line should clearly distinguish:

| Field                 | Meaning                                              |
| --------------------- | ---------------------------------------------------- |
| List price            | Vendor/publisher price used for discount math        |
| Expected retail price | Store selling price                                  |
| Supplier discount     | Discount from list                                   |
| Expected unit cost    | Expected purchasing cost                             |
| Expected margin       | Difference between expected retail and expected cost |

### Immediate recalculation

When user edits economics, recalculate immediately.

### Manual override display

If manual override exists, show clear indicators:

```text
Expected cost: $16.50  Manual override
Expected retail: $28.00  From variant price
```

Possible actions:

* Recalculate from vendor source.
* Clear manual cost override.
* Clear manual price override.

---

## 6.7 Receive ordered items

### User flow

1. User opens purchase order or receipt.
2. User enters quantity received and accepted.
3. System shows linked demand, especially special orders.
4. User allocates accepted quantities:

   * to special order/customer,
   * to stock,
   * to hold/other.
5. System posts only accepted stock quantities to inventory ledger.

### Rules

* Allocation cannot exceed accepted quantity.
* Special order demand is fulfilled only by receipt allocation.
* Partial receipts partially allocate demand.
* Unfulfilled demand remains open/ordered/backordered.
* Extra received quantity may go to stock.

---

# 7. Receiving allocation examples

## Example 1 — One special order, full receipt

```text
Customer special order demand: 1 copy
PO line ordered: 1 copy
Receipt accepted: 1 copy
Allocation: 1 to special order
Demand status: fulfilled
```

## Example 2 — Two special orders, short receipt

```text
Special Order A: 1 copy
Special Order B: 1 copy
PO line ordered: 2 copies
Receipt accepted: 1 copy
Allocation: 1 to Special Order A
Special Order A: fulfilled
Special Order B: ordered / unfulfilled
```

## Example 3 — Demand and stock on same PO line

```text
TBO demand: 1 copy
Special order demand: 1 copy
Buyer adds 2 extra stock copies
PO line ordered: 4 copies
Receipt accepted: 4 copies
Allocation:
  1 to TBO/stock demand
  1 to customer special order
  2 to stock
```

## Example 4 — Used item demand

```text
Used book demand created from item page
Demand type: tbo
Normal vendor PO conversion attempted
Eligibility resolver blocks:
  reason: used_variant
Demand remains open or is cancelled manually
```

---

# 8. UI requirements

## 8.1 Item overview

Show ordering readiness panel:

```text
Ordering
Preferred vendor: Ingram
Vendor source: Active
Orderable: Yes
Expected cost: $12.00
Supplier discount: 40%
Warnings: None
```

If problematic:

```text
Ordering
Preferred vendor: None
Vendor source: Missing
Orderable: Warning
Warnings:
- No preferred vendor selected.
- No active vendor source.
- Expected cost missing.
```

## 8.2 Purchase demand list

Filters:

* status,
* demand type,
* preferred vendor,
* customer,
* item,
* needed by,
* created by.

Columns:

| Column           | Notes                               |
| ---------------- | ----------------------------------- |
| Item             | Variant description                 |
| Type             | TBO, special order, frontlist, etc. |
| Qty requested    | Requested demand                    |
| Qty ordered      | Assigned to PO                      |
| Qty allocated    | Received/allocated                  |
| Customer         | If attached                         |
| Preferred vendor | Nullable                            |
| Status           | Open, ordered, fulfilled            |
| Needed by        | Optional                            |
| Warnings         | Ordering readiness                  |

## 8.3 PO line editor

Required visible fields:

* quantity,
* item,
* list price,
* expected retail price,
* supplier discount,
* expected cost,
* margin,
* source/override indicators.

## 8.4 Receiving screen

When a receipt line has linked demand, display:

| Demand | Customer | Qty requested | Qty already allocated | Qty remaining |
| ------ | -------- | ------------: | --------------------: | ------------: |

Allow user to allocate accepted quantity.

---

# 9. Reporting readiness

After Phase 8.5-3, the following questions should be answerable from stored records:

| Question                                                 | Source                                                                   |
| -------------------------------------------------------- | ------------------------------------------------------------------------ |
| What demand existed before ordering?                     | `purchase_demands`                                                       |
| Was this TBO, special order, frontlist, or sales demand? | `purchase_demands.demand_type`                                           |
| Which vendor was preferred?                              | `purchase_demands.preferred_vendor_id`, product/variant preferred vendor |
| What was ordered?                                        | `purchase_order_lines`                                                   |
| What expected cost was used?                             | `purchase_order_lines.expected_unit_cost_cents`                          |
| Was cost manually overridden?                            | `purchase_order_lines.manual_cost_override`                              |
| What expected margin was projected?                      | PO line economics fields                                                 |
| Which demand caused this PO line?                        | `purchase_order_line_demands`                                            |
| What was actually received?                              | `receipt_lines`                                                          |
| Which received copies fulfilled customer demand?         | `receipt_allocations`                                                    |
| Which special orders remain unfulfilled?                 | demand status + allocation quantities                                    |

---

# 10. Acceptance criteria

## Vendor and item readiness

* Product form supports nullable preferred vendor.
* Variant form supports nullable preferred vendor.
* Preferred vendor resolution is centralized.
* Ingram import can assign preferred vendor.
* Existing manually selected preferred vendors are not overwritten unless explicitly requested.
* Item warnings are centralized and reusable.
* Ordering warnings distinguish blocking, warning, and informational conditions.

## Order eligibility

* Used variants cannot be added to normal vendor POs.
* Gift card/service/non-orderable variants are blocked.
* Inactive products/variants are blocked.
* Inactive vendors are blocked.
* Missing vendor source warns but does not block.
* Missing cost warns but allows manual cost entry.
* Eligibility results are structured and testable.

## PO line economics

* User can edit list price.
* User can edit supplier discount.
* User can edit expected unit cost.
* User can edit expected retail price.
* Related fields recalculate immediately.
* Manual overrides are preserved.
* Source/override indicators are visible.
* PO line stores enough data to report expected margin later.

## Purchase demand

* User can create a TBO for exactly one variant.
* User cannot add multiple line items to one TBO.
* Vendor is optional.
* Customer is optional for TBO.
* Customer is required for special order demand.
* Demand can be filtered by vendor, status, customer, item, and type.
* Demand can be assigned to PO lines.
* One PO line can satisfy multiple demand records.
* Demand status updates when assigned to PO lines.

## Receipt allocation

* Accepted receipt quantity can be allocated to special order demand.
* Special order demand is not fulfilled until receipt allocation occurs.
* Allocation cannot exceed accepted quantity.
* Partial receipt results in partial allocation.
* Extra accepted quantity can go to stock.
* Receipt allocation records preserve customer/demand linkage.

---

# 11. Suggested test plan

## Model tests

### `PurchaseDemand`

* requires product variant,
* requires positive quantity,
* requires valid demand type,
* requires valid status,
* requires customer for special order,
* does not require customer for TBO,
* updates status based on ordered/allocated quantities.

### `PurchaseOrderLineDemand`

* requires PO line,
* requires purchase demand,
* requires positive assigned quantity,
* prevents over-assignment unless override exists,
* updates demand quantities.

### `ReceiptAllocation`

* requires receipt line,
* requires positive quantity,
* prevents over-allocation,
* requires demand for special order allocation,
* updates demand allocated/fulfilled quantities.

---

## Service tests

### `Purchasing::PreferredVendorResolver`

Test precedence:

1. variant preferred vendor,
2. product preferred vendor,
3. variant vendor source,
4. product vendor source,
5. none.

### `Purchasing::OrderEligibilityResolver`

Test:

* normal variant allowed,
* used variant blocked,
* gift card blocked,
* service blocked,
* inactive product blocked,
* inactive variant blocked,
* inactive vendor blocked,
* missing vendor source warns,
* missing cost warns.

### `Purchasing::LineEconomicsCalculator`

Test:

* list price + discount calculates cost,
* cost calculates discount when list exists,
* retail price does not change cost,
* quantity updates totals only,
* margin calculates correctly,
* manual override flags are preserved.

### `Purchasing::DemandAssignmentService`

Test:

* demand assigned to PO line,
* multiple demands assigned to one PO line,
* partial assignment,
* over-assignment rejected,
* status updates correctly.

### `Receiving::ReceiptAllocationService`

Test:

* allocation to special order,
* allocation to stock,
* partial allocation,
* over-allocation rejected,
* demand fulfilled only when fully allocated.

---

## System/UI tests

* create TBO from item page,
* create special order demand with customer,
* attempt special order without customer and fail,
* build PO line from demand,
* edit PO line cost/discount/retail price,
* verify immediate recalculation,
* receive item and allocate to special order,
* verify special order becomes fulfilled only after allocation.

---

# 12. Migration/backfill notes

## Existing TBO records

If existing TBO records already exist:

* migrate each TBO line into one `PurchaseDemand`,
* preserve item, quantity, vendor, customer, note, status, creator, and timestamps where possible,
* if old TBO had multiple lines, create multiple demand records,
* map old header-level note into each demand note or source snapshot.

## Existing purchase order lines

For existing PO lines:

* populate missing `expected_retail_price_cents` from variant price where available,
* populate missing `list_price_cents` from vendor source or variant/list data where available,
* populate missing `expected_unit_cost_cents` from existing cost field where available,
* set `cost_source = unknown` if unclear,
* set `price_source = unknown` if unclear,
* set manual override flags to `false` unless existing data indicates manual entry.

## Existing special order records

If special orders exist separately:

* migrate open special orders to `PurchaseDemand.demand_type = special_order`,
* require customer linkage or mark as data exception,
* preserve original source record in `source_record_type/id`.

---

# 13. Recommended implementation order

## Step 1 — Vendor and warning foundation

* Add preferred vendor fields.
* Add `Purchasing::PreferredVendorResolver`.
* Add ordering subset of `Items::OperationalWarningBuilder`.
* Add Ingram preferred vendor import option.

## Step 2 — Order eligibility

* Add `Purchasing::OrderEligibilityResolver`.
* Integrate resolver into PO line add flow.
* Add blocking/warning UI.

## Step 3 — PO line economics

* Add/edit economics fields.
* Add `Purchasing::LineEconomicsCalculator`.
* Add manual override behavior.
* Add recalculation UI.

## Step 4 — Purchase demand

* Add `PurchaseDemand`.
* Implement TBO creation.
* Implement special order demand creation.
* Add demand list/filtering.

## Step 5 — Demand-to-PO assignment

* Add `PurchaseOrderLineDemand`.
* Allow demand records to create/append to PO lines.
* Update demand statuses.

## Step 6 — Receipt allocation foundation

* Add `ReceiptAllocation`.
* Allocate accepted receipt quantity to special orders or stock.
* Ensure special orders are fulfilled only from receipt allocations.

---

# 14. Final implementation principle

Phase 8.5-3 should produce this reliable operational chain:

```text
A bookseller identifies demand
  → the system resolves vendor/orderability
  → the buyer places a PO with expected economics
  → receiving records what actually arrived
  → received quantity is allocated to customer demand or stock
```
