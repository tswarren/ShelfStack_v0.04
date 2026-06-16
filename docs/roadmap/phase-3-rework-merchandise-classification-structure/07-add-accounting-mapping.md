

# Add accounting mapping rules for sales and GL reporting

## Summary

Add configurable accounting/sales mapping rules so ShelfStack can derive sales reporting and GL buckets from merchandise class, condition, product type, category, and/or overrides.

## Why

A single `Department#gl_account_code` is too limited for real bookstore reporting.

Examples:

```text
MerchandiseClass = General Trade Books + Condition = New  → New Book Sales
MerchandiseClass = Used Books + Condition = Used          → Used Book Sales
MerchandiseClass = Cafe                                   → Cafe Food & Beverage Sales
Product type = Ticket                                     → Ticket Revenue
Product type = Shipping                                   → Shipping/Postage
```

## Suggested concept

`AccountingMapping` or `SalesAccountMapping`

Possible inputs:

* merchandise class
* condition
* product type
* category scheme/category node
* tax category
* explicit product/variant override

Possible output:

* sales account code
* reporting bucket
* GL export code
* description

## Acceptance criteria

* Mapping model exists.
* Store/admin users can define basic mappings.
* System can resolve a mapping for a product variant.
* New vs used variants can map to different sales buckets.
* Missing mappings are reported clearly.
* No full GL export is required in this issue.
