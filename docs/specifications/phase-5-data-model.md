# Phase 5 Data Model

## Purpose

Source of truth for Phase 5 migrations.

Functional behavior: [phase-5-purchasing-and-receiving-spec.md](phase-5-purchasing-and-receiving-spec.md)

---

# 1. Schema Changes on Existing Tables

## 1.1 `product_variants.returnability_status`

| Field | Type | Notes |
| --- | --- | --- |
| `returnability_status` | string | `returnable`, `non_returnable`, `conditional`, `unknown`; default `unknown` |

## 1.2 `inventory_balances.moving_average_unit_cost_cents`

| Field | Type | Notes |
| --- | --- | --- |
| `moving_average_unit_cost_cents` | integer | nullable; set on first receipt |

## 1.3 `vendors` cleanup

Remove: `default_pricing_model`, `default_margin_target_bps`.

Keep: `default_supplier_discount_bps`.

## 1.4 Ledger cost sources

Extend `inventory_ledger_entries.cost_source` allowed values with `receipt_cost`, `moving_average`.

---

# 2. New Tables

## `product_vendors`

| Field | Constraints |
| --- | --- |
| `product_id`, `vendor_id` | null false; unique composite |
| `vendor_item_number` | optional |
| `supplier_discount_bps` | 0–10000 optional |
| `returnability_status` | nullable controlled |
| `preferred` | boolean default false |
| `active` | boolean default true |

## `product_variant_vendors`

| Field | Constraints |
| --- | --- |
| `product_variant_id`, `vendor_id` | null false; unique composite |
| `vendor_item_number`, `supplier_discount_bps`, `returnability_status` | optional overrides |
| `preferred` | boolean default false |
| `active` | boolean default true |

## `vendor_terms`

| Field | Constraints |
| --- | --- |
| `vendor_id` | null false |
| `name` | null false |
| `net_days` | integer optional |
| `terms_data` | jsonb default {} |
| `active` | boolean default true |

## `purchase_requests` / `purchase_request_lines`

Header: `store_id`, `status`, `notes`.

Line: `product_variant_id`, `requested_quantity`, `request_reason`, `status`, `line_number`.

## `purchase_orders` / `purchase_order_lines`

Header: `store_id`, `vendor_id`, `status`, `notes`, `submitted_at`, `submitted_by_user_id`.

Line: variant + vendor refs, snapshots, quantity fields, `status`.

## `receipts` / `receipt_lines`

Header: `store_id`, `vendor_id`, `purchase_order_id` optional, `receipt_type`, `status`, `posted_at`.

Line: quantity fields, cost snapshots, `purchase_order_line_id` optional.

## `receiving_discrepancies`

Links receipt line; `discrepancy_type`, `quantity_delta`, `notes`.

## `returns_to_vendor` / `return_to_vendor_lines`

Header: `store_id`, `vendor_id`, `status`, `notes`, `posted_at`.

Line: `product_variant_id`, `quantity`, cost snapshots, `credit_amount_cents` optional.

---

# 3. Money and Basis Points

All currency fields integer cents. Discounts and margins as basis points (0–10000).
