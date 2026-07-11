# v0.04-16 Product Entry Revamp — Functional Specification

## Status

**Complete** — product-metadata entry foundation: progressive forms, vocabulary alignment, format and genre eligibility, resolver/sanitizer stack. No new core product metadata tables.

Companion documents:

* [data-model.md](data-model.md) — format eligibility, genre schemes, field matrix, services
* [test-plan.md](test-plan.md) — resolver, integration, and regression gates
* [completion](../../implementation/v0.04-16-completion.md)
* [classification-target-spec.md](../../specifications/classification-target-spec.md) — classification spine
* [v0.04-1 product fusion](../v0.04-1-product-fusion/spec.md) — fused metadata on `products`
* [v0.04-15 overview refactor](../v0.04-15-products-overview-refactor/spec.md) — read surfaces this milestone improves data for

**Next milestone:** v0.04-16.1 Unified product management & form stability — [spec bundle](../v0.04-16.1-unified-product-management/spec.md). Then v0.04-17 Product feature assignments — [spec bundle](../v0.04-17-product-feature-assignments/spec.md).

Source drafts (superseded by this bundle): `docs/drafts_temp/v0.04-1x-product-entry-revamp_summary.md`, `docs/drafts_temp/v0.04-1x-product-entry-revamp-details.md`.

### Known follow-ups (v0.04-16.1)

Do **not** extend these as the long-term Product form architecture; they are deferred to [v0.04-16.1](../v0.04-16.1-unified-product-management/spec.md):

* Turbo Frame full-form GET section replacement for visibility changes
* Staff Catalog-linked vs Non-catalog Add Item choice → unified **Add Product**
* Separate Edit Bibliographic Details surface → unified **Edit Product**
* Form stability: mounted fields + driver-only context endpoint (no large HTML section replacement)
* Service / Non-Inventory default-variant auto-create policy (locked in 16.1)

---

## Job

Make product entry **item-kind aware** and **progressive**. Staff select an **Item kind** first; the form reveals only fields, formats, controlled vocabularies, and variant controls that apply to that kind, its **Digital** flag, selected **Format**, and **Variation type**.

```text
What is this item?        → Item kind (catalog_item_type) + identity
How do we sell/classify?  → Selling & store classification
What format/metadata?     → Format, publisher/label, subjects/genres
Physical details?         → Dimensions, weight, page count, running time
What SKUs?                → Variant setup
Internal behavior?        → Inventory, orderable, discountable, notes
```

This milestone delivers the **resolver, format/genre, and progressive-form foundation** for the v0.04-1 fused product model. Metadata columns already live on `products`; v0.04-16 adds eligibility rules, expanded formats (MVP subset), genre schemes, and progressive metadata forms. **Unified staff Product create/edit vocabulary and stable form mechanics are completed in v0.04-16.1.**

---

## Resolved decisions

| Decision | Choice |
| -------- | ------ |
| Milestone id | **v0.04-16** product entry revamp |
| Next milestone | **v0.04-16.1** unified product management & form stability; then **v0.04-17** product feature assignments |
| Item kind storage | Keep column **`catalog_item_type`**; staff UI label **Item kind** |
| Audiobooks / eBooks | Single item kind **Book** — `digital` + format (`ebook`, `epub`, `audiobook_download`, etc.) |
| Legacy `audiobook` / `ebook` types | Remain valid in DB; edit UI normalizes display to **Book** + digital + format; backfill optional/deferred |
| Operational type | Keep **`product_type`** (`physical`, `digital`, `service`, `non_inventory`, `financial`) — derived/defaulted, not primary staff taxonomy |
| Service vs non-inventory | Staff picks **Service** or **Non-Inventory Item**; both store `catalog_item_type: other` with `product_type: service` or `non_inventory` |
| Service / Non-Inventory display | **Never** show staff label **Other** for these — use explicit **Service** / **Non-Inventory Item** in forms, index, and search (`Products::ItemKindNormalizer` + presenters) |
| Format catalog | **MVP subset** (~25 common formats); extensible via Setup |
| Store category | Available for all sellable item kinds except Service / Non-Inventory short form |
| Field visibility | **`Products::FieldVisibilityResolver`** — item kind + digital + format + variation type + operational product_type |
| Genre pickers | One controlled picker at a time: BISAC (book) or genre scheme (music/video/game/sideline/calendar) |
| Variant form | Hide legacy/advanced fields; currency entry for selling price; system-assigned SKU unchanged |
| Schema | No new product metadata table; extend `formats`; seed genre `CategoryScheme`s |
| Genre `node_key` length | **Expand** validation to **128** chars for genre schemes; **do not** shorten seed keys; `store_categories` remain ≤30 |
| Column rename | Do **not** rename `catalog_item_type` to `item_kind` in v0.04-16 |

---

## Vocabulary (staff vs storage)

Do **not** use “Product type” in the UI for Book / Video / Sideline — that collides with operational `product_type`.

| Staff label | Storage | Purpose |
| ----------- | ------- | ------- |
| **Item kind** | `products.catalog_item_type` | Content/merchandise discriminator |
| **Digital** | `products.digital` | Physical vs digital presentation |
| **Format** | `products.format_id` → `formats` | Carrier/presentation (trade cloth, DVD, ebook, …) |
| **Operational type** | `products.product_type` | Inventory/tax/orderability behavior (mostly derived) |
| **Variation type** | `products.variation_type` | Single, conditional, variable, matrix |
| **Store category** | `products.store_category_id` | Store topic/shelving node (`store_categories` scheme) |
| **Subdepartment** | `products.default_sub_department_id` | Operational merchandise behavior |

### Staff item kinds → `catalog_item_type`

| Staff label | `catalog_item_type` | `product_type` default | Notes |
| ----------- | -------------------- | ------------------------ | ----- |
| Book | `book` | `physical` or `digital` from Digital flag | Includes print, ebook, audiobook via format |
| Recorded Music | `recorded_music` | `physical` or `digital` | |
| Video | `videorecording` | `physical` or `digital` | |
| Video Game | `game` | `physical` or `digital` | Platform often variant attribute |
| Periodical | `periodical` | `physical` | Issue-oriented metadata deferred beyond MVP |
| Calendar | `calendar` | `physical` | Use **Calendar year** field |
| Sideline | `sideline` | `physical` | |
| Other | `other` | `physical` | |
| Service | `other` | `service` | Short form; staff label **Service** only |
| Non-Inventory Item | `other` | `non_inventory` | Short form; staff label **Non-Inventory Item** only |

Legacy values `audiobook`, `ebook`, `map`, `gift` remain in `ProductMetadata::CATALOG_ITEM_TYPES` for existing rows. New creates use the table above.

---

## Hard gates

1. **Do not** overload `product_type` with Book / Video / Sideline labels.
2. **Do not** add a parallel product metadata table — use existing `products` columns and `categorizations`.
3. **Do not** use `digital_book` as an item kind or format parent type — digital books are `catalog_item_type: book`, `digital: true`, format slug.
4. **Do not** break v0.04-2 identifier/SKU assignment — hide SKU from staff variant form; system assigns at creation.
5. **Do not** break `Inventory::TrackingResolver`, orderability, or buyback eligibility keyed on operational `product_type`.
6. **Field visibility** must be centralized — views call `Products::FieldVisibilityResolver`, not ad hoc `if book?` branches.
7. **Format lists** must be filtered via `Products::FormatEligibility` — no unfiltered format dropdowns on entry surfaces.
8. **One genre/subject picker** visible at a time per item kind rules.
9. **Store category** selection must preview default subdepartment and display location via existing `StoreCategoryDefaults`.
10. **Audit events** on product metadata create/update where entry paths already audit (preserve existing behavior; extend if gaps found).
11. **Genre `node_key` values** in seed CSVs are authoritative — widen `CategoryNode` validation (128 for genre schemes); do **not** shorten hierarchical keys to fit the legacy 30-char limit.
12. **Service / Non-Inventory** must never present as plain **Other** in staff UI, item index filters, or search results — resolve display label from staff item-kind choice / `product_type`, not raw `catalog_item_type` alone.

---

## Scope

### In scope

1. **Vocabulary alignment** — item kind labels, operational type derivation, legacy type display normalization
2. **`formats` extension** — eligibility columns + MVP seed subset (see data-model)
3. **Genre category schemes** — seed `music_genres`, `video_genres`, `video_game_genres`, `sideline_genres` from `db/seeds/data/*.csv` (~1,650 nodes)
4. **`category_nodes.node_key` length** — scheme-aware validation (128 for genre schemes; 30 for `store_categories` / legacy short keys)
5. **`Products::FieldVisibilityResolver`** — field matrix as code
6. **`Products::FormatEligibility`** — filtered format options
7. **`Products::OperationalTypeDeriver`** (or equivalent) — set/default `product_type` from item kind + digital + staff service/non-inventory choice
8. **Progressive Add Item** — item kind first; six sections on item details and selling setup paths
9. **Product edit / Item setup tab** — same section model and visibility rules
10. **Variant create/edit cleanup** — simplified fields, currency selling price
11. **BISAC** — book only; unchanged scheme wiring
12. **Controlled genres** — music/video/game/sideline/calendar via `categorizations` on product
13. **Tests + verifier** — see test-plan

### Out of scope (deferred)

* v0.04-17 product feature assignments (awards, lists, displays, staff picks as participation records)
* Full format catalog (~100+ slugs from draft)
* **`format_item_kind_eligibilities` join table** when a format spans multiple item kinds (see data-model — likely follow-up after MVP)
* **Periodical issue metadata** (`volume`, `issue_number`, `cover_date` / issue date) — **near follow-up (v0.04-16b)**; periodicals will feel incomplete without at least cover/issue date soon after MVP
* Contributor role normalization (author/narrator/illustrator tables)
* Platform/rating/region as first-class columns (use `metadata` JSONB until needed)
* Rename `catalog_item_type` column to `item_kind`
* Bulk backfill of legacy `audiobook`/`ebook` rows to `book`
* Product groups / work-level UI (v0.04-3 deferred)
* POS or import pipeline rewrites beyond compatibility guards

---

## Form structure

Six sections (Add Item, product edit, Item setup metadata edit):

```text
1. Product Identity
   Item kind, primary identifier, title, creators, thumbnail, description

2. Selling & Store Classification
   List price, store category, subdepartment (grouped by department),
   default display location, preferred vendor (when shown)

3. Format & Metadata
   Digital, format (filtered), publisher/label/studio, publication/release date,
   publication status, controlled subject/genre picker, series, language,
   target audience, access restrictions, type-specific fields (calendar year, rating TBD)

4. Physical / Logistics
   Dimensions, weight, units, page count, running time (duration_minutes)

5. Variant Setup
   Variation type, attribute labels (conditional), initial variant row(s)

6. Internal Controls
   Internal notes, active, product-level discountable default,
   default inventory tracking preview (advanced override deferred)
```

### Progressive rules (summary)

| Trigger | Effect |
| ------- | ------ |
| Item kind selected | Filters formats; shows/hides genre picker; sets short form for Service/Non-Inventory |
| Digital = true | Hides physical dimensions/weight; filters to digital-capable formats |
| Format selected | May reveal page count, running time, calendar year, large print, etc. |
| Store category selected | Previews default subdepartment + display location |
| Variation type | `variable` → Attribute label 1; `matrix` → labels 1 and 2 |
| Service / Non-Inventory | Collapses to short form (see data-model) |

Full matrix: [data-model.md § Field visibility matrix](data-model.md#field-visibility-matrix).

---

## Controlled vocabularies

| Item kind | Subject/genre system |
| --------- | -------------------- |
| Book | BISAC (`bisac` scheme) via existing categorization UI |
| Recorded Music | `music_genres` scheme |
| Video | `video_genres` scheme |
| Video Game | `video_game_genres` scheme |
| Calendar | `sideline_genres` scheme (UI label: **Theme** or **Category**) |
| Sideline | `sideline_genres` scheme (UI label: **Sideline category**) |
| Periodical, Other, Service, Non-Inventory | No controlled genre picker in MVP |

Free-text `subjects`, `genres`, `themes` fields remain hidden when a controlled picker is active unless spec explicitly enables both (default: controlled only for listed kinds).

---

## Variant form (simplified)

**Hide** from default staff variant form:

* Name override
* SKU / SKU preview
* Derived defaults block
* Short name
* Pricing model override

**Show** (order):

1. Condition
2. Selling price (currency input → `selling_price_cents`)
3. Attribute 1 / Attribute 2 (from parent labels when variation type requires)
4. Inventory tracking
5. Orderable
6. Discountable
7. Active

SKU remains system-assigned per v0.04-2. Barcode/identifier scan paths unchanged.

---

## Surfaces in scope

| Surface | Change |
| ------- | ------ |
| Add Item — choose path / identify | Unchanged entry; item kind selection moves earlier in catalog/non-catalog flows |
| Add Item — item details | Progressive six-section form (replaces flat catalog form for product-first path) |
| Add Item — selling setup | Align classification section with section 2 rules |
| Add Item — sellable SKU | Simplified variant partials |
| Items — product `new` / `edit` | Progressive form |
| Items — product `edit_metadata` | Product metadata form + `EntryContext` |
| Items — variant `new` / `edit` | Simplified variant form |
| Items — Item setup tab | Metadata modals or inline edit follow same visibility rules |
| Setup — formats | Admin can add formats; eligibility columns editable |
| Setup — category schemes | Genre schemes editable via existing Category Schemes UI |

**Out of scope for layout redesign:** Operations tab, Overview tab (v0.04-15), POS.

---

## Services

| Service | Responsibility |
| ------- | -------------- |
| `Products::FieldVisibilityResolver` | Returns visible/required fields for context |
| `Products::FormatEligibility` | Returns allowed `Format` records for kind + digital |
| `Products::OperationalTypeDeriver` | Defaults `product_type` on create from kind + digital + service/non-inventory |
| `Products::ItemKindNormalizer` | Maps legacy `audiobook`/`ebook` to book display context; resolves staff item-kind label for Service / Non-Inventory (never plain **Other**) |
| `Products::FieldLabelResolver` (or resolver helper) | Contextual field labels — e.g. **Publisher** (book), **Label** (music), **Studio** (video) on shared `publisher` column |
| `Products::EntryContext` | Composed context for controllers/views — visibility, labels, eligible formats, controlled scheme, operational type, short-form flag, staff item kind |
| `Products::MetadataParamsSanitizer` | Enforces hidden-field policy on create, edit, and item-kind change |
| `StoreCategoryDefaults` | Existing — wire live preview on store category change |

Controllers remain thin; build one `Products::EntryContext` per request. Client controllers may apply visibility from server context, but **server-side resolver + sanitizer are authoritative** for submit validation. Do **not** treat large Turbo Frame HTML section replacement (full-form GET reload) as the long-term progressive-form mechanism — that debt is retired in v0.04-16.1.

---

## Implementation policies

### Product metadata form ownership

v0.04-16 introduces a **product-oriented** shared metadata form under `app/views/items/shared/product_forms/metadata/`. Primary consumers: Add Item `item_details`, `products#edit_metadata`. Legacy [`catalog_items/_form`](../../app/views/items/catalog_items/_form.html.erb) paths **wrap or delegate** to the product form — metadata entry is product-first, not catalog-item-only.

### Hidden-field and stale-data policy

Resolvers determine which fields are **visible** and **accepted** for the current context.

| Situation | Policy |
| --------- | ------ |
| **New create** | Hidden submitted fields are **ignored** (`MetadataParamsSanitizer` filters against `EntryContext`) |
| **Edit, item kind unchanged** | Hidden fields with existing DB values are **preserved** — submit must not wipe values merely because they are not on the form |
| **Edit, item kind changed** | Incompatible controlled classifications (e.g. BISAC on non-book, wrong genre scheme) must be **cleared or reviewed** via a deliberate item-kind-change path — not left stale silently |

Coordinate item-kind-change cleanup with `ProductBisacSync` / `Products::GenreSync`.

### Resolver context object

`Products::EntryContext` (or `FormContext`) composes resolver outputs. Controllers pass **one object** to views instead of scattered instance variables. Minimum surface:

* `field_visibility` — visible/required field keys
* `field_labels` — contextual labels (Publisher / Label / Studio)
* `eligible_formats` — scoped format relation
* `controlled_scheme` — BISAC or genre scheme key, or nil
* `operational_product_type` — derived/defaulted `product_type`
* `short_form?` — Service / Non-Inventory collapsed layout
* `staff_item_kind` — normalized staff choice (distinct from raw `catalog_item_type` for Service / Non-Inventory)

### Legacy format compatibility

Add **mappings** for legacy format keys in import and eligibility paths (e.g. `hardcover` → `trade_cloth`). **Do not** retire, inactivate, or delete legacy `formats` rows in v0.04-16 unless all import paths and existing records are audited. MVP format seed **upserts** new rows alongside legacy keys.

### Service / Non-Inventory behavior

* Staff labels **Service** and **Non-Inventory Item** only — never plain **Other**
* Short-form entry via `EntryContext#short_form?`
* `OperationalTypeDeriver` sets `product_type`
* Follow existing `ProductVariants::OperationalPolicy` — **no normal variant setup** in Add Item for Service / Non-Inventory in v0.04-16 (skip sellable SKU step). Default-variant auto-create on primary save is locked in **v0.04-16.1**.

---

## Permissions

Reuse existing product/item setup permissions. No new permission keys required for MVP unless implementation discovers gaps.

---

## Import and external catalog

* Ingram/import paths must continue to resolve item kind and format without staff UI.
* Imported rows may set `catalog_item_type` directly; resolver treats `audiobook`/`ebook` as book for display.
* `Products::FormatEligibility` must include formats referenced by import mappers.

---

## Migration plan

1. Migration: extend `formats` (eligibility columns)
2. Migration: extend `CategoryScheme::PURPOSES` for genre schemes
3. Migration / model: **scheme-aware `CategoryNode#node_key` length** — see [data-model § Category node keys](data-model.md#category-node-keys-genre-trees)
4. Seeds: MVP formats + genre scheme CSV import (`music_genres`, `video_genres`, `video_game_genres`, `sideline_genres`)
5. Genre tree importer (reuse `CsvClassificationImporter` two-pass pattern)
6. Services: resolvers, `EntryContext`, `MetadataParamsSanitizer`
7. Client progressive visibility (server validates; Turbo Frame full-form GET replacement is transitional — retired in v0.04-16.1)
8. Views: product metadata form partials; catalog_items delegate; Add Item, variant form; Setup category node `maxlength`
9. Tests + `shelfstack:v00416:verify_product_entry_revamp`

---

## Relationship to v0.04-17

v0.04-17 (product feature assignments) adds a **participation layer** (awards, lists, displays, staff picks) on top of this classification model. v0.04-16 does **not** implement feature assignments.

Recommended v0.04-17 UI placement: new section **Recognitions & Features** on product detail/edit, after Format & Metadata — slot reserved in layout but not built in v0.04-16.

---

## Acceptance criteria (summary)

- [ ] Staff can create a **Book** (print and digital) with only applicable fields visible
- [ ] Staff can create **Recorded Music**, **Video**, **Sideline** with correct genre scheme picker
- [ ] **Service** and **Non-Inventory** short forms work with correct `product_type` and staff labels (not **Other**)
- [ ] Format dropdown never shows ineligible formats for selected kind/digital
- [ ] Store category updates subdepartment/display location preview
- [ ] Variant form uses currency selling price and hides legacy SKU/name override fields
- [ ] Legacy products with `audiobook`/`ebook` types remain editable
- [ ] Genre scheme CSVs import without `node_key` validation errors (keys up to 128 chars)
- [ ] `store_categories` nodes still enforce ≤30 char `node_key` on create/edit
- [ ] Hidden fields ignored on create; preserved on edit when item kind unchanged
- [ ] Item kind change clears or reviews incompatible BISAC/genre classifications
- [ ] Legacy format rows remain; import mappers resolve legacy keys
- [ ] Existing import and buyback paths pass regression tests
- [ ] Verifier task passes with `STRICT=1`
