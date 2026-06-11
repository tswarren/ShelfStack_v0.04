# Transitional Domain Mapping — Classification Rework

## Purpose

Phase 2/3 shipped a workable but overloaded model. Phase 3B separates **behavior**, **topic**, **display**, and **accounting** without breaking existing item entry, seeds, or imports.

**Core correction:**

> Legacy `Category` ≈ future **`MerchandiseClass`** (+ some format overlap), **not** future topic **`CategoryNode`**.

This document is the source of truth for transitional semantics during the Phase 3B classification rework. Issue 01 introduces it; later issues implement against it.

Related: [00-epic-phase-3-rework-merchandise-classification-structure.md](00-epic-phase-3-rework-merchandise-classification-structure.md)

---

## Entity mapping table

| Current entity / field | What it means today | Target concept(s) | Transitional rule | Migration step |
| --- | --- | --- | --- | --- |
| **`Department`** | Top-level reporting bucket; has `gl_account_code` | **`Department`** (reporting) + **`AccountingMapping`** (rules) | Keep departments through transition. Do not add new behavior defaults here. | Issue 07: map dept/GL via accounting rules; deprecate dept as sole GL source over time |
| **`Department#gl_account_code`** | Implicit GL/reporting bucket | **`AccountingMapping`** output | Legacy fallback when no mapping rule matches | Issue 07 |
| **`Category`** | Format/merchandise bucket + pricing/tax defaults (Hardcover, Used PB, Gifts) | **`MerchandiseClass`** (behavior) + optional bridge label | Treat as **Merchandise Category** in UI during transition | Issue 03: `categories.merchandise_class_id` |
| **`Category#default_pricing_model`** | Variant pricing default source | **`MerchandiseClass`** | Resolve via `variant → category → merchandise_class`; category field becomes legacy | Issue 04: move source of truth to merchandise class |
| **`Category#default_margin_target_bps`** | Margin default | **`MerchandiseClass`** | Same as above | Issue 04 |
| **`Category#default_supplier_discount_bps`** | Supplier discount default | **`MerchandiseClass`** | Same as above | Issue 04 |
| **`Category#default_tax_category_id`** | Tax classification default | **`MerchandiseClass#default_tax_category_id`** | Same as above; tax lookup still uses tax category + store rates | Issue 04 |
| **`Category` name examples** (Hardcover, Used Paperback, Gifts) | Mixed format + merchandise type | **`MerchandiseClass`** + **`Format`** | Do **not** assume these become topic nodes | Issue 08 templates; optional rename in UI only |
| **`ProductVariant#category_id`** | Required sellable classification + default source | **Primary topic `CategoryNode`** *or* legacy bridge | **Keep required through transition.** Still drives forms, lifecycle, Ingram import | Issue 06: show classification summary; Issue 09: imports |
| **`ProductVariant#condition_id`** | SKU suffix, price factor, name | **`ProductCondition`** (unchanged) | Used by **`AccountingMapping`** with merchandise class | Issue 07 |
| **`ProductVariant#pricing_model_override`** | Explicit override | **Variant override** (unchanged) | Beats merchandise class defaults | Document in resolution order |
| **`ProductVariant#display_location_id`** | Merchandising placement | **`DisplayLocation`** (unchanged) | Stays separate from classification | No schema change |
| **`Product#default_display_location_id`** | Product-level display default | **`DisplayLocation`** (unchanged) | Stays separate | No schema change |
| **`Format`** (catalog item) | Bibliographic/material type | **`Format`** + mapping inputs | Use in accounting rules later; not a replacement for merchandise class | Issue 07 extension |
| **`Product#product_type`** | Physical/digital/etc. | Mapping input | Use in accounting rules (tickets, shipping, digital) | Issue 07 |
| **Catalog BISAC/subjects JSONB** | Descriptive metadata | **`Categorization`** to BISAC nodes | BISAC codes load into `CategoryScheme(bisac)` via Setup → BISAC Subjects import; catalog items link via structured pickers and `CatalogItemBisacSync`; `bisac_subjects` / `bisac_subject_data` are derived for export/import | Implemented |
| **Phase 2 seed categories** | Format/merchandise buckets | **`MerchandiseClass`** records | Backfill category → merchandise class; **create new topic tree separately** | Issues 03, 08 |
| **Phase 2 seed departments** (Books, Used Books, …) | Reporting + implied behavior | **`Department`** + **`MerchandiseClass`** | “Used Books” department overlaps merchandise class + condition; reduce reliance over time | Issue 07 |
| **Ingram import default category** | Single category for new variants | **Default merchandise class + topic node** (future) | Keep category picker until issue 09 | Issue 09 |
| **Item lifecycle `missing_category`** | Variant has no category | **Missing classification** (broader) | Keep check on `category_id` until replaced | Issue 06 |
| **UI: “Category/Tax Summary”** | Category drives defaults | **“Classification & Defaults”** | Show merchandise class + derived defaults | Issue 06 |
| **Setup nav: Departments, Categories** | Admin maintains overloaded model | **+ Merchandise Classes, Schemes, Mappings** | Old screens remain; new screens added | Issues 02, 05, 07, 08 |

---

## What legacy `Category` is not

During transition, do **not** treat existing categories as:

* Topic/subject nodes (Biography, Fiction, Military History)
* ABA financial reporting categories
* Website browse taxonomy

Those belong in **`CategoryScheme` / `CategoryNode`** (issue 05), seeded fresh in templates (issue 08).

---

## Suggested seed remapping (current → merchandise class)

| Current category (Phase 2 seed) | Suggested `MerchandiseClass` |
| --- | --- |
| Hardcover, Trade Paperback, Mass Market Paperback, Children's Books | General Trade Books |
| Magazines, Newspapers | Periodicals |
| Gifts, Stationery, Games & Puzzles | Sidelines |
| Used Hardcover, Used Paperback | Used Books |
| Gift Cards | Gift Cards / Pass-through |
| Prepared Beverages, Packaged Snacks | Cafe |

**Note:** Format (hardcover vs paperback) stays on **`Format`** / catalog metadata, not on topic scheme.

---

## Suggested starter topic scheme (new, not migrated from Category)

**CategoryScheme:** `Store Sections / Topics`

Examples:

* Fiction
* Biography
* History → Military History, U.S. History
* Religion → Bibles, Christianity
* Stationery
* Games
* Cafe / Bakery

Assign via **`Categorization`** (issue 05). Item forms may show one primary topic during entry (issue 06).

---

## Default resolution order

Use this order for pricing, tax, returnability, buyback, and sales-account derivation:

```text
1. Explicit variant override
   (pricing_model_override, future sales_account_override)

2. AccountingMapping rule match
   (merchandise class + condition + product type + optional topic node)

3. MerchandiseClass defaults
   (pricing model, margin, supplier discount, tax category,
    returnable, buyback, default_sales_account_code)

4. Legacy Category defaults (transitional only)
   (only if merchandise class missing or not yet backfilled)

5. Legacy Department / gl_account_code (transitional only)
   (reporting fallback only; warn if used)
```

**Tax rate lookup** (unchanged structurally):

```text
resolved tax category
  → store + tax category + date
  → store_tax_category_rate
  → store_tax_rate
```

Only the **source of the tax category** moves from Category → MerchandiseClass.

---

## User-facing terminology (transition)

| Internal model | Store-facing label (transition) |
| --- | --- |
| `Department` | Reporting Department |
| `Category` | Merchandise Category *(temporary)* |
| `MerchandiseClass` | Merchandise Class |
| `CategoryScheme` / `CategoryNode` | Section / Topic |
| `DisplayLocation` | Display Location |
| `AccountingMapping` | Sales Account Mapping |

Item entry should show **four picks**, not four taxonomies:

```text
Merchandise Class | Section/Topic | Condition | Display Location
```

---

## `ProductVariant.category_id` — transitional decision

**Recommended for Phase 3B:**

| Phase | Behavior |
| --- | --- |
| **Now → Issue 06** | Keep `category_id` required; UI still shows category picker |
| **Issue 03–04** | Category inherits behavior from merchandise class; category defaults become read-only/derived |
| **Issue 05–06** | Add topic `Categorization`; item form shows topic separately |
| **Later (explicit milestone)** | Decide whether `category_id` becomes legacy alias, primary topic node FK, or is retired |

Do **not** remove `category_id` in the first slice.

---

## Docs to update when issue 01 is accepted

| Document | Change |
| --- | --- |
| `docs/domain-model.md` | Add transitional mapping section referencing this note |
| `docs/glossary.md` | Mark Category as transitional; add new terms |
| `docs/specifications/phase-2-classification-and-tax-spec.md` | “Superseded in part by Phase 3B” note |
| `docs/specifications/phase-3-data-model.md` | Clarify transitional role of `category_id` |
| `docs/specifications/ui-ux-concept.md` | Replace category-centric summaries with issue 06 model |
| `docs/specifications/ingram-catalog-import-spec.md` | Plan merchandise class + topic defaults |
| `AGENTS.md` | Transitional default-resolution rules |

---

## Developer guidance

> **Do not add more responsibilities to `Category`.** Backfill it to `MerchandiseClass`, introduce topic schemes separately, and route accounting through mapping rules—while keeping variant `category_id` and existing forms working until item UI and imports are updated.
