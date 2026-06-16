# Update item and variant forms with classification summary and defaults

## Summary

Update item/product/variant forms so users can maintain classification without seeing unnecessary model complexity.

The UI should not make users feel like they are managing several taxonomies during item entry. It should show a compact classification area and derived defaults.

## Desired item/variant form section

```text
Classification & Defaults

Merchandise Class: General Trade Books
Topic / Section: Biography
Condition: New
Home Display Location: Biography
````

Then show derived defaults:

```text
Defaults from General Trade Books:
Pricing: Discount from list
Tax: Taxable
Sales Account: New Book Sales
Returnable: Yes
Buyback eligible: Yes
```

## UX rules

* Day-to-day users should primarily choose:

  * merchandise class
  * topic/section
  * condition
  * display location
* Advanced pricing/accounting overrides should be hidden behind an advanced section.
* Defaults should be visible but not overwhelming.
* Missing mappings should produce warnings, not silent failures.

## Acceptance criteria

* Product/variant forms display a classification summary.
* Forms show derived defaults from merchandise class.
* Users can override where permitted.
* Missing merchandise class or accounting mapping is clearly flagged.
* Existing item creation flow remains usable.
