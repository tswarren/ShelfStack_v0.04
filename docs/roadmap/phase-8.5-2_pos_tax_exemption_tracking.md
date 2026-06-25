# Phase 8.5-2 Spec Refinement — POS Tax Exception Tracking

Formal specifications:

* [phase-8.5-2a-pos-tax-exemption-spec.md](../specifications/phase-8.5-2a-pos-tax-exemption-spec.md)
* [phase-8.5-2b-pos-line-tax-override-spec.md](../specifications/phase-8.5-2b-pos-line-tax-override-spec.md)

## Recommended design direction

Use the same pattern as Phase 8.5-1 discounts:

> Keep existing POS tax fields as cached/final transaction facts, but add structured exception records underneath them.

Current `main` already calculates POS line tax after discounts, stores final line tax snapshots, and rolls line tax into `pos_transactions.tax_cents`. `RecalculateTransaction` recalculates line bases, runs the discount phase, then applies line tax before transaction totals. Existing line tax snapshots include `tax_category`, `store_tax_rate`, `tax_rate_bps`, `tax_cents`, `tax_identifier_snapshot`, and `store_tax_rate_short_name_snapshot`.

So Phase 8.5-2 should **not replace tax calculation**. It should add:

1. normal/expected tax snapshots,
2. transaction-level exemption records,
3. line-level override records (Phase 8.5-2b),
4. reason/audit records,
5. recalculation behavior that explains why final tax differs from normal tax.

---

# Phase 8.5-2 — POS Tax Exception Tracking

## 1. Purpose

Make POS tax results explainable, auditable, and report-ready when final tax differs from the normal calculated tax.

This phase should answer:

* Was the item normally taxable?
* What tax rate would normally have applied?
* Was the transaction tax-exempt?
* Was a line tax category overridden?
* Who made the exception?
* Why was the exception made?
* What certificate/reference supports the exception?
* How much tax was reduced or changed?

---

## 2. Phased delivery

Phase 8.5-2 is split into two sub-phases. Ship **8.5-2a** first; **8.5-2b** builds on the same foundation.

### Phase 8.5-2a — Transaction tax exemption

| Deliverable | In 8.5-2a |
| ----------- | --------- |
| `tax_exception_reasons` + seeds | Yes — seed all reason keys; POS UI filters to `exemption` / `both` only |
| `pos_tax_exemptions` | Yes |
| `pos_line_tax_overrides` | Optional in migration; no services or UI until 8.5-2b |
| Normal tax snapshots on lines | Yes |
| `pos_transactions.normal_tax_cents` | Yes |
| `applied_tax_source` values | `normal`, `non_taxable`, `transaction_exemption`, `sourced_return` |
| `Pos::TaxRecalculator` extraction | Yes — normal tax + transaction exemption |
| `Pos::LineTaxSnapshot` helpers | Yes — `apply_normal!` / `apply_final!` |
| `Pos::TaxExceptionApplicationService` | Yes — transaction scope only |
| `Pos::VoidTaxException` | Yes — transaction scope only |
| Audit events | `pos.tax_exemption.applied` / `pos.tax_exemption.voided` |
| POS UI | Transaction exemption panel |
| Setup CRUD | Tax exception reasons |
| Backfill | Normal snapshots from existing final tax fields |
| Receipt | Exemption reason/certificate footer |

### Phase 8.5-2b — Line tax override

| Deliverable | In 8.5-2b |
| ----------- | --------- |
| `pos_line_tax_overrides` | Services and UI |
| `applied_tax_source` | Add `line_override` |
| `Pos::TaxExceptionApplicationService` | Add line scope |
| `Pos::VoidTaxException` | Add line scope |
| Audit events | `pos.line_tax_override.applied` / `pos.line_tax_override.voided` |
| POS UI | Line override controls in line detail row |
| Permissions | `pos.tax_overrides.line.apply` / `pos.tax_overrides.line.void` |

No second backfill is expected for 8.5-2b. Historical transactions without override records remain as backfilled in 8.5-2a.

---

## 3. Current-state assumptions

### Existing normal tax flow

`Pos::TaxCalculator` currently resolves a tax category and store tax rate, then calculates tax as:

```ruby
tax_cents = ((taxable_cents * rate.tax_rate_bps) / 10_000.0).round
```

It returns a tax snapshot containing the tax category, store tax rate, rate basis points, and tax cents. Normal tax calculation in `Pos::TaxRecalculator` should reuse `Pos::TaxCalculator` and `TaxRateLookup` — do not duplicate lookup logic.

### Existing line tax fields

`pos_transaction_lines` already stores final/applied tax fields:

| Existing field                       | Current role                    |
| ------------------------------------ | ------------------------------- |
| `tax_category_id`                    | Applied tax category            |
| `store_tax_rate_id`                  | Applied store tax rate          |
| `tax_rate_bps`                       | Applied rate                    |
| `tax_cents`                          | Final calculated line tax       |
| `tax_identifier_snapshot`            | Applied tax identifier snapshot |
| `store_tax_rate_short_name_snapshot` | Applied rate label snapshot     |

### Existing transaction tax total

`pos_transactions.tax_cents` is the final transaction-level tax total.

---

# 4. Scope

## In scope (full Phase 8.5-2)

1. `tax_exception_reasons`
2. transaction-level tax exemption records (8.5-2a)
3. line-level tax override records (8.5-2b)
4. normal/expected tax snapshots on POS lines (8.5-2a)
5. audit fields: user, timestamp, reason, note, certificate/reference
6. audit events for apply/void actions
7. recalculation behavior
8. basic POS UI
9. setup CRUD for tax exception reasons
10. tests for tax calculation, exemption, override, immutability, and reporting-readiness

## Out of scope

Do **not** include:

* full jurisdictional tax engine replacement
* multi-jurisdiction split taxes
* tax filing reports
* customer exemption certificate library
* automatic customer-based tax exemption
* tax holidays
* destination-based tax
* marketplace facilitator rules
* full accounting export
* same-category rate correction without changing tax category (staff must select a different tax category; see Decision 6)

This phase is about **POS exception tracking**, not replacing the current tax-rate system.

---

# 5. Key design decisions

## Decision 1 — Use a separate transaction exemption table

Use:

```text
pos_tax_exemptions
```

rather than adding all exemption fields directly to `pos_transactions`.

Reason: exemptions are audit events. A transaction should be able to show when an exemption was applied, by whom, why, and whether it was later removed before completion.

`pos_transactions.tax_cents` remains the cached final tax total.

## Decision 2 — Use a separate line override table

Use:

```text
pos_line_tax_overrides
```

rather than putting all override fields directly on `pos_transaction_lines`.

Reason: line overrides are also audit actions. They need reason, note, user, timestamp, and removal history.

`pos_transaction_lines.tax_cents` remains the final applied tax amount.

## Decision 3 — Add normal tax snapshots to POS lines

Add normal/expected tax fields to `pos_transaction_lines`.

This lets reports separate:

* normally taxable sales,
* transaction-exempt taxable sales,
* line-overridden taxable sales,
* non-taxable zero-tax sales.

Without normal snapshots, a completed exempt line with `tax_cents = 0` is hard to distinguish from a genuinely non-taxable item.

## Decision 4 — Unified apply/void services

Use two services mirroring Phase 8.5-1 discount pattern, not four separate services:

* `Pos::TaxExceptionApplicationService` — `scope: :transaction | :line`
* `Pos::VoidTaxException` — voids either exemption or override record

Implement the service interface in 8.5-2a with transaction scope only; add line scope in 8.5-2b.

Keep **two audit tables** (`pos_tax_exemptions`, `pos_line_tax_overrides`). Table separation stays domain-clear; service lifecycle stays DRY.

## Decision 5 — Extend `Pos::LineTaxSnapshot`

Add snapshot helpers rather than scattering attribute assignment in `Pos::TaxRecalculator`:

* `LineTaxSnapshot.apply_normal!(line, ...)` — writes `normal_*` fields
* `LineTaxSnapshot.apply_final!(line, ...)` — writes applied/final tax fields (replaces current `apply!` or aliases it)

## Decision 6 — Category-driven line override (8.5-2b)

Staff choose an **override tax category**; ShelfStack resolves the mapped store tax rate via `TaxRateLookup` for the transaction's store and business date.

* `override_tax_category_id` is the staff input and the stable audit intent.
* `override_store_tax_rate_id`, `override_tax_rate_bps`, and identifier/short-name snapshots are **resolved and stored at apply time** — not submitted by the client.
* On recalculation, re-resolve rate from the stored override category + current business date, then re-snapshot rate fields.

**Intentional constraint:** staff cannot override to a different rate for the same tax category. A manual correction to 0% while keeping the item's original classification is not supported — staff must select the tax category that maps to the intended rate (e.g. Non-Taxable). This keeps override behavior consistent with existing tax lookup and avoids arbitrary rate selection.

## Decision 7 — Transaction-level cache

Add only `pos_transactions.normal_tax_cents` as a header convenience cache. Do **not** add `tax_adjustment_cents` or `tax_exception_cents`; reports derive the difference as `normal_tax_cents - tax_cents`.

## Decision 8 — Audit events

Apply and void actions create audit events mirroring discount naming:

| Event | When |
| ----- | ---- |
| `pos.tax_exemption.applied` | Transaction exemption created (8.5-2a) |
| `pos.tax_exemption.voided` | Transaction exemption voided (8.5-2a) |
| `pos.line_tax_override.applied` | Line override created (8.5-2b) |
| `pos.line_tax_override.voided` | Line override voided (8.5-2b) |

Include actor, reason key, certificate (when present), transaction/line context, and store/workstation/session context where available.

---

# 6. Data model

## 6.1 `tax_exception_reasons`

Seedable/admin-maintainable reason list.

Use `reason_key`, not `code`, to stay consistent with `discount_reasons`.

| Field                       |     Type | Notes                                   |
| --------------------------- | -------: | --------------------------------------- |
| `id`                        |   bigint | PK                                      |
| `reason_key`                |   string | Unique stable key, lowercase snake_case |
| `name`                      |   string | User-facing                             |
| `exception_type`            |   string | `exemption`, `rate_override`, `both`    |
| `requires_note`             |  boolean | Default `false`                         |
| `requires_certificate`      |  boolean | Default `false`                         |
| `active`                    |  boolean | Default `true`                          |
| `sort_order`                |  integer | Default `0`                             |
| `created_at` / `updated_at` | datetime | Standard                                |

### Seed examples

| Key                  | Name                       | Type            | Notes                        |
| -------------------- | -------------------------- | --------------- | ---------------------------- |
| `resale`             | Resale Certificate         | `exemption`     | Requires certificate         |
| `nonprofit`          | Nonprofit Exemption        | `exemption`     | Usually requires certificate |
| `school`             | School Exemption           | `exemption`     | May require certificate      |
| `government`         | Government Exemption       | `exemption`     | May require certificate      |
| `out_of_state`       | Out of State / Not Taxable | `exemption`     | May require note             |
| `wrong_tax_category` | Wrong Tax Category         | `rate_override` | Requires note                |
| `manual_correction`  | Manual Tax Correction      | `rate_override` | Requires note                |
| `manager_adjustment` | Manager Tax Adjustment     | `both`          | Optional future approval     |
| `other`              | Other                      | `both`          | Requires note                |

### Validation

* `reason_key` required, unique, normalized.
* `name` required.
* `exception_type` must be one of: `exemption`, `rate_override`, `both`.
* inactive reasons cannot be selected for new exceptions.
* inactive reasons remain valid for historical records.

---

## 6.2 `pos_tax_exemptions`

One active transaction-level tax exemption per transaction. **Phase 8.5-2a.**

| Field                       |     Type | Notes                       |
| --------------------------- | -------: | --------------------------- |
| `id`                        |   bigint | PK                          |
| `pos_transaction_id`        |   bigint | Required                    |
| `tax_exception_reason_id`   |   bigint | Required                    |
| `certificate_number`        |   string | Optional/required by reason |
| `note`                      |     text | Optional/required by reason |
| `exempted_by_user_id`       |   bigint | Required                    |
| `exempted_at`               | datetime | Required                    |
| `voided_by_user_id`         |   bigint | Nullable                    |
| `voided_at`                 | datetime | Nullable                    |
| `void_reason`               |     text | Nullable                    |
| `details`                   |    jsonb | Default `{}`, null false    |
| `created_at` / `updated_at` | datetime | Standard                    |

### Indexes

* `pos_transaction_id`
* `tax_exception_reason_id`
* `exempted_by_user_id`
* partial unique index: one active exemption per transaction where `voided_at IS NULL`

### Rules

* transaction must be editable to add/remove an exemption.
* reason must allow `exemption` or `both`.
* reason is required.
* note required if reason requires note.
* certificate number required if reason requires certificate.
* completed transactions cannot have exemptions changed.
* removing an exemption should void the exemption record, not delete it.

---

## 6.3 `pos_line_tax_overrides`

One active line tax override per POS line. **Phase 8.5-2b.**

| Field                                           |     Type | Notes                                              |
| ----------------------------------------------- | -------: | -------------------------------------------------- |
| `id`                                            |   bigint | PK                                                 |
| `pos_transaction_id`                            |   bigint | Required, denormalized                             |
| `pos_transaction_line_id`                       |   bigint | Required                                           |
| `tax_exception_reason_id`                       |   bigint | Required                                           |
| `override_tax_category_id`                      |   bigint | Required — staff input; stable override intent     |
| `override_store_tax_rate_id`                    |   bigint | Required — resolved snapshot via `TaxRateLookup`   |
| `override_tax_rate_bps`                         |  integer | Required — resolved snapshot                       |
| `override_tax_identifier_snapshot`            |   string | Resolved snapshot                                  |
| `override_store_tax_rate_short_name_snapshot`   |   string | Resolved snapshot                                  |
| `note`                                          |     text | Optional/required by reason                        |
| `overridden_by_user_id`                         |   bigint | Required                                           |
| `overridden_at`                                 | datetime | Required                                           |
| `voided_by_user_id`                             |   bigint | Nullable                                           |
| `voided_at`                                     | datetime | Nullable                                           |
| `void_reason`                                   |     text | Nullable                                           |
| `details`                                       |    jsonb | Default `{}`, null false                           |
| `created_at` / `updated_at`                     | datetime | Standard                                           |

### Indexes

* `pos_transaction_id`
* `pos_transaction_line_id`
* `tax_exception_reason_id`
* `override_tax_category_id`
* `override_store_tax_rate_id`
* partial unique index: one active override per line where `voided_at IS NULL`

### Rules

* line must belong to transaction.
* transaction must be editable.
* line must be a positive sale line.
* no overrides on sourced return lines.
* no overrides on gift card sale lines.
* no overrides on open-ring lines without a tax category.
* reason must allow `rate_override` or `both`.
* note required if reason requires note.
* `override_tax_category_id` required; rate fields resolved by service via `TaxRateLookup` — reject if no applicable mapping for store + category + business date.
* completed transactions cannot have overrides changed.
* removing an override should void the override record, not delete it.

---

## 6.4 Normal tax snapshots on `pos_transaction_lines`

Add these fields. **Phase 8.5-2a.**

| Field                                       |    Type | Notes                                                                               |
| ------------------------------------------- | ------: | ----------------------------------------------------------------------------------- |
| `normal_tax_category_id`                    |  bigint | Expected category before exception                                                  |
| `normal_store_tax_rate_id`                  |  bigint | Expected store tax rate before exception                                            |
| `normal_tax_rate_bps`                       | integer | Expected rate before exception                                                      |
| `normal_tax_cents`                          | integer | Expected tax before exception                                                       |
| `normal_tax_identifier_snapshot`            |  string | Expected tax identifier                                                             |
| `normal_store_tax_rate_short_name_snapshot` |  string | Expected rate label                                                                 |
| `applied_tax_source`                        |  string | See §7.5; `line_override` added in 8.5-2b                                           |

Existing fields remain final/applied values:

| Existing field                       | New clarified role           |
| ------------------------------------ | ---------------------------- |
| `tax_category_id`                    | Final/applied tax category   |
| `store_tax_rate_id`                  | Final/applied store tax rate |
| `tax_rate_bps`                       | Final/applied rate           |
| `tax_cents`                          | Final/applied tax amount     |
| `tax_identifier_snapshot`            | Final/applied tax identifier |
| `store_tax_rate_short_name_snapshot` | Final/applied rate label     |

---

## 6.5 Transaction-level cache on `pos_transactions`

Add one field. **Phase 8.5-2a.**

| Field              |    Type | Notes                                    |
| ------------------ | ------: | ---------------------------------------- |
| `normal_tax_cents` | integer | Sum of signed line normal tax before exceptions |

Reports derive tax reduction as `normal_tax_cents - tax_cents`. Do not add `tax_adjustment_cents` or `tax_exception_cents`.

---

# 7. Service objects

## 7.1 `TaxExceptionReason`

Model only (not namespaced under `Pos::`). Handles validations and scopes.

Suggested scopes:

```ruby
scope :active_records, -> { where(active: true) }
scope :for_exemption, -> { where(exception_type: %w[exemption both]) }
scope :for_rate_override, -> { where(exception_type: %w[rate_override both]) }
```

---

## 7.2 `Pos::TaxExceptionApplicationService`

Unified apply service for transaction exemption (8.5-2a) and line override (8.5-2b).

```ruby
Pos::TaxExceptionApplicationService.call!(
  transaction:,
  scope:,                        # :transaction | :line
  tax_exception_reason:,
  actor:,
  line: nil,                     # required when scope == :line
  override_tax_category: nil,    # required when scope == :line
  certificate_number: nil,       # transaction scope
  note: nil
)
```

Responsibilities:

* verify transaction editable,
* verify reason active and allows the requested scope/type,
* enforce note/certificate requirements,
* for line scope: verify line belongs to transaction; reject gift card, sourced return, and uncategorized open-ring lines; resolve rate via `TaxRateLookup`; snapshot resolved rate fields,
* void any prior active record for the same transaction (exemption) or line (override),
* create `pos_tax_exemption` or `pos_line_tax_override`,
* create audit event,
* call `Pos::RecalculateTransaction`.

---

## 7.3 `Pos::VoidTaxException`

Unified void service for exemption or override records.

```ruby
Pos::VoidTaxException.call!(
  record:,           # PosTaxExemption or PosLineTaxOverride
  actor:,
  void_reason: nil
)
```

Responsibilities:

* verify transaction editable,
* verify record is active (not already voided),
* mark record voided,
* create audit event,
* call `Pos::RecalculateTransaction`.

---

## 7.4 `Pos::TaxRecalculator`

Central service used inside `Pos::RecalculateTransaction`. **Phase 8.5-2a** extracts existing behavior first; exemption layering in 8.5-2a; override layering in 8.5-2b.

```ruby
Pos::TaxRecalculator.call!(
  transaction:,
  business_date:
)
```

Responsibilities:

1. Skip sourced return lines (handled by `ReturnLinePricing` before tax phase).
2. Calculate normal tax for each eligible line via `Pos::TaxCalculator`.
3. Write normal tax snapshots via `LineTaxSnapshot.apply_normal!`.
4. Apply active line-level tax overrides (8.5-2b) — resolve rate from stored override category + business date.
5. Apply active transaction-level tax exemption (8.5-2a).
6. Write final applied tax via `LineTaxSnapshot.apply_final!`.
7. Set `applied_tax_source` on each line.
8. Update transaction `tax_cents` and `normal_tax_cents`.

This replaces the inline tax section currently inside `Pos::RecalculateTransaction`, while preserving existing calculation rules for non-exempt transactions.

---

## 7.5 `Pos::LineTaxSnapshot` extensions

Extend the existing helper:

```ruby
LineTaxSnapshot.apply_normal!(line, tax_category:, store_tax_rate:, tax_rate_bps:, tax_cents:)
LineTaxSnapshot.apply_final!(line, tax_category:, store_tax_rate:, tax_rate_bps:, tax_cents:)
```

`apply_final!` replaces or aliases the current `apply!` method.

---

# 8. Tax calculation rules

## 8.1 Calculation order

For each recalculation:

1. Recalculate line base amounts.
2. Apply discounts.
3. Calculate normal expected tax.
4. Apply active line-level tax override (8.5-2b).
5. Apply active transaction-level exemption (8.5-2a).
6. Store final tax on each line.
7. Roll up transaction totals.

This matches the existing order where tax is calculated after the discount phase.

---

## 8.2 Normal tax

Normal tax is the tax ShelfStack would have charged without exceptions.

For variant lines:

* resolve tax category from current classification defaults via `Pos::TaxCalculator.snapshot_for_variant!`,
* resolve current store rate for business date,
* calculate normal tax on `extended_price_cents`.

For open-ring lines:

* use selected subdepartment/tax category,
* resolve store rate for business date,
* calculate normal tax on `extended_price_cents`.

For gift card sale lines:

* normal tax is zero,
* `applied_tax_source = "non_taxable"`.

For sourced return lines:

* handled by `ReturnLinePricing` before the tax phase; see §8.7.

---

## 8.3 Line-type hard rules

| Line type | Normal tax | Applied tax | Exemption eligible? | Override eligible? |
| --------- | ---------- | ----------- | ------------------- | ------------------ |
| `gift_card_sale` | 0 | 0 | No | No |
| `open_ring` (no tax category) | skip / 0 | 0 | No | No |
| `open_ring` (with category) | calculated | per exception rules | Yes (8.5-2a) | Yes (8.5-2b) |
| Positive variant sale | calculated | per exception rules | Yes (8.5-2a) | Yes (8.5-2b) |
| Sourced return | prorate from source | prorate from source | No | No |

---

## 8.4 Line-level override (8.5-2b)

A line override changes the applied tax category (and resolved rate) for one line.

Rules:

* applies only to positive sale lines with a resolvable tax category,
* cannot apply to gift card sale lines,
* cannot apply to sourced return lines,
* cannot apply to open-ring lines without a tax category,
* staff selects `override_tax_category_id`; service resolves rate via `TaxRateLookup`,
* reason required,
* final tax recalculated from line `extended_price_cents` using the resolved override rate,
* normal tax snapshot remains unchanged,
* same-category rate correction without changing category is **not supported** (Decision 6).

Example:

```text
Normal category: Books → MI 6% = $0.60
Override category: Non-Taxable → MI 0% = $0.00
Reason: Wrong Tax Category
```

---

## 8.5 Transaction-level exemption (8.5-2a)

A transaction exemption applies after line overrides.

Rules:

* reason required,
* certificate required if reason requires it,
* applies only to positive taxable sale lines,
* does not alter sourced return lines,
* does not make gift card sale lines "exempt"; they remain non-taxable,
* sets final tax to zero for eligible sale lines,
* normal tax snapshot remains unchanged.

If a line has both a line override and a transaction exemption:

> The transaction exemption wins for final tax, but the line override record remains in audit history.

---

## 8.6 Tax source values

Use a controlled field on `pos_transaction_lines.applied_tax_source`.

| Value                   | Phase     | Meaning                                               |
| ----------------------- | --------- | ----------------------------------------------------- |
| `normal`                | 8.5-2a    | Final tax equals normal calculation                   |
| `non_taxable`           | 8.5-2a    | Normal rate/tax is zero or no tax applies             |
| `transaction_exemption` | 8.5-2a    | Final tax set to zero by active transaction exemption |
| `sourced_return`        | 8.5-2a    | Tax prorated from source sale line                    |
| `line_override`         | 8.5-2b    | Final tax comes from line override category/rate      |

---

## 8.7 Sourced return tax proration

`ReturnLinePricing` runs before the tax phase and bypasses `TaxRecalculator` for sourced return lines. Update it to prorate **both** applied and normal tax from the source line:

* Applied: `tax_cents`, `tax_category_id`, `store_tax_rate_id`, `tax_rate_bps`, identifier/short-name snapshots (existing behavior).
* Normal: `normal_tax_cents`, `normal_tax_category_id`, `normal_store_tax_rate_id`, `normal_tax_rate_bps`, normal identifier/short-name snapshots (new).
* Set `applied_tax_source = sourced_return`.
* Do not run exemption or override logic on sourced return lines.

When the original sale was tax-exempt, applied tax prorates as zero while normal tax prorates from the source line's normal snapshots — preserving gross exempt volume net of returns for reporting.

If source line predates normal snapshots (pre-backfill), fall back to prorating applied fields for both layers.

---

## 8.8 Business date changes on suspended transactions

When a suspended transaction completes under a later `business_date`:

* Active exemption and override **records persist** (reason, certificate, note, override category).
* **Normal tax** recalculates from current classification + new business date.
* **Line override rate snapshots** re-resolve from stored `override_tax_category_id` + new business date.
* **Applied tax** = normal → line override (if active) → transaction exemption (if active).

This prevents silent loss of exemption intent while keeping rate facts current when store tax mappings change.

---

# 9. UI requirements

## 9.1 Transaction tax exemption UI (8.5-2a)

Add a tax exception panel in POS, likely near totals/discounts.

Fields:

| Field                      | Required |
| -------------------------- | -------: |
| Tax exempt checkbox/action |      Yes |
| Reason                     |      Yes |
| Certificate/reference      | Conditionally |
| Note                       | Conditionally |
| Remove exemption           | If active and transaction editable |

Display:

```text
Tax exemption: Resale Certificate
Certificate: MI-123456
Expected tax: $4.12
Tax removed: -$4.12
```

Behavior:

* applying exemption recalculates totals immediately,
* removing exemption recalculates totals immediately,
* disabled after completion,
* reason/certificate validation errors render in POS workspace.

---

## 9.2 Line tax override UI (8.5-2b)

In the line edit/details row, add a small tax section:

Display:

```text
Normal tax: MI 6% — $0.72
Applied tax: MI 0% — $0.00
Override category: Non-Taxable
Reason: Wrong Tax Category
```

Fields:

| Field                    | Required |
| ------------------------ | -------: |
| Override tax category    |      Yes |
| Reason                   |      Yes |
| Note                     | Conditionally |
| Remove override          | If active and transaction editable |

Staff select a tax category from the global tax category list. ShelfStack resolves and displays the mapped store rate for preview before apply. Do not expose a free-form store rate picker.

Behavior:

* line override recalculates totals immediately,
* override action hidden/disabled on gift card sale lines,
* override action hidden/disabled on sourced return lines,
* override action hidden/disabled on open-ring lines without a tax category,
* if transaction is tax-exempt, show that exemption controls final tax.

---

## 9.3 Receipt behavior

Minimum receipt behavior:

* final tax total remains printed as today,
* transaction tax exemption reason/certificate prints if present (8.5-2a),
* line override does not need a prominent receipt note unless required later (8.5-2b).

Suggested receipt footer:

```text
Tax exemption: Resale Certificate
Certificate: MI-123456
```

---

# 10. Reporting requirements enabled

| Question                                        | Source                                                  |
| ----------------------------------------------- | ------------------------------------------------------- |
| What tax was normally expected?                 | `normal_tax_cents` on lines                             |
| What tax was actually charged?                  | `tax_cents` on lines                                    |
| How much taxable sale was exempted?             | active/completed `pos_tax_exemptions` + normal line tax |
| Which exemption reasons were used?              | `tax_exception_reasons`                                 |
| Which certificate/reference was used?           | `pos_tax_exemptions.certificate_number`                 |
| Which lines had tax overridden?                 | `pos_line_tax_overrides` (8.5-2b)                       |
| Which cashier made the tax exception?           | exemption/override user fields                          |
| Which sales were non-taxable without exemption? | `applied_tax_source = non_taxable`                      |
| Which sales were taxable but exempted?          | `applied_tax_source = transaction_exemption`            |
| Which sales used a manual override?             | `applied_tax_source = line_override` (8.5-2b)           |

---

# 11. Backfill / migration behavior

Existing completed transactions do not have structured tax exception records. **Phase 8.5-2a.**

Backfill should:

1. Set `normal_*` tax snapshot fields from the existing final tax fields.
2. Set `applied_tax_source`:
   * `normal` when `tax_cents > 0`,
   * `non_taxable` when `tax_cents = 0` and no exception record exists,
   * `sourced_return` for sourced return lines (`return_line?` with `source_transaction_line_id` present).
3. Set transaction `normal_tax_cents = tax_cents`.
4. Do **not** create synthetic exemptions or overrides for historical transactions.
5. Do **not** recalculate completed historical transactions.

This preserves history without inventing reasons that were never captured. Pre-backfill sourced returns fall back to prorating applied fields only (see §8.7).

---

# 12. Permissions

| Permission                               | Phase     | Purpose                               |
| ---------------------------------------- | --------- | ------------------------------------- |
| `pos.tax_exemptions.apply`               | 8.5-2a    | Apply transaction tax exemption       |
| `pos.tax_exemptions.void`                | 8.5-2a    | Remove/void transaction tax exemption |
| `pos.tax_overrides.line.apply`           | 8.5-2b    | Apply line tax override               |
| `pos.tax_overrides.line.void`            | 8.5-2b    | Remove/void line tax override         |
| `setup.tax_exception_reasons.view`       | 8.5-2a    | View tax exception reasons            |
| `setup.tax_exception_reasons.create`     | 8.5-2a    | Create tax exception reasons          |
| `setup.tax_exception_reasons.update`     | 8.5-2a    | Update tax exception reasons          |
| `setup.tax_exception_reasons.inactivate` | 8.5-2a    | Inactivate/reactivate reasons         |

Manager PIN authorization can be deferred unless tax overrides should require approval immediately in 8.5-2b.

---

# 13. Tests

## Model tests

### `TaxExceptionReason`

* requires key/name/type.
* validates exception type.
* normalizes reason key.
* inactive reason cannot be selected for new exception.
* certificate/note requirements are enforced through services.

### `PosTaxExemption` (8.5-2a)

* requires transaction.
* requires reason.
* reason must allow exemption.
* only one active exemption per transaction.
* cannot change after transaction completion.

### `PosLineTaxOverride` (8.5-2b)

* requires transaction and line.
* line must belong to transaction.
* `override_tax_category_id` required.
* reason must allow rate override.
* only one active override per line.
* cannot apply to gift card sale lines.
* cannot apply to sourced return lines.
* cannot change after transaction completion.
* rate fields populated by service via `TaxRateLookup`.

---

## Service tests

### Tax recalculation

| Scenario                                 | Phase     | Expected                                        |
| ---------------------------------------- | --------- | ----------------------------------------------- |
| normal taxable line                      | 8.5-2a    | normal and final tax match                      |
| non-taxable line                         | 8.5-2a    | normal and final tax zero; source `non_taxable` |
| transaction exemption                    | 8.5-2a    | normal tax preserved; final tax zero            |
| line override                            | 8.5-2b    | normal tax preserved; final tax uses override   |
| line override then transaction exemption | 8.5-2b    | final tax zero; both audit records preserved    |
| gift card sale line                      | 8.5-2a    | no exemption/override; tax zero; `non_taxable`  |
| open-ring without category               | 8.5-2a    | tax zero; not exemption-eligible                  |
| sourced return line                      | 8.5-2a    | applied + normal tax prorated from source       |
| return of exempt sale                    | 8.5-2a    | applied tax zero; normal tax prorated             |
| discounts before tax                     | 8.5-2a    | tax calculated on discounted extended price     |
| business date change on suspended txn      | 8.5-2a    | exemption persists; normal tax recalculates       |
| removing exemption                       | 8.5-2a    | final tax restores to normal                      |
| removing line override                   | 8.5-2b    | final tax restores to normal                      |
| override category with no mapping        | 8.5-2b    | rejected with configuration error                 |

---

## Controller/UI tests

### 8.5-2a

* cashier can apply transaction tax exemption with reason.
* exemption requiring certificate rejects blank certificate.
* exemption requiring note rejects blank note.
* cashier can remove exemption before completion.
* totals update after exemption.
* completed transaction cannot be modified.
* audit events created on apply/void.

### 8.5-2b

* cashier can apply line override with reason and tax category.
* line override requiring note rejects blank note.
* gift card line override attempt is rejected.
* totals update after override.
* audit events created on apply/void.

---

## Reporting-readiness tests

* exempt taxable sale can be queried separately from non-taxable sale (8.5-2a).
* override lines can be queried by reason and cashier (8.5-2b).
* transaction `tax_cents` equals sum of final line tax.
* transaction `normal_tax_cents` equals sum of signed line normal tax.
* tax exception records remain after completion.

---

# 14. Acceptance criteria

## Functional — 8.5-2a

* A transaction can be marked tax-exempt only with an active exemption reason.
* Certificate/reference is required when the reason requires it.
* Note is required when the reason requires it.
* Gift card and sourced return lines are not affected by transaction exemption.
* Tax totals recalculate immediately after exemption changes.
* Removing an exemption restores normal calculated tax.
* Completed transactions preserve tax exemption audit records.
* Audit events are created for apply and void.

## Functional — 8.5-2b

* A line tax category can be overridden only with an active override reason.
* Override rate is resolved from category via `TaxRateLookup`, not staff-selected.
* Gift card, sourced return, and uncategorized open-ring lines cannot receive overrides.
* Tax totals recalculate immediately after override changes.
* Removing an override restores normal calculated tax.
* Completed transactions preserve line override audit records.

## Reporting-readiness (full 8.5-2)

* Normal expected tax is preserved.
* Final applied tax is preserved.
* Exempt sales are distinguishable from non-taxable sales.
* Line overrides are distinguishable from normal tax.
* Tax exception reason, user, timestamp, and certificate/reference are reportable.
* Tax reports can separate:
  * normal taxable sales,
  * exempt taxable sales,
  * line-overridden tax,
  * zero-tax non-taxable lines.

---

# 15. Recommended implementation order

## Phase 8.5-2a — Transaction tax exemption

### Step 1 — Data foundation

* Add `tax_exception_reasons`.
* Add `pos_tax_exemptions`.
* Add normal tax snapshot fields + `applied_tax_source` to `pos_transaction_lines`.
* Add `normal_tax_cents` to `pos_transactions`.
* Seed tax exception reasons and permissions.

### Step 2 — Tax recalculation (behavior-neutral first)

* Extend `Pos::LineTaxSnapshot` with `apply_normal!` / `apply_final!`.
* Extract inline tax logic from `Pos::RecalculateTransaction` into `Pos::TaxRecalculator`.
* Write normal snapshots on every recalc; verify all existing tax tests pass with no exemption behavior yet.

### Step 3 — Exemption services

* `Pos::TaxExceptionApplicationService` (transaction scope).
* `Pos::VoidTaxException` (transaction scope).
* Wire exemption layering into `Pos::TaxRecalculator`.
* Audit events on apply/void.

### Step 4 — Return line integration

* Update `ReturnLinePricing` to prorate normal tax fields from source.
* Set `applied_tax_source = sourced_return`.

### Step 5 — POS UI + Setup

* Transaction exemption panel.
* Tax exception reason CRUD at `/setup/tax_exception_reasons`.
* Receipt exemption footer.

### Step 6 — Backfill

* Populate normal tax snapshots from existing final tax fields.
* Do not invent historical exemption records.

### Step 7 — Regression tests

* POS sale tax still works.
* Discounts-before-tax behavior still works.
* Returns prorate applied and normal tax.
* Register summaries still use final tax totals.
* Exempt taxable sales queryable separately from non-taxable sales.

---

## Phase 8.5-2b — Line tax override

### Step 1 — Data foundation

* Add `pos_line_tax_overrides` (if not created in 8.5-2a migration).
* Seed override permissions.

### Step 2 — Override services

* Add line scope to `Pos::TaxExceptionApplicationService`.
* Add line scope to `Pos::VoidTaxException`.
* Wire override layering into `Pos::TaxRecalculator`.
* Audit events on apply/void.

### Step 3 — POS UI

* Line override controls in line detail row.
* Tax category picker with resolved rate preview.

### Step 4 — Tests

* Override apply/void, category resolution, interaction with transaction exemption.
* Reporting queries for `applied_tax_source = line_override`.
