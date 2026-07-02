# v0.04-11 Documentation and Schema Cleanup — Functional Specification

## Status

**Planned** — begins on `main` after [v0.04-10 completion](../../implementation/v0.04-10-completion.md) (merged 2026-07-02, PR #15).

Companion documents:

* [data-model.md](data-model.md) — schema artifact audit decision log (not new model design)
* [test-plan.md](test-plan.md) — stale-reference scanning, schema-doc consistency, verifier gate

Completion note (created in Slice F): `docs/implementation/v0.04-11-completion.md`

---

## Job

v0.04-11 is a **stabilization, documentation, and cleanup milestone**.

The job is to make the repository read as if v0.04 is the canonical ShelfStack core:

```text
Product / ProductVariant
  → DemandLine
  → DemandAllocation
  → Sourcing
  → PurchaseOrder / Receipt
  → Inventory::Post
  → Fulfillment / POS pickup
```

This milestone does **not** introduce new staff workflows. It updates active documentation, schema references, terminology, examples, verifiers, and any remaining quarantined legacy schema/code left after v0.04-10.

---

## Milestone boundary

v0.04-11 must not become:

* a new catalog modeling milestone;
* a new purchasing automation milestone;
* a POS redesign milestone;
* a production historical data migration project;
* a broad UI redesign (Phase 10-E resumes **after** v0.04-11, not inside it);
* a feature pass for returns/refunds/reopening fulfilled demand;
* a migration squash unless explicitly approved as a final, separately scoped slice.

This milestone succeeds when a developer, tester, or AI coding agent can read **active docs** and understand the implemented v0.04 domain without being led toward v0.03 concepts as current guidance.

---

## Active vs historical documentation

| Scope | Paths | v0.04-11 treatment |
| ----- | ----- | ------------------ |
| **Active (rewrite)** | `AGENTS.md`, `README.md`, `docs/README.md`, `docs/overview.md`, `docs/domain-model.md`, `docs/glossary.md`, `docs/schema-reference.md`, `docs/architecture.md`, `docs/testing.md`, `docs/roadmap/v0.04-delivery-roadmap.md`, `docs/v0.04/**`, `docs/implementation/v0.04-*-completion.md` | Must use v0.04 vocabulary; stale v0.03 workflow language removed or marked retired |
| **Historical (banner only)** | `docs/specifications/phase-*`, `docs/roadmap/phase-*`, phase completion notes for pre-v0.04 work | Add or retain explicit **v0.03 implementation reference** banner; do not rewrite full phase specs |
| **Implementation reference** | `docs/design/VERSION_0.04.md` | Align with current chain; minor updates only if contradicted by shipped milestones |

---

## Roadmap definition of done

From [delivery roadmap](../../roadmap/v0.04-delivery-roadmap.md):

1. Documentation matches implementation.
2. No stale `catalog_item` or v0.03 ordering language remains in **active** docs.
3. Any remaining quarantined v0.03 tables/columns are dropped **or** explicitly documented as retained with reason.
4. Completion notes exist for v0.04 milestones (status aligned with merge state).
5. `AGENTS.md`, schema references, and active domain docs use stable v0.04 vocabulary.

Extended for this spec:

6. Active docs describe `Product` as the descriptive commercial item and `ProductVariant` as the operational sellable/inventory/purchasing/POS grain.
7. Active docs describe demand → allocation → sourcing → PO/receiving → inventory → POS fulfillment as the canonical operational chain.
8. Legacy terms may remain only in archived/history sections, explicitly marked retired.
9. `shelfstack:v00411:verify_documentation_schema_cleanup` detects stale active-doc references.
10. Feature code changes only when required to remove stale references, support verifiers, or execute an audited schema drop.

---

## Source-of-truth vocabulary

Use these terms consistently in active docs:

| Canonical term | Meaning |
| -------------- | ------- |
| `Product` | Descriptive commercial item (book edition, media release, sideline, etc.). |
| `ProductVariant` | Operational sellable unit: SKU, POS, inventory, purchasing, receiving, buyback, fulfillment grain. |
| `DemandLine` | Captured need/intent: hold, notify, special order, used wanted, manual TBO, buyer replenishment, research. |
| `DemandAllocation` | Claim/pointer from demand to supply: on-hand, inbound PO, vendor backorder. |
| `SourcingRun` / `SourcingAttempt` / `VendorResponse` | Vendor inquiry and response workflow. |
| `PurchaseOrderLine` | Store-requested / vendor-confirmed purchasing line at variant grain. |
| `ReceiptLine` | Physical receiving line; only accepted quantity posts inventory. |
| `Inventory::Post` | Sole authoritative inventory mutation path. |
| `InventoryBalance` / `inventory_ledger_entries` | Cached balance and append-only ledger (not “stock balance” unless glossary defines alias). |
| POS pickup | Fulfillment of active on-hand demand allocation through normal POS sale + `DemandAllocations::Fulfill`. |

Avoid in active **current-state** docs unless clearly marked retired:

| Retired / legacy term | Replacement |
| --------------------- | ----------- |
| `CatalogItem` as active model | `Product` |
| `catalog_item_id` as canonical FK | `product_id` / `product_variant_id` |
| customer request / `customer_requests` | demand line / `/demand` queues |
| special order table/model | `DemandLine` with `capture_intent = special_order` |
| purchase request / TBO hub | demand + sourcing / manual TBO intent |
| inventory reservation | demand allocation |
| PO line allocation / receipt line allocation | demand allocation / receipt conversion |
| `from_tbo` PO builder | manual TBO demand + sourcing |

**Allowed current terms:** “special order”, “hold”, “notify”, “manual TBO” as **customer-facing capture intents**, not legacy table names.

---

## Implementation slices

```text
0 → A → B → C → D → E → F → G
```

| Slice | Name | Purpose |
| ----- | ---- | ------- |
| **0** | Baseline on main | Confirm v0.04-10 complete; run migrate/seed/test + v0046–v00410; open v0.04-11 branch |
| **A** | Active documentation audit | Classify stale v0.03 hits in active docs (update / archive / allowed / remove) |
| **B** | Canonical domain docs | Rewrite domain, overview, glossary, AGENTS guidance |
| **C** | Schema reference cleanup | Align `docs/schema-reference.md` with `db/schema.rb`; update [data-model.md](data-model.md) decisions |
| **D** | Verifier + test-plan gate | Add `v00411` stale-reference verifier; wire rake task and tests |
| **E** | Catalog artifact audit + drop | Required audit of `catalog_items` / `catalog_item_id` FKs; drop or document retain |
| **F** | Completion + roadmap closure | Completion note, milestone statuses, verification results |
| **G** | Active code reference cleanup | Remove/rename stale identifiers in app code (presenters, route alias comments, hub DTO names) — no behavior change |

Each slice must leave the repo runnable and docs internally consistent.

---

## Slice 0 — Baseline on main

### Goals

* Confirm v0.04-10 completion docs are accurate (already merged).
* Establish clean baseline before v0.04-11 edits.

### Tasks

1. Verify v0.04-10 completion/spec statuses remain **Complete** (no duplicate rework).
2. Run baseline verification (record results in v0.04-11 completion draft):

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails db:seed
./dev/rails-docker bin/rails test

./dev/rails-docker env V00410_PHASE=g2 STRICT=1 bin/rails shelfstack:v00410:verify_legacy_ordering_retired

STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v0046:verify_demand_foundation
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v0047:verify_allocations
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v0048:verify_sourcing
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v0049:verify_po_receiving
```

### Done when

* Baseline commands pass on `main`.
* v0.04-11 spec bundle exists (this document set).

---

## Slice A — Active documentation audit

### Goals

Find stale or misleading v0.03 language in **active** docs and classify each hit.

### Audit targets (minimum)

```text
AGENTS.md
README.md
docs/README.md
docs/overview.md
docs/domain-model.md
docs/glossary.md
docs/schema-reference.md
docs/architecture.md
docs/testing.md
docs/roadmap/v0.04-delivery-roadmap.md
docs/v0.04/**/*.md
docs/implementation/v0.04-*-completion.md
```

### Search terms (minimum)

```text
catalog item
catalog_items
catalog_item_id
CatalogItem
customer request
customer_requests
special_orders
purchase request
purchase_requests
inventory reservation
inventory_reservations
purchase_order_line_allocations
receipt_line_allocations
from_tbo
TBO hub
legacy ordering
v0.03 workflow
```

### Classification

| Class | Action |
| ----- | ------ |
| **Update** | Rewrite active section to v0.04 vocabulary |
| **Archive allowed** | Keep in historical section with “Retired v0.03” banner |
| **Allowed current term** | Valid intent label (e.g. special order capture intent) — document in audit log |
| **Remove** | Delete content pointing at dropped routes/models/tables |

Record outcomes in [data-model.md](data-model.md) audit appendix **or** v0.04-11 completion note audit checklist.

### Done when

* Every high-risk hit in active docs is classified.
* Slice B/C work list is explicit.

---

## Slice B — Canonical domain docs

### Required updates

#### `docs/domain-model.md`

Must describe current entities and the canonical chain (see [Job](#job)).

Must state:

* `ProductVariant` is the operational grain.
* `Inventory::Post` is the sole authoritative stock mutation service.
* Demand and allocation do not mutate on-hand inventory.
* Receiving posts accepted quantity only.
* POS pickup fulfills demand allocation after normal POS sale inventory posting.

#### `docs/overview.md`

Bookstore operations overview using v0.04 vocabulary; no `CatalogItem` as active core model.

#### `docs/glossary.md`

Current terms plus **Retired terms** section (customer request, purchase request, inventory reservation, etc.).

#### `AGENTS.md`

Agent guidance: Product/ProductVariant, DemandLine/DemandAllocation, thin controllers, `Inventory::Post`, verifier commands v0046–v00411.

### Done when

* Core active docs consistently describe v0.04 as canonical.

---

## Slice C — Schema reference cleanup

### Goals

Align `docs/schema-reference.md` (and related architecture notes) with post-v0.04-10 `db/schema.rb`.

### Must not list as active tables (dropped v0.04-10)

```text
customer_requests
customer_request_lines
special_orders
purchase_requests
purchase_request_lines
inventory_reservations
purchase_order_line_allocations
receipt_line_allocations
```

### Must document current v0.04 tables (non-exhaustive)

```text
products
product_identifiers
product_variants
demand_lines
demand_allocations
sourcing_runs
sourcing_attempts
vendor_responses
purchase_orders
purchase_order_lines
receipts
receipt_lines
inventory_ledger_entries
inventory_balances
pos_transactions
pos_transaction_lines  (including demand_allocation_id)
```

Update [data-model.md](data-model.md) decision rows as schema doc edits land.

### Done when

* Schema reference matches current database.
* Dropped ordering tables are not presented as active.

---

## Slice D — Verifier and test-plan gate

Add `Shelfstack::V00411Verify` and rake task:

```bash
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v00411:verify_documentation_schema_cleanup
```

See [test-plan.md](test-plan.md) for check list and test coverage.

### Done when

* v00411 verifier exists and passes on updated docs.
* v0046–v00410 verifiers still pass.

---

## Slice E — Catalog artifact audit (required)

**Not optional.** v0.04-1 fused catalog metadata onto `products`, but `catalog_items` and related FKs may still exist.

Audit and record every row in [data-model.md](data-model.md):

* `catalog_items` table
* `products.catalog_item_id`
* buyback / external lookup / import FK paths
* `CatalogItem` model and remaining app references

Outcomes: **already removed**, **drop in v0.04-11**, **retain with documented reason**, **test-only — rewrite tests then drop**.

Rules:

* Do not remove artifacts still required by product identifier or buyback flows without a replacement path.
* Prefer reseed over row migration (pre-production).
* Any drop requires migration + schema doc + v00411 verifier update in same slice.

### Done when

* Every catalog artifact has a recorded decision and owner slice.
* Drops (if any) are migrated, tested, and documented.

---

## Slice F — Completion and roadmap closure

1. Add `docs/implementation/v0.04-11-completion.md`.
2. Update roadmap and `docs/v0.04/README.md` milestone status.
3. Record full verification command output.
4. List deferred work explicitly.

### Done when

* v0.04-11 marked **Complete** after merge.
* New contributors can follow active docs without v0.03 workflow confusion.

---

## Slice G — Active code reference cleanup

Thin cleanup pass for **identifiers and comments only** (no workflow changes):

* Route redirect aliases (`customers_customer_requests`, `orders_purchase_requests`) — remove or document retain in completion note.
* Presenter/hub field names (`purchase_requests`, `open_special_orders`, `PurchaseRequestLink`) — rename to demand-native labels where staff-facing or grep-noisy.
* Comments referencing dropped models.

May extend v00411 to scan `app/` for forbidden **model class names** (similar to v00410 staff-permission scan).

### Done when

* Stale legacy model names absent from active app paths verifiers scan, or explicitly allowlisted with reason.

---

## Verification commands (merge gate)

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails db:seed
./dev/rails-docker bin/rails test

STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v0046:verify_demand_foundation
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v0047:verify_allocations
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v0048:verify_sourcing
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v0049:verify_po_receiving
./dev/rails-docker env V00410_PHASE=g2 STRICT=1 bin/rails shelfstack:v00410:verify_legacy_ordering_retired
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v00411:verify_documentation_schema_cleanup
```

Optional:

```bash
./dev/rails-docker bin/rails shelfstack:seeds:validate
```

---

## Acceptance criteria

v0.04-11 is complete when:

1. Active domain docs describe v0.04 as canonical.
2. Active schema docs match `db/schema.rb`.
3. No active docs present dropped ordering tables or legacy workflow models as current.
4. Catalog artifact audit in [data-model.md](data-model.md) is closed (drop or retain documented).
5. `AGENTS.md` gives correct v0.04 implementation guidance.
6. v00411 verifier passes; v0046–v00410 verifiers pass.
7. Full test suite passes.
8. v0.04-11 completion note records audit results and deferred items.

---

## Explicitly deferred

* Automatic vendor cascade
* Pubnet / EDI / API sourcing import
* POS return/refund reopening demand allocations
* Production historical data migration
* Multi-register row-lock hardening for pickup claims
* Phase 10-E consistency sweep (starts after v0.04-11)
* Migration squashing (separate approval)
* New purchasing automation
* New external bibliographic integrations
