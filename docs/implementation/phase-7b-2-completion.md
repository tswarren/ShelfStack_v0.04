# Phase 7B-2 Completion Record

**Phase slice:** 7B-2 Stored Value Foundation  
**Status:** Complete  
**Date:** 2026-06-21

---

## Delivered Scope

Phase 7B-2 implements the stored value account and ledger foundation **without POS integration**. POS issue/redeem remains deferred to 7B-3.

### Tables

```text
stored_value_reason_codes
stored_value_accounts
stored_value_identifiers
stored_value_ledger_entries
stored_value_transfers
```

Migration: `db/migrate/20250630120000_create_phase7b_stored_value_foundation.rb`

### Services

```text
StoredValue::Post
StoredValue::BalanceUpdater
StoredValue::Issue
StoredValue::Adjust
StoredValue::VoidEntry
StoredValue::Transfer
StoredValue::RedeemCredit          (service only; used by tests and 7B-3)
StoredValue::IdentifierCodec
StoredValue::CreateIdentifier
StoredValue::ReplaceIdentifier
StoredValue::DeactivateIdentifier
StoredValue::RebuildBalances
StoredValue::BalanceIntegrityCheck
StoredValue::AdminTaskAuthorization
StoredValue::LiabilityReport
```

### Admin UI

| Surface | Capability |
| --- | --- |
| Setup | Stored value reason codes CRUD, inactivate/reactivate |
| Customers | Account list/detail/create/edit, suspend/close |
| Customers | Identifier generate/replace/deactivate (masked display) |
| Customers | Manual issue, adjust, transfer, void entry forms |
| Customers | Liability report (`stored_value.reports.view`) |

### Rake tasks

```text
rails shelfstack:stored_value:rebuild_balances USERNAME=...
rails shelfstack:stored_value:integrity_check [USERNAME=...]
```

### Seeds

```text
db/seeds/phase7b_permissions.rb
db/seeds/phase7b_stored_value.rb
```

---

## Verification

1. Run migration: `bin/rails db:migrate`
2. Seed: `bin/rails db:seed` (includes Phase 7B permissions and reason codes)
3. Run tests: `bin/rails test test/models/stored_value_* test/services/stored_value test/integration/phase7b_stored_value_admin_test.rb test/seeds/phase7b_* test/tasks/stored_value_rake_test.rb`
4. Customers workspace → Stored value → create account, issue credit, view ledger
5. Setup → Stored Value Reason Codes
6. Confirm `Pos::TenderValidator` still rejects `gift_card` / `store_credit` (Phase 6 allowlist unchanged)

---

## Known Gaps / Deferred to 7B-3

```text
POS return-to-credit issuance
POS stored value redemption tenders
pos_tenders.stored_value_account_id / stored_value_identifier_id columns
pos.tenders.store_credit, pos.tenders.gift_card, pos.refunds.store_credit permissions at POS
Receipt/register report stored value totals from POS
Gift card product activation workflow
Buyback intake
Customer deposits/prepayments
Multi-store liability settlement
GL journal entries
```

---

## Audit Events

Account and identifier lifecycle plus ledger operations per [phase-7b-stored-value-spec.md](../specifications/phase-7b-stored-value-spec.md) §12.

---

## Permissions

All keys from roadmap §Permissions seeded in `phase7b_permissions.rb`, plus `setup.stored_value_reason_codes.*` and `stored_value.admin.rebuild_balances`.

Super administrator role receives new permissions on seed (existing grant-all loop in `db/seeds.rb`).
