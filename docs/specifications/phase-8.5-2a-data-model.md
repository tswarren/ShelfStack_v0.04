# Phase 8.5-2a Data Model — POS Transaction Tax Exemption

Functional behavior: [phase-8.5-2a-pos-tax-exemption-spec.md](phase-8.5-2a-pos-tax-exemption-spec.md)

Roadmap: [phase-8.5-2_pos_tax_exemption_tracking.md](../roadmap/phase-8.5-2_pos_tax_exemption_tracking.md)

Migrations: `20250708120000_create_phase852a_tax_exception_foundation.rb`, `20250708120100_backfill_phase852a_normal_tax_snapshots.rb`

---

## `tax_exception_reasons`

Seedable/admin-maintainable reason reference data.

| Column | Type | Notes |
|--------|------|-------|
| `reason_key` | string | Unique stable key |
| `name` | string | Unique user-facing label |
| `exception_type` | string | `exemption`, `rate_override`, `both` |
| `requires_note` | boolean | Default false |
| `requires_certificate` | boolean | Default false |
| `active` | boolean | Default true |
| `sort_order` | integer | Default 0 |

## `pos_tax_exemptions`

One active transaction-level exemption per transaction (`voided_at IS NULL` partial unique index on `pos_transaction_id`).

Audit fields: reason, certificate, note, exempted user/at, void user/at/reason, `details` JSONB.

## Line additions on `pos_transaction_lines`

| Column | Purpose |
|--------|---------|
| `normal_tax_category_id` | Expected category before exceptions |
| `normal_store_tax_rate_id` | Expected rate before exceptions |
| `normal_tax_rate_bps` | Expected bps before exceptions |
| `normal_tax_cents` | Expected tax before exceptions |
| `normal_tax_identifier_snapshot` | Expected identifier |
| `normal_store_tax_rate_short_name_snapshot` | Expected label |
| `applied_tax_source` | `normal`, `non_taxable`, `transaction_exemption`, `sourced_return` (8.5-2b adds `line_override`) |

Existing applied tax columns remain final/applied values.

## `pos_transactions.normal_tax_cents`

Cached sum of signed line normal tax before exceptions.

## Backfill

Copies final tax fields to normal fields for historical lines; sets `applied_tax_source` heuristically; does **not** create synthetic exemption records.
