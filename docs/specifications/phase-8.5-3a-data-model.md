# Phase 8.5-3a Data Model

## products

| Column | Type | Notes |
| ------ | ---- | ----- |
| `preferred_vendor_id` | FK → vendors, nullable | Store-facing default vendor |

## product_variants

| Column | Type | Notes |
| ------ | ---- | ----- |
| `preferred_vendor_id` | FK → vendors, nullable | Overrides product preferred |
| `orderable` | boolean NOT NULL | Default from `OrderabilityDefaults` at create/backfill |

## purchase_order_lines (additive)

| Column | Type | Notes |
| ------ | ---- | ----- |
| `expected_retail_price_cents` | integer, nullable | Unit retail at order time |
| `expected_line_cost_cents` | integer, nullable | `unit_cost * qty` |
| `expected_line_retail_cents` | integer, nullable | `retail * qty` |
| `expected_margin_cents` | integer, nullable | Line retail − line cost |
| `expected_margin_bps` | integer, nullable | Margin as basis points of line retail |
| `cost_source` | string NOT NULL | Check constraint |
| `price_source` | string NOT NULL | Check constraint |
| `manual_cost_override` | boolean NOT NULL default false | |
| `manual_price_override` | boolean NOT NULL default false | |
| `line_note` | text, nullable | Staff note |
| `source_snapshot` | jsonb default {} | Submit-time sourcing snapshot |

Existing columns unchanged: `unit_list_price_cents`, `unit_cost_cents`, `supplier_discount_bps`.

## Unchanged Phase 7A chain

```text
special_orders → purchase_order_line_allocations → receipt_line_allocations
```

No new demand or receipt allocation tables.
