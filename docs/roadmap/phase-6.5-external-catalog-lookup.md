# Phase 6.5: External Catalog Lookup and ISBNdb Integration

> **Status:** Planned.

## Purpose

Phase 6.5 adds ShelfStack’s first external bibliographic lookup integration, using ISBNdb as the initial provider.

This phase allows staff to search for book metadata outside the local ShelfStack catalog, preview the external data, compare it against existing local records, and create or enrich catalog records through a controlled, user-confirmed workflow.

Phase 6.5 is intentionally positioned between Phase 6 POS and Phase 7 customer demand workflows. Customer requests, special orders, buybacks, and future intake workflows will often begin with an ISBN, title, author, or customer description for an item that may not yet exist in ShelfStack. This phase creates the lookup and import foundation those later workflows need.

This phase does not make ISBNdb the authoritative source for ShelfStack data. ISBNdb records are treated as external candidates. Staff must review and confirm before ShelfStack creates or updates local catalog, product, or variant records.

---

## Goals

Phase 6.5 should provide a reusable external catalog lookup foundation with ISBNdb as the first implementation.

The primary goals are:

1. Add a provider-based external catalog lookup architecture.
2. Configure ISBNdb API access securely.
3. Support API key health checks and quota visibility.
4. Search ShelfStack locally before calling ISBNdb.
5. Lookup books by ISBN through ISBNdb.
6. Search ISBNdb by title, author, keyword, publisher, or subject where appropriate.
7. Normalize ISBNdb responses into provider-neutral book candidate objects.
8. Persist lookup requests, lookup results, and raw response snapshots.
9. Detect existing local catalog, product, and variant matches.
10. Present a user-facing candidate preview before import.
11. Create catalog items from confirmed ISBNdb candidates.
12. Create catalog item identifiers for ISBN-13 and ISBN-10.
13. Create or link contributors, publishers, formats, and language metadata where practical.
14. Optionally create products and product variants when staff confirms store-facing setup.
15. Preserve source/provenance history for imported data.
16. Record audit events for lookup/import actions.
17. Expose external lookup from the Add Item workflow.
18. Prepare the lookup/import workflow for reuse in Phase 7 customer requests and special orders.
19. Establish fixture-based tests that do not call ISBNdb in CI.

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
* Automatic tax category, subdepartment, or merchandise-class assignment.
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

---

## Major Capabilities

Phase 6.5 includes the following capabilities:

| Capability                  | Description                                                                                                                                         |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| ISBNdb source configuration | ShelfStack can configure ISBNdb as an active external catalog source while storing secrets outside normal database configuration.                   |
| API key health check        | Authorized users can verify whether ISBNdb is configured and view basic plan/quota status.                                                          |
| Local-first lookup          | ShelfStack searches local identifiers and catalog records before calling ISBNdb.                                                                    |
| ISBN lookup                 | Staff can scan or enter an ISBN and retrieve an ISBNdb candidate when no confident local match exists.                                              |
| Keyword search              | Staff can search ISBNdb by title, author, keyword, publisher, or subject.                                                                           |
| Candidate normalization     | ISBNdb book responses are mapped into provider-neutral normalized book candidates.                                                                  |
| Lookup persistence          | Lookup request, response status, raw payload, and normalized results are stored for caching and auditability.                                       |
| Candidate preview           | Staff can review title, authors, publisher, date, binding, pages, subjects, synopsis, image, ISBNs, MSRP, and local match status.                   |
| Duplicate detection         | ShelfStack detects likely local matches by ISBN-13, ISBN-10, title/author, and title/publisher/year.                                                |
| Controlled import           | Staff can create or update local records only after reviewing a preview.                                                                            |
| Catalog item import         | ShelfStack can create or enrich catalog items from confirmed ISBNdb candidates.                                                                     |
| Identifier import           | ShelfStack can create ISBN-13 and ISBN-10 identifiers for imported catalog items.                                                                   |
| Contributor import          | ShelfStack can create or link author/contributor records from ISBNdb author names.                                                                  |
| Publisher import            | ShelfStack can create or link publisher records from ISBNdb publisher data.                                                                         |
| Format suggestion           | ShelfStack can map ISBNdb binding values to local formats when a safe mapping exists, or require staff selection.                                   |
| Product creation            | Staff can optionally create a product from an imported catalog item.                                                                                |
| Variant creation            | Staff can optionally create a product variant after providing local selling fields such as subdepartment, condition, price, and inventory behavior. |
| Source provenance           | Imported records retain source and raw payload history.                                                                                             |
| Audit logging               | Lookup, import, link, update, and failure events create audit events.                                                                               |
| Add Item integration        | External lookup is available from the Add Item workflow.                                                                                            |
| Phase 7 readiness           | Customer request and special order workflows can later reuse the same lookup/import services.                                                       |

---

## Internal Phase Breakdown

Phase 6.5 may be implemented as four internal workstreams.

---

## Phase 6.5A: External Catalog Provider Foundation

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
11. External catalog imports can record preview, applied, failed, or skipped import actions.
12. Provider-neutral normalized book result object exists.
13. ISBNdb-specific client code is separated from ShelfStack import logic.
14. Provider errors are converted into consistent ShelfStack error states.
15. Audit events are created for health checks, failed lookups, and failed imports.
16. Tests cover provider configuration, status transitions, and raw payload persistence.

---

## Phase 6.5B: ISBN Lookup, Search, and Normalization

### Purpose

Implement the ISBNdb client and normalize ISBNdb book responses into ShelfStack candidate records.

### Includes

* ISBN normalization
* Local-first ISBN lookup
* ISBNdb `GET /book/{isbn}` lookup
* ISBNdb keyword/title/author search
* Optional advanced book search parameters
* 404 handling as a retryable external miss
* Pagination support for search results
* Search result candidate persistence
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

Phase 6.5B is complete when:

1. ISBN input is normalized before local or external lookup.
2. Invalid ISBN input is rejected before calling ISBNdb.
3. Local ISBN-13 match opens or identifies the existing local catalog record.
4. Local ISBN-10 match opens or identifies the existing local catalog record.
5. ISBNdb is called only when local lookup does not produce a confident match.
6. ISBNdb `GET /book/{isbn}` responses are parsed successfully.
7. ISBNdb 404 responses are stored as `not_found`, not treated as application errors.
8. ISBNdb 404 responses can be retried later.
9. ISBNdb timeout responses are stored as failed lookup attempts.
10. ISBNdb rate-limit responses are stored as rate-limited lookup attempts.
11. Search by title/keyword returns candidate results.
12. Search by author can be performed through supported ISBNdb search parameters.
13. Search by publisher can be performed through supported ISBNdb search parameters.
14. Search by subject can be performed through supported ISBNdb search parameters.
15. Search pagination is supported.
16. Search page size is constrained by ShelfStack defaults.
17. ISBNdb responses are normalized into provider-neutral book candidates.
18. Candidate results persist ISBN-13, ISBN-10, title, authors, publisher, date published, binding, language, pages, synopsis, subjects, MSRP, image URL, and related ISBNs when present.
19. Deprecated ISBNdb fields are not used as primary mapping sources when non-deprecated fields are available.
20. `image_original` is not stored as the durable cover URL because it is temporary.
21. `with_prices=true` is not used by default.
22. Tests cover successful ISBN lookup, not-found lookup, timeout/failure handling, keyword search, normalization, and pagination.

---

## Phase 6.5C: Candidate Preview, Matching, and Controlled Import

### Purpose

Allow staff to review ISBNdb candidates, compare them against local records, and create or enrich ShelfStack catalog records only after confirmation.

### Includes

* Candidate detail/preview page
* Local duplicate detection
* Field-by-field preview
* Existing catalog item link action
* Create catalog item action
* Update existing catalog item action
* Create identifiers
* Create/link contributors
* Create/link publisher
* Suggest or require format
* Suggest language
* Store external subjects as candidate metadata
* Store raw payload snapshot with import
* Preserve local curated data by default
* Explicit overwrite/update choices
* Import audit events
* Import failure handling

### Primary question answered

> Can a staff member safely turn an external candidate into ShelfStack catalog data without polluting or overwriting local records?

### Exit Criteria

Phase 6.5C is complete when:

1. Staff can open a persisted ISBNdb candidate preview.
2. Preview displays title, ISBN-13, ISBN-10, authors, publisher, publication date, binding, pages, language, subjects, synopsis, image URL, MSRP, and related ISBNs when present.
3. Preview clearly labels the source as ISBNdb.
4. Preview shows local match status.
5. Exact local ISBN match is shown as an existing record rather than a new import.
6. Probable duplicate matches are shown before import.
7. Staff can link an ISBNdb candidate to an existing catalog item.
8. Staff can create a new catalog item from a candidate.
9. Staff can update an existing catalog item from a candidate.
10. Updates default to filling blank fields rather than overwriting populated local fields.
11. Staff can explicitly choose to apply external values over local values where allowed.
12. ShelfStack creates ISBN-13 identifier when present.
13. ShelfStack creates ISBN-10 identifier when present.
14. ShelfStack does not create duplicate identifiers.
15. ShelfStack creates or links contributor records from authors.
16. ShelfStack creates or links publisher records from publisher name.
17. ShelfStack maps binding to local format only when a safe mapping exists.
18. ShelfStack requires staff selection when format mapping is ambiguous.
19. ISBNdb subjects are stored as external subject metadata or suggestions, not automatically assigned as store categories.
20. MSRP is treated as suggested list price, not authoritative selling price.
21. Related ISBNs are displayed or stored as related metadata, but do not automatically create records.
22. Import action records created/updated local record IDs.
23. Import action stores source, raw payload, field mapping snapshot, actor, and timestamp.
24. Audit events are created for link, create, update, skip, and failed import actions.
25. Tests cover duplicate detection, create catalog item, link existing, update existing, do-not-overwrite behavior, contributor creation, publisher creation, identifier creation, ambiguous format handling, and audit creation.

---

## Phase 6.5D: Add Item Integration and Optional Product/Variant Creation

### Purpose

Expose external lookup in the operational Add Item workflow and allow staff to continue from bibliographic import into store-facing product and variant setup.

### Includes

* Add Item external lookup entry point
* ISBN quick lookup
* Local-first result behavior
* ISBNdb fallback behavior
* Candidate import flow from Add Item
* Optional product creation
* Optional product variant creation
* Required local store-facing fields
* SKU policy integration
* Subdepartment selection
* Condition selection
* Selling price entry
* Inventory behavior selection
* Tax behavior through existing subdepartment/tax setup
* Return to Add Item confirmation/result page
* Reusable service entry points for Phase 7 request intake

### Primary question answered

> Can a bookseller start with an ISBN or title and end with a usable ShelfStack catalog/product/variant record?

### Exit Criteria

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

## Models Introduced

Phase 6.5 introduces the following tables:

| Table                      | Purpose                                                                                            |
| -------------------------- | -------------------------------------------------------------------------------------------------- |
| `external_data_sources`    | Configures external catalog data providers such as ISBNdb.                                         |
| `external_lookup_requests` | Records each external lookup attempt, including query, endpoint, status, response code, and actor. |
| `external_lookup_results`  | Stores normalized candidate records returned by an external provider.                              |
| `external_catalog_imports` | Records user-confirmed import, link, update, skip, or failed import actions.                       |

Optional/deferred tables:

| Table                          | Status            | Notes                                                                                                     |
| ------------------------------ | ----------------- | --------------------------------------------------------------------------------------------------------- |
| `external_identifiers`         | Optional/deferred | Useful as a generalized source-link table across catalog items, products, variants, and future providers. |
| `external_subject_suggestions` | Optional/deferred | Useful if ISBNdb subjects need structured review/mapping later.                                           |
| `external_provider_logs`       | Optional/deferred | Useful if provider diagnostics need more detail than lookup request records.                              |
| `external_image_assets`        | Deferred          | Only needed if cover images are downloaded/stored locally.                                                |
| `external_sync_runs`           | Deferred          | Only needed for future bulk enrichment or update-feed synchronization.                                    |

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
retry_after_at
requested_by_user_id
started_at
completed_at
created_at
updated_at
```

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
* `local_*` fields can cache match results, but should be refreshable.

---

### `external_catalog_imports`

Tracks user-confirmed import actions.

```text
id
external_lookup_result_id
external_data_source_id
status
import_mode
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
preview
applied
failed
skipped
```

Suggested `import_mode` values:

```text
create_catalog_item
update_existing_catalog_item
link_existing_catalog_item
create_product
create_product_variant
skip
```

---

## Permissions Introduced

Phase 6.5 introduces the following permissions:

| Permission                          | Purpose                                                            |
| ----------------------------------- | ------------------------------------------------------------------ |
| `external_catalog.access`           | Access external catalog lookup workspace or Add Item lookup panel. |
| `external_catalog.search`           | Search external catalog sources.                                   |
| `external_catalog.import`           | Create local records from external candidates.                     |
| `external_catalog.update_existing`  | Apply external candidate data to an existing local record.         |
| `external_catalog.link_existing`    | Link an external candidate to an existing local record.            |
| `external_catalog.view_raw_payload` | View raw provider response payloads.                               |
| `external_catalog.configure`        | Configure provider settings and health checks.                     |

Suggested permission defaults:

| User type             | Suggested access                                           |
| --------------------- | ---------------------------------------------------------- |
| Frontline bookseller  | Search and import with restricted update behavior.         |
| Buyer/inventory staff | Search, import, link existing, and create product/variant. |
| Manager/admin         | Configure provider, update existing, and view raw payload. |

---

## Services Introduced

Phase 6.5 introduces the following service objects:

| Service                                       | Purpose                                                               |
| --------------------------------------------- | --------------------------------------------------------------------- |
| `ExternalCatalog::Provider::IsbndbClient`     | Low-level ISBNdb HTTP client.                                         |
| `ExternalCatalog::Provider::IsbndbNormalizer` | Converts ISBNdb responses into normalized book candidates.            |
| `ExternalCatalog::CheckProviderHealth`        | Calls provider health/quota endpoint and records provider status.     |
| `ExternalCatalog::LookupByIsbn`               | Local-first ISBN lookup with ISBNdb fallback.                         |
| `ExternalCatalog::SearchBooks`                | Searches local catalog and external book candidates.                  |
| `ExternalCatalog::PersistLookupResult`        | Stores normalized candidates and raw payloads.                        |
| `ExternalCatalog::DuplicateDetector`          | Finds exact and probable local matches.                               |
| `ExternalCatalog::ImportPreview`              | Builds field-by-field preview for user confirmation.                  |
| `ExternalCatalog::ImportCandidate`            | Applies confirmed candidate data to local records.                    |
| `ExternalCatalog::CatalogItemBuilder`         | Creates or updates catalog item data.                                 |
| `ExternalCatalog::ContributorMapper`          | Creates or links contributor records.                                 |
| `ExternalCatalog::PublisherMapper`            | Creates or links publisher records.                                   |
| `ExternalCatalog::FormatMapper`               | Maps ISBNdb binding values to ShelfStack formats where safe.          |
| `ExternalCatalog::ProductBuilder`             | Optionally creates a product from an imported catalog item.           |
| `ExternalCatalog::VariantBuilder`             | Optionally creates a product variant using local store-facing fields. |

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

---

### ISBNdb 404 handling

An ISBNdb 404 for `GET /book/{isbn}` should be treated as a retryable external miss, not as proof that the ISBN is invalid.

Recommended status:

```text
not_found
```

Recommended retry behavior:

```text
retry_after_at = 24.hours.from_now
```

User-facing message:

> No ISBNdb match found. ISBNdb may add new records later. You can add the item manually or try again later.

---

### ISBNdb pricing behavior

Do not enable ISBNdb `with_prices=true` by default.

Reasons:

* It may require a higher ISBNdb plan.
* It increases response time.
* It fetches vendor prices, not necessarily publisher MSRP.
* Search and bulk endpoints do not return pricing.
* ShelfStack local pricing remains authoritative.

Use the ISBNdb `msrp` field, when present, as suggested list price only.

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
* Add missing contributors.
* Add missing publisher if blank.
* Add external subjects as suggestions.
* Show conflicting values in preview.
* Require explicit confirmation before overwriting local data.

Avoid automatic overwrite of curated local data.

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

The following are intentionally deferred:

| Item                               | Reason                                                                 |
| ---------------------------------- | ---------------------------------------------------------------------- |
| Bulk ISBN enrichment               | Useful later, but interactive lookup is the MVP.                       |
| Premium update feed sync           | Requires higher plan and background synchronization design.            |
| `with_prices=true` support         | Higher plan/performance impact and not core bibliographic metadata.    |
| Cover image asset storage          | Requires image caching, licensing, refresh, and storage decisions.     |
| Automatic subject/category mapping | Risky; store categories are curated operational data.                  |
| Automatic pricing updates          | Local pricing should remain authoritative.                             |
| Automatic vendor sourcing          | Vendor data belongs to purchasing/sourcing workflows.                  |
| Related edition auto-creation      | Could create duplicate/noisy records without staff review.             |
| Multi-provider merge logic         | Only ISBNdb is in scope for this phase.                                |
| Customer request integration       | Phase 6.5 prepares the service; Phase 7 uses it.                       |
| Buyback lookup integration         | Useful later; buyback workflow is not in scope yet.                    |
| Non-book lookup                    | ISBNdb is book-focused; media/game lookup should use future providers. |
| Public/customer-facing search      | This is an internal staff workflow.                                    |

---

## Final Phase 6.5 Exit Criteria

Phase 6.5 is complete when all of the following are true.

### Provider Configuration

1. ISBNdb is represented as an external data source.
2. ISBNdb base URL is configurable or seeded.
3. ISBNdb API key is loaded from credentials/environment/secrets.
4. API key is not stored in plain database fields.
5. Authorized user can check ISBNdb provider health.
6. Provider health check records last status and timestamp.
7. Provider health check records plan limit total, spent, and remaining when available.
8. Provider configuration screens are permission-protected.

### Lookup Requests

1. ShelfStack can create external lookup request records.
2. Lookup requests store source, lookup type, query, normalized query, request path, request params, actor, and timestamps.
3. Lookup requests support `pending`, `completed`, `not_found`, `failed`, `rate_limited`, and `cancelled` statuses.
4. Successful lookups store response status and completion timestamp.
5. Failed lookups store error code/message.
6. Not-found ISBN lookups are stored as retryable misses.
7. Lookup requests retain enough information for debugging and audit review.

### ISBN Lookup

1. Staff can scan or enter an ISBN.
2. ISBN input is normalized.
3. Invalid ISBN input is rejected before external lookup.
4. ShelfStack searches local ISBN identifiers first.
5. Exact local ISBN match is shown before any external import.
6. ISBNdb is called when no confident local match exists.
7. ISBNdb book response is parsed.
8. ISBNdb 404 is handled as `not_found`.
9. ISBNdb timeout/failure is handled without crashing the workflow.
10. ISBNdb rate-limit response is handled without crashing the workflow.

### Search

1. Staff can search by title/keyword.
2. Staff can search by author where supported.
3. Staff can search by publisher where supported.
4. Staff can search by subject where supported.
5. Search results are paginated.
6. Search results clearly identify ISBNdb as the source.
7. Search results show enough data to distinguish editions.
8. Local matches are shown or badged when detected.
9. Search does not automatically create local records.

### Normalization

1. ISBNdb responses are converted into provider-neutral book candidates.
2. Candidate stores ISBN-13.
3. Candidate stores ISBN-10 when present.
4. Candidate stores title.
5. Candidate stores authors.
6. Candidate stores publisher.
7. Candidate stores publication date.
8. Candidate stores binding/format candidate.
9. Candidate stores language.
10. Candidate stores page count.
11. Candidate stores synopsis/description when present.
12. Candidate stores subjects.
13. Candidate stores MSRP as suggested list price when present.
14. Candidate stores image URL when present.
15. Candidate stores related ISBNs when present.
16. Candidate stores raw payload JSON.

### Matching and Duplicate Detection

1. Exact ISBN-13 match is detected.
2. Exact ISBN-10 match is detected.
3. Probable title/author duplicate is detected.
4. Probable title/publisher/year duplicate is detected.
5. Candidate preview displays local match status.
6. Import is blocked or redirected when exact duplicate exists unless user chooses link/update.
7. Duplicate detection is refreshable before import.

### Candidate Preview

1. Candidate preview page exists.
2. Preview displays bibliographic fields.
3. Preview displays source provider.
4. Preview displays raw payload only to authorized users.
5. Preview shows local matches and conflicts.
6. Preview distinguishes blank-field fills from overwrites.
7. Preview allows create, link, update, skip, or cancel actions according to permission.

### Catalog Import

1. Staff can create a catalog item from an ISBNdb candidate.
2. Staff can link an ISBNdb candidate to an existing catalog item.
3. Staff can update an existing catalog item from an ISBNdb candidate.
4. Existing local data is not overwritten by default.
5. Staff can explicitly approve allowed overwrites.
6. ISBN-13 identifier is created when present.
7. ISBN-10 identifier is created when present.
8. Duplicate identifiers are not created.
9. Contributors are created or linked.
10. Publisher is created or linked.
11. Format is mapped when safe.
12. Ambiguous format requires staff selection.
13. Language is mapped when safe.
14. External subjects are stored as suggestions/metadata.
15. Related ISBNs are stored or displayed without auto-creation.
16. MSRP is treated as suggested list price.
17. Import action stores field mapping snapshot.
18. Import action stores raw payload snapshot.
19. Import action records actor and timestamp.

### Optional Product and Variant Creation

1. Staff can create a product after catalog import.
2. Product creation is optional.
3. Product creation requires staff confirmation.
4. Staff can create a product variant after product creation.
5. Variant creation is optional.
6. Variant creation requires subdepartment.
7. Variant creation requires condition.
8. Variant creation requires selling price.
9. Variant creation requires inventory behavior.
10. Variant creation uses local SKU rules.
11. Variant creation does not infer tax behavior directly from ISBNdb.
12. Variant creation records audit events.

### Add Item Integration

1. Add Item screen exposes external catalog lookup.
2. ISBN lookup can be launched from Add Item.
3. Keyword search can be launched from Add Item.
4. Local match opens or links to the existing ShelfStack item.
5. External match opens candidate preview.
6. Successful import returns the user to a sensible Add Item continuation path.
7. Add Item lookup respects permissions.
8. Add Item lookup is usable with barcode scanner input.

### Auditability

1. Provider health checks create audit events when appropriate.
2. Lookup failures create audit events or persisted diagnostic records.
3. Candidate imports create audit events.
4. Candidate links create audit events.
5. Candidate updates create audit events.
6. Product/variant creation from external candidate creates audit events.
7. Audit events include actor, event name, timestamp, source, auditable record, and store/workstation/session context when available.
8. Raw provider payloads are not editable through normal UI.

### Authorization

1. Permissions are seeded.
2. Unauthorized users cannot access external catalog lookup.
3. Unauthorized users cannot import candidates.
4. Unauthorized users cannot update existing catalog records from external candidates.
5. Unauthorized users cannot configure ISBNdb.
6. Unauthorized users cannot view raw provider payloads.
7. Store-scoped authorization works where store context is required.

### Testing

1. ISBN normalization tests pass.
2. ISBNdb client fixture tests pass.
3. Provider health check tests pass.
4. Lookup request status tests pass.
5. Normalization tests pass.
6. Duplicate detection tests pass.
7. Candidate preview tests pass.
8. Catalog import tests pass.
9. Identifier import tests pass.
10. Contributor import tests pass.
11. Publisher import tests pass.
12. Format mapping tests pass.
13. Do-not-overwrite-local-data tests pass.
14. Add Item integration tests pass.
15. Authorization tests pass.
16. Audit tests pass.
17. Seed idempotency tests pass.
18. No CI test calls the live ISBNdb API.
