# AGENTS.md

## Purpose

This file provides guidance for AI coding agents and developer assistants working on ShelfStack.

Agents should follow the project documentation, preserve the domain model, and avoid making broad architectural changes without clear justification.

ShelfStack is a bookstore-focused catalog, inventory, stock, and point-of-sale management system. It is being developed in phases, beginning with foundation, classification/tax setup, and catalog/product/variant modeling.

---

# Project Overview

ShelfStack is designed for independent bookstores and similar retailers that sell both metadata-heavy items and ordinary retail products.

Examples of metadata-heavy items:

* Books
* Periodicals
* Recorded music
* Videorecordings
* Audiobooks
* eBooks
* Calendars
* Maps
* Games

Examples of simpler/non-catalog items:

* Sidelines
* Gifts
* Food and beverage items
* Services
* Donations
* Gift cards
* Event tickets

ShelfStack separates descriptive catalog metadata from store-facing products and sellable SKUs.

Core model:

```text
Catalog Item → Product → Product Variant/SKU → Inventory/POS Activity
```

---

# Primary Documentation

Before implementing or changing major behavior, review the relevant documents.

## General Documents

```text
docs/overview.md
docs/domain-model.md
docs/architecture.md
docs/roadmap.md
docs/implementation-guide.md
docs/glossary.md
docs/schema-reference.md
docs/specifications/seed-data-spec.md
docs/implementation/csv-seeds.md
```

## Phase 1 Documents

```text
docs/roadmap/phase-1-foundation.md
docs/specifications/phase-1-foundation-spec.md
docs/specifications/phase-1-data-model.md
docs/specifications/phase-1-test-plan.md
```

## Phase 2 Documents

```text
docs/roadmap/phase-2-departments-categories-taxes.md
docs/specifications/phase-2-classification-and-tax-spec.md
docs/specifications/phase-2-data-model.md
docs/specifications/phase-2-test-plan.md
```

## Phase 3 Documents

```text
docs/roadmap/phase-3-catalog-products-variants.md
docs/specifications/phase-3-catalog-products-variants-spec.md
docs/specifications/phase-3-data-model.md
docs/specifications/phase-3-test-plan.md
```

## Phase 4 Documents

```text
docs/roadmap/phase-4-inventory-foundation.md
docs/specifications/phase-4-inventory-foundation-spec.md
docs/specifications/phase-4-data-model.md
docs/specifications/phase-4-test-plan.md
```

## Phase 5 Documents

```text
docs/roadmap/phase-5-purchasing-and-receiving.md
docs/specifications/phase-5-purchasing-and-receiving-spec.md
docs/specifications/phase-5-data-model.md
docs/specifications/phase-5-test-plan.md
```

## Phase 6 Documents

```text
docs/roadmap/phase-6-pos-foundation.md
docs/specifications/phase-6-pos-foundation-spec.md
docs/specifications/phase-6-data-model.md
docs/specifications/phase-6-test-plan.md
```

## Phase 7A Documents

```text
docs/roadmap/phase-7a-customer-demand.md
docs/specifications/phase-7a-customer-demand-spec.md
docs/specifications/phase-7a-data-model.md
docs/specifications/phase-7a-test-plan.md
```

## Phase 7B Documents

```text
docs/roadmap/phase-7b-customer-credit-foundation.md
docs/roadmap/phase-7b-1-pos-settlement-foundation.md
docs/roadmap/phase-7b-2-stored-value-foundation.md
docs/roadmap/phase-7b-3-pos-stored-value-integration.md
docs/specifications/phase-7b-pos-settlement-spec.md
docs/specifications/phase-7b-stored-value-spec.md
docs/specifications/phase-7b-data-model.md
docs/specifications/phase-7b-test-plan.md
```

## Phase 7C Documents

```text
docs/roadmap/phase-7c-used-buyback.md
docs/specifications/phase-7c-used-buyback-spec.md
docs/specifications/phase-7c-data-model.md
docs/specifications/phase-7c-test-plan.md
```

If documentation and implementation disagree, flag the discrepancy rather than silently changing the domain model.

---

# Current Development Priority

Development follows the phase roadmap.

## Phase 1: Foundation — **Complete**

Phase 1 was completed on 2025-06-10. See [docs/implementation/phase-1-completion.md](docs/implementation/phase-1-completion.md) for deliverables, verification steps, and known gaps.

Do not remove or bypass Phase 1 protections (super administrator, system user, audit events) when extending the application.

## Phase 2: Departments, Categories, and Taxes — **Complete**

Phase 2 was completed on 2025-06-10. See [docs/implementation/phase-2-completion.md](docs/implementation/phase-2-completion.md).

## Phase 3: Catalog, Products, and Product Variants — **Complete**

Phase 3 was completed on 2025-06-10. See [docs/implementation/phase-3-completion.md](docs/implementation/phase-3-completion.md).

## Phase 4: Inventory Foundation — **Complete**

Phase 4 was completed on 2026-06-16. See [docs/implementation/phase-4-completion.md](docs/implementation/phase-4-completion.md).

## Phase 5: Purchasing and Receiving — **Complete**

Phase 5 was completed on 2026-06-10. See [docs/implementation/phase-5-completion.md](docs/implementation/phase-5-completion.md).

## Phase 6: POS Foundation — **Complete**

Phase 6 was completed on 2026-06-10. See [docs/implementation/phase-6-completion.md](docs/implementation/phase-6-completion.md).

## Phase 6.5: External Catalog Lookup — **Complete**

Phase 6.5 was completed on 2026-06-21. ISBNdb local-first lookup, Add Item wizard integration, and controlled import.

## Phase 7A: Customer Demand — **Complete**

Phase 7A was completed on 2026-06-21. See [docs/implementation/phase-7a-completion.md](docs/implementation/phase-7a-completion.md).

## Phase 7B: Customer Credit Foundation — **Complete**

Phase 7B was completed on 2026-06-21. See [docs/implementation/phase-7b-2-completion.md](docs/implementation/phase-7b-2-completion.md) and [docs/implementation/phase-7b-3-completion.md](docs/implementation/phase-7b-3-completion.md).

- 7B-1: merged via PR #23 (POS settlement foundation)
- 7B-2: stored value accounts/ledger (Customers workspace)
- 7B-3: POS issue/redeem/void integration, bearer refund identifiers, redemption balance cap, POS gift card sale/reload (`pos.gift_cards.issue`)

The canonical stored value model (`stored_value_*` tables) supersedes earlier `gift_card_accounts` / `store_credit_accounts` future-table language. Do not implement separate account tables.

Do not jump ahead to offline POS or full GL unless explicitly requested.

## Phase 7C: Used Buyback — **Complete**

Phase 7C was completed on 2026-06-23. See [docs/implementation/phase-7c-completion.md](docs/implementation/phase-7c-completion.md).

- Buyback workspace at `/buybacks`; single payout mode per session (cash OR trade_credit OR no_value_donation)
- Completion: `used_buyback` inventory posting, `source: BuybackSession`; void via `buyback_voids` + `buyback_void` posting
- Workstation-scoped buyback numbers: `{store_number}-{workstation_number}-B{sequence:06d}`
- Trade credit issues to `trade_credit` account with identifier for POS redemption

---

# Architectural Principles

## Keep controllers thin

Controllers should coordinate requests and responses. They should not contain complex business rules.

Use services for:

* Authorization
* Audit logging
* Session lifecycle
* Workstation assignment
* Tax lookup
* Identifier normalization
* ISBN conversion
* Local identifier generation
* SKU generation
* Product/variant name rendering
* Metadata parsing
* Inventory posting, eligibility, cost estimation, and balance updates
* Purchasing: returnability, vendor cost, sourcing lookup, receipt and RTV posting, moving average cost
* POS: line lookup, transaction type derivation, return quantity validation, tax/discount/tender calculators, complete and void workflows, register session lifecycle, inventory posting via `pos_transaction` / `pos_void`
* Stored value: issue, adjust, redeem, void, transfer, identifier codec, balance rebuild/integrity, liability reporting

## Centralize business rules

Do not duplicate domain rules across controllers, models, views, and jobs.

Examples of expected service areas:

```text
Authorization
AuditEvents
SessionLifecycle
WorkstationAssignment
TaxRateLookup
CatalogIdentifierService
SkuGenerator
ProductNameRenderer
MetadataParser
Inventory::Eligibility
Inventory::CostEstimator
Inventory::Post
Inventory::BalanceUpdater
Inventory::RebuildBalances
Inventory::BalanceIntegrityCheck
StoredValue::Post
StoredValue::BalanceUpdater
StoredValue::Issue
StoredValue::Adjust
StoredValue::VoidEntry
StoredValue::Transfer
StoredValue::RedeemCredit
StoredValue::IdentifierCodec
StoredValue::RebuildBalances
StoredValue::BalanceIntegrityCheck
StoredValue::LiabilityReport
Buybacks::CompleteSession
Buybacks::VoidSession
Buybacks::PostVoidInventory
Buybacks::PriceLine
Buybacks::ResolveItem
Purchasing::ReturnabilityResolver
Purchasing::VendorCostCalculator
Purchasing::SourcingLookup
Purchasing::BuildPurchaseOrder
Purchasing::SubmitPurchaseOrder
Purchasing::PostReceipt
Purchasing::PostReturnToVendor
Purchasing::MovingAverageCost
```

## Preserve auditability

Important setup, security, catalog, product, SKU, identifier, and lifecycle changes should create audit events.

Do not implement silent destructive changes.

## Prefer inactivation over deletion

Once records are referenced, prefer:

```text
active = false
```

over hard deletion.

Examples:

* Users
* Stores
* Roles
* Departments
* Categories
* Tax categories
* Catalog items
* Products
* Product variants
* Vendors

Hard delete should only be allowed for unused records where no history would be affected.

---

# Naming Conventions

## Product name

Use:

```text
ShelfStack
```

Do not use old or alternate names such as ShelfSense or BookSense.

## Booleans

Use Rails-style boolean names without `is_`.

Preferred:

```text
active
virtual
digital
large_print
new_condition
primary_identifier
system_role
```

Avoid:

```text
is_active
is_virtual
is_digital
is_large_print
is_new
```

## Stable keys

Use `_key` for stable internal identifiers.

Examples:

```text
permission_key
role_key
format_key
condition_key
```

## Dates and times

Use `_at` for datetimes:

```text
created_at
updated_at
last_login_at
locked_at
ended_at
```

Use `_on` for dates:

```text
effective_on
ends_on
```

## Controlled type fields

Avoid a plain `type` column unless intentionally using Rails single-table inheritance.

Use explicit names:

```text
user_type
scope_type
workstation_type
catalog_item_type
product_type
variation_type
identifier_type
```

---

# Database Conventions

## Money

Store prices as integer cents.

Examples:

```text
products.list_price_cents
product_variants.selling_price_cents
```

## Percentages

Store percentages as integer basis points.

Examples:

```text
tax_rate_bps
default_margin_target_bps
default_supplier_discount_bps
default_list_price_factor_bps
```

Reference:

| Percent | Basis Points |
| ------: | -----------: |
|   0.00% |            0 |
|   6.00% |          600 |
|  40.00% |         4000 |
| 100.00% |        10000 |

## JSONB

Use JSONB for flexible metadata where full normalization is intentionally deferred.

Examples:

```text
event_details
creator_details
publisher_details
series_data
bisac_subject_data
genre_data
theme_data
target_audience_data
access_restriction_data
```

Do not use JSONB for clear business relationships that should be modeled relationally.

## Foreign keys

Use foreign keys for explicit references.

Examples:

```text
users.default_store_id → stores.id
sub_departments.department_id → departments.id
catalog_items.format_id → formats.id
products.catalog_item_id → catalog_items.id
product_variants.product_id → products.id
product_variants.sub_department_id → sub_departments.id
```

---

# Domain Rules to Preserve

## Phase 1 Rules

* System user cannot log in interactively.
* Role assignments may be global or store-scoped.
* Store-scoped role assignments apply only in the matching store context.
* Workstation context is resolved server-side from a secure token.
* Browser stores raw workstation token; database stores digest.
* User sessions are persisted.
* Session statuses are controlled: `active`, `locked`, `ended`, `expired`, `force_ended`.
* Terminal sessions cannot return to active.
* Inactivity timeout **locks** the session; it does not set `force_password_change` or require full re-login.
* Interactive users must set a PIN after login (navigation gated until `pin_digest` is present).
* Self-service password and PIN changes require matching confirmation fields.
* Audit events are append-only in normal behavior.
* At least one active interactive global super administrator path must remain.

## Phase 2 Rules

* Departments are global.
* Department numbers are strings, three digits, numeric-only, and zero-padded.
* Tax categories describe item taxability.
* Store tax rates belong to stores.
* Store tax category rates are effective-dated mappings.
* For a store, tax category, and date, tax lookup must return exactly one applicable active rate.
* Overlapping active tax mappings for the same store/tax category/date are not allowed.
* Phase 2 `categories` table was **removed** (2025-06); sellable classification uses `sub_departments` and store category nodes instead.

## Phase 3 Rules

* Catalog items are metadata records, not sellable SKUs.
* Products are store-facing product groupings.
* Product variants are actual sellable SKUs.
* Every catalog item must have at least one active identifier.
* Every catalog item must have exactly one active primary identifier.
* ISBN-10 identifiers are saved as non-primary and converted to ISBN-13 primary identifiers.
* Invalid standard identifiers may be saved, but the user must be warned.
* Publisher numbers preserve display value and store normalized searchable value.
* Product SKU is required and unique.
* Catalog-linked product SKU defaults from catalog primary identifier.
* Variant SKU is required and unique.
* New condition has no SKU suffix.
* Condition variants append condition SKU component.
* Variable variants append attribute 1 SKU component.
* Matrix variants append attribute 1 and attribute 2 SKU components.
* Product and variant names are generated conservatively and may be overridden.
* Product is not sellable until it has at least one active variant.

## Phase 3B transitional rules

* `SubDepartment` is the operational sellable classification (renamed from `merchandise_classes`).
* `CategoryNode` in the `store_categories` scheme is the store shelving/topic tree (not Phase 2 `categories`).
* `product_variants.sub_department_id` is **required**; `product_variants.category_id` was removed.
* Default resolution order: variant override → variant `sub_department` → product defaults → store category defaults (catalog path).
* GL posting uses `sub_department → department.gl_account_code` (no `AccountingMapping`).
* `SubDepartment.short_name` may duplicate; `sub_department_key` and `name` are unique.
* Classification reference seeds load from `db/seeds/data/*.csv`; validate with `rails shelfstack:seeds:validate`.
* See `docs/specifications/classification-target-spec.md` and `docs/implementation/classification-cleanup.md`.

## Phase 4 Rules

* Authoritative inventory grain is `store_id + product_variant_id`.
* Only `inventory_behavior = standard_physical` variants are ledger-eligible.
* Balances are cached from posted ledger entries; do not mutate balances outside `Inventory::Post` / `Inventory::BalanceUpdater`.
* `quantity_available = quantity_on_hand - quantity_reserved` after Phase 7A on-hand holds (`quantity_reserved` cached from active `on_hand_hold` / `special_order_reserve` reservations).
* Negative on-hand is allowed; treat as an operational exception.
* Posted postings and ledger entries are immutable in normal operation.
* Inventory locations are context only; they do not maintain authoritative balances.
* Cost fallback order: manual line cost → subdepartment margin estimate → unknown.
* Phase 4 restores `sub_departments.default_margin_target_bps` for margin estimation.

## Phase 5 Rules

* Purchasing grain is product variant; multi-vendor via `product_vendors` and `product_variant_vendors`.
* Only `quantity_accepted` on receipt lines posts to inventory (`posting_type: receiving`, `movement_type: received`).
* PO lines snapshot SKU, name, vendor item number, list price, discount, unit cost, and returnability at submit.
* Returnability precedence: `product_variant_vendors` → `product_vendors` → `product_variants.returnability_status`.
* Receipt cost updates moving average on `inventory_balances`; vendor returns post via `vendor_return`.
* TBO (purchase requests) does not affect inventory.

## Phase 6 Rules

* POS uses `pos_*` tables; inventory only via `Inventory::Post`.
* Completed transaction: one posting with `posting_type: pos_transaction`, `source: PosTransaction`; ledger lines use `movement_type: sold` or `customer_return`.
* Only `inventory_behavior = standard_physical` lines with `product_variant_id` post; open-ring without variant does not post.
* Do not store `inventory_posting_id` on `pos_transactions`.
* `pos_sale` and `customer_return` posting types are reserved on the enum; do not use for new POS postings.
* Completed void: `pos_voids` source, `posting_type: pos_void`, reversal FKs; reversing `pos_tenders`; original transaction immutable.
* `transaction_type` derived at completion from variant/open_ring lines only; draft type may be provisional.
* `receipt_number == transaction_number` in Phase 6; separate columns.
* Transaction number assigned at completion; sequence per workstation.
* Suspended transactions may complete under a later register session and `business_date`.
* `ClassificationDefaultsResolver` + `TaxRateLookup` use transaction `business_date`; missing tax/subdepartment blocks completion.
* Inactive sell: warn + confirm; $0 allowed with price prompt.
* `Pos::ReturnQuantityValidator`: cumulative returns ≤ original sold qty via `source_transaction_line_id`.
* `Pos::TenderTypePolicy` + `Pos::TenderValidator` enforce stored value tender permissions and account linkage; legacy Phase 6 allowlist remains as base types only.
* Gift-card and store-credit **ledgers** use `stored_value_*` tables; POS posts via `Pos::PostStoredValueLedger`.

## Phase 7A Rules

* `notify` request lines surface in Notify Customer queue on stock arrival; **no auto-hold**.
* Default hold expiry: 14 days (`expires_at`); staff may override; nightly `InventoryReservations::Expire`.
* Over-reserve on-hand uses reservation override columns + `inventory_reservations.override`; POS reserved-stock override uses `pos_authorizations`.
* PO customer allocations require `special_order_id`; auto-merge same variant + vendor on draft PO lines; TBO FK path unchanged.
* Receipt customer allocation is atomic with `PostReceipt`; failure rolls back entire receipt.
* Pickup POS lines require `inventory_reservation_id`; validate consistent demand chain FKs.
* Partial receipt: FIFO allocation to PO line allocations; partial pickup/void/cancel per spec.
* Header status derived via `CustomerRequests::HeaderStatusResolver`; manual override limited to terminal statuses.

## Phase 7B Rules

* Implement in order: 7B-1 settlement → 7B-2 stored value ledger → 7B-3 POS integration. **Phase 7B is complete.**
* Multiple `pos_tender` rows per transaction; one cash row only; `sum(amount_cents) == total_cents`.
* Cash drawer math uses `amount_cents`, not `tendered_cents`; migrate legacy `reference_number` tendered hack.
* Check refunds out of scope for 7B-1; check payments only.
* Stored value: append-only ledger; `stored_value_*` supersedes `gift_card_accounts` / `store_credit_accounts`.
* Negative stored value balances not allowed; account row locked on post via `StoredValue::Post`.
* Manual issue/adjust/transfer/void require reason code and audit events (7B-2 admin UI).
* `Pos::TenderTypePolicy` enables `store_credit` / `gift_card` **tender redemption** when actor has `pos.tenders.*`; `pos.refunds.store_credit` (or related) for return store-credit issuance via negative settlement rows.
* **Gift card sale/reload** is a `gift_card_sale` POS line (not a `gift_card` tender): variable amount via `/giftcard` command; pay with cash/card/check; `Pos::PostGiftCardSaleLedger` issues balance at completion; requires `pos.gift_cards.issue`.
* POS redemption saves `min(amount entered, account balance)` on store-credit/gift-card tender rows; remainder due needs another tender.
* POS completion posts stored value ledger via `Pos::PostStoredValueLedger` (tenders) and `Pos::PostGiftCardSaleLedger` (gift card sale lines); void reverses both via `Pos::ReverseStoredValueLedger`.
* POS void reverses stored value ledger entries via `reverses_entry_id`; do not mutate originals.
* Liability reporting is operational only — no GL export in 7B.

## Phase 7C Rules

* Dual eligibility: `sub_department.buyback_allowed` AND `product_condition.buyback_eligible`.
* Single payout mode per session: `cash`, `trade_credit`, or `no_value_donation` (never both cash and credit).
* Completion inventory: `posting_type: used_buyback`, `source: BuybackSession`; void: `posting_type: buyback_void`, `source: BuybackVoid`.
* Movement type `used_buyback` for original and reversal lines; cost sources `buyback_offer` / `no_value_donation`.
* Workstation-scoped buyback numbers via `buyback_sequences`.
* Trade credit issues to `trade_credit` account; POS redemption via identifier or explicit account only.
* `merged_into_customer_id` is schema-only in 7C; no merge workflow.

---

# Testing Expectations

Every meaningful change should include or update tests.

## Test categories

Use tests for:

* Models
* Validations
* Services
* Authorization
* Request/controller behavior
* System flows where useful
* Audit events
* Seeds

## Always test

* Permission checks
* Store-scoped access
* Audit event creation
* Seed idempotency
* Controlled value validation
* Deletion/inactivation rules
* Security-sensitive workflows

## Phase-specific test focus

### Phase 1

* Login/logout
* Failed login attempts
* Session locking/unlocking
* Forced session termination
* Workstation assignment
* Super administrator protection

### Phase 2

* Department number normalization
* Tax rate basis points
* Effective-dated tax lookup
* Tax mapping overlap prevention
* Subdepartment and store category defaults

### Phase 3

* Identifier normalization
* Check digit validation
* ISBN-10 to ISBN-13 conversion
* Local identifier generation
* SKU generation
* Variant name rendering
* Creator/subject metadata parsing

### Phase 4

* Inventory eligibility by `inventory_behavior`
* Posting idempotency
* Balance equals ledger sum
* Cost estimation and valuation snapshots
* Adjustment draft/post/cancel workflows
* Store-scoped inventory authorization
* Balance rebuild and integrity checks

### Phase 5

* Returnability precedence and RTV posting
* Receipt posts only accepted qty; moving average cost
* TBO does not affect inventory

### Phase 6

* Lookup ranking and transaction type derivation
* Return quantity validation across partial returns
* Inventory posting eligibility and void reversal FKs
* Register session business_date and suspended completion
* Tender validation and reversing tenders on void
* Workstation-scoped transaction numbering
* Full `pos.*` permission enforcement

---

# Seed Data Rules

Seeds must be idempotent.

Running seeds multiple times should not duplicate records.

Use stable keys:

| Entity            | Stable Key              |
| ----------------- | ----------------------- |
| User              | `username`              |
| Role              | `role_key`              |
| Permission        | `permission_key`        |
| Store             | `store_number`          |
| Department        | `department_number`     |
| SubDepartment     | `sub_department_key`    |
| Tax Category      | `name`                  |
| Category Node     | `node_key` (per scheme) |
| Display Location  | `short_name`            |
| Format            | `format_key`            |
| Product Condition | `condition_key`         |
| Inventory Reason Code | `reason_key`        |

Classification CSV files and load order: `docs/specifications/seed-data-spec.md`, `docs/implementation/csv-seeds.md`. Importer: `db/seeds/concerns/csv_classification_importer.rb`.

When updating seed files, prefer upsert-style behavior based on stable keys.

---

# Audit Event Guidelines

Use dot-separated event names.

Examples:

```text
user.login
session.locked
department.created
catalog_item_identifier.isbn10_converted
product_variant.sku_generated
product_variant.name_regenerated
```

Audit events should include:

* Actor
* Event name
* Auditable record where applicable
* Source record where applicable
* Store context where applicable
* Workstation context where applicable
* User session context where applicable
* JSONB event details
* UTC timestamp

---

# UI Guidelines

## Workspaces

Present operational catalog/product/variant work in the **Items** workspace (`/items`). Admin reference data (formats, product conditions, display locations, vendors, tax, users) belongs in **Setup** (`/setup`).

Use user-facing labels from the UX concept (Item Details, Selling Setup, Sellable SKUs) in Items views via `ItemsHelper`.

Unified item flows should use `Items::ItemPresenter` and `ItemLifecycleStatus` rather than branching on raw model types in views.

## Setup screens

Setup screens should generally include:

* List
* Search/filter
* Detail
* Create
* Edit
* Inactivate
* Reactivate
* Delete only when allowed
* Audit timeline

## Dynamic forms

Use dynamic forms where the domain calls for it.

Examples:

* `catalog_item_type` controls catalog metadata fields shown.
* `variation_type` controls variant attribute fields.
* `inventory_behavior` controls future POS/inventory behavior.
* Tax mapping screens should preview applicable date ranges.
* SKU screens should preview generated SKUs.

## Real-time previews

Where practical, show previews for:

* Department number normalization
* Tax rate percentage from basis points
* Product SKU
* Variant SKU
* Product name
* Variant name
* Used condition price factor

---

# Do Not Do Without Confirmation

Do not introduce these unless explicitly requested:

* POS transaction tables
* Purchase order tables
* Receiving tables
* Vendor-product sourcing tables
* Product price history tables
* Inventory location balance tables
* Inventory transfer and reservation tables
* Fully normalized contributor tables
* Fully normalized subject tables
* External bibliographic API integration
* Offline POS implementation
* Major authentication library changes
* Major database engine changes
* New framework/language choices

Flag these as future-phase work instead.

---

# Preferred Development Sequence for a Feature

1. Read relevant roadmap/spec/data-model/test-plan.
2. Confirm the phase and scope.
3. Add or update migration.
4. Add or update model and validations.
5. Add or update service objects.
6. Add or update authorization checks.
7. Add or update audit events.
8. Add or update setup UI.
9. Add or update seeds.
10. Add or update tests.
11. Update documentation.

---

# Definition of Done

A feature is not done until:

1. It matches the relevant specification.
2. Migrations run cleanly.
3. Models and services are implemented.
4. Authorization is enforced.
5. Audit events are created where required.
6. Seeds are idempotent where applicable.
7. Tests pass.
8. Documentation is updated.
9. Deferred behavior is explicitly noted.

---

# Agent Behavior

When working on ShelfStack:

* Preserve the domain model.
* Make small, explainable changes.
* Prefer explicit service objects for business rules.
* Avoid unrequested scope expansion.
* Do not silently rename established concepts.
* Do not bypass authorization or audit requirements.
* Do not remove historical data paths.
* Ask for clarification when a change affects phase scope or core architecture.
* If a requested change conflicts with existing documentation, identify the conflict clearly.
