# Phase 7B: Customer Credit Foundation

**Status:** Complete (2026-06-21). See [phase-7b-2-completion.md](../implementation/phase-7b-2-completion.md) and [phase-7b-3-completion.md](../implementation/phase-7b-3-completion.md).

## Purpose

Phase 7B introduces ShelfStack’s customer credit foundation in three dependent slices:

```text
7B-1 POS Settlement Foundation
7B-2 Stored Value Account + Ledger Foundation
7B-3 POS Stored Value Integration
```

It answers:

> How does POS accurately record split payments and refunds, how are store credit and gift-card-style balances tracked as liabilities, and how does POS issue and redeem stored value safely?

Phase 6 reserved `gift_card` and `store_credit` tender types while rejecting them in `Pos::TenderValidator`. Phase 7A deferred store-credit ledgers, deposits, and prepayments. Phase 7B is the correct place to activate this work.

## Dependency chain

```text
POS can accurately record split settlement rows (7B-1)
  -> stored value accounts and ledgers exist (7B-2)
  -> POS can issue/redeem stored value safely (7B-3)
```

7B-1 is not merely “add multiple tenders.” It is the POS settlement foundation stored value depends on. 7B-2 is the ledger/account foundation. 7B-3 is the POS integration between the two.

## Canonical model decision

Phase 7B replaces earlier future-table language for separate `gift_card_accounts` and `store_credit_accounts` with the canonical stored-value model:

```text
stored_value_accounts
stored_value_identifiers
stored_value_ledger_entries
stored_value_transfers
stored_value_reason_codes
```

POS settlement continues to use `pos_tenders` with `tender_type` values `store_credit` and `gift_card` for user-facing settlement rails. Stored value account types distinguish business use (`merchandise_credit`, `trade_credit`, `gift_card`, etc.).

## Slice overview

| Slice | Focus | Outcome |
| --- | --- | --- |
| **7B-1** | POS settlement | Multiple card/check rows, structured cash/card/check fields, settlement UI, receipts, reports, void reversal field copy |
| **7B-2** | Stored value foundation | Accounts, identifiers, append-only ledger, transfers, manual issue/adjust/void, liability reporting, permissions, audit |
| **7B-3** | POS integration | Issue credit from returns/exchanges, redeem stored value as tender, transactional ledger posting, void reversal |

Detailed scope: [phase-7b-1-pos-settlement-foundation.md](phase-7b-1-pos-settlement-foundation.md), [phase-7b-2-stored-value-foundation.md](phase-7b-2-stored-value-foundation.md), [phase-7b-3-pos-stored-value-integration.md](phase-7b-3-pos-stored-value-integration.md).

## Normative documentation

```text
docs/specifications/phase-7b-pos-settlement-spec.md
docs/specifications/phase-7b-stored-value-spec.md
docs/specifications/phase-7b-data-model.md
docs/specifications/phase-7b-test-plan.md
```

## Implementation sequencing

```text
7B-1A  pos_tenders data model migration + reference_number backfill
7B-1B  Pos::SettlementSync refactor (replace Pos::TenderSync)
7B-1C  POS settlement UI rebuild
7B-1D  Receipt, void, and report updates
7B-1E  Tests

7B-2A  Stored value account/identifier/ledger data model
7B-2B  Stored value services and permissions
7B-2C  Transfers, adjustments, voids
7B-2D  Liability reporting
7B-2E  Tests

7B-3A  POS issue-to-credit
7B-3B  POS stored value redemption
7B-3C  Multiple stored value tenders
7B-3D  POS void reversal of stored value entries
7B-3E  Receipt/report updates
7B-3F  Tests
```

## Deferred (all of Phase 7B)

```text
check refunds
customer deposits / prepayments
gift card activation/sale product workflow
used buyback intake, pricing, and seller workflow
multi-store liability settlement
GL journal entries and accounting export
metadata JSONB on pos_tenders
```

## Major risks

* Settlement UI complexity and draft-state edge cases
* Migration from `reference_number` tendered-cents hack
* Stored value concurrency (two registers redeeming same bearer code)
* Transaction boundary between POS completion and ledger posting
* Naming confusion between POS `store_credit` tender type and stored value account types

## Exit criteria (phase level)

Phase 7B is complete when all slice exit criteria in 7B-1, 7B-2, and 7B-3 are met. See each slice document and [phase-7b-test-plan.md](../specifications/phase-7b-test-plan.md).
