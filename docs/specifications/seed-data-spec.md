# Seed Data Specification

Reference classification seed files live in `db/seeds/data/` as CSV. Validate before seeding:

```bash
./dev/rails-docker rails shelfstack:seeds:validate
```

## Load order

1. `tax_categories.csv`
2. `departments.csv`
3. `sub_departments.csv` (after tax categories and departments)
4. `store_tax_rates.csv` (after Phase 1 stores)
5. `store_tax_mappings.csv`
6. `display_locations.csv`
7. `store_categories.csv` (after subdepartments and display locations)
8. `bisac.csv` (optional; set `SEED_BISAC=1` or omit `SKIP_BISAC_SEED` in non-test env)
9. Genre scheme trees (v0.04-16) — after `CategoryScheme::PURPOSES` extended and genre importer wired:
   * `music_genres.csv` → scheme `music_genres`
   * `video_genres.csv` → scheme `video_genres`
   * `video_game_genres.csv` → scheme `video_game_genres`
   * `sideline_genres.csv` → scheme `sideline_genres`

Importer: [`db/seeds/concerns/csv_classification_importer.rb`](../db/seeds/concerns/csv_classification_importer.rb) (store categories today; genre trees use the same two-pass `node_key` / `parent_node_key` pattern in v0.04-16).

## File formats

### tax_categories.csv

| Column | Required |
|--------|----------|
| name | yes (FK target for mappings and subdepartments) |
| short_name | yes |
| sort_order | yes |

### departments.csv

| Column | Required |
|--------|----------|
| department_number | yes (3 digits) |
| name | yes |
| short_name | yes |
| gl_account_code | no |

### sub_departments.csv

| Column | Required |
|--------|----------|
| sub_department_key | yes (unique stable key) |
| department_number | yes |
| name | yes (unique) |
| short_name | yes (max 20; duplicates allowed) |
| default_pricing_model | no |
| tax_category_name | yes (matches tax_categories.name) |
| vendor_returnable_default | no (TRUE/FALSE) |
| buyback_allowed | no (TRUE/FALSE) |
| default_margin_target_bps | no (0–10000; margin basis points for inventory cost estimation) |

### store_tax_rates.csv

| Column | Required |
|--------|----------|
| store_number | yes |
| rate_name | yes |
| short_name | yes |
| tax_identifier | yes |
| tax_rate_bps | yes |

### store_tax_mappings.csv

| Column | Required |
|--------|----------|
| store_number | yes |
| tax_category_name | yes (full name, not short_name) |
| store_tax_rate_name | yes |
| effective_on | yes (YYYY-MM-DD) |
| ends_on | no |

### display_locations.csv

| Column | Required |
|--------|----------|
| short_name | yes (unique) |
| name | yes |
| parent_short_name | no |
| sort_order | yes |

### store_categories.csv

| Column | Required |
|--------|----------|
| department_number | no (metadata only) |
| node_key | yes (unique per scheme) |
| name | yes |
| parent_node_key | no |
| sort_order | yes |
| default_sub_department_key | no |
| default_display_location_short_name | no |

### bisac.csv

| Column | Required |
|--------|----------|
| code | yes |
| heading | yes |

BISAC nodes import flat (`parent_id` nil).

### Genre category trees (v0.04-16)

Shared format for `music_genres.csv`, `video_genres.csv`, `video_game_genres.csv`, and `sideline_genres.csv`. Each file loads into its own `CategoryScheme` (`scheme_key` matches filename stem).

| Column | Required |
|--------|----------|
| node_key | yes (unique per scheme; lowercase stable key) |
| name | yes (staff-facing label) |
| parent_node_key | no (blank = root node) |
| sort_order | no (importer may assign `row_index * 1000` when absent) |

Rules:

* `parent_node_key` must reference an exact `node_key` in the **same file** (full hierarchical key — not a shortened suffix).
* No duplicate `node_key` values within a file.
* Genre trees are hierarchical (depth typically 2–3); BISAC remains flat.
* Hierarchical genre keys may exceed 30 characters (current `store_categories` keys stay ≤30). v0.04-16 applies **scheme-aware** `CategoryNode` validation: **128** max for genre schemes — see [v0.04-16 data model](../v0.04/v0.04-16-product-entry-revamp/data-model.md#category-node-keys-genre-trees). Do **not** shorten seed CSV keys.

| File | scheme_key | ~rows | Used for item kinds |
|------|------------|------:|---------------------|
| `music_genres.csv` | `music_genres` | 660 | Recorded Music |
| `video_genres.csv` | `video_genres` | 188 | Video |
| `video_game_genres.csv` | `video_game_genres` | 130 | Video Game |
| `sideline_genres.csv` | `sideline_genres` | 681 | Sideline, Calendar (theme picker) |

Assignments use existing `categorizations` on `Product` (not `Categorization` date/rank extensions).

## FK rules

- Reference stable keys (`department_number`, `sub_department_key`, `tax_category_name`, `node_key`, `short_name`) not surrogate IDs.
- Store category `node_key` is globally unique within the store_categories scheme.
- Subdepartment `short_name` may repeat; `sub_department_key` and `name` must be unique.
