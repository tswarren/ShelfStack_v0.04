# Phase 8.5-2 Spec Refinement — POS Tax Exception Tracking

## Recommended design direction

Use the same pattern as Phase 8.5-1 discounts:

> Keep existing POS tax fields as cached/final transaction facts, but add structured exception records underneath them.

Current `main` already calculates POS line tax after discounts, stores final line tax snapshots, and rolls line tax into `pos_transactions.tax_cents`. `RecalculateTransaction` recalculates line bases, runs the discount phase, then applies line tax before transaction totals.  Existing line tax snapshots include `tax_category`, `store_tax_rate`, `tax_rate_bps`, `tax_cents`, `tax_identifier_snapshot`, and `store_tax_rate_short_name_snapshot`.

So Phase 8.5-2 should **not replace tax calculation**. It should add:

1. normal/expected tax snapshots,
2. transaction-level exemption records,
3. line-level override records,
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
* Was a line tax rate overridden?
* Who made the exception?
* Why was the exception made?
* What certificate/reference supports the exception?
* How much tax was reduced or changed?

---

## 2. Current-state assumptions

## Existing normal tax flow

`Pos::TaxCalculator` currently resolves a tax category and store tax rate, then calculates tax as:

```ruby
tax_cents = ((taxable_cents * rate.tax_rate_bps) / 10_000.0).round
```

It returns a tax snapshot containing the tax category, store tax rate, rate basis points, and tax cents.

## Existing line tax fields

`pos_transaction_lines` already stores final/applied tax fields:

| Existing field                       | Current role                    |
| ------------------------------------ | ------------------------------- |
| `tax_category_id`                    | Applied tax category            |
| `store_tax_rate_id`                  | Applied store tax rate          |
| `tax_rate_bps`                       | Applied rate                    |
| `tax_cents`                          | Final calculated line tax       |
| `tax_identifier_snapshot`            | Applied tax identifier snapshot |
| `store_tax_rate_short_name_snapshot` | Applied rate label snapshot     |

These are visible in the current schema.

## Existing transaction tax total

`pos_transactions.tax_cents` is the final transaction-level tax total.

---

# 3. Scope

## In scope

Phase 8.5-2 should deliver:

1. `tax_exception_reasons`
2. transaction-level tax exemption records
3. line-level tax override records
4. normal/expected tax snapshots on POS lines
5. audit fields: user, timestamp, reason, note, certificate/reference
6. recalculation behavior
7. basic POS UI
8. setup CRUD for tax exception reasons
9. tests for tax calculation, exemption, override, immutability, and reporting-readiness

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

This phase is about **POS exception tracking**, not replacing the current tax-rate system.

---

# 4. Key design decisions

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

---

# 5. Data model

## 5.1 `tax_exception_reasons`

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
* `exception_type` must be one of:

  * `exemption`
  * `rate_override`
  * `both`
* inactive reasons cannot be selected for new exceptions.
* inactive reasons remain valid for historical records.

---

## 5.2 `pos_tax_exemptions`

One active transaction-level tax exemption per transaction.

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

## 5.3 `pos_line_tax_overrides`

One active line tax override per POS line.

| Field                                         |     Type | Notes                       |
| --------------------------------------------- | -------: | --------------------------- |
| `id`                                          |   bigint | PK                          |
| `pos_transaction_id`                          |   bigint | Required, denormalized      |
| `pos_transaction_line_id`                     |   bigint | Required                    |
| `tax_exception_reason_id`                     |   bigint | Required                    |
| `override_tax_category_id`                    |   bigint | Nullable                    |
| `override_store_tax_rate_id`                  |   bigint | Required after resolution   |
| `override_tax_rate_bps`                       |  integer | Required snapshot           |
| `override_tax_identifier_snapshot`            |   string | Nullable                    |
| `override_store_tax_rate_short_name_snapshot` |   string | Nullable                    |
| `note`                                        |     text | Optional/required by reason |
| `overridden_by_user_id`                       |   bigint | Required                    |
| `overridden_at`                               | datetime | Required                    |
| `voided_by_user_id`                           |   bigint | Nullable                    |
| `voided_at`                                   | datetime | Nullable                    |
| `void_reason`                                 |     text | Nullable                    |
| `details`                                     |    jsonb | Default `{}`, null false    |
| `created_at` / `updated_at`                   | datetime | Standard                    |

### Indexes

* `pos_transaction_id`
* `pos_transaction_line_id`
* `tax_exception_reason_id`
* `override_store_tax_rate_id`
* partial unique index: one active override per line where `voided_at IS NULL`

### Rules

* line must belong to transaction.
* transaction must be editable.
* line must be a positive sale line.
* no overrides on sourced return lines.
* no overrides on gift card sale lines.
* reason must allow `rate_override` or `both`.
* note required if reason requires note.
* completed transactions cannot have overrides changed.
* removing an override should void the override record, not delete it.

---

## 5.4 Add normal tax snapshots to `pos_transaction_lines`

Add these fields:

| Field                                       |    Type | Notes                                                                               |
| ------------------------------------------- | ------: | ----------------------------------------------------------------------------------- |
| `normal_tax_category_id`                    |  bigint | Expected category before exception                                                  |
| `normal_store_tax_rate_id`                  |  bigint | Expected store tax rate before exception                                            |
| `normal_tax_rate_bps`                       | integer | Expected rate before exception                                                      |
| `normal_tax_cents`                          | integer | Expected tax before exception                                                       |
| `normal_tax_identifier_snapshot`            |  string | Expected tax identifier                                                             |
| `normal_store_tax_rate_short_name_snapshot` |  string | Expected rate label                                                                 |
| `applied_tax_source`                        |  string | `normal`, `non_taxable`, `line_override`, `transaction_exemption`, `sourced_return` |

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

## 5.5 Optional cached fields on `pos_transactions`

Recommended but optional:

| Field                  |    Type | Notes                                                           |
| ---------------------- | ------: | --------------------------------------------------------------- |
| `normal_tax_cents`     | integer | Sum of line normal tax before exceptions                        |
| `tax_adjustment_cents` | integer | `tax_cents - normal_tax_cents`; usually negative for exemptions |
| `tax_exception_cents`  | integer | Positive reduction amount, if preferred for reports             |

If only one is added, prefer:

```text
normal_tax_cents
```

The report can derive the difference from `normal_tax_cents - tax_cents`.

---

# 6. Service objects

## 6.1 `Pos::TaxExceptionReason`

Model only. Handles validations and scopes.

Suggested scope:

```ruby
scope :active_records, -> { where(active: true) }
scope :for_exemption, -> { where(exception_type: %w[exemption both]) }
scope :for_rate_override, -> { where(exception_type: %w[rate_override both]) }
```

---

## 6.2 `Pos::ApplyTaxExemption`

Creates a transaction-level exemption.

```ruby
Pos::ApplyTaxExemption.call!(
  transaction:,
  tax_exception_reason:,
  certificate_number: nil,
  note: nil,
  actor:
)
```

Responsibilities:

* verify transaction editable,
* verify reason active,
* verify reason allows exemption,
* enforce note/certificate requirements,
* void any prior active transaction exemption,
* create `pos_tax_exemption`,
* recalculate transaction tax and totals.

---

## 6.3 `Pos::VoidTaxExemption`

Voids/removes the active transaction exemption before completion.

```ruby
Pos::VoidTaxExemption.call!(
  exemption:,
  actor:,
  void_reason: nil
)
```

Responsibilities:

* verify transaction editable,
* mark exemption voided,
* recalculate transaction tax and totals.

---

## 6.4 `Pos::ApplyLineTaxOverride`

Creates a line-level tax override.

```ruby
Pos::ApplyLineTaxOverride.call!(
  transaction:,
  line:,
  tax_exception_reason:,
  override_tax_category: nil,
  override_store_tax_rate:,
  note: nil,
  actor:
)
```

Responsibilities:

* verify transaction editable,
* verify line belongs to transaction,
* reject gift card sale lines,
* reject sourced return lines,
* verify reason active,
* verify reason allows rate override,
* enforce note requirement,
* void prior active override for that line,
* snapshot override rate fields,
* create `pos_line_tax_override`,
* recalculate transaction tax and totals.

---

## 6.5 `Pos::VoidLineTaxOverride`

Voids/removes an active line tax override before completion.

```ruby
Pos::VoidLineTaxOverride.call!(
  override:,
  actor:,
  void_reason: nil
)
```

---

## 6.6 `Pos::TaxRecalculator`

Central service used inside `Pos::RecalculateTransaction`.

```ruby
Pos::TaxRecalculator.call!(
  transaction:,
  business_date:
)
```

Responsibilities:

1. Calculate normal tax for each eligible line.
2. Write normal tax snapshots.
3. Apply active line-level tax overrides.
4. Apply active transaction-level tax exemption.
5. Update final existing line tax fields.
6. Update transaction `tax_cents`.
7. Update optional transaction `normal_tax_cents`.

This should replace the inline tax section currently inside `Pos::RecalculateTransaction`, while preserving the existing calculation rules.

---

# 7. Tax calculation rules

## 7.1 Calculation order

For each recalculation:

1. Recalculate line base amounts.
2. Apply discounts.
3. Calculate normal expected tax.
4. Apply active line-level tax override.
5. Apply active transaction-level exemption.
6. Store final tax on each line.
7. Roll up transaction totals.

This matches the existing order where tax is calculated after the discount phase.

---

## 7.2 Normal tax

Normal tax is the tax ShelfStack would have charged without exceptions.

For variant lines:

* resolve tax category from current classification defaults,
* resolve current store rate for business date,
* calculate normal tax on `extended_price_cents`.

For open-ring lines:

* use selected subdepartment/tax category,
* resolve store rate for business date,
* calculate normal tax on `extended_price_cents`.

For gift card sale lines:

* normal tax should be zero,
* `applied_tax_source = "non_taxable"`.

For sourced return lines:

* preserve source return pricing/tax behavior,
* `applied_tax_source = "sourced_return"`.

---

## 7.3 Line-level override

A line override changes the applied tax rate for one line.

Rules:

* applies only to positive sale lines,
* cannot apply to gift card sale lines,
* cannot apply to sourced return lines,
* reason required,
* final tax is recalculated from line `extended_price_cents` using the override rate,
* normal tax snapshot remains unchanged.

Example:

```text
Normal tax: 6% = $0.60
Override rate: 0% = $0.00
Reason: Wrong Tax Category
```

---

## 7.4 Transaction-level exemption

A transaction exemption applies after line overrides.

Rules:

* reason required,
* certificate required if reason requires it,
* applies only to positive taxable sale lines,
* does not alter sourced return lines,
* does not make gift card sale lines “exempt”; they remain non-taxable,
* sets final tax to zero for eligible sale lines,
* normal tax snapshot remains unchanged.

If a line has both a line override and a transaction exemption:

> The transaction exemption wins for final tax, but the line override record remains in audit history.

---

## 7.5 Tax source values

Use a controlled field on `pos_transaction_lines.applied_tax_source`.

| Value                   | Meaning                                               |
| ----------------------- | ----------------------------------------------------- |
| `normal`                | Final tax equals normal calculation                   |
| `non_taxable`           | Normal rate/tax is zero or no tax applies             |
| `line_override`         | Final tax comes from line override                    |
| `transaction_exemption` | Final tax set to zero by active transaction exemption |
| `sourced_return`        | Tax copied/prorated from source sale line             |

---

# 8. UI requirements

## 8.1 Transaction tax exemption UI

Add a tax exception panel in POS, likely near totals/discounts.

Fields:

| Field                      |                           Required |
| -------------------------- | ---------------------------------: |
| Tax exempt checkbox/action |                                Yes |
| Reason                     |                                Yes |
| Certificate/reference      |                      Conditionally |
| Note                       |                      Conditionally |
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

## 8.2 Line tax override UI

In the line edit/details row, add a small tax section:

Display:

```text
Normal tax: MI 6% — $0.72
Applied tax: MI 0% — $0.00
Reason: Wrong Tax Category
```

Fields:

| Field                  |                           Required |
| ---------------------- | ---------------------------------: |
| Override rate/category |                                Yes |
| Reason                 |                                Yes |
| Note                   |                      Conditionally |
| Remove override        | If active and transaction editable |

Behavior:

* line override recalculates totals immediately,
* override action hidden/disabled on gift card sale lines,
* override action hidden/disabled on sourced return lines,
* if transaction is tax-exempt, show that exemption controls final tax.

---

## 8.3 Receipt behavior

Minimum Phase 8.5-2 receipt behavior:

* final tax total remains printed as today,
* transaction tax exemption reason/certificate prints if present,
* line override does not need a prominent receipt note unless required later.

Suggested receipt footer:

```text
Tax exemption: Resale Certificate
Certificate: MI-123456
```

---

# 9. Reporting requirements enabled

This phase should make these report questions answerable:

| Question                                        | Source                                                  |
| ----------------------------------------------- | ------------------------------------------------------- |
| What tax was normally expected?                 | `normal_tax_cents` on lines                             |
| What tax was actually charged?                  | `tax_cents` on lines                                    |
| How much taxable sale was exempted?             | active/completed `pos_tax_exemptions` + normal line tax |
| Which exemption reasons were used?              | `tax_exception_reasons`                                 |
| Which certificate/reference was used?           | `pos_tax_exemptions.certificate_number`                 |
| Which lines had tax overridden?                 | `pos_line_tax_overrides`                                |
| Which cashier made the tax exception?           | exemption/override user fields                          |
| Which sales were non-taxable without exemption? | `applied_tax_source = non_taxable`                      |
| Which sales were taxable but exempted?          | `applied_tax_source = transaction_exemption`            |
| Which sales used a manual override?             | `applied_tax_source = line_override`                    |

---

# 10. Backfill / migration behavior

Existing completed transactions do not have structured tax exception records.

Backfill should:

1. Set `normal_*` tax snapshot fields from the existing final tax fields.
2. Set `applied_tax_source`:

   * `normal` when `tax_cents > 0`,
   * `non_taxable` when `tax_cents = 0` and no exception record exists,
   * `sourced_return` for sourced return lines if identifiable.
3. Set transaction `normal_tax_cents = tax_cents` if that cached field is added.
4. Do **not** create synthetic exemptions or overrides for historical transactions.
5. Do **not** recalculate completed historical transactions.

This preserves history without inventing reasons that were never captured.

---

# 11. Permissions

Suggested permission keys:

| Permission                               | Purpose                               |
| ---------------------------------------- | ------------------------------------- |
| `pos.tax_exemptions.apply`               | Apply transaction tax exemption       |
| `pos.tax_exemptions.void`                | Remove/void transaction tax exemption |
| `pos.tax_overrides.line.apply`           | Apply line tax override               |
| `pos.tax_overrides.line.void`            | Remove/void line tax override         |
| `setup.tax_exception_reasons.view`       | View tax exception reasons            |
| `setup.tax_exception_reasons.create`     | Create tax exception reasons          |
| `setup.tax_exception_reasons.update`     | Update tax exception reasons          |
| `setup.tax_exception_reasons.inactivate` | Inactivate/reactivate reasons         |

For 8.5-2, manager PIN authorization can be deferred unless you want tax overrides to require approval immediately.

---

# 12. Tests

## Model tests

### `TaxExceptionReason`

* requires key/name/type.
* validates exception type.
* normalizes reason key.
* inactive reason cannot be selected for new exception.
* certificate/note requirements are enforced through services.

### `PosTaxExemption`

* requires transaction.
* requires reason.
* reason must allow exemption.
* only one active exemption per transaction.
* cannot change after transaction completion.

### `PosLineTaxOverride`

* requires transaction and line.
* line must belong to transaction.
* reason must allow rate override.
* only one active override per line.
* cannot apply to gift card sale lines.
* cannot apply to sourced return lines.
* cannot change after transaction completion.

---

## Service tests

### Tax recalculation

| Scenario                                 | Expected                                        |
| ---------------------------------------- | ----------------------------------------------- |
| normal taxable line                      | normal and final tax match                      |
| non-taxable line                         | normal and final tax zero; source `non_taxable` |
| transaction exemption                    | normal tax preserved; final tax zero            |
| line override                            | normal tax preserved; final tax uses override   |
| line override then transaction exemption | final tax zero; both audit records preserved    |
| gift card sale line                      | no exemption/override allocation; tax zero      |
| sourced return line                      | source tax preserved                            |
| discounts before tax                     | tax calculated on discounted extended price     |
| removing exemption                       | normal tax restored                             |
| removing line override                   | normal tax restored                             |

---

## Controller/UI tests

* cashier can apply transaction tax exemption with reason.
* exemption requiring certificate rejects blank certificate.
* exemption requiring note rejects blank note.
* cashier can remove exemption before completion.
* cashier can apply line override with reason.
* line override requiring note rejects blank note.
* gift card line override attempt is rejected.
* totals update after exemption/override.
* completed transaction cannot be modified.

---

## Reporting-readiness tests

* exempt taxable sale can be queried separately from non-taxable sale.
* override lines can be queried by reason and cashier.
* transaction `tax_cents` equals sum of final line tax.
* transaction `normal_tax_cents`, if added, equals sum of line normal tax.
* tax exception records remain after completion.

---

# 13. Acceptance criteria

## Functional

* A transaction can be marked tax-exempt only with an active exemption reason.
* Certificate/reference is required when the reason requires it.
* Note is required when the reason requires it.
* A line tax rate can be overridden only with an active override reason.
* Gift card sale lines cannot receive tax overrides.
* Sourced return lines preserve source tax behavior.
* Tax totals recalculate immediately after exemption/override changes.
* Removing an exemption or override restores normal calculated tax.
* Completed transactions preserve tax exception audit records.

## Reporting-readiness

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

# 14. Recommended implementation order

## Step 1 — Data foundation

* Add `tax_exception_reasons`.
* Add `pos_tax_exemptions`.
* Add `pos_line_tax_overrides`.
* Add normal tax snapshot fields to `pos_transaction_lines`.
* Optionally add `normal_tax_cents` to `pos_transactions`.
* Seed tax exception reasons.

## Step 2 — Tax exception services

* `Pos::ApplyTaxExemption`
* `Pos::VoidTaxExemption`
* `Pos::ApplyLineTaxOverride`
* `Pos::VoidLineTaxOverride`

## Step 3 — Tax recalculation

* Extract current inline tax logic from `Pos::RecalculateTransaction`.
* Add `Pos::TaxRecalculator`.
* Preserve current normal behavior.
* Layer in exemptions and overrides.

## Step 4 — POS UI

* Transaction exemption panel.
* Line override controls.
* Tax status display.
* Turbo refresh of totals/readiness.

## Step 5 — Setup UI

* Tax exception reason CRUD.
* Seed permissions and role grants.

## Step 6 — Backfill

* Populate normal tax snapshots from existing final tax fields.
* Do not recalculate completed transactions.
* Do not invent historical exemption/override records.

## Step 7 — Regression tests

* POS sale tax still works.
* discounts-before-tax behavior still works.
* returns still work.
* register summaries still use final tax totals.
* new tax exception facts are queryable.
