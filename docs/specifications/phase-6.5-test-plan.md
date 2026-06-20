# Phase 6.5 External Catalog Lookup Test Plan

## Purpose

Test coverage expectations for Phase 6.5 MVP. All external HTTP uses fixture JSON — no live ISBNdb in CI.

See also:

```text
docs/specifications/phase-6.5-external-catalog-lookup-spec.md
docs/roadmap/phase-6.5-external-catalog-lookup.md
```

---

# 1. Test Infrastructure

- Stub `ExternalCatalog::Provider::IsbndbClient` in service and controller tests.
- Fixtures under `test/fixtures/isbndb/`: success, not_found, rate_limit, timeout, missing_publisher, ambiguous_binding.
- Phase 6.5 permissions in `seed_minimal_permissions!` via `Seeds::Phase65Permissions`.
- Create `external_data_sources` rows in tests that need them — not in global test helper.

---

# 2. Model Tests

| Area | Cases |
| ---- | ----- |
| Validations | status/action_type/lookup_type enums |
| Associations | request → result → import chain |
| Idempotency index | duplicate applied import blocked at DB level |

---

# 3. Service Tests

## 3.1 `LookupByIsbn`

- Invalid ISBN rejected before client call
- Local match short-circuits without HTTP
- 200 → completed result persisted
- 404 → not_found
- 429 → rate_limited
- Timeout → failed
- Each staff submit creates new request row

## 3.2 `IsbndbNormalizer`

- Maps fixture success to candidate fields
- Handles missing publisher, ambiguous binding

## 3.3 `DuplicateDetector`

- Exact ISBN-13 match
- Exact ISBN-10 match
- No fuzzy matching

## 3.4 `ImportPreview`

- Field diff for existing catalog item
- Blocks apply when format unresolved
- MSRP display only

## 3.5 `ImportCandidate`

- create_catalog_item creates item + identifiers
- link_existing_catalog_item attaches metadata
- fill_blank_existing_catalog_item updates only blank fields
- Double apply does not duplicate catalog items
- Race: duplicate appears between preview and apply → block create

## 3.6 `CheckProviderHealth`

- Updates source health fields
- Respects cache window

---

# 4. Authorization Tests

| Action | Permission required |
| ------ | ------------------- |
| identify step | `items.external_lookup.access` |
| POST lookup | `items.external_lookup.search` |
| GET preview | `items.external_lookup.access` |
| POST import create | `items.external_lookup.import` |
| POST import link | `items.external_lookup.link_existing` |
| POST import fill-blank | `items.external_lookup.update_existing` |
| raw payload | `items.external_lookup.view_raw_payload` |
| health check | `items.external_lookup.configure` |

Denial redirects or 403 for unauthorized users.

---

# 5. Controller / Integration Tests

## 5.1 Add Item flow

```text
choose_path (catalog_linked)
→ identify (ISBN entry)
→ preview
→ import (create)
→ item_details (pre-filled draft)
→ selling_setup
```

- Permission denial at identify and lookup
- Local match banner on identify step
- Scanner-friendly single ISBN field

## 5.2 Setup health check

- Authorized user can run health check
- Unauthorized user blocked

---

# 6. Seed Tests

- `Seeds::Phase65Permissions` idempotent
- `external_data_sources` isbndb row idempotent in `db:seed`

---

# 7. Audit Tests

- Lookup failure events recorded
- Import success/failure events recorded
- catalog_item.created on new import

---

# 8. Exit Criteria Mapping

All items in Phase 6.5 Exit Criteria (`docs/roadmap/phase-6.5-external-catalog-lookup.md`) must have at least one automated test or seed verification.
