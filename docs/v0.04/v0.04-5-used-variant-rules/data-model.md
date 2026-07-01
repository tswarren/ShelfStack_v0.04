# v0.04-5 Used Variant Rules — Data Model Notes

## Status

**Draft** — companion to [spec.md](spec.md).

---

## Schema policy

**Default: no migrations.** v0.04-5 derives behavior from existing tables and columns.

Add migrations only if a slice proves necessary:

* Backfill `product_variants.orderable` to `false` for used-like variants incorrectly set `true`.
* Optional condition-level flag when `new_condition` is insufficient (e.g. explicit remainder replenishment class) — prefer policy derivation first.

Do **not** add in v0.04-5:

```text
product_variants.vendor_orderable
product_variants.customer_reservable
product_variants.replenishment_strategy
demand_lines / demand_allocations
used_items / copy_serial tables
```

Design doc vocabulary maps to **policy methods**, not new columns, unless a follow-up slice documents otherwise.

---

## Canonical grain (unchanged)

```text
Product
  ├── product_identifiers (ISBN/UPC/house — product grain)
  └── product_variants (operational grain)
        ├── condition_id → product_conditions
        ├── orderable (boolean)
        ├── sku (211-segment system-assigned for new variants per v0.04-2)
        └── selling_price_cents, inventory fields, classification FKs
```

Used/new distinction lives at **variant + condition**, not product.

---

## Tables and columns in scope

### `product_conditions`

| Column | Role in v0.04-5 |
| ------ | ----------------- |
| `condition_key` | Stable seed key (`new`, `used_good`, `remainder`, …) |
| `new_condition` | **Primary** new vs used-like gate |
| `buyback_eligible` | Buyback intake allowed for this condition |
| `buyback_default` | Default condition in buyback UI (`used_good` in seeds) |
| `active` | Inactive conditions not selectable for new variants |
| `default_list_price_factor_bps` | Pricing factor (unchanged) |
| `sku_component` | Legacy suffix component; **not** used for new variant SKU generation post–v0.04-2 |

### Seed matrix (authoritative baseline)

Loaded via `db/seeds/phase3_catalog_products.rb` and `db/seeds/phase7c_buyback.rb`:

| condition_key | new_condition | buyback_eligible | buyback_default | Used-like (policy) |
| ------------- | ------------- | ---------------- | --------------- | ------------------ |
| `new` | true | false | false | no |
| `signed_copy` | true | false | false | no |
| `special_edition` | true | false | false | no |
| `remainder` | true | false | false | no (remainder ≠ used) |
| `used_like_new` | false | true | false | yes |
| `used_very_fine` | false | true | false | yes |
| `used_fine` | false | true | false | yes |
| `used_good` | false | true | **true** | yes |
| `used_poor` | false | true | false | yes |
| `used_ex_library` | false | true | false | yes |
| `used_book_club` | false | true | false | yes |

Audit task should fail if this matrix drifts (e.g. used condition with `new_condition: true`).

### `product_variants`

| Column | Role in v0.04-5 |
| ------ | ----------------- |
| `condition_id` | Required for condition-driven policy (nullable in schema but operational variants should have condition) |
| `orderable` | Staff-visible flag; **default false** for used-like on create via `ProductVariants::OrderabilityDefaults` |
| `sku` | System-assigned 211 EAN-13 for newly created variants (`ProductVariants::SkuAllocator`); buyback path must align |
| `source` | e.g. `buyback_intake`, `manual` |
| `created_from_buyback_session_id` | Provenance for buyback-created variants |
| `active` | Inactive variants blocked from sale/order |
| `product_id` | Product owns identifiers; used variant does not duplicate ISBN |

**Policy derivation (target):**

```text
used_like?     = condition present && !condition.new_condition?
new_condition? = condition.present && condition.new_condition?
vendor_orderable? =
  variant.active &&
  product.active &&
  product.product_type not in (service, financial) &&
  variant.orderable? &&
  new_condition? &&
  not non_inventory_blocked?
buyback_eligible? =
  condition.buyback_eligible? &&
  sub_department.buyback_allowed? (buyback paths only)
customer_reservable? =
  variant.active && product.active && sellable setup
  (hold/notify paths; special_order excluded for used_like)
```

Exact precedence lives in `ProductVariants::OperationalPolicy` — this table is documentation, not duplicate logic.

### `products`

| Column | Role |
| ------ | ---- |
| `active` | Inactive product blocks variant operations |
| `product_type` | `service` / `financial` block vendor ordering (existing) |
| `publication_status` | Discontinued warnings (unchanged from v0.04-4) |

No used-specific columns on `products`.

---

## Services and policy (new / refactored)

| Component | v0.04-5 role |
| --------- | ------------ |
| `ProductVariants::OperationalPolicy` | **New** — single source for new/used/vendor_orderable/buyback/reservable |
| `ProductVariants::OrderabilityDefaults` | Create-time default `orderable`; delegate used detection to policy |
| `Purchasing::OrderEligibilityResolver` | Delegate used checks to policy; **extend `:tbo` to block used** |
| `PurchaseRequests::CreateSingleLine` | Block when policy says not vendor-orderable |
| `Purchasing::TboQueueRowBuilder` | Exclude or mark blocked rows for used variants |
| `Buybacks::FindOrCreateGradedUsedVariant` | SkuAllocator + orderability defaults + policy compliance |
| `Items::OperationalWarningBuilder` | Used-specific info; suppress vendor sourcing for used-like |
| `CustomerRequests::StartFromItem` | Block `special_order` for used-like variants |

---

## Relationship to v0.04 milestones

| Milestone | Relationship |
| --------- | ------------ |
| v0.04-2 Product identifiers | Product owns identifiers; variant SKU is 211 segment; buyback create must use allocator |
| v0.04-4 Wire-through | Product-first buyback/intake; v0.04-5 enforces used variant defaults on those paths |
| v0.04-6 Demand foundation | `used_wanted` purpose, no vendor PO; v0.04-5 bridge guardrails only |
| v0.04-11 Cleanup | May remove legacy `SkuGenerator` suffix paths entirely |

---

## FK and snapshot preservation

Do not rewrite historical snapshots:

```text
pos_transaction_lines.variant_sku_snapshot
purchase_order_lines.variant_sku_snapshot
buyback_lines.variant_sku_snapshot / condition_snapshot
receipt_lines (variant references)
```

v0.04-5 changes **forward behavior** and eligibility, not historical row content.

---

## Verification data checks

`shelfstack:v0045:verify_used_variant_rules` (planned) should query:

```sql
-- illustrative; implement in Ruby against models

-- Used conditions incorrectly marked new
ProductCondition.where(buyback_eligible: true, new_condition: true)

-- Active used-like variants marked orderable (report/warn)
ProductVariant.active_records
  .joins(:condition)
  .where(product_conditions: { new_condition: false }, orderable: true)

-- Buyback-created variants on new condition (should be zero)
ProductVariant.where(source: "buyback_intake")
  .joins(:condition)
  .where(product_conditions: { new_condition: true })
```

Strict mode may fail the build on non-zero counts where policy says they must be zero post-backfill.

---

## Optional migration (if needed)

If backfill is scoped:

```text
Migration: backfill_used_variant_orderable_false
  UPDATE product_variants
  SET orderable = false
  FROM product_conditions
  WHERE product_variants.condition_id = product_conditions.id
    AND product_conditions.new_condition = false
    AND product_variants.orderable = true
```

Run only after reviewing stores that intentionally marked used variants orderable for non-vendor reasons; PO/TBO blocking remains policy-level regardless.
