# Phase 6.5 External Catalog Lookup Functional Specification

## Purpose

This specification defines functional behavior for ShelfStack Phase 6.5 MVP: real-time ISBN local-first lookup via ISBNdb, candidate preview, controlled catalog import, and Add Item wizard integration.

Phase 6.5E keyword search is out of scope.

See also:

```text
docs/specifications/phase-6.5-data-model.md
docs/specifications/phase-6.5-test-plan.md
docs/roadmap/phase-6.5-external-catalog-lookup.md
```

---

# 1. Core Principles

- External providers supply **candidate metadata**; ShelfStack remains authoritative for catalog curation, pricing, and sellable setup.
- Lookups are **real-time, synchronous, staff-initiated** — no automatic retry, no lookup-result caching.
- Persist lookup requests and results for **audit and diagnostics** only.
- Local ISBN identifiers are searched **before** any external call.
- Import rows record **staff-confirmed actions** only — not previews or wizard navigation.
- MSRP from providers is **display/snapshot only** — never written to `list_price_cents` or variant prices.

---

# 2. Permissions

Namespace: `items.external_lookup.*`

| Permission | Purpose |
| ---------- | ------- |
| `items.external_lookup.access` | Access Add Item identify step and preview |
| `items.external_lookup.search` | Submit ISBN lookup |
| `items.external_lookup.import` | Create catalog item from candidate |
| `items.external_lookup.link_existing` | Link candidate to existing catalog item |
| `items.external_lookup.update_existing` | Fill-blank update on existing catalog item |
| `items.external_lookup.view_raw_payload` | View raw provider JSON |
| `items.external_lookup.configure` | Configure provider and run health checks |

---

# 3. Provider Configuration

## 3.1 ISBNdb source

- Represented as `external_data_sources` row with `source_key: isbndb`.
- API key from `Rails.application.credentials.dig(:isbndb, :api_key)` with `ENV["ISBNDB_API_KEY"]` fallback.
- Never store API keys in `configuration_json`.

## 3.2 Health check

- Manual from Setup (`Setup::ExternalDataSourcesController`).
- Calls ISBNdb `GET /key` endpoint.
- Updates `last_health_check_*` fields on the source record.
- Reuse cached status for 15–60 minutes unless manually refreshed.
- Protected by `items.external_lookup.configure`.

## 3.3 MVP endpoints

- `GET /book/{isbn}` for lookup
- `GET /key` for health check only

---

# 4. ISBN Lookup Flow

Service: `ExternalCatalog::LookupByIsbn`

```text
Staff submits ISBN
→ normalize via CatalogIdentifierService
→ reject invalid before external call
→ local match via IngramCatalogImport::IdentifierResolver patterns
→ if local hit: return :local_match (no ISBNdb call)
→ if miss: IsbndbClient#fetch_book (open 2s / read 5s)
→ IsbndbNormalizer → PersistLookupResult
```

## 4.1 Status mapping

| HTTP / outcome | Request status |
| -------------- | -------------- |
| 200 with book | `completed` |
| 404 | `not_found` |
| 429 | `rate_limited` |
| timeout / error | `failed` |

No in-request retry. Staff must submit again manually.

## 4.2 Audit events

| Event | When |
| ----- | ---- |
| `external_lookup.completed` | Successful external lookup |
| `external_lookup.not_found` | ISBN not found at provider |
| `external_lookup.failed` | Timeout or error |
| `external_lookup.rate_limited` | HTTP 429 |
| `external_lookup.local_match` | Local catalog match short-circuit |

---

# 5. Preview and Duplicate Detection

Service: `ExternalCatalog::ImportPreview`

- Renders from `external_lookup_results` — no import row.
- Shows bibliographic fields, source label, MSRP (display), local duplicate status.
- `ExternalCatalog::DuplicateDetector` uses exact ISBN-13/ISBN-10 on `catalog_item_identifiers.normalized_identifier`.
- Block Apply when `format_id` cannot be resolved — staff must pick format in preview UI.

---

# 6. Import Actions

Service: `ExternalCatalog::ImportCandidate`

| action_type | Permission | Behavior |
| ----------- | ---------- | -------- |
| `create_catalog_item` | `import` | New catalog item via `CatalogItemBuilder` |
| `link_existing_catalog_item` | `link_existing` | Attach identifiers/metadata to existing item |
| `fill_blank_existing_catalog_item` | `update_existing` | Update only blank fields on existing item |
| `skip` | `access` | Record skipped action |

Import row status: `applied`, `failed`, or `skipped`.

## 6.1 Rules

- Identifiers via `CatalogIdentifierService`.
- Authors/publisher via `MetadataMapper` and `MetadataParser`.
- Binding/format via shared `CatalogImport::BindingFormatMapper`.
- Duplicate detection re-run inside apply transaction.
- Repeat apply for same result must not create duplicate catalog items or identifiers.
- MSRP stored on snapshots only.

## 6.2 Audit events

| Event | When |
| ----- | ---- |
| `external_lookup.imported` | Successful apply |
| `external_lookup.import_failed` | Apply failure |
| `catalog_item.created` | New catalog item |
| `catalog_item.updated` | Fill-blank or link update |

---

# 7. Add Item Integration

Wizard steps for catalog-linked path:

```text
choose_path → identify → item_details → selling_setup → sellable_sku
```

- `identify` requires `items.external_lookup.access`; lookup submit requires `items.external_lookup.search`.
- After successful import: update `session[:add_item_draft]` with `catalog_item_id` and redirect to `item_details`.
- Wizard navigation handoff does **not** create an `external_catalog_imports` row.
- Non-catalog path skips `identify`.

---

# 8. Controllers

| Controller | Actions |
| ---------- | ------- |
| `Items::ExternalLookupController` | `lookup`, `preview`, `import` |
| `Setup::ExternalDataSourcesController` | `index`, `health_check` |

Raw payload partial gated by `items.external_lookup.view_raw_payload`.

---

# 9. Out of Scope (MVP)

- Keyword/title/author search (6.5E)
- POS external lookup
- Fuzzy duplicate detection
- Per-field overwrite matrix
- MSRP → price field mapping
- Lookup-result caching
- Automatic retry / background jobs
- `continue_add_item` import action type
