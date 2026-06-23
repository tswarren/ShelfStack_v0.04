# 7B-3: POS Stored Value Integration

Parent phase: [phase-7b-customer-credit-foundation.md](phase-7b-customer-credit-foundation.md)

Normative spec: [phase-7b-stored-value-spec.md](../specifications/phase-7b-stored-value-spec.md) (§ POS integration)

Depends on: 7B-1 (settlement rows), 7B-2 (accounts/ledger)

## Purpose

7B-3 wires stored value into POS so credit can be issued from returns and exchanges, redeemed as tender, voided, and reported.

## Capabilities

```text
issue store credit from POS returns
issue store credit from exchanges with refund due
redeem store credit as POS tender
redeem gift-card-type stored value as POS tender
redeem multiple stored value accounts in one transaction
post ledger entries transactionally with POS completion
show issued/redeemed credit on receipts
reverse stored value entries on POS void
```

## POS tender type policy

Replace Phase 6 fixed allowlist with phase-aware policy:

```text
Pos::TenderTypePolicy.allowed_types(transaction)
```

7B-1 enabled: `cash`, `card`, `check`

7B-3 additionally enables: `store_credit`, `gift_card`

`store_credit` and `gift_card` rows are rejected unless linked to a valid stored value account/identifier and pass stored value validation.

## `pos_tenders` linkage

Stored value tender rows require:

```text
pos_tenders.stored_value_account_id   (required for store_credit/gift_card rows)
pos_tenders.stored_value_identifier_id (required when lookup is by code)
```

Ledger entries use polymorphic source:

```text
source_type = PosTender
source_id = pos_tender.id
```

## Issuance (return / exchange)

POS refund settlement row:

```text
tender_type = store_credit (or gift_card when applicable)
amount_cents = negative refund amount
```

Ledger entry:

```text
entry_type = issue
amount_delta_cents = positive credit amount
source_type = PosTender
source_id = pos_tender.id
```

### Account selection workflows

| Scenario | Behavior |
| --- | --- |
| Return with `pos_transactions.customer_id` | Default to customer-linked account of appropriate type; create if none exists (permission-gated) |
| Return without customer | Prompt for bearer account selection or create standalone account |
| Exchange with refund due | Same as return; may coexist with other refund rows (card + store credit split) |

Example split refund:

```text
Exchange total: -$30.00
  Card refund:      -$10.00
  Store credit:     -$20.00  -> ledger issue +$20.00
```

## Redemption

POS tender row:

```text
tender_type = store_credit or gift_card
amount_cents = positive redeemed amount
stored_value_account_id set
```

Ledger entry:

```text
entry_type = redeem
amount_delta_cents = negative redeemed amount
source_type = PosTender
source_id = pos_tender.id
```

Rules:

```text
one pos_tender row per stored value account redeemed
one ledger entry per pos_tender row
POS caps saved tender amount to min(amount entered, account balance)
redemption cannot exceed transaction amount due (sum of tenders must equal transaction total)
multiple accounts allowed in one transaction
```

## Transaction boundary

### Completion ordering

```text
Pos::CompleteTransaction
  -> recalculate transaction
  -> validate settlement rows (Pos::TenderValidator / TenderTypePolicy)
  -> validate stored value lookups and balances
  -> lock stored value accounts involved
  -> post stored value ledger entries for redemptions/issues
  -> mark POS transaction completed
  -> create receipt snapshot
  -> commit
```

If any stored value ledger post fails, POS completion fails and no POS/stored-value state is committed.

### Void ordering

```text
Pos::VoidTransaction
  -> create PosVoid
  -> reverse inventory posting
  -> create reversing pos_tender rows
  -> create reversing stored value ledger entries (reverses_entry_id)
  -> mark original POS transaction voided
  -> commit
```

## Audit events

```text
pos.stored_value.issued
pos.stored_value.redeemed
pos.stored_value.void_reversed
```

Plus underlying `stored_value.ledger.*` events from 7B-2.

## Receipts and reports

Receipts show credit issued/redeemed and remaining balance where applicable.

Register reports include store-credit and gift-card tender totals. Liability reports reflect POS issuances and redemptions.

---

# Exit criteria

7B-3 is complete when:

1. POS issues store credit from a return.
2. POS issues store credit from an exchange with refund due.
3. POS redeems store credit as tender.
4. POS redeems gift-card-type stored value as tender.
5. POS redeems multiple stored value accounts in one transaction.
6. Each redemption creates one POS tender row and one ledger entry.
7. Each issuance creates one POS refund settlement row and one ledger entry.
8. Redemption tender amount is capped to available account balance (ledger never exceeds balance).
9. Redemption cannot exceed transaction balance due.
10. Issue/redeem operations are transactional with POS completion.
11. POS void reverses stored value ledger entries without mutating originals.
12. Receipts show credit issued/redeemed and remaining balance.
13. Register reports include store-credit and gift-card tender totals.
14. Liability reports reflect POS issuances and redemptions.
15. `store_credit` and `gift_card` tender types are enabled only when stored value validation is active.
