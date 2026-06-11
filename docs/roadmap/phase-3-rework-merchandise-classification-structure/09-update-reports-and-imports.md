# Update reports and imports to support new classification layers

## Summary

Update reporting and import flows to use the new classification architecture where appropriate.

This should happen after merchandise classes and category schemes exist.

## Areas affected

- item imports
- catalog/product/variant creation
- sales summaries
- inventory reporting
- category/topic reports
- tax/default resolution
- future GL summaries
- future accounting exports

## Desired behavior

Imports and item creation should be able to suggest:

- merchandise class
- topic/category node
- display location
- accounting mapping

Reports should distinguish:

- merchandise class reporting
- topic/category reporting
- accounting/sales account reporting
- display/location reporting
- condition-based reporting

## Acceptance criteria

- Import flows can assign or suggest merchandise class.
- Import flows can assign or suggest category nodes where available.
- Reports do not assume one category means all classification types.
- Condition-sensitive reporting is possible.
- Existing reports remain functional during transition.