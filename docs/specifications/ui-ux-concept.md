# ShelfStack UI/UX Concept

## Purpose

This document defines the core UI/UX direction for ShelfStack.

ShelfStack should use a **workflow-first, item-centered UX**, not a table-first/admin CRUD UX.

The underlying data model intentionally separates catalog metadata, store-facing products, and sellable SKUs:

```text
Catalog Item → Product → Product Variant/SKU
```

However, users should not experience those as disconnected modules. The interface should present them as one coherent item lifecycle:

```text
Identify the item → describe what it is → define how the store sells it → manage sellable SKUs
```

The goal is to make ShelfStack feel practical for bookstore staff while preserving the technical separation needed for inventory, purchasing, POS, reporting, and future accounting workflows.

---

# 1. Primary UX Principle

ShelfStack should organize the application around **store workflows**, not database tables.

Users should not need to understand whether they are working with:

```text
catalog_items
catalog_item_identifiers
products
product_variants
stock_balances
inventory_ledger_entries
purchase_order_lines
sale_lines
```

Instead, screens should guide users through familiar bookstore work:

```text
Find an item
Add an item
Sell an item
Receive stock
Create an order
Manage variants/SKUs
Handle a customer request
Review inventory
Run reports
```

The service layer can update the correct tables behind the scenes. The UI should present clear task-oriented screens that match how bookstore staff actually work.

---

# 2. Core Mental Model

ShelfStack has two related UX models:

1. **Workspace model** for the whole application.
2. **Item lifecycle model** for catalog, product, and variant workflows.

---

## 2.1 Workspace Model

Use this high-level mental model:

```text
Front Counter = fast sales and customer-facing work
Inventory Desk = stock movement, receiving, counts, and availability
Catalog Desk = item, product, and SKU maintenance
Customer Desk = holds, credits, special orders, and customer history
Manager Desk = approvals, reporting, setup, and controls
```

This can be expressed in main navigation as:

```text
Dashboard
POS
Items
Inventory
Orders
Customers
Reports
Setup
```

---

## 2.2 Item Lifecycle Model

For catalog/product/variant workflows, use this mental model:

```text
Identify → Describe → Sell → Organize → Review
```

| Step     | User Meaning                                         | Technical Records                                      |
| -------- | ---------------------------------------------------- | ------------------------------------------------------ |
| Identify | What barcode, identifier, or SKU is this?            | `catalog_item_identifiers`, product/variant SKU lookup |
| Describe | What is this item?                                   | `catalog_items`                                        |
| Sell     | How does the store recognize and sell it?            | `products`                                             |
| Organize | Which versions/SKUs exist?                           | `product_variants`                                     |
| Review   | What changed, what is missing, what needs attention? | `audit_events`, status checks                          |

The user should experience this as one item workflow, not as three unrelated screens.

---

# 3. Recommended App Workspaces

## 3.1 Main Navigation

```text
Dashboard
POS
Items
Inventory
Orders
Customers
Reports
Setup
```

## 3.2 Workspace Meaning

| Workspace | Primary Users                     | Purpose                                                                               |
| --------- | --------------------------------- | ------------------------------------------------------------------------------------- |
| Dashboard | Everyone                          | Today’s store status, alerts, pending work, and high-level context.                   |
| POS       | Clerks/front counter              | Sales, returns, tenders, customer-facing transactions, and future register workflows. |
| Items     | Catalog/inventory/frontline staff | Search, add, review, and maintain items, products, and sellable SKUs.                 |
| Inventory | Stock staff/managers              | Future receiving, adjustments, counts, stock lookup, and movement history.            |
| Orders    | Buyers/managers                   | Future purchase orders, special orders, and vendor returns.                           |
| Customers | Clerks/managers                   | Future customer profiles, credits, holds, special orders, and buybacks.               |
| Reports   | Managers                          | Sales, inventory, cash, tax, margin, and operational reports.                         |
| Setup     | Admins/managers                   | Stores, users, roles, departments, categories, tax, formats, conditions, vendors.     |

---

# 4. Current Phase UX Priorities

ShelfStack should not attempt to build the complete future-state UI all at once.

The current UX priority should match the phased roadmap.

## Phase 1 UX Priorities

Phase 1 should focus on:

```text
Login
Workstation assignment
Session context
Session lock/unlock
Application shell
Dashboard placeholder
Setup navigation
Users
Roles
Permissions
Stores
Workstations
Audit event review
```

## Phase 2 UX Priorities

Phase 2 should focus on:

```text
Departments
Categories
Tax categories
Store tax rates
Store tax category rates
Tax lookup preview
Setup audit timelines
```

## Phase 3 UX Priorities

Phase 3 should focus on:

```text
Unified item search
Add item workflow
Catalog details
Barcodes and identifiers
Product selling setup
Sellable SKUs / variants
Product conditions
Display locations
Vendors
SKU generation previews
Name rendering previews
Catalog/product/variant audit timelines
```

Future POS, receiving, inventory, special orders, buybacks, vendor returns, and reports should remain conceptually described but should not drive the immediate Phase 1–3 implementation.

---

# 5. Dashboard UX

The dashboard should answer:

```text
What needs attention today?
```

For early phases, the dashboard may be simple.

## Phase 1 Dashboard

Show environment/session context:

```text
Current store
Store time zone
Workstation
Current user
Last login
Previous login
Session status
Inactivity duration
```

## Later Dashboard Cards

Future dashboard cards may include:

```text
Open register sessions
Suspended POS transactions
Pending approvals
Special orders ready for pickup
Purchase orders expected soon
Low-stock / out-of-stock items
Receiving batches pending
Vendor returns pending credit
Inventory value summary
Cash variance alerts
Gift card / store credit exceptions
```

---

# 6. Items Workspace

The Items workspace is the most important UX area for Phase 3.

Its purpose is to make catalog records, products, and variants feel like one coherent concept.

## 6.1 Primary Item Actions

```text
Search Items
Add Item
View Item
Edit Item
Manage Sellable SKUs
```

The main UI should avoid making ordinary users choose directly between:

```text
Catalog Items
Products
Product Variants
```

Those are implementation concepts. The user-facing concept should be:

```text
Items
```

or:

```text
Item Setup
```

---

# 7. Add Item Workflows

The Add Item workflow guides users through item setup without exposing the database model. ShelfStack supports two creation paths:

1. **Catalog-linked item** — for books, media, gifts, and other metadata-heavy items. Creates `catalog_item` → `product` → `product_variant`.
2. **Non-catalog item** — for services, fees, donations, gift cards, and simple merchandise. Creates `product` → `product_variant`.

Internally the layers remain catalog details, selling setup, and sellable SKUs. User-facing labels use **Item Details**, **Selling Setup**, and **Sellable SKU**.

Before choosing a path, users may optionally **search for an existing item** to avoid duplicates.

---

## Choose creation path

Prompt:

```text
What kind of item are you adding?
```

| Option | Use when | Result |
| ------ | -------- | ------ |
| **Catalog-linked item** | Bibliographic or catalog metadata is needed | `catalog_item` → `product` → `product_variant` |
| **Non-catalog item** | No catalog metadata needed | `product` → `product_variant` |

---

## Catalog-linked item workflow

### Step 1: Item Details

User-facing screen: **Add Catalog-Linked Item — Item Details**

The first field is **Item Type**. After selection, the form shows metadata fields appropriate to that type (book, calendar, periodical, recorded music, sideline, videorecording, audiobook, ebook, map, game, gift, other).

Requirements:

- At least one identifier (external or locally generated).
- ISBN-10 saves as non-primary; ISBN-13 becomes primary.
- Inline identifier validation warnings.
- Creator and subject fields support semicolon-separated entry with parsed preview.

| Action | Behavior |
| ------ | -------- |
| **Create Selling Setup** | Saves catalog item and proceeds to selling setup |
| **Done** | Saves catalog item; item overview shows status **Catalog Only** |
| **Cancel** | Returns to Items home |

### Step 2: Selling Setup

User-facing screen: **Create Selling Setup**

When reached from a catalog item:

- Product is linked to the catalog item automatically.
- Catalog title shown near optional name override.
- SKU prefilled from primary identifier.
- Product type limited to `physical` or `digital` (default `physical`).
- Variation type **defaults to `conditional`** and is hidden in this simplified workflow (workflow simplification, not a permanent domain rule).
- **Initial SKU category** prefills the first sellable SKU.

| Action | Behavior |
| ------ | -------- |
| **Continue to Sellable SKU** | Creates product and proceeds |
| **Cancel** | Returns to catalog item overview |

### Step 3: Sellable SKU

User-facing screen: **Create Sellable SKU**

For catalog-linked products in this workflow, the first variant is condition-based:

- Inventory behavior derived from product type (`physical` → `standard_physical`, `digital` → `digital_asset`).
- Condition defaults to New.
- Selling price defaults to `list_price_cents × condition.default_list_price_factor_bps / 10000`.
- SKU and name previews shown; New condition uses product SKU/name without suffix.

| Action | Behavior |
| ------ | -------- |
| **Create SKU** | Creates variant; returns to item overview (**Sellable**) |
| **Create SKU and Add Another** | Creates variant; stays on sellable SKU step for another variant |
| **Cancel** | Returns to item overview |

---

## Non-catalog item workflow

### Step 1: Selling Setup

User-facing screen: **Add Non-Catalog Item**

Skips catalog item creation. Fields include SKU (manual or **Generate SKU**), product name, product type, list price, initial SKU category, and variation type when applicable.

Variation type rules:

| Product type | Variation type |
| ------------ | -------------- |
| `service`, `financial` | Forced to `standard` (hidden) |
| `non_inventory` | Defaults to `standard` (hidden in simplified workflow) |
| `physical` | User may choose `standard`, `conditional`, `variable`, or `matrix` |
| `digital` | User may choose `standard`, `conditional`, or `variable` |

Show `variant1_label` when variation type is `variable` or `matrix`. Show `variant2_label` when variation type is `matrix`.

| Action | Behavior |
| ------ | -------- |
| **Add Sellable SKU** | Creates product and proceeds |
| **Done** | Creates product only; overview shows **Product Created** / **No Active Variant** |
| **Cancel** | Returns to Items home |

### Step 2: Sellable SKU

Displayed fields depend on `variation_type`:

- **Standard** — name override, SKU (= product SKU), selling price, category, display location.
- **Conditional** — condition, SKU/name previews, selling price from condition factor.
- **Variable** — attribute 1 value and SKU component, previews.
- **Matrix** — attribute 1 and 2 values and components, previews.

Completion returns to item overview.

---

## Partial completion statuses

| User stops after | Lifecycle status |
| ---------------- | ---------------- |
| Catalog item only | Catalog Only |
| Product only | Product Created / No Active Variant |
| Product + variant | Sellable |

Advanced fields (variation type override, inventory behavior, pricing model) remain available on full Selling Setup and Sellable SKU edit screens.

---

# 8. Unified Item Detail Page

ShelfStack should provide one primary detail page for an item.

Recommended page title:

```text
The Hobbit
```

or:

```text
Item: The Hobbit
```

## 8.1 Suggested Page Structure

```text
[Item Header]

Tabs:
  Overview
  Catalog Details
  Selling / SKUs
  Display & Vendors
  Activity
```

Future tabs may include:

```text
Inventory
Purchasing
Sales History
```

---

## 8.2 Item Header

The header should summarize the item immediately.

Recommended header data:

```text
Title/product name
Primary identifier
Product SKU
Sellable status
Active variant count
Main format
Category/department
Price range
```

Example:

```text
The Hobbit
ISBN 9780123456789 · Hardcover · Books

Status: Sellable
Product SKU: 9780123456789
Active SKUs: 3
```

---

## 8.3 Overview Tab

The Overview tab should answer:

```text
Can I use this item operationally?
```

Recommended cards:

| Card                 | Purpose                                                                                            |
| -------------------- | -------------------------------------------------------------------------------------------------- |
| Catalog Status       | Shows whether metadata exists and has usable identifiers.                                          |
| Selling Status       | Shows whether product and active variants exist.                                                   |
| SKU Summary          | Shows product SKU and active variant SKUs.                                                         |
| Category/Tax Summary | Shows category, department, and tax default.                                                       |
| Alerts               | Shows missing price, missing category, invalid identifier, no active variant, inactive references. |

Example:

```text
Catalog Record: Complete
Product: Active
Sellable SKUs: 3 active variants
Primary SKU: 9780123456789
Warnings: ISBN check digit invalid
```

---

## 8.4 Catalog Details Tab

The Catalog tab should answer:

```text
What is this item?
```

Show:

```text
Identifiers
Title
Creators
Publisher
Format
Publication details
Series
Edition statement
Language
Dimensions/weight
Subjects/genres/themes
Description
```

This tab should feel like metadata, not selling setup.

---

## 8.5 Selling / SKUs Tab

The Selling / SKUs tab should answer:

```text
How does the store sell this item?
```

Show product-level fields:

```text
Product name
Product SKU
Product type
Variation type
List price
Default display location
```

Then show active variants in a table.

Example:

| Variant               | SKU                | Condition | Category   |  Price | Active |
| --------------------- | ------------------ | --------- | ---------- | -----: | ------ |
| The Hobbit            | `9780123456789`    | New       | Books      | $18.99 | Yes    |
| The Hobbit - Signed   | `9780123456789-SG` | Signed    | Books      | $24.99 | Yes    |
| The Hobbit - Like New | `9780123456789-UN` | Like New  | Used Books | $12.99 | Yes    |

Suggested actions:

```text
Add Variant
Generate Used Variant
Add Signed Copy
Add Remainder Copy
Add Matrix Variants
Edit Product
Regenerate Names
Regenerate SKUs
```

---

## 8.6 Display & Vendors Tab

This tab should answer:

```text
Where is this item merchandised, and who supplies it?
```

Phase 3 can show:

```text
Default display location
Variant display locations
Basic vendor references
```

Vendor-product sourcing can be marked as future work:

```text
Vendor sourcing, costs, and ordering rules will be added in a later purchasing phase.
```

---

## 8.7 Activity Tab

The Activity tab should show audit events.

Examples:

```text
Catalog item created
Identifier added
ISBN-10 converted to ISBN-13
Product created
Variant SKU generated
Product name overridden
Variant price changed
Variant inactivated
```

---

# 9. Unified Search Experience

Search should be unified.

Users should be able to search by:

```text
Title
Creator
Publisher
ISBN
UPC
EAN
GTIN
Publisher number
Local identifier
Product SKU
Variant SKU
```

Search results should not force the user to decide whether they are searching catalog records, products, or variants.

## 9.1 Search Result Format

Example:

```text
The Hobbit
J.R.R. Tolkien · Hardcover · ISBN 9780123456789

Catalog: Active
Product SKU: 9780123456789
Variants: New, Signed, Like New
Price Range: $12.99–$24.99
Status: Sellable
```

Suggested actions:

```text
View Item
Sell New
Edit Catalog
Edit SKUs
Add Used Copy
```

---

# 10. Relationship Breadcrumbs

Every catalog/product/variant screen should show the relationship between records.

Example:

```text
Catalog: The Hobbit → Product: The Hobbit → Variant: Signed Copy
```

Or visually:

```text
Catalog Item
The Hobbit
  ↓
Product
The Hobbit — SKU 9780123456789
  ↓
Variants
New, Signed, Like New
```

This helps users understand that these records are connected parts of one item lifecycle.

---

# 11. User-Facing Labels

Use labels that match user expectations.

| Internal Model             | User-Facing Label              |
| -------------------------- | ------------------------------ |
| `catalog_items`            | Catalog Details / Item Details |
| `catalog_item_identifiers` | Barcodes & Identifiers         |
| `products`                 | Store Product / Selling Setup  |
| `product_variants`         | Sellable SKUs / Versions       |
| `product_conditions`       | Conditions                     |
| `display_locations`        | Shelf/Display Locations        |
| `vendors`                  | Vendors                        |

For frontline users, prefer:

```text
Items
Sellable SKUs
Barcodes & Identifiers
```

over raw model names.

---

# 12. Status Indicators

ShelfStack should show clear statuses that explain whether an item is usable.

## Recommended Statuses

| Status                     | Meaning                                                          |
| -------------------------- | ---------------------------------------------------------------- |
| Catalog Only               | Catalog metadata exists, but no product/variant exists.          |
| Product Created            | Product exists, but no active sellable variant exists.           |
| Sellable                   | At least one active variant exists.                              |
| Missing Category           | Variant needs a category before it can be sold.                  |
| Missing Price              | Variant needs a selling price.                                   |
| Invalid Identifier Warning | Identifier was saved but failed check digit validation.          |
| Inactive Setup Reference   | Variant references inactive category/condition/display location. |
| No Active Variant          | Product is not currently sellable.                               |

These statuses should appear on:

```text
Item detail page
Search results
Product/variant setup screens
Dashboard alerts where appropriate
```

---

# 13. Generated Values and Previews

Generated values should be visible and explainable.

## Product SKU Preview

```text
Product SKU
9780123456789
Source: catalog primary identifier
```

## Variant SKU Preview

```text
Variant SKU
9780123456789-SG
Source: product SKU + condition suffix SG
```

## Variant Name Preview

```text
Variant Name
The Hobbit - Signed
Source: product name + condition short name
```

Generated values should update dynamically as users change:

```text
Primary identifier
Product SKU
Condition
Attribute values
Attribute SKU components
Name override fields
```

---

# 14. Variant/SKU Matrix

The Selling / SKUs tab should use a matrix or table when multiple variants exist.

## 14.1 Condition Variants

| Condition | SKU Suffix | Generated SKU      | Name                  |  Price |
| --------- | ---------- | ------------------ | --------------------- | -----: |
| New       | —          | `9780123456789`    | The Hobbit            | $18.99 |
| Signed    | SG         | `9780123456789-SG` | The Hobbit - Signed   | $24.99 |
| Like New  | UN         | `9780123456789-UN` | The Hobbit - Like New | $12.99 |

## 14.2 Matrix Variants

| Color | Size  | SKU             | Name                         |  Price |
| ----- | ----- | --------------- | ---------------------------- | -----: |
| Blue  | Small | `TSHIRT-BLU-SM` | Store T-Shirt - Blue / Small | $19.99 |
| Blue  | Large | `TSHIRT-BLU-LG` | Store T-Shirt - Blue / Large | $19.99 |

The matrix should make SKU generation predictable.

---

# 15. Dynamic Form Behavior

ShelfStack forms should feel responsive and operational.

Use **reactive operational workflows** where appropriate.

Reactive operational workflows are dynamic, line-oriented or task-oriented screens that continuously recalculate totals, validate entries, preview downstream effects, and support uninterrupted data entry while preserving a clear distinction between editable draft state and posted transaction state.

---

## 15.1 Catalog Form

The catalog form should support:

```text
Change catalog item type → relevant fields appear/disappear
Enter identifier → validation warning appears
Enter ISBN-10 → generated ISBN-13 preview appears
Enter creators → parsed creator/role preview appears
Enter subjects → scheme/code parsing preview appears
```

---

## 15.2 Product Form

The product form should support:

```text
Catalog-linked product name previews from catalog title
Product SKU previews from primary identifier
Name override immediately updates display name preview
Product type influences inventory behavior defaults
```

---

## 15.3 Variant Form

The variant form should support:

```text
Condition selection previews SKU and name
Attribute components preview SKU
Attribute values preview variant name
Category selection fills tax/pricing defaults where applicable
Price preview reflects condition list-price factor where applicable
```

---

# 16. Progressive Disclosure

Avoid overwhelming users with every field at once.

## 16.1 Catalog Details Sections

```text
Basic Details
Barcodes & Identifiers
Creators
Publisher
Format & Physical Details
Subjects, Genres & Audience
Description
Advanced Metadata
```

## 16.2 Selling Setup Sections

```text
Product Name & SKU
Product Type & Variation Type
Price & Category Defaults
Display
Sellable SKUs
```

## 16.3 Variant Sections

```text
SKU & Name
Condition / Attributes
Price
Category
Display
Inventory Behavior
```

---

# 17. Context-Aware Actions

Actions should appear where users need them.

## On a catalog record with no product

```text
Create Store Product
```

## On a product with no variants

```text
Create First Sellable SKU
```

## On a standard product

```text
Add Used/Special Copy
Add Signed Copy
Add Remainder Copy
```

## On a variable product

```text
Add Option
```

## On a matrix product

```text
Generate Matrix Variants
```

## On a variant

```text
Edit Price
Edit Category
Edit Display Location
Inactivate SKU
```

---

# 18. Administrative Setup Separation

Technical setup should not dominate the main workflow.

Place foundational setup records under Setup:

```text
Setup
  Stores
  Users
  Roles
  Permissions
  Workstations

  Classification
    Departments
    Categories
    Tax Categories
    Store Tax Rates
    Store Tax Category Rates

  Catalog & Items
    Formats
    Product Conditions
    Display Locations
    Vendors
```

The Items workspace should focus on item search, item creation, and sellable SKU management.

---

# 19. Phase 1 Application Shell

Phase 1 should establish a clear application shell.

## Header

The header should show:

```text
ShelfStack logo/name
Active store
Active workstation
Main navigation
Search/command area placeholder
User display name
Session/logout controls
```

## Footer or Utility Area

The footer or utility area may show:

```text
Application version
Copyright
Lock session action
```

## Session Context

Store/workstation/user context should be visible enough that staff know where they are working, but not so prominent that it clutters operational screens.

---

# 20. POS Workspace: Future Direction

POS should eventually be the fastest, most focused part of the application.

A future POS screen should use a three-panel layout:

```text
[Search / Scan / Command Bar]

[Cart / Transaction Lines]        [Item / Customer / Totals Panel]

[Tender / Actions Bar]
```

## POS UX Principles

```text
Keyboard-friendly
Scan-first
Fast item lookup
Large action targets
Clear totals
Clear tender state
Clear tax/discount/return state
Minimal clutter
```

## Future POS Workflows

Future POS should support:

```text
Sale
Return
Exchange
Open-ring sale
Gift card sale/redemption
Store credit redemption
Suspended transaction
Tax exemption
Discount/markdown approval
```

These workflows are future scope and should not be implemented until the POS phase.

---

# 21. Inventory Workspace: Future Direction

Inventory should eventually focus on stock state and stock movement.

Future inventory screens may include:

```text
Stock lookup
Receiving
Adjustments
Cycle counts
Inventory movements
Inventory value
Transfers
Vendor returns
```

## Future Inventory UX Principles

```text
Quantity and value effects should preview before posting.
Draft stock workflows should be editable.
Posted stock workflows should be corrected through adjustments or reversals.
Inventory screens should operate at the product variant/SKU level.
```

---

# 22. Orders Workspace: Future Direction

Orders should eventually support:

```text
Purchase orders
Receiving from purchase orders
Special orders
Vendor returns
Vendor order history
```

Purchase order and receiving screens should feel like controlled workpads with live totals and automatic row continuation.

---

# 23. Customer Workspace: Future Direction

Customer profiles should eventually consolidate operational activity.

Future customer page tabs may include:

```text
Profile
Purchases
Returns
Special Orders
Store Credit
Gift Cards
Buybacks
Reservations
Notes
```

This should make front-counter customer workflows easier.

---

# 24. Manager and Reports UX: Future Direction

Manager views should group work by operational questions.

## Approval Queues

Future approval queues may include:

```text
Markdown approvals
No-receipt return approvals
Cash paid out approvals
Stock adjustment approvals
Buyback approvals
```

## Reports

Reports should be grouped by business question:

```text
Sales
Inventory
Cash/Register
Taxes
Buybacks
Vendors
Audit
```

---

# 25. Visual Style

ShelfStack should use a **workstation-style interface**.

Recommended characteristics:

```text
Dense but readable
Keyboard-friendly
Clear tables
Strong status labels
Minimal animation
Large POS action targets
Persistent search/scan where useful
Clear audit/status cues
```

Avoid making the application too card-heavy.

Cards are useful for dashboards and summaries. Operational workflows need tables, queues, and forms.

---

# 26. Reactive Operational Workflows

ShelfStack screens should be dynamic and workflow-oriented.

As users enter lines, quantities, prices, discounts, tax exemptions, tenders, receiving quantities, or payout amounts, the interface should immediately preview calculated totals, balances, margins, taxes, inventory effects, and validation warnings.

Users should not need to save or refresh a form to understand the effect of their entry.

---

## 26.1 Recommended Terms

| Term                        | Meaning                                                                                         |
| --------------------------- | ----------------------------------------------------------------------------------------------- |
| Reactive forms              | Fields, totals, statuses, and dependent values update immediately as the user enters data.      |
| Live calculations           | Totals, taxes, margins, inventory value, expected costs, and balances recalculate in real time. |
| Inline validation           | Errors/warnings appear next to the field as soon as the system can detect them.                 |
| Automatic row continuation  | When a user completes a line item, a new blank line is automatically added.                     |
| Progressive disclosure      | Additional fields appear only when relevant.                                                    |
| Preview-before-commit       | The screen shows calculated effects before finalizing the workflow.                             |
| Workflow workpad            | The form acts like a live workspace for building a transaction/order/batch.                     |
| Non-destructive draft state | Entries can be edited freely until the user completes/posts/finalizes the record.               |

---

## 26.2 Preview vs. Posted State

This distinction is critical.

### Draft State

While the user is entering data:

```text
Totals are previews.
Inventory effects are previews.
Gift card/store credit effects are previews.
Register cash effects are previews.
Validation warnings are live.
```

### Completed/Posted State

When the user clicks complete/post/finalize:

```text
Stock movements are created.
Ledger entries are created.
Register cash events are created.
Balances are updated.
Transaction becomes locked.
```

Completed records should be corrected through reversal, adjustment, or follow-up workflows, not direct editing.

---

# 27. Technical UX Implementation Direction

For Rails implementation, use:

```text
Hotwire/Turbo-driven reactive forms with Stimulus controllers for local calculations and server-backed recalculation/validation where authoritative business rules are required.
```

A practical split:

| Calculation Type             | Recommended Location                          |
| ---------------------------- | --------------------------------------------- |
| Simple line math             | Client-side Stimulus                          |
| Display subtotal previews    | Client-side Stimulus                          |
| Product/variant name preview | Client-side Stimulus or server-backed preview |
| SKU preview                  | Client-side preview plus server validation    |
| Tax calculation              | Server-backed service                         |
| Gift card balance validation | Server-backed service                         |
| Inventory availability       | Server-backed service                         |
| Approval requirement checks  | Server-backed service                         |
| Final posting                | Server-side service only                      |

---

# 28. UX Acceptance Criteria

The UI/UX concept is being followed when:

1. Users can search for an item without choosing catalog/product/variant first.
2. Users can add an item through a guided workflow.
3. Catalog, product, and variant records are shown as one item lifecycle.
4. Product SKU and variant SKU generation are previewed and explained.
5. Product and variant names are previewed and overrideable.
6. Item detail pages clearly show catalog status, selling status, and sellable SKU status.
7. Setup screens are separated from operational workflows.
8. Dynamic forms use progressive disclosure and inline validation.
9. Future operational workflows distinguish preview/draft state from posted state.
10. The interface uses bookstore workflow language rather than raw table names.

---

# Bottom Line

ShelfStack should be organized around **store workflows** and **items**, not database objects.

The most important UX rule is:

```text
Users should interact with items, sellable SKUs, sales, receiving, orders, customers, and inventory workflows — not with raw implementation tables.
```

For Phase 3 specifically:

```text
Catalog Item → Product → Product Variant/SKU
```

should be presented as:

```text
Item Details → Selling Setup → Sellable SKUs
```

The data model can remain precise. The UI should make it feel obvious.

---

# 29. Form Layout Standard

ShelfStack forms use a shared layout system for setup and Items workflows.

## Page structure

```text
ss-page-header (eyebrow, h1, description, optional actions)
ss-form (width modifier)
  shared/forms/errors
  shared/forms/section (ss-form-card)
    ss-form-grid
      shared/forms/field (label, input, help, inline error)
      shared/forms/checkbox
  ss-form-actions (submit, cancel)
```

## Width modifiers

| Class | Use |
| ----- | --- |
| `ss-form--standard` | Setup forms (56rem) |
| `ss-form--wide` | Catalog, product, variant, Add Item wizard (72rem) |
| `ss-form--narrow` | Auth forms (reserved; login/PIN unchanged) |

## Field errors

Top-level error summary plus inline `ss-field-error` per field via `FormHelper#ss_field_error`.

## Preview controllers (Stimulus)

| Controller | Use |
| ---------- | --- |
| `department-number-preview` | Zero-padded department number |
| `basis-points-preview` | bps → percent display |
| `tax-mapping-preview` | Store tax mapping sentence preview |
| `variant-preview` | Variant SKU, name, conditional selling price |

Catalog metadata previews (creators, subjects, identifier normalization) remain inline until extracted in a later pass.
