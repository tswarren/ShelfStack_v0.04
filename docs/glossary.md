# ShelfStack Glossary

## Purpose

This glossary defines recurring ShelfStack terms.

It is intended to keep documentation, code, UI labels, and developer conversation consistent.

---

# A

## Active

A record with `active = true`. Active records may be used for new activity unless other rules prevent it. Inactive records remain visible for history but cannot be selected for new setup or business activity.

---

## Active Draft

The single in-progress POS transaction (`status: draft`) for the current register session, workstation, and cashier. Phase 10-C: `/pos` always returns to the active draft until complete, cancel, hold, or void. See [phase-10c-pos-keyboard-workspace-spec.md](specifications/phase-10c-pos-keyboard-workspace-spec.md).

---

## Audit Event

An append-only record of significant application activity.

Audit events may record security, session, setup, catalog, inventory, POS, stored-value, and buyback events.

---

## Actor

The user or system account that performed an action.

Stored on audit events as `actor_user_id`.

---

# B

## Buyer Replenishment

A **[capture intent](#capture-intent)** on **`DemandLine`** (`buyer_replenishment`) for buyer-driven shelf or frontlist replenishment. Vendor-orderable variants only. May flow into **sourcing** and purchase orders; does not post inventory by itself.

---

## Buyback Session

Staged used-buyback workflow document (intake through completion) with workstation-scoped buyback number, single payout mode, and inventory posting at completion only.

---

## Basis Points

Integer representation of a percentage.

Used for tax rates, margins, discounts, and price factors.

Examples:

| Percent | Basis Points |
| ------: | -----------: |
|   6.00% |        `600` |
|  40.00% |       `4000` |
| 100.00% |      `10000` |

---

## Browser Workstation Assignment

A durable token-based assignment linking a browser to a workstation.

The browser stores the raw token.
The database stores only a token digest.

Preferred table name:

```text
workstation_assignments
```

---

# C

## Cash Drop

Drawer-to-safe cash movement. **Planned/disabled** in Phase 10-C until `cash_drop` movement type exists on `PosCashMovement` (only `paid_in` / `paid_out` today).

---

## Cash Movement

Register-session cash drawer event: `paid_in` or `paid_out` via `/cashin` and `/cashout` commands (Phase 10-C).

---

## Command Alias

Short token that normalizes to a canonical slash command (for example `/ld` → line discount). Aliases must be unique across the full `Pos::CommandRegistry` (Phase 10-C).

---

## Command Registry

Ruby-side registry (`Pos::CommandRegistry`) defining canonical POS commands, aliases, permissions, valid states, and handler targets. Authoritative for command routing — not Stimulus-only logic.

---

## Capture Intent

Controlled field on **`DemandLine`** describing why the line was captured. Valid values:

```text
hold              — reserve on-hand stock for a customer
notify            — alert staff when stock arrives (no auto-hold)
special_order     — customer-backed order for a variant
used_wanted       — customer wants a used copy (not vendor-orderable)
manual_tbo        — staff/buyer manual replenishment (To Be Ordered)
buyer_replenishment — buyer-driven shelf/frontlist replenishment
research          — provisional lookup before variant match
```

Use these as **intent labels**, not legacy table names. Staff workspace: `/demand`.

---

## Catalog Item (retained temporary — legacy admin)

Legacy bibliographic metadata record in `catalog_items`. **Not the canonical v0.04 model** — use **`Product`** + **`product_identifiers`** for new work. Retained for external lookup, ISBNdb import, buyback intake, and admin CRUD until a future catalog cleanup milestone. See [v0.04-11 audit log](v0.04/v0.04-11-documentation-schema-cleanup/data-model.md).

---

## Customer

A lightweight store customer profile used for requests, holds, special orders, and pickup contact history.

---

## Customer Pickup

POS fulfillment of an active on-hand **`DemandAllocation`**. Phase 10-C uses a drawer workflow; completed sale lines carry `demand_allocation_id` and fulfillment runs via `Pos::CompleteDemandAllocationFulfillment` after normal inventory posting.

---

## Catalog Item Identifier (retained temporary — legacy admin)

An identifier on a legacy **`catalog_items`** record. **Superseded by [Product Identifier](#product-identifier)** on `product_identifiers` for v0.04 work. Retained for bibliographic admin, external lookup, and import paths only.

Examples: ISBN-10, ISBN-13, EAN, UPC, GTIN, publisher number, local identifier.

---

## Catalog Item Type

Controlled field describing the kind of catalog item.

Examples:

```text
book
calendar
periodical
recorded_music
sideline
videorecording
audiobook
ebook
map
game
gift
other
```

Catalog item type controls UI field display, not hard database validity.

---

## Category

**Deprecated / historical.** Phase 2 introduced a `categories` table for product-level classification linked to a department. That table was **removed** in the 2025-06 classification simplification.

Operational merchandise defaults now live on **SubDepartment**. Topic/shelving classification uses **Category Node** records in the `store_categories` scheme.

See [implementation/classification-cleanup.md](implementation/classification-cleanup.md).

---

## Merchandise Class

**Deprecated.** Renamed to **SubDepartment** during the classification target migration. Do not use this term for new work.

---

## Category Scheme

Named topical classification system (for example, `store_categories` for store shelving/topics, or BISAC for subject headings).

Category schemes organize **topic** trees. They are not the operational merchandise behavior bucket — that is **SubDepartment**.

---

## Category Node

A node within a category scheme hierarchy (for example, Fiction, Biography).

Store category nodes classify catalog topics and may suggest defaults on catalog-linked items. They are **not** required on every product variant and are **not** the same as subdepartments.

---

## Categorization

Assignment of a catalog item, product, or product variant to a category node.

---

## Accounting Mapping

**Removed (2025-06).** Former configurable rules mapping merchandise class, condition, and topic to GL accounts.

GL posting now uses:

```text
variant.sub_department → department.gl_account_code
```

See [implementation/classification-cleanup.md](implementation/classification-cleanup.md).

---

## Condition

See **Product Condition**.

---

## Current Context

Request-scoped application context.

Expected values:

```text
Current.user
Current.store
Current.workstation
Current.user_session
Current.workstation_assignment
Current.time_zone
```

---

# D

## Demand Allocation

A claim linking a **`DemandLine`** to supply at variant grain (`demand_allocations`). Allocations do **not** post inventory — only **`Inventory::Post`** mutates on-hand quantity.

**Allocation kinds:**

```text
on_hand                 — claims current store stock (hold)
inbound_purchase_order  — claims expected inbound PO quantity
vendor_backorder        — claims vendor-confirmed backorder quantity
```

Active on-hand allocations reduce `quantity_available`. **Fulfillment** completes through POS pickup or `DemandAllocations::Fulfill`.

---

## Demand Line

Store-scoped customer or buyer need at **product variant** grain (`demand_lines`). See **[Capture Intent](#capture-intent)** for intent values. Staff workspace: `/demand`.

Demand records need; it does not change on-hand inventory until receiving or POS posts stock.

---

## Department

Top-level operational merchandise and reporting bucket (Phase 2). Departments carry GL account codes and, after Phase 8.5-1, a `discountable` flag.

Department numbers are fixed-width, zero-padded strings such as `001`, `010`, and `100`. Used for POS reporting, department summaries, and GL-shaped export (Phase 9c deferred).

## Discount Application

A single discount action on a POS transaction (`pos_discount_applications`). Each application has a required reason, scope (`line` or `transaction`), method, stack order, and applying user.

## Discount Allocation

The line-level impact of a discount application (`pos_discount_allocations`). Used for department, SKU, and reason reporting without relying on live catalog joins.

## Discount Reason

Seedable/admin-maintainable reason code required for every POS discount application (`discount_reasons`).

## Discountable

Catalog or system flag indicating whether a POS line may receive discounts. Phase 8.5-1 uses strictest-wins precedence across department, subdepartment, product, and variant; gift card sale lines are always non-discountable.

## Display Location

A merchandising or shelving location.

Examples:

* Front Table
* New Releases
* Fiction
* Children’s
* Register Counter

Display locations are not inventory locations and do not represent stock balances.

---

# F

## Format

Controlled record describing the format of a catalog item.

Examples:

* Hardcover
* Trade Paperback
* Mass Market Paperback
* Calendar
* DVD
* Compact Disc
* eBook

---

## Fulfillment

Completing an active **`DemandAllocation`** so the linked **`DemandLine`** moves toward `fulfilled` status. Customer-facing path: normal POS sale with `demand_allocation_id` on the line, then `Pos::CompleteDemandAllocationFulfillment`. Does not replace **`Inventory::Post`** — sale posting and fulfillment are separate steps.

---

## `from_tbo` (deprecated compatibility)

Legacy query/route parameter retained for return-path compatibility. Must **not** open the removed v0.03 PO TBO builder. Lands on manual TBO / **`DemandLine`** / sourcing flows. Future rename to demand-native params deferred.

---

# G

## Gift Card Issue / Reload

POS `gift_card_sale` line (not a tender) that issues stored-value balance at completion via `/giftcard` or `/gc`. Phase 10-C: `/gc` with amount adds the line immediately; without amount opens the amount panel (focus there; submit adds line and returns to command).

---

## Gift Card Redemption

Applying stored-value gift card balance as a POS tender via `/giftredeem` or `/gr` (distinct from gift card sale line).

---

## Global Role Assignment

A role assignment that applies across all stores.

---

## Hold

A **[capture intent](#capture-intent)** on **`DemandLine`** (`hold`) paired with an on-hand **`DemandAllocation`**. Reserves available stock for a customer until expiry, release, or fulfillment.

---

## House Identifier

A **product identifier** using ShelfStack's internal EAN-13 segment (prefix **200–229** on `product_identifiers` with `identifier_family = house`). Assigned sequentially — not derived from variant SKU. Distinct from variant SKUs (segment **211**).

---

# I

## Idle POS Workspace

POS landing state when register is open and no active draft exists. Command field is home base; no silent draft creation (Phase 10-C).

---

## Inventory Reservation

**Retired v0.03.** Replaced by **`DemandAllocation`** (on-hand and inbound kinds). Do not use `inventory_reservations` — table removed v0.04-10.

---

## Identifier Normalization

The process of converting an entered identifier into a consistent indexed value.

Examples:

* ISBN/EAN/UPC/GTIN remove spaces and punctuation.
* Publisher numbers preserve display value but index uppercase alphanumeric-only text.

---

## Inventory Behavior

Legacy product variant field describing historical inventory/POS behavior (`standard_physical`, `non_inventory`, etc.). Phase 8 adds `Inventory::TrackingResolver` and `inventory_tracking_override`; **`Inventory::Eligibility` is the mutation gate**. Legacy `standard_physical` maps to inventory tracking. Do not use `inventory_behavior` alone for new posting decisions.

---

## Inventory Tracking

Resolved inventory vs non-inventory state via `Inventory::TrackingResolver` (override → legacy behavior → product default → product type). Authoritative for eligibility alongside `Inventory::Eligibility`.

---

## Inventory Balance

The cached quantity and estimated value of one product variant at one store.

Authoritative grain:

```text
store_id + product_variant_id
```

Balances are projections from posted ledger entries.

---

## Inventory Ledger Entry

An append-only record of one quantity and value effect within an inventory posting.

Ledger entries capture signed `quantity_delta`, movement type, cost and retail snapshots, and optional location or reason context.

---

## Inventory Posting

The atomic posted inventory event record (`inventory_postings`). One posting may contain one or many ledger entries. Postings are immutable once created.

Distinct from the **`Inventory::Post`** service, which creates postings and ledger entries.

---

## Inventory::Post

The sole authoritative service for mutating on-hand inventory. All stock changes — receiving, POS sale/return, adjustments, buyback, vendor return — flow through this service into **`Inventory Posting`** and **`Inventory Ledger Entry`** records, then update **`Inventory Balance`**.

Demand and allocations never call **`Inventory::Post`** directly.

---

## Inventory Reason Code

Global setup record describing why an inventory adjustment line was posted (for example, shrink, damage, cycle count).

Identified by stable `reason_key` for idempotent seeds.

---

# L

## Local Identifier

A ShelfStack-generated identifier used when a catalog item has no manufacturer/vendor identifier.

Example:

```text
L000000001
```

---

# M

## Manual TBO

“To Be Ordered” — a **[capture intent](#capture-intent)** on **`DemandLine`** (`manual_tbo`) for staff-initiated replenishment of a specific variant. Does not post inventory. Typically flows through **sourcing** into a purchase order. Legacy route alias `orders_purchase_requests` redirects to `/demand?capture_intent=manual_tbo`.

---

# N

## Notify

A **[capture intent](#capture-intent)** on **`DemandLine`** (`notify`). Staff are alerted when stock arrives; **no auto-hold** is created. May convert to hold or special order manually.

---

# P

## Operational Report

Phase 9b report under `/reports` reading operational snapshots and ledgers (not GL postings). Canonical report hub; POS navigates here via `/reports`.

---

## Permission

A seed-managed capability in the application.

Example:

```text
setup.products.update
```

Permissions are assigned to roles through role permissions.

---

## Primary Identifier

The main active **product identifier** for a product (`product_identifiers.primary_identifier = true`). Used for scan/lookup and bibliographic identity — **not** for variant SKU assignment in v0.04.

Legacy `catalog_item_identifiers.primary_identifier` remains on retained-temporary catalog admin records only.

---

## Product

The descriptive **commercial item** in v0.04 — one edition, release, or manufactured item (book ISBN, UPC, sideline, service, etc.). Metadata lives on `products`; sellable behavior lives on **`Product Variant`**.

Examples: a specific hardcover ISBN, a gift card product, a café item, an event ticket.

A product is not sellable until it has at least one active variant. Optional legacy link: `products.catalog_item_id` (retain-temporary admin only).

---

## Product Condition

A controlled setup record describing a variant’s condition or special state.

Examples:

* New
* Signed Copy
* Used - Like New
* Used - Good
* Remainder

Product conditions affect default pricing and used-variant rules; they do **not** suffix variant SKUs in v0.04.

---

## Product Group

Optional non-operational grouping of related products (`product_groups`; v0.04-3 deferred). Types include work, series cluster, release family, and merchandise family. **Not** the operational grain for POS, inventory, or purchasing.

---

## Product Identifier

External or house identifier on a **product** (`product_identifiers`). Validation families:

```text
gtin     — EAN/UPC/GTIN (including book EAN-13)
isbn     — ISBN-10/ISBN-13 (ISBN-10 converts to ISBN-13 primary where applicable)
freeform — staff-entered non-standard codes
house    — ShelfStack-assigned EAN-13 (prefix 200–229)
```

Scan and lookup resolve product identity here; POS/inventory operate on **`Product Variant`**. See also **[House Identifier](#house-identifier)**.

---

## Product SKU (legacy field)

Historical product-level SKU column on `products`. In v0.04, **variant SKUs are system-assigned** and authoritative for operational workflows. Do not derive new variant SKUs from product identifiers or this field.

---

## Product Variant

The **operational grain** for ShelfStack: sellable SKU with price, condition, classification, and tracking flags. POS, inventory, purchasing, receiving, demand, allocations, buyback, and fulfillment all reference **`product_variants`**.

Variant SKUs are **system-assigned at creation** (internal EAN-13 segment **211**), unique, and not suffix-derived from condition or product identifiers.

Examples: new copy, signed copy, used condition, size/color variant.

---

## Purchase Order (PO)

A committed order to a vendor with line-level snapshots at submit time.

---

## Purchase Order Line

One variant line on a purchase order (`purchase_order_lines`). Snapshots SKU, name, vendor item number, costs, and returnability at PO submit. Open quantity drives receiving; may link to inbound **demand allocations**.

---

## Purchase Request (TBO)

**Retired v0.03 table.** Replenishment intent is captured as a **`DemandLine`** with `capture_intent = manual_tbo` or `buyer_replenishment`, then sourced and converted to PO lines. Legacy route alias `orders_purchase_requests` redirects to `/demand?capture_intent=manual_tbo`.

---

# R

## Receipt

A receiving document; only `quantity_accepted` on each **receipt line** posts to inventory via **`Inventory::Post`**.

---

## Receipt Line

One variant line on a receipt (`receipt_lines`). Tracks expected, received, and **accepted** quantity. Only accepted quantity posts to **`Inventory Balance`**. May trigger demand allocation conversion on post.

---

## Return Drawer

Phase 10-C POS drawer workflow for receipted and no-receipt returns; may add return lines to an active sale-only draft (exchange) but blocked when tender rows exist.

---

## Return to Vendor (RTV)

Posted document removing inventory for vendor returns via `posting_type: vendor_return`.

---

## Role

A named bundle of permissions.

Example:

```text
super_administrator
```

---

## Role Assignment

The assignment of a role to a user.

Role assignments may be:

* global
* store-scoped

The assignment is scoped, not the role itself.

---

# S

## Stored Value Account

Canonical liability account (`stored_value_accounts`) for gift card, store credit, trade credit, and related types. Balance from append-only ledger.

---

## Stored Value Identifier

Redemption token linked to a stored value account; masked in UI; full reveal may require audited action.

---

## Special Order

A **[capture intent](#capture-intent)** on **`DemandLine`** (`special_order`) — customer-backed order for a specific variant. **Not** the retired v0.03 `special_orders` table. May pair with inbound **demand allocations** and PO/receiving before **fulfillment** / POS pickup.

---

## Sourcing Attempt

One vendor inquiry within a **sourcing run** (`sourcing_attempts`). Tracks which vendor was contacted and links to **vendor responses**.

---

## Sourcing Run

A vendor inquiry workflow (`sourcing_runs`) initiated from replenishment **demand** or buyer **stock considerations**. Groups one or more **sourcing attempts** before PO creation.

---

## Stock Consideration

Buyer or system replenishment signal (`stock_considerations`) that may spawn **demand lines** or feed sourcing. Distinct from customer-facing capture intents (hold, notify, special order).

---

## SubDepartment

Operational merchandise behavior bucket belonging to a department.

Subdepartments provide defaults for product variants:

* Pricing model
* Margin target (`default_margin_target_bps`)
* Supplier discount
* Tax category
* Returnability and buyback defaults

Every product variant requires a `sub_department_id`. GL posting resolves via `sub_department → department.gl_account_code`.

---

## SKU

Stock keeping unit. In v0.04 the authoritative sellable SKU is on **`Product Variant`**, system-assigned (segment **211**). Product-level SKU and identifier-derived suffix patterns are legacy.

---

## Store

A physical or operational store/location using ShelfStack.

Store context affects:

* Time zone
* Workstations
* Store-scoped permissions
* Store tax rates
* Future inventory and POS behavior

---

## Store Display Location

A store-specific activation of a global display location.

This allows a display location to exist globally while being active only in certain stores.

---

## Store-Scoped Role Assignment

A role assignment that applies only when the active store context matches the assignment’s store.

---

## Store Tax Category Rate

An effective-dated mapping of:

```text
store + tax category + date range → store tax rate
```

This determines which tax rate applies to a tax category at a store on a given date.

---

## Store Tax Rate

A tax rate defined for a specific store.

Examples:

* Non-Taxable, 0%
* Michigan Sales Tax, 6%
* California Demo Tax, 9.5%

---

## System User

A non-interactive user used for background/system actions.

The system user cannot log in interactively.

---

# T

## Transaction Intent Boundary

Phase 10-C rule: slash-prefixed input → command registry; non-slash → scan/catalog lookup only. Failed lookup never creates a draft or infers open-ring/return workflows.

---

## Tax Category

Global product taxability classification.

Examples:

* Non-Taxable
* Books
* Periodicals
* General Merchandise
* Prepared Food
* Gift Card

Tax categories do not directly define rates. Store tax category rates map tax categories to store tax rates.

---

# U

## Used Wanted

A **[capture intent](#capture-intent)** on **`DemandLine`** (`used_wanted`) when a customer wants a **used** copy of a title. Customer-reservable via allocations; **not vendor-orderable** for new-item PO lines (v0.04-5).

---

## User

Application user or system actor.

Interactive users may log in if active and permitted.

The system user is non-interactive.

---

## User Session

Persisted login/session lifecycle record.

Statuses:

```text
active
locked
ended
expired
force_ended
```

---

# V

## Vendor

Supplier or source organization. Phase 5 adds product and variant vendor sourcing, purchase orders, receiving, and returns to vendor.

---

## Vendor Item Number

The supplier's catalog or stock number for a product or variant, stored on sourcing records and snapshotted on purchase order and receipt lines.

---

## Vendor Response

A vendor's answer to a **sourcing attempt** (`vendor_responses`): confirmed, declined, or backorder quantity and related metadata. Informs PO line quantities; does not post inventory until receipt.

---

## Variant

See **Product Variant**.

---

# W

## Workstation

A store-level computer, register, service desk, receiving station, or back-office station.

Workstations are assigned to stores.

---

## Workstation Assignment

A secure browser-to-workstation assignment.

The browser stores a raw token.
ShelfStack stores a digest and resolves store/workstation context server-side.

---

# Retired terms (v0.03 → v0.04)

These names appear in historical phase specs only. Active code and docs use the v0.04 replacements.

| Retired term | v0.04 replacement |
| ------------ | ----------------- |
| Customer request / `customer_requests` | `DemandLine` / `/demand` |
| Customer request line | `DemandLine` (single-line model) |
| Special order table / `special_orders` | `DemandLine` with `capture_intent = special_order` |
| Purchase request / TBO table | `DemandLine` with `capture_intent = manual_tbo` |
| Inventory reservation | `DemandAllocation` |
| PO line allocation / receipt line allocation | `DemandAllocation` + receipt conversion services |
| `CatalogItem` as canonical model | `Product` + `product_identifiers` |
| `from_tbo` PO builder | Manual TBO demand + sourcing (param name retained deprecated) |

**Compatibility redirects (302 only):**

* `customers_customer_requests` → `/demand`
* `orders_purchase_requests` → `/demand?capture_intent=manual_tbo`

See [v0.04-10 completion](implementation/v0.04-10-completion.md) and [domain-model.md](domain-model.md) §8.

