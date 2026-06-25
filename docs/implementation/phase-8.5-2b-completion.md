# Phase 8.5-2b — Completion Record

**Status:** In review

## Summary

Phase 8.5-2b adds line-level tax category override with rate resolution via `TaxRateLookup`, extending the 8.5-2a tax exception foundation.

## Deliverables

### Schema

```text
pos_line_tax_overrides
applied_tax_source includes line_override
```

### Services

* `Pos::TaxExceptionApplicationService` line scope
* `Pos::VoidTaxException` for `PosLineTaxOverride`
* `Pos::TaxRecalculator` override branch (normal → override → exemption)

### POS UI

* Line tax override form in cart line edit row

## Verification

See [phase-8.5-2b-test-plan.md](../specifications/phase-8.5-2b-test-plan.md).

## Related documents

* [phase-8.5-2b-pos-line-tax-override-spec.md](../specifications/phase-8.5-2b-pos-line-tax-override-spec.md)
* [phase-8.5-2a-completion.md](phase-8.5-2a-completion.md)
