# v0.04-11 Documentation and Schema Cleanup — Schema Artifact Audit Log

## Status

**Complete (pending merge)** — companion to [spec.md](spec.md).

---

## Resolved decisions summary (2026-07-02)

| Topic | Decision | v0.04-11 action |
| ----- | -------- | --------------- |
| `catalog_items` | **retain-temporary** | Document in schema reference + active docs; no drop migration |
| Redirect aliases | **keep** | Allowlist in v00411; document in glossary/AGENTS |
| `from_tbo` params | **keep deprecated** | Document; verify return paths; no rename |
| Schema reference | **curated** | Rewrite active sections; retained-temporary section for catalog |
| Phase specs | **banner only** | No rewrite; fix active nav links only |
| Verifier scope | **active docs + app + routes** | See [test-plan.md](test-plan.md) |

---

## Purpose

Record every schema artifact, FK, route alias, and code identifier that v0.04-11 must classify as:

* **already removed** (v0.04-10 or earlier)
* **retain-temporary** (legacy admin; documented quarantine)
* **doc-only** (no schema change; update docs/comments)
* **drop in v0.04-11** (not expected for catalog per resolved decisions)
* **defer** (future milestone owner)

Fill **Decision** and **Verification** columns as slices complete. Leave `_pending_` only for items discovered during audit.

---

## v0.04-10 dropped ordering artifacts (reference — do not reintroduce)

These were removed in v0.04-10 G2. Active docs and schema reference must not list them as current.

| Artifact | Decision | Verification |
| -------- | -------- | ------------ |
| `customer_requests` table | already removed | v00410 G2 verifier |
| `customer_request_lines` table | already removed | v00410 G2 verifier |
| `purchase_requests` table | already removed | v00410 G2 verifier |
| `purchase_request_lines` table | already removed | v00410 G2 verifier |
| `special_orders` table | already removed | v00410 G2 verifier |
| `inventory_reservations` table | already removed | v00410 G2 verifier |
| `purchase_order_line_allocations` table | already removed | v00410 G2 verifier |
| `receipt_line_allocations` table | already removed | v00410 G2 verifier |
| `CustomerRequest` model | already removed | grep `app/` |
| `PurchaseRequest` model | already removed | grep `app/` |
| `InventoryReservation` model | already removed | grep `app/` |
| `customer_requests.*` permissions | already removed | v00410 legacy_staff_permissions_absent |

---

## Catalog artifacts (Slice E)

Per spec resolved decision #1: **retain-temporary** for v0.04-11.

| Artifact | Decision | Owner | Verification |
| -------- | -------- | ----- | ------------ |
| `catalog_items` table | retain-temporary | Slice E (doc) | Listed under "Retained temporary" in schema-reference; not in canonical domain chain |
| `catalog_item_identifiers` table (if present) | retain-temporary | Slice E (doc) | Same section as catalog_items |
| `products.catalog_item_id` | retain-temporary | Slice E (doc) | schema-reference notes optional legacy FK |
| `buyback_lines.catalog_item_id` | retain-temporary | Slice E (doc) | buyback spec / data-model cross-ref |
| `buyback_lines.created_catalog_item_id` | retain-temporary | Slice E (doc) | same |
| `external_catalog_imports.catalog_item_id` | retain-temporary | Slice E (doc) | import flow docs |
| `external_lookup_results.local_catalog_item_id` | retain-temporary | Slice E (doc) | lookup flow docs |
| `CatalogItem` model | retain-temporary | Slice E (doc) | AGENTS.md: not canonical; bibliographic admin only |
| `/items/catalog_items` routes | retain-temporary | Slice G (doc) | routes.rb comment or glossary |
| `items.catalog_items.*` permissions | retain-temporary | Slice E (doc) | permission seeds unchanged |

**Future owner:** v0.04-12+ catalog/import cleanup (tentative) — removal, import dependency replacement, `products.catalog_item_id` drop.

**No drop migration in v0.04-11** unless milestone is explicitly rescoped.

---

## Route and param compatibility (Slice G)

| Artifact | Decision | Owner | Verification |
| -------- | -------- | ----- | ------------ |
| `customers_customer_requests` redirect → `/demand` | keep | Slice G | v00411 allowlist; glossary "Retired routes" |
| `orders_purchase_requests` redirect → manual TBO | keep | Slice G | v00411 allowlist |
| `from_tbo` query/route params | keep deprecated | Slice G | Document deprecated; grep confirms no PO TBO builder target |
| `from_tbo` PO builder views/controllers | already removed | v0.04-10 | grep + orphan view delete in Slice G if any remain |

---

## Code identifier cleanup (Slice G)

| Identifier / path | Decision | Owner | Verification |
| ----------------- | -------- | ----- | ------------ |
| `PurchaseRequestLink` (presenter/hub) | renamed ManualTboDemandLink | Slice G | grep after rename |
| `open_special_orders` | aliased to demand queries | Slice G | drawer uses demand_lines partial |
| `open_purchase_request_lines` | aliased to demand queries | Slice G | drawer uses demand_lines partial |
| Comments referencing `CustomerRequest` etc. | doc-only | Slice G | v00411 app scan (dropped models only) |

**Note:** `CatalogItem` references in `app/` are **allowed** while retain-temporary; v00411 must not fail on `CatalogItem` / `catalog_items` in app paths unless active docs present them as canonical.

---

## Active documentation files (Slice A–B)

| File | Decision | Owner | Verification |
| ---- | -------- | ----- | ------------ |
| `docs/domain-model.md` | rewrite v0.04 chain | Slice B | v00411 structural grep |
| `docs/overview.md` | rewrite reporting/workspaces | Slice B | manual review |
| `docs/glossary.md` | add retired terms + compat aliases | Slice B | v00411 glossary check |
| `docs/schema-reference.md` | curated rewrite | Slice C | v00411 dropped-table check |
| `AGENTS.md` | align v0.04 priority + verifiers | Slice B | v00411 agents check |
| `README.md` | align milestone status | Slice F | v00411 README alignment |
| `docs/README.md` | rewrite nav + priority | Slice B | v00411 stale nav check |
| `docs/specifications/phase-*` | banner only (no rewrite) | Slice A optional | banner present or excluded from scan |

---

## Schema doc consistency checklist (Slice C)

Manual verification after `docs/schema-reference.md` rewrite:

- [x] Every table in **Active v0.04 operational** sections exists in `db/schema.rb`
- [x] Dropped ordering tables (§ above) not listed as active
- [x] Demand chain documented: `demand_lines`, `demand_allocations`, sourcing, PO, receipt, inventory, POS pickup FK
- [x] Inventory tables use `inventory_balances` and `inventory_ledger_entries` (not legacy names)
- [x] `catalog_items` only under **Retained temporary (legacy admin)** if still in DB
- [x] `pos_transaction_lines.demand_allocation_id` documented

Optional rake task: `shelfstack:v00411:audit_schema_docs` — document in completion note if implemented.

---

## Sign-off

| Slice | Auditor | Date | Notes |
| ----- | ------- | ---- | ----- |
| E — catalog audit | v0.04-11 | 2026-07-02 | retain-temporary documented |
| C — schema reference | v0.04-11 | 2026-07-02 | curated rewrite complete |
| G — code cleanup | v0.04-11 | 2026-07-02 | demand drawer lists wired |
| F — completion | v0.04-11 | 2026-07-02 | ready for PR |
