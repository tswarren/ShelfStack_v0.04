# Phase 6 POS Foundation Functional Specification

## Purpose

This specification defines functional behavior for ShelfStack Phase 6.

Phase 6 establishes register sessions, POS transactions, tax and tender handling, inventory posting for sales and returns, completed void reversals, receipts, and snapshot reports. Inventory changes only through the Phase 4 ledger (`Inventory::Post`).

See also:

```text
docs/specifications/phase-6-data-model.md
docs/specifications/phase-6-test-plan.md
docs/roadmap/phase-6-pos-foundation.md
```

---

# 1. Core Principles

- POS sells at **product variant** grain; **open-ring** lines support non-catalog merchandise without a variant.
- `pos_transactions` are **source documents**; they do not mutate `inventory_balances` directly.
- Inventory posts only through `Inventory::Post` with controlled posting types.
- Completed transactions and voids are **immutable**; corrections use void reversal, not edits.
- Mutable catalog, product, variant, tax, and price data is **snapshotted on lines at completion**.
- Tax lookup uses transaction **`business_date`**, not wall-clock alone.
- Phase 1 **user sessions** and **workstations** provide security context; Phase 6 adds **register sessions** for drawer and business-date context.

---

# 2. Workspaces and Context

## 2.1 POS workspace

Route namespace: `/pos`.

Gated by `pos.access` and store-scoped authorization.

Requires:

- Active interactive user session (Phase 1)
- Resolved workstation context (Phase 1)
- Open register session for **completion** (Phase 6)

## 2.2 Context fields on transactions

At completion, persist:

```text
store_id
workstation_id
user_session_id (Phase 1)
pos_register_session_id (current open session at completion)
cashier_user_id
business_date (from register session at completion)
completed_at
transaction_number
```

Suspended transactions store the creating session reference but **rebind to the current open session** on completion.

---

# 3. Register Sessions

## 3.1 Purpose

A register session represents one open drawer / register period on a workstation.

Fields include `business_date`, opening cash, expected closing cash, status, and timestamps.

## 3.2 Rules

- At most **one open** register session per workstation.
- Every **completed** transaction must reference the currently open session.
- **Force-close** requires `pos.register_sessions.force_close`; show warning for suspended transactions; **do not block** close.
- Drawer reconciliation at close uses `pos.register_sessions.reconcile`.
- Cash paid-in and paid-out use `pos_cash_movements` (`pos.cash_movements.*`).

## 3.3 Statuses

Controlled values: `open`, `closed`, `force_closed`.

---

# 4. Transactions

## 4.1 Header statuses

Controlled values:

```text
draft
suspended
completed
voided
cancelled
```

- **Draft:** editable; no inventory or tender finalization.
- **Suspended:** saved for later; may outlive register session.
- **Completed:** immutable; numbered; receipt generated; inventory posted when eligible.
- **Voided:** completed transaction reversed via `pos_voids`.
- **Cancelled:** draft discarded; no inventory or tender impact.

## 4.2 Transaction type

Stored column `transaction_type`. Controlled values: `sale`, `return`, `exchange`.

**Derivation at completion** (`POS::DeriveTransactionType`):

- Consider only lines where `line_type` is `variant` or `open_ring` and `quantity != 0`.
- Ignore tenders, discounts, tax rows, cash rounding, and receipt metadata.
- All considered quantities positive → `sale`.
- All considered quantities negative → `return`.
- Mixed signs → `exchange`.

While draft or suspended, `transaction_type` may be provisional. **Completion recalculates and persists the authoritative value.**

## 4.3 Numbering

Assigned **at completion only**:

```text
{store_number}-{workstation_number}-{sequence}
```

- Sequence is **per workstation**, monotonic, not reset on drawer close.
- Uses existing `stores.store_number` and `workstations.workstation_number`.
- Draft and suspended UI shows internal `id` only.

## 4.4 Business date

- `business_date` on `pos_register_sessions` and `pos_transactions`.
- Tax lookup (`TaxRateLookup`) uses transaction `business_date` at completion.

---

# 5. Transaction Lines

## 5.1 Line types

Controlled values:

```text
variant
open_ring
```

- **variant:** normal sellable SKU line; `product_variant_id` required.
- **open_ring:** non-catalog or manual line; description and classification fields required; `product_variant_id` optional.

## 5.2 Quantity sign

- Sale lines: positive quantity.
- Return lines: negative quantity.
- Mixed signs on one transaction produce `transaction_type = exchange`.

## 5.3 Snapshots at completion

Variant lines snapshot at minimum:

```text
product_sku_snapshot
variant_sku_snapshot
product_name_snapshot
variant_name_snapshot
unit_price_cents
extended_price_cents
sub_department_id (and denormalized labels as needed)
tax_category_id
tax_rate_bps
tax_amount_cents
inventory_behavior_snapshot
```

Open-ring lines snapshot description, classification, tax, and price fields entered at sale time.

## 5.4 Return linkage

Return lines that reference an original sale use:

```text
source_transaction_id (optional header shortcut)
source_transaction_line_id (required for receipt-linked returns)
source_sold_quantity_snapshot (optional audit convenience)
```

`POS::ReturnQuantityValidator` ensures cumulative **completed** return quantity across all return lines pointing to the same `source_transaction_line_id` does not exceed the original completed sale line quantity.

Open-ring returns are allowed via `source_transaction_line_id` and line snapshots. Open-ring lines without `product_variant_id` do not post inventory.

## 5.5 Return dispositions

Controlled values (line-level):

```text
return_to_stock
damaged
defective
return_to_vendor_candidate
other
```

Only `return_to_stock` on eligible physical variant lines creates `customer_return` ledger entries. Other dispositions are flags and report filters only.

## 5.6 Discounts

- Line discount amount or percent applied before transaction discount.
- Transaction discount applied pro-rata across eligible lines.
- Order: price override → line discount → transaction discount → tax → cash rounding → tender.

---

# 6. Lookup

`POS::LineLookup` resolves scan or keyboard entry in the current store.

**Ranking (first exact match wins):**

1. Active variant SKU (normalized)
2. Active product SKU (normalized)
3. Active catalog identifier (ISBN-13, UPC, etc., normalized)

Barcode scanners may send ISBN/UPC; the service searches all normalized candidates and ranks exact variant SKU first when multiple matches exist.

---

# 7. Tax

At line add or price change (and finalized at completion):

1. Resolve classification via `ClassificationDefaultsResolver.for(variant:, store:, date: business_date)`.
2. Resolve rate via `TaxRateLookup.call(store:, tax_category:, date: business_date)`.
3. Snapshot tax category and rate on the line.

**Block completion** when subdepartment or tax category/rate cannot be resolved.

Tax calculation: line-level tax from discounted taxable base; round per line; sum line taxes for transaction total.

---

# 8. Sellability

Applied in a single validation path before completion:

| Condition | Behavior |
| --- | --- |
| `selling_price_cents == 0` | Allowed; prompt for price |
| Missing subdepartment or tax | **Block completion** |
| `inventory_behavior != standard_physical` (legacy) / non-inventory tracking | Sell allowed; **no inventory posting** (Phase 8: `Inventory::Eligibility.eligible_for_pos_line?`) |
| Inactive product or variant | **Warn + confirm** in UI |

---

# 9. Tenders

## 9.1 Tender types

Controlled values:

```text
cash
card
check
gift_card
store_credit
```

Phase 6 UI and `POS::TenderValidator` accept: `cash`, `card` (manual/stub), `check` (if enabled).

**Reject in Phase 6:** `gift_card`, `store_credit` (enum reserved for future ledger work).

## 9.2 Rules

- Completed transaction tender total must equal transaction total (after cash rounding).
- Refund tenders on returns and voids use negative amounts or explicit refund rows per data model.
- Cash refund above store threshold requires authorization (`pos.returns.cash_refund.over_threshold` or linked `pos_authorizations`).

## 9.3 Void tender reversal

On completed void, create **reversing `pos_tenders`** linked to original tender rows (`reverses_tender_id`). Do not mutate original tender rows.

---

# 10. Inventory Posting

## 10.1 Completion posting

`POS::PostInventory` builds a payload **only** from eligible lines:

```text
product_variant_id present
inventory_behavior = standard_physical (from snapshot or variant at completion)
line contributes sold (positive qty) or customer_return (negative qty with return_to_stock)
```

Non-inventory and open-ring lines without variant are **not passed** to `Inventory::Post`.

Service call:

```text
Inventory::Post.call(
  posting_type: "pos_transaction",
  source: pos_transaction,
  lines: [...],  # movement_type sold | customer_return
  idempotency_key: stable per transaction
)
```

One posting per completed transaction when at least one eligible line exists. Transactions with no eligible lines complete without an inventory posting.

## 10.2 No header FK

Do not add `inventory_posting_id` to `pos_transactions`. Discover via `inventory_postings.source`.

## 10.3 Posting types

Phase 6 POS uses:

```text
pos_transaction  — completion of sale, return, or exchange
pos_void         — reversal of a completed transaction
```

Do not use `pos_sale` or `customer_return` posting types for new POS postings.

---

# 11. Completed Voids

In scope for Phase 6.

Workflow (`POS::VoidTransaction`):

1. Authorize (`pos.transactions.void`; supervisor authorization when configured).
2. Create `pos_voids` row linked to original `pos_transaction`.
3. Mark original transaction `voided`; do **not** edit lines, tenders, or snapshots.
4. Post inventory reversal via `Inventory::Post` with `posting_type: pos_void`, `source: PosVoid`, negating eligible original ledger quantities; set `reversal_of_posting_id` on void posting.
5. Create reversing `pos_tenders` linked to originals.
6. Audit `pos.void.completed`.

If original transaction had no inventory posting, void creates no inventory posting.

---

# 12. Receipts

`pos_receipts` created at completion.

Phase 6 invariant:

```text
receipt_number == transaction_number
```

Keep separate columns to allow future divergence (reprint-only sequences, etc.).

Reprint requires `pos.receipts.print`. Receipt content renders from snapshotted line and tender data.

---

# 13. Suspend and Resume

- Suspend: `pos.transactions.suspend`; status → `suspended`.
- Resume own: `pos.transactions.resume`.
- Resume another cashier: `pos.transactions.resume.other_cashier`.
- On complete from suspended: attach **current open** `pos_register_session_id` and `business_date`.

---

# 14. Authorizations

`pos_authorizations` record supervisor approvals for:

```text
discount over limit
no-receipt return
cash refund over threshold
force-close register session
inactive sell (optional policy)
other configured overrides
```

Granting requires `pos.authorizations.grant` (or `pos.authorizations.self_grant` when policy allows).

---

# 15. Reports

Under `/pos/reports`, gated by `pos.reports.*`.

Reports read from **completed transaction snapshots** (not live catalog data).

Phase 6 minimum:

```text
session / drawer summary (at close)
sales snapshot
returns snapshot
```

Real-time totals during an open session may read draft/completed data for the current register session.

---

# 16. Permissions

POS workspace gated by `pos.access`.

Full matrix (seed in `db/seeds/phase6_permissions.rb`):

```text
pos.access

pos.transactions.view
pos.transactions.create
pos.transactions.update
pos.transactions.complete
pos.transactions.suspend
pos.transactions.resume
pos.transactions.resume.other_cashier
pos.transactions.void
pos.transactions.cancel

pos.lines.add
pos.lines.add.open_ring
pos.lines.update
pos.lines.remove
pos.lines.sell_inactive

pos.discounts.line.apply
pos.discounts.transaction.apply
pos.discounts.override_limit

pos.returns.receipted
pos.returns.no_receipt
pos.returns.partial
pos.returns.disposition.override
pos.returns.open_ring
pos.returns.cash_refund.over_threshold

pos.tenders.cash
pos.tenders.card
pos.tenders.check
pos.tenders.gift_card
pos.tenders.store_credit
pos.tenders.refund

pos.register_sessions.view
pos.register_sessions.open
pos.register_sessions.close
pos.register_sessions.force_close
pos.register_sessions.reconcile

pos.cash_movements.view
pos.cash_movements.create
pos.cash_movements.large_amount

pos.authorizations.grant
pos.authorizations.self_grant

pos.receipts.view
pos.receipts.print
pos.receipts.email

pos.reports.view
pos.reports.drawer
pos.reports.sales
pos.reports.returns
pos.reports.export
```

Store-scoped role assignments apply per Phase 1 rules.

---

# 17. Audit Events

Examples:

```text
pos.register_session.opened
pos.register_session.closed
pos.register_session.force_closed
pos.cash_movement.recorded
pos.transaction.created
pos.transaction.suspended
pos.transaction.resumed
pos.transaction.completed
pos.transaction.cancelled
pos.transaction.voided
pos.void.completed
pos.authorization.granted
pos.receipt.printed
```

Include actor, store, workstation, user session, register session, auditable record, and JSONB event details per Phase 1 guidelines.

---

# 18. Service Summary

| Service | Role |
| --- | --- |
| `POS::LineLookup` | Ranked SKU and identifier resolution |
| `POS::DeriveTransactionType` | Merchandise-line sign derivation at completion |
| `POS::ReturnQuantityValidator` | Cumulative return qty vs source line |
| `POS::PostInventory` | Eligible-line payload; `Inventory::Post` |
| `POS::TenderValidator` | Tender type and total validation |
| `POS::CompleteTransaction` | Completion orchestration |
| `POS::VoidTransaction` | Void and reversal orchestration |
| `POS::TaxCalculator` | Tax snapshots and totals |
| `POS::DiscountCalculator` | Line and transaction discounts |
| `POS::TransactionNumberAssigner` | Workstation-scoped sequence |
| `POS::RegisterSessionLifecycle` | Open, close, force-close |

Controllers remain thin; business rules live in services.

---

# 19. Deferred

```text
gift-card and store-credit ledgers
gift-card issuance, reload, redemption, cash-out
offline POS
external card terminal integration
full GL / accounting export
```

---

# Appendix A — Locked Decisions

This appendix is the authoritative decision log for Phase 6 planning disputes.

## A.1 Inventory

- One `pos_transaction` completion → at most one `pos_transaction` inventory posting.
- Ledger `movement_type`: `sold` or `customer_return` per line.
- Open-ring without `product_variant_id`: no inventory posting.
- No `inventory_posting_id` on `pos_transactions`.
- Void: `pos_voids` source, `posting_type = pos_void`, reversal FKs to original posting.

## A.2 Exchanges and returns

- Mixed signed lines on one transaction.
- Partial exchange and partial return supported.
- Open-ring return via `source_transaction_line_id`.
- `POS::ReturnQuantityValidator` on receipt-linked returns.

## A.3 Numbering and receipts

- Transaction number at completion; per-workstation sequence.
- `receipt_number == transaction_number` in Phase 6.

## A.4 Sessions

- Suspended txns may outlive session; complete on current open session.
- Force-close with auth; warn suspended; do not block.

## A.5 Sellability

- $0 with prompt; missing tax/subdepartment blocks; non-inventory sells without post; inactive warn+confirm.

## A.6 Tenders

- Store credit on normal return/exchange when ledger exists; not a separate transaction type.
- `POS::TenderValidator` rejects gift_card and store_credit in Phase 6.

## A.7 Lookup

- Rank: variant SKU → product SKU → catalog identifier.

## A.8 Transaction type

- Derived from variant/open_ring lines with non-zero quantity only.
- Draft provisional; completion authoritative.

## A.9 Posting type names

- `pos_sale` and `customer_return` on enum: reserved historically; **not used** for new POS postings.
