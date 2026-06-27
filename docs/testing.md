# ShelfStack Testing Overview

Test strategy and index of phase test plans. Conventions: [implementation-guide.md](implementation-guide.md).

---

## Test layers

| Layer | Tool | Use for |
| ----- | ---- | ------- |
| Unit / service | Minitest | Business rules, validators, calculators, registry objects |
| Model | Minitest | Validations, scopes, controlled values |
| Integration | Minitest + Rails | Controllers, request/response, Turbo targets, permissions |
| System | Capybara + Minitest | End-to-end workflows, focus/keyboard behavior where practical |

Run full suite: `./dev/rails-docker bin/rails test`

---

## What to always test

* Permission checks and store-scoped access
* Audit event creation on mutating workflows
* Seed idempotency (`rails shelfstack:seeds:validate`, re-run seeds)
* Controlled value validation and deletion/inactivation rules
* Service-layer business rules (prefer service tests over controller-only coverage)

---

## Phase test plans

| Phase | Test plan |
| ----- | --------- |
| 1 | [phase-1-test-plan.md](specifications/phase-1-test-plan.md) |
| 2 | [phase-2-test-plan.md](specifications/phase-2-test-plan.md) |
| 3 | [phase-3-test-plan.md](specifications/phase-3-test-plan.md) |
| 4 | [phase-4-test-plan.md](specifications/phase-4-test-plan.md) |
| 5 | [phase-5-test-plan.md](specifications/phase-5-test-plan.md) |
| 6 | [phase-6-test-plan.md](specifications/phase-6-test-plan.md) |
| 7A | [phase-7a-test-plan.md](specifications/phase-7a-test-plan.md) |
| 7B | [phase-7b-test-plan.md](specifications/phase-7b-test-plan.md) |
| 7C | [phase-7c-test-plan.md](specifications/phase-7c-test-plan.md) |
| 8 | [phase-8-test-plan.md](specifications/phase-8-test-plan.md) |
| 8.5-* | See `specifications/phase-8.5-*-test-plan.md` |
| 9a / 9b | [phase-9a-test-plan.md](specifications/phase-9a-test-plan.md), [phase-9b-test-plan.md](specifications/phase-9b-test-plan.md) |
| 10-A / 10-B / 10-C | [phase-10a-test-plan.md](specifications/phase-10a-test-plan.md), [phase-10b-test-plan.md](specifications/phase-10b-test-plan.md), [phase-10c-test-plan.md](specifications/phase-10c-test-plan.md) |

Completion records under [implementation/](implementation/) list verification steps per phase.

---

## Domain regression guardrails

When changing shared components or POS behavior, regression-test:

* **Inventory:** `Inventory::Post` idempotency; balance equals ledger sum; eligibility gate
* **POS:** completion, void, partial returns, tender validation, inventory posting eligibility
* **Stored value:** append-only ledger, balance cap on redemption, void reversals
* **Discounts / tax:** `Pos::DiscountRecalculator`, `Pos::TaxRecalculator`, sourced return lines preserved
* **Buyback:** staged workflow, completion/void inventory posting

---

## POS and command registry (Phase 10-C)

* Prefer **service tests** for `Pos::LandingRouter`, `Pos::ActiveDraftResolver`, and `Pos::CommandRegistry` (permission, state, alias normalization).
* Use **integration/system tests** for idle workspace landing, draft stamping, and parser intent boundary.
* Do not rely on Stimulus-only tests for command routing — Ruby registry is authoritative.

See [phase-10c-test-plan.md](specifications/phase-10c-test-plan.md).

---

## Interaction infrastructure (Phase 10-A)

* Modal/drawer focus trap and restore; dirty guard; overlay stack
* Test fixture: `/test/interaction_shell` (test env only)

See [phase-10a-test-plan.md](specifications/phase-10a-test-plan.md).

---

## Related

```text
docs/implementation/phase-1-test-coverage.md
docs/implementation-guide.md  (sections 7–7.4)
AGENTS.md  (Testing Expectations)
```
