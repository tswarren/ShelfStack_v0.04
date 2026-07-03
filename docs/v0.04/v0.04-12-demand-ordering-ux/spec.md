# v0.04-12 Demand, Sourcing, and Ordering UX Completion — Functional Specification

## Status

**Planned** — begins after v0.04-11 merge.

Companion documents:

* [data-model.md](data-model.md) — minimal; no major schema redesign
* [test-plan.md](test-plan.md) — workflow, system, and regression coverage
* `docs/implementation/v0.04-12-completion.md`

---

## Job

v0.04-12 completes **staff-facing UX** for the v0.04 demand-to-fulfillment chain (v0.04-6 through v0.04-10 backend).

```text
DemandLine → DemandAllocation → Sourcing → PO/Receipt → Inventory::Post → POS pickup
```

---

## Resolved decisions

| Decision | Choice |
|----------|--------|
| Milestone type | UX/workflow completion only — no domain redesign |
| Schema | No new core tables; audit payloads preferred |
| Catalog drop | Out of scope (v0.04-12+ catalog milestone) |
| `/customers` vs `/demand` | Keep both; align labels and deep-links |
| Supply semantics | Four staff states: Unallocated, Planned on order, On order (inbound), On hand |
| Planned vs committed | Draft PO coverage is **planned**; active `inbound_purchase_order` only when `InboundAvailability` eligible |
| PO bridge | `DemandCoveragePlanner` plans; allocation services commit |
| Next-action authority | `Demand::DemandLineWorkflowPresenter` — detail + queue labels |
| No raw IDs | Normal UX must not require typing internal IDs |
| Verifier | Slice-aware `V00412_SLICE` |
| Implementation order | B before A |

### PO bridge commit point rule

Demand-to-PO may record proposed demand coverage on a draft PO, but must **not** create active `inbound_purchase_order` allocations until the PO line passes existing `DemandAllocations::InboundAvailability` rules (typically submitted/ordered PO, not draft).

---

## Implementation slices

```text
0 Docs → B Next-action → A Capture → C Allocation → D Sourcing → E PO bridge → F Receiving → G POS → H Verifier
```

See [test-plan.md](test-plan.md) for acceptance criteria and merge gate.

---

## Out of scope

Vendor API/EDI, automatic cascade, catalog removal, Phase 10-E styling sweep, production migration, full POS redesign, notification delivery engine.
