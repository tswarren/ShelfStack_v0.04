# Phase 8.5-2b Test Plan — POS Line Tax Override

```bash
./dev/rails-docker bin/rails test test/models/pos_line_tax_override_test.rb test/services/pos/line_tax_override_integration_test.rb
```

## Scenarios

| Scenario | Expected |
|----------|----------|
| Line override to zero-rate category | normal preserved; final uses override; `line_override` |
| Override + transaction exemption | final tax zero; both audit records kept |
| Gift card / sourced return | override rejected |
| Missing tax mapping for category | service error at apply |
