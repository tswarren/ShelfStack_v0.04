
# Move pricing and tax defaults from Category toward MerchandiseClass

## Summary

Begin moving pricing, taxation, and operational default behavior away from `Category` and toward `MerchandiseClass`.

Currently, `Category` stores defaults such as pricing model, margin target, supplier discount, and default tax category. These are better represented as merchandise behavior defaults.

## Current problem

A subject/category like “Biography” or “History” should not be responsible for determining whether an item:

- has a list price
- uses vendor discount from list
- uses markup from cost
- is taxable
- is returnable
- supports used buyback
- maps to a sales account

Those defaults belong to a broader operational merchandise class.

## Desired behavior

When a product variant is assigned to a category, the system can derive defaults from:

```text
variant → category → merchandise_class
```

Later, variants may support direct overrides.

## Acceptance criteria

* Pricing/tax defaults can be resolved from `MerchandiseClass`.
* Existing `Category` defaults remain backward-compatible during transition.
* Product/variant form shows derived defaults clearly.
* Tests cover default resolution order.
* Documentation states the intended future source of truth for pricing/tax defaults.
