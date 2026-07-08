# v0.04-15 Products Overview Refactor — Data Model

## Status

**Draft** — presentation milestone; no core schema redesign.

---

## Schema policy

**No new core tables** for v0.04-15.

### Permitted additions

| Addition | Reason |
| -------- | ------ |
| None required | Reuse existing `products`, `product_variants`, `inventory_balances`, demand and PO quantity lookups |

### Do not add

* Staff notes tables
* Product overview cache tables
* New demand or inventory domain tables

---

## Read-model / presenter additions

### `Items::SubdepartmentDisplayResolver` (name TBD)

Resolves display subdepartment for eyebrow fallback and variant table:

```text
variant.sub_department
  → product.default_sub_department
  → store_category.default_sub_department
```

Returns name (and optionally source: `variant`, `product`, `store_category`, `none`) for future muted inherited styling.

**Note:** `ProductVariant#resolved_sub_department` today returns only `sub_department`; extend or delegate to this resolver for display paths. Do not change POS/tax resolution without explicit scope.

### `Items::ItemOverviewPresenter` (extend)

| Method / struct | Purpose |
| --------------- | ------- |
| `summary_strip` | Rollup: available, reserved, on_order, tbo, last_received, last_sold |
| `availability_rows` | Slim variant rows for Overview table (replaces `matrix_rows` on Overview) |
| Header badge helpers | Digital, large print, item type, status |

Continue using `VariantOperationalSnapshot` for per-variant quantities.

### `Items::ItemPresenter` (extend)

| Method | Purpose |
| ------ | ------- |
| `overview_eyebrow_label` | Store category breadcrumb or resolved subdepartment |
| `subject_groups` | Add **Audiences** and **Access Restrictions** groups from metadata JSONB / text fields |
| `product_facts_for_overview` | Facts table fields including list price |

---

## Quantity semantics (authoritative)

| UI label | Snapshot field | Definition |
| -------- | -------------- | ---------- |
| Avail. On Hand | `available` | `quantity_available` on inventory balance |
| Avail. On Order | `on_order_available` | Open PO qty minus inbound demand allocations |
| Strip On Order | `on_order` (sum) | Raw open PO line remainder — strip only |

Do not label `available` as "On Hand" or `on_order_available` as "On Order" without the **Avail.** prefix.

---

## Existing services (reuse)

```text
Items::VariantOperationalSnapshot
Items::SalesHistoryLookup
Items::ReceivingHistoryLookup          # Operations/Activity — not Overview v1
Items::ItemOperationsPresenter         # demand_actions, drawer wiring
ProductVariants::OperationalPolicy
Purchasing::OrderQuantityLookup
```

---

## DOM / anchor contract

| Id / class | Role |
| ---------- | ---- |
| `.ss-item-hero` | Product identity |
| `#warnings` | Hidden anchor for legacy report links |
| `#overview-summary-strip` | Compact strip (class name TBD in implementation) |
| `#variant-availability` | Variant table region |
| `section.ss-item-main[aria-label='Item overview']` | Main column shell |
