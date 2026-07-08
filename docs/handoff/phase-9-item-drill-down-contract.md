# Phase 9 — Item Drill-Down Contract

Phase 8.5-4 establishes what Phase 9 reporting may rely on when linking into `/items`.

Spec: [phase-8.5-4-item-data-quality-spec.md](../specifications/phase-8.5-4-item-data-quality-spec.md)

v0.04-15 (Products Overview refactor) revises Overview-tab surfaces; Operations tab retains history anchors.

Phase 9b operational reports that consume this contract:

* **Customer Request Queue** — item links via `product_variant_id` to overview tab
* **Inventory Value Snapshot** — variant links where applicable
* Future report drill-downs should follow the same link conventions

---

## Link conventions

Canonical (use for all new report and workspace links):

```text
/items/item?product_id=:id&tab=overview
/items/item?product_variant_id=:id&tab=overview
```

Legacy redirect only (do not emit from new code):

```text
/items/item?catalog_item_id=:id&tab=overview
  → 302 to product_id when an active linked product exists
```

Anchors:

```text
#warnings              — hidden anchor on Overview (report drill-down stability)
#variant-availability  — Overview variant table (replaces #variant-matrix on Overview)
#overview-summary-strip
#sales-history         — Operations tab
#receiving-history     — Operations tab
```

## Contract surfaces (overview tab)

| Surface | DOM / aria |
| ------- | ---------- |
| Stable identity | `.ss-item-hero` |
| Warning anchor | `#warnings` (hidden; no visible panel on Overview) |
| Operational summary | `#overview-summary-strip` |
| Variant availability | `#variant-availability` |
| Main column shell | `section.ss-item-main[aria-label='Item overview']` |

Removed from Overview (v0.04-15): `.ss-item-summary-cards`, visible `#warnings` panel, `#variant-matrix`, `#sales-history`, `#receiving-history`.

## Index contract

Index rows may expose batched worst warning severity and operational quantities via the Signals column. Full warning text is only on item detail (Operations tab).

## Out of scope

Phase 9 must not assume analytics export, variant image overrides, or write actions from report links.
