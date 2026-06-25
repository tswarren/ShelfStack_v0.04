# Phase 8.5-3 — Order Handling Readiness

**Status:** Draft (revised)

**Canonical spec:** This document supersedes the earlier unified-demand draft. It extends the existing Phase 5 purchasing and Phase 7A customer-demand architecture rather than replacing it.

Related:

```text
docs/roadmap/phase-8.5-operational-cleanup.md  (Epics 4–6)
docs/specifications/phase-7a-customer-demand-spec.md
docs/specifications/phase-5-purchasing-and-receiving-spec.md
docs/roadmap/phase-8.5-3-order-handling-readiness-user-stories.md  (to be aligned)
```

---

## Purpose

Make ShelfStack’s ordering workflow **reliable, auditable, and report-ready** before deeper reporting and advanced replenishment features are built.

Phase 8.5 focuses on operational records that reports will depend on:

* what was ordered,
* from which vendor,
* at what expected cost,
* which items are orderable,
* which vendor should be used by default.

Phase 8.5-3 does **not** build a full automated purchasing engine, unified demand platform, or sales/frontlist reorder tooling. It improves vendor defaults, ordering eligibility, PO line economics, operational warnings, TBO usability, and (later) receiving allocation visibility on **existing tables and services**.

---

## Revision summary

The original draft clarified the desired operational chain but overreached by proposing greenfield models (`PurchaseDemand`, `PurchaseOrderLineDemand`, `ReceiptAllocation`) that conflict with completed Phase 7A behavior.

| Earlier draft | Revised decision |
| ------------- | ---------------- |
| Unified `PurchaseDemand` for TBO + special orders | **Do not build** in 8.5-3 |
| Migrate special orders into demand records | **Do not do** |
| New `ReceiptAllocation` model | **Do not create** — extend `receipt_line_allocations` |
| New `Purchasing::PreferredVendorResolver` | **Extend** `Purchasing::SuggestedVendorResolver` |
| Rename PO cost columns (`list_price_cents`, `expected_unit_cost_cents`) | **Keep** existing `unit_list_price_cents`, `unit_cost_cents` |
| Unified demand inbox | **Future** presentation layer only |
| Sales reorder / frontlist demand types | **Future** |

---

# 1. Operational chains (keep separate)

ShelfStack already has two ordering-intent paths. Phase 8.5-3 must preserve both.

## 1.1 Internal TBO (Phase 5)

```text
purchase_requests / purchase_request_lines
  → purchase_order_lines.purchase_request_line_id
  → receipt_lines
  → inventory posting (stock)
```

* TBO is **internal**, store-scoped, not customer-committed.
* `Purchasing::BuildPurchaseOrder` accepts TBO via `purchase_request_line_id`.
* Phase 7A explicitly keeps this path unchanged.

## 1.2 Customer demand (Phase 7A)

```text
customer_requests / customer_request_lines
  → special_orders
  → purchase_order_line_allocations
  → receipt_line_allocations
  → inventory_reservations (incoming → on-hand)
  → POS pickup
```

* Special orders are **first-class commitment records** with their own statuses and quantity buckets.
* Customer linkage lives on `customer_requests` / `special_orders`, not on TBO.
* `Receiving::AllocateCustomerDemandFromReceipt` runs inside `Purchasing::PostReceipt` and creates `receipt_line_allocations` via FIFO from PO allocations.
* Phase 7A warns **not** to merge TBO-backed PO lines with customer allocations unless explicitly supported.

## 1.3 Conceptual chain (reporting view)

Both paths share this reporting story:

```text
Ordering intent
  → purchase order commitment
    → receipt
      → allocation / fulfillment
```

Implementation stays on **existing tables**; do not collapse both paths into one demand abstraction in 8.5-3.

---

# 2. Phase split

## Phase 8.5-3a — Ordering readiness (P0)

High value, low risk, **no domain migration**.

* Preferred vendor on products and variants.
* Extend `Purchasing::SuggestedVendorResolver` with product/variant preferred vendor precedence.
* `Purchasing::OrderEligibilityResolver`.
* Ordering subset of `Items::OperationalWarningBuilder` (coordinate with `Purchasing::SourcingWarnings`).
* PO line economics cleanup on **existing columns** plus additive snapshot fields.
* `Purchasing::LineEconomicsCalculator` wrapping `VendorCostCalculator` / `LinePriceDefaults`.
* Ingram import option to set preferred vendor.
* Block invalid variants from normal vendor POs.

## Phase 8.5-3b — TBO simplification

TBO-only UX and workflow cleanup on existing `purchase_requests` / `purchase_request_lines`.

* One variant per TBO request (UI enforcement; keep existing tables).
* Optional vendor resolution via extended resolver (no new TBO customer FK in 8.5-3).
* Better filtering and conversion to PO.
* Clearer build-from-TBO flow in Orders workspace.
* **No** special-order migration; customer ordering stays on Phase 7A path.

## Phase 8.5-3c — Receiving allocation visibility (optional / later)

Enhance receiving UX without changing post behavior until explicitly designed.

* Show linked special orders and customer-reserved quantities on receipt lines.
* Show stock vs customer split after post.
* **Default:** keep automatic FIFO allocation in `Receiving::AllocateCustomerDemandFromReceipt`.
* Manual pre-post allocation or post override is a **separate design decision** — do not change `Purchasing::PostReceipt` behavior in 8.5-3c unless that decision is made.
* Extend `receipt_line_allocations` if explicit stock rows or allocation types are needed; do not add a parallel allocation model.

---

# 3. Scope

## In scope (8.5-3a)

1. `preferred_vendor_id` on products and variants.
2. Extended vendor resolution (`SuggestedVendorResolver`).
3. `Purchasing::OrderEligibilityResolver`.
4. `Items::OperationalWarningBuilder` (ordering + data-quality subset first).
5. Editable PO line economics with recalculation and override indicators.
6. Ingram preferred-vendor import option.
7. Tests for resolver precedence, eligibility, economics, and warnings.

## In scope (8.5-3b)

1. TBO UX: one variant per request, improved create/list/filter/build-to-PO flows.
2. Preserve `purchase_request_line_id` on PO lines.
3. Regression tests on existing TBO → PO path.

## In scope (8.5-3c, when scheduled)

1. Receiving screen visibility for customer allocations.
2. Optional extensions to `receipt_line_allocations` for explicit stock/customer labeling.
3. No change to auto-allocation on post unless explicitly approved.

## Out of scope (all sub-phases)

* `PurchaseDemand`, `PurchaseOrderLineDemand`, or new `ReceiptAllocation` models.
* Migration of special orders into a unified demand table.
* Automatic sales-based reorder suggestions.
* Full min/max replenishment engine.
* Full frontlist buying tool.
* Unified demand inbox (future UI over existing tables only).
* Merging TBO-backed PO lines with customer allocations (unless a future phase explicitly designs it).
* Moving submitted PO lines between vendors.
* Cascading orders between vendors.
* Receive-across-multiple-PO UI.
* Customer notification, deposits, pickup/abandoned-order workflow (Phase 7A / later).
* Full vendor performance reporting.
* Full item page redesign.

---

# 4. Core design decisions

## 4.1 Do not unify demand in the database

TBO and special orders represent different business commitments. They already have distinct models, services, and tests. Phase 8.5-3 improves readiness around them; it does not replace them.

## 4.2 TBO may exist when vendor PO is blocked

A user may create TBO for an item even when it cannot be added to a normal vendor PO (e.g. used copy for internal tracking). TBO creation and PO conversion use **different** eligibility rules.

| Item | TBO allowed? | Normal vendor PO allowed? |
| ---- | -----------: | ------------------------: |
| New trade paperback | Yes | Yes |
| Used book | Yes | No |
| Discontinued title | Yes | Override or block |
| Gift card | No | No |
| Service item | Usually no | No |

## 4.3 Special order fulfillment stays receipt-based (Phase 7A)

A special order is not fulfilled because it was placed on a PO. Fulfillment requires accepted receipt quantity allocated through `receipt_line_allocations` and reservation conversion — already implemented. 8.5-3c may improve visibility; it must not regress this behavior by default.

## 4.4 Receipt allocation extends existing records

Receiving answers: *What arrived?* Allocation answers: *Where did accepted quantity go?*

Phase 7A `receipt_line_allocations` already link receipt lines to `special_order`, `purchase_order_line_allocation`, `customer_request_line`, and `inventory_reservation`. Extend this model if 8.5-3c needs explicit stock vs customer labeling; do not introduce a parallel table.

## 4.5 PO economics use existing column names

Controllers already permit editing:

```ruby
unit_list_price_cents
supplier_discount_bps
unit_cost_cents
```

Add new fields only where missing. Do not rename existing economics columns without an explicit migration decision.

## 4.6 Used variant = condition-based

For ordering eligibility, **used** means `product_condition.new_condition = false` on the variant’s condition. Do not introduce a separate “used” flag.

## 4.7 `orderable` is distinct from inventory tracking

Add `product_variants.orderable` (boolean) for explicit vendor-order eligibility edge cases. Default at create time from product type and condition; distinct from `inventory_behavior` / Phase 8 tracking. A variant may be inventory-tracked but not vendor-orderable, or explicitly orderable but non-inventory (rare; manual enable only).

---

# 5. Terminology

| Term | Meaning |
| ---- | ------- |
| TBO | Internal store reorder intent on `purchase_request_lines` |
| Special order | Customer-backed commitment on `special_orders` (Phase 7A) |
| Preferred vendor | Vendor the store usually expects for ordering an item |
| Vendor source | `product_vendors` / `product_variant_vendors` purchasing data |
| Order eligibility | Whether a variant may be added to a normal vendor PO |
| PO line economics | List price, discount, unit cost, retail snapshot, margin metadata on a PO line |
| Receipt allocation | Assignment of accepted receipt qty via `receipt_line_allocations` |
| Suggested vendor | Resolved vendor from extended `SuggestedVendorResolver` |

User-facing labels remain **TBO**, **Special Order**, **Preferred vendor**. Do not expose internal “purchase demand” language in the UI for 8.5-3.

---

# 6. Data model

## 6.1 Products — add

| Field | Type | Notes |
| ----- | ---- | ----- |
| `preferred_vendor_id` | bigint | Nullable FK to `vendors` |

Rules:

* Nullable; optional on form.
* Set manually or by Ingram import when allowed.
* Do not overwrite existing manual selection unless import overwrite is explicitly selected.

## 6.2 Product variants — add

| Field | Type | Notes |
| ----- | ---- | ----- |
| `preferred_vendor_id` | bigint | Nullable FK to `vendors`; overrides product |
| `orderable` | boolean | Default from product type/condition at create; editable |

Rules:

* `preferred_vendor_id` overrides product preferred vendor.
* `orderable` is separate from inventory tracking.
* Used conditions default `orderable: false` unless explicitly overridden by staff with permission (future override key if needed).

## 6.3 Purchase order lines — extend (keep existing names)

**Existing fields (retain):**

| Field | Notes |
| ----- | ----- |
| `unit_list_price_cents` | Vendor/publisher list price |
| `supplier_discount_bps` | Nullable; 40% = `4000` |
| `unit_cost_cents` | Expected net unit cost |
| `purchase_request_line_id` | TBO link (unchanged) |
| `product_variant_vendor_id` | Sourcing link (unchanged) |

**Add if missing:**

| Field | Type | Notes |
| ----- | ---- | ----- |
| `expected_retail_price_cents` | integer | Store selling price snapshot |
| `expected_line_cost_cents` | integer | Cached: `unit_cost_cents * quantity_ordered` |
| `expected_line_retail_cents` | integer | Cached retail total |
| `expected_margin_cents` | integer | Cached margin |
| `expected_margin_bps` | integer | Cached margin percent (basis points) |
| `cost_source` | string | `vendor_source`, `manual`, `import`, `default`, `unknown` |
| `price_source` | string | `variant`, `vendor_source`, `manual`, `import`, `unknown` |
| `manual_cost_override` | boolean | Default `false` |
| `manual_price_override` | boolean | Default `false` |
| `line_note` | text | Optional |
| `source_snapshot` | jsonb | Optional economics/sourcing snapshot at submit |

UI labels may say “List price” and “Expected unit cost”; storage remains `unit_list_price_cents` and `unit_cost_cents`.

## 6.4 TBO — no new table (8.5-3b)

Keep `purchase_requests` and `purchase_request_lines`.

8.5-3b UX rules:

* **One variant per TBO request** — enforce in UI (single line per request, or line-first create flow).
* Multi-line legacy requests may exist; list/filter should still work; new creates follow one-variant rule.
* **No `customer_id` on TBO** in 8.5-3 — customer-backed ordering uses `customer_requests` → `special_orders`.
* Optional `preferred_vendor_id` on request line is **out of scope** unless added in a later sub-phase; vendor comes from resolver at PO build time.

## 6.5 Customer demand — unchanged (Phase 7A)

Do not migrate. Key tables:

| Table | Role |
| ----- | ---- |
| `special_orders` | Customer commitment, statuses, quantity buckets |
| `purchase_order_line_allocations` | Links PO line to special order qty |
| `receipt_line_allocations` | Links accepted receipt qty to special order / reservation |
| `inventory_reservations` | Incoming and on-hand holds |

## 6.6 Receipt lines — unchanged expectations

Existing `receipt_lines` fields remain authoritative. Future receive-across-PO is out of scope; do not assume one receipt = one PO forever in **design**, but 8.5-3 UI continues PO-scoped receiving.

## 6.7 Receipt line allocations — extend only if needed (8.5-3c)

Existing Phase 7A fields remain. Optional future additions (8.5-3c only):

| Field | Notes |
| ----- | ----- |
| `allocation_type` | e.g. `special_order`, `stock` — only if explicit stock rows are required |

Do not replace or duplicate this table.

---

# 7. Service objects

## 7.1 Extend `Purchasing::SuggestedVendorResolver` (8.5-3a)

Do not add a parallel resolver. Extend the existing service and migrate call sites to one canonical API.

### Resolution order

1. Variant `preferred_vendor_id`.
2. Product `preferred_vendor_id`.
3. Active `product_variant_vendors` row with `preferred: true`.
4. Active `product_vendors` row with `preferred: true`.
5. First active variant vendor source (existing fallback).
6. First active product vendor source (existing fallback).
7. No vendor.

### Result object (extend existing)

Add `source` (and optional `warnings`) to the existing `Result` struct:

| Source | Meaning |
| ------ | ------- |
| `variant_preferred` | Explicit preferred vendor on variant |
| `product_preferred` | Explicit preferred vendor on product |
| `variant_vendor_source` | Preferred flag on variant vendor row |
| `product_vendor_source` | Preferred flag on product vendor row |
| `variant_vendor_fallback` | First variant vendor (existing behavior) |
| `product_vendor_fallback` | First product vendor (existing behavior) |
| `none` | No vendor found |

## 7.2 `Purchasing::OrderEligibilityResolver` (8.5-3a)

```ruby
Purchasing::OrderEligibilityResolver.call(
  product_variant:,
  vendor: nil,
  context: :purchase_order
)
```

### Result

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

| Condition | Behavior |
| --------- | -------- |
| Used variant (`new_condition: false`) | Block normal vendor PO |
| Gift card / service / financial product type | Block |
| `orderable: false` | Block |
| Non-inventory and not explicitly orderable | Block |
| Variant inactive | Block |
| Product inactive | Block |
| Vendor inactive | Block |
| Discontinued catalog item | Block or require manager override |
| Missing vendor source | Warning; allow |
| Missing cost | Warning; allow manual cost |
| Missing preferred vendor | Warning; allow vendor selection |
| Missing external identifier | Info/warning; allow |

Integrate into PO line add, `BuildPurchaseOrder`, and TBO-to-PO conversion.

## 7.3 `Items::OperationalWarningBuilder` (8.5-3a)

Cross-context warnings for item overview, PO line entry, and TBO create.

```ruby
Items::OperationalWarningBuilder.call(
  product_variant:,
  contexts: [:sale, :ordering, :inventory, :data_quality]
)
```

Delegate ordering warnings to `OrderEligibilityResolver` where appropriate. Do not duplicate `Purchasing::SourcingWarnings` PO-scoped messages — that service remains for draft/submitted PO review.

## 7.4 `Purchasing::LineEconomicsCalculator` (8.5-3a)

Wrap existing `VendorCostCalculator` and coordinate with `LinePriceDefaults`.

Uses **`unit_list_price_cents`**, **`unit_cost_cents`**, **`supplier_discount_bps`**, **`expected_retail_price_cents`**, **`quantity_ordered`**.

### Recalculation rules

| User edits | System recalculates |
| ---------- | ------------------- |
| List price + discount | Unit cost |
| Supplier discount | Unit cost |
| Unit cost | Discount, if list price exists |
| Expected retail price | Margin caches only |
| Quantity | Line total caches only |

Formulas:

```text
unit_cost_cents = unit_list_price_cents * (1 - supplier_discount_bps / 10000)
expected_line_cost_cents = unit_cost_cents * quantity_ordered
expected_line_retail_cents = expected_retail_price_cents * quantity_ordered
expected_margin_cents = expected_line_retail_cents - expected_line_cost_cents
```

Manual overrides preserved until user recalculates from vendor source or clears override flags.

## 7.5 Existing services — retain (no replacement)

| Service | Role |
| ------- | ---- |
| `Purchasing::BuildPurchaseOrder` | TBO + special order → PO |
| `SpecialOrders::AttachToPurchaseOrderLine` | Customer allocation on PO line |
| `Purchasing::AllocateCustomerDemandToPoLine` | Creates `purchase_order_line_allocations` |
| `Receiving::AllocateCustomerDemandFromReceipt` | FIFO receipt allocation on post |
| `Purchasing::SourcingWarnings` | PO-level missing vendor source warnings |
| `Purchasing::LinePriceDefaults` | Default economics from sourcing |
| `Purchasing::SubmitPurchaseOrder` | Submit-time snapshots |

---

# 8. Workflows

## 8.1 Preferred vendor setup (8.5-3a)

* Product and variant forms: nullable preferred vendor.
* Item Operations tab shows resolved vendor and source from extended resolver.
* Inactive vendors cannot be newly assigned.

## 8.2 Ingram import (8.5-3a)

Import option: **Set Ingram as preferred vendor for imported/updated products and variants.**

| Scenario | Behavior |
| -------- | -------- |
| Product/variant created | Set preferred vendor if option enabled |
| Existing record, no preferred vendor | Set if option enabled |
| Existing manual preferred vendor | Do not overwrite |
| User selects overwrite | Replace preferred vendor |
| Ingram buying data present | Create/update vendor source rows |

Settings:

| Setting | Default |
| ------- | ------: |
| `set_preferred_vendor` | `false` |
| `overwrite_existing_preferred_vendor` | `false` |
| `create_or_update_vendor_sources` | `true` when data available |

## 8.3 Create TBO (8.5-3b — existing path)

1. User opens item/variant → Add TBO.
2. System creates or appends **`purchase_request_line`** (one variant).
3. Resolver prefills suggested vendor at PO build time (not necessarily stored on line).
4. User edits quantity and note.

Rules:

* One variant per new TBO request.
* No customer on TBO in 8.5-3.
* Used variants may be TBO’d; PO conversion runs eligibility and may block.
* Gift cards and services not TBO-eligible.

## 8.4 Create special order (Phase 7A — unchanged)

Use existing path:

```text
customer_request → customer_request_line → special_orders
```

Do not create parallel “special order demand” records. Customer required via customer request workflow.

## 8.5 Build PO (existing + eligibility)

### From TBO

1. User filters open TBO lines (Orders workspace).
2. User selects lines for a vendor.
3. `BuildPurchaseOrder` creates PO lines with `purchase_request_line_id`.
4. `OrderEligibilityResolver` runs per line; blocks/warns as configured.

### From special orders

1. User attaches approved special orders to draft PO lines via existing attach flow.
2. `purchase_order_line_allocations` created; incoming reservations reserved.
3. **Do not** merge TBO-backed lines with customer allocations on the same PO line in 8.5-3.

## 8.6 Edit PO line economics (8.5-3a)

User edits on draft PO:

* unit list price,
* supplier discount,
* unit cost,
* expected retail price,
* quantity,
* line note.

Show override indicators and “recalculate from vendor source” actions. On submit, `SubmitPurchaseOrder` continues snapshot behavior; add `cost_source` / `price_source` / margin caches as implemented.

## 8.7 Receive ordered items (Phase 7A + 8.5-3c visibility)

**Current behavior (preserve):**

1. User posts receipt with accepted quantities.
2. `AllocateCustomerDemandFromReceipt` FIFO-allocates to linked special orders.
3. `receipt_line_allocations` and reservation conversion created automatically.
4. Remaining accepted qty posts to inventory as stock.

**8.5-3c additions (visibility only, unless manual allocation is explicitly approved):**

* Show linked special orders and allocation summary on receipt line before/after post.
* Show unallocated accepted qty destined for stock.

---

# 9. Examples

## Example 1 — Special order, full receipt (Phase 7A)

```text
Special order: 1 copy committed
PO line: 1 copy with purchase_order_line_allocation
Receipt accepted: 1 copy
Auto allocation: 1 to special order via receipt_line_allocation
Special order: ready_for_pickup
```

## Example 2 — Two special orders, short receipt

```text
Special Order A: 1 copy on PO line (qty 2 total ordered)
Special Order B: 1 copy on same PO line
Receipt accepted: 1 copy
FIFO: 1 to Special Order A
Special Order B: still ordered / awaiting receipt
```

## Example 3 — TBO + stock on separate PO lines

```text
TBO line: 1 copy → PO line A (purchase_request_line_id set)
Buyer adds manual stock line: 2 copies → PO line B (no allocation)
Receipt: allocate customer qty only on lines with allocations; stock posts from unallocated accepted qty
```

Do not combine TBO and special-order allocations on one PO line in 8.5-3.

## Example 4 — Used item TBO blocked at PO

```text
Used variant TBO created for tracking
Build PO from TBO attempted
OrderEligibilityResolver blocks: used_variant
TBO remains open or user cancels
```

---

# 10. UI requirements

## 10.1 Item overview / Operations (8.5-3a)

Ordering readiness panel:

```text
Ordering
Preferred vendor: Ingram (variant preferred)
Vendor source: Active
Orderable: Yes
Expected cost: $12.00
Supplier discount: 40%
Warnings: None
```

Warnings from `OperationalWarningBuilder`; blocking vs warning vs info severities.

## 10.2 TBO list (8.5-3b)

Filters: status, item/variant, store, created date.

Columns: item, qty requested, status, linked PO (if any), warnings.

No unified “demand inbox” mixing TBO and special orders in 8.5-3.

## 10.3 PO line editor (8.5-3a)

Visible: quantity, item, unit list price, expected retail price, supplier discount, unit cost, margin caches, source/override indicators.

## 10.4 Receiving screen (8.5-3c)

When receipt line has PO allocations, show:

| Special order | Customer | Qty allocated on PO | Qty received prior | Qty remaining |
| ------------- | -------- | ------------------: | -----------------: | ------------: |

Read-only visibility in 8.5-3c unless manual allocation is explicitly in scope.

---

# 11. Reporting readiness

After Phase 8.5-3, these questions should be answerable from **existing and extended** records:

| Question | Source |
| -------- | ------ |
| What internal reorder intent existed? | `purchase_request_lines` + status |
| What customer commitment existed? | `special_orders`, `customer_request_lines` |
| Which vendor was preferred? | `products.preferred_vendor_id`, `product_variants.preferred_vendor_id`, vendor sources |
| What was ordered? | `purchase_order_lines` |
| What expected cost was used? | `purchase_order_lines.unit_cost_cents`, `cost_source` |
| Was cost manually overridden? | `purchase_order_lines.manual_cost_override` |
| What expected margin was projected? | PO line margin cache fields |
| Which TBO caused this PO line? | `purchase_order_lines.purchase_request_line_id` |
| Which special orders caused this PO line? | `purchase_order_line_allocations` |
| What was actually received? | `receipt_lines` |
| Which received copies fulfilled customer demand? | `receipt_line_allocations` |
| Which special orders remain unfulfilled? | `special_orders.status`, quantity buckets |

---

# 12. Acceptance criteria

## 8.5-3a — Ordering readiness

* Product and variant forms support nullable preferred vendor.
* Extended `SuggestedVendorResolver` returns vendor + source; used across Items and Orders.
* `OrderEligibilityResolver` blocks used/gift card/service/non-orderable/inactive paths.
* Missing vendor source warns; missing cost warns with manual entry allowed.
* PO line economics editable with immediate recalculation on existing column names.
* Override flags and sources stored; margin caches populated when retail price present.
* Ingram import can set preferred vendor without silent overwrite.
* `OperationalWarningBuilder` surfaces consistent ordering warnings on item overview.
* `Purchasing::SourcingWarnings` remains for PO draft review (no duplicate logic).

## 8.5-3b — TBO simplification

* New TBO creates one variant per request (UI enforced).
* TBO list/filter improved; build-to-PO flow uses existing services.
* TBO → PO regression tests pass.
* No customer FK added to TBO tables.
* Special order workflow unchanged.

## 8.5-3c — Receiving visibility (when scheduled)

* Receipt show/edit surfaces linked special orders and allocation outcomes.
* Auto FIFO allocation on post unchanged unless explicitly redesigned.
* No new allocation table introduced.

---

# 13. Test plan

## 8.5-3a

### `Purchasing::SuggestedVendorResolver` (extended)

* variant preferred → product preferred → preferred vendor source → fallback → none.

### `Purchasing::OrderEligibilityResolver`

* new condition allowed; used blocked; gift card/service blocked; inactive blocked; warnings for missing source/cost.

### `Purchasing::LineEconomicsCalculator`

* list + discount → cost; cost → discount; retail changes margin only; quantity changes totals; overrides preserved.

### `Items::OperationalWarningBuilder`

* severities and categories; coordination with eligibility resolver.

### Integration

* edit PO line economics in Orders UI; submit snapshots; Ingram import preferred vendor option.

## 8.5-3b

* create single-variant TBO; build PO; eligibility block for used variant.
* regression: existing `BuildPurchaseOrder` + TBO tests.

## 8.5-3c

* receipt show presents allocation summary after post.
* regression: `Receiving::AllocateCustomerDemandFromReceipt` unchanged.

## Regression suites (always)

* Phase 7A special order attach, receipt allocation, pickup.
* Phase 5 TBO/PO/receipt paths.

---

# 14. Migration and backfill

## Preferred vendor

No backfill required. Nullable columns; import may populate over time.

## PO line economics (8.5-3a)

For existing `purchase_order_lines`:

* populate `expected_retail_price_cents` from variant `selling_price_cents` where missing,
* set `cost_source` / `price_source` to `unknown` where unclear,
* set override flags to `false` unless evidence of manual entry,
* compute margin caches where retail and cost exist.

Use **`unit_list_price_cents`** and **`unit_cost_cents`** — do not rename columns.

## TBO / special orders

**No migration** to unified demand tables. Legacy multi-line `purchase_requests` remain valid; new creates follow one-variant UX.

---

# 15. Implementation order

## Step 1 — 8.5-3a foundation

1. Migrations: `preferred_vendor_id`, `orderable`, PO line additive fields.
2. Extend `SuggestedVendorResolver`.
3. Add `OrderEligibilityResolver`; wire into PO flows.
4. Add `OperationalWarningBuilder` ordering subset.
5. Add `LineEconomicsCalculator` + PO UI recalculation.
6. Ingram import preferred vendor option.
7. Tests + docs (`AGENTS.md`, schema-reference, domain-model as needed).

## Step 2 — 8.5-3b TBO simplification

1. TBO create/list/filter UX on existing models.
2. Enforce one-variant-per-request in UI.
3. Improve build-from-TBO using resolver + eligibility.
4. Tests + user story alignment.

## Step 3 — 8.5-3c receiving visibility (optional)

1. Receipt presenter enhancements.
2. Decide manual vs auto allocation policy before any post-behavior change.
3. Extend `receipt_line_allocations` only if required.

---

# 16. Final principle

Phase 8.5-3 is **ordering readiness on existing architecture**, not a unified demand platform:

```text
Staff identifies need (TBO or special order — separate paths)
  → system resolves vendor and orderability
  → buyer places PO with trustworthy economics snapshots
  → receiving records what arrived
  → accepted qty allocates to customers (Phase 7A) or stock
```

Preserve Phase 7A customer-demand integrity. Extend Phase 5 purchasing records. Defer sales reorder, frontlist, unified inbox, and receive-across-PO to later phases.
