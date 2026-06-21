# Phase 6.5 External Catalog Lookup Data Model

## Purpose

Tables, enums, and indexes for Phase 6.5 MVP external catalog lookup.

See also:

```text
docs/specifications/phase-6.5-external-catalog-lookup-spec.md
docs/roadmap/phase-6.5-external-catalog-lookup.md
```

---

# 1. Tables

## 1.1 `external_data_sources`

| Column | Type | Notes |
| ------ | ---- | ----- |
| `source_key` | string | Unique; includes `isbndb` |
| `name` | string | Display name |
| `base_url` | string | Provider base URL |
| `active` | boolean | Default true |
| `last_health_check_at` | datetime | |
| `last_health_check_status` | string | e.g. `ok`, `failed` |
| `last_plan_limit_total` | integer | From `/key` response |
| `last_plan_limit_spent` | integer | |
| `last_plan_limit_left` | integer | |
| `configuration_json` | jsonb | Non-secret config only |

## 1.2 `external_lookup_requests`

| Column | Type | Notes |
| ------ | ---- | ----- |
| `external_data_source_id` | bigint FK | |
| `lookup_type` | string | MVP: `isbn`, `key_check` |
| `query` | string | Raw staff input |
| `normalized_query` | string | Normalized ISBN |
| `request_path` | string | API path |
| `request_params_json` | jsonb | |
| `status` | string | See enums |
| `response_status_code` | integer | |
| `error_code` | string | |
| `error_message` | text | |
| `requested_by_user_id` | bigint FK users | |
| `started_at` | datetime | |
| `completed_at` | datetime | |

No `retry_after_at`.

## 1.3 `external_lookup_results`

| Column | Type | Notes |
| ------ | ---- | ----- |
| `external_lookup_request_id` | bigint FK | |
| `source_key` | string | |
| `external_identifier` | string | Usually ISBN-13 |
| `isbn10` | string | |
| `isbn13` | string | |
| `title` | string | |
| `subtitle` | string | |
| `authors_snapshot` | jsonb | |
| `publisher_snapshot` | jsonb | |
| `date_published_snapshot` | string | |
| `binding_snapshot` | string | |
| `language_snapshot` | string | |
| `pages` | integer | |
| `msrp_cents` | integer | Display only |
| `currency_code` | string | |
| `image_url` | string | |
| `synopsis` | text | |
| `excerpt` | text | |
| `subjects_snapshot` | jsonb | |
| `dewey_decimal_snapshot` | string | |
| `dimensions_snapshot` | jsonb | |
| `other_isbns_snapshot` | jsonb | |
| `raw_payload_json` | jsonb | Full provider response |
| `confidence_score` | decimal | Optional |
| `local_catalog_item_id` | bigint FK | Match at lookup time |
| `local_product_id` | bigint FK | Optional |
| `local_product_variant_id` | bigint FK | Optional |
| `selected` | boolean | Default false |

## 1.4 `external_catalog_imports`

| Column | Type | Notes |
| ------ | ---- | ----- |
| `external_lookup_result_id` | bigint FK | |
| `external_data_source_id` | bigint FK | |
| `status` | string | `applied`, `failed`, `skipped` |
| `action_type` | string | See enums |
| `imported_by_user_id` | bigint FK users | |
| `catalog_item_id` | bigint FK | |
| `product_id` | bigint FK | Optional |
| `product_variant_id` | bigint FK | Optional |
| `error_message` | text | |
| `field_mapping_snapshot` | jsonb | |
| `raw_payload_json` | jsonb | |
| `applied_at` | datetime | |

---

# 2. Enums

## 2.1 `external_lookup_requests.status`

```text
pending
completed
not_found
failed
rate_limited
cancelled
```

## 2.2 `external_lookup_requests.lookup_type`

MVP uses `isbn` and `key_check`. Reserved: `keyword`, `advanced`, `bulk`, `feed`.

## 2.3 `external_catalog_imports.status`

```text
applied
failed
skipped
```

## 2.4 `external_catalog_imports.action_type`

```text
create_catalog_item
link_existing_catalog_item
fill_blank_existing_catalog_item
skip
```

---

# 3. Indexes

```text
external_data_sources.source_key                    UNIQUE

external_lookup_requests:
  (external_data_source_id, lookup_type, normalized_query)
  (status)
  (requested_by_user_id)
  (created_at)

external_lookup_results:
  (external_lookup_request_id)
  (source_key, external_identifier)
  (isbn13)
  (isbn10)
  (local_catalog_item_id)

external_catalog_imports:
  (external_lookup_result_id)
  (catalog_item_id)
  (imported_by_user_id)
  (applied_at)
  UNIQUE (external_lookup_result_id, catalog_item_id, action_type)
    WHERE status = 'applied' AND action_type IN (
      'create_catalog_item',
      'link_existing_catalog_item',
      'fill_blank_existing_catalog_item'
    )
```

---

# 4. Relationships

```text
ExternalDataSource
  has_many :external_lookup_requests
  has_many :external_catalog_imports

ExternalLookupRequest
  belongs_to :external_data_source
  belongs_to :requested_by_user, class_name: "User"
  has_one :external_lookup_result

ExternalLookupResult
  belongs_to :external_lookup_request
  belongs_to :local_catalog_item, class_name: "CatalogItem", optional: true
  has_many :external_catalog_imports

ExternalCatalogImport
  belongs_to :external_lookup_result
  belongs_to :external_data_source
  belongs_to :imported_by_user, class_name: "User"
  belongs_to :catalog_item, optional: true
```
