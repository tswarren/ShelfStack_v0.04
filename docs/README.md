# ShelfStack Documentation

This directory contains the primary documentation for ShelfStack.

ShelfStack is a bookstore-focused catalog, inventory, stock, and point-of-sale management system. Documentation is organized by concept, roadmap, and phase-specific specifications.

---

## Suggested Reading Order

### New to the project

1. [overview.md](overview.md) — what ShelfStack is and who it is for
2. [domain-model.md](domain-model.md) — core business concepts and relationships
3. [roadmap.md](roadmap.md) — phase-by-phase development plan
4. [glossary.md](glossary.md) — recurring domain terms

### Implementing a feature

1. Relevant phase roadmap in [roadmap/](roadmap/)
2. Functional specification in [specifications/](specifications/)
3. Data model in [specifications/](specifications/)
4. Test plan in [specifications/](specifications/)
5. [implementation-guide.md](implementation-guide.md) — conventions and patterns
6. [architecture.md](architecture.md) — services, context, and layering

### Working on schema or migrations

1. Phase data model document (source of truth for that phase)
2. [schema-reference.md](schema-reference.md) — index across all phases

### AI coding agents

Read [../AGENTS.md](../AGENTS.md) first, then the phase documents relevant to the task.

**Phases 1–3 are implemented.** See completion records under [implementation/](implementation/). **Items** (`/items`) is the operational workspace for catalog/product/variant workflows; **Setup** (`/setup`) holds admin reference data (formats, conditions, tax, users, etc.). **Phase 4** (inventory foundation) is in progress — see [roadmap/phase-4-inventory-foundation.md](roadmap/phase-4-inventory-foundation.md) and [specifications/phase-4-inventory-foundation-spec.md](specifications/phase-4-inventory-foundation-spec.md).

---

## Implementation Status

| Phase | Documentation | Implementation record |
| ----- | ------------- | --------------------- |
| Phase 1 | Complete | [implementation/phase-1-completion.md](implementation/phase-1-completion.md) |
| Phase 2 | Complete | [implementation/phase-2-completion.md](implementation/phase-2-completion.md) |
| Phase 3 | Complete | [implementation/phase-3-completion.md](implementation/phase-3-completion.md) |

Operational tasks (login, workstation assignment, PIN/password onboarding, sessions, admin recovery): [operations/foundation-runbook.md](operations/foundation-runbook.md).

Classification CSV seeds: [implementation/csv-seeds.md](implementation/csv-seeds.md), [specifications/seed-data-spec.md](specifications/seed-data-spec.md).

Test coverage matrix: [implementation/phase-1-test-coverage.md](implementation/phase-1-test-coverage.md).

---

## General Documents

| Document | Purpose |
| -------- | ------- |
| [overview.md](overview.md) | High-level explanation of ShelfStack |
| [domain-model.md](domain-model.md) | Core business concepts and relationships |
| [architecture.md](architecture.md) | Technical architecture and service structure |
| [roadmap.md](roadmap.md) | Full development roadmap including future phases |
| [implementation-guide.md](implementation-guide.md) | Developer conventions, naming, seeds, testing |
| [implementation/csv-seeds.md](implementation/csv-seeds.md) | CSV classification seed pipeline and validation |
| [specifications/seed-data-spec.md](specifications/seed-data-spec.md) | CSV column definitions and FK rules |
| [implementation/classification-cleanup.md](implementation/classification-cleanup.md) | Classification simplification (categories removed) |
| [glossary.md](glossary.md) | Definitions of recurring domain terms |
| [schema-reference.md](schema-reference.md) | Schema index assembled from phase data models |
| [implementation/phase-1-completion.md](implementation/phase-1-completion.md) | Phase 1 sign-off: delivered scope, gaps, verification |
| [implementation/phase-1-test-coverage.md](implementation/phase-1-test-coverage.md) | Phase 1 automated test mapping |
| [operations/foundation-runbook.md](operations/foundation-runbook.md) | Phase 1 operational procedures |

---

## Phase Roadmaps

| Document | Phase focus |
| -------- | ----------- |
| [roadmap/phase-1-foundation.md](roadmap/phase-1-foundation.md) | Users, roles, permissions, stores, workstations, sessions, audit |
| [roadmap/phase-2-departments-categories-taxes.md](roadmap/phase-2-departments-categories-taxes.md) | Departments, categories, tax categories, store tax rates |
| [roadmap/phase-3-catalog-products-variants.md](roadmap/phase-3-catalog-products-variants.md) | Catalog items, products, variants, SKUs, vendors |
| [roadmap/phase-4-inventory-foundation.md](roadmap/phase-4-inventory-foundation.md) | Inventory ledger, balances, adjustments, valuation |

---

## Phase Specifications

Each phase has three companion documents: functional specification, data model, and test plan.

### Phase 1: Foundation

| Document | Purpose |
| -------- | ------- |
| [specifications/phase-1-foundation-spec.md](specifications/phase-1-foundation-spec.md) | Authentication, authorization, sessions, workstations, setup UI |
| [specifications/phase-1-data-model.md](specifications/phase-1-data-model.md) | Phase 1 tables, indexes, constraints, and seed data |
| [specifications/phase-1-test-plan.md](specifications/phase-1-test-plan.md) | Required Phase 1 test coverage |

### Phase 2: Classification and Taxes

| Document | Purpose |
| -------- | ------- |
| [specifications/phase-2-classification-and-tax-spec.md](specifications/phase-2-classification-and-tax-spec.md) | Departments, categories, tax setup, tax lookup |
| [specifications/phase-2-data-model.md](specifications/phase-2-data-model.md) | Phase 2 tables, indexes, constraints, and seed data |
| [specifications/phase-2-test-plan.md](specifications/phase-2-test-plan.md) | Required Phase 2 test coverage |

### Phase 3: Catalog, Products, and Variants

| Document | Purpose |
| -------- | ------- |
| [specifications/phase-3-catalog-products-variants-spec.md](specifications/phase-3-catalog-products-variants-spec.md) | Catalog items, identifiers, products, variants, SKUs |
| [specifications/phase-3-data-model.md](specifications/phase-3-data-model.md) | Phase 3 tables, indexes, constraints, and seed data |
| [specifications/phase-3-test-plan.md](specifications/phase-3-test-plan.md) | Required Phase 3 test coverage |

### Phase 4: Inventory Foundation

| Document | Purpose |
| -------- | ------- |
| [specifications/phase-4-inventory-foundation-spec.md](specifications/phase-4-inventory-foundation-spec.md) | Ledger, balances, adjustments, valuation, read surfaces |
| [specifications/phase-4-data-model.md](specifications/phase-4-data-model.md) | Phase 4 tables, indexes, constraints, and seed data |
| [specifications/phase-4-test-plan.md](specifications/phase-4-test-plan.md) | Required Phase 4 test coverage |

---

## Document Hierarchy

```text
overview / domain-model / architecture     ← concepts and structure
        ↓
roadmap.md + roadmap/phase-*.md            ← phase goals and scope
        ↓
specifications/phase-*-{spec,data-model,test-plan}.md   ← implementation detail
        ↓
schema-reference.md                        ← assembled schema index
```

A phase is not complete when tables exist. A phase is complete when behavior is implemented, permission-controlled, audited, seeded, tested, and documented.

**Phase 1 completion record:** [implementation/phase-1-completion.md](implementation/phase-1-completion.md)

---

## Related Files Outside docs/

| File | Purpose |
| ---- | ------- |
| [../README.md](../README.md) | Project entry point and quick start |
| [../DOCKER.md](../DOCKER.md) | Docker-based development setup |
| [../AGENTS.md](../AGENTS.md) | Guidance for AI coding agents |
