# Phase 8.5-2a — Completion Record

**Status:** In review

## Summary

Phase 8.5-2a adds structured transaction tax exemption tracking with normal/applied tax snapshots, `Pos::TaxRecalculator`, and Setup/POS UI for exemption reasons.

## Deliverables

### Schema

```text
tax_exception_reasons
pos_tax_exemptions
pos_transaction_lines.normal_tax_* + applied_tax_source
pos_transactions.normal_tax_cents
```

### Services

```text
Pos::TaxRecalculator
Pos::TaxExceptionApplicationService (transaction scope)
Pos::VoidTaxException
Pos::LineTaxSnapshot.apply_normal! / apply_final!
```

### POS UI

* Transaction tax exemption panel in adjustments sidebar
* Receipt exemption reason/certificate footer

### Setup

* Tax exception reasons CRUD at `/setup/tax_exception_reasons`

## Verification

See [phase-8.5-2a-test-plan.md](../specifications/phase-8.5-2a-test-plan.md).

## Deferred to 8.5-2b

* Line tax category override UI and `pos_line_tax_overrides`

## Related documents

* [phase-8.5-2a-pos-tax-exemption-spec.md](../specifications/phase-8.5-2a-pos-tax-exemption-spec.md)
* [phase-8.5-2a-data-model.md](../specifications/phase-8.5-2a-data-model.md)
* [phase-8.5-2_pos_tax_exemption_tracking.md](../roadmap/phase-8.5-2_pos_tax_exemption_tracking.md)
