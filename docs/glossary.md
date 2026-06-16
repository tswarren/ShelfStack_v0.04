# `docs/glossary.md`

# ShelfStack Glossary

## Purpose

This glossary defines recurring ShelfStack terms.

It is intended to keep documentation, code, UI labels, and developer conversation consistent.

---

# A

## Active

A record with `active = true`.

Active records may be used for new activity unless other rules prevent it.

Inactive records usually remain visible for history but cannot be selected for new setup or business activity.

---

## Audit Event

An append-only record of significant application activity.

Audit events may record:

* Security events
* Session events
* Setup changes
* SKU generation
* Identifier changes
* Product/variant changes
* Future inventory/POS events

---

## Actor

The user or system account that performed an action.

Stored on audit events as `actor_user_id`.

---

# B

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

A product-level classification linked to a department.

**Transitional note (Phase 3B):** Legacy categories correspond to **MerchandiseClass** behavior buckets, not topic **CategoryNode** records. During transition, categories remain required on product variants and are labeled “Merchandise Category” in setup and item UI.

Categories provide default values for future product variants, including:

* Pricing model
* Margin target
* Supplier discount
* Tax category

---

## Merchandise Class

Operational merchandise behavior bucket (pricing model, margin/supplier defaults, tax category, returnability, buyback). Linked from legacy categories during Phase 3B transition.

---

## Category Scheme

Named topical classification system (for example, Store Sections / Topics).

---

## Category Node

A node within a category scheme hierarchy (for example, Fiction, Biography).

---

## Categorization

Assignment of a catalog item, product, or product variant to a category node.

---

## Accounting Mapping

Configurable rule that maps merchandise class, condition, product type, and optional topic node to sales account and reporting bucket outputs.

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

Top-level sales and reporting bucket.

Departments are used for:

* POS reporting
* Department sales summaries
* Future GL/accounting export
* High-level product organization

Department numbers are fixed-width, zero-padded strings such as `001`, `010`, and `100`.

---

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

## Global Role Assignment

A role assignment that applies across all stores.

---

# I

## Identifier Normalization

The process of converting an entered identifier into a consistent indexed value.

Examples:

* ISBN/EAN/UPC/GTIN remove spaces and punctuation.
* Publisher numbers preserve display value but index uppercase alphanumeric-only text.

---

## Inventory Behavior

A product variant field that describes how the variant should behave in future inventory/POS workflows.

Examples:

```text
standard_physical
digital_asset
drop_ship
composite_recipe
capacitated_service
pure_financial
non_inventory
```

In Phase 4, only `standard_physical` variants may receive inventory ledger entries.

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

# L

## Local Identifier

A ShelfStack-generated identifier used when a catalog item has no manufacturer/vendor identifier.

Example:

```text
L000000001
```

---

# P

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

The actual sellable SKU.

Future POS, receiving, purchasing, and inventory workflows should operate at the product variant level.

Examples:

* New copy
* Signed copy
* Used - Like New copy
* Blue / Large T-shirt
* 16 oz latte

---

# R

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

Supplier or source organization.

Phase 3 includes the vendor directory. Vendor-product sourcing is deferred.

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

