# Phase 8.5-2a Spec — POS Transaction Tax Exemption

Roadmap: [phase-8.5-2_pos_tax_exemption_tracking.md](../roadmap/phase-8.5-2_pos_tax_exemption_tracking.md)

Data model: [phase-8.5-2a-data-model.md](phase-8.5-2a-data-model.md)

Test plan: [phase-8.5-2a-test-plan.md](phase-8.5-2a-test-plan.md)

---

## Purpose

Make POS tax results explainable and auditable when final tax differs from normal calculated tax. Phase 8.5-2a delivers transaction-level tax exemption, normal tax snapshots, and `Pos::TaxRecalculator` extraction.

## Services

```text
Pos::TaxRecalculator
Pos::TaxExceptionApplicationService (scope: transaction)
Pos::VoidTaxException
```

## Calculation order

1. Line bases
2. Discount phase
3. Normal tax snapshots via `Pos::TaxCalculator`
4. Transaction exemption (zeros eligible sale lines)
5. Roll up `tax_cents`, `normal_tax_cents`, totals

Sourced return lines bypass tax recalc; `ReturnLinePricing` prorates applied and normal tax from source.

## Audit events

* `pos.tax_exemption.applied`
* `pos.tax_exemption.voided`

## Permissions

* `pos.tax_exemptions.apply`
* `pos.tax_exemptions.void`
* `setup.tax_exception_reasons.*`

## POS UI

Transaction exemption panel in sidebar adjustments area; receipt footer shows reason/certificate when present.

Line tax override deferred to [phase-8.5-2b-pos-line-tax-override-spec.md](phase-8.5-2b-pos-line-tax-override-spec.md).
