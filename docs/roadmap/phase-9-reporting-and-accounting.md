# Phase 9 — Reporting and Accounting

## Purpose

Phase 9 gives ShelfStack reliable operational visibility and accounting-grade financial data without turning ShelfStack into a full accounting system.

ShelfStack remains the operational system of record. External accounting software may remain the official general ledger. Phase 9 creates trustworthy reports for daily store work and a GL-shaped financial posting layer that produces export-ready journal summaries.

## Sub-Phases

| Sub-phase | Document | Job |
| --------- | -------- | --- |
| **9a** | [phase-9a-ux-foundation-for-reporting.md](phase-9a-ux-foundation-for-reporting.md) | Report-facing UI standards, formatting conventions, date/status semantics, and operational-vs-financial reporting rules |
| **9b** | [phase-9b-reports.md](phase-9b-reports.md) | Consolidate and extend operational reports for daily management, reconciliation, inventory visibility, buybacks, stored value, and customer demand |
| **9c** | [phase-9c-gl-shaped-financial-layer.md](phase-9c-gl-shaped-financial-layer.md) | Generate balanced financial postings from operational events and produce export-ready financial summaries for external accounting systems |

## Boundary with Phase 10

[Phase 10 — Comprehensive UI/UX Expansion](Phase-x10-comprehensive-ux-expansion.md) implements the broader interaction vision: POS command registry, drawers, full item cockpit, modal rollout, and keyboard-first workspace expansion.

Phase 9 implements the **report-facing subset** of the ShelfStack UX direction. It does not complete the comprehensive interaction system.

Report screens should remain compatible with Phase 10 component upgrades but are not redesigned as part of the POS workspace overhaul. Phase 10 explicitly excludes redesigning Phase 9 report screens except for shared component upgrades, accessibility, or compatibility updates.

## Recommended Sequence

```text
9a  Foundations     UX contract, formatting, reporting semantics
9b  Visibility      Operational reports (may ship before 9c is complete)
9c  Financial layer Balanced postings, mappings, GL export readiness
```

9b reports may initially use operational tables, snapshots, and ledgers. Phase 9c adds accounting-grade postings; selected 9b reports may later gain financial tie-out sections. See [9c — Relationship to Phase 9b](phase-9c-gl-shaped-financial-layer.md#relationship-to-phase-9b).

## Operational vs Financial Reporting

| Layer | Owner | Source | Examples |
| ----- | ----- | ------ | -------- |
| **Operational** | 9b | POS snapshots, inventory ledger, stored value ledger, workflow tables | Customer request queue, open PO status, register session activity |
| **Financial** | 9c | `financial_events`, `financial_entries`, `financial_entry_lines` | GL export, tax payable tie-out, liability postings |
| **Hybrid** | 9b + 9c | Operational context + financial totals | Register summary, stored value activity with tie-out |

Semantics for both layers are defined in Phase 9a. Phase 9c posting rules must follow those semantics.

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

At the end of Phase 9:

1. Reports use a shared view contract and consistent formatting.
2. Operational reports reconcile against POS, inventory, buyback, and stored-value data.
3. Financial postings are balanced, idempotent, traceable, and reversible.
4. Export-ready journal summaries can be generated for external accounting software.
5. The broader POS/items/modal/drawer UX vision remains deferred to Phase 10.

## Current Priority

Phase 9 follows completion of Phase 8.5 operational cleanup (discounts, tax exceptions, order handling, item data quality). Implement in order: **9a → 9b → 9c**, with selective 9b delivery before 9c where operational value does not depend on financial postings.

Phase 9c design work may begin after 9a semantics are stable, but 9c posting implementation should not override or reinterpret 9b operational totals. Financial postings should tie out to operational reports rather than replace them on day one.
