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

## Catalog Item

A descriptive metadata record.

Examples:

* Book title
* Calendar
* Periodical
* Recorded music item
* DVD/video
* Audiobook
* eBook
* Map
* Game
* Gift item
* Sideline item

A catalog item is not the sellable SKU. Products and product variants are used for store-facing sales behavior.

---

## Customer

A lightweight store customer profile used for requests, holds, special orders, and pickup contact history.

---

## Customer Pickup

POS fulfillment of customer demand; Phase 10-C uses a drawer workflow with draft created on line fulfillment.

---

## Customer Request

A store-scoped document capturing one or more customer demand lines (research, notify, hold, or special order) with optional provisional metadata before variant matching.

---

## Customer Request Line

A single line on a customer request. May start provisional and later link to catalog/product/variant.

---

## Catalog Item Identifier

An identifier associated with a catalog item.

Examples:

* ISBN-10
* ISBN-13
* EAN
* UPC
* GTIN
* Publisher number
* ShelfStack local identifier

A catalog item must have at least one active identifier and exactly one active primary identifier.

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

# I

## Idle POS Workspace

POS landing state when register is open and no active draft exists. Command field is home base; no silent draft creation (Phase 10-C).

---

## Inventory Reservation

A quantity commitment against on-hand or incoming stock for customer demand.

Types: `on_hand_hold`, `incoming_reserve`, `special_order_reserve`. Active on-hand reservations reduce `quantity_available`.

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

The atomic posted inventory event. One posting may contain one or many ledger entries.

Postings are immutable once created.

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

The main active identifier for a catalog item.

A catalog item may have many identifiers but must have exactly one active primary identifier.

The primary identifier is used as the default SKU source for catalog-linked products.

---

## Product

A store-facing product grouping.

A product may be linked to a catalog item, but does not have to be.

Examples:

* A book title as sold by the store
* A gift card
* A latte
* An event ticket
* A donation
* A sideline item

A product is not sellable until it has at least one active product variant.

---

## Product Condition

A controlled setup record describing a variant’s condition or special state.

Examples:

* New
* Signed Copy
* Used - Like New
* Used - Good
* Remainder

Product conditions can affect variant SKU generation and default pricing.

---

## Product SKU

The base SKU for a product.

For catalog-linked products, the product SKU defaults from the catalog item’s primary identifier.

For non-catalog products, the SKU is manually entered or generated by ShelfStack.

---

## Product Variant

The actual sellable SKU. POS, receiving, purchasing, inventory, and buyback workflows operate at the product variant level.

Examples: new copy, signed copy, used condition, size/color variant.

---

## Purchase Order (PO)

A committed order to a vendor with line-level snapshots at submit time.

---

## Purchase Request (TBO)

Store-level “to be ordered” demand signal. Does not affect inventory until received through a receipt.

---

# R

## Receipt

A receiving document; only `quantity_accepted` posts to inventory via `Inventory::Post`.

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

A customer-backed commitment record linking a matched request line to downstream PO allocation, receiving, and pickup fulfillment.

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

Stock keeping unit.

ShelfStack uses:

* Product SKU as the base SKU
* Product variant SKU as the actual sellable SKU

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

