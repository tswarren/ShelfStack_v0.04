# ShelfStack Roadmap

## Purpose

This document summarizes ShelfStack’s development roadmap.

It explains the purpose of each phase, the major capabilities introduced, and how each phase builds toward a complete bookstore-focused catalog, inventory, purchasing, and point-of-sale system.

Detailed implementation specifications live in the phase-specific roadmap, functional specification, data model, and test plan documents.

---

# Roadmap Summary

ShelfStack is being developed in phases.

Each phase should produce a coherent working foundation for later phases, rather than a disconnected set of tables or screens.

| Phase   | Focus                           | Outcome                                                                                                      |
| ------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Phase 1 | Foundation                      | Users, roles, permissions, stores, workstations, sessions, and audit events.                                 |
| Phase 2 | Classification and Taxes        | Departments, subdepartments, tax categories, store tax rates, and effective-dated tax mappings.              |
| Phase 3 | Catalog, Products, and Variants | Catalog metadata, identifiers, products, product variants, SKUs, conditions, display locations, and vendors. |
| Phase 4 | Inventory Foundation            | Inventory ledger, store balances, adjustments, valuation snapshots, and inventory read surfaces.             |
| Phase 5 | Purchasing and Receiving        | Vendors, purchase orders, receiving, supplier terms, vendor costs, and returns to vendor.                    |
| Phase 6 | POS Foundation                  | Register sessions, POS transactions, tax/tender snapshots, inventory posting, void reversals, receipts, and workstation-aware POS behavior. |
| Phase 6.5 | External Catalog Lookup       | Real-time ISBN local-first lookup via ISBNdb, candidate preview, controlled catalog import, and Add Item wizard integration. **Complete.** |
| Phase 7A | Customer Demand               | Customers, requests, special orders, holds/reservations, PO/receipt allocations, ready-for-pickup, POS fulfillment. **Complete.** |
| Phase 7B | Customer Credit Foundation    | POS multi-row settlement (7B-1), stored value accounts/ledger (7B-2), POS issue/redeem (7B-3). **Complete.** |
| Phase 7C | Used Buyback                  | Customer-required buyback sessions, graded used variants, cash/trade-credit/donation payout, inventory posting. **Complete** (2026-06-23). |
| Phase 8 | Inventory Eligibility and Tracking | Centralized inventory tracking gate (`inventory` / `non_inventory`); behavior-neutral resolver/eligibility refactor. **8-1/8-2 complete** (2026-06-23). |
| Phase 8.5-1 | POS Discount Model & Calculation | Structured discount reasons, applications, allocations, stacking, and non-discountable rules. **In review** (branch merge pending). |
| Phase 7 | Advanced Store Operations       | Transfers, cycle counts, and remaining operational workflows.                                      |
| Phase 9 | Reporting and Accounting        | Report UX foundation (9a) and operational reports (9b) **complete**. GL-shaped financial postings and export (9c) **deferred**; see Phase 10. |
| Phase 10 | Comprehensive UI/UX Expansion  | Interaction infra (10-A ✓), item cockpit (10-B ✓), POS workspace (10-C ✓), workflow polish (10-D ✓), consistency sweep (10-E ✓ on integration branch; v0.04-14 release pending). |

Later phases may be split or reordered as implementation details become clearer.

---

# ShelfStack v0.04 Core

**v0.04 is the core domain model** — not Phase 11. Phases 1–10 delivered the v0.03 codebase; v0.04 is the canonical architecture for products, identifiers, demand, sourcing, and receiving going forward.

| Document | Purpose |
| -------- | ------- |
| [design/VERSION_0.04.md](design/VERSION_0.04.md) | Core domain model |
| [roadmap/v0.04-delivery-roadmap.md](roadmap/v0.04-delivery-roadmap.md) | Implementation milestones |
| [v0.04/README.md](v0.04/README.md) | Milestone spec index |

**Status:** Active. v0.04-0 complete. Current milestone: v0.04-1 product fusion.

---

# Phase 1: Foundation

## Purpose

Phase 1 establishes the operational foundation for ShelfStack.

It answers:

> Who is using the system, where are they working, what are they allowed to do, and how is their activity audited?

## Major Capabilities

* Users
* Roles
* Permissions
* Role assignments
* Stores
* Workstations
* Browser-to-workstation assignments
* User sessions
* Session locking/unlocking
* Forced session termination
* Audit events
* Setup navigation
* Foundation seed data

## Key Outcomes

At the end of Phase 1:

1. Users can log in and out.
2. Sessions can be locked, unlocked, expired, ended, or force-ended.
3. Workstation and store context are resolved server-side.
4. Permissions are resolved from roles and role assignments.
5. Roles may be global or store-scoped.
6. Setup screens are permission-controlled.
7. Audit events are created for security and setup changes.
8. The application shell displays user, store, workstation, and session context.

**Status:** Implemented. See [implementation/phase-1-completion.md](implementation/phase-1-completion.md).

## Detailed Documents

```text
docs/roadmap/phase-1-foundation.md
docs/specifications/phase-1-foundation-spec.md
docs/specifications/phase-1-data-model.md
docs/specifications/phase-1-test-plan.md
```

---

# Phase 2: Departments, Subdepartments, and Taxes

## Purpose

Phase 2 establishes the classification and tax setup layer.

It answers:

> How are future sellable items classified for reporting, pricing defaults, and tax behavior?

> **Note:** Phase 2 originally delivered a `categories` table. That table was removed in the 2025-06 classification simplification; operational defaults now live on `sub_departments`. See [implementation/classification-cleanup.md](implementation/classification-cleanup.md).

## Major Capabilities

* Departments
* Subdepartments (operational merchandise behavior buckets)
* Tax categories
* Store tax rates
* Store tax category rates
* Effective-dated tax lookup
* Subdepartment default pricing model
* Subdepartment default margin target
* Subdepartment default supplier discount
* Subdepartment default tax category
* Phase 2 setup permissions
* Phase 2 audit events
* Bookstore-oriented seed data

## Key Outcomes

At the end of Phase 2:

1. Departments exist as top-level sales/reporting buckets.
2. Department numbers are three-character zero-padded strings.
3. Subdepartments belong to departments and provide operational defaults for sellable items.
4. Subdepartments provide defaults for future product variants.
5. Tax categories classify item taxability.
6. Store tax rates define store-specific tax percentages.
7. Store tax category rates map tax categories to store tax rates by effective date.
8. Tax lookup returns exactly one active rate for a store, tax category, and date.
9. Phase 2 setup screens are permission-controlled.
10. Phase 2 setup changes are audited.

**Status:** Implemented. See [implementation/phase-2-completion.md](implementation/phase-2-completion.md).

## Detailed Documents

```text
docs/roadmap/phase-2-departments-categories-taxes.md
docs/specifications/phase-2-classification-and-tax-spec.md
docs/specifications/phase-2-data-model.md
docs/specifications/phase-2-test-plan.md
```

---

# Phase 3: Catalog, Products, and Product Variants

## Purpose

Phase 3 establishes the catalog and sellable SKU foundation.

It answers:

> What is this item, how does the store sell it, and what is the sellable SKU?

## Major Capabilities

* Formats
* Catalog items
* Catalog item identifiers
* Local identifier generation
* ISBN-10 to ISBN-13 conversion
* Identifier validation and warnings
* Creator metadata parsing
* Subject metadata parsing
* Products
* Product conditions
* Product variants
* Product SKU generation
* Variant SKU generation
* Product and variant name rendering
* Display locations
* Store display locations
* Vendor directory
* Phase 3 setup permissions
* Phase 3 audit events

## Key Outcomes

At the end of Phase 3:

1. Catalog items can describe books, media, periodicals, sidelines, and other items.
2. Every catalog item has at least one active identifier.
3. Every catalog item has exactly one active primary identifier.
4. Product SKUs are required base SKUs.
5. Product variants are actual sellable SKUs.
6. Variant SKUs are generated from product SKU plus condition and/or attribute components.
7. Product names default from catalog titles or user entry.
8. Variant names default from product name plus condition and/or attributes.
9. Display locations support merchandising setup.
10. Vendors exist as a basic directory.
11. Phase 3 setup screens are permission-controlled.
12. Phase 3 setup changes are audited.

## Detailed Documents

```text
docs/roadmap/phase-3-catalog-products-variants.md
docs/specifications/phase-3-catalog-products-variants-spec.md
docs/specifications/phase-3-data-model.md
docs/specifications/phase-3-test-plan.md
```

---

# Phase 4: Inventory Foundation

## Purpose

Phase 4 establishes the inventory ledger and store-level balance foundation.

It answers:

> What quantity of each product variant does each store have, how did it change, and what is its estimated value?

Detailed scope: [roadmap/phase-4-inventory-foundation.md](roadmap/phase-4-inventory-foundation.md)

## Expected Capabilities

* Grouped inventory postings and append-only ledger entries
* Cached `inventory_balances` at `store_id + product_variant_id`
* Quantity on hand and quantity available (initially equal)
* Negative on-hand support
* Opening inventory and manual adjustments
* Cost and retail valuation snapshots
* Inventory reason codes and optional inventory locations (context only)
* Inventory audit events
* Store, variant, product, and enterprise read surfaces
* Balance rebuild and integrity-check tooling

## Expected Design Direction

Inventory operates at the product variant + store level.

```text
Product Variant → Inventory Posting → Inventory Ledger Entries → Inventory Balance
```

Only variants with `inventory_behavior = standard_physical` are ledger-eligible in Phase 4.

Balances are cached projections from posted ledger entries. Application code must post through `Inventory::Post`, not mutate balances directly.

## Phase 4 Tables

```text
inventory_postings
inventory_ledger_entries
inventory_balances
inventory_adjustments
inventory_adjustment_lines
inventory_reason_codes
inventory_locations
```

Phase 4 also restores `sub_departments.default_margin_target_bps` for cost estimation.

## Documentation

```text
docs/roadmap/phase-4-inventory-foundation.md
docs/specifications/phase-4-inventory-foundation-spec.md
docs/specifications/phase-4-data-model.md
docs/specifications/phase-4-test-plan.md
```

## Major Risks

* Preventing balance drift from direct mutation
* Idempotent posting from adjustments
* Cost estimation when actual cost is unknown
* Handling ineligible variant behaviors
* Store-scoped authorization on write paths

---

# Phase 5: Purchasing and Receiving — **Complete**

Phase 5 was completed on 2026-06-10. See [docs/implementation/phase-5-completion.md](docs/implementation/phase-5-completion.md).

Normative requirements:

```text
docs/roadmap/phase-5-purchasing-and-receiving.md
docs/specifications/phase-5-purchasing-and-receiving-spec.md
docs/specifications/phase-5-data-model.md
docs/specifications/phase-5-test-plan.md
```

Delivered: vendor sourcing, purchase requests (TBO), purchase orders, receiving with moving average cost, returns to vendor, Orders workspace (`/orders`), setup sourcing CRUD, permissions, audit events, and seeds.

---

## Major Risks

* Multiple vendors for the same item
* Vendor-specific item numbers
* Returnable versus non-returnable inventory
* Supplier discounts
* Net cost versus list-price discount purchasing
* Partial receiving
* Backorders and cancellations

---

# Phase 6: POS Foundation

## Purpose

Phase 6 establishes core point-of-sale behavior.

It should answer:

> What was sold or returned, at what price, with what tax, through which workstation, by which user, on which business date, and how was payment taken?

## Documentation

Detailed scope, locked decisions, and exit criteria:

```text
docs/roadmap/phase-6-pos-foundation.md
docs/specifications/phase-6-pos-foundation-spec.md
docs/specifications/phase-6-data-model.md
docs/specifications/phase-6-test-plan.md
```

## Expected Capabilities

* Register sessions and cash movements
* Draft, suspended, completed, and voided POS transactions
* Sale, return, and exchange (mixed signed lines)
* Open-ring lines and open-ring returns
* Tax and tender snapshots
* Workstation-scoped transaction numbering
* Register-session business dates
* Inventory posting via `Inventory::Post` (`pos_transaction`, `pos_void`)
* Completed void reversal workflow (`pos_voids`)
* Receipts and snapshot reports
* Full `pos.*` permissions and audit events

## Design Direction

* Use `pos_*` tables, not `sales` / `sale_*`.
* Snapshot mutable product, price, and tax data on lines at completion.
* Do not store `inventory_posting_id` on `pos_transactions`; use polymorphic posting sources.
* One inventory posting per completed transaction; void reversals use separate `PosVoid` source.

## Major Risks

* Tax accuracy and business-date handling
* Historical snapshot preservation
* Return quantity validation across partial returns
* Register session and suspended-transaction edge cases
* Void reversal correctness (inventory and tenders)
* Offline POS requirements (deferred)

---

# Phase 6.5: External Catalog Lookup

## Purpose

Phase 6.5 adds real-time ISBN lookup for catalog-linked Add Item workflows.

It should answer:

> Can staff scan an ISBN, see a provider candidate or local match, preview fields, and import catalog metadata before continuing the Add Item wizard?

## Documentation

```text
docs/roadmap/phase-6.5-external-catalog-lookup.md
docs/specifications/phase-6.5-external-catalog-lookup-spec.md
docs/specifications/phase-6.5-data-model.md
docs/specifications/phase-6.5-test-plan.md
```

## Expected Capabilities (MVP)

* ISBNdb provider configuration and manual health check
* Local-first ISBN lookup with synchronous external fallback
* Candidate preview and exact-ISBN duplicate detection
* Controlled catalog import (create, link, fill-blank)
* Add Item `identify` wizard step and post-import handoff to `item_details`
* `items.external_lookup.*` permissions and audit events

## Out of Scope (MVP)

* Keyword/title/author search (Phase 6.5E)
* POS register lookup
* Lookup-result caching and automatic retry

---

# Phase 7B: Customer Credit Foundation

## Purpose

Phase 7B introduces customer credit by upgrading POS settlement, then adding stored value accounts and ledgers, then wiring POS issue and redeem.

It should answer:

> How does POS record split payments and refunds, how are store credit and gift-card-style balances tracked as liabilities, and how does POS issue and redeem stored value safely?

## Documentation

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

## Slices

| Slice | Focus |
| --- | --- |
| 7B-1 | Multiple card/check rows, structured cash/card/check fields, settlement UI, receipts, reports |
| 7B-2 | `stored_value_*` accounts, identifiers, append-only ledger, transfers, liability reporting |
| 7B-3 | POS issue from returns/exchanges, redeem as tender, void reversal |

Phase 6 reserved `gift_card` and `store_credit` tender types; Phase 7B activates stored value. The generic `stored_value_*` model supersedes earlier `gift_card_accounts` / `store_credit_accounts` future-table language.

**Status:** Implemented. See [implementation/phase-7b-2-completion.md](implementation/phase-7b-2-completion.md) and [implementation/phase-7b-3-completion.md](implementation/phase-7b-3-completion.md).

## Deferred

Check refunds, deposits/prepayments, buyback intake, multi-store liability settlement, GL export.

---

# Phase 7: Advanced Store Operations

## Purpose

Phase 7 should expand operational workflows around inventory and customer-facing store activity.

## Expected Capabilities

* Store transfers
* Cycle counts
* Physical inventory
* Buybacks
* Consignment
* Damaged inventory
* Internal notes/tasks

Phase 7A delivered customer requests, special orders, holds, and reservations. Phase 7B delivers customer credit. Remaining Phase 7 items include transfers, counts, buybacks, and consignment.

## Possible Tables

```text
inventory_transfers
inventory_transfer_lines
cycle_counts
cycle_count_lines
buybacks
consignment_accounts
```

(Phase 7A and 7B tables are documented in their phase data models.)

## Major Risks

* Workflow complexity
* State transitions
* Inventory reservation behavior
* Partial fulfillment
* Buyback pricing rules
* Consignment liability tracking

---

# Phase 8: Inventory Eligibility and Tracking Refactor

## Purpose

Phase 8 centralizes whether a product variant participates in the stock ledger.

Legacy gate: `inventory_behavior == "standard_physical"`. Phase 8 introduces `Inventory::TrackingResolver` (`inventory` / `non_inventory`) and `Inventory::Eligibility` as the mutation gate.

## Status

Phase 8-1 and 8-2 are **complete** (2026-06-23). Slices 8-3 (schema defaults), 8-4 (UI), and 8-5 (COGS/margin) are deferred.

## Detailed Documents

* [roadmap/phase-8-inventory-eligibility-and-tracking-refactor.md](roadmap/phase-8-inventory-eligibility-and-tracking-refactor.md)
* [specifications/phase-8-inventory-eligibility-and-tracking-spec.md](specifications/phase-8-inventory-eligibility-and-tracking-spec.md)
* [specifications/phase-8-test-plan.md](specifications/phase-8-test-plan.md)
* [implementation/phase-8-1-8-2-completion.md](implementation/phase-8-1-8-2-completion.md)

---

# Phase 8.5-1: POS Discount Model & Calculation

## Purpose

Phase 8.5-1 makes POS discounts structured, auditable, stackable, and report-ready before Phase 9 reporting. It introduces discount reasons, application and allocation records, stacking, non-discountable eligibility, and gift card sale protection while preserving existing cached discount cents fields.

## Status

**In review** (target completion after branch merge). See [implementation/phase-8.5-1-completion.md](implementation/phase-8.5-1-completion.md).

## Detailed Documents

* [roadmap/phase-8.5-1-pos-discount-model.md](roadmap/phase-8.5-1-pos-discount-model.md)
* [specifications/phase-8.5-1-pos-discount-spec.md](specifications/phase-8.5-1-pos-discount-spec.md)
* [specifications/phase-8.5-1-data-model.md](specifications/phase-8.5-1-data-model.md)
* [specifications/phase-8.5-1-test-plan.md](specifications/phase-8.5-1-test-plan.md)

Related operational context: [roadmap/phase-8.5-operational-cleanup.md](roadmap/phase-8.5-operational-cleanup.md)

---

# Phase 9: Reporting and Accounting

## Purpose

Phase 9 gives ShelfStack reliable operational visibility. Phase 9a and 9b are **complete**. Phase 9c (accounting-grade financial postings) is **deferred**; see [Phase 10](roadmap/Phase-x10-comprehensive-ux-expansion.md) for the next active priority.

## Sub-Phases

| Sub-phase | Focus | Status |
| --------- | ----- | ------ |
| **9a** | Report-facing UX standards, formatting, and reporting semantics | Complete |
| **9b** | Operational reports — daily reconciliation and management reports | Complete |
| **9c** | GL-shaped financial posting layer — balanced entries, mappings, export-ready journals | **Deferred** |

See [roadmap/phase-9-reporting-and-accounting.md](roadmap/phase-9-reporting-and-accounting.md).

## Expected Capabilities

* Shared report view contract and formatting (9a)
* Sales, tax, discount, cash, buyback, inventory, purchasing, stored value, and customer-request reports (9b)
* Operational margin and liability reports (9b)
* Simple print and CSV export for operational reports (9b)
* Balanced financial postings from operational events (9c — **deferred**)
* Accounting mappings and export-ready journal summaries (9c — **deferred**)
* GL/accounting export to external systems (9c — **deferred**)

Deferred to Phase 10 or later: comprehensive POS/items/modal/drawer UX; advanced dashboards; scheduled reports; full chart-of-accounts administration. Phase 9c financial layer also deferred.

## Expected Design Direction

Reports should prefer immutable transaction snapshots and ledger entries rather than mutable setup records.

Departments, subdepartments, tax rates, and product names should be snapshot where needed in transaction history.

Operational reports (9b) use POS and ledger sources. Financial reports and GL export require Phase 9c posted entries when that sub-phase is resumed.

## Current priority

Phase 9a and 9b are complete. Phase 9c is deferred. **Phase 10-D** is the next active roadmap priority (10-C complete 2026-06-26).

### Phase 10 sub-phases

Delivery order: **10-A → 10-B → 10-C → 10-D → 10-E**. Phase 10 is complete when all sub-phases are done.

| Sub-phase | Document |
| --------- | -------- |
| 10-A Interaction infrastructure | [phase-10a-interaction-infrastructure.md](roadmap/phase-10a-interaction-infrastructure.md) |
| 10-B Item cockpit completion | [phase-10b-item-cockpit-completion.md](roadmap/phase-10b-item-cockpit-completion.md) |
| 10-C POS keyboard workspace | [phase-10c-pos-keyboard-workspace.md](roadmap/phase-10c-pos-keyboard-workspace.md) — **Complete** |
| 10-C slice 9A (transaction discount modal) | [phase-10c-9a-transaction-discount-modal.md](roadmap/phase-10c-9a-transaction-discount-modal.md) |
| 10-C slice 9B (tender/completion) | [phase-10c-9b-tender-workspace-and-completion.md](roadmap/phase-10c-9b-tender-workspace-and-completion.md) |
| 10-D / 10-E | [Phase-x10-comprehensive-ux-expansion.md](roadmap/Phase-x10-comprehensive-ux-expansion.md) |

Visual mockups: [docs/samples/phase-10-mockups/](samples/phase-10-mockups/)

## Detailed Documents

Phase 9:

```text
docs/roadmap/phase-9-reporting-and-accounting.md
docs/roadmap/phase-9a-ux-foundation-for-reporting.md
docs/roadmap/phase-9b-reports.md
docs/roadmap/phase-9c-gl-shaped-financial-layer.md
```

Phase 10:

```text
docs/roadmap/Phase-x10-comprehensive-ux-expansion.md
docs/roadmap/phase-10a-interaction-infrastructure.md
docs/roadmap/phase-10b-item-cockpit-completion.md
docs/roadmap/phase-10c-pos-keyboard-workspace.md
docs/roadmap/phase-10c-9a-transaction-discount-modal.md
docs/roadmap/phase-10c-9b-tender-workspace-and-completion.md
docs/specifications/phase-10c-pos-keyboard-workspace-spec.md
docs/specifications/phase-10c-test-plan.md
docs/specifications/pos-keyboard-workspace.md
docs/samples/phase-10-mockups/
```

## Major Risks

* Historical accuracy
* Reconciliation between operational and financial totals
* Tax reporting
* Inventory valuation
* Cost methodology
* Performance on large datasets
* Posting rule errors creating misleading financial entries

---

---

# Roadmap Principles

## 1. Build foundations before workflows

Each phase should create the stable setup and data structure required by later workflows.

## 2. Keep historical data stable

Future transaction and inventory records should snapshot mutable setup data.

## 3. Prefer append-only ledgers for financial/stock movement

Inventory and audit history should not be silently overwritten.

## 4. Keep UI practical

ShelfStack should support detailed metadata without making routine store operations slow.

## 5. Defer complexity until required

Do not normalize every metadata concept too early. Use JSONB where it provides useful flexibility, then normalize later when workflows justify it.

---

# Current Priority

Phases 1–10-E are complete on integration branch **`v0.04-14/ux-migration`**. See implementation records under `docs/implementation/`.

```text
v0.04-14 release (merge to main) → v0.04-13 demand-to-fulfillment continuity
```

**Active work:** Release [v0.04-14](implementation/v0.04-14-completion.md) to `main`, then resume [v0.04-13](v0.04/v0.04-13-demand-to-fulfillment-continuity/spec.md). [v0.04 delivery roadmap](roadmap/v0.04-delivery-roadmap.md).

Phase 9c GL-shaped financial layer remains deferred.

Implementation records:

- [docs/implementation/phase-1-completion.md](implementation/phase-1-completion.md) through [phase-10c-completion.md](implementation/phase-10c-completion.md)
- [docs/implementation/v0.04-14-completion.md](implementation/v0.04-14-completion.md) · [phase-10e-completion.md](implementation/phase-10e-completion.md)
- [docs/implementation/phase-10a-completion.md](implementation/phase-10a-completion.md), [phase-10b-completion.md](implementation/phase-10b-completion.md), [phase-10c-completion.md](implementation/phase-10c-completion.md)
- Phase 8.5 slice records: `docs/implementation/phase-8.5-*-completion.md`
