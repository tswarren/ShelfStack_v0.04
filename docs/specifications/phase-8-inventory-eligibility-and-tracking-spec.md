# Phase 8 Inventory Eligibility and Tracking — Functional Specification

Roadmap: [phase-8-inventory-eligibility-and-tracking-refactor.md](../roadmap/phase-8-inventory-eligibility-and-tracking-refactor.md)

Test plan: [phase-8-test-plan.md](phase-8-test-plan.md)

Completion (8-1/8-2): [phase-8-1-8-2-completion.md](../implementation/phase-8-1-8-2-completion.md)

Completion (8-3/8-4/8-5): [phase-8-3-4-5-completion.md](../implementation/phase-8-3-4-5-completion.md)

Data model: [phase-8-data-model.md](phase-8-data-model.md)

---

# 1. Purpose

Phase 8-1 and 8-2 centralize the inventory posting eligibility decision without changing runtime behavior.

The operational question:

> Does this variant participate in the stock ledger?

Legacy answer: `product_variants.inventory_behavior == "standard_physical"`.

Phase 8 answer: `Inventory::TrackingResolver` resolves to `inventory` or `non_inventory`; `Inventory::Eligibility` is the mutation gate.

# 2. Locked decisions (8-1 / 8-2)

- **Behavior-neutral** — same variants post / do not post as before
- **No schema changes** — no migrations in 8-1/8-2
- **No UI changes** — forms and labels unchanged
- **No COGS changes**
- **No receipt policy changes** — non-inventory variants still cannot be received into stock
- **Keep `inventory_behavior`** — legacy column remains; resolver maps values
- **`Inventory::TrackingResolver`** maps values; **`Inventory::Eligibility`** is the mutation gate
- **No `Inventory::SourceHint`** in 8-1/8-2

# 3. Services

## 3.1 `Inventory::TrackingResolver`

Maps legacy behavior strings and future tracking values.

| Method | Behavior |
| --- | --- |
| `resolve(value)` | Returns `"inventory"` or `"non_inventory"`; fail-closed for nil/unknown |
| `inventory?(value)` | Boolean; fail-closed |
| `resolve!(value)` | Raises `UnknownTrackingValueError` on nil/unknown |
| `tracking_for_behavior(behavior)` | `"standard_physical"` → `"inventory"`; all other legacy values → `"non_inventory"` |

Accepts: `ProductVariant`, tracking strings (`inventory`, `non_inventory`), legacy behavior strings.

## 3.2 `Inventory::Eligibility`

| Method | Behavior |
| --- | --- |
| `eligible?(variant)` | Delegates to `TrackingResolver.inventory?(variant)` |
| `ensure_eligible!(variant)` | Raises `IneligibleVariantError` with tracking + legacy behavior |
| `eligible_for_pos_line?(line)` | Snapshot first, variant fallback, then resolver |

# 4. Gate rule

| Area | Call |
| --- | --- |
| Receipt / RTV / adjustment posting | `Inventory::Eligibility` |
| Buyback inventory leg | `Inventory::Eligibility.eligible?(variant)` plus buyback-specific rules |
| POS inventory posting | `Inventory::Eligibility.eligible_for_pos_line?(line)` |
| Presenters / lookups / labels | May call `TrackingResolver` directly |

# 5. POS snapshots

- Completed lines: trust `inventory_tracking_snapshot` first, then `inventory_behavior_snapshot`, then variant
- Snapshot writers store both legacy `inventory_behavior` and resolved `inventory_tracking` at completion
- Draft lines without snapshot: fall back to current variant

# 6. Buyback

Dual gates unchanged:

- `product_condition.buyback_eligible`
- `sub_department.buyback_allowed`
- `Inventory::Eligibility.eligible?(variant)`
- `variant.active?`

# 7. Slices 8-3 through 8-5 (complete)

## 8-3 Product defaults

- `products.default_inventory_tracking` seeded at create; backfill from product type only
- `product_variants.inventory_tracking_override` — staff override only; not backfilled
- Resolution: override → behavior → product default → product_type
- Changing product default must not affect variants with populated `inventory_behavior`

## 8-4 UI and SourceHint

- Staff select Inventory / Non-Inventory; sync via `Items::InventoryTrackingSync`
- Non-inventory on physical products → `non_inventory` behavior (never `standard_physical`)
- Admin legacy behavior edit clears override
- `Inventory::SourceHint`: acquisition movements only; label "Last stock source"

## 8-5 POS COGS

- `Pos::LineCogsCalculator` at completion using pre-sale balance
- `unit_cogs_cents >= 0`; `total_cogs_cents` signed (returns negative)
- Returns reverse source COGS when available; blind/old returns estimated
- Voided transactions excluded from operational margin MVP
- Non-inventory COGS null; open-ring estimated
- Buyback MAC includes positive inbound `buyback_offer`

# 8. Cross-references

Phase 4 eligibility: [phase-4-inventory-foundation-spec.md](phase-4-inventory-foundation-spec.md) §2 — implementation path via Phase 8 resolver/eligibility.
