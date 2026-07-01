# v0.04-6 Demand Foundation — Functional Specification

## Status

**Planned** — next active milestone after v0.04-5. Spec bundle for implementation planning; mark **Complete** after merge to `main`.

## Job

Introduce **`demand_lines`** and **`stock_considerations`** as the **new runtime path** for staff-entered demand.

New demand entry writes to **`demand_lines` only**. Legacy `customer_requests`, `special_orders`, and `purchase_requests` tables and routes may remain temporarily for reference, historical data, tests, and unfinished cleanup — but they are **not the preferred write path** and must not receive new staff-facing demand creation in v0.04-6.

```text
Interest / consideration
  → demand_line (committed need)
  → [v0.04-7+] allocation → sourcing → PO → receiving → fulfillment
```

v0.04-6 is **schema + services + primary demand UI + item-drawer cutover**. It does **not** implement allocations, sourcing, PO/receiving integration, or full legacy route removal (v0.04-7 through v0.04-10).

## Purpose

v0.03 fragments demand across:

```text
customer_requests + customer_request_lines
special_orders
purchase_requests / TBO lines
inventory_reservations
PO/receipt allocations
```

Because ShelfStack is **not in production**, v0.04-6 **begins runtime cutover** to `demand_lines` rather than maintaining two equivalent demand workflows.

**Demand does not post inventory.** Creating, matching, canceling, or expiring a demand line must not call `Inventory::Post` or mutate `inventory_balances`.

---

## Source documents

```text
docs/design/VERSION_0.04.md (§6 Stock Considerations, §7 Demand)
docs/roadmap/v0.04-delivery-roadmap.md (Demand taxonomy, Lifecycle vocabulary)
docs/v0.04/v0.04-5-used-variant-rules/spec.md
docs/implementation/v0.04-5-completion.md
docs/specifications/phase-7a-customer-demand-spec.md (legacy behavior reference)
docs/specifications/phase-8.5-3a-order-handling-readiness-spec.md
AGENTS.md
```

---

## Hard gates

1. **No `demand_allocations` in v0.04-6** — allocations and reservation bridge belong to v0.04-7.
2. **No sourcing runs / vendor responses in v0.04-6** — v0.04-8.
3. **No PO or receipt quantity lifecycle changes in v0.04-6.**
4. **New demand creation writes `demand_lines` only** — do not dual-write `customer_request_lines`, `special_orders`, or `purchase_request_lines`.
5. **Legacy demand-related tables and routes may remain physically present**, but they are not the preferred write path and must not be expanded with new workflow investment unless needed for a temporary bridge.
6. **Item variant drawer uses v0.04 demand actions only** — do not show legacy customer-request actions side-by-side; no feature flag unless implementation uncovers a specific blocker.
7. **Used wanted does not enter vendor sourcing** — enforce via eligibility + `ProductVariants::OperationalPolicy`.
8. **Unavailable used demand must not auto-convert to new-item vendor demand** — staff may create a separate demand line for a vendor-orderable variant; no automatic conversion.
9. **Preserve v0.04-5 used variant rules** — delegate to `ProductVariants::OperationalPolicy`.
10. **Matched demand requires `product_variant_id`**; provisional demand may omit variant until match.
11. **Demand creation, cancellation, expiry, and matching must not post inventory.**
12. **Audit events** on create, cancel, expire, status change, variant match, stock consideration convert, and stock consideration dismiss.

---

## Legacy posture (v0.04-6)

| Aspect | v0.04-6 behavior |
| ------ | ---------------- |
| New staff demand creation | **`demand_lines` only** |
| Item variant drawer | **v0.04 demand actions only** (Hold, Notify, Special order, Used wanted, Manual TBO, Buyer demand) |
| `/demand` workspace | **Primary** staff-facing demand UI |
| Legacy customer-request / TBO routes | May remain reachable elsewhere; **not removed** if that expands scope |
| Legacy services (`CustomerRequests::StartFromItem`, etc.) | **Not invoked** from item drawer or new demand UI; may remain for tests/historical reference until v0.04-10 |
| `manual_tbo` demand lines | Visible in **`/demand` only** — do **not** feed legacy build-from-TBO PO screens until later milestones |

---

## Baseline (pre–v0.04-6)

| Legacy concept | Current entry / service | v0.04-6 target |
| -------------- | ----------------------- | -------------- |
| Customer hold / notify / special order from item | `CustomerRequests::StartFromItem` | **`DemandLines::StartFromItem`** → `demand_lines`; drawer cutover |
| Customer request header + lines | `CustomerRequests::Create`, workspace UI | New `/demand` workspace; legacy customer-request area not expanded |
| Special order record | `SpecialOrders::CreateFromRequestLine` | **Not created** — demand carries purpose |
| On-hand hold / reservation | `InventoryReservations::ReserveOnHand` | **Deferred** — v0.04-7 allocation bridge |
| Manual TBO | `PurchaseRequests::CreateSingleLine` | **`source: manual_tbo`** on `demand_lines`; not in legacy TBO-to-PO UI |
| Buyer “consider stocking” note | Informal / none | `stock_considerations` |
| Used wanted (not on hand) | Partial legacy paths | `used_wanted_request` + `used_wanted` purpose; customer required |
| Research / provisional line | `customer_request_lines` provisional fields | `demand_lines` provisional fields + `DemandLines::MatchVariant` |

---

## Eligibility matrix

Drives `DemandLines::EligibilityResolver`, `DemandLines::StartFromItem`, and tests.

| Capture intent | Source | Purpose | Variant required | Customer required | Vendor-orderable required | Used-like allowed | Creates legacy row |
| -------------- | ------ | ------- | ----------------: | ------------------: | -------------------------: | -----------------: | -----------------: |
| `hold` | `customer_order` | `customer_fulfillment` | yes | customer or snapshot | no | yes | no |
| `notify` | `customer_order` | `customer_fulfillment` | yes | customer or snapshot | no | yes | no |
| `special_order` | `customer_order` | `customer_fulfillment` | yes | yes | yes | no | no |
| `used_wanted` | `used_wanted_request` | `used_wanted` | yes | customer or snapshot | no | yes | no |
| `manual_tbo` | `manual_tbo` | `shelf_replenishment` | yes | no | yes | no | no |
| `buyer_replenishment` | `buyer_decision` | `shelf_replenishment` | yes | no | yes | no | no |
| `research` | `customer_order` | `customer_fulfillment` | no | customer or snapshot | no | yes | no |

**Used wanted:** customer-facing by default — requires customer record or contact snapshot. Store-level used interest without a customer is **out of scope** for v0.04-6 unless explicitly added later.

---

## Demand taxonomy (v0.04-6 representable paths)

Each bookseller action must map to a creatable `demand_line` (or `stock_consideration`). **Fulfillment mechanics** defer to v0.04-7+.

| Bookseller action | v0.04-6 record | Notes |
| ----------------- | -------------- | ----- |
| Reserve on-hand copy | `demand_line` (`hold`) | Status `open`; allocation deferred |
| Notify when available | `demand_line` (`notify`) | Queue semantics in v0.04-7 |
| Customer special order (new item) | `demand_line` (`special_order`) | Vendor-orderable variant |
| Wait for used copy | `demand_line` (`used_wanted`) | No vendor path |
| Manual TBO / replenishment | `demand_line` (`manual_tbo`) | `/demand` only; not legacy TBO-to-PO |
| Buyer stocking decision | `demand_line` (`buyer_replenishment`) | Store demand |
| Research / unmatched title | `demand_line` (`research`) | `status: captured` until match |
| Buyer note (not committed) | `stock_consideration` | Convert → demand or dismiss |

**Explicit deferrals:**

| Action | Defer to |
| ------ | -------- |
| Reserve inbound PO qty | v0.04-7 |
| Unresolved → vendor sourcing | v0.04-8 |
| PO line customer allocation | v0.04-7 / v0.04-9 |
| POS pickup from demand | v0.04-7 |
| Remove legacy customer-request / TBO routes | v0.04-10 |
| Nightly automatic demand expiry job | v0.04-7 |

---

## Lifecycle (v0.04-6 subset)

### `demand_lines.status`

```text
captured     — provisional / research; variant may be unmatched
open         — matched need; no allocation yet
canceled
expired
```

**Deferred (v0.04-7+):** `partially_allocated`, `allocated`, `fulfilled`.

```text
captured → open        (DemandLines::MatchVariant)
captured → canceled
open → canceled
open → expired         (DemandLines::Expire — staff/manual only in v0.04-6)
```

**Expiry:** `DemandLines::Expire` is implemented as a **manual/staff service** in v0.04-6. **Scheduled/nightly expiry job deferred to v0.04-7** when allocation and reservation semantics exist.

### `stock_considerations.status`

```text
open
reviewing
converted_to_demand
dismissed
duplicate
already_carried
```

---

## Demand numbering

Demand lines receive an immutable store-scoped **`demand_number`**:

```text
{store_number}-D{sequence:06d}
```

Examples: `001-D000001`, `002-D000001`.

* Distinct from legacy customer request numbering.
* Assigned at create time via `DemandLines::NumberAllocator` + `demand_line_sequences`.
* Identifies the v0.04 canonical demand record.

---

## Core services

| Service | Responsibility |
| ------- | -------------- |
| `DemandLines::NumberAllocator` | Store-scoped sequence → formatted `demand_number` |
| `DemandLines::Create` | Matched variant demand; audit |
| `DemandLines::CreateFromProvisional` | Research path with provisional fields |
| `DemandLines::StartFromItem` | Item drawer entry; eligibility matrix; **no legacy writes** |
| `DemandLines::MatchVariant` | `captured` → `open`; sets actor/timestamp |
| `DemandLines::Cancel` | Terminal cancel; audit |
| `DemandLines::Expire` | **Manual/staff expiry only** in v0.04-6 |
| `DemandLines::EligibilityResolver` | Eligibility matrix + `OperationalPolicy` |
| `StockConsiderations::Create` | Non-committing buyer note |
| `StockConsiderations::ConvertToDemand` | Creates linked `demand_line` |
| `StockConsiderations::Dismiss` | Terminal dismiss |

---

## UI scope

**`/demand`** is the primary staff-facing demand workspace.

| Surface | v0.04-6 behavior |
| ------- | ---------------- |
| `/demand` index | Filters: status, source, purpose, customer, variant |
| `/demand/:id` | Summary, cancel, **manual expire** |
| Manual create | Writes `demand_lines` only |
| Item variant drawer | **v0.04 demand actions only** — no legacy customer-request actions |
| Customer workspace | Customer's `demand_lines`; legacy request area may remain separately if still present |
| Stock considerations | Minimal buyer queue: create, convert, dismiss |

Reuse Phase 10-D patterns where practical.

**Rule:** Do not remove legacy routes if that expands milestone scope; **do** route all new demand creation through `demand_lines`.

---

## Permissions (proposed)

```text
demand.access
demand.create
demand.update
demand.cancel
demand.expire
demand.match_variant
stock_considerations.access
stock_considerations.create
stock_considerations.convert
stock_considerations.dismiss
```

Store-scoped authorization consistent with existing workspace patterns.

---

## Integration with v0.04-5

Use `ProductVariants::OperationalPolicy` — see [Eligibility matrix](#eligibility-matrix).

---

## Verification

Rake: `shelfstack:v0046_verify_demand_foundation` (alias `shelfstack:v0046:verify_demand_foundation`).

**Cutover invariants (STRICT):**

* No v0.04 demand service creates `customer_request_lines`
* No v0.04 demand service creates `special_orders`
* No v0.04 demand service creates `purchase_request_lines`
* No v0.04 demand service calls `Inventory::Post`
* `DemandLines::StartFromItem` does not write legacy demand rows

**Additional checks:**

* Tables and enums present
* Used-wanted demand on used-like variants; customer present
* Manual TBO / buyer replenishment on vendor-orderable variants only
* `demand_number` matches `{store_number}-D{sequence:06d}` pattern

---

## Definition of done

1. Migrations for `demand_lines`, `demand_line_sequences`, `stock_considerations` run cleanly.
2. Demand number uses `{store_number}-D{sequence:06d}` via `DemandLines::NumberAllocator`.
3. Models, validations, and services implemented with audit events.
4. New demand entry from **item drawer**, **customer workspace**, and **`/demand` manual create** writes `demand_lines` only.
5. Item drawer shows **v0.04 demand actions only** — not legacy demand actions side-by-side.
6. Stock considerations create, convert, dismiss with **no inventory effect**.
7. `DemandLines::Expire` supports manual/staff expiry; **scheduled job deferred to v0.04-7**.
8. Used-wanted demand does not enter vendor sourcing.
9. Manual TBO / buyer replenishment requires vendor-orderable variants.
10. `manual_tbo` demand visible in `/demand` only — not legacy TBO-to-PO build screens.
11. Legacy tables may remain; v0.04 demand services **do not create rows in them**.
12. No mutating demand service calls `Inventory::Post` or mutates inventory balances.
13. Permissions seeded and enforced.
14. Tests cover eligibility matrix and inventory non-side-effects per [test-plan.md](test-plan.md).
15. Verify rake passes with `STRICT=1`.
16. [v0.04-6-completion.md](../../implementation/v0.04-6-completion.md) written; roadmap priority → v0.04-7.

---

## Next milestone

**v0.04-7 — Allocations and reservations** (`demand_allocations`, reservation bridge, nightly expiry job). **v0.04-3 — Product groups** remains deferred.
