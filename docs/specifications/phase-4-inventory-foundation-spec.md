# Phase 4 Inventory Foundation Functional Specification

## Purpose

This specification defines the functional behavior for ShelfStack Phase 4.

Phase 4 establishes the inventory ledger, store-level balances, opening inventory, manual adjustments, valuation snapshots, and read surfaces that later purchasing, receiving, and POS workflows will post into.

For schema details, see:

```text
docs/specifications/phase-4-data-model.md
```

For test coverage, see:

```text
docs/specifications/phase-4-test-plan.md
```

Normative roadmap context:

```text
docs/roadmap/phase-4-inventory-foundation.md
```

---

# 1. Core Concepts

## 1.1 Inventory balance

An inventory balance is the current quantity and estimated value of one **product variant** at one **store**.

Authoritative grain:

```text
store_id + product_variant_id
```

Balances are cached projections from posted ledger entries. Application code must not mutate balances except through `Inventory::Post`.

---

## 1.2 Inventory posting

An inventory posting is the atomic posted inventory event.

One posting may contain one or many ledger entries (multi-line adjustments now; receiving, sales, and transfers later).

Postings are immutable once created.

---

## 1.3 Inventory ledger entry

A ledger entry records one quantity and value effect within a posting:

* store
* product variant
* signed `quantity_delta`
* movement type
* cost and retail snapshots
* optional inventory location context
* optional reason code

Ledger entries are append-only in normal operation.

---

## 1.4 Inventory adjustment

An inventory adjustment is a user-facing draft workflow that groups lines before posting.

Phase 4 adjustment types:

| `adjustment_type` | Meaning |
| --- | --- |
| `opening_inventory` | Initial on-hand setup for a store |
| `manual_adjustment` | Operational quantity correction |

Adjustment statuses:

| `status` | Meaning |
| --- | --- |
| `draft` | Editable; not yet posted |
| `posted` | Locked; linked to an inventory posting |
| `cancelled` | Discarded draft |

Posted adjustments cannot be edited. Corrections require a new adjustment or balance-correction posting.

---

## 1.5 Inventory reason code

A global setup record describing why a quantity changed.

Reason codes are optional on adjustment lines in Phase 4 but should be seeded for common bookstore cases (opening balance, shrink, damage, recount, data correction).

---

## 1.6 Inventory location

Optional store-scoped reference data describing where stock was counted or moved (sales floor, back room, receiving area).

Inventory locations are **context only** in Phase 4. They do not maintain authoritative balances and do not change store-level quantity when used.

---

# 2. Inventory Eligibility

Only product variants that are **inventory-eligible** may receive ledger entries in Phase 4.

Implementation (Phase 8): `Inventory::Eligibility` / `Inventory::TrackingResolver`. Legacy stored field:

```text
inventory_behavior = standard_physical  →  inventory tracking
```

| `inventory_behavior` | Phase 4 ledger |
| --- | --- |
| `standard_physical` | Eligible (`inventory`) |
| `digital_asset` | Not eligible |
| `drop_ship` | Not eligible |
| `composite_recipe` | Not eligible |
| `capacitated_service` | Not eligible |
| `pure_financial` | Not eligible |
| `non_inventory` | Not eligible |

Condition (new, used, signed, etc.) does not determine eligibility. A used copy that is inventory-eligible (legacy: `standard_physical`) is eligible.

`Inventory::Eligibility` enforces this rule at post time (via `Inventory::TrackingResolver`). UI should warn when users add ineligible variants to draft adjustments.

Phase 8: [phase-8-inventory-eligibility-and-tracking-spec.md](phase-8-inventory-eligibility-and-tracking-spec.md).

---

# 3. Quantity Rules

## 3.1 Quantity on hand

`quantity_on_hand` is the signed integer sum of posted `quantity_delta` values for the store + variant.

Negative on-hand is **allowed**. Negative inventory is an operational exception, not a posting blocker.

## 3.2 Quantity available

Phase 4 sets:

```text
quantity_available = quantity_on_hand
```

Reservations, holds, and committed quantity are deferred.

---

# 4. Valuation

Phase 4 captures management inventory value, not accounting-grade COGS.

## 4.1 Retail snapshot

At posting time, retail per unit comes from the variant’s `selling_price_cents`.

Ledger entries snapshot:

* `unit_retail_cents`
* `total_retail_cents` = `unit_retail_cents * abs(quantity_delta)` (signed totals stored on entry as documented in data model)

`retail_source` = `variant_selling_price`.

## 4.2 Cost snapshot

Cost per unit is resolved in this order:

1. **Manual** — `unit_cost_cents` entered on the adjustment line (`cost_source = manual`)
2. **Margin estimate** — from variant subdepartment `default_margin_target_bps` (`cost_source = margin_estimate`)
3. **Unknown** — `unit_cost_cents` null or zero with `cost_source = unknown`

Margin estimate formula:

```text
estimated_unit_cost_cents = (selling_price_cents * (10000 - default_margin_target_bps)) / 10000
```

(integer rounding: round to nearest cent)

When `default_margin_target_bps` is null, fall through to unknown.

Ledger entries snapshot unit and total cost at post time. Later price or margin changes must not rewrite historical entries.

## 4.3 Balance value fields

`inventory_balances` cache:

* `inventory_cost_value_cents` — sum of ledger total cost effects (see data model)
* `inventory_retail_value_cents` — based on current on-hand quantity and latest balance retail unit snapshot
* `unit_cost_cents`, `unit_retail_cents`, `cost_source`, `retail_source` — from the most recent posting affecting the balance

Phase 4 valuation is management inventory value, not accounting-grade COGS. `unit_cost_cents` on balances may reflect manual or margin-estimated costs per `cost_source`.

---

# 5. Posting Rules

## 5.1 Transaction boundary

`Inventory::Post` runs inside one database transaction:

```text
validate eligibility and idempotency
create inventory_posting
create inventory_ledger_entries
update inventory_balances via Inventory::BalanceUpdater
write audit events
commit
```

If any step fails, nothing posts.

## 5.2 Idempotency

Each posted adjustment produces exactly one posting.

Enforce uniqueness on:

```text
inventory_postings (source_type, source_id)
```

where `source_type` is `InventoryAdjustment` for Phase 4.

Duplicate post attempts must fail with a clear error and leave no partial data.

## 5.3 Posting types (Phase 4)

| `posting_type` | Source |
| --- | --- |
| `opening_inventory` | Posted opening adjustment |
| `manual_adjustment` | Posted manual adjustment |
| `balance_correction` | Admin correction workflow (optional Phase 4 UI; schema supports) |

## 5.4 Movement types (Phase 4)

| `movement_type` | Used when |
| --- | --- |
| `opening_balance` | Opening inventory lines |
| `manual_adjustment` | Manual adjustment lines |
| `correction` | Balance correction postings |
| `recount_adjustment` | Recount-driven corrections |

Future movement types (`received`, `sold`, `customer_return`, etc.) are reserved for later phases.

## 5.4 Immutability

Posted ledger entries and postings must not be updated or deleted in normal operation.

Reversal posting fields (`reversal_of_posting_id`, `reversed_by_posting_id`) exist for future use. Full reversal UI is optional in Phase 4.

---

# 6. Adjustment Workflows

## 6.1 Create draft

Authorized user creates a draft adjustment for a store:

* select `adjustment_type`
* add one or more lines: variant, signed quantity delta, optional manual unit cost, optional reason code, optional inventory location
* save as `draft`

## 6.2 Edit draft

Draft adjustments may be edited:

* add/remove lines
* change quantities and costs
* update notes

## 6.3 Cancel draft

Draft may move to `cancelled`. No posting is created.

Audit: `inventory_adjustment.cancelled`.

## 6.4 Post draft

Authorized user posts a draft adjustment:

* all lines validated (eligible variants, non-zero deltas, store context)
* `Inventory::PostAdjustment` builds posting payload
* adjustment status becomes `posted`
* `posted_at`, `posted_by_user_id`, `inventory_posting_id` set

Audit: `inventory_adjustment.posted`, `inventory_posting.created`.

## 6.5 Opening inventory

Opening inventory is a specialized manual workflow using `adjustment_type = opening_inventory` and movement type `opening_balance`.

Rules match manual adjustments except posting type is `opening_inventory`.

---

# 7. Authorization

Phase 4 permissions (seed-managed):

| Permission | Purpose |
| --- | --- |
| `inventory.access` | Enter Inventory workspace |
| `inventory.balances.view` | View store balances and rollups |
| `inventory.adjustments.view` | View adjustments |
| `inventory.adjustments.create` | Create/edit draft adjustments |
| `inventory.adjustments.post` | Post adjustments |
| `inventory.adjustments.cancel` | Cancel draft adjustments |
| `inventory.ledger.view` | View ledger history |
| `inventory.negative_exceptions.view` | View negative on-hand report |
| `inventory.enterprise.view` | Enterprise rollup across stores |
| `inventory.admin.rebuild_balances` | Run rebuild / integrity check |
| `setup.inventory_reason_codes.*` | Reason code setup CRUD |
| `setup.inventory_locations.*` | Store inventory location setup |

Store-scoped permissions apply in the matching store context, consistent with Phase 2 tax setup.

Posting and balance views default to `Current.store` unless the user has enterprise access and explicitly selects another permitted store.

---

# 8. Audit Events

Phase 4 audit event names:

```text
inventory_adjustment.created
inventory_adjustment.updated
inventory_adjustment.cancelled
inventory_adjustment.posted
inventory_posting.created
inventory_balance.negative
inventory_balance.cleared_negative
inventory.balance_rebuild
inventory.integrity_check
```

Audit events should include actor, store, workstation, session, and JSONB details where applicable.

---

# 9. Read Surfaces

## 9.1 Inventory workspace (`/inventory`)

Enable main nav **Inventory** (replace disabled placeholder).

| Screen | Purpose |
| --- | --- |
| Store inventory index | Paginated variant balances for selected store: SKU, title, on hand, available, cost/retail value |
| Negative exceptions | Variants with `quantity_on_hand < 0` |
| Variant stock detail | Balance + ledger history for store + variant |
| Adjustments index | Draft and posted adjustments |
| Adjustment new/edit/show | Draft workflow and posted detail with ledger link |
| Enterprise rollup | Sum balances across stores (global permission) |

## 9.2 Items integration (read-only)

On unified item detail and variant show:

* show on-hand / available for `Current.store` when variant is eligible
* link to inventory variant detail / ledger

Do not add inventory posting from Items screens in Phase 4 unless explicitly extended later.

## 9.3 Setup

| Screen | Purpose |
| --- | --- |
| Inventory reason codes | Global CRUD, inactivate |
| Store inventory locations | Store-scoped CRUD, inactivate |

---

# 10. Integrity Tooling

## 10.1 Balance integrity check

`Inventory::BalanceIntegrityCheck` compares cached `inventory_balances` to `sum(inventory_ledger_entries.quantity_delta)` per store + variant.

Exposed via rake task and restricted permission.

Audit: `inventory.integrity_check`.

## 10.2 Rebuild balances

`Inventory::RebuildBalances` recomputes all balance rows from ledger entries.

Used for recovery after bugs or manual data repair.

Audit: `inventory.balance_rebuild`.

---

# 11. Services

| Service | Responsibility |
| --- | --- |
| `Inventory::Eligibility` | Variant ledger eligibility |
| `Inventory::CostEstimator` | Per-line cost resolution |
| `Inventory::Post` | Atomic posting transaction |
| `Inventory::PostAdjustment` | Post draft adjustment |
| `Inventory::BalanceUpdater` | Upsert balances from entries |
| `Inventory::Availability` | Read on-hand / available |
| `Inventory::Valuation` | Rollup helpers |
| `Inventory::RebuildBalances` | Rebuild cached balances |
| `Inventory::BalanceIntegrityCheck` | Drift detection |

Controllers remain thin.

---

# 12. Non-Goals

Phase 4 does not include:

* Purchase orders, receiving, POS, returns, buybacks, consignment intake, vendor returns
* Inter-store transfers (UI or in-transit state)
* Customer holds / `quantity_committed`
* Location-level authoritative balances
* Average cost, FIFO, or accounting COGS
* Copy-level inventory
* Direct balance mutation outside `Inventory::Post`

---

# 13. Classification Change: Subdepartment Margin

Phase 4 restores `sub_departments.default_margin_target_bps` for cost estimation.

This field was removed during classification cleanup and is required again for margin-based cost fallback.

CSV seeds may supply optional `default_margin_target_bps` per subdepartment.

---

# 14. Exit Criteria

Phase 4 is complete when behavior matches the exit criteria in `docs/roadmap/phase-4-inventory-foundation.md` and the tests in `docs/specifications/phase-4-test-plan.md` pass.
