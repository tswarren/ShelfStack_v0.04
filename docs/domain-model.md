# ShelfStack Domain Model

## Purpose

This document explains the major business concepts in ShelfStack and how they relate to each other.

It is intended to help developers, contributors, and future maintainers understand the product domain before reading the detailed data model and phase specifications.

> **v0.04 canonical model (active).** Descriptive metadata lives on **`Product`** (`product_identifiers`). **`ProductVariant`** is the operational grain for inventory, POS, purchasing, receiving, demand, and fulfillment. Customer need is captured as **`DemandLine`** with supply claims via **`DemandAllocation`**. The canonical chain is documented in [VERSION_0.04.md](design/VERSION_0.04.md) and milestone specs under [docs/v0.04/](v0.04/README.md).

---

# 1. Foundation Domain

The foundation domain establishes who is using ShelfStack, where they are working, and what they are allowed to do.

## Core Concepts

| Concept                | Meaning                                                         |
| ---------------------- | --------------------------------------------------------------- |
| User                   | Application user or system actor.                               |
| Role                   | Named bundle of permissions.                                    |
| Permission             | Specific application capability.                                |
| Role Assignment        | Assignment of a role to a user, globally or within a store.     |
| Store                  | Physical store/location using ShelfStack.                       |
| Workstation            | Store-level computer/register/service desk/back-office station. |
| Workstation Assignment | Browser-to-workstation assignment using a secure token.         |
| User Session           | Persisted login/session lifecycle record.                       |
| Audit Event            | Append-only record of significant application activity.         |

## Key Relationships

```text
User → User Role Assignment → Role → Role Permission → Permission
Store → Workstation → Workstation Assignment
User → User Session
Audit Event → Actor/User + Auditable Record + Context
```

## Important Rules

* Users receive permissions through roles.
* Role assignments may be global or store-scoped.
* Store-scoped assignments apply only in the matching store context.
* Workstation context is resolved server-side from a browser assignment token.
* Audit events record security, setup, and system activity.

---

# 2. Classification and Tax Domain

The classification domain defines how sellable items are grouped for reporting, operational defaults, shelving/topic organization, and taxation.

## Core Concepts

| Concept | Meaning |
| --- | --- |
| Department | Top-level sales/reporting bucket with GL account code. |
| SubDepartment | Operational merchandise behavior bucket (pricing model, margin, supplier discount, tax category, returnability). Required on every product variant. |
| Category Scheme | Named topical classification system (for example, `store_categories`, BISAC). |
| Category Node | A node within a category scheme hierarchy (for example, Fiction, Biography). Store categories are **not** the merchandise behavior bucket. |
| Display Location | Store-facing shelf/signage location; distinct from inventory locations. |
| Tax Category | Global taxability classification for items. |
| Store Tax Rate | Store-specific tax rate. |
| Store Tax Category Rate | Effective-dated mapping of store + tax category to store tax rate. |

## Key Relationships

```text
Department → SubDepartment
SubDepartment → Default Tax Category
Product → Store Category (CategoryNode in store_categories scheme, optional)
Product Variant → SubDepartment (required)
Store → Store Tax Rate
Store + Tax Category + Date → Store Tax Category Rate → Store Tax Rate
```

## Important Rules

* Departments and subdepartments are global across the ShelfStack instance.
* Subdepartments provide operational defaults for product variants (pricing model, margin target, supplier discount, tax category).
* Store category nodes classify catalog topics and may suggest defaults on catalog-linked items; they are not required on every variant.
* Tax categories do not directly define rates.
* Tax rates belong to stores.
* Store tax category rates define which rate applies to each tax category at each store during a date range.
* For a given store, tax category, and date, tax lookup must return exactly one applicable rate.

Default resolution order for operational defaults:

```text
variant override → variant.sub_department → product defaults → store category defaults (catalog path)
```

GL posting:

```text
variant.sub_department → department.gl_account_code
```

Reference data loads from CSV (`db/seeds/data/*.csv`) via `Seeds::CsvClassificationImporter`. Validate with `rails shelfstack:seeds:validate`. See [implementation/csv-seeds.md](implementation/csv-seeds.md) and [specifications/classification-target-spec.md](specifications/classification-target-spec.md).

### Historical note

Phase 2 originally introduced a `categories` table combining merchandise behavior and topic classification. That table was **removed** in the 2025-06 classification simplification. Operational defaults now live on `sub_departments`; topic trees use `category_schemes` / `category_nodes`. See [implementation/classification-cleanup.md](implementation/classification-cleanup.md).

---

# 3. Product and Identifiers Domain (v0.04)

The product domain describes the commercial item and its external identifiers. v0.04-1 fused v0.03 catalog metadata onto **`products`**; **`product_identifiers`** is the canonical identifier table (v0.04-2).

## Core Concepts

| Concept | Meaning |
| --- | --- |
| Format | Controlled format record (hardcover, paperback, DVD, etc.). |
| Product | Specific commercial item — book edition, media release, sideline, service, etc. |
| Product Identifier | ISBN, UPC, GTIN, house identifier, or freeform identifier on `product_identifiers`. |
| Product Group | Optional non-operational grouping (`product_groups`; deferred UI in v0.04-3). |
| Creator / Subject Details | Structured JSONB metadata on the product where applicable. |

## Retained temporary: legacy catalog admin

`catalog_items` and related bibliographic admin routes remain for external lookup, ISBNdb import, and buyback intake. They are **not** the canonical v0.04 domain model. New item work uses **`Product`** + **`product_identifiers`**. See [v0.04-11 audit log](v0.04/v0.04-11-documentation-schema-cleanup/data-model.md).

## Key Relationships

```text
Product → Format
Product → Product Identifier(s)
Product → Product Variant(s)
Optional Product Group → Product
```

## Important Rules

* Every product should have at least one active identifier (v0.04-2 validation families: `gtin`, `isbn`, `freeform`, `house`).
* ISBN-10 entry converts to ISBN-13 primary where applicable.
* House EAN-13 (prefix 200–229) is a **product identifier**, not a variant SKU.
* Variant SKUs are **system-assigned** at variant creation (segment `211`), not derived from product identifiers.
* `product_type` controls metadata fields shown in UI.

---

# 4. Product Variant Domain

Product variants are the **operational grain** for POS, inventory, purchasing, receiving, demand, allocations, buyback, and fulfillment.

## Core Concepts

| Concept | Meaning |
| --- | --- |
| Product | Descriptive commercial item (see §3). |
| Product Variant | Sellable SKU with price, condition, classification, and operational flags. |
| Product Condition | New, signed, used, remainder, or special condition. |
| Display Location | Merchandising/display placement. |
| Store Display Location | Store-specific activation of a display location. |
| Vendor | Supplier or source organization. |

## Key Relationships

```text
Product → Product Variant
Product Variant → SubDepartment (required)
Product Variant → Product Condition
Product Variant → Display Location
Product → Default Display Location
Store → Store Display Location → Display Location
```

## Important Rules

* **ProductVariant** is the grain for inventory balances, PO lines, receipt lines, POS lines, and demand.
* Variant SKU is required, unique, and system-assigned (v0.04-2).
* A product is not sellable until it has at least one active variant.
* Used variants follow v0.04-5 operational policy (customer-reservable, not vendor-orderable).
* Variant names may be generated from product name plus condition/attributes and may be overridden.
* `ProductVariants::OperationalPolicy` gates vendor orderability and used-wanted demand.

---

# 5. Inventory Domain (Phase 4)

Phase 4 implements store-level inventory at the product variant grain.

## Core Concepts

| Concept | Meaning |
| --- | --- |
| Inventory Posting | Atomic posted inventory event grouping one or more ledger entries. |
| Inventory Ledger Entry | Append-only quantity and value effect for one store + variant within a posting. |
| Inventory Balance | Cached quantity and estimated value for one store + variant. |
| Inventory Adjustment | User-facing draft workflow that posts opening inventory or manual corrections. |
| Inventory Location | Optional store context on ledger lines; not an authoritative balance grain in Phase 4. |
| Inventory Value | Management cost and retail snapshots on ledger entries and balances. |

## Authoritative Grain

```text
store_id + product_variant_id
```

Product-level, department-level, and enterprise quantities are rollups from variant/store balances.

## Eligibility

Only **inventory-eligible** product variants receive ledger entries in Phase 4.

Implementation: `Inventory::Eligibility` / `Inventory::TrackingResolver` (`inventory` / `non_inventory`). Legacy stored value:

```text
inventory_behavior = standard_physical
```

## Design Direction

```text
Product Variant → Inventory Posting → Inventory Ledger Entries → Inventory Balance
```

Posted ledger entries are immutable. Balances update only through `Inventory::Post` (and rebuild tooling).

Phase 4 defers POS, transfers, holds, location balances, and full accounting beyond moving-average receipt cost.

---

# 6. Purchasing Domain (Phase 5 + v0.04)

Purchasing operates at **product variant** grain: vendor sourcing, purchase orders, receiving, and returns to vendor. Store demand for replenishment flows through **demand lines** and **sourcing** (v0.04-6–8), not legacy purchase-request tables.

## Core Concepts

| Concept | Meaning |
| --- | --- |
| Product Vendor | Product-level vendor sourcing defaults (item number, discount, returnability). |
| Product Variant Vendor | Variant-level vendor overrides; highest precedence for returnability. |
| DemandLine (manual TBO) | Buyer/store replenishment intent with `capture_intent = manual_tbo`; does not post inventory. |
| SourcingRun / VendorResponse | Vendor inquiry and confirmed availability (v0.04-8). |
| Purchase Order | Committed order to a vendor with line snapshots at submit time. |
| Receipt | Posted receiving document; only `quantity_accepted` posts to inventory. |
| Return to Vendor (RTV) | Posted vendor return; negative quantity via inventory ledger. |
| Moving Average Cost | `inventory_balances.moving_average_unit_cost_cents` updated on receive. |

## Returnability Precedence

```text
product_variant_vendors → product_vendors → product_variants.returnability_status
```

## Design Direction

```text
DemandLine (manual_tbo / buyer_replenishment)
  → SourcingRun / VendorResponse
  → PurchaseOrder
  → Receipt
  → Inventory::Post (receiving)
Return to Vendor → Inventory::Post (vendor_return)
```

Purchasing documents are sources; inventory changes only through `Inventory::Post`. Legacy `purchase_requests` tables were removed in v0.04-10.

---

# 7. POS Domain (Phase 6)

Phase 6 implements point-of-sale using `pos_*` tables. Inventory changes only through `Inventory::Post`.

## Core Concepts

| Concept              | Meaning                                              |
| -------------------- | ---------------------------------------------------- |
| Register Session     | Drawer/register period on a workstation (`business_date`). |
| POS Transaction      | Sale, return, or exchange document (`pos_transactions`). |
| Transaction Line     | Variant or open-ring line with signed quantity.      |
| Tender               | Payment or refund row (`pos_tenders`).               |
| Receipt              | Customer-facing document (`pos_receipts`).          |
| Void                 | Reversal of a completed transaction (`pos_voids`).   |
| Authorization        | Supervisor override record (`pos_authorizations`).   |

## Transaction Types

`transaction_type` is stored on the header and derived at completion from signed merchandise lines (`variant`, `open_ring`):

* all positive → `sale`
* all negative → `return`
* mixed → `exchange`

## Inventory Posting

Completed transaction:

```text
inventory_postings.posting_type = pos_transaction
inventory_postings.source = PosTransaction
inventory_ledger_entries.movement_type = sold | customer_return
```

Completed void:

```text
inventory_postings.posting_type = pos_void
inventory_postings.source = PosVoid
(reversal_of_posting_id links to original transaction posting)
```

Only `standard_physical` lines with `product_variant_id` post. Open-ring lines without a variant do not post.

Do not store `inventory_posting_id` on `pos_transactions`.

## Snapshotting

POS lines snapshot SKU, name, price, tax category, tax rate, and classification context at completion so later catalog or tax setup changes do not rewrite history.

## Discount Model (Phase 8.5-1)

Phase 8.5-1 adds structured discount records while preserving cached aggregate fields:

| Concept | Meaning |
| --- | --- |
| Discount Reason | Admin-maintained reason code (`discount_reasons`) |
| Discount Application | One discount action with scope, method, reason, and stack order |
| Discount Allocation | Line-level allocation with classification snapshots for reporting |

Services:

```text
Pos::DiscountEligibilityResolver
Pos::DiscountRecalculator
Pos::DiscountApplicationService
Pos::VoidDiscountApplication
```

Cached fields remain report-stable:

```text
pos_transactions.discount_cents
pos_transaction_lines.line_discount_cents
pos_transaction_lines.transaction_discount_cents
```

## Tax Exception Model (Phase 8.5-2)

Phase 8.5-2 adds structured tax exception records while preserving cached tax totals:

| Concept | Meaning |
| --- | --- |
| Tax Exception Reason | Admin-maintainable reason (`tax_exception_reasons`) |
| Transaction Tax Exemption | One active exemption per transaction (`pos_tax_exemptions`) |
| Line Tax Override | One active override per line (`pos_line_tax_overrides`) |
| Normal Tax Snapshot | Expected tax before exceptions on each line |
| Applied Tax Source | Why final tax differs (`applied_tax_source`) |

Services:

```text
Pos::TaxRecalculator
Pos::TaxExceptionApplicationService
Pos::VoidTaxException
```

Cached fields:

```text
pos_transactions.tax_cents
pos_transactions.normal_tax_cents
pos_transaction_lines.tax_cents
pos_transaction_lines.normal_tax_cents
```

## Related Documents

```text
docs/roadmap/phase-6-pos-foundation.md
docs/specifications/phase-6-pos-foundation-spec.md
docs/specifications/phase-6-data-model.md
```

---

# 8. Demand and Allocation Domain (v0.04)

v0.04-6 through v0.04-10 replaced v0.03 customer requests, special orders, purchase requests, and inventory reservations with a unified demand model.

| Concept | Description |
| --- | --- |
| Customer | Lightweight customer profile (`customers`). |
| DemandLine | Store-scoped need/intent at variant grain (`demand_lines`). Capture intents include hold, notify, special_order, used_wanted, manual_tbo, buyer_replenishment, research. |
| DemandAllocation | Claim on supply: on-hand, inbound PO, or vendor backorder (`demand_allocations`). Does **not** post inventory. |
| SourcingRun | Vendor inquiry workflow linked from replenishment demand (v0.04-8). |
| POS Pickup | Fulfillment of active on-hand allocation via normal POS sale + `CompleteDemandAllocationFulfillment`. |

## Important Rules

* **Demand does not mutate on-hand inventory.** Only `Inventory::Post` changes authoritative stock.
* **Allocations do not post inventory.** They point demand at supply (on-hand or inbound).
* Notify intent surfaces in staff queues on stock arrival; holds are staff-created allocations.
* Used-wanted demand is customer-reservable and does not auto-create new-item PO lines (v0.04-5).
* Receipt posts only `quantity_accepted`; demand conversion happens through allocation services, not legacy receipt-line allocation tables.

Availability:

```text
quantity_available = quantity_on_hand - quantity_reserved
```

`quantity_reserved` is cached from active on-hand demand allocations.

Staff workspace: `/demand` with queue filters (`DemandLines::QueueScope`).

## Retired v0.03 (do not reintroduce)

`customer_requests`, `special_orders`, `purchase_requests`, `inventory_reservations`, `purchase_order_line_allocations`, `receipt_line_allocations` — removed v0.04-10. See [v0.04-10 completion](implementation/v0.04-10-completion.md).

## Related Documents

```text
docs/v0.04/v0.04-6-demand-foundation/spec.md
docs/v0.04/v0.04-7-allocations-and-reservations/spec.md
docs/v0.04/v0.04-10-retire-v0.03-ordering-ui/spec.md
docs/specifications/phase-7a-customer-demand-spec.md  (historical v0.03 reference)
```

---

# 10. Stored Value / Customer Credit (Phase 7B)

Phase 7B introduces a canonical stored-value ledger replacing earlier separate gift-card/account designs.

| Concept | Description |
| --- | --- |
| Stored Value Account | Liability account by type (`gift_card`, `store_credit`, `trade_credit`, etc.). |
| Stored Value Identifier | Redemption token (masked display; full reveal audited where required). |
| Ledger Entry | Append-only balance movement; voids reverse via `reverses_entry_id`. |
| POS Settlement | Multi-row tenders; cash drawer math on `amount_cents`. |
| Gift Card Sale Line | POS line type issuing balance at completion (not a tender). |

POS redemption saves `min(amount entered, balance)` on tender rows. Manual issue/adjust/transfer/void require reason codes and audit events in admin UI.

## Related Documents

```text
docs/roadmap/phase-7b-customer-credit-foundation.md
docs/specifications/phase-7b-stored-value-spec.md
docs/specifications/phase-7b-data-model.md
```

---

# 11. Used Buyback (Phase 7C)

Staged buyback workflow: intake → pricing/proposal → customer decision → payout → completion.

| Concept | Description |
| --- | --- |
| Buyback Session | Workstation-scoped session with single payout mode (cash, trade_credit, or no_value_donation). |
| Buyback Line | Resolved catalog item with proposed/accepted offer and outcome. |
| Graded Used Variant | Created at pricing when needed; inventory posts at completion. |
| Trade Credit | Issued to stored-value account with identifier for POS redemption. |

Completion posts `used_buyback` inventory; void reverses via `buyback_void`. No cash/inventory posting before `CompleteSession`.

## Related Documents

```text
docs/roadmap/phase-7c-used-buyback.md
docs/specifications/phase-7c-used-buyback-spec.md
docs/specifications/phase-7c-data-model.md
```

---

# 12. Inventory Tracking (Phase 8)

Phase 8 centralizes inventory vs non-inventory behavior.

| Concept | Description |
| --- | --- |
| Inventory Tracking | Resolved value: inventory-eligible vs non-inventory (`Inventory::TrackingResolver`). |
| Override | Variant `inventory_tracking_override` wins over product default and legacy `inventory_behavior`. |
| Eligibility Gate | `Inventory::Eligibility` is the mutation gate for posting and POS lines. |
| POS Snapshot | `inventory_tracking_snapshot` on lines at completion. |

Legacy `inventory_behavior` column remains; `standard_physical` maps to inventory tracking.

## Related Documents

```text
docs/roadmap/phase-8-inventory-eligibility-and-tracking-refactor.md
docs/specifications/phase-8-inventory-eligibility-and-tracking-spec.md
```

---

# 13. External Catalog Lookup (Phase 6.5)

ISBNdb local-first bibliographic lookup integrated with Add Item wizard: candidate preview, controlled import, no silent catalog mutation without staff confirmation.

## Related Documents

```text
docs/implementation/phase-6.5-completion.md
```

---

# 14. Operational Reporting (Phase 9a / 9b)

Phase 9a defines report UX semantics, formatting, and view contracts. Phase 9b implements operational reports at `/reports` (canonical hub). POS `/reports` command navigates here with confirm when an active draft exists (10-C).

Reports read operational snapshots and ledgers — not GL postings (Phase 9c deferred).

## Related Documents

```text
docs/roadmap/phase-9-reporting-and-accounting.md
docs/specifications/phase-9b-operational-reports-spec.md
docs/implementation/phase-9a-completion.md
docs/implementation/phase-9b-completion.md
```

---

# 15. Interaction / UX Domain (Phase 10)

Phase 10 establishes app-wide interaction patterns without changing core domain rules.

| Concept | Description |
| --- | --- |
| Modal Shell | Bounded decisions; focus trap; dirty guard; Turbo `modal` target. |
| Drawer Shell | Contextual detail (demand, variant ops, return/pickup in 10-C). |
| Expanded Row | Inline line edits (cart, PO lines). |
| View Contract | Per-screen first focus and primary action ([view-contracts.md](specifications/view-contracts.md)). |
| POS Command Workspace | Idle/active shell, two-lane parser, `Pos::CommandRegistry` (10-C). |

Phase 10-A/10-B complete; 10-C in progress. Function keys out of scope for 10-C completion.

## Related Documents

```text
docs/roadmap/Phase-x10-comprehensive-ux-expansion.md
docs/specifications/phase-10a-interaction-infrastructure-spec.md
docs/specifications/phase-10c-pos-keyboard-workspace-spec.md
docs/specifications/view-contracts.md
docs/specifications/keyboard-and-focus.md
```

---

# 16. Conceptual Flow (v0.04)

ShelfStack’s canonical operational flow:

```text
Foundation (users, stores, workstations, permissions)
  ↓
Departments / Subdepartments / Taxes
  ↓
Product (+ product_identifiers)
  ↓
Product Variant  ← operational grain
  ↓
DemandLine → DemandAllocation → Sourcing → PO / Receipt
  ↓
Inventory::Post (sole authoritative stock mutation)
  ↓
POS sale / pickup fulfillment / buyback / stored value
  ↓
Operational Reporting (/reports)
  ↓
Interaction system (Phase 10)
  ↓
Deferred: GL / financial export (Phase 9c)
```

Legacy `catalog_items` admin may exist for bibliographic import and buyback intake but is not part of this chain.
