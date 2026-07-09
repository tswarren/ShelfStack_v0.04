# v0.04-17 Product Feature Assignments — Data Model

## Status

**Draft**

Spec: [spec.md](spec.md)

---

## Architecture

```text
category_schemes
  └── category_nodes                         # durable feature vocabulary

product_feature_programs                   # optional campaign instance
  └── category_node_id (optional template)

product_feature_assignments                # participation
  ├── category_node_id (xor program)
  ├── product_feature_program_id
  ├── product_id
  └── product_variant_id (optional)
```

**Identity rule:** assignment must have `category_node_id` **or** `product_feature_program_id` (exactly one in normal operation). If program is present, assignment should not duplicate the program's template node.

---

## Schema changes

### 1. Extend `category_schemes.purpose`

Add to `CategoryScheme::PURPOSES`:

```text
awards
featured_lists
book_clubs
display_programs
promotion_programs
reading_lists
review_sources
event_series
```

Feature schemes are **not** `store_categories` or `bisac`.

### 2. `product_feature_programs`

```text
product_feature_programs
  id
  category_node_id          bigint FK category_nodes, null
  program_kind              string, not null
  name                      string, not null
  short_name                string, null
  description               text, null
  store_id                  bigint FK stores, null
  display_location_id       bigint FK display_locations, null
  starts_on                 date, null
  ends_on                   date, null
  source                    string, null
  source_url                string, null
  metadata                  jsonb, not null, default {}
  active                    boolean, not null, default true
  created_at
  updated_at
```

Indexes:

```text
category_node_id
program_kind
store_id
display_location_id
(starts_on, ends_on)
active
```

Validation notes:

* `name` required
* `program_kind` in same family as `feature_kind` subset
* `category_node` active if present; node scheme compatible with `program_kind`
* `ends_on >= starts_on` when both present

### 3. `product_feature_assignments`

```text
product_feature_assignments
  id
  category_node_id              bigint FK category_nodes, null
  product_feature_program_id    bigint FK product_feature_programs, null
  product_id                    bigint FK products, not null
  product_variant_id            bigint FK product_variants, null
  store_id                      bigint FK stores, null

  feature_kind                  string, not null
  status                        string, null

  starts_on                     date, null
  ends_on                       date, null

  year                          integer, null
  list_date                     date, null
  list_name                     string, null
  rank                          integer, null

  display_location_id           bigint FK display_locations, null
  priority                      integer, null
  label_text                    string, null
  public_note                   text, null
  staff_note                    text, null
  recommended_by_user_id        bigint FK users, null

  source                        string, null
  source_url                    string, null
  external_key                  string, null

  public_visible                boolean, not null, default true
  staff_visible                 boolean, not null, default true
  pos_visible                   boolean, not null, default true
  website_visible               boolean, not null, default false
  needs_review                  boolean, not null, default false

  metadata                      jsonb, not null, default {}
  active                        boolean, not null, default true
  created_at
  updated_at
```

Indexes:

```text
category_node_id
product_feature_program_id
product_id
product_variant_id
store_id
feature_kind
status
(starts_on, ends_on)
year
list_date
rank
active
external_key (partial, where external_key is not null)
```

Check constraints (app-level if not DB):

```text
exactly one of category_node_id, product_feature_program_id
product_variant.product_id = product_id when variant present
rank > 0 when present
ends_on >= starts_on when both present
```

Uniqueness: no broad unique index in v1. Targeted:

```text
unique external_key per import scope (optional partial index)
```

Duplicate detection via `ProductFeatures::AssignmentValidator` service.

---

## Associations

```text
CategoryNode
  has_many :product_feature_assignments
  has_many :product_feature_programs

ProductFeatureProgram
  belongs_to :category_node, optional: true
  belongs_to :store, optional: true
  belongs_to :display_location, optional: true
  has_many :product_feature_assignments

ProductFeatureAssignment
  belongs_to :category_node, optional: true
  belongs_to :product_feature_program, optional: true
  belongs_to :product
  belongs_to :product_variant, optional: true
  belongs_to :store, optional: true
  belongs_to :display_location, optional: true
  belongs_to :recommended_by_user, class_name: "User", optional: true

Product
  has_many :product_feature_assignments

ProductVariant
  has_many :product_feature_assignments
```

---

## Feature kinds and statuses

### `feature_kind` (assignment; required)

```text
award
featured_list
book_club
promotion
display
staff_pick
reading_list
event_tie_in
media_tie_in
vendor_coop
review_callout
internal_feature
other
```

Set on create from node scheme / program kind when possible; denormalized for reporting.

### Status by kind (v1 — controlled strings)

| Kind | Example statuses |
| ---- | ---------------- |
| `award` | winner, joint_winner, shortlisted, longlisted, finalist, nominee, honorable_mention |
| `featured_list` | ranked, selected, featured, notable, pick |
| `book_club` | selected, monthly_pick, featured, past_selection |
| `promotion` | planned, active, ended, cancelled |
| `display` | planned, active, ended, removed, extended |
| `staff_pick` | active, expired, archived, removed |
| `event_tie_in` | featured, event_title, signed_stock, past_event, cancelled |
| `vendor_coop` | planned, active, fulfilled, ended, cancelled |
| `reading_list` | selected, featured |
| `review_callout` | starred, notable, best_of |
| `internal_feature` | active, ended |
| `other` | freeform or active/ended |

Validated in `ProductFeatures::AssignmentValidator`, not DB enum (v1).

---

## Effective date resolution

```text
effective_starts_on = assignment.starts_on || program&.starts_on
effective_ends_on   = assignment.ends_on   || program&.ends_on
```

`ProductFeatures::EffectiveAssignments` filters by `on_date`, `store`, `active` flags, and visibility context.

---

## Store scope

If program has `store_id`:

* assignment `store_id` must match program store, **or**
* assignment `store_id` blank and inherits program scope

If program is global (`store_id` null), assignment may be global or store-specific.

---

## Seed data

### Feature schemes (stable `scheme_key`)

```text
awards
featured_lists
book_clubs
display_programs
promotion_programs
reading_lists
review_sources
event_series
```

### Starter nodes (minimum)

```text
awards: booker_prize, pulitzer_fiction, national_book_award
featured_lists: nyt_bestseller, indienext, publishers_weekly_best_books
display_programs: summer_reading, holiday_gift_guide, front_table_feature
promotion_programs: staff_picks
book_clubs: (optional starter)
reading_lists: (optional starter)
```

Load via CSV importer pattern; idempotent upsert by `node_key` per scheme. See [seed-data-spec.md](../../specifications/seed-data-spec.md).

---

## Services

### `ProductFeatures::EffectiveAssignments`

```ruby
ProductFeatures::EffectiveAssignments.call(
  product: product,
  product_variant: nil,
  store: current_store,
  on_date: Date.current,
  feature_kinds: nil,
  visibility: :staff # :customer, :pos, :website
)
```

Responsibilities: date resolution, active filtering, store filtering, sort by priority/feature_kind/date.

### `ProductFeatures::BadgePresenter`

```ruby
ProductFeatures::BadgePresenter.call(
  assignments: assignments,
  context: :customer | :staff | :pos | :website
)
```

Prefers `label_text`; maps status + kind to compact badge labels; respects visibility flags. For program-backed assignments, resolves display name from `product_feature_program` and optional template `category_node_id` (inherit vocabulary label for reporting/badges without duplicating node on assignment).

### `ProductFeatures::VisibilityPreset`

Maps staff UI presets to the four stored boolean columns (see spec § Visibility presets). Inverse mapping for edit forms.

### `ProductFeatures::AssignmentValidator`

* status compatible with `feature_kind`
* anchor presence (node xor program)
* variant belongs to product
* store scope
* duplicate warnings (same product + node + year + status; same product + program + overlapping dates)
* assignment dates outside program dates → `needs_review` or warning

### `ProductFeatures::SearchFilters`

Scope builder for item index and future reports. When filtering by `category_node_id`, include assignments anchored to programs whose `category_node_id` matches the template node.

---

## Audit events

```text
product_feature_program.created
product_feature_program.updated
product_feature_program.inactivated

product_feature_assignment.created
product_feature_assignment.updated
product_feature_assignment.deactivated
```

---

## Example records

### Award (vocabulary-backed)

```text
CategoryNode: awards/booker_prize

ProductFeatureAssignment:
  category_node_id: booker_prize
  product_id: ...
  feature_kind: award
  status: shortlisted
  year: 2023
  public_visible: true
```

### Bestseller list

```text
CategoryNode: featured_lists/nyt_bestseller

ProductFeatureAssignment:
  feature_kind: featured_list
  status: ranked
  list_date: 2024-02-11
  list_name: Hardcover Fiction
  rank: 2
  label_text: "#2 NYT Bestseller"
```

### Display campaign (program-backed)

```text
ProductFeatureProgram:
  category_node_id: summer_reading
  program_kind: display
  name: Summer Reading Display 2026
  store_id: main
  display_location_id: front_table
  starts_on: 2026-06-01
  ends_on: 2026-08-31

ProductFeatureAssignment:
  product_feature_program_id: ...
  product_id: ...
  feature_kind: display
  status: active
  priority: 1
  label_text: Beach Read Pick
```

### Staff pick

```text
CategoryNode: promotion_programs/staff_picks (or program-backed — either valid)

ProductFeatureAssignment:
  feature_kind: staff_pick
  status: active
  recommended_by_user_id: ...
  label_text: "Tom recommends"
  staff_note: "..."
  public_note: "..."
```

---

## JSONB usage

Structured columns hold common query/report fields (`year`, `list_date`, `rank`, `status`, dates).

`metadata` for import/source-specific extras only:

```json
{
  "source_feed": "publisher_excel",
  "original_label": "NYT Best Seller",
  "list_section": "Hardcover Fiction"
}
```

---

## Deferred

* `classification_axis` on `category_schemes`
* Normalized `feature_statuses` reference table
* POS discount rule FK on promotions
* Bulk assignment UI
* Fixture capacity / merchandising tasks
