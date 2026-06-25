# Phase 8 Data Model — Inventory Tracking and POS COGS

This document describes schema additions for Phase 8-3 through 8-5.

## Product defaults (8-3)

### `products.default_inventory_tracking`

| Column | Type | Nullable | Check |
|--------|------|----------|-------|
| `default_inventory_tracking` | string | yes | `NULL` or `inventory` or `non_inventory` |

Seeded at product create from `product_type`. Backfilled from product type only (no majority rule). Changing this column does **not** retroactively change effective tracking for variants that already have `inventory_behavior` populated.

## Variant overrides (8-3)

### `product_variants.inventory_tracking_override`

| Column | Type | Nullable | Check |
|--------|------|----------|-------|
| `inventory_tracking_override` | string | yes | `NULL` or `inventory` or `non_inventory` |

Staff-intentional override only. **Not backfilled.** When set via UI sync, legacy `inventory_behavior` is updated to match.

## Resolution chain

```text
inventory_tracking_override
  → tracking_for(inventory_behavior)
  → product.default_inventory_tracking
  → AddItem::InventoryTrackingMapper.for_product_type(product_type)
```

## POS tracking snapshot (8-4)

### `pos_transaction_lines.inventory_tracking_snapshot`

| Column | Type | Nullable | Check |
|--------|------|----------|-------|
| `inventory_tracking_snapshot` | string | yes | none (values mirror resolver output) |

Written at POS completion. Eligibility read order:

```text
inventory_tracking_snapshot → inventory_behavior_snapshot → product_variant
```

## POS COGS snapshots (8-5)

### `pos_transaction_lines` COGS columns

| Column | Type | Nullable | Default | Check |
|--------|------|----------|---------|-------|
| `unit_cogs_cents` | integer | yes | — | `>= 0` when present |
| `total_cogs_cents` | integer | yes | — | signed |
| `cogs_source` | string | yes | — | enum (see below) |
| `costing_method_snapshot` | string | yes | — | none |
| `revenue_treatment` | string | yes | — | enum (see below) |
| `cogs_estimated` | boolean | no | `false` | — |

### `cogs_source` allowed values

```text
moving_average | unit_cost | receipt_cost | buyback_offer | margin_estimate
| return_reversal | none | unknown
```

### `revenue_treatment` allowed values

```text
merchandise | service | liability | passthrough | none
```

COGS is calculated at completion using pre-sale inventory balance (before inventory post). Non-inventory variants receive null COGS in MVP.
