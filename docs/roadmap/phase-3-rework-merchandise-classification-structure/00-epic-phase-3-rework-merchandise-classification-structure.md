Below are ready-to-paste GitHub issue drafts. I’d structure this as **one parent epic** plus **nine child issues**.

---

# Rework merchandise classification architecture

## Summary

ShelfStack’s current merchandise setup is too linear for real bookstore operations.

The current model effectively uses:

```text
Department → Category → ProductVariant
Product/ProductVariant → DisplayLocation
```

This works for a simple setup, but it overloads `Category` with too many responsibilities. Today:

* `Department` owns many `Category` records and includes `gl_account_code`, so it is partly acting as a reporting/accounting bucket.
* `Category` belongs to `Department`, belongs to a default tax category, and stores pricing defaults such as pricing model, margin target, and supplier discount.
* `ProductVariant` belongs to one `Category`, one optional `Condition`, and one optional `DisplayLocation`.
* `DisplayLocation` is its own hierarchy, but it is conceptually a merchandising/location concept rather than an intrinsic product classification.

This means `Category` is currently being used for product grouping, pricing defaults, tax defaults, sales reporting, and implied accounting behavior. That does not fully represent how real bookstores classify, price, tax, report, and merchandise inventory.

## Business problem

Bookstores classify merchandise along several overlapping but distinct dimensions:

1. **Accounting / GL classification**
   How sales should roll up for bookkeeping, such as New Book Sales, Used Book Sales, Cafe Sales, Ticket Revenue, Shipping, or Other Income.

2. **Merchandise behavior**
   How the item behaves operationally: list price behavior, vendor discounting, markup from cost, returnability, buyback eligibility, default pricing model, and default tax treatment.

3. **Topic / subject classification**
   What the item is about or how it should be analyzed by subject, such as Biography, Fiction, History / Military, Religion / Bibles, Stationery, Games, or Cafe / Bakery.

4. **Format / material type**
   Book, periodical, recorded music, DVD/video, sideline, cafe item, ticket, shipping, service, digital item, etc.

5. **Condition**
   New, used, remainder, damaged, collectible, etc. Condition may change pricing, buyback, accounting, and reporting behavior.

6. **Display / merchandising location**
   Where the item is normally shelved or temporarily featured, such as Biography, Endcap, Staff Picks, Front Table, Sale Cart, Holiday Display, or Event Table.

These dimensions are related, but they are not interchangeable.

Example: a new hardcover biography and a used hardcover biography are both **Biography** as a topic. But the new copy may report to **New Book Sales**, while the used copy may report to **Used Book Sales**. They may also have different pricing, buyback, returnability, and accounting behavior.

## Proposed direction

Separate the overloaded category concept into clearer classification layers:

| Concept             | Purpose                                                                                                                                            |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Department`        | Broad reporting/accounting grouping.                                                                                                               |
| `MerchandiseClass`  | Operational merchandise behavior: pricing, tax defaults, returnability, list-price behavior, buyback eligibility, and default accounting behavior. |
| `CategoryScheme`    | A named category tree or classification system.                                                                                                    |
| `CategoryNode`      | A category inside a scheme, such as Biography, Fiction, Cafe / Bakery, or ABA / Used Book Sales.                                                   |
| `Categorization`    | Assignment of a catalog item, product, or variant to a category node.                                                                              |
| `DisplayLocation`   | Physical or promotional merchandising location.                                                                                                    |
| `AccountingMapping` | Configurable mapping from merchandise class, condition, category, product type, and/or overrides to GL/reporting buckets.                          |

## Key concept: MerchandiseClass

`MerchandiseClass` should answer:

> How does this sellable item behave operationally?

Examples:

* General Trade Books
* Pro/Sci/Tech Books
* Used Books
* Bargain / Remainder Books
* Periodicals
* Recorded Music / Video / Games
* Sidelines
* Cafe
* Shipping
* Tickets
* Donations

It should own or provide defaults for:

* has list price
* vendor discounts from list price
* store marks up from cost
* vendor returnable
* used sales / buyback eligibility
* default pricing model
* default margin target
* default supplier discount
* default tax category
* default sales/accounting bucket

## Key concept: CategoryScheme / CategoryNode

`CategoryScheme` represents a named classification system.

`CategoryNode` represents one category inside that scheme.

Examples:

### CategoryScheme: Bookstore Topics

* Fiction
* Biography
* History

  * Military History
  * U.S. History
  * World History
* Religion

  * Bibles
  * Christianity
  * Judaism
* Travel

  * Domestic
  * International

### CategoryScheme: Nonbook Sections

* Stationery
* Games
* Toys
* Food
* Recorded Music
* DVD

### CategoryScheme: ABA / Financial Reporting

* Total Book Sales

  * New Book Sales
  * Used Book Sales
* Total Non-Book Sales

  * Cafe Food & Beverage Sales
  * Other Non-Book Sales
* Event Proceeds

  * Ticket Revenue
  * Book Club

## User experience goal

The internal model may be more sophisticated, but the store-facing UI should remain simple.

Users should maintain:

* **Merchandise Classes** = how things behave
* **Sections & Topics** = what things are
* **Display Locations** = where things go
* **Sales Account Mapping** = where totals report

During item entry and import, ShelfStack should suggest sensible defaults and require users to handle exceptions only when necessary.

## Suggested implementation plan

This should be implemented as a multi-step architecture refactor, not a single feature ticket.

**Start here:** [transitional-domain-mapping.md](transitional-domain-mapping.md) — entity mapping, resolution order, and seed remapping guidance (issue 01).

1. Document current limitations and lock terminology.
2. Add `MerchandiseClass`.
3. Associate existing categories with merchandise classes.
4. Move pricing/tax/default behavior toward merchandise classes.
5. Add `CategoryScheme`, `CategoryNode`, and `Categorization`.
6. Update item/product/variant forms with classification summaries.
7. Add accounting/sales account mapping.
8. Add bookstore setup templates and seed defaults.
9. Update reports/imports to use the new classification layers.

## Out of scope for the first slice

* Full GL export implementation
* Full BISAC automation
* Public/web browse category management
* Temporary display placement history
* Complete migration of all reports
* Removing the existing `Category` model immediately

---

# Suggested labels

```text
architecture
domain-model
inventory
catalog
reporting
setup
refactor
```

# Suggested milestone

```text
Phase 3B — Classification Architecture
```

# Suggested implementation order

```text
1. Document terminology and limitations
2. Add MerchandiseClass
3. Link Category to MerchandiseClass
4. Move defaults toward MerchandiseClass
5. Add CategoryScheme / CategoryNode / Categorization
6. Update item/variant forms
7. Add accounting mappings
8. Add setup templates
9. Update reports/imports
```

## Core message for developers

> This is not “add more fields to Category.”
>
> This is a domain-model correction. Category currently means too many things. We need to separate merchandise behavior, topical categorization, display location, and accounting mapping so bookstores can maintain accurate defaults, reporting, and GL summaries without making item entry harder.
