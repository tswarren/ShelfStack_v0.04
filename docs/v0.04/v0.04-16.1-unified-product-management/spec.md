# v0.04-16.1 Unified Product Management & Form Stability — Functional Specification

## Status

**Draft** — finishes the staff-facing Product transition begun in v0.04-16, and stabilizes the dynamic Product form before that form becomes the single create/edit surface.

Companion documents:

* [data-model.md](data-model.md) — form shell, visibility policy, sanitizer modes, context payload, auto-variant seeds
* [test-plan.md](test-plan.md) — value preservation, hidden-field submit, picker, workflow gates

Related:

* [v0.04-16 product entry revamp](../v0.04-16-product-entry-revamp/spec.md) — resolvers, formats, genre pickers, progressive metadata form, variant form rules
* [v0.04-16 completion](../../implementation/v0.04-16-completion.md)
* [v0.04-1 product fusion](../v0.04-1-product-fusion/spec.md) — fused metadata on `products`
* [v0.04-15 overview refactor](../v0.04-15-products-overview-refactor/spec.md) — Product Summary read surfaces
* [v0.04-2 product identifiers](../v0.04-2-product-identifiers/spec.md) — identifiers / SKU rules

**Tracks:**

| Track | Name | Goal |
| ----- | ---- | ---- |
| **v0.04-16.1A** | Form Stability | Stable Product form mechanics |
| **v0.04-16.1B** | Unified Product Management | One Add/Edit Product workflow and vocabulary |

**Hard sequencing rule:** Do not route the unified Add/Edit Product workflow through the current Turbo Frame section-replacement mechanic. Complete 16.1A before 16.1B workflow cutover.

---

## Job

Make Product the only staff-facing create/edit concept, and make the dynamic Product form safe to use.

```text
Add Product → Product Details → Create Variant
Edit Product (one form)
```

Staff should not choose “Catalog-linked” vs “Non-catalog,” or edit “Bibliographic Details” separately from “Product.”

The form remains item-kind aware (Type / Item kind, Digital, Format, Variation type). Changing those drivers updates visibility without destroying unsaved work, jumping scroll/focus, or losing controlled picker selections.

---

## Guiding principles

1. **Product is the staff record.** Catalog Item is legacy/admin/import vocabulary only.
2. **Dynamic visibility ≠ dynamic data loss.** Hiding a field must not erase staged browser values during pre-submit editing.
3. **Browser stages; server saves.** Client preserves editing state; `Products::MetadataParamsSanitizer` (and related services) decide what persists.
4. **Reuse v0.04-16 resolvers.** Do not rewrite domain rules into ad hoc JS or view branches.
5. **Stabilize before unify.** Form correctness first; workflow/label cutover second.
6. **Shared field keys.** The same field keys drive DOM wrappers, client visibility, server visibility, and sanitizer mappings.

---

## Resolved decisions

| Decision | Choice |
| -------- | ------ |
| Milestone id | **v0.04-16.1** unified product management & form stability |
| Tracks | **16.1A** form stability, then **16.1B** unified workflow |
| Form refresh mechanic | **Stop** replacing large Turbo Frame HTML for visibility changes |
| Field mounting | Ordinary fields remain **mounted** in a stable shell; toggle visibility |
| Hidden client policy | When hidden: `hidden` + remove `required` + **disable** input; re-enable when shown |
| Client state store | **Not required** for ordinary mounted fields; optional only for heavy unmounted widgets |
| Rebuilt controls | Any control whose options/UI can be rebuilt must restore selected/canonical values explicitly |
| Visibility rules source | Initial page **embeds** `EntryContext` JSON; on driver change, **fetch** driver-only JSON context (client does not own the visibility matrix) |
| Context endpoint | `GET /items/product_entry_context` (driver fields only) |
| Full-form GET serialization | **Forbidden** for context/preview |
| Preview HTML replacement | **Remove** as the primary dynamic path; if any preview remains, use preview-safe sanitizer |
| Controlled pickers | Canonical hidden inputs live in the **stable shell**; disable when picker invalid for selected Type |
| Picker staging | Preserve staged BISAC/genre selections across temporary Type changes |
| Classification cleanup | Clear incompatible categorizations **only on successful save** when item kind actually changed |
| Staged-value warning UI | **Deferred** (optional polish after 16.1A); not acceptance-critical |
| Staff Type label | **Type** (or **Item kind**); storage remains `catalog_item_type` |
| Operational `product_type` | Derived; **hidden** from normal staff forms |
| Title vs name | Staff edit **Title** only (`products.title`); sync/regenerate `products.name` internally |
| `name_override` | Not on normal Add/Edit Product form (advanced/admin later if needed) |
| List price | Currency UI; store cents |
| Add path | Unified **Add Product** (optional lookup/identifier assist) |
| Edit path | Unified **Edit Product** for **all** products shown on Product Summary, including formerly catalog-linked |
| Legacy catalog item edit | Retain-temporary admin/import only; not linked from Product Summary |
| Service / Non-Inventory | Same form shell + short presentation (hide sections; do not swap form architecture) |
| Service / Non-Inventory variants | **Auto-create** one standard default variant on save, unless explicit “Save product only” |
| Ordinary create CTAs | Primary: **Save and Create Variant**; Secondary: **Save Product Only** |
| Service / Non-Inventory CTAs | Primary: **Save Product and Create Default Variant**; Secondary: **Save Product Only** |
| `catalog_items` table | Retain-temporary; not part of normal staff Product workflow |
| Drop `products.name` | **Out of scope** |
| Variant form field rules | Retain v0.04-16 simplified variant rules; cite that spec (do not reinvent here) |
| v0.04-17 features | **Out of scope** |
| Default Type on blank Add Product | **Book** |
| Periodical controlled genres | Deferred |
| Non-Inventory physical dimensions | Hidden |

---

## Hard gates

1. **Do not** replace large Product form sections via Turbo Frame for Type/Digital/Format/Variation changes.
2. **Do not** serialize the full form into a GET query string.
3. **Do not** assign raw preview/context params to `Product` without a preview-safe allowlist/sanitizer (if any server preview path remains).
4. **Do not** clear existing DB metadata merely because a field is hidden or absent from submit.
5. **Do not** clear staged controlled picker values on temporary client Type toggles.
6. **Do not** expose operational `product_type` or manual SKU editing on normal Product forms.
7. **Do not** present Catalog-linked vs Non-catalog as the primary Add Product choice.
8. **Do not** present Edit Bibliographic Details as a separate staff edit target for fused products.
9. **Do not** break v0.04-16 resolver contracts (`EntryContext`, visibility, format eligibility, operational type derivation, item-kind normalization, save sanitizer).
10. **Do not** break v0.04-2 identifier/SKU assignment rules.
11. **Do not** depend on legacy `catalog-item-form` for Product form behavior.
12. Field visibility remains centralized in `Products::FieldVisibilityResolver` (server authoritative).
13. **Do not** treat missing hidden/disabled params as instructions to clear existing values.
14. **Do not** link ordinary Product Summary actions to retain-temporary `catalog_items` edit routes.
15. **Do not** regress Ingram/import product creation, buyback product/variant resolution, or POS SKU/lookup-code findability.

---

## Current code to replace

The following current mechanisms are explicitly replaced by **16.1A**:

| Current mechanism | Path / behavior | Replacement |
| ----------------- | --------------- | ----------- |
| Full-form GET + `frame.src` | `app/javascript/controllers/product_metadata_form_controller.js` `#reloadSections` | Client visibility on mounted fields + driver-only context fetch |
| Dual controller root | `app/views/items/shared/product_forms/metadata/_form.html.erb` mounts `catalog-item-form product-metadata-form` | Product form controller + narrow preview/picker controllers |
| Raw preview assign | `Items::ProductMetadataSectionsRefreshable#apply_metadata_preview_attributes!` | Remove as primary path; preview-safe allowlist only if temporary HTML preview remains |
| HTML sections refresh | `metadata_sections` → `sections_turbo_frame` as primary dynamic visibility path | `GET /items/product_entry_context` JSON |
| Picker state in replaced sections | BISAC/genre state rendered inside `_sections` / internal controls frame | Canonical picker inputs in stable shell |

The following current staff UX is replaced by **16.1B**:

| Current UX | Path | Replacement |
| ---------- | ---- | ----------- |
| Catalog-linked / Non-catalog choice | `items/add_item/choose_path` | Unified **Add Product** |
| Catalog-linked / Non-catalog titles | `items/add_item/item_details` | **Add Product — Product Details** |
| Bibliographic Details edit | `items/products/edit_metadata` as primary surface | Unified **Edit Product**; `edit_metadata` becomes compatibility redirect |
| Direct `product_type` / `sku` / dual name editing | `Items::ProductsController#product_params` + product forms | Derived operational type; Title-only; no normal SKU field |

Compatibility may keep old routes temporarily, but Product Summary and Add Product must not present them as primary staff paths.

---

## Form state and submit semantics

The Product form distinguishes staged browser values from submitted values.

### Pre-submit editing

* Hidden fields remain mounted and retain their DOM value.
* Hidden fields are **disabled** while hidden (and `required` is removed).
* Because disabled inputs do not submit, the server must treat **absence of a hidden/disabled field as “not submitted,” not as “clear this value.”**
* Only **visible** submitted fields may intentionally clear existing values by submitting blank values.
* Controlled picker canonical inputs follow the same policy: preserve staged DOM values; disable when the picker is not valid for the selected Type; sanitizer ignores invalid picker values if somehow submitted.

### After failed validation

```text
Submit invalid Product
→ re-render form
→ preserve submitted/accepted visible values
→ show validation errors
→ apply visibility for the submitted Type context
```

A failed save must not fall back to persisted database values in a way that loses the user’s submitted visible edits.

Hidden staged values that were invalid for the selected Type are **not guaranteed** to survive the server round-trip unless intentionally supported. Pre-submit temporary Type toggles must preserve values client-side; post-submit restoration of invalid-for-Type staged values is not required for 16.1.

### Ordinary vs rebuilt controls

* Ordinary mounted scalar inputs may rely on DOM value retention while hidden/disabled.
* Any control whose options, hidden canonical value, or widget UI can be rebuilt (format select options, picker UI, currency widget display) must have explicit restore behavior for selected/canonical values.

---

## Field key anti-drift

The Product form must use shared field keys so the same keys drive:

* DOM wrappers (`data-product-field-key`)
* client visibility application
* server `FieldVisibilityResolver` / `EntryContext`
* sanitizer param mappings

Do not maintain unrelated separate field-key lists in views, JavaScript, and sanitizers. Implementation may be a small registry object or a payload generated from `EntryContext`; the requirement is shared keys, not a specific class name.

---

## Track A — Form Stability (v0.04-16.1A)

### A1. Stable Product form shell

Render one stable Product form shell for create and edit.

Requirements:

* Ordinary metadata and default fields that may apply to any Type are present in a predictable structure.
* Each field wrapper has stable identity:
  * `id` (where practical)
  * `data-product-field-key`
  * stable input `name`
* Cover image / file inputs live in the stable shell and are never dynamically removed.
* Controlled picker **canonical hidden inputs** live in the stable shell.

Visibility changes apply by updating attributes on existing nodes:

```text
hidden / aria-hidden
disabled (when hidden)
required removed when hidden; restored when visible+required
data-visible
labels when EntryContext labels change
format <option> list when eligibility changes (restore selected value)
```

**Do not** destroy and recreate field inputs for ordinary visibility updates.

Service and Non-Inventory use this **same** stable shell. Short presentation means irrelevant fields/sections are hidden and disabled — not that the form swaps to a different dynamic form implementation.

### A2. Client Product form controller

Replace the current `product-metadata-form` Turbo Frame reload path with a Product form controller that:

1. Watches driver fields: Type / staff item kind, Digital, Format, Variation type
2. Applies visibility/required/label updates from context JSON
3. Fetches updated context on driver change
4. Preserves focus and scroll (by not replacing the form body)
5. Does not make final save decisions

Remove Product-form dependence on `catalog-item-form` for show/hide. Keep narrow controllers for:

* creator preview
* subject/theme preview
* currency fields
* identifier preview
* classification pickers

### A3. Product entry context endpoint

**Initial render:** embed current `EntryContext` JSON on the form.

**On any driver change:** fetch JSON context from the server using only driver fields. The client does not duplicate the resolver matrix except for trivial UI wiring.

#### Route

```text
GET /items/product_entry_context
```

#### Allowed params

```text
product_id          # optional (edit)
staff_item_kind
digital
format_id
variation_type
```

Optional namespacing (`product[...]`) may be accepted for form compatibility. Full form state must not be required.

#### Response

```json
{
  "staff_item_kind": "book",
  "catalog_item_type": "book",
  "operational_product_type": "physical",
  "short_form": false,
  "controlled_scheme": "bisac",
  "field_visibility": {
    "page_count": { "visible": true, "required": false },
    "duration_minutes": { "visible": false, "required": false }
  },
  "field_labels": {
    "publisher": "Publisher"
  },
  "eligible_formats": [
    { "id": 1, "name": "Hardcover", "format_key": "trade_cloth" }
  ]
}
```

**Forbidden:** full-form state in GET query strings.  
**Forbidden:** returning replacement form HTML as the primary dynamic mechanism.

`metadata_sections` HTML refresh may remain temporarily only as a compatibility/debug path; it must not remain the normal visibility mechanism.

### A4. Hidden-field client policy

| State | Client behavior |
| ----- | --------------- |
| Visible + required | shown, enabled, `required` set |
| Visible + optional | shown, enabled, no `required` |
| Hidden | hidden, **disabled**, `required` removed; value retained in DOM |
| Shown again | re-enabled; prior value still present |
| Picker invalid for Type | picker UI hidden; canonical inputs disabled but staged |

Optional client state store is allowed only for widgets that must unmount. It is not the default architecture.

### A5. Preview / save safety

Save path remains authoritative via `Products::MetadataParamsSanitizer` + `Products::EntryContext`.

If any server-side preview/context HTML path remains temporarily:

* Add `Products::MetadataPreviewParams` (or equivalent) that allowlists preview-safe attributes
* Do **not** `assign_attributes` from raw params

Preferred end state: no HTML preview replacement; context JSON only.

### A6. Controlled picker stability

BISAC and genre pickers:

* Canonical values stored in stable hidden inputs outside dynamic sections
* Visible picker UI reads/writes those inputs
* Temporary Type change may hide picker UI but must not erase staged canonical values
* Canonical inputs are disabled when the picker is invalid for the selected Type
* On submit:
  * invalid-for-kind picker values are ignored
  * incompatible saved categorizations are cleared only via explicit item-kind-change cleanup after successful save

### A7. Scroll and focus

Acceptance:

* Changing Type, Digital, Format, or Variation type must not jump the page to the top
* Focus remains on the driver field, or moves predictably if the active field becomes hidden

Because fields stay mounted, dedicated scroll/focus restore hacks should be unnecessary for the common path. Add system coverage for the acceptance rule.

---

## Track B — Unified Product Management (v0.04-16.1B)

### B1. Add Product workflow

Replace:

```text
Catalog-linked item → …
Non-catalog item → …
```

With:

```text
Add Product
  → optional identifier/lookup assist
  → unified Product form
  → save Product
  → Create Variant
```

Lookup/import is prefill assistance, not a product subtype.

`choose_path` either disappears or becomes an optional assist step (lookup/manual), not a catalog-vs-non-catalog product-type fork.

#### Create CTAs

| Product kind | Primary CTA | Secondary CTA |
| ------------ | ----------- | ------------- |
| Ordinary (Book, Music, etc.) | **Save and Create Variant** | **Save Product Only** |
| Service / Non-Inventory | **Save Product and Create Default Variant** | **Save Product Only** |

After ordinary “Save and Create Variant”: continue to Create Variant.  
After Service/Non-Inventory auto-create: redirect to Product Summary (variant exists).  
After “Save Product Only”: redirect to Product Summary without requiring a variant.

### B2. Edit Product workflow

Replace separate staff targets:

```text
Edit Bibliographic Details
Edit Product
```

With one:

```text
Edit Product
```

Rules:

* Product Summary always links to unified **Edit Product** for all products, including formerly catalog-linked / fused products.
* `edit_metadata` remains only as a compatibility route and redirects to unified Edit Product.
* `update_metadata` may merge into `update` or remain as a thin compatibility endpoint that applies the same unified form/sanitizer path.
* Legacy CatalogItem edit remains reachable only from retain-temporary admin/import surfaces, not from Product Summary.

### B3. Type / operational type

Staff choose **Type** (Item kind). Operational `product_type` is derived via existing `Products::OperationalTypeDeriver` / `EntryContext` and is not shown on normal forms.

Service and Non-Inventory remain first-class staff Types (never displayed as plain “Other”).

### B4. Title / name

Normal forms expose one field: **Title** → `products.title`.

On save:

* Sync/regenerate `products.name` from title (and existing renderer rules) for compatibility
* Do not expose dual title/name editing
* `name_override` not on normal form

Dropping `products.name` is out of scope.

### B5. Identifiers and SKUs

* Primary identifier managed through `product_identifiers`
* Blank primary identifier may auto-generate per existing v0.04-2 / Add Item rules
* Manual product SKU editing is not part of the normal Product form
* Variant SKU remains system-assigned; normal variant form does not expose SKU editing

### B6. Product defaults vs variant finals

| Product-level default | Variant-level final value |
| --------------------- | ------------------------- |
| `list_price_cents` | `selling_price_cents` |
| `default_sub_department_id` | `sub_department_id` |
| `default_display_location_id` | `display_location_id` |
| product discountable default | variant `discountable` |
| product default inventory tracking | variant inventory tracking / behavior |

Product form owns defaults. Variant form owns the sellable SKU’s final values.

### B7. Service / Non-Inventory

Same stable form shell; short presentation (hide format/genre/publisher/physical/etc.).

On primary save (unless “Save Product Only”):

* Auto-create one active `standard` default variant suitable for POS
* Seed defaults as defined in [data-model.md](data-model.md)
* If required defaults are missing (e.g. subdepartment), block auto-create and show validation on the Product form

### B8. Create Variant (cite v0.04-16)

Variant form behavior remains as specified in [v0.04-16 product entry revamp](../v0.04-16-product-entry-revamp/spec.md):

* conditional requires condition
* variable requires attribute 1
* matrix requires attributes 1 and 2
* selling price uses currency UI; defaults from product list price where applicable
* subdepartment / display location default from product defaults where applicable
* SKU is not editable on the normal variant form

16.1B does not reinvent those rules; it routes unified Product create into that Create Variant step.

### B9. Product Summary vocabulary sweep

| Area | Must not show as primary | Must show |
| ---- | ------------------------ | --------- |
| Add entry | Catalog-linked item / Non-catalog item | Add Product |
| Product Summary action | Edit Bibliographic Details | Edit Product |
| Product form classification | Product type for Book/Music/etc. | Type / Item kind |
| Normal Product form | SKU / operational `product_type` / dual name editing | Title, Identifier, derived behavior |
| Product Summary language | Catalog Item as primary noun | Product, Identifier, Variant, Lookup Code, Vendor |

Primary actions:

```text
Edit Product
Add Variant
Add Identifier
Add Lookup Code
Add Vendor (if already supported)
```

### B10. Legacy retain-temporary

`catalog_items` admin/import/buyback-adjacent surfaces may remain where already retain-temporary. Existing routes may remain for compatibility, but item/product UI must not link ordinary staff to them as the primary edit path.

---

## Hidden-field submit policy (authoritative)

| Situation | Behavior |
| --------- | -------- |
| Create submit | Accept only fields valid/visible for selected Type context; ignore others |
| Edit submit, kind unchanged | Do not null existing DB values for fields absent/hidden/disabled |
| Edit submit, kind changed | Accept valid fields; run explicit incompatible classification cleanup |
| Intentionally cleared visible field | Persist blank/clear |
| Staged hidden browser values (pre-submit) | May exist client-side; not saved if invalid for selected Type |
| Submit fails validation | Re-render from sanitized accepted visible params + submitted Type context; show errors; do not lose submitted visible edits |
| Invalid hidden staged values after failed submit | Not guaranteed to remain staged after round-trip |
| Security | Never trust client hidden/disabled state; sanitizer is authoritative |

Formalize this in tests (see [test-plan.md](test-plan.md)).

---

## Compatibility route map

| Current route / action | 16.1 fate |
| ---------------------- | --------- |
| `items/add_item#choose_path` Catalog-linked/Non-catalog | Remove as required fork; optional lookup assist or redirect into Add Product |
| `items/add_item` item_details / selling_setup | Become unified Add Product details (and Create Variant continuation) |
| `items/products#edit` | Canonical **Edit Product** |
| `items/products#update` | Canonical Product update (unified form + sanitizer) |
| `items/products#edit_metadata` | Compatibility redirect → Edit Product |
| `items/products#update_metadata` | Merge into `update` or thin compatibility wrapper using same path |
| `items/products#metadata_sections` | Retire as primary visibility path; replace with `product_entry_context` |
| `items/catalog_items#edit` | Retain-temporary admin/import only; not Product Summary primary |

---

## Scope

### In scope — 16.1A

1. Stable Product form shell and field wrappers
2. Client visibility application without Turbo Frame section replacement
3. Remove full-form GET serialization
4. Remove Product dependence on `catalog-item-form` for visibility
5. Stable controlled picker canonical inputs
6. `GET /items/product_entry_context` contract
7. Preview-safe param handling if any preview path remains
8. Hidden-field client + submit + validation-failure policy tests
9. Scroll/focus acceptance coverage
10. Shared field-key anti-drift

### In scope — 16.1B

1. Unified Add Product entry (remove staff Catalog-linked / Non-catalog choice)
2. Unified Edit Product surface for all Product Summary products
3. Compatibility redirects for bibliographic routes
4. Hide operational `product_type` and normal SKU editing from Product forms
5. Title-only staff field; internal name sync
6. Service/Non-Inventory short presentation + default variant auto-create
7. Explicit create CTAs
8. Product Summary / action vocabulary alignment
9. Workflow/integration test updates
10. Regression gates for import, buyback, POS lookup

### Out of scope

1. Dropping `catalog_items` table
2. Removing `products.name` column
3. Rebuilding external lookup/import architecture
4. v0.04-17 feature assignments
5. Deep vendor-source redesign
6. Mandatory staged-value warning banner
7. Full client duplication of all resolver rules as long-term source of truth
8. Mandatory universal client form-state store for all fields
9. Guaranteeing invalid-for-Type staged values survive failed-submit round-trips

---

## Implementation slices

### Slice 1 — Stop section replacement (16.1A)

* Mount candidate fields in stable shell
* Client show/hide/disable/required
* Delete primary Turbo Frame reload path for visibility
* Keep cover image outside dynamic behavior
* Short-form = hide sections on same shell

### Slice 2 — Context endpoint (16.1A)

* Embed EntryContext on initial render
* Add `GET /items/product_entry_context`
* Fetch on driver change with driver fields only
* No full-form GET

### Slice 3 — Picker + sanitizer hardening (16.1A)

* Move canonical picker hidden inputs to stable shell
* Preview-safe sanitizer if needed
* Lock hidden-field submit + validation-failure policy with tests
* Shared field-key mapping

### Slice 4 — Unified Add Product (16.1B)

* Replace choose_path catalog/non-catalog fork
* One create form path + CTA rules
* Optional lookup assist remains assistive

### Slice 5 — Unified Edit Product + Summary vocabulary (16.1B)

* One Edit Product surface for all Product Summary products
* Redirect/retire bibliographic primary UX
* Hide operational fields
* Title-only + name sync
* Service/Non-Inventory default variant policy
* Vocabulary sweep + regression gates

---

## Acceptance criteria

### Form stability (16.1A)

1. Changing Type does not clear unsaved ordinary field values when switching away and back before save.
2. Changing Digital / Format / Variation type does not clear unrelated unsaved values.
3. Controlled picker selections survive temporary Type changes while editing.
4. Page does not jump to top on driver changes.
5. Focus remains predictable on driver changes.
6. Invalid-for-Type values are not saved.
7. Existing hidden DB values are not cleared merely because fields are absent from submit.
8. Item-kind-change cleanup runs only on successful save when kind actually changed.
9. Product form no longer depends on `catalog-item-form` for visibility.
10. No full-form GET Turbo Frame reload is used for visibility updates.
11. Failed validation re-renders with submitted visible values, submitted Type context, and errors.
12. Driver changes use embedded/fetched EntryContext JSON, not HTML section replacement.

### Unified workflow (16.1B)

13. Staff start from **Add Product**, not Catalog-linked vs Non-catalog.
14. Staff edit via **Edit Product**, not Bibliographic Details as a separate primary target.
15. Product Summary does not link ordinary staff to CatalogItem edit as the primary path.
16. Operational `product_type` is derived and not shown on normal forms.
17. Staff enter one Title field.
18. List price uses currency UI.
19. Ordinary create primary CTA continues to Create Variant; Save Product Only is available.
20. Service and Non-Inventory auto-create a default variant on primary save unless Save Product Only.
21. Tests no longer require the old catalog-linked vs non-catalog staff choice as the happy path.
22. Import, buyback, and POS lookup regressions remain green.

---

## Open items (defaults locked unless reopened)

| Item | Default for this milestone |
| ---- | -------------------------- |
| Default Type on blank Add Product | Book |
| Save Product only | Allowed as secondary CTA |
| Periodical controlled genres | Deferred |
| Sideline Digital | Keep current resolver behavior |
| Non-Inventory physical dimensions | Hidden |
| Lookup Code vs Identifier UI copy | Keep both terms if already present; do not redesign taxonomy in 16.1 |
| Staged hidden-value warning | Deferred |
| Invalid staged values after failed submit | Not guaranteed to survive round-trip |

---

## Summary

v0.04-16.1 has two jobs:

1. Make the dynamic Product form stable by keeping fields mounted and applying visibility client-side, with server resolvers/sanitizers remaining authoritative.
2. Finish the staff-facing transition to unified Product create/edit vocabulary and workflow.

```text
Stable mounted form
+ client show/hide/disable
+ embedded EntryContext + driver-only context fetch
+ authoritative save sanitizer
→ then unified Add Product / Edit Product
```

Do not build the unified workflow on Turbo Frame section replacement.
