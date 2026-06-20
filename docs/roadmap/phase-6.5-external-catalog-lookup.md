# Phase 6.5: External Catalog Lookup and ISBNdb Integration

> **Status:** Planned — ShelfStack fit review (2026-06-10); decisions tightened (2026-06-10).
>
> **Primary UI surface:** Items workspace → Add Item (`/items/add_item`), not POS register.
>
> **MVP center:** ISBN local-first lookup → candidate preview → catalog create or link → Add Item continuation.
>
> **Naming:** Services `ExternalCatalog::*` · Permissions `items.external_lookup.*` · UI Items / Add Item.

## Purpose

Phase 6.5 adds ShelfStack’s first external bibliographic lookup integration, using ISBNdb as the initial provider.

This phase allows staff to search for book metadata outside the local ShelfStack catalog, preview the external data, compare it against existing local records, and create or enrich catalog records through a controlled, user-confirmed workflow.

Phase 6.5 is intentionally positioned between Phase 6 POS and Phase 7 customer demand workflows. Customer requests, special orders, buybacks, and future intake workflows will often begin with an ISBN, title, author, or customer description for an item that may not yet exist in ShelfStack. This phase creates the lookup/import foundation those later workflows need.

This phase does not make ISBNdb the authoritative source for ShelfStack data. ISBNdb records are treated as external candidates. Staff must review and confirm before ShelfStack creates or updates local catalog, product, or variant records.

> **Note:** Phase 6 POS (`Pos::LineLookup`) resolves **local** SKUs and catalog identifiers only. External lookup belongs in Items/Add Item for v1. A future “not found at register → Add Item lookup” handoff is deferred.

---

## ShelfStack Fit Review

This section records how Phase 6.5 aligns with the **current** ShelfStack codebase. Use it when scoping implementation and updating the functional spec/data model.

### Where it fits

| Surface | Fit | Notes |
| ------- | --- | ----- |
| **Add Item wizard** | **Primary** | Hook before or at start of `item_details` on the `catalog_linked` path. Reuse `session[:add_item_draft]` after import. |
| **Items index / search** | Secondary | Optional “search ISBNdb” when local search misses; same services as Add Item. |
| **Setup / admin** | Small | Provider health check and API key status. |
| **POS register** | **Out of scope (v1)** | Cashiers sell existing variants. Do not call ISBNdb from `/pos` in the first release. |
| **Phase 7 special orders / customer requests** | Consumer | Build reusable services now; wire UI in Phase 7. |
| **Ingram spreadsheet import** | Parallel | Bulk distributor import stays separate; share identifier resolution and catalog upsert patterns. |

### Reuse existing ShelfStack building blocks

Do **not** introduce parallel import logic when these already exist:

| Existing component | Phase 6.5 use |
| ------------------ | ------------- |
| `CatalogIdentifierService` | Identifier normalization, check-digit warnings, ISBN-10 → ISBN-13 primary rule, `add_identifier!` on import |
| `IngramCatalogImport::IdentifierResolver` | Local-first ISBN/EAN match before external call |
| `MetadataParser` | Map ISBNdb author arrays → `catalog_items.creators` + `creator_details` JSONB |
| `IngramCatalogImport::FormatMapper` (or shared extract) | Binding → `formats` mapping |
| `Items::AddItemController` | Wizard steps `choose_path` → `item_details` → `selling_setup` → `sellable_sku` |
| `AuditEvents` | Lookup, import, link, failure events |

### Domain model corrections (vs earlier draft language)

| Topic | ShelfStack today | Phase 6.5 direction |
| ----- | ---------------- | ------------------- |
| **Contributors** | `creators` string + `creator_details` JSONB — **no** `Contributor` model | Import via `MetadataParser`; do **not** add normalized contributor tables unless explicitly approved |
| **Publishers** | `catalog_items.publisher` string — **no** `Publisher` model | Set publisher string on catalog item; do not add publisher entity tables in v1 |
| **Classification** | Sellable defaults from **`sub_department`** on variants; BISAC via `CategoryScheme(bisac)` | Do not assign subdepartment, tax category, or BISAC from ISBNdb subjects automatically |
| **Store categories** | `CategoryNode` in store category scheme | ISBNdb subjects → external metadata/suggestions only |
| **Permissions** | Items workspace uses `items.*` (see `db/seeds/phase3_permissions.rb`) | **`items.external_lookup.*` only** — do not use `external_catalog.*` |

---

## MVP Scope vs Follow-up

Ship **MVP** first; keep the full phase document as the long-term target.

### MVP (recommended first release)

```text
6.5A  Provider foundation + lookup persistence + health check (minimal)
6.5B  ISBN lookup and normalization (ISBN path only)
6.5C  Preview + exact-ISBN duplicate detection + create catalog / link existing
       + fill-blank-only updates
6.5D  Add Item ISBN entry → import → hand off to existing selling_setup / sellable_sku
6.5E  External catalog search expansion (follow-up — not MVP)
```

### Follow-up Backlog (Phase 6.5.x / pre–Phase 7)

Not required for Phase 6.5 completion. See **Follow-up Backlog** section at end of document.

* **6.5E** — ISBNdb keyword/title/author/publisher/subject search and pagination
* Fuzzy duplicate detection (title/author, title/publisher/year)
* Explicit per-field overwrite UI on update-existing
* Dedicated product/variant builders outside Add Item wizard
* POS “not found → Add Item external lookup” handoff
* Rich provider quota dashboard
* Optional `external_identifiers` / subject suggestion tables
* Copy MSRP into list price field during Add Item review

---

## Decisions (locked)

| Topic | Decision |
| ----- | -------- |
| Permission namespace | `items.external_lookup.*` only |
| Service namespace | `ExternalCatalog::*` |
| UI namespace | Items workspace / Add Item |
| Phase 6.5 completion gate | **Phase 6.5 Exit Criteria** section below — not the follow-up backlog |
| Import rows | `external_catalog_imports` records **staff actions only** — not previews |
| Lookup execution | Real-time, staff-initiated, synchronous — **no automatic retry** |
| MSRP in MVP | Display + snapshot only — **not** written to catalog/product/variant price fields |
| Incomplete catalog import | Block Apply until required fields resolved (especially `format_id`) — no active catalog item with missing required fields |
| Keyword search | Phase **6.5E** follow-up — not in Phase 6.5 MVP |

## Open Decisions (resolve before implementation)

| # | Decision | Recommendation |
| - | -------- | ---------------- |
| 1 | **Secrets convention** | `Rails.credentials.isbndb_api_key` **vs** `ENV["ISBNDB_API_KEY"]` — pick one and document in runbook |
| 2 | **ISBNdb plan tier** | Which endpoints are contracted (book lookup, search, health/quota) |
| 3 | **Add Item entry UX** | New `identify` step **vs** panel on `choose_path` / top of `item_details` |
| 4 | **After import navigation** | Pre-filled `item_details` **vs** jump to `selling_setup` when catalog complete |

---

## Goals

Phase 6.5 should provide a reusable external catalog lookup foundation with ISBNdb as the first implementation.

The primary goals are:

1. Add a provider-based external catalog lookup architecture. **[MVP]**
2. Configure ISBNdb API access securely. **[MVP]**
3. Support API key health checks and quota visibility. **[MVP — minimal status only; rich dashboard follow-up]**
4. Search ShelfStack locally before calling ISBNdb. **[MVP]**
5. Lookup books by ISBN through ISBNdb. **[MVP]**
6. Search ISBNdb by title, author, keyword, publisher, or subject where appropriate. **[Follow-up — not MVP]**
7. Normalize ISBNdb responses into provider-neutral book candidate objects. **[MVP]**
8. Persist lookup requests, lookup results, and raw response snapshots. **[MVP]**
9. Detect existing local catalog, product, and variant matches. **[MVP — exact ISBN; fuzzy matching follow-up]**
10. Present a user-facing candidate preview before import. **[MVP]**
11. Create catalog items from confirmed ISBNdb candidates. **[MVP]**
12. Create catalog item identifiers for ISBN-13 and ISBN-10. **[MVP — via `CatalogIdentifierService`]**
13. Map authors and publisher into existing catalog fields (`creators`, `creator_details`, `publisher` string). **[MVP — not normalized contributor/publisher tables]**
14. Optionally continue to product and variant setup through the **existing Add Item wizard** when staff confirms store-facing fields. **[MVP — handoff, not parallel builders]**
15. Preserve source/provenance history for imported data. **[MVP]**
16. Record audit events for lookup/import actions. **[MVP]**
17. Expose external lookup from the Add Item workflow. **[MVP]**
18. Prepare the lookup/import workflow for reuse in Phase 7 customer requests and special orders. **[MVP — service API; Phase 7 UI deferred]**
19. Establish fixture-based tests that do not call ISBNdb in CI. **[MVP]**

---

## Non-Goals

Phase 6.5 does not include:

* Automated background enrichment.
* Bulk catalog refresh.
* Premium update-feed synchronization.
* Live API calls in automated tests.
* Automatic overwrite of curated local data.
* Automatic product or variant creation without staff confirmation.
* Automatic store category or BISAC mapping.
* Automatic tax category, subdepartment, or **category** assignment. *(Use subdepartment on variants; Phase 2 `categories` table was removed.)*
* Automatic vendor selection.
* Automatic purchase order creation.
* Automatic pricing updates.
* Real-time vendor price comparison.
* `with_prices=true` ISBNdb pricing lookup as a default workflow.
* Cover image downloading or local asset storage.
* Related-edition auto-creation.
* Multi-provider merge logic.
* Google Books, Open Library, ONIX, or distributor API integration.
* Buyback pricing.
* Customer-facing public catalog search.
* Non-book media lookup.
* Full Phase 7 customer request or special order workflows.
* **Normalized contributor or publisher entity tables** *(use `MetadataParser` + string/JSONB fields unless domain direction changes)*.
* **POS register external lookup** *(defer; local `Pos::LineLookup` only in Phase 6)*.
* **Field-level overwrite matrix on update-existing** *(defer; fill-blank-only in MVP)*.
* **Automatic retry or background re-fetch of failed lookups** *(real-time staff-initiated lookups only)*.
* **Automatic lookup result caching** *(persist for audit; each staff lookup runs live local-first + external path)*.
* **Fuzzy duplicate blocking** *(defer; exact ISBN match in MVP)*.

---

## Major Capabilities

Phase 6.5 includes the following capabilities. **Priority** indicates recommended delivery order; **MVP** marks the first release cut.

| Capability                  | Priority | Description                                                                                                                                         |
| --------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| ISBNdb source configuration | MVP      | ShelfStack can configure ISBNdb as an active external catalog source while storing secrets outside normal database configuration.                   |
| API key health check        | MVP      | Authorized users can verify whether ISBNdb is configured and view basic plan/quota status. *(Rich quota UI: follow-up.)*                            |
| Local-first lookup          | MVP      | ShelfStack searches local identifiers and catalog records before calling ISBNdb. Reuse `IngramCatalogImport::IdentifierResolver` patterns.        |
| ISBN lookup                 | MVP      | Staff can scan or enter an ISBN and retrieve an ISBNdb candidate when no confident local match exists.                                              |
| Keyword search              | Follow-up | Staff can search ISBNdb by title, author, keyword, publisher, or subject. *(Deferred from MVP — quota and UX cost.)*                               |
| Candidate normalization     | MVP      | ISBNdb book responses are mapped into provider-neutral normalized book candidates.                                                                  |
| Lookup persistence          | MVP      | Lookup request, response status, raw payload, and normalized results stored for **audit and troubleshooting** — not as a cache to skip live lookups. |
| Candidate preview           | MVP      | Staff can review title, authors, publisher, date, binding, pages, subjects, synopsis, image, ISBNs, MSRP, and local match status.                   |
| Duplicate detection         | MVP / Follow-up | **MVP:** exact ISBN-13 and ISBN-10. **Follow-up:** probable title/author and title/publisher/year.                                          |
| Controlled import           | MVP      | Staff can create or update local records only after reviewing a preview. *(Update: fill-blank-only in MVP.)*                                        |
| Catalog item import         | MVP      | ShelfStack can create or enrich catalog items from confirmed ISBNdb candidates.                                                                     |
| Identifier import           | MVP      | ShelfStack can create ISBN-13 and ISBN-10 identifiers via `CatalogIdentifierService`.                                                               |
| Author/publisher mapping    | MVP      | Map ISBNdb authors → `creators` / `creator_details`; publisher → `catalog_items.publisher` string. *(Not separate entity tables.)*                  |
| Format suggestion           | MVP      | Map ISBNdb binding to local `formats` when safe; require staff selection when ambiguous. Share logic with Ingram `FormatMapper` where possible.     |
| Product/variant continuation | MVP     | After catalog import, staff continue through **existing Add Item** `selling_setup` / `sellable_sku` steps. *(Not standalone ProductBuilder in MVP.)* |
| Source provenance           | MVP      | Imported records retain source and raw payload history on lookup/import rows.                                                                       |
| Audit logging               | MVP      | Lookup, import, link, update, and failure events create audit events.                                                                               |
| Add Item integration        | MVP      | External lookup is available from the Add Item workflow (`/items/add_item`), not POS.                                                                 |
| Phase 7 readiness           | MVP      | Lookup/import services expose entry points for future customer request and special order workflows.                                                   |

---

## Internal Phase Breakdown

Phase 6.5 is implemented as workstreams **6.5A–D** (MVP). Workstream **6.5E** is follow-up only.

---

## Phase 6.5A: External Catalog Provider Foundation

> **MVP:** All items below except rich quota dashboard UI.

### Purpose

Build the provider-neutral foundation for external catalog lookup.

This workstream creates the structure needed to support ISBNdb now and additional providers later without tightly coupling ShelfStack’s import workflow to ISBNdb-specific response shapes.

### Includes

* External data source records
* External lookup request records
* External lookup result records
* External catalog import records
* Provider-neutral normalized book result object
* Provider interface/conventions
* ISBNdb source seed/configuration
* API key lookup from credentials/environment
* API health check service
* Quota/plan status capture
* Basic provider error handling
* Lookup status model
* Raw payload snapshot storage
* Audit events for provider checks and failed lookups

### Primary question answered

> How does ShelfStack represent and track external catalog lookup independent of any one provider?

### Exit Criteria

Phase 6.5A is complete when:

1. ISBNdb can be configured as an `external_data_source`.
2. API keys are read from credentials, environment, or deployment secrets.
3. API keys are not stored in plain database fields.
4. Authorized users can run an ISBNdb health check.
5. Health check captures configured/not-configured status.
6. Health check captures last successful check timestamp.
7. Health check captures plan limit total, spent, and remaining when available.
8. Lookup requests can be created with source, lookup type, query, normalized query, request path, and request params.
9. Lookup requests can end in `completed`, `not_found`, `failed`, or `rate_limited`.
10. Lookup results can store normalized candidate fields and raw payload JSON.
11. External catalog imports record **staff actions only** (`applied`, `failed`, `skipped`) — not previews.
12. Provider-neutral normalized book result object exists.
13. ISBNdb-specific client code is separated from ShelfStack import logic.
14. Provider errors are converted into consistent ShelfStack error states.
15. Audit events are created for health checks, failed lookups, and failed imports.
16. Tests cover provider configuration, status transitions, and raw payload persistence.

---

## Phase 6.5B: ISBN Lookup and Normalization

> **MVP:** ISBN normalization, local-first ISBN lookup, synchronous `GET /book/{isbn}`, 404/timeout/rate-limit handling, book response normalization, fixture tests.
>
> Keyword/title/author search moved to **Phase 6.5E** (follow-up).

### Purpose

Implement the ISBNdb client and normalize ISBNdb book responses into ShelfStack candidate records for the **ISBN lookup path only**.

### Includes

* ISBN normalization *(reuse `CatalogIdentifierService`)*
* Local-first ISBN lookup *(reuse `IngramCatalogImport::IdentifierResolver` patterns)*
* ISBNdb `GET /book/{isbn}` lookup *(synchronous, real-time)*
* 404 handling as external miss — **no automatic retry**
* Book response normalization
* MSRP parsing
* ISBN-10 and ISBN-13 extraction
* Author array normalization
* Publisher normalization
* Binding/format normalization
* Language normalization
* Publication date parsing
* Subject array normalization
* Related ISBN capture
* Image URL capture
* Avoidance of deprecated response fields where alternatives exist

### Primary question answered

> Can ShelfStack reliably find and normalize book metadata from ISBNdb without creating local records yet?

### Exit Criteria

> **Annotation:** Criteria 11–16 and keyword search tests are **Phase 6.5E follow-up**. MVP completes criteria 1–10, 17–21, and ISBN-path tests only.

Phase 6.5B is complete when:

1. ISBN input is normalized before local or external lookup.
2. Invalid ISBN input is rejected before calling ISBNdb.
3. Local ISBN-13 match opens or identifies the existing local catalog record.
4. Local ISBN-10 match opens or identifies the existing local catalog record.
5. ISBNdb is called only when local lookup does not produce a confident match.
6. ISBNdb `GET /book/{isbn}` responses are parsed successfully.
7. ISBNdb 404 responses are stored as `not_found`, not treated as application errors.
8. ISBNdb 404 responses are **not** automatically retried; staff may submit a new lookup manually.
9. ISBNdb timeout responses are stored as failed lookup attempts.
10. ISBNdb rate-limit responses are stored as rate-limited lookup attempts.
11. Search by title/keyword returns candidate results. *(Phase 6.5E.)*
12. Search by author can be performed through supported ISBNdb search parameters. *(Phase 6.5E.)*
13. Search by publisher can be performed through supported ISBNdb search parameters. *(Phase 6.5E.)*
14. Search by subject can be performed through supported ISBNdb search parameters. *(Phase 6.5E.)*
15. Search pagination is supported. *(Phase 6.5E.)*
16. Search page size is constrained by ShelfStack defaults. *(Phase 6.5E.)*
17. ISBNdb responses are normalized into provider-neutral book candidates.
18. Candidate results persist ISBN-13, ISBN-10, title, authors, publisher, date published, binding, language, pages, synopsis, subjects, MSRP, image URL, and related ISBNs when present.
19. Deprecated ISBNdb fields are not used as primary mapping sources when non-deprecated fields are available.
20. `image_original` is not stored as the durable cover URL because it is temporary.
21. `with_prices=true` is not used by default.
22. Tests cover successful ISBN lookup, not-found lookup, timeout/failure handling, normalization. *(Add keyword search tests in 6.5E.)*

---

## Phase 6.5C: Candidate Preview, Matching, and Controlled Import

> **MVP:** Preview, exact ISBN duplicate detection, create catalog item, link existing, fill-blank-only update, identifiers via `CatalogIdentifierService`, authors via `MetadataParser`, publisher string, format suggestion, external subjects as metadata.
>
> **Follow-up:** Fuzzy duplicate detection, explicit per-field overwrite UI.

### Purpose

Allow staff to review ISBNdb candidates, compare them against local records, and create or enrich ShelfStack catalog records only after confirmation.

### Includes

* Candidate detail/preview page
* Local duplicate detection
* Field-by-field preview
* Existing catalog item link action
* Create catalog item action
* Update existing catalog item action
* Create identifiers *(via `CatalogIdentifierService`)*
* Map authors into `creators` / `creator_details` *(via `MetadataParser` — not contributor entity tables)*
* Set `catalog_items.publisher` string *(not publisher entity tables)*
* Suggest or require format
* Suggest language
* Store external subjects as candidate metadata
* Store raw payload snapshot with import
* Preserve local curated data by default
* Explicit overwrite/update choices — **follow-up** *(MVP: fill-blank-only)*
* Import audit events
* Import failure handling

### Primary question answered

> Can a staff member safely turn an external candidate into ShelfStack catalog data without polluting or overwriting local records?

### Exit Criteria

> **Annotation:** Criteria 6, 11, 15–16 (fuzzy duplicates, overwrite matrix, contributor/publisher **entities**) adjusted for ShelfStack: MVP uses exact ISBN, fill-blank updates, and string/JSONB author/publisher fields.

Phase 6.5C is complete when:

1. Staff can open a persisted ISBNdb candidate preview.
2. Preview displays title, ISBN-13, ISBN-10, authors, publisher, publication date, binding, pages, language, subjects, synopsis, image URL, MSRP, and related ISBNs when present.
3. Preview clearly labels the source as ISBNdb.
4. Preview shows local match status.
5. Exact local ISBN match is shown as an existing record rather than a new import.
6. Probable duplicate matches are shown before import. *(Follow-up; MVP may omit or show as non-blocking hints only.)*
7. Staff can link an ISBNdb candidate to an existing catalog item.
8. Staff can create a new catalog item from a candidate.
9. Staff can update an existing catalog item from a candidate.
10. Updates default to filling blank fields rather than overwriting populated local fields.
11. Staff can explicitly choose to apply external values over local values where allowed. *(Follow-up; not required for MVP.)*
12. ShelfStack creates ISBN-13 identifier when present.
13. ShelfStack creates ISBN-10 identifier when present.
14. ShelfStack does not create duplicate identifiers.
15. ShelfStack maps ISBNdb authors into `creators` / `creator_details` via `MetadataParser`.
16. ShelfStack sets `catalog_items.publisher` from ISBNdb publisher name when blank.
17. ShelfStack maps binding to local format only when a safe mapping exists.
18. ShelfStack requires staff selection when format mapping is ambiguous.
19. ISBNdb subjects are stored as external subject metadata or suggestions, not automatically assigned as store categories.
20. MSRP is displayed in preview and stored on lookup/import snapshots only — **not** written to catalog/product/variant price fields in MVP.
21. Related ISBNs are displayed or stored as related metadata, but do not automatically create records.
22. Import action records created/updated local record IDs.
23. Import action stores source, raw payload, field mapping snapshot, actor, and timestamp.
24. Audit events are created for link, create, update, skip, and failed import actions.
25. Tests cover duplicate detection *(exact ISBN in MVP)*, create catalog item, link existing, update existing *(fill-blank)*, author/publisher field mapping, identifier creation, ambiguous format handling, and audit creation.

---

## Phase 6.5D: Add Item Integration and Optional Product/Variant Creation

> **MVP:** ISBN entry on Add Item `catalog_linked` path, local-first behavior, candidate preview, catalog import, hand off to existing `selling_setup` / `sellable_sku` wizard. Subdepartment, condition, price, and inventory behavior remain **staff-entered** on variant step.
>
> **Follow-up:** Keyword search from Add Item; standalone `ProductBuilder` / `VariantBuilder` outside wizard; POS handoff.

### Purpose

Expose external lookup in the operational Add Item workflow and allow staff to continue from bibliographic import into store-facing product and variant setup **using the existing wizard**.

### Includes

* Add Item external lookup entry point *(before or at top of `item_details`; optional new `identify` step — see Open Decisions)*
* ISBN quick lookup
* Local-first result behavior
* ISBNdb fallback behavior
* Candidate import flow from Add Item
* Prefill `session[:add_item_draft]` after catalog import
* Continue to existing `selling_setup` and `sellable_sku` steps — **MVP path**
* Optional product creation via wizard — **not a separate builder in MVP**
* Optional product variant creation via wizard
* Required local store-facing fields on variant step: subdepartment, condition, selling price, inventory behavior
* SKU policy integration via existing Add Item / `SkuGenerator` rules
* Tax behavior through existing subdepartment/tax setup only
* Return to Add Item confirmation/result page
* Reusable service entry points for Phase 7 request intake

### Primary question answered

> Can a bookseller start with an ISBN or title and end with a usable ShelfStack catalog/product/variant record?

### Exit Criteria

> **Annotation:** Criterion 3 (keyword search from Add Item) is **follow-up**. Criteria 7–8 are satisfied by **existing wizard continuation**, not new standalone builders.

Phase 6.5D is complete when:

1. Add Item includes an external catalog lookup option.
2. Staff can scan or enter an ISBN from Add Item.
3. Local match opens or routes to the existing ShelfStack item.
4. No local match can trigger ISBNdb lookup.
5. ISBNdb match opens candidate preview.
6. Staff can import a candidate as a catalog item.
7. Staff can continue from catalog import to product creation.
8. Staff can continue from product creation to variant creation.
9. Product creation requires local store-facing confirmation.
10. Variant creation requires subdepartment.
11. Variant creation requires condition.
12. Variant creation requires selling price.
13. Variant creation requires inventory behavior.
14. Variant creation uses existing ShelfStack SKU rules.
15. Variant creation does not infer tax behavior directly from ISBNdb.
16. Product and variant creation actions are audited.
17. The external lookup/import service can be called from future customer request workflows.
18. Tests cover Add Item lookup, local-first behavior, ISBNdb fallback, candidate import, optional product creation, optional variant creation, required field validation, and authorization.

---

## Phase 6.5E: External Catalog Search Expansion (follow-up)

> **Not part of Phase 6.5 MVP.** Implement after 6.5A–D are stable.

### Purpose

Add ISBNdb keyword/title/author/publisher/subject search with pagination for staff who do not have an ISBN.

### Includes

* `ExternalCatalog::SearchBooks`
* ISBNdb keyword/title/author/publisher/subject search endpoints
* Pagination and page-size defaults
* Search result candidate persistence
* Add Item and Items index search entry points
* Real-time staff-initiated search only — **no automatic retry** on failed search requests

### Exit Criteria

Phase 6.5E is complete when search, pagination, normalization, permissions, tests, and Add Item/Items integration for keyword paths match the former Phase 6.5B search criteria (11–16) and Add Item criterion 3.

---

## Models Introduced

Phase 6.5 introduces the following tables:

| Table                      | Purpose                                                                                            |
| -------------------------- | -------------------------------------------------------------------------------------------------- |
| `external_data_sources`    | Configures external catalog data providers such as ISBNdb.                                         |
| `external_lookup_requests` | Records each external lookup attempt, including query, endpoint, status, response code, and actor. |
| `external_lookup_results`  | Stores normalized candidate records returned by an external provider.                              |
| `external_catalog_imports` | Records **staff-confirmed import/link/update/skip actions** — not previews.                       |

Optional/deferred tables:

| Table                          | Status            | Notes                                                                                                     |
| ------------------------------ | ----------------- | --------------------------------------------------------------------------------------------------------- |
| `external_identifiers`         | Optional/deferred | Useful as a generalized source-link table across catalog items, products, variants, and future providers. |
| `external_subject_suggestions` | Optional/deferred | Useful if ISBNdb subjects need structured review/mapping later.                                           |
| `external_provider_logs`       | Optional/deferred | Useful if provider diagnostics need more detail than lookup request records.                              |
| `external_image_assets`        | Deferred          | Only needed if cover images are downloaded/stored locally.                                                |
| `external_sync_runs`           | Deferred          | Only needed for future bulk enrichment or update-feed synchronization.                                    |

### Table roles

| Table                      | Role                                                  |
| -------------------------- | ----------------------------------------------------- |
| `external_lookup_requests` | API call / lookup attempt (audit + diagnostics)       |
| `external_lookup_results`  | Persisted candidate and preview source                |
| `external_catalog_imports` | User action: create, link, fill-blank update, skip, failed apply |

Preview is rendered from `external_lookup_results` (+ `ImportPreview` service). **Do not** create an import row for preview alone.

---

## Suggested Table Details

### `external_data_sources`

Tracks external providers.

```text
id
source_key
name
base_url
active
last_health_check_at
last_health_check_status
last_plan_limit_total
last_plan_limit_spent
last_plan_limit_left
configuration_json
created_at
updated_at
```

Notes:

* `source_key` should include `isbndb`.
* `configuration_json` should store only non-secret configuration.
* API keys should be stored in credentials, environment variables, or deployment secrets.

---

### `external_lookup_requests`

Tracks each lookup attempt.

```text
id
external_data_source_id
lookup_type
query
normalized_query
request_path
request_params_json
status
response_status_code
error_code
error_message
requested_by_user_id
started_at
completed_at
created_at
updated_at
```

Notes:

* Each staff-initiated lookup runs **synchronously at request time** (local-first, then external when needed).
* Persist rows for audit and troubleshooting — **not** to skip live lookups or auto-retry failures.
* **No `retry_after_at`** and no background re-fetch.

Suggested `lookup_type` values:

```text
isbn
keyword
advanced
key_check
bulk
feed
```

Suggested `status` values:

```text
pending
completed
not_found
failed
rate_limited
cancelled
```

---

### `external_lookup_results`

Stores normalized candidate results.

```text
id
external_lookup_request_id
source_key
external_identifier
isbn10
isbn13
title
subtitle
authors_snapshot
publisher_snapshot
date_published_snapshot
binding_snapshot
language_snapshot
pages
msrp_cents
currency_code
image_url
synopsis
excerpt
subjects_snapshot
dewey_decimal_snapshot
dimensions_snapshot
other_isbns_snapshot
raw_payload_json
confidence_score
local_catalog_item_id
local_product_id
local_product_variant_id
selected
created_at
updated_at
```

Notes:

* `external_identifier` should usually be ISBN-13 for ISBNdb book records.
* `raw_payload_json` should preserve the ISBNdb source response.
* `local_*` fields store match results at lookup time; re-run staff lookup to refresh.

---

### `external_catalog_imports`

Tracks **staff-confirmed import actions** only (not previews).

```text
id
external_lookup_result_id
external_data_source_id
status
action_type
imported_by_user_id
catalog_item_id
product_id
product_variant_id
error_message
field_mapping_snapshot
raw_payload_json
applied_at
created_at
updated_at
```

Suggested `status` values:

```text
applied
failed
skipped
```

Suggested `action_type` values:

```text
create_catalog_item
link_existing_catalog_item
fill_blank_existing_catalog_item
skip
```

Notes:

* `reversed` is deferred unless a void/undo workflow exists.
* Do not use `preview` as a status — preview uses `external_lookup_results` only.
* `create_product` / `create_product_variant` are not separate import actions in MVP; those steps use the Add Item wizard after catalog import.

---

## Indexes and Constraints

Recommended constraints:

```text
external_data_sources.source_key                    unique

external_lookup_requests:
  index (external_data_source_id, lookup_type, normalized_query)
  index (status)
  index (requested_by_user_id)
  index (created_at)

external_lookup_results:
  index (external_lookup_request_id)
  index (source_key, external_identifier)
  index (isbn13)
  index (isbn10)
  index (local_catalog_item_id)

external_catalog_imports:
  index (external_lookup_result_id)
  index (catalog_item_id)
  index (imported_by_user_id)
  index (applied_at)
```

Optional uniqueness (idempotency):

```text
one applied create/link action per external_lookup_result_id + catalog_item_id + action_type
```

---

## Permissions Introduced

Phase 6.5 uses **`items.external_lookup.*`** only (aligned with Items workspace and `items.ingram_import.run`).

| Permission | Purpose |
| ---------- | ------- |
| `items.external_lookup.access` | Access Add Item external lookup panel. |
| `items.external_lookup.search` | Run external ISBN lookup *(and keyword search in 6.5E)*. |
| `items.external_lookup.import` | Create local catalog records from external candidates. |
| `items.external_lookup.link_existing` | Link an external candidate to an existing local catalog item. |
| `items.external_lookup.update_existing` | Apply fill-blank external data to an existing catalog item. |
| `items.external_lookup.view_raw_payload` | View raw provider response payloads. |
| `items.external_lookup.configure` | Configure provider settings and run health checks. |

Suggested permission defaults:

| User type             | Suggested access                                           |
| --------------------- | ---------------------------------------------------------- |
| Frontline bookseller  | Search and import; link existing; **no** update-existing or configure in MVP. |
| Buyer/inventory staff | Search, import, link existing, continue Add Item to variant. |
| Manager/admin         | Configure provider, update existing *(follow-up)*, view raw payload. |

> **Note:** Catalog data is global; permissions gate **who may trigger external API calls and imports**, not store-scoped catalog rows. Store context may still appear on audit events when lookup runs from a store session.

---

## Services Introduced

> **Annotation:** Prefer shared catalog upsert with `IngramCatalogImport`. **Naming:** services `ExternalCatalog::*`; permissions `items.external_lookup.*`.

| Service                                       | MVP | Purpose                                                               |
| --------------------------------------------- | --- | --------------------------------------------------------------------- |
| `ExternalCatalog::Provider::IsbndbClient`     | Yes | Low-level ISBNdb HTTP client.                                         |
| `ExternalCatalog::Provider::IsbndbNormalizer` | Yes | Converts ISBNdb responses into normalized book candidates.            |
| `ExternalCatalog::CheckProviderHealth`        | Yes | Calls provider health/quota endpoint and records provider status.     |
| `ExternalCatalog::LookupByIsbn`               | Yes | Local-first ISBN lookup with ISBNdb fallback.                         |
| `ExternalCatalog::SearchBooks`                | No  | Searches local catalog and external book candidates. *(Follow-up.)*   |
| `ExternalCatalog::PersistLookupResult`        | Yes | Stores normalized candidates and raw payloads.                        |
| `ExternalCatalog::DuplicateDetector`          | Partial | **MVP:** exact ISBN. **Follow-up:** fuzzy title/author matches.   |
| `ExternalCatalog::ImportPreview`              | Yes | Builds field-by-field preview for user confirmation.                  |
| `ExternalCatalog::ImportCandidate`            | Yes | Applies confirmed candidate data to local records.                    |
| `ExternalCatalog::CatalogItemBuilder`         | Yes | Creates or updates catalog item data; should delegate to shared upsert logic. |
| `ExternalCatalog::MetadataMapper`             | Yes | Maps authors/publisher/subjects into `MetadataParser` + catalog fields. *(Replaces ContributorMapper / PublisherMapper.)* |
| `ExternalCatalog::FormatMapper`               | Yes | Maps ISBNdb binding to ShelfStack `formats`; share with Ingram where practical. |
| `ExternalCatalog::ProductBuilder`             | No  | **Follow-up.** MVP uses existing Add Item product step.               |
| `ExternalCatalog::VariantBuilder`             | No  | **Follow-up.** MVP uses existing Add Item variant step.               |

---

## Key Design Decisions

### Provider-based architecture

Build the integration as an external catalog provider layer, not as a one-off ISBNdb screen.

Correct direction:

```text
ExternalCatalog::Provider::IsbndbClient
→ normalized book candidate
→ ShelfStack import preview
→ confirmed local record changes
```

Avoid:

```text
ISBNdb response directly creates ShelfStack records
```

This keeps the import workflow reusable for future providers.

---

### ISBNdb is not the source of truth

ISBNdb provides external candidate metadata.

ShelfStack remains authoritative for:

* Local catalog curation
* Product setup
* Product variants
* Store categories
* Subdepartments
* Tax behavior
* Pricing
* Vendor sourcing
* Inventory behavior
* SKU behavior
* Staff notes

---

### Local-first lookup

ShelfStack should always search local records before calling ISBNdb.

For ISBN lookup:

```text
normalized ISBN
→ local catalog identifiers
→ local products/variants if applicable
→ ISBNdb only if no confident local match
```

For keyword search:

```text
local catalog results
→ external candidates
→ clearly labeled source sections
```

> **Follow-up:** Keyword search is not part of MVP. Do not block MVP on search endpoints or pagination.

---

### ISBN lookup is the MVP center

The most important Phase 6.5 workflow is ISBN lookup.

The primary flow is:

```text
Scan or enter ISBN
→ local lookup
→ ISBNdb lookup
→ candidate preview
→ confirmed import
```

Keyword and author/title search are useful, but secondary.

> **MVP defers keyword search.** Implement ISBN lookup path first; add search in Phase 6.5.x once Add Item ISBN flow is stable.

---

### Architecture naming

```text
Service namespace:     ExternalCatalog::*
Permission namespace:  items.external_lookup.*
UI namespace:          Items workspace / Add Item
```

Provider-neutral services live under `ExternalCatalog::*`. Authorization uses Items permission keys because staff trigger lookups from the Items workspace.

---

### Real-time lookup policy

All external lookups and searches are **real-time and staff-initiated**:

```text
Staff submits lookup
→ synchronous request (local-first, then external when needed)
→ persist lookup request + result for audit
→ show preview or outcome
```

Rules:

* **No automatic retry** for `failed`, `not_found`, or `rate_limited` outcomes.
* **No background re-fetch** or scheduled retry jobs.
* **No lookup result cache** used to skip a live external call on a new staff submission.
* Failed outcomes are diagnostic records only; staff must **manually submit again** to retry.
* Do **not** store or use `retry_after_at`.

Persisted lookup rows support audit, troubleshooting, and preview source data — not quota-saving cache substitution.

---

### HTTP timeouts (single ISBN lookup)

Single ISBN lookup runs synchronously in the web request:

```text
Open timeout:  2 seconds
Read timeout:  5 seconds
```

On timeout: persist `failed` lookup, show staff-friendly message, allow manual entry or a **new** staff-initiated lookup. Do not retry inside the same request.

---

### Provider health check frequency

Do **not** call ISBNdb `/key` on every Add Item page load.

Health check is:

* Manual from setup/admin (`items.external_lookup.configure`), or
* Cached on `external_data_sources` for **15–60 minutes** unless user manually refreshes.

Operational diagnostics only — not part of every item lookup.

---

### ISBNdb 404 handling

An ISBNdb 404 for `GET /book/{isbn}` is an external miss for that moment — not proof the ISBN is invalid.

Recommended status:

```text
not_found
```

**No automatic retry.** Staff may submit a new lookup manually or add the item manually.

User-facing message:

> No ISBNdb match found right now. You can add the item manually or try a new lookup.

---

### MSRP handling (MVP)

```text
ISBNdb MSRP: displayed in preview and stored on lookup/import snapshots only.
MVP:         do not write MSRP to catalog_items, products, or product_variants price fields.
Follow-up:   optional staff action to copy MSRP into list price during Add Item review (Phase 6.5.x).
```

---

### ISBNdb pricing behavior (`with_prices`)

Do not enable ISBNdb `with_prices=true` by default.

Reasons:

* It may require a higher ISBNdb plan.
* It increases response time.
* It fetches vendor prices, not necessarily publisher MSRP.
* Search and bulk endpoints do not return pricing.
* ShelfStack local pricing remains authoritative.

Use the ISBNdb `msrp` field for preview/snapshot display only in MVP (see **MSRP handling** above).

---

### Data precedence

Use this precedence order:

```text
manual store-entered data
> vendor/import data
> ISBNdb/API data
> generated/default values
```

External data fills gaps unless staff explicitly chooses otherwise.

---

### Field overwrite policy

Default import behavior should be conservative.

Correct behavior:

* Fill blank local fields.
* Add missing identifiers.
* Add missing author metadata via `MetadataParser` when `creators` is blank.
* Set `publisher` string when blank.
* Add external subjects as suggestions.
* Show conflicting values in preview.
* Require explicit confirmation before overwriting local data.

Avoid automatic overwrite of curated local data.

> **MVP:** Fill-blank-only updates. Per-field overwrite checkboxes are follow-up.

---

### Integration with Ingram import

`IngramCatalogImport` already upserts catalog items, products, and variants from spreadsheet rows with identifier resolution, format mapping, and audit events.

Phase 6.5 should:

* Reuse identifier resolution and format mapping patterns.
* Extract or share a common **catalog item upsert from external metadata** path where practical.
* Treat Ingram and ISBNdb as separate **sources** with separate provenance on lookup/import rows.
* When both sources could apply to the same ISBN, prefer **existing local record + link**; never silently merge conflicting metadata.

---

### Add Item session draft behavior

After a confirmed catalog import from Add Item:

1. Write imported `catalog_item_id` and bibliographic prefill into `session[:add_item_draft]`.
2. Set `workflow` to `catalog_linked`.
3. Route staff to `item_details` (review/edit) or directly to `selling_setup` if catalog item is complete enough.

Staff still complete **subdepartment**, **condition**, **selling price**, and **inventory behavior** on existing wizard steps. ISBNdb does not set these.

---

### Required catalog fields on import

Imported catalog items must satisfy Phase 3 rules. ShelfStack must **not** create an active catalog item with missing required fields.

If a required field cannot be derived safely from ISBNdb (especially `format_id`), the import preview must **require staff selection before Apply**. Block the create/link action until resolved.

Required for catalog create:

* `catalog_item_type` (default `book` when appropriate)
* `title`
* `format_id` *(mapped or staff-selected — never omitted)*
* `publication_status` *(default e.g. `unknown` when appropriate)*
* At least one active primary identifier via `CatalogIdentifierService`

ShelfStack does not use incomplete catalog draft records in MVP; use Add Item `session[:add_item_draft]` for wizard state before persist where appropriate.

`store_category` / BISAC linking remains **staff-curated** after import unless already present on an existing record.

---

### Idempotency

Phase 6.5 must prevent duplicate catalog noise:

* Repeating the same import action for the same ISBN must not create duplicate catalog items or duplicate identifiers.
* If an exact local ISBN match exists at import time, route to **link** or **fill-blank update** — not create.
* Re-submitting a staff lookup runs a **new** lookup request (real-time); import idempotency is enforced at apply time, not by skipping live lookup.

---

### Store category behavior

ISBNdb subjects should not automatically become ShelfStack store categories.

ISBNdb subjects may be stored as:

* External subject metadata
* Searchable descriptive metadata
* Future mapping suggestions

ShelfStack store categories remain curated operational classifications.

---

### Format/binding behavior

ISBNdb binding may suggest local format.

Examples:

| ISBNdb binding        | Possible ShelfStack format             |
| --------------------- | -------------------------------------- |
| Hardcover             | Hardcover                              |
| Paperback             | Trade Paperback or Paperback candidate |
| Mass Market Paperback | Mass Market Paperback                  |
| eBook                 | Digital/eBook candidate                |
| Audio CD              | Audiobook/Audio CD candidate           |

Ambiguous bindings should require staff selection.

---

### Related ISBN behavior

ISBNdb `other_isbns` can identify related editions or formats.

Phase 6.5 should display or store related ISBNs, but should not automatically create related catalog items, products, or variants.

---

### Cover image behavior

Store durable image URL only.

Do not store `image_original` as a long-term cover URL if it is temporary.

Downloading cover images into Active Storage or another asset system is deferred.

---

### Secret storage

ISBNdb API key must be stored outside normal database configuration.

Acceptable locations:

```text
Rails credentials
ENV["ISBNDB_API_KEY"]
deployment secret manager
```

Do not store the key in `external_data_sources.configuration_json`.

---

### Audit terminology

Use standard ShelfStack audit terminology:

| Term       | Meaning                                                                 |
| ---------- | ----------------------------------------------------------------------- |
| Actor      | User/system that performed the lookup/import.                           |
| Event name | What happened.                                                          |
| Auditable  | Lookup request, lookup result, import action, or local record affected. |
| Source     | Optional external lookup/import record that caused the local change.    |

---

### Testing strategy

No automated test should call the live ISBNdb API.

Use fixture JSON for:

```text
successful book lookup
book not found
keyword search results
missing publisher
missing author
missing MSRP
ambiguous binding
rate limit response
timeout/failure response
```

---

## Deferred Items

The following are intentionally deferred. Items marked **review addition** were added during the 2026-06 ShelfStack fit review.

| Item                               | Reason                                                                 |
| ---------------------------------- | ---------------------------------------------------------------------- |
| Bulk ISBN enrichment               | Useful later, but interactive lookup is the MVP.                       |
| Premium update feed sync           | Requires higher plan and background synchronization design.            |
| `with_prices=true` support         | Higher plan/performance impact and not core bibliographic metadata.    |
| Cover image asset storage          | Requires image caching, licensing, refresh, and storage decisions.     |
| Automatic subject/category mapping | Risky; store categories and BISAC are curated operational data.        |
| Automatic pricing updates          | Local pricing should remain authoritative.                             |
| Automatic vendor sourcing          | Vendor data belongs to purchasing/sourcing workflows.                  |
| Related edition auto-creation      | Could create duplicate/noisy records without staff review.             |
| Multi-provider merge logic         | Only ISBNdb is in scope for this phase.                                |
| Customer request integration       | Phase 6.5 prepares the service; Phase 7 uses it.                       |
| Buyback lookup integration         | Useful later; buyback workflow is not in scope yet.                    |
| Non-book lookup                    | ISBNdb is book-focused; media/game lookup should use future providers. |
| Public/customer-facing search      | This is an internal staff workflow.                                    |
| **ISBNdb keyword/title/author search** | **Review addition:** defer from MVP; ISBN path first.              |
| **Fuzzy duplicate detection**      | **Review addition:** exact ISBN sufficient for MVP.                    |
| **Per-field overwrite UI**         | **Review addition:** fill-blank-only for MVP.                          |
| **Standalone ProductBuilder / VariantBuilder** | **Review addition:** use Add Item wizard continuation.     |
| **POS register external lookup**   | **Review addition:** Items/Add Item only in v1.                        |
| **Normalized contributor/publisher tables** | **Review addition:** use existing string/JSONB fields.          |
| **Rich provider quota dashboard**  | **Review addition:** minimal health status in MVP.                     |
| **`external_identifiers` table**   | **Review addition:** optional until multi-provider linking needed.     |
| **Background/async lookup jobs**   | **Review addition:** defer until keyword search or slow paths ship.    |
| **Polish file–style split of lookup UI** | Optional maintainability; not required for MVP.                |

| **Automatic retry / lookup caching** | Real-time staff-initiated lookups only; audit persistence without cache substitution. |
| **Phase 6.5E keyword search** | Separate follow-up workstream after 6.5A–D. |

---

## Phase 6.5 Exit Criteria

Phase 6.5 is **complete** when all of the following are true. This is the only completion gate for the phase.

### Provider configuration

1. ISBNdb is represented as an `external_data_source`.
2. API key is loaded from credentials/environment/secrets — not plain database fields.
3. Authorized user can run health check manually; status cached 15–60 minutes — not on every Add Item load.
4. Configuration is protected by `items.external_lookup.configure`.

### Lookup (real-time ISBN path)

1. Staff can scan or enter an ISBN from Add Item.
2. ISBN is normalized; invalid ISBN rejected before external call.
3. Local ISBN identifiers searched first via existing patterns.
4. Exact local match routes to existing record — no duplicate external import.
5. External ISBNdb call runs **synchronously** only when local miss (open 2s / read 5s timeouts).
6. Outcomes persisted: `completed`, `not_found`, `failed`, `rate_limited` — **no automatic retry**.
7. Normalized candidate + raw payload stored on `external_lookup_results`.

### Preview and duplicate detection

1. Candidate preview shows bibliographic fields, source label, MSRP *(display only)*, and exact ISBN local match status.
2. Exact ISBN-13 and ISBN-10 duplicates detected; create blocked unless staff chooses link or fill-blank update.
3. Ambiguous `format_id` requires staff selection before Apply.
4. Preview does **not** create `external_catalog_imports` rows.

### Catalog import (staff actions)

1. Staff can create catalog item, link existing, or fill-blank update from preview.
2. Identifiers created via `CatalogIdentifierService` — no duplicates.
3. Authors/publisher via `MetadataMapper` / `MetadataParser` — not entity tables.
4. MSRP stored on snapshots only — **not** written to price fields.
5. `external_catalog_imports` records **actions only** (`applied`, `failed`, `skipped`) with `action_type`.
6. Import idempotency: repeat apply for same ISBN does not create duplicate catalog items or identifiers.

### Add Item integration

1. External lookup on Add Item `catalog_linked` path with barcode/scanner input.
2. After import, `session[:add_item_draft]` updated; staff continues via existing `selling_setup` / `sellable_sku`.
3. Subdepartment, condition, selling price, inventory behavior remain staff-entered on wizard steps.

### Authorization, audit, and tests

1. `items.external_lookup.*` permissions seeded; unauthorized users blocked.
2. Audit events for lookup failures, imports, links, and apply failures.
3. Fixture-based tests only — no live ISBNdb in CI.
4. Tests cover normalization, exact-ISBN duplicate detection, idempotent import, timeouts, and Add Item flow.

---

## Follow-up Backlog (not Phase 6.5)

Work tracked here does **not** block Phase 6.5 completion.

### Phase 6.5E — External catalog search expansion

* ISBNdb keyword/title/author/publisher/subject search and pagination
* `ExternalCatalog::SearchBooks`
* Add Item / Items index keyword entry points
* Real-time staff-initiated search only — no automatic retry on failed searches

### Other Phase 6.5.x items

* Fuzzy duplicate detection (title/author, title/publisher/year)
* Per-field overwrite UI on update-existing
* Copy MSRP into list price during Add Item review
* Standalone `ProductBuilder` / `VariantBuilder` outside Add Item wizard
* POS “not found → Add Item external lookup” handoff
* Rich provider quota dashboard
* `external_identifiers` / subject suggestion tables
* Background/async lookup jobs *(only if needed for slow search paths)*

### Phase 7 consumers

* Customer request and special order intake reusing `ExternalCatalog::LookupByIsbn` and import services

---

## Related Documents

```text
docs/roadmap.md                                    — add Phase 6.5 row when approved
docs/roadmap/phase-6-pos-foundation.md             — POS local lookup only (Pos::LineLookup)
docs/roadmap/phase-3-catalog-products-variants.md  — catalog item, identifiers, Add Item
docs/specifications/classification-target-spec.md  — sub_department, BISAC, store categories
docs/implementation/phase-3-completion.md          — Add Item wizard, Ingram import
app/services/catalog_identifier_service.rb         — identifier rules
app/services/ingram_catalog_import/                — parallel bulk import patterns
app/controllers/items/add_item_controller.rb       — wizard integration point
AGENTS.md                                          — deferred: external API without confirmation
```
