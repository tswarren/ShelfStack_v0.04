# ShelfStack Documentation

Navigation hub for ShelfStack docs.

---

## ShelfStack v0.04 core (active)

**v0.04 is the core domain model** — not another numbered phase. Phases 1–10 built the Rails codebase; v0.04 is the canonical architecture for products, demand, sourcing, and fulfillment.

| Start here | Purpose |
| ---------- | ------- |
| [design/VERSION_0.04.md](design/VERSION_0.04.md) | Core domain model (products, identifiers, demand, …) |
| [roadmap/v0.04-delivery-roadmap.md](roadmap/v0.04-delivery-roadmap.md) | Implementation milestones v0.04-0 … v0.04-12 |
| [v0.04/README.md](v0.04/README.md) | Milestone spec bundles and completion status |

**Current priority:**

```text
Complete: v0.04-0 through v0.04-11
Current:  v0.04-12 — demand ordering UX **complete on branch** (merge pending)
```

Phase 10-E (consistency sweep) is **paused** until v0.04-12 stabilizes.

---

## Active v0.04 guidance (canonical)

These documents describe the **current** implemented domain:

| Document | Purpose |
| -------- | ------- |
| [overview.md](overview.md) | Product overview and major domains |
| [domain-model.md](domain-model.md) | Entities, relationships, and v0.04 operational chain |
| [glossary.md](glossary.md) | Term definitions and retired v0.03 vocabulary |
| [schema-reference.md](schema-reference.md) | Curated schema index (authoritative detail: `db/schema.rb`) |
| [design/VERSION_0.04.md](design/VERSION_0.04.md) | Authoritative v0.04 design |
| [v0.04/README.md](v0.04/README.md) | Milestone specs and status |

---

## Reading paths

### New to the project

1. [overview.md](overview.md) — what ShelfStack is
2. [design/VERSION_0.04.md](design/VERSION_0.04.md) — **core domain model**
3. [domain-model.md](domain-model.md) — entities and relationships
4. [glossary.md](glossary.md) — domain terms

### Implementing v0.04 core

1. [design/VERSION_0.04.md](design/VERSION_0.04.md)
2. [roadmap/v0.04-delivery-roadmap.md](roadmap/v0.04-delivery-roadmap.md)
3. Milestone bundle under [v0.04/](v0.04/)
4. [implementation-guide.md](implementation-guide.md) — conventions

### Working on v0.03 code (historical)

1. [roadmap/README.md](roadmap/README.md) — Phases 1–10 index
2. [specifications/phase-*-{spec,data-model,test-plan}.md](specifications/) — **historical v0.03 implementation reference**
3. [implementation/phase-*-completion.md](implementation/)

Do not extend v0.03 customer-request, purchase-request, or inventory-reservation patterns. v0.04-10 retired those tables.

### AI coding agents

Read [../AGENTS.md](../AGENTS.md) first, then v0.04 core docs above.

---

## Folder map

```text
docs/
  README.md                 ← you are here
  design/                   ← v0.04 core domain model
  v0.04/                    ← milestone specs (v0.04-1 … v0.04-12)
  roadmap/                  ← v0.04 delivery roadmap + v0.03 phase roadmaps
  specifications/           ← v0.03 phase specs (historical reference)
  implementation/           ← completion records
  operations/               ← runbooks
  handoff/                  ← cross-cutting contracts
  samples/                  ← mockups, fixtures
  phases/                   ← redirect stub (use v0.04/ instead)
```

Legacy redirects: [VERSION_0.04.md](VERSION_0.04.md) → [design/VERSION_0.04.md](design/VERSION_0.04.md)

---

## v0.04 core vs v0.03 phases

| | **v0.04 core** | **v0.03 phases (1–10)** |
| --- | --- | --- |
| **What** | Canonical domain architecture | How the current codebase was built |
| **Docs** | `design/`, `v0.04/`, active docs above | `specifications/`, `roadmap/phase-*.md` |
| **Status** | Active — all new domain work | Complete — historical reference |
| **Extend?** | Yes | No (ordering/request/reservation stack retired v0.04-10) |

`catalog_items` remains **retain-temporary** legacy bibliographic admin until a future catalog cleanup milestone.

---

## Document types

| Type | Location |
| ---- | -------- |
| **Core domain** | [design/VERSION_0.04.md](design/VERSION_0.04.md) |
| **Active domain docs** | overview, domain-model, glossary, schema-reference |
| **Delivery milestones** | [roadmap/v0.04-delivery-roadmap.md](roadmap/v0.04-delivery-roadmap.md) |
| **Milestone specs** | [v0.04/](v0.04/) |
| **v0.03 phase specs** | [specifications/](specifications/) — historical |
| **Cross-cutting** | [specifications/cross-cutting/README.md](specifications/cross-cutting/README.md) |
| **Completion records** | [implementation/](implementation/) |
| **Guides** | architecture, testing, security, … |

---

## Implementation status

| Workstream | Status |
| ---------- | ------ |
| v0.03 Phases 1–10-D | Complete |
| **ShelfStack v0.04 core** | **v0.04-0 through v0.04-10 Complete** |
| **v0.04-11** doc/schema cleanup | **Complete** |
| **v0.04-12** demand ordering UX | **Complete** (branch) |
| Phase 9c GL layer | Deferred |
| Phase 10-E consistency sweep | Paused (after v0.04-12) |

v0.03 phase links: [roadmap/README.md](roadmap/README.md)

---

## General reference

| Document | Purpose |
| -------- | ------- |
| [overview.md](overview.md) | Product overview (v0.04 canonical) |
| [domain-model.md](domain-model.md) | Entities and relationships (v0.04 canonical) |
| [architecture.md](architecture.md) | Services and layering |
| [architecture-map.md](architecture-map.md) | Domain → tables → services |
| [roadmap.md](roadmap.md) | Full development history summary |
| [security.md](security.md) | Auth, permissions, audit |
| [testing.md](testing.md) | Test strategy |
| [implementation-guide.md](implementation-guide.md) | Developer conventions |
| [schema-reference.md](schema-reference.md) | Curated schema index |
| [glossary.md](glossary.md) | Term definitions |

---

## Operations and seeds

| Document | Purpose |
| -------- | ------- |
| [operations/foundation-runbook.md](operations/foundation-runbook.md) | Login, workstation, PIN, admin recovery |
| [implementation/csv-seeds.md](implementation/csv-seeds.md) | Classification CSV pipeline |
| [specifications/seed-data-spec.md](specifications/seed-data-spec.md) | Seed column definitions |

---

## Document hierarchy

```text
design/VERSION_0.04.md          ← core domain (authoritative for new work)
        ↓
overview / domain-model / glossary / schema-reference  ← active v0.04 guidance
        ↓
roadmap/v0.04-delivery-roadmap  ← milestones
        ↓
v0.04/{milestone}/              ← spec, data-model, test-plan
        ↓
implementation/                 ← completion records

v0.03: roadmap/ + specifications/ ← historical phased delivery
```

---

## Related files outside docs/

| File | Purpose |
| ---- | ------- |
| [../README.md](../README.md) | Project entry and quick start |
| [../DOCKER.md](../DOCKER.md) | Docker development |
| [../AGENTS.md](../AGENTS.md) | AI agent guidance |
