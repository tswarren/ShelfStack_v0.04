# Phase 9 — Reporting and Accounting

## Purpose

Phase 9 gives ShelfStack reliable **operational** reporting for daily store work. Phases **9a** and **9b** are **complete**. Phase **9c** (accounting-grade financial postings and GL export) is **deferred**; see [Phase 10](Phase-x10-comprehensive-ux-expansion.md) for the next active priority.

ShelfStack remains the operational system of record. External accounting software may remain the official general ledger. When Phase 9c resumes, it would add a GL-shaped posting layer that produces export-ready journal summaries without replacing 9b operational reports on day one.

## Sub-Phases

| Sub-phase | Document | Job |
| --------- | -------- | --- |
| **9a** | [phase-9a-ux-foundation-for-reporting.md](phase-9a-ux-foundation-for-reporting.md) | Report-facing UI standards, formatting conventions, date/status semantics, and operational-vs-financial reporting rules |
| **9b** | [phase-9b-reports.md](phase-9b-reports.md) | Consolidate and extend operational reports for daily management, reconciliation, inventory visibility, buybacks, stored value, and customer demand |
| **9c** | [phase-9c-gl-shaped-financial-layer.md](phase-9c-gl-shaped-financial-layer.md) | Generate balanced financial postings from operational events and produce export-ready financial summaries for external accounting systems — **deferred** |

## Status

| Sub-phase | Status |
| --------- | ------ |
| **9a** | Complete — see [phase-9a-completion.md](../implementation/phase-9a-completion.md) |
| **9b** | Complete — see [phase-9b-completion.md](../implementation/phase-9b-completion.md) |
| **9c** | **Deferred** — design reference retained; not scheduled for immediate implementation |
| **Next** | [Phase 10 — Comprehensive UI/UX Expansion](Phase-x10-comprehensive-ux-expansion.md) |

## Boundary with Phase 10

[Phase 10 — Comprehensive UI/UX Expansion](Phase-x10-comprehensive-ux-expansion.md) implements the broader interaction vision in sub-phases **10-A through 10-E**.

**Delivery order:** 10-A (interaction infra) → 10-B (item cockpit) → 10-C (POS keyboard workspace) → 10-D (workflow polish) → 10-E (consistency sweep).

Phase 9 implements the **report-facing subset** of the ShelfStack UX direction. It does not complete the comprehensive interaction system.

Report screens should remain compatible with Phase 10 component upgrades but are not redesigned as part of the POS workspace overhaul. Phase 10 explicitly excludes redesigning Phase 9 report screens except for shared component upgrades, accessibility, or compatibility updates.

POS `/reports` command and utility links navigate to the canonical **9b `/reports` hub** (legacy `/pos/reports/*` redirects remain). When an in-progress POS draft exists, confirm before navigating away (10-C spec).

## Recommended Sequence

```text
9a  Foundations     UX contract, formatting, reporting semantics          ✓ complete
9b  Visibility      Operational reports                                   ✓ complete
9c  Financial layer Balanced postings, mappings, GL export readiness      deferred
10  UX expansion    10-A→10-B→10-C→10-D→10-E (modals, items, POS, workflows)  next
```

9b reports use operational tables, snapshots, and ledgers. Phase 9c would add accounting-grade postings and optional financial tie-out sections on selected 9b reports. That work is **deferred**; the [9c design document](phase-9c-gl-shaped-financial-layer.md) remains the reference when resumed. See [9c — Relationship to Phase 9b](phase-9c-gl-shaped-financial-layer.md#relationship-to-phase-9b).

## Operational vs Financial Reporting

| Layer | Owner | Source | Examples |
| ----- | ----- | ------ | -------- |
| **Operational** | 9b | POS snapshots, inventory ledger, stored value ledger, workflow tables | Customer request queue, open PO status, register session activity |
| **Financial** | 9c | `financial_events`, `financial_entries`, `financial_entry_lines` | GL export, tax payable tie-out, liability postings |
| **Hybrid** | 9b + 9c | Operational context + financial totals | Register summary, stored value activity with tie-out |

Semantics for both layers are defined in Phase 9a. Phase 9c posting rules must follow those semantics when that sub-phase is resumed.

## Reporting Dimensions

Use consistent terminology across 9a, 9b, and 9c:

```text
store
department
subdepartment
tax category
tender type
product variant
vendor
register session
procurement path (derived reporting dimension; see 9a)
inventory behavior / inventory tracking
```

Do not use legacy **merchandise class** unless that entity is formally reintroduced.

## Related Documents

```text
docs/specifications/ui-ux-concept.md
docs/handoff/phase-9-item-drill-down-contract.md
docs/implementation/classification-cleanup.md
docs/roadmap.md
```

## Key Outcomes

### Complete (9a and 9b)

1. Reports use a shared view contract and consistent formatting.
2. Operational reports reconcile against POS, inventory, buyback, and stored-value data.
3. Thirteen operational reports are available under `/reports` with permission-union navigation and legacy URL redirects.
4. The broader POS/items/modal/drawer UX vision remains deferred to Phase 10.

### Deferred (9c)

1. Financial postings are balanced, idempotent, traceable, and reversible.
2. Export-ready journal summaries can be generated for external accounting software.

See [phase-9c-gl-shaped-financial-layer.md](phase-9c-gl-shaped-financial-layer.md) for the retained design reference.

## Current Priority

Phases 9a and 9b are **complete**. Phase 9c (GL-shaped financial layer) is **deferred**. The next planned roadmap phase is **Phase 10 — Comprehensive UI/UX Expansion**.

Phase 9c design work may resume later without overriding 9b operational totals. Financial postings should tie out to operational reports rather than replace them on day one.
