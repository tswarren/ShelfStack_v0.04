# v0.04-11 Documentation and Schema Cleanup — Test Plan

## Status

**Planned** — companion to [spec.md](spec.md).

Focus areas:

1. **Stale-reference scanning** (active docs + optional app code identifiers)
2. **Schema-doc consistency** (`docs/schema-reference.md` vs `db/schema.rb`)
3. **Verifier gate** v0046 through v00411 (STRICT)
4. **Full Rails test suite** (regression only — no new feature tests unless schema/code cleanup requires)

This milestone does **not** add staff workflow or domain behavior tests.

---

## Test categories

| Category | Focus |
| -------- | ----- |
| **Verifier — v00411** | New documentation/schema cleanup checks |
| **Verifier — regression** | v0046, v0047, v0048, v0049, v00410 remain green |
| **Verifier unit** | `test/lib/shelfstack/v00411_verify_test.rb` |
| **Schema audit** | Manual/rake comparison checklist (see [data-model.md](data-model.md)) |
| **Regression** | `bin/rails test` after doc-only and schema-drop slices |
| **Seeds** | Optional `shelfstack:seeds:validate` after catalog doc updates (no drop expected) |

---

## Merge gate (normative)

Run in order; all must pass before marking v0.04-11 complete:

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

Record command output summary in `docs/implementation/v0.04-11-completion.md`.

---

## v00411 verifier — planned checks

Implement `Shelfstack::V00411Verify` + `shelfstack:v00411:verify_documentation_schema_cleanup`.

### Check list

| Key | Description |
| --- | ----------- |
| `v00410_completion_marked_complete` | `docs/implementation/v0.04-10-completion.md` status is Complete |
| `active_docs_no_forbidden_legacy_models` | Active doc paths do not contain unqualified forbidden model/table names |
| `schema_reference_no_dropped_ordering_tables` | `docs/schema-reference.md` does not list v0.04-10 dropped tables as active |
| `domain_model_describes_v004_chain` | `docs/domain-model.md` mentions required v0.04 entities (structural grep) |
| `glossary_has_retired_section` | `docs/glossary.md` contains retired-term guidance |
| `agents_md_references_v004_verifiers` | `AGENTS.md` lists v0046–v00411 verification commands |
| `v004_milestone_statuses_aligned` | `docs/v0.04/README.md` shows v0.04-10 Complete and v0.04-11 in progress/complete appropriately |
| `redirect_aliases_allowlisted` | Known legacy redirects present in routes.rb and documented (not flagged as errors) |
| `prior_verifiers_pass` | Delegate or document that v0046–v00410 are run in merge gate (optional inline re-run) |

### Active doc scan paths (minimum)

Per [spec.md resolved decision #4](spec.md#4-v00411-verifier-scope):

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
docs/implementation/v0.04-*-completion.md
docs/v0.04/
app/
config/routes.rb
```

**Excluded from strict forbidden-term checks** (historical — banner optional):

```text
docs/specifications/phase-*
docs/roadmap/phase-*
docs/implementation/phase-*-completion.md  (historical phase completion notes)
```

**Standard historical banner** (required if a phase spec is linked from active nav; otherwise exclusion is sufficient):

```text
Historical v0.03 implementation reference. This document is retained for project history and is not current domain guidance. For current behavior, see the v0.04 domain, schema, and workflow docs.
```

### Route redirect allowlist (must exist in `config/routes.rb`)

```text
customers_customer_requests
orders_purchase_requests
```

These are **not** failures when documented as legacy redirects.

Prose allowlist contexts (forbidden-term scanner):

```text
Retired
Historical
v0.03 implementation reference
Archived
Migration history
Already-removed (v0.04-10)
Retained temporary
legacy admin
deprecated compatibility
from_tbo (deprecated)
customers_customer_requests (redirect)
orders_purchase_requests (redirect)
```

### Forbidden patterns (active docs — unqualified)

Scanner should fail if these appear outside allowlisted contexts in **active doc paths** (not `app/` — see app scan below):

```text
CustomerRequest
CustomerRequestLine
PurchaseRequest
PurchaseRequestLine
SpecialOrder
InventoryReservation
purchase_order_line_allocations
receipt_line_allocations
customer_requests      (as active workflow/table)
purchase_requests      (as active workflow/table)
inventory_reservations (as active workflow/table)
```

**Active docs only** — also fail if `catalog_items` or `catalog_item_id` appear as **canonical** domain guidance (without "retained-temporary", "legacy admin", or "Retired" context).

**Allowed in active docs:**

* `catalog_items` under explicit **Retained temporary (legacy admin)** section
* `from_tbo` marked deprecated compatibility
* Redirect alias names in glossary or AGENTS compatibility section

**Allowed examples:**

* “special order” as capture intent in glossary with clarification
* “Retired: customer request → use DemandLine”
* Historical phase spec paths under `docs/specifications/` (excluded from scan or bannered)

### App scan (Slice G — required per spec decision #4)

Scan `app/` for **dropped ordering model class names** only:

```text
CustomerRequest
CustomerRequestLine
PurchaseRequest
PurchaseRequestLine
SpecialOrder
InventoryReservation
```

**Do not fail** on `CatalogItem`, `catalog_item`, or `/catalog_items` paths while retain-temporary policy is in effect.

| Key | Description |
| --- | ----------- |
| `app_no_dropped_ordering_model_constants` | `app/` has no unqualified references to v0.04-10 dropped model class names |

---

## Unit tests — `test/lib/shelfstack/v00411_verify_test.rb`

Minimum cases:

| Test | Assert |
| ---- | ------ |
| `report includes required check keys` | All planned v00411 keys present |
| `forbidden term scanner flags sample stale string` | Synthetic fixture string fails outside allowlist |
| `allowlist permits retired historical reference` | String with “Retired v0.03” context passes |
| `schema reference check detects dropped table name` | Synthetic bad schema-reference snippet fails (if unit-testable) |
| `report passes on current repo` | After Slice B–D complete, STRICT report status PASS |

Follow pattern from `test/lib/shelfstack/v00410_verify_test.rb`.

---

## Schema-doc consistency tests

No automated diff against `db/schema.rb` is required for v0.04-11 MVP unless a rake task is added. Minimum process:

1. Complete checklist in [data-model.md](data-model.md) § Schema doc consistency.
2. v00411 check `schema_reference_no_dropped_ordering_tables`.
3. Manual spot-check: every table listed in active sections of `docs/schema-reference.md` exists in `db/schema.rb`.

If a rake task is added (optional):

```bash
./dev/rails-docker bin/rails shelfstack:v00411:audit_schema_docs
```

Document in completion note if implemented.

---

## Regression tests by slice

| Slice | Required test action |
| ----- | -------------------- |
| **0** | Full merge gate baseline on `main` |
| **A** | None (audit only) |
| **B** | v00411 unit + STRICT v00411 after doc rewrites |
| **C** | v00411 schema-reference check |
| **D** | Add v00411 verify test file; full verifier suite |
| **E** | Full `bin/rails test` (no migration expected); v0046–v00411; seeds validate optional |
| **F** | Final merge gate recorded in completion note |
| **G** | Full test suite if app identifiers renamed; extend v00411 if app scan added |

---

## Stale-reference scanning — manual smoke (Slice A)

After classification, spot-check these user-facing doc paths render no dead links to removed routes:

| Path | Must not imply active route |
| ---- | --------------------------- |
| `docs/overview.md` | `/customers/customer_requests`, `/orders/purchase_requests/from_tbo` |
| `docs/domain-model.md` | `customer_requests` table as current |
| `AGENTS.md` | `CustomerRequest`, `PurchaseRequest` as implementation targets |

---

## Acceptance mapping

| Spec acceptance criterion | Test evidence |
| ------------------------- | ------------- |
| Active docs v0.04 canonical | v00411 `active_docs_*` + manual review |
| Schema docs match DB | data-model checklist + v00411 schema check |
| Catalog audit closed | data-model.md rows filled (retain-temporary); no unplanned drops |
| Verifiers pass | Merge gate commands |
| Full suite green | `bin/rails test` output in completion note |

---

## Explicitly out of scope

* New POS pickup / demand workflow integration tests
* New purchasing automation tests
* Phase 10-E UI consistency system tests
* Production data migration verification
* Performance/load testing
