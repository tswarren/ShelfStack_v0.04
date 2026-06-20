# Phase 6.5 External Catalog Lookup — Completion Summary

## Status

Phase 6.5 MVP (workstreams 6.5A–D) is implemented. Phase 6.5E keyword search remains deferred.

## Delivered

### Documentation

- `docs/specifications/phase-6.5-external-catalog-lookup-spec.md`
- `docs/specifications/phase-6.5-data-model.md`
- `docs/specifications/phase-6.5-test-plan.md`
- `docs/roadmap.md` — Phase 6.5 summary row and phase section
- `docs/operations/foundation-runbook.md` — ISBNdb API key configuration
- Roadmap doc synced: removed `continue_add_item` from import `action_type` values

### Data model

Migration `20250627120000_create_phase65_external_catalog_lookup.rb`:

- `external_data_sources`
- `external_lookup_requests` (no `retry_after_at`)
- `external_lookup_results`
- `external_catalog_imports`

Models with enum validations; partial unique index for applied import idempotency.

### Permissions and seeds

- `db/seeds/phase65_permissions.rb` — seven `items.external_lookup.*` permissions
- Included in `db/seeds.rb` and `seed_minimal_permissions!`
- Idempotent `external_data_sources` row for `isbndb` in `db/seeds.rb`

### Services (`ExternalCatalog::*`)

| Service | Purpose |
| ------- | ------- |
| `LookupByIsbn` | Local-first ISBN lookup, synchronous ISBNdb fallback |
| `LocalIsbnMatch` | Local identifier resolution |
| `Provider::IsbndbClient` | HTTP client (2s open / 5s read timeouts) |
| `Provider::IsbndbNormalizer` | Provider JSON → `BookCandidate` |
| `PersistLookupResult` | Audit persistence |
| `DuplicateDetector` | Exact ISBN-13/ISBN-10 matching |
| `ImportPreview` | Field diff, format gate, allowed actions |
| `ImportCandidate` | Create / link / fill-blank / skip apply |
| `CatalogItemBuilder` | New catalog item + identifiers |
| `MetadataMapper` | Candidate → catalog attributes |
| `CheckProviderHealth` | Manual `/key` health check with 30-minute cache |

Shared refactor: `CatalogImport::BindingFormatMapper` extracted; `IngramCatalogImport::FormatMapper` delegates to it.

### UI and routes

- `Setup::ExternalDataSourcesController` — provider list and health check
- `Items::ExternalLookupController` — lookup, preview, import
- Add Item wizard: `choose_path` → **`identify`** → `item_details` → `selling_setup` → `sellable_sku` (catalog-linked)
- Post-import handoff via `session[:add_item_draft]` → `item_details`

### Tests

Fixture JSON under `test/fixtures/isbndb/`; no live ISBNdb in CI.

Phase 6.5 test files (29 tests, all passing):

- Model, lookup, import flow, permissions seed
- Setup health check controller
- Add Item external lookup integration
- Existing Add Item tests updated for `identify` redirect

Run:

```bash
./dev/rails-docker bin/rails test test/models/external_catalog_models_test.rb test/services/external_catalog/ test/seeds/phase65_permissions_seed_test.rb test/controllers/setup/external_data_sources_controller_test.rb test/integration/items_add_item_external_lookup_test.rb test/integration/items_add_item_controller_test.rb
```

## Configuration

Set ISBNdb API key via Rails credentials (`isbndb.api_key`) or `ENV["ISBNDB_API_KEY"]`.

## Out of scope (unchanged)

- Phase 6.5E keyword search
- POS external lookup
- Lookup-result caching and automatic retry
- MSRP → price field mapping

## Exit criteria

All items in `docs/roadmap/phase-6.5-external-catalog-lookup.md` Phase 6.5 Exit Criteria are addressed by the implementation and automated tests above.
