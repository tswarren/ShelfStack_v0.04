# ShelfStack v0.04 — Documentation

**ShelfStack v0.04 is the core domain model** for the application — products, identifiers, variants, demand, sourcing, and receiving. This folder holds milestone-specific specs as implementation proceeds.

---

## Start here

| Document | Role |
| -------- | ---- |
| [Core domain model](../design/VERSION_0.04.md) | Authoritative design — what v0.04 *is* |
| [Delivery roadmap](../roadmap/v0.04-delivery-roadmap.md) | Milestones, dependencies, preserve vs replace |
| [v0.03 phase index](../roadmap/README.md) | Historical Phases 1–10 (built the pre-v0.04 codebase) |

**Current priority:** milestone **v0.04-8** sourcing and vendor responses. **v0.04-3** product groups remains **deferred**.

---

## Milestone documents

Each milestone bundle lives under `docs/v0.04/<milestone>/` with `spec.md`, `data-model.md`, and `test-plan.md` when scoped.

| Milestone | Status | Spec bundle |
| --------- | ------ | ------------- |
| v0.04-0 Baseline | **Complete** | [v0.04-0 completion](../implementation/v0.04-0-completion.md) |
| v0.04-1 Product fusion | **Complete** | [spec](v0.04-1-product-fusion/spec.md) · [data model](v0.04-1-product-fusion/data-model.md) · [test plan](v0.04-1-product-fusion/test-plan.md) · [completion](../implementation/v0.04-1-completion.md) |
| v0.04-2 Product identifiers | **Complete** | [spec](v0.04-2-product-identifiers/spec.md) · [data model](v0.04-2-product-identifiers/data-model.md) · [test plan](v0.04-2-product-identifiers/test-plan.md) · [completion](../implementation/v0.04-2-completion.md) |
| v0.04-3 Product groups | **Deferred** | Roadmap only — see [delivery roadmap](../roadmap/v0.04-delivery-roadmap.md) |
| v0.04-4 Wire-through | **Complete** | [spec](v0.04-4-variant-grain-wire-through/spec.md) · [data model](v0.04-4-variant-grain-wire-through/data-model.md) · [test plan](v0.04-4-variant-grain-wire-through/test-plan.md) · [completion](../implementation/v0.04-4-completion.md) |
| v0.04-5 Used variant rules | **Complete** | [spec](v0.04-5-used-variant-rules/spec.md) · [data model](v0.04-5-used-variant-rules/data-model.md) · [test plan](v0.04-5-used-variant-rules/test-plan.md) · [completion](../implementation/v0.04-5-completion.md) |
| v0.04-6 Demand foundation | **Complete** | [spec](v0.04-6-demand-foundation/spec.md) · [data model](v0.04-6-demand-foundation/data-model.md) · [test plan](v0.04-6-demand-foundation/test-plan.md) · [completion](../implementation/v0.04-6-completion.md) |
| v0.04-7 Allocations | **Complete** | [spec](v0.04-7-allocations-and-reservations/spec.md) · [data model](v0.04-7-allocations-and-reservations/data-model.md) · [test plan](v0.04-7-allocations-and-reservations/test-plan.md) · [completion](../implementation/v0.04-7-completion.md) |
| v0.04-8 Sourcing | **In progress** (Slice A/B on branch) | [spec](v0.04-8-sourcing-and-vendor-responses/spec.md) · [data model](v0.04-8-sourcing-and-vendor-responses/data-model.md) · [test plan](v0.04-8-sourcing-and-vendor-responses/test-plan.md) |
| v0.04-9 PO/receiving quantities | Planned | *(not yet created)* |
| v0.04-10 Retire v0.03 ordering UI | Planned | *(not yet created)* |
| v0.04-11 Doc and schema cleanup | Planned | *(not yet created)* |

---

## v0.03 reference (historical)

These describe the **current codebase** until v0.04 milestones replace each area:

| Topic | v0.03 documents |
| ----- | ---------------- |
| Catalog / products | [phase-3 spec](../specifications/phase-3-catalog-products-variants-spec.md), [phase-3 data model](../specifications/phase-3-data-model.md) |
| Customer demand | [phase-7a spec](../specifications/phase-7a-customer-demand-spec.md), [phase-7a data model](../specifications/phase-7a-data-model.md) |
| Order handling | [phase-8.5-3a spec](../specifications/phase-8.5-3a-order-handling-readiness-spec.md) |

Do not extend v0.03 catalog-item or customer-request patterns for new work.
