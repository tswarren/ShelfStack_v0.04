# v0.04-11 Documentation and Schema Cleanup — Schema Artifact Audit Log

## Status

**Planned** — companion to [spec.md](spec.md). This document is **not** a new domain model design.

Purpose:

* Record **audit decisions** for schema and code artifacts that may still reference v0.03.
* Track **retain vs drop** outcomes with owner slice and verification notes.
* Stay synchronized with `docs/schema-reference.md` during Slice C/E.

Update this log as decisions are made. Do not spec new tables or business rules here — use [VERSION_0.04.md](../../design/VERSION_0.04.md) and milestone v0.04-6–10 specs for domain design.

---

## How to use this log

For each artifact, fill one row in the decision table:

| Column | Meaning |
| ------ | ------- |
| **Artifact** | Table, column, model, route alias, or doc section |
| **Location** | `db/schema.rb`, model path, route, doc path |
| **Pre-audit state** | Present / absent / redirect-only / doc-only |
| **Decision** | `drop` · `retain` · `retain-temporary` · `doc-only` · `already-removed` |
| **Owner slice** | A–G from spec |
| **Blockers** | Flows/tests still referencing artifact |
| **Verified** | Date + command (migrate/test/verifier) |

Close the milestone when every **required** row has a decision and verification note.

---

## Ordering domain (v0.04-10 — reference baseline)

These were targeted for removal in v0.04-10 G2. Confirm absent on `main` before v0.04-11 schema doc work.

| Artifact | Expected state post-v0.04-10 | Decision | Verified |
| -------- | ---------------------------- | -------- | -------- |
| `customer_requests` | Dropped | `already-removed` (v0.04-10) | v00410 G2 |
| `customer_request_lines` | Dropped | `already-removed` (v0.04-10) | v00410 G2 |
| `special_orders` | Dropped | `already-removed` (v0.04-10) | v00410 G2 |
| `purchase_requests` | Dropped | `already-removed` (v0.04-10) | v00410 G2 |
| `purchase_request_lines` | Dropped | `already-removed` (v0.04-10) | v00410 G2 |
| `inventory_reservations` | Dropped | `already-removed` (v0.04-10) | v00410 G2 |
| `purchase_order_line_allocations` | Dropped | `already-removed` (v0.04-10) | v00410 G2 |
| `receipt_line_allocations` | Dropped | `already-removed` (v0.04-10) | v00410 G2 |
| `pos_transaction_lines.inventory_reservation_id` | Dropped | _confirm in schema audit_ | |
| `pos_transaction_lines.demand_allocation_id` | Active FK | `retain` (v0.04-10) | v00410 G1 |

---

## Catalog artifacts (Slice E — required audit)

v0.04-1 fused metadata onto `products`; v0.04-2 added `product_identifiers`. **`catalog_items` may still exist** — audit before any drop.

### Pre-audit inventory (2026-07-02)

Known references to verify during Slice E:

| Artifact | Known location | Pre-audit state | Decision | Owner | Blockers | Verified |
| -------- | -------------- | --------------- | -------- | ----- | -------- | -------- |
| `catalog_items` table | `db/schema.rb` | Present | _TBD_ | E | buyback, external lookup, `products.catalog_item_id` | |
| `CatalogItem` model | `app/models/catalog_item.rb` | Present | _TBD_ | E | app routes/controllers/views/tests | |
| `products.catalog_item_id` | `db/schema.rb` | Present (nullable FK) | _TBD_ | E | product create/migration paths | |
| `buyback_lines.catalog_item_id` | `db/schema.rb` | Present | _TBD_ | E | buyback intake/match flows | |
| `buyback_lines.created_catalog_item_id` | `db/schema.rb` | Present | _TBD_ | E | graded item create from buyback | |
| `external_catalog_imports.catalog_item_id` | `db/schema.rb` | Present | _TBD_ | E | ISBNdb import path | |
| `external_lookup_results.local_catalog_item_id` | `db/schema.rb` | Present | _TBD_ | E | add-item / external lookup | |
| Items routes `catalog_item` legacy paths | `config/routes.rb` | _audit_ | _TBD_ | E/G | redirects vs active | |
| `catalog_item_identifiers` (if any) | _audit_ | _TBD_ | _TBD_ | E | superseded by `product_identifiers`? | |

### Slice E decision rules

| Outcome | When to use |
| ------- | ----------- |
| **drop** | No production path requires artifact; tests rewritten; migration + reseed documented |
| **retain-temporary** | Still referenced; document replacement milestone (e.g. external lookup cutover) |
| **retain** | Intentional bridge (document why and who owns removal) |
| **doc-only** | Name appears only in historical docs — update docs, no schema change |

---

## Route and permission aliases (Slice G)

v0.04-10 retained compatibility redirects. Audit whether v0.04-11 removes or documents them.

| Artifact | Location | Pre-audit state | Decision | Owner | Notes |
| -------- | -------- | --------------- | -------- | ----- | ----- |
| `customers_customer_requests` route alias → `/demand` | `config/routes.rb` | Redirect | _TBD_ | G | v0.04-10 deferred |
| `orders_purchase_requests` → manual TBO demand | `config/routes.rb` | Redirect | _TBD_ | G | v0.04-10 deferred |
| Legacy Phase 7A permission keys in seeds | `db/seeds` | May exist unused | _TBD_ | G | v00410 scans app, not seeds |

---

## Active code identifiers (Slice G)

Rename-only cleanup candidates (no behavior change):

| Identifier | Location | Pre-audit state | Decision | Owner |
| ------------ | -------- | --------------- | -------- | ----- |
| `PurchaseRequestLink` | `PurchaseOrderDocumentHub` | Present | _TBD_ | G |
| `open_special_orders` | item operations presenters | Empty/stub | _TBD_ | G |
| `open_purchase_request_lines` | item operations tab presenter | Returns `[]` | _TBD_ | G |
| `from_tbo` return path | `Items::ReturnPath` | Redirect to manual TBO | _TBD_ | G |

---

## Documentation artifacts (Slice A–C)

Track major active doc sections that required rewrite (fill during implementation):

| Doc path | Issue (pre-audit) | Decision | Owner | Verified |
| -------- | ----------------- | -------- | ----- | -------- |
| `docs/domain-model.md` | Customer Request entity described as active | _TBD_ | B | |
| `docs/overview.md` | “customer requests” in reporting list | _TBD_ | B | |
| `docs/schema-reference.md` | May list dropped / catalog tables | _TBD_ | C | |
| `docs/glossary.md` | Missing retired-term section | _TBD_ | B | |
| `docs/v0.04/README.md` v0.03 reference blurb | Says “until milestones replace” — update tone | _TBD_ | F | |

---

## Schema doc consistency checklist (Slice C)

After edits, confirm alignment between `db/schema.rb` and `docs/schema-reference.md` for:

- [ ] Demand tables (`demand_lines`, `demand_allocations`)
- [ ] Sourcing tables (`sourcing_runs`, `sourcing_attempts`, `vendor_responses`)
- [ ] PO line vendor quantity columns (v0.04-9)
- [ ] POS `demand_allocation_id` (v0.04-10)
- [ ] Inventory ledger / balances naming
- [ ] Absence of dropped ordering tables in **active** schema reference sections

Record pass/fail in v0.04-11 completion note.

---

## Audit closure

| Gate | Status |
| ---- | ------ |
| All ordering artifacts confirmed removed or documented | _open_ |
| All catalog artifact rows decided | _open_ |
| Schema reference matches `db/schema.rb` | _open_ |
| v00411 verifier passes | _open_ |
| Completion note links this log | _open_ |
