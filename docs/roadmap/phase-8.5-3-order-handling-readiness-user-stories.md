# Phase 8.5-3 User Stories — Order Handling Readiness

Recommended path:

```text
docs/specifications/phase-8.5-3a-order-handling-readiness-spec.md
docs/roadmap/phase-8.5-3-order-handling-readiness.md
```

**Revised:** Epics 4–7 align with 8.5-3a/b/c split. No unified `PurchaseDemand` model.

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

# Epic 4 — TBO simplification (Phase 8.5-3b)

Uses existing `purchase_requests` / `purchase_request_lines`. No unified `PurchaseDemand` model.

## Story 4.1 — Create single-line TBO from item page

**As a bookseller,**
I want to mark a single item as To Be Ordered from the item page,
**so that buyer demand can be captured quickly without creating a purchase order.**

### Acceptance criteria

* New TBO create flow accepts exactly one product variant.
* Quantity defaults to `1` and can be increased.
* `:tbo` eligibility runs at create (allows used; blocks service/financial).
* Suggested vendor is displayed from extended resolver but **not stored** on the request line.
* Legacy multi-line purchase requests remain viewable.

---

## Story 4.2 — Single-line TBO enforcement (UI/service only)

**As a buyer,**
I want each new TBO to represent one item only,
**so that demand records stay simple.**

### Acceptance criteria

* `PurchaseRequests::CreateSingleLine` enforces one line per new request.
* No model validation breaks legacy multi-line requests or seeds.
* TBO list shows suggested vendor from resolver at display time.

---

# Epic 5 — Build PO from TBO and special orders (existing paths)

## Story 5.1 — Build PO from TBO lines

**As a buyer,**
I want to convert open TBO lines into a draft purchase order,
**so that captured demand becomes an actual order.**

### Acceptance criteria

* `Purchasing::BuildPurchaseOrder` applies full PO eligibility per TBO line.
* TBO-backed PO lines link via `purchase_request_line_id`.
* Cannot merge special-order allocation onto a TBO-backed PO line for the same variant.

---

## Story 5.2 — Special orders via Phase 7A chain

**As a frontline bookseller,**
I want customer special orders to follow the existing Phase 7A workflow,
**so that customer-linked demand is not collapsed into a unified demand model.**

### Acceptance criteria

* Special orders use `purchase_order_line_allocations` unchanged.
* Customer linkage remains on `customer_requests` / `special_orders`.
* Receipt FIFO allocation via `Receiving::AllocateCustomerDemandFromReceipt` is unchanged.

---

# Epic 6 — Receiving allocation visibility (Phase 8.5-3c)

Read-only UX. No changes to allocation services.

## Story 6.1 — Show projected vs actual stock split

**As a receiving clerk,**
I want to see how accepted quantity will split between special orders and stock,
**so that I understand fulfillment before and after posting.**

### Acceptance criteria

* Draft receipts label stock quantity as **Projected stock quantity**.
* Posted receipts label stock quantity as **Actual stock quantity**.
* Pre-post message: will auto-allocate to N special orders on post.
* Post-post shows actual `receipt_line_allocations` rows.

---

## Story 6.2 — Show PO allocation context on receipt

**As a buyer,**
I want receipt detail to show linked special orders and allocation quantities,
**so that I can reconcile customer demand against what arrived.**

### Acceptance criteria

* Receipt show displays customer names, PO allocation qty, received, and remaining.
* FIFO allocation behavior is unchanged (regression tests required).

---

# Epic 7 — Future work (out of scope for 8.5-3)

* Unified demand inbox / `PurchaseDemand` model
* Sales-based reorder and frontlist demand types
* Manual receipt allocation replacing auto FIFO
* Cascading orders and multi-PO receiving UI

---

# Suggested implementation sequence

| Order | Story group                             |
| ----: | --------------------------------------- |
|     1 | Preferred vendor fields and resolver    |
|     2 | Operational warning builder             |
|     3 | Order eligibility resolver              |
|     4 | PO line economics and override behavior |
|     5 | TBO single-line create (8.5-3b)         |
|     6 | Build PO eligibility and merge guard    |
|     7 | Receipt allocation visibility (8.5-3c)  |
