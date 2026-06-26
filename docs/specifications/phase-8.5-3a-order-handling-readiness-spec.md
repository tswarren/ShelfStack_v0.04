# Phase 8.5-3a Spec — Ordering Readiness

## Purpose

Extend existing Phase 5 purchasing and Phase 7A customer-demand architecture so staff can reliably order from vendors with correct defaults, eligibility gates, and auditable PO line economics.

Do **not** introduce unified demand models. Preserve separate TBO and special-order chains.

---

# 1. Scope

## In scope

1. `products.preferred_vendor_id` and `product_variants.preferred_vendor_id`
2. `product_variants.orderable` with service-driven defaults via `ProductVariants::OrderabilityDefaults`
3. Extended `Purchasing::SuggestedVendorResolver` with preferred-vendor precedence and `source`
4. `Purchasing::OrderEligibilityResolver` (contexts: `:purchase_order`, `:purchase_order_submit`, `:tbo`)
5. Submit gate in `Purchasing::SubmitPurchaseOrder`
6. PO line economics fields and `Purchasing::LineEconomicsCalculator` (server canonical)
7. `Items::OperationalWarningBuilder` on Items Operations tab
8. Ingram import preferred-vendor options
9. Phase 7A regression: special-order allocations and receipt FIFO unchanged

## Out of scope

* Unified `PurchaseDemand` / demand inbox
* Merging TBO-backed PO lines with customer allocations (except existing explicit block)
* TBO simplification UX (8.5-3b)
* Receipt allocation visibility (8.5-3c)
* Discontinued manager override
* `preferred_vendor_id` on `purchase_request_lines`

---

# 2. Preferred vendor

Precedence in `SuggestedVendorResolver`:

```text
variant preferred → product preferred → variant vendor source (preferred) → product vendor source (preferred) → variant fallback → product fallback → none
```

Inactive preferred vendors are skipped. Result includes `source` from allowed values.

Staff may set preferred vendor on product and variant forms. Inactive vendor assignment is blocked.

---

# 3. Orderability

`ProductVariants::OrderabilityDefaults` is invoked from variant create paths and backfill migration — **not** a model callback for ongoing updates.

| Condition / type | Default `orderable` |
| ---------------- | ------------------: |
| New physical sellable | `true` |
| Used condition | `false` |
| Service / financial product type | `false` |
| Non-inventory physical | `false` |
| Null condition physical | `true` |

Staff may manually enable `orderable` on edge-case variants.

---

# 4. Eligibility

## Hard blockers (PO draft add/update and PO build)

* Inactive product / variant / vendor
* Service / financial product type
* Used condition (`new_condition: false`)
* `orderable: false`
* Non-inventory without explicit `orderable: true`

## Warnings only (draft save allowed)

* Missing vendor source
* Missing preferred vendor
* Missing cost
* Missing catalog identifier
* Discontinued / publication_cancelled catalog status

## Submit gate (`:purchase_order_submit`)

All hard blockers plus discontinued catalog status (warning escalates to submit block). No manager override in 8.5-3a.

## TBO context (`:tbo`)

Allows used variants. Blocks service / financial types.

---

# 5. PO line economics

Additive columns on `purchase_order_lines`:

* Expected retail, line cost/retail, margin cents/bps
* `cost_source`, `price_source` (NOT NULL, default `unknown`)
* Override flags, `line_note`, `source_snapshot`

Allowed sources:

```text
cost_source:  vendor_source | manual | import | default | unknown
price_source: variant | vendor_source | manual | import | unknown
```

`LineEconomicsCalculator` recalculates on PO save and submit. Stimulus line row controller is preview-only.

Submit copies server-computed values into snapshots via `SubmitPurchaseOrder`.

---

# 6. Operational warnings

`Items::OperationalWarningBuilder` delegates ordering checks to `OrderEligibilityResolver`. Does not duplicate `Purchasing::SourcingWarnings` used in PO line lookup.

---

# 7. Authorization

No new permission keys in 8.5-3a. Existing `orders.purchase_orders.*`, `orders.purchase_requests.*`, and Items permissions apply.

---

# 8. Audit

Standard PO submit and import audit events. No separate discontinued-override audit in 8.5-3a.
