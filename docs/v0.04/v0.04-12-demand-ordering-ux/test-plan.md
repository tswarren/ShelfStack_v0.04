# v0.04-12 Demand Ordering UX — Test Plan

## Status

**Planned** — companion to [spec.md](spec.md).

---

## Merge gate (milestone complete)

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails db:seed
./dev/rails-docker bin/rails test

STRICT=1 bin/rails shelfstack:v0046:verify_demand_foundation
STRICT=1 bin/rails shelfstack:v0047:verify_allocations
STRICT=1 bin/rails shelfstack:v0048:verify_sourcing
STRICT=1 bin/rails shelfstack:v0049:verify_po_receiving
V00410_PHASE=g2 STRICT=1 bin/rails shelfstack:v00410:verify_legacy_ordering_retired
STRICT=1 bin/rails shelfstack:v00411:verify_documentation_schema_cleanup
V00412_SLICE=final STRICT=1 bin/rails shelfstack:v00412:verify_demand_ordering_ux
```

Per-PR: run prior verifiers + `V00412_SLICE=<slice>` for current slice.

---

## v00412 slice stages

| Stage | Checks |
| ----- | ------ |
| `slice_0` | Spec bundle + completion stub exist |
| `slice_b` | Workflow presenter + next-action partial |
| `slice_a` | Capture form lookups/prefill |
| `slice_c` | Allocation workbench + inbound picker |
| `slice_d` | Sourcing vendor cards + response wizard |
| `slice_e` | Demand-to-PO services/routes |
| `slice_f` | Receipt pickup visibility |
| `slice_g` | POS pickup paths |
| `final` | All checks 1–8 |

---

## Test matrix

### Slice B — next action

* unallocated + on-hand → allocate CTA
* unallocated + inbound → inbound review CTA
* no supply → sourcing CTA
* active sourcing → review run CTA
* planned draft PO → planned label
* vendor backorder → backorder CTA
* ready for pickup → POS CTA
* terminal → no action

### Slice A — capture

* item hold with auto-alloc message
* customer special order
* manual TBO
* research + match path
* prefill from query params

### Slice C — allocation

* inbound allocate via picker (no typed PO line ID)
* allocate-all blocked without override+reason

### Slice D — sourcing

* attempt from vendor card
* partial vendor response
* cascade

### Slice E — PO bridge

* planner qty split
* draft PO = planned not inbound
* inbound alloc only when PO submitted + eligible

### Slice F — receiving

* pre-post preview with customer names
* post confirmation customer-ready vs stock split

### Slice G — POS

* lookup by customer / demand number
* stale allocation blocks
* fulfill once; void safe
