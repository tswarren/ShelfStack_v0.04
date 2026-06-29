# ShelfStack v0.04 — Documentation

**ShelfStack v0.04 is the core domain model** for the application — products, identifiers, variants, demand, sourcing, and receiving. This folder holds milestone-specific specs as implementation proceeds.

---

## Start here

| Document | Role |
| -------- | ---- |
| [Core domain model](../design/VERSION_0.04.md) | Authoritative design — what v0.04 *is* |
| [Delivery roadmap](../roadmap/v0.04-delivery-roadmap.md) | Milestones, dependencies, preserve vs replace |
| [v0.03 phase index](../roadmap/README.md) | Historical Phases 1–10 (built the pre-v0.04 codebase) |

**Current priority:** milestone v0.04-0 baseline, then v0.04-1 product fusion and v0.04-2 identifiers.

---

## Milestone documents

Create each bundle when a milestone is scoped:

```text
docs/v0.04/
  v0.04-1-product-fusion/
    spec.md
    data-model.md
    test-plan.md
  v0.04-2-product-identifiers/
    ...
```

| Milestone | Status | Spec bundle |
| --------- | ------ | ------------- |
| v0.04-0 Baseline | Planned | — (delivery roadmap only) |
| v0.04-1 Product fusion | Planned | *(not yet created)* |
| v0.04-2 Product identifiers | Planned | *(not yet created)* |
| v0.04-3 Product groups | Planned | *(not yet created)* |
| v0.04-4 Wire-through | Planned | *(not yet created)* |
| v0.04-5 Used variant rules | Planned | *(not yet created)* |
| v0.04-6 Demand foundation | Planned | *(not yet created)* |
| v0.04-7 Allocations | Planned | *(not yet created)* |
| v0.04-8 Sourcing | Planned | *(not yet created)* |
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
