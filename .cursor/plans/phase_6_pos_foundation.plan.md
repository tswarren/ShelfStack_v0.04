# Phase 6 POS Foundation

## Overview

Document and implement Phase 6 POS Foundation using `pos_*` tables, inventory posting via `Inventory::Post` (`pos_transaction` / `pos_void`), register sessions, full reversal voids, and a complete `pos.*` permission matrix.

**Status:** Documentation in progress. Implementation follows doc approval.

---

## Scope

**In scope:**

```text
register sessions
draft / suspended / completed transactions
tax and tender snapshots
inventory posting (sale, return, exchange)
completed void reversals
receipts
snapshot reports
```

**Deferred:**

```text
gift-card and store-credit ledgers
offline POS
external card integration (Phase 6 uses stub/manual card tender)
full GL / accounting export
```

---

## Locked decisions

### Transactions and numbering

| Rule | Decision |
|------|----------|
| `transaction_type` | Stored on header; **derived at completion** from signed merchandise lines only |
| Derivation | `line_type` in `variant`, `open_ring`; `quantity != 0`; ignore tenders, discounts, rounding, receipt rows |
| Values | All positive → `sale`; all negative → `return`; mixed → `exchange` |
| Draft type | Provisional while editing; **completion recalculates and persists authoritative value** |
| Mixed lines | Sale, return, exchange on **one** `pos_transaction` |
| Partial exchange/return | **Yes**; cumulative completed return qty ≤ original sold qty |
| Open-ring return | **Yes** via `source_transaction_line_id` + snapshots |
| Public number | `{store_number}-{workstation_number}-{seq}`; sequence **per workstation**; assigned **at completion only** |
| Draft/suspended UI | Internal `id` only until complete |
| `receipt_number` | **Same as `transaction_number` in Phase 6**; separate column for future divergence |
| `business_date` | On `pos_register_sessions` and `pos_transactions`; tax uses transaction `business_date` at completion |

### Register sessions and suspended transactions

| Rule | Decision |
|------|----------|
| Completion | Requires **currently open** register session on workstation |
| Suspended lifespan | May **outlive** creating session |
| Resume/complete | Binds to **current open session** and its `business_date` |
| Force-close | Allowed with authorization; **warn** suspended txns; **do not block** |
| Cross-cashier resume | Requires `pos.transactions.resume.other_cashier` |

### Inventory

| Rule | Decision |
|------|----------|
| Completion posting | One posting per completed txn: `posting_type = pos_transaction`, `source = PosTransaction` |
| Ledger lines | `movement_type` = `sold` or `customer_return` per eligible line |
| Eligible lines | `product_variant_id` present; `inventory_behavior = standard_physical`; inventory effect sold or customer_return |
| Open-ring | **No inventory posting** unless `product_variant_id` present |
| Header FK | **No** `inventory_posting_id` on `pos_transactions`; discover via polymorphic source |
| Posting types | Phase 6 uses `pos_transaction` and `pos_void`. `pos_sale` / `customer_return` were reserved on the enum; **do not use for new POS postings** |

### Completed voids (in scope)

| Rule | Decision |
|------|----------|
| Approach | **Authorized reversal workflow**; never mutate completed txn or original posting |
| Entity | **`pos_voids`** records void event |
| Inventory | `source_type = PosVoid`, `posting_type = pos_void`; link via `reversal_of_posting_id` / `reversed_by_posting_id` |
| Original txn | Mark `voided`; immutable thereafter |
| Tenders | **Reversing `pos_tenders`** linked to original tender rows |

### Sellability

| Rule | Decision |
|------|----------|
| `selling_price_cents == 0` | Allowed with price prompt |
| Missing subdepartment/tax | **Block completion** |
| Non-inventory variant | Sell allowed; no inventory posting |
| Inactive product/variant | **Warn + confirm** |

### Returns and tenders

| Rule | Decision |
|------|----------|
| Receipted returns | Original line snapshots |
| No-receipt returns | Permission + authorization |
| Return qty | `POS::ReturnQuantityValidator`: cumulative completed returns ≤ original `source_transaction_line_id` qty |
| Dispositions | Line-level; only `return_to_stock` posts inventory; `return_to_vendor_candidate` flag only |
| Store credit | Future tender on normal return/exchange txn; **not** separate transaction type |
| `gift_card` / `store_credit` tender | Enum reserved; **`POS::TenderValidator` rejects in Phase 6** |

### Lookup

| Rule | Decision |
|------|----------|
| Ranking | **Variant SKU → product SKU → catalog identifier** (exact match first; normalized ISBN/UPC candidates for scanners) |

---

## Implementation services

| Service | Responsibility |
|---------|----------------|
| `POS::LineLookup` | Ranked SKU/identifier search |
| `POS::DeriveTransactionType` | Merchandise lines only; authoritative at completion |
| `POS::ReturnQuantityValidator` | Cumulative returns vs source line |
| `POS::PostInventory` | Build payload from eligible lines only; call `Inventory::Post` |
| `POS::TenderValidator` | Reject `gift_card`, `store_credit` in Phase 6 |
| `POS::CompleteTransaction` | Numbers, business_date, session bind, type, receipt |
| `POS::VoidTransaction` | `PosVoid`, void posting, reversing tenders, audit |
| `POS::TaxCalculator` | ClassificationDefaultsResolver → TaxRateLookup → line snapshots |
| `POS::DiscountCalculator` | Line → transaction pro-rata → tax → cash rounding |

---

## Documentation deliverables

1. [docs/roadmap/phase-6-pos-foundation.md](../docs/roadmap/phase-6-pos-foundation.md)
2. [docs/specifications/phase-6-pos-foundation-spec.md](../docs/specifications/phase-6-pos-foundation-spec.md)
3. [docs/specifications/phase-6-data-model.md](../docs/specifications/phase-6-data-model.md)
4. [docs/specifications/phase-6-test-plan.md](../docs/specifications/phase-6-test-plan.md)

Meta updates: `docs/roadmap.md`, `docs/domain-model.md`, `docs/schema-reference.md`, `README.md`, `docs/README.md`, `AGENTS.md`.

---

## Implementation sequence (after docs)

1. Migration + models + `phase6_permissions.rb` + extend `POSTING_TYPES`
2. Register sessions + cash movements + force-close
3. POS routes + `POS::LineLookup` + draft/suspend/resume
4. Tax/discount/tender calculators + authorizations + sellability
5. `POS::CompleteTransaction` + `POS::PostInventory` + receipts
6. Returns/exchanges + `POS::VoidTransaction`
7. `/pos/reports` + tests + `phase-6-completion.md`

---

## Definition of done

- Spec set and meta-docs committed
- Migrations run cleanly; controlled values validated
- Complete/suspend/return/exchange/void enforce locked rules
- Inventory only via `Inventory::Post`; void via `PosVoid`
- Full `pos.*` permissions seeded and enforced
- Tests pass per phase-6-test-plan
