# ShelfStack v0.04 — Core Domain Model

## Purpose

**ShelfStack v0.04 is the core domain model** for the application — the canonical architecture for products, identifiers, variants, demand, sourcing, receiving, and how they connect to inventory and POS.

The v0.03 **Phases 1–10** built a working codebase on an earlier vocabulary (`catalog_items`, fragmented customer requests, TBO). That implementation remains in the repo until migrated milestone by milestone. v0.04 is not “Phase 11”; it is the **new foundation** going forward.

The main goal is to clarify how commercial items, sellable variants, identifiers, customer/store demand, vendor sourcing, receiving, inventory posting, and POS behavior operate at the correct grain — especially for bookstores (ISBN/UPC scanning, new/used variants, vendor ordering, buyback intake).

**Delivery roadmap (ordered milestones):** [roadmap/v0.04-delivery-roadmap.md](../roadmap/v0.04-delivery-roadmap.md)

---

# 1. Catalog Items and Products

## Current issue

The existing model separates:

```text
Catalog Item → Product → Product Variant
```

This was useful for preserving rich metadata, but it creates ambiguity because `catalog_items` and `products` both partly describe “what the item is.”

From a bookstore perspective, a product is not usually an abstract title-level grouping. A product is generally a specific commercial item, edition, release, or manufactured item.

Examples:

```text
Book hardcover ISBN = one product
Book paperback ISBN = another product
CD release UPC = one product
Vinyl release UPC = another product
DVD edition UPC = one product
Gift item UPC = one product
```

Therefore, hardcover and paperback editions of the same title should normally be represented as separate products, because they have distinct ISBNs, formats, prices, publisher data, vendor ordering behavior, and sales history.

## New direction

In v0.04, ShelfStack should collapse or reframe the catalog/product distinction so that the core item model becomes:

```text
Optional Product Group / Work
  → Product
    → Product Variant
```

Where:

| Layer                | Purpose                                                           |
| -------------------- | ----------------------------------------------------------------- |
| Product Group / Work | Optional grouping across editions, formats, or releases           |
| Product              | Specific commercial item, edition, release, or manufactured item  |
| Product Variant      | Store-specific sellable, stockable, reservable, or orderable form |

## Product definition

A product is ShelfStack’s record for a specific commercial item.

Examples:

* A specific book edition with an ISBN
* A specific album release with a UPC
* A specific DVD/Blu-ray release
* A specific video game platform/release
* A specific gift or sideline item
* A defined café item or service

Product-level data may include:

```text
title
subtitle
creator / contributor display
publisher / manufacturer
format
edition statement
publication or release date
primary external identifier
list price
description
series data
subject/genre metadata
external metadata source records
```

## Product group / work

Optional grouping uses the **`product_groups`** table and model. **Work** is a `group_type` value (and display label for books), not the universal table name — other types include `series_cluster`, `release_family`, and `merchandise_family`. See [v0.04 delivery roadmap](../roadmap/v0.04-delivery-roadmap.md#product-groups-naming).

A product group is optional. It can be used to group related products across editions or formats.

Example:

```text
Product Group:
- North Woods

Products:
- North Woods hardcover ISBN
- North Woods paperback ISBN
- North Woods audiobook ISBN
```

This grouping is useful for search, display, recommendations, and related-edition navigation, but it should not be the operational unit for POS, purchasing, receiving, or inventory.

---

# 2. Product Variants

## New definition

A product variant is the specific store-facing sellable, stockable, reservable, or orderable form of a product.

The product identifies the commercial item. The variant identifies how ShelfStack handles that item operationally.

Example:

```text
Product:
- North Woods hardcover, ISBN 978...

Variants:
- New hardcover
- Used hardcover
- Signed hardcover
- Damaged hardcover
- Remainder hardcover
```

## Variant responsibilities

Product variants should continue to be the operational grain for:

```text
POS lines
inventory ledger entries
stock balances
purchase order lines
receipt lines
customer demand
reservations / allocations
used-copy handling
pricing behavior
tax/classification behavior
vendor orderability
```

This preserves one of the strongest parts of the existing ShelfStack architecture: operational workflows already work best at the product variant level.

---

# 3. SKUs, Barcodes, and Identifiers

## Current issue

The v0.03 model mixes three different ideas:

```text
Commercial identity   → ISBN / UPC / publisher number (today: catalog_item_identifiers)
Product grouping      → products.sku, often copied from the primary identifier (display/search only)
Operational sellable  → product_variants.sku, system-assigned; not derived from product identifiers
```

That was tolerable while catalog items and products were separate, but it creates confusion after v0.04 collapses them. An ISBN identifies a **commercial product**, not necessarily the exact **variant** being sold, priced, received, or reserved.

The same product may have multiple active variants:

```text
New
Used
Signed
Damaged
Remainder
Collectible
Consignment
```

Those variants differ in price, cost, inventory behavior, orderability, returnability, and POS handling. ShelfStack must keep product identity and variant identity distinct without adding unnecessary barcode layers.

## Design principle

v0.04 keeps **three identifier concepts** separate, rather than introducing a universal identifier table:

```text
Product identifier  → what commercial item is this?
Variant SKU         → which sellable/stockable/reservable form is this?
Vendor item number  → how does this vendor refer to it when ordering?
```

Product identifiers belong to **products**. Variant SKUs belong to **product variants**. Vendor item numbers belong to **vendor sourcing records**, not to a shared polymorphic identifier model.

---

## Product identifiers

After catalog and product are merged, external and store-assigned codes live on the product in a dedicated `product_identifiers` table. This is the direct successor to `catalog_item_identifiers`, scoped to `product_id` rather than `catalog_item_id`.

### Identifier families (not barcode subtypes)

v0.04 should **not** treat `isbn13`, `ean`, `upc`, and `gtin` as separate stored types. They are the same underlying GTIN family: digits, fixed lengths, and a shared check-digit algorithm. ISBN-13 is EAN-13 with a `978` or `979` prefix; UPC-A is commonly represented as EAN-13 with a leading `0`.

Instead, each identifier row should store a **validation family** that controls normalization and validation rules:

| Family | Purpose | Validation |
| ------ | ------- | ---------- |
| `gtin` | Externally assigned barcodes: ISBN-13/EAN-13, EAN-8, UPC-A, GTIN-14 | Digits only; allowed lengths 8, 12, 13, 14; GTIN check digit required |
| `isbn` | ISBN-10 | Mod-11 check digit (including `X`); separate from GTIN-family rules |
| `freeform` | Publisher numbers, BIPAD (magazine) codes, and similar vendor/catalog references | Alphanumeric normalization; **no** check digit |
| `house` | Store-assigned **EAN-13** barcodes for items without manufacturer codes | EAN-13 check digit; prefix in reserved **200–229** range (see below) |

**Display labels** such as “ISBN-13”, “ISBN-10”, “UPC”, or “EAN-13” should be **inferred** from the normalized value and validation family when showing staff-facing UI. They do not need separate persistence.

Examples of inferred display:

```text
9781643751234   → ISBN-13 (gtin)
0123456789      → ISBN-10 (isbn)
9791643751234   → ISBN-13 (gtin; no ISBN-10 alternate)
0049000007746   → UPC-A (gtin; normalize to 13-digit EAN with leading 0)
2010000000014   → House EAN-13 (house; segment 201, product house identifier)
012345678905    → EAN-13 (gtin; non-ISBN)
PUB-ACME-8842   → Publisher number (freeform)
BIPAD123456     → BIPAD (freeform)
```

### Why keep `isbn` separate from `gtin`?

ISBN-10 uses mod-11 check-digit rules, not GTIN rules. It remains common on older stock, vendor files, and copyright pages. v0.04 stores ISBN-10 rows in the `isbn` family so ShelfStack can validate them correctly while still treating ISBN-13/EAN-13 as the canonical barcode form for **product** lookup and POS scan resolution (see [POS and lookup behavior](#pos-and-lookup-behavior)).

### Automatic ISBN alternates

ShelfStack should automatically maintain **paired ISBN-10 and ISBN-13/EAN-13 rows** for the same book product when conversion is possible.

General rules:

* The **primary identifier** for a book should be the **`gtin` ISBN-13/EAN-13** row whenever one exists.
* The alternate form should be stored as a **non-primary** row in the other family.
* Auto-created alternates should record `source` such as `isbn_converted`.
* Do not create duplicate rows for the same normalized value.

#### Enter ISBN-10 (`isbn` family)

When staff enter a valid ISBN-10:

```text
1. Validate mod-11 check digit
2. Create/update isbn row (non-primary unless this is the only identifier)
3. Convert to ISBN-13/EAN-13
4. Create/update gtin row for the converted ISBN-13
5. Set gtin ISBN-13 as primary
```

Example:

```text
Entered:
  isbn  0123456789

Stored:
  isbn   0123456789   primary: false   source: manual
  gtin   9780123456786 primary: true    source: isbn_converted
```

This matches current v0.03 behavior and remains the default intake path for legacy ISBN-10 entry.

#### Enter ISBN-13 / book EAN (`gtin` family)

When staff enter a valid 13-digit GTIN that is an ISBN-13 (`978…` or `979…`):

```text
1. Validate GTIN check digit
2. Create/update gtin row
3. Set gtin row as primary
4. If prefix is 978 and an ISBN-10 equivalent exists:
     create/update non-primary isbn row
5. If prefix is 979:
     do not create an ISBN-10 alternate
```

Example (`978…`):

```text
Entered:
  gtin  9780123456786

Stored:
  gtin   9780123456786 primary: true    source: manual
  isbn   0123456789   primary: false   source: isbn_converted
```

Example (`979…`):

```text
Entered:
  gtin  9798765432109

Stored:
  gtin   9798765432109 primary: true    source: manual
  (no isbn row; 979 cannot convert to ISBN-10)
```

#### Lookup behavior

POS and search lookup should treat either form as the same product:

```text
Scan or enter ISBN-10  → resolve via isbn row or gtin conversion candidate
Scan or enter ISBN-13  → resolve via gtin row or stored alternate
```

`lookup_candidates` should continue to derive cross-form matches even before alternates are persisted, but persisted alternates make audit history and staff-facing identifier lists explicit.

### House EAN-13 assignment (prefix 200–229)

v0.03 generated locals such as `L000000001`. v0.04 should assign **house EAN-13** codes for scannable store-created products — not ad hoc strings and **not UPC prefix `4`** (GS1 company prefix `4` is a North America UPC assignment; it is not a suitable global internal-EAN strategy and does not align with ISBN/EAN-13 as the canonical barcode form).

ShelfStack should use the **EAN prefix range 200–229**, reserved for internal / store-variable numbering in many retail and library implementations. House codes are stored and validated as **13-digit EAN-13** with a correct **EAN-13 check digit** (not UPC-A / 12-digit weighting).

#### Sequential, not random

Use a **sequential counter** per prefix segment (e.g. `…000000001`, `…000000002`), not random digits.

* **Avoid collisions** — random generation forces repeated database uniqueness checks and retries.
* **Predictable capacity** — one prefix segment supports up to **1 billion** codes (`000000000`–`999999999` in the variable portion).

`ProductIdentifierService` (or a dedicated allocator) should reserve the next sequence atomically per prefix segment.

#### Internal EAN segment policy (prefix 200–229)

ShelfStack uses the **EAN prefix range 200–229** for internally assigned scannable codes. Codes are stored as **13-digit EAN-13** with correct **EAN-13 check digit** (not UPC-A weighting).

**Namespace layout (authoritative as of v0.04-2):**

| Range | Purpose | Active in v0.04-2 |
| ----- | ------- | ----------------- |
| `20X` | Product-level identification | `201` = product house identifiers |
| `21X` | Variant / copy / unit-level identification | `211` = generated variant SKUs |
| `22X` | Operational series (gift certificates, store credits, claim tickets, buyback tickets, RTV authorizations) | Reserved — not generated |

Only **`201`** (product house) and **`211`** (variant SKU) are active in v0.04-2. All other segments are reserved for future milestones.

Example:

```text
2010000000014   # product house identifier
2110000000011   # generated variant SKU
```

`InternalEanAllocator` (or equivalent) reserves the next sequence atomically per segment via `internal_ean_sequences`.

#### Sequential, not random

House codes must use **EAN-13** check-digit weighting (alternating **1 and 3** on the 12-digit body). This differs from **UPC-A** (12-digit) weighting because of the extra leading digit — implementations must not reuse UPC-only check-digit logic for house EAN-13 generation.

External `gtin` identifiers (ISBN-13, EAN-13, UPC normalized to EAN-13) share the same EAN/GTIN family validation; `house` adds the constraint that the **company prefix** falls in 200–229.

#### House vs freeform

Prefer **`house`** when the item will be scanned at POS or receiving **as a product identifier** (ISBN/UPC substitute on the product). Use **`freeform`** only for non-scannable references (publisher numbers, BIPAD) that will never be label barcodes.

House EAN-13 rows are **product identifiers**, not variant SKUs. Variant SKUs are assigned separately (see [Variant SKUs](#variant-skus)).

### Stored fields

Each row should support:

```text
validation_family      # gtin | isbn | freeform | house
identifier_value       # display / entered value
normalized_identifier  # canonical lookup key
primary_identifier
valid_check_digit      # boolean or null for freeform
validation_message
active
source                 # manual | isbn_converted | local_generated | import | ...
```

Rules:

* A product may have **many** identifiers.
* Exactly one active identifier should be marked **primary** when identifiers exist.
* For book products with both forms, **`gtin` ISBN-13/EAN-13 is primary**; `isbn` ISBN-10 is alternate/non-primary.
* **GTIN-family values** (`gtin`, converted ISBN-13) must normalize to digits and enforce **global uniqueness** on `normalized_identifier`.
* **House EAN-13 values** (`house`) must normalize to 13 digits, use prefix **200–229**, pass EAN-13 check-digit validation, and enforce global uniqueness within the house family.
* **ISBN-10 values** (`isbn`) must normalize to 10-character ISBN form and enforce global uniqueness within the `isbn` family.
* **Freeform values** (`freeform`) normalize alphanumerically and enforce uniqueness on **`product_id + freeform_scope + normalized_identifier`** (not global — publisher numbers and vendor refs may repeat across products).
* **Do not store duplicate rows** for the same normalized value in the same family.
* **Automatic ISBN alternates** must stay in sync when either form is added or corrected.

Product identifiers answer:

```text
What commercial item is this?
What ISBN/UPC/barcode is printed on the package or copyright page?
How do we match imports, vendor files, and external catalog lookup?
```

They do **not** answer which used/new/signed copy is being sold. That remains variant grain.

Optional convenience: `products.sku` may remain as a **transitional/cache** copy of the primary normalized identifier for display, search, and legacy joins. It is **not** the source of truth for product lookup after v0.04-2 — `product_identifiers` is. It is **not** used to generate variant SKUs. New code must not treat `products.sku` as canonical except as an explicit legacy fallback during migration.

---

## Variant SKUs

Every product variant must have exactly one **required, unique** `product_variants.sku`. This is ShelfStack’s operational barcode/SKU for:

```text
POS lines
inventory ledger entries
stock balances
purchase order lines
receipt lines
customer demand
reservations / allocations
buyback-created used variants
```

Variant SKUs answer:

```text
Which exact ShelfStack variant is being sold, reserved, received, or adjusted?
```

### Generation rules

**Variant SKUs are system-assigned at variant creation.** They do **not** derive from product identifiers, `products.sku`, condition codes, or attribute suffixes. An ISBN or UPC identifies the **product**; the variant SKU identifies the **exact sellable form** (new, used, signed, etc.) as a distinct operational record.

When staff create a variant, `ProductVariants::SkuAllocator` (successor to suffix-based `SkuGenerator`) allocates the next SKU automatically from internal EAN segment **`211`**.

**Resolved in v0.04-2:** variant SKUs use **system-generated EAN-13** from segment `211`, distinct from product house segment `201`.

Rules:

* Variant SKUs must be **globally unique** across all variants.
* Variant SKUs must **not** be reused across variants, even after inactivation, unless an explicit reuse policy is added later.
* **Product identifier scans at POS** resolve to the product; if multiple active variants exist, staff must disambiguate. Scanning the ISBN on the book does not identify which used/signed copy is being sold unless only one variant matches or staff scan the variant’s own label.
* Buyback- and intake-created used variants receive a **new system-assigned SKU**, not an ISBN-derived suffix.

Example:

```text
Product:
- North Woods hardcover
- Primary identifier: 9781643751234

Variants (SKUs system-assigned from segment 211; illustrative):
- New hardcover
  SKU: 2110000000042
- Used hardcover
  SKU: 2110000000043
- Signed hardcover
  SKU: 2110000000044
```

---

## Variant lookup codes (manual POS aliases)

Some variants — especially café items, services, modifiers, and unlabeled sidelines — need **short staff-entered POS codes** that are not product identifiers and not canonical variant SKUs.

Examples: `LATTE`, `COF`, `101`.

ShelfStack stores these as `product_variant_lookup_codes` (variant grain). They resolve at POS **after** variant SKU match and **before** product identifier match.

v0.04-2 introduces the model, service, basic assignment, and POS resolution. Polished café/menu UI defers to v0.04-4+.

---

## What does not belong in `product_identifiers`

ShelfStack should not introduce a polymorphic `identifiers` table spanning unrelated entities.

Keep these concepts on their existing domain records:

| Concept | Where it lives |
| ------- | -------------- |
| Product ISBN / UPC / local code | `product_identifiers` |
| Vendor item number | `product_vendors`, `product_variant_vendors` |
| Gift card / stored value code | stored value identifier system |
| Display location code | `display_locations` |
| Legacy import cross-reference | import/staging tables if needed |

This keeps lookup rules, permissions, and audit behavior explicit.

---

## POS and lookup behavior

POS, receiving, inventory adjustment, and item lookup should resolve scans in this order:

```text
1. Exact match on product_variants.sku
2. Exact match on active product_variant_lookup_codes.normalized_code
3. Exact match on active product_identifiers.normalized_identifier
4. Cross-form ISBN candidates (ISBN-10 ↔ ISBN-13)
5. If exactly one active variant matches → add/select that variant
6. If multiple active variants match → disambiguation prompt
7. Text search → product/variant name or SKU prefix search
```

`products.sku` is a legacy/cache field only — not a primary scan path after v0.04-2 except as an explicit documented fallback during migration.

### Scan variant SKU or sticker

```text
Scan 2110000000043
→ Used hardcover variant (system-assigned variant SKU on shelf label)
→ add used hardcover to cart
```

### Scan product identifier

When the scan matches a product identifier and only one active variant exists, POS should select it directly.

```text
Scan 9781643751234
→ North Woods hardcover
→ only New hardcover is active
→ add new hardcover to cart
```

When multiple active variants share the same product, POS must prompt for the correct variant. Scanning the ISBN on a used book does not identify the used copy unless only one variant matches or staff scan the variant’s system-assigned SKU on its label.

```text
Scan 9781643751234
→ North Woods hardcover
→ Choose:
   - New hardcover
   - Used hardcover
   - Signed hardcover
```

### Completed line snapshots

Completed POS and operational documents should continue to snapshot both layers:

```text
primary product identifier (when present)
variant SKU
product name
variant name
```

---

## Migration note

v0.04 should **rename and re-home**, not generalize away, the current identifier model:

```text
catalog_item_identifiers  →  product_identifiers
catalog_item_id           →  product_id
identifier_type           →  validation_family (gtin | isbn | freeform | house)
isbn10 rows               →  isbn
isbn13 / ean / upc / gtin →  gtin
publisher_number / local  →  freeform (legacy L... → freeform_scope legacy_local; new scannable locals → house 201)
P... transitional SKU     →  freeform legacy_product_sku (v0.04-1); not house
```

Retire separate stored subtypes (`isbn13`, `ean`, `upc`, `gtin`, `publisher_number`, `local`) in favor of validation families plus inferred display labels.

Preserve and extend current identifier behavior:

```text
ISBN-10 entry  → auto-create primary gtin ISBN-13 (existing)
ISBN-13 entry  → auto-create non-primary isbn when 978-convertible (new)
GTIN check-digit validation, SKU generation, and POS ambiguity behavior unchanged in spirit
```

---

# 4. Used Product Rules

Used products are central to bookstore workflows and need explicit rules.

## Core rule

Used product variants are:

```text
customer-reservable
sellable if available
not vendor-orderable
not part of normal purchase order sourcing
```

A used variant may satisfy customer demand only from existing stock or future used intake.

## Used variant example

```text
Product:
- North Woods hardcover, ISBN 978...

Variants:
- New hardcover
  vendor_orderable: true
  customer_reservable: true

- Used hardcover
  vendor_orderable: false
  customer_reservable: true
  replenishment_strategy: used_acquisition_only
```

## Used customer workflow

If a used copy is available:

```text
Customer wants used copy
→ reserve on-hand used variant
→ mark ready for pickup or hold
```

If a used copy is not available:

```text
Customer wants used copy
→ do not create a purchase order
→ create a used wanted / notify request
→ match request when used stock later enters through buyback, trade-in, consignment, donation, or manual intake
```

If the customer is willing to accept a new copy instead, staff may create a separate demand line for the new vendor-orderable variant.

ShelfStack should not automatically convert unavailable used demand into a new product order.

---

# 5. Ordering Workflow Redesign

## Current issue

The current ordering workflow has several overlapping concepts:

```text
special orders
customer requests
purchase requests
TBO lines
PO line allocations
receipt line allocations
inventory reservations
```

These concepts are individually useful, but together they create workflow fragmentation. ShelfStack needs a unified model that separates customer/store demand from vendor ordering and inventory posting.

## New ordering model

ShelfStack v0.04 should model the full process as a demand-to-fulfillment pipeline:

```text
Interest / Consideration
  → Demand
    → Allocation / Reservation
      → Sourcing Attempt
        → Vendor Response
          → Purchase Order / Vendor Order
            → Receiving
              → Inventory Posting
                → Fulfillment
```

The guiding principle:

```text
Customer orders create demand.
Demand is allocated to stock or supply.
Supply documents execute vendor and receiving workflows.
Inventory changes only through source-document posting.
```

---

# 6. Stock Considerations

Not every customer question or staff idea should become an order.

ShelfStack should support lightweight stock considerations or buying notes.

Examples:

```text
Customer asked about a title but did not order it
Staff thinks the store should carry an item
A local event may create demand
A title is missing from a section
A buyer wants to review a possible purchase
```

A stock consideration does not reserve stock, create a PO, or affect inventory. It feeds a buyer review queue.

Possible statuses:

```text
open
reviewing
converted_to_demand
dismissed
duplicate
already_carried
```

---

# 7. Demand

Demand is the central concept in the new workflow.

A demand line records that ShelfStack has identified a need for a product variant.

Demand answers:

```text
What do we need?
How many?
Why do we need it?
For whom or for what purpose?
By when?
```

Demand sources may include:

```text
customer_order
manual_tbo
sales_replenishment
buyer_decision
frontlist_import
promotion
event
inventory_replacement
used_wanted_request
```

Demand purposes may include:

```text
customer_fulfillment
shelf_replenishment
frontlist_stock
display_stock
event_stock
preorder_fulfillment
backorder_fulfillment
replacement
```

Demand does not directly mutate inventory.

---

# 8. Allocations and Reservations

Demand may be allocated to available or expected supply.

Allocation answers:

```text
What stock or inbound supply is this demand tied to?
How much is claimed?
Can it be released?
What happens if the source fails?
```

Allocation types may include:

```text
on_hand
inbound_purchase_order
draft_receipt
vendor_backorder
waitlist
preorder
used_wanted
```

Examples:

```text
Customer wants a book and one is on hand
→ demand allocated to on-hand variant

Customer wants a book already on PO
→ demand allocated to inbound PO quantity

Customer wants a used copy not on hand
→ demand cannot enter vendor sourcing
→ used wanted request remains open
```

---

# 9. Vendor Sourcing and Vendor Responses

Supplier availability should not be treated as guaranteed before ordering.

For many bookstore workflows, true availability is only learned after a vendor order attempt or vendor acknowledgement.

ShelfStack should model sourcing as a sequence of attempts and responses.

```text
Demand
→ sourcing run
→ sourcing attempt
→ vendor response
→ confirmed / backordered / canceled / unavailable quantity
→ cascade unresolved quantity if needed
```

Sourcing attempts may include:

```text
primary wholesaler
secondary warehouse
alternate distribution center
alternate wholesaler
publisher direct
manufacturer direct
buyer review
```

Vendor responses should distinguish:

```text
quantity_requested
quantity_confirmed
quantity_backordered
quantity_canceled
quantity_unavailable
quantity_substituted
expected_ship_date
expected_arrival_date
vendor_reference
vendor_message
```

Confirmed quantity becomes inbound supply. Backordered quantity remains pending if acceptable. Canceled or unavailable quantity returns to the sourcing queue or cascades to another source.

---

# 10. Purchase Orders

Purchase orders remain vendor-facing operational documents.

They answer:

```text
What did we ask this vendor to supply?
At what cost?
Under what terms?
What did the vendor confirm?
What remains unresolved?
```

PO lines should continue to point to product variants.

```text
purchase_order_lines.product_variant_id
```

But PO line quantities should be more explicit than before.

Recommended PO line quantity fields:

```text
quantity_requested
quantity_confirmed_by_vendor
quantity_backordered_by_vendor
quantity_canceled_by_vendor
quantity_cascaded
quantity_received_from_vendor
quantity_accepted_to_stock
quantity_rejected
quantity_closed_short
```

A PO line should not be treated as confirmed inbound stock simply because the store requested it. Vendor response matters.

---

# 11. Receiving

Receiving records what physically arrived and what was accepted into stock.

Receiving must distinguish:

```text
expected quantity
physically received quantity
accepted-to-stock quantity
rejected quantity
damaged quantity
wrong item
substituted item
closed-short quantity
```

Only accepted quantity posts to inventory.

Fully rejected receipts should still be postable as operational records, even when they create no inventory ledger entries.

Receiving should also update demand allocations:

```text
accepted customer-allocated stock
→ convert inbound allocation to on-hand reservation
→ mark ready for pickup

short / rejected / canceled stock
→ release or requeue affected demand
```

---

# 12. Inventory Posting

Inventory remains source-document driven.

Inventory should change only through controlled posting workflows such as:

```text
receipt
POS sale
customer return
return to vendor
manual adjustment
transfer
buyback intake
```

Demand, customer orders, and sourcing attempts should not directly mutate inventory.

The existing architecture principle should remain:

```text
Source document
→ Inventory::Post
→ Inventory ledger entries
→ Inventory balances
```

---

# 13. POS Behavior

POS should sell at product variant grain.

A scanned variant SKU identifies the exact variant.

```text
Scan 2110000000043
→ Used hardcover variant (system-assigned SKU)
→ add used hardcover to cart
```

A scanned ISBN/UPC identifies the product and may require variant selection.

```text
Scan ISBN 978...
→ Product found
→ choose new / used / signed / damaged if multiple active variants exist
```

Completed POS lines should continue to snapshot:

```text
product identifier
variant SKU
product name
variant name
unit price
tax classification
inventory behavior
cost/COGS data where applicable
```

---

# 14. Practical Migration Direction

Because ShelfStack is not yet in production, v0.04 can make destructive structural changes instead of preserving every v0.03 table.

Recommended high-level changes:

## Preserve

```text
product variant as operational unit
inventory ledger/source-document architecture
stock balances
POS source document model
purchase order and receipt concepts
vendor profile concepts
classification/subdepartment/tax concepts
```

## Rebuild or replace

```text
catalog_items vs products separation
catalog_item_identifiers → product_identifiers
special orders
customer request lines
purchase request/TBO lines
PO line allocation model
receipt line allocation model
supplier availability assumptions
```

## Build new

```text
product groups / works
stock considerations
demand lines
demand allocations
sourcing runs
sourcing attempts
vendor responses
used wanted requests
availability snapshot service
```

---

# 15. Final Design Principle

ShelfStack v0.04 should use this model:

```text
Product = specific commercial item, edition, release, or manufactured item
Product Variant = specific store-facing sellable/stockable/orderable/reservable form
Product Identifier = external or local code that identifies the commercial product
Variant SKU = unique system-assigned operational code for the exact sellable form (not derived from product identifiers)
Demand = the store/customer need
Allocation = the claim against stock or supply
Sourcing = the attempt to satisfy unresolved demand
Receiving = the record of what arrived and what was accepted
Inventory Posting = the only way stock actually changes
```

This creates a cleaner foundation for bookstore workflows, especially around new/used product, ISBN/UPC scanning, variant-specific barcodes, special orders, vendor ordering, receiving, and POS.
