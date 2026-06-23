# Phase 7C Data Model

Normative roadmap summary: [phase-7c-used-buyback.md](../roadmap/phase-7c-used-buyback.md)

Functional behavior: [phase-7c-used-buyback-spec.md](phase-7c-used-buyback-spec.md)

Test plan: [phase-7c-test-plan.md](phase-7c-test-plan.md)

---

# 1. Existing table changes

See roadmap §5. Key points:

- `customers`: structured address (`address_line1`, `address_line2`), `merged_into_customer_id` (schema only; no merge workflow in 7C)
- `product_conditions`: `buyback_eligible`, `buyback_default`, `buyback_sort_order`, `buyback_price_factor_bps`, `buyback_requires_review`
- `catalog_items`, `products`, `product_variants`: `source`, `needs_review`, `created_from_buyback_session_id`
- `pos_cash_movements`: `source_type`, `source_id`, `reverses_cash_movement_id`
- `inventory_postings.posting_type`: add `buyback_void` (`used_buyback` already reserved)
- `inventory_ledger_entries.cost_source`: add `buyback_offer`, `no_value_donation`

# 2. New tables

`buyback_sequences`, `buyback_sessions`, `buyback_lines`, `buyback_voids`, `buyback_pricing_rules`, `buyback_reject_reasons`

# 3. Indexes

```text
buyback_voids.buyback_session_id          UNIQUE
buyback_sessions.buyback_number           UNIQUE (partial: where not null)
buyback_sequences.workstation_id          UNIQUE
pos_cash_movements(source_type, source_id)
```

# 4. Posting sources

| Event | posting_type | source |
|-------|--------------|--------|
| Completion | `used_buyback` | `BuybackSession` |
| Void | `buyback_void` | `BuybackVoid` |

Movement type remains `used_buyback` for original and reversal lines.

# 5. Numbering

`buyback_number` at completion: `{store_number}-{workstation_number}-B{sequence:06d}` via `buyback_sequences` (one row per workstation).
