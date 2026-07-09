# v0.04-17 Product Feature Assignments — Test Plan

## Status

**Draft**

Spec: [spec.md](spec.md) · Data model: [data-model.md](data-model.md)

Prerequisite: v0.04-16 product entry revamp verifier green (or waived with documented dependency).

---

## Merge gate

```bash
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v00417:verify_product_feature_assignments
```

Verifier checks (minimum):

* feature schemes seeded (`awards`, `featured_lists`, `display_programs`, …)
* assignment anchor rule enforced (node xor program)
* `ProductFeatures::EffectiveAssignments` returns expected active set
* `ProductFeatures::BadgePresenter` respects visibility + dates + context
* product detail renders Recognitions & Features section
* permissions enforced on mutate paths
* `Categorization` behavior unchanged

---

## Test categories

| Category | Focus |
| -------- | ----- |
| Model — program | Validations, dates, store scope |
| Model — assignment | Anchor rule, variant/product FK, rank, visibility defaults |
| Service — effective | Date resolution, store filter, inactive exclusion |
| Service — badge | Context visibility, label_text preference |
| Service — validator | Status by kind, duplicates, needs_review |
| Service — search filters | currently_featured, staff_pick, expiring_soon |
| Integration — product UI | Section render, create, deactivate |
| Integration — programs | CRUD, inactivate |
| Integration — item index | Feature filters |
| Regression | Categorization, store_categories, inventory, v0.04-15 overview |

---

## Model tests

### `ProductFeatureProgram`

* required `name`, `program_kind`
* date order validation
* optional `category_node` must be active and scheme-compatible
* inactivate/reactivate

### `ProductFeatureAssignment`

* requires `product_id`, `feature_kind`
* requires `category_node_id` xor `product_feature_program_id`
* rejects both anchors missing; rejects both present (normal rule)
* variant must belong to product
* rank positive when present
* visibility defaults (`website_visible` false by default)
* `metadata` defaults to `{}`

---

## Service tests

### `ProductFeatures::EffectiveAssignments`

* resolves assignment vs program dates
* filters inactive assignment/program/node
* store-scoped filtering
* includes product-level assignments when variant passed
* excludes expired assignments for `on_date: today`
* respects `visibility: :pos` vs `:staff`

### `ProductFeatures::BadgePresenter`

* uses `label_text` when present
* maps award shortlisted → compact label
* hides `public_visible: false` in customer context
* hides expired assignments

### `ProductFeatures::AssignmentValidator`

* invalid status for feature_kind → error
* duplicate same product + node + year + status → warning
* assignment dates outside program dates → `needs_review`
* store scope mismatch → error

### `ProductFeatures::SearchFilters`

* `currently_featured` scope
* `award_shortlisted` scope
* `staff_pick` scope
* `expiring_soon` scope

---

## Integration tests

### Product detail / edit (new or extended)

| Test | Assertion |
| ---- | --------- |
| Recognitions section | Award assignment appears grouped under Recognitions |
| Lists section | NYT list row shows rank, list_name, list_date |
| Create assignment | Authorized user POST creates assignment |
| Deactivate | Assignment `active: false`; hidden from effective badges |
| Unauthorized | Mutate without permission → 403/redirect per app pattern |
| Variant-specific | Assignment with `product_variant_id` shows on variant context |

### Program admin

| Test | Assertion |
| ---- | --------- |
| Create program | Summer Reading 2026 with dates and store |
| Assign to program | Product linked via `product_feature_program_id` |
| Inactivate program | New assignments blocked; existing history retained |

### Item index

| Test | Assertion |
| ---- | --------- |
| Filter staff_pick | Returns products with active staff pick assignments |
| Filter on_display | Returns products in active display assignments/programs |

### Audit

| Test | Assertion |
| ---- | --------- |
| Create assignment | `product_feature_assignment.created` audit event |
| Deactivate | `product_feature_assignment.deactivated` audit event |

---

## Regression guards

| Area | Assertion |
| ---- | --------- |
| `Categorization` | BISAC/genre assignments unchanged |
| `store_categories` | Store category on product unchanged |
| Inventory | No postings from assignment create/deactivate |
| v0.04-15 Overview | Overview still renders; optional badges do not break contract |
| Orderability / POS | No change to completion paths |

---

## Manual verification

1. Seed schemes visible in Setup → Category Schemes
2. Create award assignment on product → appears in Recognitions & Features
3. Create program + assign products → merchandising group shows rows
4. Staff pick shows recommender label
5. Expired assignment hidden from POS badges, visible in edit/history
6. Item index filter by staff pick returns expected products

---

## Verifier implementation notes

Rake task `shelfstack:v00417:verify_product_feature_assignments` should:

1. Assert feature scheme keys exist with starter nodes
2. Assert assignment anchor validation in model or validator
3. Smoke `EffectiveAssignments` + `BadgePresenter` with fixture contexts
4. Assert product show template includes Recognitions & Features region id

Follow pattern from `shelfstack:v00416:verify_product_entry_revamp`.
