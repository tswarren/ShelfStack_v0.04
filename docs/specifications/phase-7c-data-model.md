# Phase 7C Data Model

Normative roadmap summary: [phase-7c-used-buyback.md](../roadmap/phase-7c-used-buyback.md)

Functional behavior: [phase-7c-used-buyback-spec.md](phase-7c-used-buyback-spec.md)

7C-1 refinement: [phase-7c-1-buyback-refinement.md](../roadmap/phase-7c-1-buyback-refinement.md)

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

`buyback_number` at proposal save (`SaveProposal`): `{store_number}-{workstation_number}-B{sequence:06d}` via `buyback_sequences` (one row per workstation). Proposal and final receipt share the same number.

# 6. Phase 7C-1 line/session fields

**Session statuses:** `draft`, `quoted`, `decision`, `completed`, `cancelled`, `voided`

**Line statuses:** `pending`, `resolved`, `priced`, `offered`, `decided`, `posted`, `voided`

**Outcomes:** `accepted_by_customer`, `declined_by_customer`, `donated_by_customer`, `rejected_by_store`, `recycle_with_permission`

**Pricing (buyback_lines):**

```text
suggested_* / proposed_* / accepted_* (resale, cash offer, trade credit offer)
base_price_cents, base_price_source
resale_price_overridden, cash_offer_overridden, trade_credit_offer_overridden
*_override_reason columns
customer_decision_at
```

**Session timestamps:** `proposal_saved_at`, `proposal_printed_at`, `customer_decision_at`, `payout_selected_at`
