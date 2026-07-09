# v0.04-16 Product Entry Revamp — Data Model

## Status

**Draft**

Spec: [spec.md](spec.md)

---

## Architecture

```text
Staff selects Item kind (catalog_item_type)
        ↓
Products::FieldVisibilityResolver
Products::FormatEligibility
Products::OperationalTypeDeriver
        ↓
Existing products columns + format_id + categorizations
        ↓
ProductVariant (simplified entry form)
```

No new product metadata table. This milestone extends **formats**, seeds **genre category schemes**, and adds **resolver services**.

---

## Schema policy

### Permitted changes

| Change | Reason |
| ------ | ------ |
| Extend `formats` with eligibility columns | Filter format dropdowns by item kind + digital |
| Seed MVP format rows | Expand beyond ~10 legacy formats |
| Seed genre `category_schemes` + starter `category_nodes` | Controlled genre pickers |
| Extend `CategoryScheme::PURPOSES` if needed | Genre scheme purposes |
| Scheme-aware `CategoryNode#node_key` max length | Genre CSV keys up to ~83 chars; store categories stay ≤30 |
| Service objects only | Visibility, eligibility, operational type derivation |

### Do not add

* `product_features` or participation tables (v0.04-17)
* Parallel item-kind table
* Rename `catalog_item_type` column in v0.04-16
* Shorten genre seed `node_key` values to fit legacy 30-char limit

---

## Category node keys (genre trees)

### Problem

Genre seed files in `db/seeds/data/` use **hierarchical** `node_key` values (prefix paths) because `node_key` is unique per **scheme**, not per parent. Current longest keys:

| File | Max `node_key` length |
| ---- | --------------------: |
| `music_genres.csv` | 81 |
| `sideline_genres.csv` | 83 |
| `video_genres.csv` | 40 |
| `video_game_genres.csv` | 18 |

`CategoryNode` currently validates `node_key` `length: { maximum: 30 }`. The DB column is `string` (255) — no column migration required unless we choose an explicit `limit: 128` in a future migration for documentation.

### Decision

**Expand validation; do not rewrite CSV keys.**

| Scheme family | `node_key` max |
| ------------- | -------------: |
| `store_categories` (and legacy `store_sections_topics`) | 30 |
| `bisac` | 30 (BISAC codes are 9 chars) |
| Genre purposes (`music_genres`, `video_genres`, `video_game_genres`, `sideline_genres`) | **128** |
| Other schemes (default) | 128 |

### Implementation

1. **Model** — replace flat `length: { maximum: 30 }` with custom validation, e.g. `CategoryNode#node_key_max_length` derived from `category_scheme.purpose` / `scheme_key`.
2. **Setup UI** — `app/views/setup/category_nodes/_form.html.erb` `maxlength` follows the same scheme-aware limit (30 vs 128).
3. **Seeds validator** — keep `store_categories` ≤30 error; genre files warn above 30 until import ships, then assert ≤128.
4. **No data backfill** — existing nodes unchanged.

```ruby
# Illustrative — implementation may use purpose list or scheme_key set
GENRE_SCHEME_PURPOSES = %w[music_genres video_genres video_game_genres sideline_genres].freeze
SHORT_NODE_KEY_SCHEMES = %w[store_categories store_sections_topics bisac].freeze

def node_key_max_length
  return 30 if category_scheme.scheme_key.in?(SHORT_NODE_KEY_SCHEMES)
  return 128 if category_scheme.purpose.in?(GENRE_SCHEME_PURPOSES)

  128
end
```

Genre import runs **after** this validation change (migration plan step 3 before seed import step 4).

---

## `formats` extension

### New columns (proposed)

```text
formats
  catalog_item_type   string, null    # primary item kind eligibility; null = multi-kind via join or legacy
  digital             boolean, null   # null = both; true/false = restrict
  sort_order          integer, default 0
```

**Alternative (if multi-kind per format is common):** join table `format_item_kind_eligibilities (format_id, catalog_item_type, digital)`. MVP may use single `catalog_item_type` + `digital` on `formats` when each format maps to one kind; use join table in a follow-up slice if overlap is frequent.

MVP recommendation: **columns on `formats`** for simplicity; ~25 formats with single kind each.

### Existing columns (retain)

```text
format_key, name, short_name, code, virtual, active
```

`virtual: true` should align with `digital: true` for digital formats.

---

## MVP format seed (v0.04-16)

Approximately 25 formats. Remaining draft slugs deferred to Setup admin or v0.04-16b.

### Book (`catalog_item_type: book`)

| format_key | name | digital | virtual |
| ---------- | ---- | ------- | ------- |
| trade_cloth | Trade Cloth | false | false |
| trade_paperback | Trade Paperback | false | false |
| mass_market_paperback | Mass Market Paperback | false | false |
| board_book | Board Book | false | false |
| library_binding | Library Binding | false | false |
| ebook | eBook | true | true |
| epub | EPUB | true | true |
| audiobook_download | Downloadable Audiobook | true | true |
| audiobook_streaming | Streaming Audiobook | true | true |
| audiobook_cd | Audiobook CD | false | false |

### Recorded Music (`recorded_music`)

| format_key | name | digital | virtual |
| ---------- | ---- | ------- | ------- |
| audio_cd | Audio CD | false | false |
| vinyl_lp | Vinyl LP | false | false |
| digital_music | Digital Music | true | true |

### Video (`videorecording`)

| format_key | name | digital | virtual |
| ---------- | ---- | ------- | ------- |
| dvd | DVD | false | false |
| blu_ray | Blu-ray | false | false |
| digital_video | Digital Video | true | true |

### Video Game (`game`)

| format_key | name | digital | virtual |
| ---------- | ---- | ------- | ------- |
| video_game_disc | Video Game Disc | false | false |
| video_game_cartridge | Video Game Cartridge | false | false |
| video_game_digital | Digital Video Game | true | true |

### Periodical (`periodical`)

| format_key | name | digital | virtual |
| ---------- | ---- | ------- | ------- |
| magazine | Magazine | false | false |
| newspaper | Newspaper | false | false |

### Calendar (`calendar`)

| format_key | name | digital | virtual |
| ---------- | ---- | ------- | ------- |
| wall_calendar | Wall Calendar | false | false |
| desk_calendar | Desk Calendar | false | false |

### Sideline (`sideline`)

| format_key | name | digital | virtual |
| ---------- | ---- | ------- | ------- |
| gift_item | Gift Item | false | false |
| apparel | Apparel | false | false |
| other_merchandise | Other Merchandise | false | false |

### Other

| format_key | name | digital | virtual |
| ---------- | ---- | ------- | ------- |
| other | Other | false | false |

Legacy format rows (hardcover, compact_disc, etc.) remain; map or inactivate duplicates during seed idempotency review.

---

## Genre category schemes

Seed idempotently via `scheme_key`:

| scheme_key | purpose (v1) | UI label on product form |
| ---------- | ------------ | ------------------------ |
| `music_genres` | `music_genres` | Genre |
| `video_genres` | `video_genres` | Genre |
| `video_game_genres` | `video_game_genres` | Genre |
| `sideline_genres` | `sideline_genres` | Sideline category / Theme |

Add to `CategoryScheme::PURPOSES`:

```text
music_genres
video_genres
video_game_genres
sideline_genres
```

Seed files (full trees) live in `db/seeds/data/` — see [seed-data-spec.md](../../specifications/seed-data-spec.md). Assignments use existing `categorizations` polymorphic on `Product`.

Genre import requires [scheme-aware `node_key` length](#category-node-keys-genre-trees) (128 max) before CSV load.

**Books:** continue BISAC via `bisac` scheme — no change.

---

## Field visibility matrix

Resolver input:

```text
catalog_item_type
digital
format_id (resolved format_key)
variation_type
product_type
operational_short_form (service | non_inventory | false)
```

Legend: **Y** = visible, **R** = required when section shown, **—** = hidden, **C** = conditional (see notes).

### Core fields by item kind

| Field | Book | Music | Video | Game | Periodical | Calendar | Sideline | Other | Service | Non-Inv. |
| ----- | ---- | ----- | ----- | ---- | ---------- | -------- | -------- | ----- | ------- | -------- |
| Item kind | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R |
| Primary identifier | Y | Y | Y | Y | Y | Y | Y | Y | — | — |
| Title | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R |
| List price | Y | Y | Y | Y | Y | Y | Y | Y | C | C |
| Digital | Y | Y | Y | Y | — | — | — | — | — | — |
| Creators | Y | Y | Y | Y | — | — | — | — | — | — |
| Store category | Y | Y | Y | Y | Y | Y | Y | Y | — | — |
| Subdepartment | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R | Y/R |
| Variation type | Y | Y | Y | Y | Y | Y | Y | Y | — | — |
| Variant label 1 | C | C | C | C | C | C | C | C | — | — |
| Variant label 2 | C | C | C | C | C | C | C | C | — | — |
| Thumbnail | Y | Y | Y | Y | Y | Y | Y | Y | — | — |
| Format | Y | Y | Y | Y | Y | Y | Y | C | — | — |
| Publisher | Y | C | C | C | — | — | — | — | — | — |
| Publication date | Y | C | C | C | — | C | C | C | — | — |
| Publication status | Y | C | C | C | — | C | C | C | — | — |
| Large print | C | — | — | — | — | — | — | — | — | — |
| Edition statement | Y | C | C | C | — | — | — | — | — | — |
| BISAC picker | Y | — | — | — | — | — | — | — | — | — |
| Genre scheme picker | — | Y | Y | Y | — | Y | Y | — | — | — |
| Free-text genres | — | — | — | — | — | — | — | C | — | — |
| Subjects (free text) | C | — | C | — | C | C | — | — | — | — |
| Series name / enum | Y | C | C | C | — | — | C | — | — | — |
| Page count | C | — | — | — | — | — | C | — | — | — |
| Running time | C | C | C | — | — | — | — | — | — | — |
| Calendar year (`year`) | — | — | — | — | — | Y/R | C | — | — | — |
| Target audience | Y | Y | Y | Y | Y | Y | Y | Y | — | — |
| Access restrictions | Y | Y | Y | Y | Y | Y | Y | Y | — | — |
| Language | Y | Y | Y | Y | Y | Y | Y | Y | — | — |
| Description | Y | Y | Y | Y | Y | Y | Y | Y | C | C |
| Physical dimensions | C | C | C | C | — | C | C | C | — | — |
| Weight | C | C | C | C | — | C | C | C | — | — |
| Internal notes | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |

**C notes:**

* **Variant labels:** visible when `variation_type` is `variable` (label 1) or `matrix` (labels 1 and 2).
* **Physical fields:** hidden when `digital: true`.
* **Page count:** book non-digital formats; some sideline book-like formats.
* **Running time:** book audiobook formats; music; video.
* **Large print:** book print formats only.
* **Publisher:** music UI may label **Label**; video **Studio** — same `publisher` column.
* **Calendar year:** calendar kinds; some sideline dated products.

### Format-driven overrides

After format selection, resolver may add fields even when item-kind default is hidden — e.g. `running_time` for `audiobook_cd`.

Implementation: optional `format_field_overrides` hash on `Format` (`metadata` jsonb) or static map in resolver for MVP.

---

## Operational `product_type` derivation

`Products::OperationalTypeDeriver` on create (and when item kind / digital / service choice changes):

| Condition | `product_type` |
| --------- | -------------- |
| Staff chose Service | `service` |
| Staff chose Non-Inventory Item | `non_inventory` |
| `digital: true` and kind in bibliographic/media set | `digital` |
| Default sellable physical | `physical` |
| Gift card / financial SKUs | unchanged — out of scope for this form |

Do not expose `product_type` as primary staff control except advanced/admin read-only preview.

---

## Legacy item kind normalization

`Products::ItemKindNormalizer` for edit/display:

| Stored `catalog_item_type` | Display as |
| -------------------------- | ---------- |
| `audiobook` | Book + digital + audiobook format |
| `ebook` | Book + digital + ebook/epub format |
| `map`, `gift` | Map to **Other** or retain read-only legacy badge until backfill |

New creates must not write `audiobook` or `ebook`.

---

## Service / Non-Inventory short form

When staff selects **Service** or **Non-Inventory Item**:

**Visible:** Item kind (fixed pair), title, subdepartment, list price (optional), description (optional), internal notes, active.

**Hidden:** Digital, format, creators, store category (optional exception: allow store category for non-inventory gift-like items — default hidden), variation setup (single non-orderable variant path or zero variants per existing product rules), physical block, genre pickers.

Variant creation: follow existing `non_inventory` / `service` product rules via `ProductVariants::OperationalPolicy`.

---

## Store category defaults

On `store_category_id` change (existing service):

```text
StoreCategoryDefaults.for(store_category_node:)
  → default_sub_department
  → default_display_location
```

UI shows preview immediately; staff may override subdepartment/display location before save.

Subdepartment select: group options by parent `Department` name.

---

## Variant model (unchanged grain)

| Field | v0.04-16 UI |
| ----- | ----------- |
| `sku` | System-assigned; hidden on create |
| `selling_price_cents` | Currency input |
| `condition` | Visible |
| `variant1_value` / `variant2_value` | Visible when parent variation type requires |
| `inventory_tracking` / `orderable` / `discountable` | Visible |
| `name_override`, `short_name`, pricing model override | Hidden |

---

## Associations (unchanged)

```text
Product
  belongs_to :format
  belongs_to :store_category, class_name: CategoryNode
  has_many :categorizations, as: :categorizable
  has_many :product_variants
```

Genre selections: `categorizations` → `category_nodes` in genre schemes.

---

## Audit events

Preserve existing product/variant audit patterns. Minimum:

```text
product.created
product.updated
product_variant.created
product_variant.updated
```

If metadata quick-modals are touched, ensure audit parity with full edit paths.

---

## CSV / seed files

```text
db/seeds/data/formats_mvp.csv          # proposed — not yet added
db/seeds/data/music_genres.csv         # 660 nodes
db/seeds/data/video_genres.csv         # 188 nodes
db/seeds/data/video_game_genres.csv    # 130 nodes
db/seeds/data/sideline_genres.csv      # 681 nodes
```

Follow [seed-data-spec.md](../../specifications/seed-data-spec.md) idempotent upsert by `format_key` / `node_key`. Validate with `rails shelfstack:seeds:validate`.

---

## Deferred (v0.04-16b or later)

* Full format catalog from draft (~100+ rows)
* `format_item_kind_eligibilities` join table if multi-kind formats proliferate
* Periodical issue columns (`volume`, `issue_number`, `cover_date`)
* `classification_axis` on `category_schemes` (alternative to growing `purpose`)
* Column rename `catalog_item_type` → `item_kind`
