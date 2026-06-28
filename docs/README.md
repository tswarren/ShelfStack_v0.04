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

**Phases 1–9b and Phase 10-A/10-B are implemented.** See completion records under [implementation/](implementation/). **Current priority:** Phase 10-C (POS keyboard workspace).

```text
Implemented: Phases 1–8, 6.5, 7A–7C, 8.5 slices, 9a/9b, 10-A, 10-B
Current:     Phase 10-C
Deferred:    Phase 9c
```

**Items** (`/items`) is the operational workspace for catalog/product/variant workflows; **Setup** (`/setup`) holds admin reference data; **Inventory** (`/inventory`) and **Orders** (`/orders`) cover Phase 4–5 workflows.

---

## Implementation Status

| Phase | Documentation | Implementation record |
| ----- | ------------- | --------------------- |
| Phase 1 | Complete | [implementation/phase-1-completion.md](implementation/phase-1-completion.md) |
| Phase 2 | Complete | [implementation/phase-2-completion.md](implementation/phase-2-completion.md) |
| Phase 3 | Complete | [implementation/phase-3-completion.md](implementation/phase-3-completion.md) |
| Phase 4 | Complete | [implementation/phase-4-completion.md](implementation/phase-4-completion.md) |
| Phase 5 | Complete | [implementation/phase-5-completion.md](implementation/phase-5-completion.md) |
| Phase 6 | Complete | [implementation/phase-6-completion.md](implementation/phase-6-completion.md) |
| Phase 6.5 | Complete | [implementation/phase-6.5-completion.md](implementation/phase-6.5-completion.md) |
| Phase 7A | Complete | [implementation/phase-7a-completion.md](implementation/phase-7a-completion.md) |
| Phase 7B | Complete | [implementation/phase-7b-2-completion.md](implementation/phase-7b-2-completion.md), [phase-7b-3-completion.md](implementation/phase-7b-3-completion.md) |
| Phase 7C | Complete | [implementation/phase-7c-completion.md](implementation/phase-7c-completion.md) |
| Phase 8 | Complete | [implementation/phase-8-1-8-2-completion.md](implementation/phase-8-1-8-2-completion.md), [phase-8-3-4-5-completion.md](implementation/phase-8-3-4-5-completion.md) |
| Phase 8.5 | Complete (see slice records) | `implementation/phase-8.5-*-completion.md` |
| Phase 9a / 9b | Complete | [implementation/phase-9a-completion.md](implementation/phase-9a-completion.md), [phase-9b-completion.md](implementation/phase-9b-completion.md) |
| Phase 9c | Deferred | [roadmap/phase-9c-gl-shaped-financial-layer.md](roadmap/phase-9c-gl-shaped-financial-layer.md) |
| Phase 10-A | Complete | [implementation/phase-10a-completion.md](implementation/phase-10a-completion.md) |
| Phase 10-B | Complete | [implementation/phase-10b-completion.md](implementation/phase-10b-completion.md) |
| Phase 10-C | In progress (slices 1–7) | [implementation/phase-10c-completion.md](implementation/phase-10c-completion.md), [roadmap/phase-10c-pos-keyboard-workspace.md](roadmap/phase-10c-pos-keyboard-workspace.md) |

Operational tasks (login, workstation assignment, PIN/password onboarding, sessions, admin recovery, POS register basics): [operations/foundation-runbook.md](operations/foundation-runbook.md). Phase 10-C POS command UX is partially shipped — see [implementation/phase-10c-completion.md](implementation/phase-10c-completion.md); runbook POS section refresh deferred to slice 10.

Classification CSV seeds: [implementation/csv-seeds.md](implementation/csv-seeds.md), [specifications/seed-data-spec.md](specifications/seed-data-spec.md).

Test coverage matrix: [implementation/phase-1-test-coverage.md](implementation/phase-1-test-coverage.md).

---

## General Documents

| Document | Purpose |
| -------- | ------- |
| [overview.md](overview.md) | High-level explanation of ShelfStack |
| [domain-model.md](domain-model.md) | Core business concepts and relationships |
| [architecture.md](architecture.md) | Technical architecture and service structure |
| [architecture-map.md](architecture-map.md) | Domain → tables → services → workspace quick map |
| [security.md](security.md) | Auth, permissions, sessions, audit overview |
| [testing.md](testing.md) | Test strategy and phase test plan index |
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
| [roadmap/phase-2-departments-categories-taxes.md](roadmap/phase-2-departments-categories-taxes.md) | Departments, subdepartments, tax categories, store tax rates |
| [roadmap/phase-3-catalog-products-variants.md](roadmap/phase-3-catalog-products-variants.md) | Catalog items, products, variants, SKUs, vendors |
| [roadmap/phase-4-inventory-foundation.md](roadmap/phase-4-inventory-foundation.md) | Inventory ledger, balances, adjustments, valuation |
| [roadmap/phase-5-purchasing-and-receiving.md](roadmap/phase-5-purchasing-and-receiving.md) | Purchasing, receiving, RTV |
| [roadmap/phase-6-pos-foundation.md](roadmap/phase-6-pos-foundation.md) | Register sessions, POS transactions, voids, receipts |
| [roadmap/phase-7a-customer-demand.md](roadmap/phase-7a-customer-demand.md) | Customer requests, special orders, holds, pickup |
| [roadmap/phase-7b-customer-credit-foundation.md](roadmap/phase-7b-customer-credit-foundation.md) | POS settlement, stored value, gift cards |
| [roadmap/phase-7c-used-buyback.md](roadmap/phase-7c-used-buyback.md) | Buyback sessions, trade credit, used inventory |
| [roadmap/phase-8-inventory-eligibility-and-tracking-refactor.md](roadmap/phase-8-inventory-eligibility-and-tracking-refactor.md) | Inventory tracking resolver and eligibility |
| [roadmap/phase-9-reporting-and-accounting.md](roadmap/phase-9-reporting-and-accounting.md) | Reporting UX (9a), operational reports (9b), GL layer (9c deferred) |
| [roadmap/Phase-x10-comprehensive-ux-expansion.md](roadmap/Phase-x10-comprehensive-ux-expansion.md) | Phase 10 parent: interaction infra, items, POS, workflow polish |
| [roadmap/phase-10a-interaction-infrastructure.md](roadmap/phase-10a-interaction-infrastructure.md) | Shared modals, drawers, focus, toasts |
| [roadmap/phase-10b-item-cockpit-completion.md](roadmap/phase-10b-item-cockpit-completion.md) | Item cockpit modals and operations drawer |
| [roadmap/phase-10c-pos-keyboard-workspace.md](roadmap/phase-10c-pos-keyboard-workspace.md) | **Current:** keyboard-first POS workspace |

Visual mockups (inspiration only): [samples/phase-10-mockups/](samples/phase-10-mockups/)

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

### Phase 5: Purchasing and Receiving

| Document | Purpose |
| -------- | ------- |
| [specifications/phase-5-purchasing-and-receiving-spec.md](specifications/phase-5-purchasing-and-receiving-spec.md) | PO, receiving, RTV, returnability |
| [specifications/phase-5-data-model.md](specifications/phase-5-data-model.md) | Phase 5 tables, indexes, constraints |
| [specifications/phase-5-test-plan.md](specifications/phase-5-test-plan.md) | Required Phase 5 test coverage |

### Phase 6: POS Foundation

| Document | Purpose |
| -------- | ------- |
| [specifications/phase-6-pos-foundation-spec.md](specifications/phase-6-pos-foundation-spec.md) | Register sessions, transactions, tax, tenders, voids, receipts |
| [specifications/phase-6-data-model.md](specifications/phase-6-data-model.md) | Phase 6 `pos_*` tables and inventory posting types |
| [specifications/phase-6-test-plan.md](specifications/phase-6-test-plan.md) | Required Phase 6 test coverage |

### Phases 7–9 (index)

Later phases follow the `{spec, data-model, test-plan}` pattern. Primary entry points:

| Phase | Spec | Data model | Test plan |
| ----- | ---- | ---------- | --------- |
| 7A Customer demand | [phase-7a-customer-demand-spec.md](specifications/phase-7a-customer-demand-spec.md) | [phase-7a-data-model.md](specifications/phase-7a-data-model.md) | [phase-7a-test-plan.md](specifications/phase-7a-test-plan.md) |
| 7B Stored value / settlement | [phase-7b-stored-value-spec.md](specifications/phase-7b-stored-value-spec.md), [phase-7b-pos-settlement-spec.md](specifications/phase-7b-pos-settlement-spec.md) | [phase-7b-data-model.md](specifications/phase-7b-data-model.md) | [phase-7b-test-plan.md](specifications/phase-7b-test-plan.md) |
| 7C Buyback | [phase-7c-used-buyback-spec.md](specifications/phase-7c-used-buyback-spec.md) | [phase-7c-data-model.md](specifications/phase-7c-data-model.md) | [phase-7c-test-plan.md](specifications/phase-7c-test-plan.md) |
| 8 Inventory tracking | [phase-8-inventory-eligibility-and-tracking-spec.md](specifications/phase-8-inventory-eligibility-and-tracking-spec.md) | [phase-8-data-model.md](specifications/phase-8-data-model.md) | [phase-8-test-plan.md](specifications/phase-8-test-plan.md) |
| 8.5-* | See `specifications/phase-8.5-*-spec.md` | See `specifications/phase-8.5-*-data-model.md` | See `specifications/phase-8.5-*-test-plan.md` |
| 9a Report UX | [phase-9a-ux-foundation-for-reporting-spec.md](specifications/phase-9a-ux-foundation-for-reporting-spec.md) | (minimal new tables) | [phase-9a-test-plan.md](specifications/phase-9a-test-plan.md) |
| 9b Operational reports | [phase-9b-operational-reports-spec.md](specifications/phase-9b-operational-reports-spec.md) | (reads operational data) | [phase-9b-test-plan.md](specifications/phase-9b-test-plan.md) |
| 9c GL layer | [phase-9c-gl-shaped-financial-layer.md](roadmap/phase-9c-gl-shaped-financial-layer.md) | Deferred | — |

See [roadmap.md](roadmap.md) for the full phase index and completion records under [implementation/](implementation/).

### Phase 10: Comprehensive UI/UX Expansion

Parent roadmap: [roadmap/Phase-x10-comprehensive-ux-expansion.md](roadmap/Phase-x10-comprehensive-ux-expansion.md). Delivery order: 10-A → 10-B → 10-C → 10-D → 10-E.

| Sub-phase | Status | Roadmap | Spec | Test plan |
| --------- | ------ | ------- | ---- | --------- |
| 10-A Interaction infrastructure | Complete | [phase-10a-interaction-infrastructure.md](roadmap/phase-10a-interaction-infrastructure.md) | [phase-10a-interaction-infrastructure-spec.md](specifications/phase-10a-interaction-infrastructure-spec.md) | [phase-10a-test-plan.md](specifications/phase-10a-test-plan.md) |
| 10-B Item cockpit | Complete | [phase-10b-item-cockpit-completion.md](roadmap/phase-10b-item-cockpit-completion.md) | [phase-10b-item-cockpit-spec.md](specifications/phase-10b-item-cockpit-spec.md) | [phase-10b-test-plan.md](specifications/phase-10b-test-plan.md) |
| 10-C POS keyboard workspace | **In progress** (slices 1–7) | [phase-10c-pos-keyboard-workspace.md](roadmap/phase-10c-pos-keyboard-workspace.md) | [phase-10c-pos-keyboard-workspace-spec.md](specifications/phase-10c-pos-keyboard-workspace-spec.md) | [phase-10c-test-plan.md](specifications/phase-10c-test-plan.md) |

Cross-cutting Phase 10 UX documents:

| Document | Purpose |
| -------- | ------- |
| [specifications/view-contracts.md](specifications/view-contracts.md) | Per-screen-type behavior contracts |
| [specifications/keyboard-and-focus.md](specifications/keyboard-and-focus.md) | Global keyboard and focus standards |
| [specifications/modal-and-drawer-patterns.md](specifications/modal-and-drawer-patterns.md) | Shared overlay patterns |
| [specifications/ui-components.md](specifications/ui-components.md) | Reusable interaction components |
| [specifications/pos-keyboard-workspace.md](specifications/pos-keyboard-workspace.md) | POS UX supplement for 10-C |

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
