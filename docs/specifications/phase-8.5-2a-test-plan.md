# Phase 8.5-2a Test Plan — POS Transaction Tax Exemption

Spec: [phase-8.5-2a-pos-tax-exemption-spec.md](phase-8.5-2a-pos-tax-exemption-spec.md)

## Verification

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails test test/models/tax_exception_reason_test.rb test/models/pos_tax_exemption_test.rb
./dev/rails-docker bin/rails test test/services/pos/tax_recalculator_test.rb test/services/pos/tax_exception_application_service_test.rb test/services/pos/void_tax_exception_test.rb
./dev/rails-docker bin/rails test test/services/pos/recalculate_transaction_test.rb test/services/pos/return_line_pricing_test.rb test/services/pos/line_tax_snapshot_test.rb
```

## Scenarios

| Scenario | Expected |
|----------|----------|
| Normal taxable sale | normal and final tax match; `applied_tax_source = normal` |
| Transaction exemption | normal preserved; final tax zero; `transaction_exemption` |
| Gift card line | zero tax; `non_taxable`; not exemption-eligible |
| Sourced return | prorated applied + normal tax; `sourced_return` |
| Discount before tax | tax on discounted extended price |
| Void exemption | final tax restores to normal |
| Certificate required | blank certificate rejected |
| Completed transaction | exemption records immutable |
