# v0.04-16.1 Unified Product Management & Form Stability — Data Model

## Status

**Draft**

Spec: [spec.md](spec.md) · Test plan: [test-plan.md](test-plan.md)

---

## Architecture

v0.04-16.1 does **not** introduce a new product metadata table. It changes how the existing fused `products` model is presented and how dynamic form visibility is applied.

```text
Products::EntryContext (server authoritative)
        ↓
Embedded JSON bootstrap on initial render
        ↓
On driver change → GET /items/product_entry_context (driver fields only)
        ↓
Stable Product form shell (mounted fields)
        ↓
Client show/hide/disable/required
        ↓
Submit → MetadataParamsSanitizer → Product save
        ↓ (16.1B)
Unified Add/Edit Product workflow + optional default variant
```

Retained from v0.04-16:

```text
Products::FieldVisibilityResolver
Products::FormatEligibility
Products::OperationalTypeDeriver
Products::ItemKindNormalizer
Products::FieldLabelResolver
Products::EntryContext
Products::MetadataParamsSanitizer
Products::GenreSync
```

---

## Schema policy

### Permitted changes

| Change | Reason |
| ------ | ------ |
| No required product metadata table | Fused columns already on `products` |
| Optional small migration only if needed for form support already started (e.g. `internal_notes`) | Support fields already in visibility matrix |
| JSON context endpoint (controller only) | Driver-field context without HTML replacement |
| Stimulus / view structure changes | Stable shell + visibility application |
| Workflow/route/label changes | Unified Add/Edit Product |

### Do not add

* Parallel product metadata table
* Mandatory client form-state persistence table/session store
* Rename `catalog_item_type` → `item_kind` in this milestone
* Drop `products.name`
* Drop `catalog_items`

---

## Stable Product form shell

### Field wrapper contract

Each ordinary field (or logical field group) is wrapped with stable identity:

```html
<div id="product-field-page-count"
     data-product-field-key="page_count"
     data-product-form-target="field"
     data-visible="true">
  <!-- input keeps stable name="product[page_count]" -->
</div>
```

Required attributes / conventions:

| Contract | Purpose |
| -------- | ------- |
| `data-product-field-key` | Matches `FieldVisibilityResolver` field key |
| Stable input `name` | Survives visibility toggles |
| Stable DOM node | Value retained when hidden |
| Cover/file inputs outside dynamic regions | Browser file selection safety |

### Mounted vs lazy

| Widget class | Policy |
| ------------ | ------ |
| Ordinary inputs, selects, textareas, checkboxes, currency fields | Remain mounted; hide/disable |
| Controlled picker visible UI | May hide; canonical hidden inputs stay mounted in stable shell |
| Heavy tree/search UI | May lazy-mount; canonical values still in stable hidden inputs |
| Cover image / file field | Always in stable shell; never removed dynamically |

### Short form

Service and Non-Inventory use the **same** stable shell. Short presentation hides/disables irrelevant sections. Do not switch to an unrelated form architecture or alternate partial tree that unmounts the shared field set.

---

## Field key anti-drift

Shared field keys must drive:

| Consumer | Uses keys for |
| -------- | ------------- |
| View wrappers | `data-product-field-key` |
| Client Product form controller | show/hide/disable/required |
| `FieldVisibilityResolver` / `EntryContext` | visibility + required |
| `MetadataParamsSanitizer` | which params are accepted |
| Field labels | `FieldLabelResolver` / context payload |

Implementation options (either acceptable):

* Small registry / mapping object consumed by views and sanitizer
* Payload generated from `EntryContext` that includes field keys + param names

Do not maintain unrelated separate field-key lists in views, JS, and sanitizers.

---

## Client visibility policy

Driver fields:

```text
staff_item_kind / Type
digital
format_id
variation_type
```

### Definitive context path

1. Initial page embeds current `EntryContext` JSON.
2. On any driver change, fetch `GET /items/product_entry_context` with driver fields only.
3. Client applies returned visibility/labels/formats/scheme.
4. Client does **not** own a duplicated resolver matrix.

On driver change, client applies:

| Attribute | Rule |
| --------- | ---- |
| `hidden` / `aria-hidden` | From `field_visibility[key].visible` |
| `disabled` on inputs | `true` when field/group hidden |
| `required` | Set only when visible **and** required; removed when hidden |
| Labels | From `field_labels` when present |
| Format options | Replace `<option>` list from `eligible_formats` without replacing the select node when practical; restore selected value |
| Controlled scheme | Show BISAC vs genre picker region; disable canonical inputs when invalid for Type; do not erase staged values |

### Why disable when hidden

Disabled inputs are not submitted by the browser. That reduces accidental persistence of invalid-for-Type values. The server sanitizer remains authoritative and must not trust client disabled/hidden state.

Values remain in the DOM while disabled. Re-enabling restores the staged value without a separate state store for ordinary mounted fields.

### Ordinary vs rebuilt controls

| Control type | Retention rule |
| ------------ | -------------- |
| Ordinary mounted scalar inputs | DOM value retention while hidden/disabled is sufficient |
| Selects whose options are rebuilt | Explicitly restore selected value after option replacement |
| Currency widgets | Restore cents + display from staged value |
| Controlled pickers | Canonical hidden inputs staged; UI may rebuild from them |
| Unmounted heavy widgets only | Optional client state store |

---

## Product entry context endpoint

### Route

```text
GET /items/product_entry_context
```

### Request (driver fields only)

```text
product_id          # optional (edit)
staff_item_kind
digital
format_id
variation_type
```

### Response

```json
{
  "staff_item_kind": "book",
  "catalog_item_type": "book",
  "operational_product_type": "physical",
  "short_form": false,
  "controlled_scheme": "bisac",
  "field_visibility": {
    "page_count": { "visible": true, "required": false },
    "duration_minutes": { "visible": false, "required": false },
    "format": { "visible": true, "required": false }
  },
  "field_labels": {
    "publisher": "Publisher",
    "genre_scheme": "Subjects"
  },
  "eligible_formats": [
    { "id": 1, "name": "Hardcover", "format_key": "trade_cloth" }
  ]
}
```

Notes:

* `controlled_scheme` may be a scheme key (`music_genres`, etc.) or a sentinel for BISAC.
* Field keys must align with `Products::FieldVisibilityResolver::FIELD_KEYS` (and documented aliases if any).
* Payload is for UX only; submit validation remains server-side.

### Forbidden

* Full-form GET query serialization
* Returning Turbo Frame HTML as the primary dynamic visibility mechanism

---

## Form state and submit semantics

### Pre-submit

| Concept | Meaning |
| ------- | ------- |
| Visible | Staff should see the field now |
| Required | Must be present for selected Type |
| Staged | Present in browser DOM (possibly hidden/disabled) |
| Submittable | Accepted by sanitizer for selected Type |
| Intentionally cleared | Visible field submitted blank |
| Not submitted | Hidden/disabled field absent from payload |

Because hidden fields are disabled, they are not included in the submitted form payload. The save layer must treat absence of a hidden/disabled field as **“not submitted,”** not as **“clear this value.”** Only visible submitted fields with blank values should clear existing values.

### After failed validation

Re-render from:

* sanitized accepted **visible** params
* submitted Type / driver context
* validation errors

Do not lose the user’s submitted visible edits by reverting to persisted DB values.

Invalid-for-Type hidden staged values are **not guaranteed** to survive the server round-trip. Pre-submit temporary toggles must preserve values client-side.

---

## Preview-safe params

If any temporary server HTML preview path remains:

```text
Products::MetadataPreviewParams
```

Responsibilities:

* Allowlist preview-safe product attributes only
* Ignore UI-only / helper / identifier staging fields unless explicitly needed for display
* Mirror save sanitizer visibility filtering where practical
* Never broad `assign_attributes` from raw params

Preferred end state: remove HTML preview replacement entirely.

---

## Save sanitizer policy

`Products::MetadataParamsSanitizer` remains authoritative.

| Mode | Behavior |
| ---- | -------- |
| `:new` | Drop keys not visible for current `EntryContext` |
| `:edit`, kind unchanged | Permit only visible keys; absent/hidden keys do **not** null existing DB columns |
| `:edit`, kind changed | Permit visible keys; signal classification cleanup (`:_classification_cleanup` or equivalent) |

Security rule: never trust client `disabled` / `hidden` for authorization of persistence.

---

## Controlled picker storage

Canonical staged values (examples):

```text
primary_bisac_category_node_id
bisac_category_node_ids[]
primary_genre_category_node_id
genre_category_node_ids[]
```

Placement:

```text
Stable form shell
  └── canonical hidden inputs (always mounted)
  └── picker UI regions (shown/hidden by scheme)
```

On temporary Type change away from Book/Music/etc.:

* Hide picker UI
* Keep canonical hidden values staged
* Disable canonical inputs while picker is invalid for Type

On submit:

* Ignore picker values invalid for selected Type
* If kind changed on a persisted product, run explicit cleanup for incompatible `categorizations`

Do not clear staged picker values merely because the client toggled Type during editing.

---

## Title / name sync

| Field | Staff-facing | Persistence role |
| ----- | ------------ | ---------------- |
| `title` | **Title** (editable) | Canonical product title |
| `name` | Not edited on normal form | Compatibility/display cache |
| `name_override` | Not on normal form | Reserved/advanced |

On save:

```text
title = staff Title
name  = ProductNameRenderer.product_name(product)  # or equivalent sync rule
```

Existing renderer precedence may still honor `name_override` if present on legacy rows, but normal 16.1 forms do not expose it.

Variant names continue to derive from product display name + variation attributes via existing `ProductNameRenderer`.

---

## Operational type derivation

Unchanged conceptually from v0.04-16:

| Staff Type | Digital | Derived `product_type` |
| ---------- | ------- | ---------------------- |
| Book / Music / Video / Game (etc.) | false | `physical` |
| Book / Music / Video / Game (etc.) | true | `digital` |
| Service | n/a | `service` |
| Non-Inventory | n/a | `non_inventory` |
| Sideline / Other / Periodical / Calendar | false | `physical` |

Normal Product forms must not permit direct staff editing of `product_type`.

---

## Product defaults vs variant finals

| Product-level default | Variant-level final value |
| --------------------- | ------------------------- |
| `list_price_cents` | `selling_price_cents` |
| `default_sub_department_id` | `sub_department_id` |
| `default_display_location_id` | `display_location_id` |
| product discountable default | variant `discountable` |
| product `default_inventory_tracking` | variant inventory tracking / behavior |

---

## Service / Non-Inventory default variant seeds

When staff uses the primary Service/Non-Inventory save CTA (not “Save Product Only”):

```text
Create ProductVariant
  product.variation_type: standard (typical)
  selling_price_cents: product.list_price_cents (or 0)
  sub_department_id: product.default_sub_department_id (required)
  display_location_id: product.default_display_location_id if present
  discountable: product discountable default
  active: true
  orderable: false unless explicitly enabled by existing policy
  inventory tracking / behavior: seeded via existing
    AddItem::InventoryTrackingMapper / InventoryBehaviorMapper
    for product.product_type (service → capacitated_service;
    non_inventory → non_inventory)
  sku: system-assigned
```

If required defaults are missing (especially subdepartment), **block auto-create** and show validation on the Product form. Do not invent a new “inventory tracking = none” concept; use existing product-type mapping services.

---

## Unified workflow data flow

### Add Product

```text
Add Product
  → optional identifier/lookup prefill
  → unified Product form (EntryContext-driven)
  → save Product (+ identifiers as applicable)
  → Create Variant
     or Service/Non-Inventory auto-create default variant
     or explicit Save Product Only
```

### Edit Product

```text
Edit Product (all Product Summary products, including formerly catalog-linked)
  → same stable form shell
  → sanitizer + kind-change cleanup
  → Product Summary
```

Legacy `edit_metadata` / bibliographic routes 302 to unified edit for compatibility. Legacy CatalogItem edit remains admin/import-only.

---

## Current fragile paths to retire

| Path | Problem |
| ---- | ------- |
| `product_metadata_form_controller.js` full `FormData` → GET → `frame.src` | DOM replacement + long URLs + value loss |
| `ProductMetadataSectionsRefreshable#apply_metadata_preview_attributes!` raw assign | Preview bypasses sanitizer |
| `data-controller="catalog-item-form product-metadata-form"` dual change handlers | Overlapping legacy behavior |
| Picker state inside replaced `_sections` frame | Staged selection loss |
| `choose_path` Catalog-linked / Non-catalog | Staff-facing implementation split |
| `edit_metadata` Bibliographic Details as primary | Dual edit surfaces |

---

## Audit

Preserve existing product create/update audit behavior. Extend only if unified edit/create paths lose events that bibliographic/product paths previously emitted.

Suggested event names remain existing patterns (`product.created`, `product.updated`, etc.). Do not invent a parallel catalog-item audit stream for normal Product edits.

---

## Summary

```text
No new core product tables
+ stable mounted form shell
+ EntryContext bootstrap + driver-only context fetch
+ client hide/disable policy
+ MetadataParamsSanitizer save authority
+ title→name sync
+ Service/Non-Inventory default variant seeds
+ unified Add/Edit Product routing in 16.1B
```
