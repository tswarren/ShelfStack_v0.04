# Phase 6 Completion Record

**Phase:** POS Foundation + Phase 6.1 Polish  
**Status:** Complete  
**Date:** 2026-06-10

---

## Delivered Scope

Phase 6 implements core POS behavior using `pos_*` tables:

```text
pos_register_sessions
pos_cash_movements
pos_transactions
pos_transaction_lines
pos_tenders
pos_receipts
pos_authorizations
pos_voids
pos_workstation_sequences
```

### Capabilities

- Register session open/close/force-close with business date
- Cash paid-in/paid-out movements
- Draft/suspended/completed/voided/cancelled transactions
- Sale, return, and exchange via mixed signed lines
- SKU lookup ranking: variant SKU → product SKU → catalog identifier
- Tax snapshots via `ClassificationDefaultsResolver` + `TaxRateLookup`
- Inventory posting via `Inventory::Post` (`pos_transaction`, `pos_void`)
- Completed void reversal workflow with `pos_voids` and reversing tenders
- Workstation-scoped transaction numbering at completion
- Receipt number equals transaction number in Phase 6
- POS workspace at `/pos` with snapshot reports
- Full `pos.*` permission matrix seeded

### Phase 6.1 Polish (delivered)

- Dedicated POS layout with register session banner and dashboard
- SKU scan/typeahead line entry with `Pos::LineLookupPresenter`
- Dollar-denominated money inputs; totals sidebar with fill-cash tender
- Receipt lookup and receipted partial returns with dispositions
- Open-ring line entry with subdepartment tax resolution
- Supervisor authorization modal (`Pos::AuthorizationRequest`) for discount over limit, no-receipt returns, cash refund over threshold, and force-close register
- Register close with computed expected cash (`Pos::RegisterSessionSummary`) and variance display
- Drawer/sales/returns reports with CSV export and printable receipt CSS
- Default POS role bundles: `pos_cashier`, `pos_lead`, `pos_manager`

### Phase 6.2 Register UX (delivered)

- Cashier-first register workspace on transaction edit: scan/cart left, sticky totals/tender/complete right
- Unified entry switch for sale, receipt return, no-receipt return, and open-ring drawers
- Scan-first flow: autofocus, auto-add on exact match, friendly preview formatting
- Cart display rows with edit expansion (no inline table-cell forms)
- One-step complete with embedded tenders (`Pos::CompletionReadiness` checklist)
- Derived draft type header (sale/return/exchange) from signed lines
- Enriched POS home draft/suspended queues with totals and timestamps
- Guided register close reconciliation breakdown; force close behind advanced disclosure
- Void modal with required reason codes
- POS-specific CSS: wider layout, sticky sidebar, return/void styling

### 80mm receipt print (delivered)

- Dedicated thermal receipt layout (`ss-receipt-80mm`) with item blocks and label/value rows
- Print CSS: `@page size: 80mm auto`, visibility isolation, tabular-nums on money
- Tax indicator letter on line headers; tax totals grouped as `T - Sales Tax` at bottom
- Receipt renders from completion snapshots only
- Persisted `pos_transaction_lines.transaction_discount_cents` for per-line order discount share

### Services

```text
Pos::LineLookup
Pos::DeriveTransactionType
Pos::ReturnQuantityValidator
Pos::TaxCalculator
Pos::DiscountCalculator
Pos::TenderValidator
Pos::SellabilityValidator
Pos::RecalculateTransaction
Pos::PostInventory
Pos::PostVoidInventory
Pos::TransactionNumberAssigner
Pos::RegisterSessionLifecycle
Pos::CompleteTransaction
Pos::VoidTransaction
Pos::LineLookupPresenter
Pos::ReturnLookup
Pos::RegisterSessionSummary
Pos::AuthorizationRequest
Pos::CompletionReadiness
Pos::TenderSync
Pos::ReturnLinePricing
```

---

## Documentation

```text
docs/roadmap/phase-6-pos-foundation.md
docs/specifications/phase-6-pos-foundation-spec.md
docs/specifications/phase-6-data-model.md
docs/specifications/phase-6-test-plan.md
```

Meta-docs updated: `docs/roadmap.md`, `docs/domain-model.md`, `docs/schema-reference.md`, `README.md`, `docs/README.md`, `AGENTS.md`.

---

## Verification

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails test
```

Phase 6-focused tests:

```bash
./dev/rails-docker bin/rails test test/models/pos_* test/services/pos test/integration/phase6_authorization_test.rb
```

---

## Deferred (per spec)

```text
gift-card and store-credit ledgers
offline POS
external card terminal integration
full GL / accounting export
```

`gift_card` and `store_credit` tender types are reserved but rejected by `Pos::TenderValidator` in Phase 6.

---

## Known Gaps / Follow-ups

- Turbo Stream cart updates (optional; full-page redirect + autofocus used in 6.2)
- `cash_drop` movement type not modeled; reconciliation uses paid in/out only
- Card tender is stub/manual reference only
