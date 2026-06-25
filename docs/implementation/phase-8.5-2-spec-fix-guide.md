# Phase 8.5-2 Spec Fix Guide

Use this guide when fixing failing specs, request tests, or documentation examples for **Phase 8.5-2 POS tax exception tracking** (8.5-2a exemption + 8.5-2b line override).

---

## 1. Pos::TenderValidator — `actor:` required

**Before (broken):**

```ruby
Pos::TenderValidator.call(
  pos_transaction: pos_transaction,
  tender_type: "cash",
  amount_cents: 1000,
  tendered_cents: 1000,
  reference_number: nil
)
```

**After (correct):**

```ruby
Pos::TenderValidator.call(
  pos_transaction: pos_transaction,
  tender_type: "cash",
  amount_cents: 1000,
  tendered_cents: 1000,
  reference_number: nil,
  actor: current_user
)
```

**Why:** `Pos::TenderValidator` requires `actor:` for permission checks (e.g. `pos.tenders.cash`). Without it, the call raises `ArgumentError: missing keyword: :actor`.

**Files to update:** Any spec that calls `Pos::TenderValidator.call` without `actor:` — grep for `Pos::TenderValidator.call` and add `actor:` (typically `actor: user` or `actor: current_user` depending on context).

---

## 2. Pos::CompleteTransaction — `user_session:` required

**Before (broken):**

```ruby
Pos::CompleteTransaction.call(
  pos_transaction: pos_transaction,
  register_session: register_session,
  actor: user,
  store: store,
  workstation: workstation
)
```

**After (correct):**

```ruby
Pos::CompleteTransaction.call(
  pos_transaction: pos_transaction,
  register_session: register_session,
  actor: user,
  store: store,
  workstation: workstation,
  user_session: user_session
)
```

**Why:** `Pos::CompleteTransaction` requires `user_session:` for audit/session context. Omitting it raises `ArgumentError: missing keyword: :user_session`.

**Files to update:** Any spec that completes a POS transaction — grep for `Pos::CompleteTransaction.call` and ensure both `actor:` and `user_session:` are passed.

---

## 3. Pos::TaxExceptionApplicationService — transaction scope needs `store:`

**Before (broken for transaction-level exemption):**

```ruby
Pos::TaxExceptionApplicationService.call(
  pos_transaction: pos_transaction,
  scope: "transaction",
  tax_exception_reason: reason,
  actor: user,
  user_session: user_session,
  workstation: workstation
)
```

**After (correct):**

```ruby
Pos::TaxExceptionApplicationService.call(
  pos_transaction: pos_transaction,
  scope: "transaction",
  tax_exception_reason: reason,
  actor: user,
  user_session: user_session,
  store: store,
  workstation: workstation
)
```

**Why:** Transaction-scope exemption recalculation uses store context for `TaxRateLookup`. Line-scope override also needs store for rate resolution.

**Note:** Some older examples may show `scope: :transaction` (symbol). The service accepts string `"transaction"` / `"line"` — use strings for consistency with controller params.

---

## 4. Pos tax exception request specs — session + workstation setup

Integration/request specs for `apply_tax_exemption`, `void_tax_exemption`, `apply_line_tax_override`, and `void_line_tax_override` need the same POS session plumbing as other POS controller tests:

- Logged-in user with appropriate permissions (`pos.tax_exemptions.apply`, `pos.tax_exemptions.void`, `pos.line_tax_overrides.apply`, `pos.line_tax_overrides.void`)
- Active `user_session` with store context
- Workstation token / assignment (see existing POS request spec helpers)
- Open register session tied to the transaction's store and business date
- Draft `pos_transaction` on that register session

**Pattern:** Copy setup from existing POS controller/integration tests rather than inventing minimal stubs.

---

## 5. Factory / fixture gaps for tax exception tests

| Need | Typical setup |
|------|----------------|
| `TaxExceptionReason` | Seed or create with stable `reason_key`; set `requires_note` / approval flags as scenario requires |
| Store tax rate | `store_tax_category_rates` effective on transaction `business_date` for line subdepartment's tax category |
| Line override | Second tax category + rate if testing category change |
| Permissions | User with role granting tax exception keys (see `db/seeds/phase852_permissions.rb`) |

**Return line tests:** Sourced returns with `applied_tax_source: sourced_return` must not be recalculated by `Pos::TaxRecalculator` — use fixtures that mirror `Pos::ReturnLinePricing` output.

---

## 6. Quick verification commands

```bash
# Targeted tax exception tests
./dev/rails-docker bin/rails test \
  test/models/tax_exception_reason_test.rb \
  test/models/pos_tax_exemption_test.rb \
  test/models/pos_line_tax_override_test.rb \
  test/services/pos/tax_recalculator_test.rb \
  test/services/pos/tax_exception_application_service_test.rb \
  test/services/pos/void_tax_exception_test.rb \
  test/services/pos/line_tax_override_integration_test.rb

# POS recalc regression
./dev/rails-docker bin/rails test test/services/pos/recalculate_transaction_test.rb

# After adding request/integration specs
./dev/rails-docker bin/rails test test/integration/pos_tax_exemption_workspace_test.rb
```

---

## 7. Checklist before opening / updating PR

- [ ] All `Pos::TenderValidator.call` invocations include `actor:`
- [ ] All `Pos::CompleteTransaction.call` invocations include `user_session:`
- [ ] Transaction tax exemption tests pass `store:` (and workstation where applicable)
- [ ] Migrations applied: `./dev/rails-docker bin/rails db:migrate`
- [ ] Seeds load for permissions/reasons: `./dev/rails-docker bin/rails db:seed` (or test helpers create reasons inline)
- [ ] No duplicate `add_index` on FK columns already indexed by `t.references`
- [ ] AGENTS.md / completion docs updated if behavior changed

---

## Related docs

- `docs/specifications/phase-8.5-2a-pos-tax-exemption-spec.md`
- `docs/specifications/phase-8.5-2b-pos-line-tax-override-spec.md`
- `docs/implementation/phase-8.5-2a-completion.md`
- `docs/implementation/phase-8.5-2b-completion.md`
- `docs/roadmap/phase-8.5-2_pos_tax_exemption_tracking.md`
