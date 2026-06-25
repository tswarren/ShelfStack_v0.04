# Phase 8.5-2b Data Model — POS Line Tax Override

Functional behavior: [phase-8.5-2b-pos-line-tax-override-spec.md](phase-8.5-2b-pos-line-tax-override-spec.md)

Migration: `20250708120200_create_phase852b_line_tax_overrides.rb`

---

## `pos_line_tax_overrides`

One active override per line (`voided_at IS NULL` partial unique index on `pos_transaction_line_id`).

| Column | Notes |
|--------|-------|
| `override_tax_category_id` | Required staff input; stable intent |
| `override_store_tax_rate_id` | Resolved via `TaxRateLookup` |
| `override_tax_rate_bps` | Resolved snapshot |
| `override_tax_identifier_snapshot` | Resolved snapshot |
| `override_store_tax_rate_short_name_snapshot` | Resolved snapshot |
| `tax_exception_reason_id` | Must allow `rate_override` or `both` |
| `note` | Required when reason requires note |
| void/audit user fields | Same pattern as exemptions |

## `applied_tax_source`

Check constraint extended to include `line_override`.
