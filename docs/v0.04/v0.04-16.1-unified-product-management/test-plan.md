# v0.04-16.1 Unified Product Management & Form Stability — Test Plan

## Status

**Draft**

Spec: [spec.md](spec.md) · Data model: [data-model.md](data-model.md)

---

## Merge gate

```bash
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v004161:verify_unified_product_management
```

Verifier name may be adjusted at implementation time; keep a single STRICT gate for the milestone.

Minimum verifier checks:

### 16.1A — Form stability

* Product metadata form does **not** use full-form GET Turbo Frame section replacement for visibility updates
* Product form shell embeds EntryContext bootstrap JSON
* `GET /items/product_entry_context` accepts driver fields only and returns JSON (not form HTML as primary mechanism)
* `Products::MetadataParamsSanitizer` still drops hidden keys on `:new`
* Edit submit with kind unchanged does not clear existing hidden DB metadata merely because keys are absent
* Item-kind-change cleanup is explicit (only when kind actually changed on save)
* Product metadata form is not coupled to `catalog-item-form` for visibility
* Controlled picker canonical hidden inputs are outside any replaced dynamic region (or no replaced region remains)
* Shared field keys are used across visibility/sanitizer mappings (anti-drift smoke check)

### 16.1B — Unified workflow

* Add Product happy path does not require Catalog-linked vs Non-catalog choice
* Edit Product is the primary edit surface; `edit_metadata` redirects (or equivalent)
* Product Summary does not primary-link to CatalogItem edit for ordinary staff
* Normal Product form does not expose operational `product_type` or manual SKU fields
* Title-only staff field syncs/regenerates `products.name`
* Service / Non-Inventory auto-creates a default variant unless save-product-only
* Ordinary create primary CTA continues to Create Variant

Also retain relevant v0.04-16 gates where still applicable:

```bash
STRICT=1 ./dev/rails-docker env STRICT=1 bin/rails shelfstack:v00416:verify_product_entry_revamp
```

---

## Test categories

| Category | Focus |
| -------- | ----- |
| System / integration — value preservation | Type/Digital/Format/Variation changes keep staged values |
| System / integration — pickers | BISAC/genre survive temporary Type changes |
| Request — hidden submit policy | Create/edit/kind-change sanitizer behavior |
| Request — validation failure | Submitted visible values + Type context preserved |
| Request — preview safety | No raw assign_attributes from unsanitized params |
| Request — context endpoint | Driver-only JSON contract |
| Integration — Add Product | Unified create path + CTAs |
| Integration — Edit Product | Unified edit path; redirects from legacy bibliographic routes |
| Integration — Service/Non-Inventory | Short form + default variant policy |
| Regression | Identifiers, inventory tracking, import, buyback, POS lookup |

---

## Form stability tests (16.1A)

### Value preservation

| Test | Assertion |
| ---- | --------- |
| Book → Music → Book before save | Staged book fields (e.g. page count, large print, publisher) still present when Book is selected again |
| Music → Book → Music before save | Staged music/genre-related inputs still present when Music is selected again |
| Matrix → Standard → Matrix | Staged variant labels preserved |
| Digital on/off | Unrelated metadata (title, list price, category, notes) not cleared |
| Format change | Title, price, category, subdepartment, notes not cleared; selected format restored after option rebuild |

### Scroll / focus

| Test | Assertion |
| ---- | --------- |
| Change Type | Page does not jump to top |
| Change Format | Focus remains on format control or moves predictably |
| Change Variation type | No unexpected scroll jump |

### Controlled pickers

| Test | Assertion |
| ---- | --------- |
| BISAC selected, switch to Music, switch back to Book | Staged BISAC canonical values still present |
| Genre selected, switch to Book, switch back to Music | Staged genre canonical values still present |
| Submit as Music with staged BISAC | BISAC not saved / ignored |
| Submit as Book with staged music genres | Music genres not saved / ignored |
| Persist Book, change kind to Music on save | Explicit cleanup clears incompatible BISAC categorizations |
| Temporary Type toggle without save | Does not clear already-saved categorizations until save+kind-change policy runs |

### Client / markup contracts

| Test | Assertion |
| ---- | --------- |
| Field wrappers | Key fields expose `data-product-field-key` |
| Hidden field | Hidden group inputs are disabled and not `required` |
| Shown again | Inputs re-enabled; prior value present |
| Cover image | File input not inside a dynamically replaced region |
| No catalog-item-form visibility coupling | Product form root does not attach `catalog-item-form` for show/hide (narrow preview controllers allowed) |
| No full-form GET reload | Successor controller does not append full `FormData` into GET frame src for visibility |
| Short form | Service/Non-Inventory hide sections on same shell; do not mount a separate form architecture |

### Context endpoint

| Test | Assertion |
| ---- | --------- |
| Driver-only request | Returns JSON with visibility, labels, formats, scheme, operational type, short_form |
| Does not require full form body | Title/description/etc. not needed |
| Does not return primary form HTML replacement | JSON context only |
| Optional product_id | Accepted on edit |

---

## Sanitizer / validation tests

### `Products::MetadataParamsSanitizer`

| Test | Assertion |
| ---- | --------- |
| `:new` service | Hidden keys (format, publisher, etc.) dropped |
| `:edit` kind unchanged | Absent hidden keys do not wipe existing DB values when controller assigns only sanitized attrs |
| `:edit` kind changed | Visible keys accepted; cleanup flag/path invoked |
| Invalid picker ids for kind | Ignored on submit |
| Intentionally blank visible field | Clears existing value |
| Missing disabled/hidden field | Treated as not submitted; existing value preserved |

### Validation failure

| Test | Assertion |
| ---- | --------- |
| Submit invalid Product | Re-renders with submitted visible values |
| Submitted Type context | Visibility matches submitted Type, not stale DB kind alone |
| Errors shown | Validation messages visible |
| No silent revert | Submitted title/description/etc. not replaced by old DB values |

### Preview safety

| Test | Assertion |
| ---- | --------- |
| If HTML preview path still exists | Uses preview-safe allowlist; does not assign raw params |
| Preferred end state | No HTML section preview replacement in Product form path |

---

## Unified workflow tests (16.1B)

### Add Product

| Test | Assertion |
| ---- | --------- |
| Start Add Product | No Catalog-linked / Non-catalog choice as required first step |
| Create book product | Uses unified Product form; sets `catalog_item_type` / derived `product_type` correctly |
| Optional lookup/identifier assist | Prefills Product form; still creates a Product |
| Primary CTA ordinary | Save and Create Variant continues to Create Variant |
| Secondary CTA | Save Product Only lands on Product Summary without requiring variant |
| Default Type | Blank form defaults to Book |

### Edit Product

| Test | Assertion |
| ---- | --------- |
| Primary edit action | Edit Product |
| Legacy bibliographic route | Redirects to unified edit |
| Formerly catalog-linked product | Edits through unified Product form from Product Summary |
| Product Summary | Does not primary-link to CatalogItem edit |
| No operational `product_type` select | Not present on normal edit form |
| No manual SKU field | Not present on normal Product form |
| Title only | Staff title field updates `title` and syncs `name` |
| List price | Currency UI posts cents |

### Service / Non-Inventory

| Test | Assertion |
| ---- | --------- |
| Staff labels | Service / Non-Inventory Item, never plain Other |
| Short presentation | Format/BISAC/genre/physical hidden on same shell |
| Primary save | One standard active variant auto-created |
| Save Product Only | Skips auto-variant |
| Missing subdepartment | Blocks auto-create; shows Product form validation |
| Seeded price/subdepartment | From product list price / default subdepartment |
| Inventory mapping | Uses existing product-type tracking/behavior mappers |
| Derived operational type | `service` / `non_inventory` |

### Vocabulary sweep

| Test | Assertion |
| ---- | --------- |
| Add entry copy | Does not require Catalog-linked / Non-catalog labels as primary choice |
| Product Summary | Shows Edit Product; not Edit Bibliographic Details as primary |
| Product form | Shows Type / Item kind; not operational Product type for Book/Music |

### Create Variant (cite v0.04-16)

| Test | Assertion |
| ---- | --------- |
| Conditional / variable / matrix requirements | Still enforced per v0.04-16 |
| Price default | From product list price where applicable |
| No normal SKU editing | Still hidden |

---

## Regression

| Area | Assertion |
| ---- | --------- |
| v0.04-2 identifiers | Primary identifier create/auto-generate still works |
| Variant SKU | System-assigned; normal variant form still hides SKU editing |
| Inventory tracking | Operational type derivation still feeds tracking defaults |
| Orderability / buyback | No regressions from hiding staff `product_type` |
| Ingram / external import | Still creates valid products/variants |
| Buyback resolve | Still resolves product/variant behavior |
| POS lookup | Still finds system-assigned SKUs and lookup codes |
| Retain-temporary catalog admin | Legacy catalog admin/import paths still reachable where intentionally retained |
| External lookup prefill | Still can assist Add Product without restoring catalog-linked as a product subtype |

---

## Suggested automated file targets

| Area | Likely location |
| ---- | --------------- |
| Sanitizer / entry context | `test/services/products/` |
| Context endpoint | `test/integration/` or request tests under items |
| Add/Edit Product integration | `test/integration/items_*` |
| Form stability system | `test/system/` (scroll/focus + Type toggle preservation) |
| Verifier | `lib/shelfstack/v004161_verify.rb` (name TBD) |

---

## Slice exit criteria

| Slice | Exit when |
| ----- | --------- |
| 1 Stop section replacement | Visibility toggles without Turbo Frame HTML replacement; preservation tests green |
| 2 Context endpoint | Embedded context + driver-only JSON fetch; no full-form GET |
| 3 Picker + sanitizer | Picker staging + hidden submit + validation-failure tests green |
| 4 Unified Add Product | Catalog-linked/non-catalog choice removed from happy path; CTAs tested |
| 5 Unified Edit + Summary | Edit Product primary; redirects; operational fields hidden; Service auto-variant + regressions green |

---

## Summary

Test v0.04-16.1 as two gates:

1. **Stability:** staged values, pickers, scroll/focus, sanitizer/validation-failure policy, context endpoint, no fragile Turbo Frame reload.
2. **Unification:** one Add Product / Edit Product staff model with derived operational type, title-only editing, explicit CTAs, and regression coverage.

Do not mark the milestone complete until both tracks’ acceptance criteria in [spec.md](spec.md) are covered by automated tests and the STRICT verifier.
