# v0.04-17 Product Feature Assignments — Functional Specification

## Status

**Draft** — domain milestone. Adds a participation layer for awards, lists, promotions, displays, staff picks, and similar product-facing features on top of the existing classification model.

Companion documents:

* [data-model.md](data-model.md) — tables, validations, seeds, services
* [test-plan.md](test-plan.md) — model, service, request, and contract gates
* [classification-target-spec.md](../../specifications/classification-target-spec.md) — classification spine
* [v0.04-16 product entry revamp](../v0.04-16-product-entry-revamp/spec.md) — prerequisite progressive product forms
* [v0.04-15 overview refactor](../v0.04-15-products-overview-refactor/spec.md) — badge/callout read surfaces

---

## Job

Record that a **product** or **product variant** participates in a named recognition, list, promotion, display, campaign, event tie-in, staff pick, or similar feature — with the contextual facts that simple `Categorization` cannot carry.

```text
CategoryScheme / CategoryNode     = durable controlled vocabulary (Booker Prize, NYT Bestseller)
ProductFeatureProgram             = optional dated/store-scoped campaign instance
ProductFeatureAssignment          = how this product/variant participates
```

Examples:

```text
The Bee Sting → Booker Prize → shortlisted → 2023
Fourth Wing → NYT Bestseller → Hardcover Fiction → #2 → 2024-02-11
Beach Read → Summer Reading Display 2026 → Front Table → Jun–Jul 2026
North Woods → Staff Picks → "Tom recommends"
```

**Demand does not post inventory.** Feature assignments do not control tax, GL, inventory tracking, POS discount calculation, or vendor ordering in v0.04-17.

---

## Purpose

ShelfStack already distinguishes:

| Layer | Role |
| ----- | ---- |
| `CategoryScheme` / `CategoryNode` | Controlled vocabulary |
| `Categorization` | Simple polymorphic node assignment (`primary`, `source`) — no dates, rank, or history |
| Item kind / genre / BISAC (v0.04-16) | Stable descriptive classification on the product |
| `SubDepartment` | Operational merchandise behavior |
| `DisplayLocation` | Normal/default physical placement |
| `Product` / `ProductVariant` | Store-facing item and sellable SKU |

Use **`Categorization`** for stable descriptive tags (BISAC, genre, topic, audience).

Use **`ProductFeatureAssignment`** for participations that are:

```text
time-bound · ranked · status-bearing · store-specific · display-specific ·
source-specific · historical · repeatable · merchandising-relevant
```

There is **no `product_features` vocabulary table** — durable feature names live in `CategoryNode` records under feature schemes. Campaign instances live in `product_feature_programs`.

---

## Resolved decisions

| Decision | Choice |
| -------- | ------ |
| Milestone id | **v0.04-17** product feature assignments |
| Prerequisite | **v0.04-16** product entry revamp (stable product edit layout) |
| Vocabulary | `CategoryScheme` / `CategoryNode` — **not** a parallel `product_features` dictionary |
| Campaign instances | `product_feature_programs` for dated/store-scoped bulk programs |
| Participation | `product_feature_assignments` — central fact table |
| Assignment anchor | **`category_node_id` XOR `product_feature_program_id`** (normally not both) |
| Product vs variant | Default `product_id`; `product_variant_id` when SKU-specific |
| `feature_kind` | Required on assignment; denormalized for filters; derived from node scheme where possible |
| Staff picks | Assignment + `recommended_by_user_id` — no separate staff-pick table in v1 |
| Promotions ↔ POS | Descriptive only — no discount linkage in v0.04-17 |
| Visibility | `public_visible`, `staff_visible`, `pos_visible`, `website_visible` on assignment |
| Import quality | `needs_review` on assignment for uncertain imports |
| Status values | Controlled strings by `feature_kind` in v1 — no normalized status table |
| Scheme purpose (v1) | Extend `CategoryScheme::PURPOSES` with feature-oriented values (Option A) |
| Lifecycle | Prefer `active = false` over hard delete when referenced |
| Programs in v1 | **Yes** — required for display/promotion campaign workflows |
| UI section | **Recognitions & Features** on product detail and product edit |

---

## Hard gates

1. **Do not extend `categorizations`** with dates, rank, status, store scope, or merchandising history.
2. **Do not store participations as product JSONB-only** — assignments are relational and queryable.
3. **Do not put awards/lists under `store_categories`** — that scheme is shelving/topic classification.
4. **Do not create `product_features`** as a second vocabulary table when `category_node_id` would duplicate the node.
5. **Assignments must not post inventory** or mutate balances.
6. **Variant assignments** must validate `product_variant.product_id == product_id`.
7. **Effective date resolution** is centralized in `ProductFeatures::EffectiveAssignments`.
8. **Badge presentation** is centralized in `ProductFeatures::BadgePresenter` — respect visibility flags and context (`:customer`, `:staff`, `:pos`, `:website`).
9. **Audit events** on program and assignment create, update, deactivate.
10. **Authorization** enforced on all mutating paths.

---

## Domain concepts

### Controlled vocabulary (`CategoryScheme` / `CategoryNode`)

Durable named things managed in **Setup → Category Schemes**:

```text
awards/booker_prize
featured_lists/nyt_bestseller
featured_lists/indienext
display_programs/summer_reading
display_programs/holiday_gift_guide
```

### Program (`ProductFeatureProgram`)

Optional instance for dated, store-scoped, bulk-assignable campaigns:

```text
Summer Reading Display 2026
Holiday Gift Guide 2026
Front Table: Beach Reads July 2026
```

Prevents creating a new permanent global node every year. Program may optionally link to a template `category_node_id` (e.g. `summer_reading`).

### Assignment (`ProductFeatureAssignment`)

Records how a product or variant participates. Points to **either**:

* a vocabulary node (`category_node_id`) — awards, list appearances, staff pick program name, etc.
* a program instance (`product_feature_program_id`) — seasonal display/promotion membership

---

## Relationship to existing concepts

### vs `Categorization`

| Use `Categorization` | Use `ProductFeatureAssignment` |
| -------------------- | ------------------------------ |
| BISAC subject | Award year/status |
| Genre / topic | List date, section, rank |
| Stable descriptive tags | Temporary display participation |
| Primary-per-scheme rules | Repeatable historical participations |

### vs `DisplayLocation`

`products.default_display_location` remains the **normal** placement model.

Assignment `display_location_id` is for **temporary merchandising override** during a display feature or program.

### vs v0.04-16 item entry

v0.04-16 owns descriptive metadata entry. v0.04-17 adds a **separate section** for participations — do not merge award/list fields into the progressive metadata form.

---

## Scope

### In scope

1. Seed feature category schemes and starter nodes (see data-model)
2. `product_feature_programs` table + model + minimal admin UI
3. `product_feature_assignments` table + model
4. Services:
   * `ProductFeatures::EffectiveAssignments`
   * `ProductFeatures::BadgePresenter`
   * `ProductFeatures::AssignmentValidator`
   * `ProductFeatures::SearchFilters`
5. Product detail + edit: **Recognitions & Features** section (grouped by kind)
6. Assignment create/edit/deactivate (permission-gated)
7. Item index filters (basic): award, staff pick, on display, currently active, expiring soon
8. Import hooks: `external_key`, `source`, `needs_review`, `metadata`
9. Permissions + audit events
10. POS/frontline compact badges via `BadgePresenter` with `context: :pos`

### Out of scope (deferred)

* POS discount linkage for promotions
* Bulk display planner UI
* Merchandising tasks / fixture capacity
* Normalized status reference table
* Advanced operational reports beyond basic filters
* Customer-facing website rendering (visibility flags exist; consumer site deferred)
* `classification_axis` column on schemes (deferred cleanup)
* Auto-hold or inventory effects from display programs

---

## Feature kinds (`feature_kind`)

Required on every assignment. Initial controlled values:

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

`ProductFeatures::AssignmentValidator` enforces status compatibility by `feature_kind`.

---

## Effective date rules

```text
effective_starts_on = assignment.starts_on || program.starts_on
effective_ends_on   = assignment.ends_on   || program.ends_on
```

Currently effective when:

```text
assignment.active = true
program.active = true (if present)
category node/scheme active (if vocabulary-backed)
effective_starts_on blank OR <= on_date
effective_ends_on blank OR >= on_date
store scope matches (if store provided)
visibility matches requested context
```

Assignment dates may fall outside program dates; validator sets `needs_review` or warns — does not hard-block in v1.

---

## Product vs variant attachment

| Feature | Attach to |
| ------- | --------- |
| Booker Prize, NYT Bestseller, IndieNext | `Product` |
| Staff Pick (default) | `Product` |
| Signed Copy Display, Used Copy Promotion | `ProductVariant` when SKU-specific |
| Paperback Sale | `Product` or `ProductVariant` per staff choice |

Rule: if the feature describes the title/release generally → **product**. If it applies only to a specific SKU/condition/format → **variant**.

---

## UI requirements

### Product detail — Recognitions & Features

Grouped sections (empty groups hidden):

```text
Recognitions     — awards, review callouts
Lists            — bestseller/featured lists, book clubs
Merchandising    — displays, promotions, vendor co-op
Staff & Events   — staff picks, event tie-ins, reading lists
```

Each row: feature name, status, key dates/rank, optional display location, badge preview.

Inactive/expired rows: collapsed history or separate “Show history” toggle (implementation choice — default hide from customer/POS contexts).

### Product edit

Staff with `products.feature_assignments.create` may:

* Choose vocabulary node **or** active program
* Set status, dates, rank, list name/date, notes, visibility
* Attach to product or specific variant
* Deactivate assignment

### Program admin

Lightweight CRUD for `product_feature_programs`:

* Name, program kind, optional template node, store, display location, date range, active
* Placement: **Setup → Classification** section or Items admin (implementation choice — default Setup)

### POS / frontline

Compact badges only via `BadgePresenter` with `context: :pos` — no full history wall.

### Overview tab (v0.04-15)

Optional: show compact badges in hero or facts region via `BadgePresenter` — use shared presenter; do not duplicate badge logic.

---

## Permissions (proposed)

```text
products.feature_assignments.read
products.feature_assignments.create
products.feature_assignments.update
products.feature_assignments.deactivate

products.feature_programs.read
products.feature_programs.manage

setup.category_schemes.*   # vocabulary only (existing)
```

| Role | Access |
| ---- | ------ |
| Cashier | Read effective badges (POS/staff visibility) |
| Bookseller | Read; optionally create staff picks (configurable) |
| Buyer | Manage assignments |
| Manager | Manage assignments + programs |
| Admin | Full access |

---

## Reporting / search (v1)

Filters via `ProductFeatures::SearchFilters`:

```text
has_feature_kind
has_category_node
has_program
feature_status
currently_featured
award_winner / award_shortlisted
on_display / on_promotion
staff_pick
feature_date_range
expiring_soon
```

No new Phase 9b operational report required for v0.04-17 completion; item index filters are sufficient.

---

## Import posture

Imports may match:

* product by identifier
* feature by `category_node_id`, normalized node key, or program id
* dedupe via `external_key` when present

Incomplete or ambiguous imports set `needs_review = true`. Unusual source fields go in `metadata` jsonb.

---

## Migration plan

1. Extend `CategoryScheme::PURPOSES` for feature schemes
2. Seed feature schemes + starter nodes
3. Migration: `product_feature_programs`
4. Migration: `product_feature_assignments`
5. Models, validations, associations
6. Services (effective, badge, validator, search)
7. Permissions + seeds
8. Program admin UI
9. Product detail/edit Recognitions & Features section
10. Item index filters
11. Tests + `shelfstack:v00417:verify_product_feature_assignments`

---

## v0.04-16 alignment

v0.04-17 mounts the **Recognitions & Features** section on the v0.04-16 six-section product layout — recommended as section 7 or nested after **Format & Metadata**. Do not add feature participation fields to `Products::FieldVisibilityResolver`.

---

## Acceptance criteria (summary)

- [ ] Feature schemes and starter nodes seeded (`awards`, `featured_lists`, …)
- [ ] Vocabulary-backed assignment: Booker Prize shortlisted 2023 on a product
- [ ] Program-backed assignment: product on Summer Reading Display 2026
- [ ] Staff pick with `recommended_by_user_id` and label text
- [ ] Effective assignments respect dates, store scope, and visibility
- [ ] POS badges compact; full detail on product edit
- [ ] Duplicate warnings via validator; `needs_review` on suspicious imports
- [ ] Deactivate assignment preserves history
- [ ] Verifier task passes with `STRICT=1`
