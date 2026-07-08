# v0.04-15 Products Workspace — Overview Tab Refactor — Functional Specification

## Status

**Complete** — UX refactor of the `/items` item detail **Overview** tab. Presentation and wiring only; no domain rule changes.

Companion documents:

* [data-model.md](data-model.md) — no core schema changes; presenter/resolver additions
* [test-plan.md](test-plan.md) — contract, integration, and regression gates
* [Phase 9 item drill-down contract](../../handoff/phase-9-item-drill-down-contract.md) — **requires revision** when this ships
* Phase 8.5-4 baseline: [phase-8.5-4-item-data-quality-spec.md](../../specifications/phase-8.5-4-item-data-quality-spec.md)

Reference mockup: products workspace overview wireframe (2026-07). Mockup deltas documented in [§ Mockup deltas](#mockup-deltas).

---

## Job

Lighten the **Overview** tab so frontline staff can quickly answer:

```text
What is this product?
What formats/variants exist?
Do we have any available?
Is any quantity inbound and available?
Where does it belong in the store? (classification orientation)
What customer request actions are available?
```

Heavier operational detail (readiness diagnostics, vendor sourcing matrix, sales/receiving history, visible warnings) moves to **Operations**, **Item setup**, and **Activity** — designed in follow-on work.

User-facing workspace language may say **Products**; routes remain under `/items` for this milestone.

---

## Resolved decisions

| Decision | Choice |
| -------- | ------ |
| Milestone type | Item cockpit UX refactor — not domain redesign |
| Schema | No new core tables |
| Default tab | `overview` (unchanged) |
| Tab labels | Overview · Operations · **Item setup** · Activity |
| Eyebrow | **Store category path** when present; else **resolved subdepartment** — display location **not** included |
| Summary strip | Single compact line below tabs — replaces summary cards |
| Variant table | Seven columns + actions — replaces wide readiness matrix on Overview |
| Quantity labels | **Avail. On Hand** / **Avail. On Order** — not raw on-hand / raw PO |
| Classification column | **Subdepartment** (resolved default) — not store category |
| Header badges | Digital, Large Print, Item Type, Status only — no readiness flags on Overview |
| Warnings on Overview | **Hidden** `#warnings` anchor only (report drill-down stability) |
| Request / Details | **On Overview** — reuse variant ops drawer + demand actions |
| Description | **Left/main column** — not right rail |
| Right rail | Subjects, Genres, Themes, Audiences, Access Restrictions |
| Expandable sections | Description and rail lists: expand **and** collapse (More / Less or `<details>`) |
| Notes / Additional Information | **Future** — does not block v1 |

---

## v0.04-14 alignment

v0.04-15 composes the v0.04-14 design-system layer ([v0.04-14 completion](../../implementation/v0.04-14-completion.md)) — it is a products UX refactor, not a second design-system migration.

**Inherits:** `shared/ui/button`, `shared/ui/empty_state`, `shared/interaction/_drawer` (variant ops drawer unchanged), domain CSS in `shelfstack.domain.items.css` (no new rules in monolithic `shelfstack.css`), documented table/badge/dropdown/disclosure classes, UX contract integration tests, Overview hero without duplicate `page_header`, no schema changes, no new `shared/ui` partials.

**Supersedes (Phase 8.5-4 / Phase 9 overview content — revise drill-down contract):** summary cards → inline strip; `#variant-matrix` → `#variant-availability`; visible warnings panel → hidden `#warnings` anchor; sales/receiving history off Overview (stay on Operations).

**Watch during implementation:** Details button matches Operations (`ss-btn-secondary ss-btn--small`); do not use reports `_metric_strip`; `button_to` in Request menu uses `.ss-inline-form`; hero renders before tabs on Overview only.

---

## Routes and navigation

Existing canonical paths (unchanged):

```text
/items
/items/item?product_id=:id
/items/item?product_variant_id=:id
/items/item?product_id=:id&tab=overview   (default when tab omitted)
```

Report and workspace drill-down should continue to use `product_id` or `product_variant_id` with `tab=overview` unless a future contract revision standardizes Operations anchors for history.

---

## Page structure

Four regions, top to bottom:

```text
1. Full-width product header
2. Tab navigation
3. Compact operational summary strip
4. Two-column content body
   - Left/main column (~70–75% desktop)
   - Right metadata rail (~25–30% desktop)
```

```text
┌─────────────────────────────────────────────────────────────┐
│ Product Header                                               │
│ Eyebrow, title, edition/series, creators, badges, image      │
└─────────────────────────────────────────────────────────────┘

[Overview] [Operations] [Item setup] [Activity]

Available: 114   Reserved: 2   On Order: 99   TBO: 3   Last Received: Jun 28   Last Sold: Jul 7

<div id="warnings" hidden aria-hidden="true"></div>

┌──────────────────────────────────────────────┬──────────────┐
│ Main Column                                   │ Right Rail   │
│ Product facts table                           │ Subjects     │
│ Variant availability table                    │ Genres       │
│ Description                                   │ Themes       │
│                                               │ Audiences    │
│                                               │ Access       │
└──────────────────────────────────────────────┴──────────────┘
```

### Visual hierarchy

Priority order (highest first):

```text
1. Product title / identity
2. Variant availability table
3. Request / Details actions
4. Operational summary strip
5. Product facts
6. Description
7. Right-rail metadata
```

Avoid large metric cards, dense readiness badges, and management controls on Overview.

---

## 1. Full-width product header

Spans full page width. Identifies the product before operational detail.

### Content

| Element | Source / behavior |
| ------- | ----------------- |
| Back link | Existing `ss-detail-back` → Items index |
| Eyebrow | See [Eyebrow](#eyebrow) |
| Title | `ItemPresenter#title` |
| Edition / series line | `subtitle` and/or `series_label` — hide empty parts |
| Creator line | `creator_entries` with role badges — adapt for non-book types |
| Key badges | Digital, Large Print, Item Type, Status — see [Header badges](#header-badges) |
| Cover image | `item_cover_thumbnail` (hero size), right-aligned |
| Item type near image | Humanized `catalog_item_type` associated with cover slot |

Overview tab does **not** render `.ss-page-header` duplicate title (existing contract).

### Eyebrow

Compact path-like line at top of hero text:

```text
{Store Category breadcrumb}     when store category present
{Resolved subdepartment name}   otherwise
```

**Do not** include display location in the eyebrow.

Store category: `display_metadata.store_category.breadcrumb_label` (e.g. `Books → Children's Books`).

Resolved subdepartment: see [Subdepartment resolution](#subdepartment-resolution).

If neither is present, omit the eyebrow (no placeholder dash).

### Header badges

Prominent descriptive badges only:

| Badge | When |
| ----- | ---- |
| Digital | `display_metadata.digital` |
| Large Print | `display_metadata.large_print` |
| Item Type | Humanized `catalog_item_type` |
| Status | Lifecycle / active status (e.g. `item_lifecycle_status_badge`) |

Do **not** show operational readiness badges (`vendor-orderable`, `used-like`, warning severity, etc.) on Overview header or variant rows.

---

## 2. Tab navigation

Directly below header:

| Tab | Purpose |
| --- | ------- |
| **Overview** | Product identity, facts, variant availability, request entry points, descriptive metadata |
| **Operations** | Demand, allocations, holds, TBO, sourcing, PO/receipt signals, readiness (future design) |
| **Item setup** | Catalog metadata, selling setup, identifiers, pricing, classification, vendors |
| **Activity** | Audit history, inventory ledger, transactional trail |

Controller tab key remains `item_setup`; user-facing label **Item setup**.

---

## 3. Compact operational summary strip

Single quiet line below tabs — **not** dashboard cards.

### Fields

| Field | Meaning | Rollup source |
| ----- | ------- | ------------- |
| **Available** | Total sellable available qty across inventory-eligible active variants | Sum `VariantOperationalSnapshot` `available` |
| **Reserved** | Qty reserved by active on-hand demand | Sum `reserved` |
| **On Order** | Open submitted/partial PO qty still open | Sum `on_order` |
| **TBO** | Open manual TBO demand not yet covered | Sum `open_tbo` |
| **Last Received** | Most recent receipt date for any variant | Max `last_received` |
| **Last Sold** | Most recent POS sale date for any variant | `SalesHistoryLookup.last_sold_at_for_variants` |

### Display

```text
Available: 0
Reserved: 0
On Order: —
TBO: —
Last Received: —
Last Sold: —
```

Use short dates (`Jun 28`, `Jul 7`). No timestamps on Overview.

Permission-aware: when inventory not visible, omit or mask inventory-backed fields per existing `inventory_visible?` patterns.

### Removed from Overview

* `.ss-item-summary-cards` (Can sell? / Can order? / Stock / Recent activity cards)
* `.ss-item-open-activity` deep links may move to Operations tab in follow-on

---

## 4. Hidden warnings anchor

Preserve report drill-down stability:

```html
<div id="warnings" hidden aria-hidden="true"></div>
```

* No visible operational warnings panel on Overview.
* Authoritative warning UI moves to **Operations** (future slice).
* Phase 9 contract updated to document anchor-only semantics on Overview.

---

## 5. Main column — product facts table

Compact two-column facts table above variant table.

### Fields (hide when empty or irrelevant to product type)

| Field | Notes |
| ----- | ----- |
| List Price | `product.list_price_cents` formatted |
| Primary identifier | Type label + normalized value |
| Format | Format name; append Large Print badge when applicable |
| Publisher / Manufacturer | Metadata publisher |
| Publication Date | `Mmmm d, yyyy` or year; optional publication status badge |
| Description summary | Composed line: pages, running time, frequency, calendar year — hide empty segments |
| Physical Details | Dimensions and weight from metadata |

Not an editing surface — management remains on Item setup.

---

## 6. Main column — variant availability table

Primary operational element on Overview.

### Columns

| Column | Source |
| ------ | ------ |
| **Variant** | `variant.list_label` (condition, format, attributes) |
| **SKU** | `variant.sku` |
| **Price** | `selling_price_cents` |
| **Avail. On Hand** | `snapshot.available` — **not** raw `on_hand` |
| **Avail. On Order** | `snapshot.on_order_available` — open PO minus inbound demand allocations |
| **Subdepartment** | [Resolved subdepartment name](#subdepartment-resolution) |
| **Actions** | Request · Details |

Preferred header labels (space-constrained fallback: `Available` / `Inbound Avail.` — document in CSS only if needed).

### Subdepartment resolution

Display chain for eyebrow fallback and table column:

```text
variant.sub_department
  → product.default_sub_department
  → store_category.default_sub_department (from catalog/product store category)
```

Implement via dedicated resolver (extend or replace `ProductVariant#resolved_sub_department` for display). Show resolved **name**; inherited values may use muted styling in a later polish slice.

### Removed from Overview variant table

Subdepartment-only when duplicated, tax category, inventory tracking, orderable flag, preferred vendor, vendor source, returnability, expected cost, per-row last sold, warning severity, operational badges.

Empty state: retain existing empty state when no active variants.

Suggested DOM id: `#variant-availability` (replaces `#variant-matrix` on Overview).

---

## 7. Variant row actions

Both actions stay on the product page.

### Request

Opens contextual menu or drawer — **not** a single fixed action.

Candidate actions (from `ItemOperationsPresenter#variant_customer_demand_actions`):

| Action | Typical context |
| ------ | ---------------- |
| Hold for customer | Available or reservable |
| Notify customer | Interest when unavailable |
| Special order | Orderable, not used-like |
| Used wanted | Used-like variant |
| Manual TBO | Vendor-orderable, `demand.create` |
| Buyer replenishment | Vendor-orderable, buyer permissions |

Gate by `ProductVariants::OperationalPolicy`, availability snapshot, and permissions. Reuse `item-variant-ops-drawer` demand section and `prepareDemandAction` flow.

### Details

Opens existing **variant operations drawer** (`item-variant-ops-drawer`) with server-rendered body — same behavior as Operations tab today.

Overview must mount drawer shell + Stimulus controller (currently on Operations partial only).

---

## 8. Main column — description

Below variant table (and below future Notes section when added).

* Concise preview for long text.
* Expand with **Read more**; expanded state must **collapse** (Read less or `<details>` toggle).
* Reuse `item_description_block` helper; ensure collapse UX is explicit.

---

## 9. Right metadata rail

Secondary discovery metadata only — not description.

### Sections (hide when empty)

| Section | Source |
| ------- | ------ |
| Subjects | BISAC / `subject_groups` Subjects |
| Genres | `genre_data` / genres |
| Themes | `theme_data` / themes |
| Audiences | `target_audience_data` / `target_audiences` — **add to presenter** |
| Access Restrictions | `access_restriction_data` / `access_restrictions` — **add to presenter** |

### Overflow behavior

* Show first N items (suggest 5).
* **More** expands; **Less** collapses.
* Shared pattern for all rail sections (Stimulus or `<details>` per section).

---

## 10. Responsive behavior

### Desktop

Two-column layout as above.

### Tablet / narrow

Stack right rail below main content:

```text
Header → Tabs → Summary strip → Facts → Variant table → Description → Right rail
```

### Mobile

* Summary strip: horizontal scroll or two-line wrap.
* Variant table: horizontal scroll or stacked rows.
* Request and Details remain visible per variant.

---

## 11. De-scoped from Overview (moves elsewhere)

| Surface | Destination |
| ------- | ------------- |
| Summary cards | Removed — replaced by strip |
| Wide readiness matrix columns | Operations tab (future) |
| Operational warnings panel | Operations tab; hidden `#warnings` anchor only on Overview |
| Recent sales table | Operations or Activity |
| Recent receiving table | Operations or Activity |
| Notes / Additional Information | Future enhancement |

---

## Contract revision (Phase 9 drill-down)

Update [phase-9-item-drill-down-contract.md](../../handoff/phase-9-item-drill-down-contract.md) when shipping:

| Surface | Overview contract (new) |
| ------- | ------------------------ |
| Stable identity | `.ss-item-hero` |
| Warnings | `#warnings` hidden anchor only |
| Summary | `.ss-item-summary-strip` (or `#overview-summary-strip`) |
| Variant availability | `#variant-availability` |
| Recent sales / receiving | **Not on Overview** — link to Operations/Activity |

Reports linking to `#warnings` or `#variant-matrix` must be updated or supported with redirect anchors during transition.

---

## Implementation slices (suggested)

```text
1. Subdepartment resolver + presenter extensions (eyebrow, audiences, access, strip rollup)
2. Overview partial refactor (header badges, strip, facts, slim table, description move)
3. Drawer + Request menu on Overview
4. Right rail overflow/collapse
5. Remove de-scoped Overview blocks
6. Contract docs + integration tests
7. Operations tab absorption (follow-on — readiness/history/warnings UI)
```

---

## Out of scope

* New readiness flag system
* RTV recommendation engine
* Full notes / staff annotations system
* External catalog overwrite workflow
* Domain rule changes to inventory, demand, or purchasing
* Route rename `/items` → `/products`
* Operations tab redesign (separate spec slice)
* Items index changes

---

## Acceptance criteria

1. Overview has full-width header with eyebrow (store category or resolved subdepartment), title, edition/series, creators, descriptive badges, image, and back link.
2. Tabs: Overview, Operations, Item setup, Activity — Overview default.
3. Compact summary strip shows Available, Reserved, On Order, TBO, Last Received, Last Sold.
4. Hidden `#warnings` anchor present; no visible warnings panel on Overview.
5. Main column: product facts table, variant availability table (seven columns + actions), description.
6. Variant quantities use **Avail. On Hand** and **Avail. On Order** semantics.
7. Subdepartment column shows resolved default.
8. **Request** opens contextual demand menu/drawer; **Details** opens variant ops drawer — without leaving product page.
9. Right rail: subjects, genres, themes, audiences, access restrictions when present; expandable with collapse.
10. No summary cards or wide readiness matrix on Overview.
11. Phase 9 drill-down contract and tests updated.
12. UX uses v0.04-14 shared button/partial contracts where actions render.

---

## Mockup deltas

Wireframe useful for layout; implement per **resolved decisions** where they differ:

| Mockup | Spec |
| ------ | ---- |
| Eyebrow includes display location path | **Omit** location — store category or subdepartment only |
| Column **Store Category** | **Subdepartment** (resolved) |
| Columns **On Hand** / **On Order** | **Avail. On Hand** / **Avail. On Order** |
| Tab **Management** | **Item setup** |
| No summary strip | **Add** strip below tabs |
| Notes / Additional Information | **Defer** v1 |
| Read More only | **More** and **Less** (collapse) |
