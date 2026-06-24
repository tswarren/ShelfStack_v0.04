**Phase 6: POS Foundation**

**Purpose**

Phase 6 establishes core point-of-sale behavior for ShelfStack.

It answers:

> What was sold or returned, at what price, with what tax, through which workstation, by which user, on which business date, and how was payment taken?

**Core Design Principles**

POS operates at the **product variant** level (with optional **open-ring** lines for non-catalog merchandise).

Inventory changes only through the Phase 4 ledger:

```text
Completed POS Transaction
  -> Inventory::Post (posting_type: pos_transaction)
  -> inventory_postings (source: PosTransaction)
  -> inventory_ledger_entries (movement_type: sold | customer_return)

Completed Void
  -> PosVoid
  -> Inventory::Post (posting_type: pos_void)
  -> inventory_postings (source: PosVoid; reversal_of_posting_id)
```

POS transactions are **source documents**. They do not mutate `inventory_balances` directly.

**Major Capabilities**

Phase 6 includes:

```text
pos_register_sessions (drawer / register context)
pos_cash_movements (paid-in / paid-out)
pos_transactions (draft, suspended, completed, voided)
pos_transaction_lines (variant, open-ring, return, exchange)
pos_tenders (cash, card stub, check; refund tenders)
pos_receipts (customer-facing document)
pos_authorizations (supervisor overrides)
pos_voids (completed transaction reversal)
SKU / identifier lookup (variant SKU, product SKU, catalog identifier)
tax snapshotting via ClassificationDefaultsResolver + TaxRateLookup
price and name snapshotting
workstation-scoped transaction numbering
register-session business_date
returns and partial exchanges
completed void reversal workflow
pos.* permissions
snapshot reports under /pos/reports
POS audit events
```

**Transaction Types**

`transaction_type` is stored on the header and derived at completion from signed merchandise lines (`variant`, `open_ring` only):

```text
sale      — all merchandise line quantities positive
return    — all merchandise line quantities negative
exchange  — mixed positive and negative merchandise lines
```

Draft values may be provisional; completion recalculates the authoritative value.

**Inventory Posting**

One inventory posting per **completed** transaction (when any eligible lines exist):

```text
inventory_postings.posting_type = pos_transaction
inventory_postings.source = PosTransaction
inventory_ledger_entries.movement_type = sold | customer_return (per line)
```

Only lines with `product_variant_id` that are inventory-eligible post (Phase 8: `Inventory::Eligibility.eligible_for_pos_line?`; legacy snapshot `inventory_behavior = standard_physical`). Open-ring lines without a variant do not post.

Do **not** store `inventory_posting_id` on `pos_transactions`. Discover postings via polymorphic `source`.

Enum values `pos_sale` and `customer_return` were reserved on `inventory_postings` before Phase 6; **do not use them for new POS postings**.

**Void Reversals**

Completed voids are in scope. Void is a **reversal workflow**, not mutation:

```text
pos_voids records the void event
original pos_transaction marked voided (immutable)
inventory reversal: posting_type = pos_void, source = PosVoid
reversing pos_tenders linked to original tender rows
```

**Numbering and Receipts**

At completion only:

```text
transaction_number = {store_number}-{workstation_number}-{sequence}
sequence is per workstation, monotonic
receipt_number equals transaction_number in Phase 6 (separate columns)
```

Draft and suspended transactions use internal id in UI until complete.

**Register Sessions**

Every completion requires an open `pos_register_session` on the workstation.

Suspended transactions may outlive the session that created them. On resume or complete, bind to the **current open session** and its `business_date`.

Force-close is allowed with authorization; warn about suspended transactions but do not block close.

**Sellability**

```text
selling_price_cents == 0: allowed with price prompt
missing subdepartment or tax: block completion
non-inventory variant: sell allowed, no inventory posting
inactive product or variant: warn + confirm
```

**Returns**

Receipt-linked returns use original line snapshots and `source_transaction_line_id`.

Cumulative completed return quantity must not exceed the original sold quantity.

No-receipt returns require permission and authorization.

Return dispositions are line-level. Only `return_to_stock` affects inventory posting. `return_to_vendor_candidate` is a flag for future RTV workflows.

**Deferred**

Phase 6 should not include:

```text
gift-card and store-credit ledgers
gift-card issuance, reload, redemption, cash-out
offline POS
external payment terminal integration
full GL posting
store credit balance accounts
```

`gift_card` and `store_credit` tender types are reserved in the schema but rejected by `POS::TenderValidator` in Phase 6.

**Exit Criteria**

Phase 6 is complete when:

1. Staff can open and close register sessions and record cash movements.
2. Staff can build, suspend, resume, and complete sale, return, and exchange transactions.
3. Lookup resolves variant SKU, product SKU, and catalog identifiers with correct ranking.
4. Tax and price snapshots are stored on lines at completion.
5. Eligible lines post inventory via `pos_transaction`; voids reverse via `pos_void`.
6. Receipt numbers match transaction numbers in Phase 6.
7. Partial returns and partial exchanges enforce quantity limits.
8. Completed voids reverse inventory and tenders without mutating original records.
9. Force-close and supervisor authorizations work with correct permissions.
10. Basic POS snapshot reports are available under `/pos/reports`.
11. POS actions are permission-controlled and audited.
12. Tests pass per phase-6-test-plan.

**Related Documents**

```text
docs/specifications/phase-6-pos-foundation-spec.md
docs/specifications/phase-6-data-model.md
docs/specifications/phase-6-test-plan.md
```
