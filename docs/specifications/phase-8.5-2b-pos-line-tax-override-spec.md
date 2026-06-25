# Phase 8.5-2b Spec — POS Line Tax Override

Roadmap: [phase-8.5-2_pos_tax_exemption_tracking.md](../roadmap/phase-8.5-2_pos_tax_exemption_tracking.md)

Foundation: [phase-8.5-2a-pos-tax-exemption-spec.md](phase-8.5-2a-pos-tax-exemption-spec.md)

---

## Purpose

Allow staff to override a line's tax category; ShelfStack resolves the store rate via `TaxRateLookup`. Same-category rate correction without changing category is **not supported**.

## Calculation precedence

normal tax → line override → transaction exemption (exemption wins final tax)

## Services

Extends `Pos::TaxExceptionApplicationService` (`scope: line`) and `Pos::VoidTaxException` for `PosLineTaxOverride`.

## Permissions

* `pos.tax_overrides.line.apply`
* `pos.tax_overrides.line.void`

## Audit events

* `pos.line_tax_override.applied`
* `pos.line_tax_override.voided`

## POS UI

Line edit row: tax category picker, reason, note; active override summary with remove action. Hidden for gift card, sourced return, and uncategorized open-ring lines.
