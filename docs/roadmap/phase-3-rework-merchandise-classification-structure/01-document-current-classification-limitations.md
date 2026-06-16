# Document current classification limitations and lock terminology

## Summary

Before changing schema, document the current classification model limitations and lock user-facing terminology.

The current `Department → Category → ProductVariant` structure is overloaded. `Category` currently carries product classification, pricing defaults, tax defaults, and implied reporting/accounting behavior. This issue captures the intended terminology and transitional meaning before deeper refactoring.

**Primary deliverable:** [transitional-domain-mapping.md](transitional-domain-mapping.md)

## Current limitation

Current effective model:

```text
Department → Category → ProductVariant
Product/ProductVariant → DisplayLocation
```

This forces several separate bookstore concepts into one path:

* accounting/reporting grouping
* merchandise behavior
* pricing defaults
* tax defaults
* topic/subject reporting
* display/merchandising location

Phase 2 seeds reinforce this overload: categories such as Hardcover, Used Paperback, and Gifts behave like **merchandise/format buckets**, not topic nodes like Biography or Fiction. The rework separates those concerns rather than renaming categories in place.

## Proposed terminology

Use these labels in documentation and UI during the transition:

| Current concept | Transitional product label |
| --------------- | -------------------------- |
| Department      | Reporting Department       |
| Category        | Merchandise Category       |
| DisplayLocation | Display Location           |

See [transitional-domain-mapping.md](transitional-domain-mapping.md) for the full entity mapping, default resolution order, and seed remapping guidance.

## Acceptance criteria

* [transitional-domain-mapping.md](transitional-domain-mapping.md) exists and explains why the current model is insufficient.
* Documentation clearly states that current `Category` is temporarily carrying merchandise defaults and is **not** the future topic taxonomy.
* Default resolution order is documented (variant override → accounting mapping → merchandise class → legacy category → legacy department).
* Transitional fate of `ProductVariant.category_id` is documented (required through Phase 3B; long-term decision deferred).
* Developer-facing terminology distinguishes:

  * merchandise behavior
  * topic/category classification
  * display location
  * accounting mapping
* Downstream docs listed in the mapping note are flagged for update (domain model, glossary, Phase 2/3 specs, ui-ux-concept, Ingram import spec, AGENTS.md).
* No schema change is required in this issue.
