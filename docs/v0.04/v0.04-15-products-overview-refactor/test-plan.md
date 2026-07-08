# v0.04-15 Products Overview Refactor — Test Plan

## Status

**Draft**

Spec: [spec.md](spec.md)

---

## Test categories

| Category | Focus |
| -------- | ----- |
| Integration — overview contract | DOM regions, de-scoped elements, tab default |
| Integration — quantities | Avail. on hand / on order labels and values |
| Integration — actions | Request menu + Details drawer on Overview |
| Integration — metadata rail | Audiences, access, collapse behavior |
| Presenter / resolver | Subdepartment resolution chain, strip rollups |
| Regression | Phase 9 report links, items UX contract, operations tab unchanged |

---

## Integration tests

### Overview contract (`test/integration/items_item_overview_contract_test.rb` — revise)

| Test | Assertion |
| ---- | --------- |
| Default overview | `.ss-item-hero`, `#overview-summary-strip` (or agreed class), `#variant-availability` |
| Hidden warnings | `#warnings[hidden]` present; no visible `.ss-operational-warnings` on Overview |
| De-scoped | No `.ss-item-summary-cards` on Overview; no `#sales-history` / `#receiving-history` on Overview |
| Eyebrow | Store category breadcrumb when set; resolved subdepartment when category blank |
| Eyebrow excludes location | No display location names in eyebrow when location set but category present |
| Variant columns | Headers include Subdepartment, Avail. On Hand, Avail. On Order; not Store Category |
| Description | `.ss-item-description` in main column, not sidebar |
| Right rail | Audiences and Access sections when metadata present |

### Overview actions (`test/integration/items_overview_actions_test.rb` — new)

| Test | Assertion |
| ---- | --------- |
| Details on Overview | `button` Details opens `#item-variant-ops-drawer` from Overview tab |
| Request on Overview | Request affordance visible per variant when `demand.access` granted |
| Demand drawer | Selecting hold/notify loads demand form in drawer |

### UX contract (`test/integration/items_item_ux_contract_test.rb` — revise)

| Test | Update |
| ---- | ------ |
| Overview hero | Keep back link, no duplicate page header |
| Overview history links | Remove or relocate assertions for sales/receiving on Overview |

---

## Presenter / service tests

### `Items::SubdepartmentDisplayResolver` (or equivalent)

| Case | Expected |
| ---- | -------- |
| Variant subdepartment set | Variant name |
| Variant blank, product default set | Product default name |
| Variant and product blank, store category default set | Category node default subdepartment name |
| All blank | nil / omit eyebrow |

### `Items::ItemOverviewPresenter`

| Case | Expected |
| ---- | -------- |
| Strip rollup | Sums match snapshot rows across variants |
| `on_order_available` in table | Not equal to raw `on_order` when inbound allocations exist |

---

## Manual verification

| Scenario | Steps |
| -------- | ----- |
| Report drill-down | Customer Request Queue → item link lands on Overview; `#warnings` does not break scroll |
| Long description | Read more → read less collapses |
| Rail overflow | Subject list > 5 → More → Less |
| Permission gating | User without inventory access — strip/table inventory fields masked |
| Variant SKU link | `product_variant_id` param still resolves product Overview |

---

## Merge gate

```bash
./dev/rails-docker bin/rails test test/integration/items_item_overview_contract_test.rb
./dev/rails-docker bin/rails test test/integration/items_item_ux_contract_test.rb
./dev/rails-docker bin/rails test test/integration/items_overview_actions_test.rb
./dev/rails-docker bin/rails test test/presenters/items/
```

Full suite green before merge.

---

## Contract doc updates (same PR)

* [docs/handoff/phase-9-item-drill-down-contract.md](../../handoff/phase-9-item-drill-down-contract.md)
* Optional: [docs/specifications/phase-8.5-4-item-data-quality-spec.md](../../specifications/phase-8.5-4-item-data-quality-spec.md) §2 cross-reference note
