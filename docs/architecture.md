# ShelfStack Architecture

## Purpose

This document explains the technical architecture of ShelfStack at a high level: application layers, major service domains, context, and principles that guide implementation.

For a quick domain → tables → services map see [architecture-map.md](architecture-map.md).

---

# 1. Architectural Goals

ShelfStack is a maintainable Rails application with clear separation between:

* Data models (validations, associations)
* Business rules (service objects)
* Authorization and audit
* Request/session context
* UI coordination (thin controllers, Turbo, Stimulus for focus/UI state only)

**Complex business rules belong in services**, not controllers, Stimulus controllers, or views. POS command routing and workflow state are Ruby-side (for example `Pos::CommandRegistry` in Phase 10-C).

---

# 2. Current Architectural Layers

ShelfStack is organized in phased domains. Each builds on the product variant as the sellable and inventory grain where applicable.

```text
Foundation (auth, stores, workstations, sessions, audit)
  ↓
Classification and tax
  ↓
Catalog → Product → Product Variant / SKU
  ↓
Inventory posting and tracking (eligibility gate)
  ↓
Purchasing and receiving
  ↓
POS (transactions, settlement, discounts, tax exceptions)
  ↓
Stored value and customer credit
  ↓
Customer demand and reservations
  ↓
Used buyback
  ↓
Operational reporting (/reports)
  ↓
Interaction system (modals, drawers, focus, command workspace — Phase 10)
  ↓
Deferred: GL-shaped financial export (Phase 9c)
```

| Layer | Primary namespaces / examples | Workspace |
| ----- | ------------------------------ | --------- |
| Foundation | `Authorization`, `SessionLifecycle`, `AuditEvents` | `/setup`, login |
| Catalog / SKU | `CatalogIdentifierService`, `SkuGenerator`, `ProductNameRenderer` | `/items` |
| Inventory | `Inventory::Post`, `Inventory::Eligibility`, `Inventory::TrackingResolver` | `/inventory` |
| Purchasing | `Purchasing::PostReceipt`, `Purchasing::MovingAverageCost` | `/orders` |
| POS | `Pos::CompleteTransaction`, `Pos::TaxRecalculator`, `Pos::DiscountRecalculator` | `/pos` |
| Stored value | `StoredValue::Post`, `Pos::PostStoredValueLedger` | `/pos`, `/customers` |
| Demand | `CustomerRequests::*`, `InventoryReservations::*` | `/customers` |
| Buyback | `Buybacks::CompleteSession`, `Buybacks::VoidSession` | `/buybacks` |
| Reports | `Reports::*` query objects | `/reports` |
| Interaction | Shared modal/drawer shells, `Pos::CommandRegistry` (10-C) | All |

Phase specs and [AGENTS.md](../AGENTS.md) list authoritative service names per domain.

---

# 3. Models

Models define database-backed records, associations, and basic validations.

Examples: `User`, `Store`, `CatalogItem`, `Product`, `ProductVariant`, `InventoryPosting`, `PosTransaction`, `StoredValueAccount`, `BuybackSession`.

Complex workflows (completion, posting, void, recalculation) belong in services.

---

# 4. Services

Services encapsulate business workflows in `app/services/`. Namespaced by domain (`Inventory::`, `Pos::`, `Purchasing::`, `StoredValue::`, `Buybacks::`, etc.).

### Cross-cutting services

| Service | Responsibility |
| ------- | -------------- |
| `Authorization` | Permission resolution and store scope |
| `AuditEvents` | Append-only audit with actor/context |
| `AuthenticationService` | Login validation and lockout |
| `SessionLifecycle` | Login, logout, lock, unlock, expiration |
| `WorkstationAssignmentService` | Browser workstation token assignment |
| `TaxRateLookup` | Effective-dated store tax rate resolution |

### Catalog and product services

| Service | Responsibility |
| ------- | -------------- |
| `CatalogIdentifierService` | Normalize, validate, ISBN-10→13, local IDs |
| `MetadataParser` | Creator/subject parsing to JSONB |
| `ProductNameRenderer` | Product and variant name generation |
| `SkuGenerator` | Product and variant SKU generation |

### Inventory services

| Service | Responsibility |
| ------- | -------------- |
| `Inventory::Post` | Authoritative inventory mutations |
| `Inventory::BalanceUpdater` | Cached balance projection |
| `Inventory::TrackingResolver` | Effective inventory vs non-inventory tracking |
| `Inventory::Eligibility` | Gate for posting and POS lines |
| `Inventory::CostEstimator` | Line cost fallback for postings |

Balances must not be mutated outside `Inventory::Post` / `Inventory::BalanceUpdater`.

### POS services

| Service | Responsibility |
| ------- | -------------- |
| `Pos::CompleteTransaction` | Completion, snapshots, inventory post, stored value |
| `Pos::VoidTransaction` | Void with reversal postings |
| `Pos::TaxRecalculator` | Normal tax, exemptions, line overrides |
| `Pos::DiscountRecalculator` | Structured discount applications |
| `Pos::CommandBarRouter` → `Pos::CommandRegistry` | Command parsing and routing (10-C) |
| `Pos::LineLookup` | Scan/catalog lookup for cart lines |

### Stored value services

| Service | Responsibility |
| ------- | -------------- |
| `StoredValue::Post` | Append-only ledger with account lock |
| `StoredValue::Issue`, `RedeemCredit`, `VoidEntry` | Account lifecycle |
| `Pos::PostStoredValueLedger` | POS tender redemption at completion |

### Purchasing, demand, buyback, reports

See phase specs for `Purchasing::*`, `CustomerRequests::*`, `Buybacks::*`, and `Reports::*` service lists in [AGENTS.md](../AGENTS.md).

Request context: `app/models/current.rb` (`CurrentAttributes`).

---

# 5. Current Context

ShelfStack uses shared request context via `CurrentAttributes`:

```ruby
Current.user
Current.store
Current.workstation
Current.user_session
Current.workstation_assignment
Current.time_zone
```

Set once per request; used by controllers, services, authorization, audit, and time zone display.

The browser must not be trusted for store, workstation, or permission data.

---

# 6. Authorization Architecture

```ruby
Authorization.allowed?(
  user: user,
  permission_key: "setup.users.update",
  store: store
)
```

Rules: active user/permission/role/assignment; global vs store-scoped assignments; system user excluded from interactive UI authorization.

---

# 7. Audit Event Architecture

Centralized via `AuditEvents.record!`. Append-only in normal operation. Include actor, event name, auditable/source, store/workstation/session context, JSONB details, UTC timestamp.

---

# 8. Session and Workstation Architecture

**Workstation:** browser raw token → digest in DB → resolve workstation and store.

**User session:** persisted record; statuses `active`, `locked`, `ended`, `expired`, `force_ended`. Inactivity locks session.

---

# 9. Tax Architecture

Three concepts: **Tax Category** (item taxability), **Store Tax Rate**, **Store Tax Category Rate** (effective-dated mapping).

`TaxRateLookup.call(store:, tax_category:, date:)` returns exactly one applicable rate or raises.

POS stores tax snapshots on lines at completion; Phase 8.5-2 adds exemption and line override recalculation via `Pos::TaxRecalculator`.

---

# 10. Catalog Identifier Architecture

Centralized in `CatalogIdentifierService`: normalization, check digits, ISBN-10→13, local generation, primary identifier rules, publisher number display vs index values.

External lookup (Phase 6.5): ISBNdb local-first import path integrated with Add Item wizard.

---

# 11. Product and Variant Architecture

Naming and SKU generation via `ProductNameRenderer` and `SkuGenerator`. Variants require `sub_department_id` for operational classification.

Inventory tracking: Phase 8 `Inventory::TrackingResolver` chain (override → legacy behavior → product default → product type). Staff UI syncs via `Items::InventoryTrackingSync`.

---

# 12. Inventory Architecture

Authoritative grain: `store_id + product_variant_id`.

```text
Inventory::Post
  → inventory_postings (immutable)
  → inventory_ledger_entries
  → inventory_balances (cached)
```

Only eligible variants post (via `Inventory::Eligibility`). POS posts via `posting_type: pos_transaction` / `pos_void`. Receiving posts `quantity_accepted` only.

---

# 13. POS Architecture

Register sessions scope business date and cash movements. Transactions are source documents with snapshotted tax, discount, classification, and inventory tracking on lines at completion.

Settlement: multi-row tenders (Phase 7B), stored value redemption, gift card sale lines. Completion assigns register session and business date; Phase 10-C adds draft stamping at create time and session-scoped active draft resolution.

Command workspace (10-C): shared idle/active shell, two-lane parser, `Pos::CommandRegistry` with permission and state checks. Domain rules (tax, discount eligibility, inventory posting) unchanged.

---

# 14. Stored Value Architecture

Canonical model: `stored_value_accounts`, `stored_value_ledger_entries`, `stored_value_identifiers`. Append-only ledger; negative balances not allowed. POS integrates at completion via tender and gift-card-sale line services.

Supersedes earlier separate gift-card/account table designs in Phase 6 docs.

---

# 15. Time Zone and Business Dates

Timestamps persisted in UTC; display uses store time zone.

**Business dates** are used for register sessions, POS completion, tax/discount lookup, and reporting. Register session `business_date` is authoritative for POS activity in that session.

---

# 16. Phase 10 Interaction Architecture

Phase 10-A delivers shared interaction infrastructure used across workspaces:

| Component | Role |
| --------- | ---- |
| Modal shell | Bounded decisions, settlement, confirmations |
| Drawer shell | Line-adjacent detail, return/pickup (10-C) |
| Expanded row | Inline cart/line edits |
| Toast region | Non-blocking confirmations |
| Focus helpers | Trap, restore, keyboard scope |

Conventions: [modal-and-drawer-patterns.md](specifications/modal-and-drawer-patterns.md), [keyboard-and-focus.md](specifications/keyboard-and-focus.md), [view-contracts.md](specifications/view-contracts.md).

Turbo targets (`modal`, `drawer`, `pos_cart`, etc.) documented in view contracts. Stimulus handles focus and UI state; **server renders authoritative workflow state**.

Phase 10-C adds POS command registry and idle workspace — see [phase-10c-pos-keyboard-workspace-spec.md](specifications/phase-10c-pos-keyboard-workspace-spec.md).

---

# 17. Deletion and Inactivation

Prefer `active = false` over hard delete for referenced records. Audit events append-only. Hard delete only for unused setup records.

---

# 18. Testing Principles

Security, permissions, posting idempotency, and service-layer rules are heavily tested. See [testing.md](testing.md) and phase test plans.

---

# 19. Deferred / Future Architecture

| Area | Status |
| ---- | ------ |
| GL-shaped financial postings and export | Phase 9c — deferred |
| Inventory location balances, transfers, cycle counts | Not implemented |
| Offline POS | Out of scope |
| Fully normalized contributors/subjects | Deferred normalization |

Operational reporting (9b) uses snapshots and ledgers; 9c would add accounting-grade postings when resumed.

---

# Related Documents

```text
docs/architecture-map.md
docs/domain-model.md
docs/implementation-guide.md
docs/security.md
docs/testing.md
AGENTS.md
```
