# Phase 9 — Item Drill-Down Contract

Phase 8.5-4 establishes what Phase 9 reporting may rely on when linking into `/items`.

Spec: [phase-8.5-4-item-data-quality-spec.md](../specifications/phase-8.5-4-item-data-quality-spec.md)

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
#warnings
#variant-matrix
#sales-history
#receiving-history
```

## Contract surfaces (overview tab)

| Surface | DOM / aria |
| ------- | ---------- |
| Stable identity | `.ss-item-hero` |
| Warning summary | `#warnings` |
| Sell / order / stock cards | `.ss-item-summary-cards` |
| Variant readiness | `#variant-matrix` |
| Recent sales | `#sales-history` |
| Recent receiving | `#receiving-history` |

## Index contract

Index rows may expose batched worst warning severity and operational quantities via the Signals column. Full warning text is only on item detail.

## Out of scope

Phase 9 must not assume analytics export, variant image overrides, or write actions from report links.
