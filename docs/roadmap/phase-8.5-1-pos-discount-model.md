# Phase 8.5-1 Roadmap — POS Discount Model & Calculation

**Status:** In review (branch `phase-8.5-operational-cleanup`)

Normative behavior, services, and UI rules live in the functional spec. This roadmap is a short orientation only.

## Purpose

Make POS discounts structured, auditable, stackable, and report-ready before Phase 9 reporting. Preserve cached aggregate cents on transactions and lines for register and report compatibility.

## In scope

1. Discount reasons (Setup CRUD + seeds)
2. Discount applications and allocations
3. Stacking via `stack_order`
4. Non-discountable eligibility (catalog flags + system rules)
5. Gift card sale exclusion
6. POS line and transaction discount UI (`/d`, `/dt`)
7. Legacy bridge and historical backfill

## Out of scope

Promotion/coupon/loyalty engines, full discount activity report UI, tax exceptions (Phase 8.5-2), tender/customer cleanup (Phase 8.5-3).

## Documents

| Document | Role |
| --- | --- |
| [phase-8.5-1-pos-discount-spec.md](../specifications/phase-8.5-1-pos-discount-spec.md) | Functional specification |
| [phase-8.5-1-data-model.md](../specifications/phase-8.5-1-data-model.md) | Schema and constraints |
| [phase-8.5-1-test-plan.md](../specifications/phase-8.5-1-test-plan.md) | Test coverage |
| [phase-8.5-1-completion.md](../implementation/phase-8.5-1-completion.md) | Deliverables and verification |

Related umbrella: [phase-8.5-operational-cleanup.md](phase-8.5-operational-cleanup.md)
