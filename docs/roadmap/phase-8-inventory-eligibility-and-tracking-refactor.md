# Phase 8: Inventory Eligibility and Tracking Refactor

> **Status:** Phase 8 **complete** (8-1 through 8-5, 2026-06-23).
>
> **Primary code surface:** Inventory posting eligibility, POS inventory posting, buyback eligibility, inventory lookups, and item setup terminology.
>
> **MVP center:** Centralize the inventory posting gate around `inventory` / `non_inventory` tracking while preserving current behavior.
>
> **Naming:** Service `Inventory::TrackingResolver` · Gate `Inventory::Eligibility` · UI term “Inventory / Non-Inventory”.

## Purpose

Phase 8 simplifies how ShelfStack determines whether a product variant participates in stock tracking.

Today, `product_variants.inventory_behavior` mixes several concepts:

* physical inventory tracking
* digital asset behavior
* future dropship behavior
* service/capacity behavior
* financial/liability behavior
* non-inventory behavior
* future composite/recipe behavior

However, Phase 4–7 inventory posting behavior only needs one operational question:

> Does this variant use the stock ledger?

Today, the answer is effectively:

```text
inventory_behavior == "standard_physical"
````

Phase 8 introduces a clearer inventory tracking model:

```text
inventory
non_inventory
```

The initial implementation is behavior-neutral. It does not change which variants post to inventory. It only centralizes and renames the eligibility decision so later phases can safely introduce product defaults, variant overrides, cleaner UI, COGS snapshots, and future fulfillment workflows.

Phase 8 does not remove `inventory_behavior` immediately. The legacy column remains in place during transition, and `Inventory::TrackingResolver` maps legacy values to the new tracking language.

---

## Phase Placement

This initiative becomes **Phase 8** in the ShelfStack roadmap.

The existing Phase 8, Reporting and Accounting, becomes **Phase 9** when Phase 8 documentation lands.

Phase 8 is intentionally positioned after Phase 7 customer demand work because inventory reservations, buybacks, receiving, POS posting, customer requests, and special orders all depend on a consistent stock eligibility decision.

### Internal Slices

| Slice   | Focus                                               | Status        |
| ------- | --------------------------------------------------- | ------------- |
| **8-1** | `Inventory::TrackingResolver` + central eligibility | Complete |
| **8-2** | Replace direct gates; docs + tests                  | Complete |
| **8-3** | Product defaults + variant overrides                | Complete |
| **8-4** | UI cleanup: Inventory / Non-Inventory               | Complete |
| **8-5** | POS COGS / operational margin subsystem             | Complete |

> **Note:** Phase 8-5 is downstream operational margin work that depends on inventory cost basis. It is not part of the Phase 8 tracking refactor and is not full GL export. Full accounting/reporting remains Phase 9.

---

## ShelfStack Fit Review

This section records how Phase 8 aligns with the current ShelfStack codebase.

### Where it fits

| Surface                    | Fit         | Notes                                                                                                 |
| -------------------------- | ----------- | ----------------------------------------------------------------------------------------------------- |
| **Inventory posting**      | **Primary** | All stock ledger mutations should flow through `Inventory::Eligibility`.                              |
| **POS inventory posting**  | **Primary** | POS should use transaction snapshots first, variant fallback second, then resolve inventory tracking. |
| **Purchasing / receiving** | **Primary** | Receipt posting remains inventory-only in Phase 8-1/8-2.                                              |
| **Buybacks**               | **Primary** | Buyback remains dual-gated by condition, subdepartment, inventory eligibility, and active variant.    |
| **RTV / adjustments**      | **Primary** | These continue to require inventory eligibility.                                                      |
| **Items workspace**        | Secondary   | Phase 8-1/8-2 may expose clearer labels later, but UI cleanup is deferred.                            |
| **Add Item wizard**        | Secondary   | Current behavior mapping remains during 8-1/8-2; product defaults are deferred.                       |
| **Reporting / accounting** | Deferred    | POS COGS and margin reporting are Phase 8-5 or later.                                                 |

### Reuse existing ShelfStack building blocks

Do **not** introduce parallel inventory posting rules when these already exist:

| Existing component                               | Phase 8 use                                                                         |
| ------------------------------------------------ | ----------------------------------------------------------------------------------- |
| `Inventory::Eligibility`                         | Remains the authoritative mutation gate for inventory posting.                      |
| `Inventory::Post`                                | Continues creating ledger entries and updating balances only for eligible variants. |
| `ProductVariant#inventory_behavior`              | Legacy storage field used by the resolver during transition.                        |
| `Pos::PostInventory`                             | Uses snapshot-first eligibility resolution.                                         |
| `Buybacks::Eligibility`                          | Keeps buyback-specific rules; replaces only the direct tracking check.              |
| `AddItem::InventoryBehaviorMapper`               | Continues seeding legacy behavior in 8-1/8-2.                                       |
| Inventory ledger `movement_type` / `cost_source` | Remains source-of-truth for how stock entered or left inventory.                    |

---

## Problem

`product_variants.inventory_behavior` currently combines inventory tracking, fulfillment semantics, financial semantics, and future workflow concepts.

The current enum-like behavior list includes values such as:

```text
standard_physical
digital_asset
drop_ship
composite_recipe
capacitated_service
pure_financial
non_inventory
```

But Phase 4–7 posting logic effectively treats only one value as ledger-eligible:

```text
standard_physical
```

This creates several problems:

1. The field name suggests more behavior than inventory posting actually supports.
2. Direct string comparisons appear in multiple services.
3. Future concepts such as dropship, digital fulfillment, service capacity, and financial treatment are stored as if they were inventory tracking types.
4. POS snapshots store legacy behavior values, which must remain readable.
5. Future product defaults and variant overrides need a simpler foundation.
6. Future COGS/margin work needs to build on inventory tracking without conflating it with pricing or fulfillment.

---

## Design Principles

Phase 8 follows these agreed principles:

| Principle                                   | Decision                                                                                         |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Inventory tracking is the ledger gate       | The core distinction is `inventory` vs `non_inventory`.                                          |
| Inventory source is workflow-driven         | Source comes from receipt, buyback, adjustment, transfer, POS sale/return, not from the variant. |
| Do not persist inventory source on variants | Use ledger `movement_type` and `cost_source` as source-of-truth.                                 |
| Keep `inventory_behavior` during transition | Do not drop or rename the column in Phase 8-1/8-2.                                               |
| Behavior-neutral first                      | The same variants must post or not post exactly as before.                                       |
| Keep pricing separate                       | `pricing_model` and future `costing_method` are not the same concept.                            |
| Keep buyback dual-gated                     | Buyback eligibility remains condition + subdepartment + inventory tracking + active variant.     |
| Defer dropship workflow                     | Dropship is not a product type or inventory type; it is a future fulfillment workflow.           |
| Defer POS COGS                              | Phase 4–7 inventory cost basis is not sale-line COGS.                                            |
| Use compatibility mapping                   | Resolver must accept both legacy behavior strings and future tracking strings.                   |

---

## Target Architecture

### Phase 8-1 and 8-2

```text
ProductVariant.inventory_behavior
  → Inventory::TrackingResolver
  → Inventory::Eligibility
  → Inventory::Post / POS posting / receipt posting / buyback / RTV / adjustments
```

### Future Phase 8-3

```text
product_variants.inventory_tracking_override
  → legacy inventory_behavior mapping
  → products.default_inventory_tracking
  → product_type default
```

During migration, legacy variant behavior should remain safer than product-level inheritance. Product defaults should help seed new variants; they should not unexpectedly change existing variant behavior.

---

## MVP Scope vs Follow-up

Ship **Phase 8-1 and Phase 8-2** first.

### MVP: Phase 8-1 and 8-2

```text
8-1  Add Inventory::TrackingResolver
8-1  Update Inventory::Eligibility to use resolver
8-2  Replace direct "standard_physical" eligibility comparisons
8-2  Preserve POS legacy snapshot compatibility
8-2  Add resolver, eligibility, buyback, and POS tests
8-2  Add Phase 8 roadmap/spec/implementation docs
8-2  Update AGENTS.md and roadmap references
```

### Follow-up Backlog

Not required for Phase 8-1/8-2 completion:

* Product-level inventory tracking defaults
* Variant-level inventory tracking overrides
* UI replacement of raw `inventory_behavior` enum
* Add Item default seeding changes
* Inventory source hints in Items workspace
* Non-inventory receipt policy
* POS COGS snapshots
* Operational margin reports
* Future dropship workflow
* Removal of legacy `inventory_behavior`

---

## Decisions Locked

| Topic                    | Decision                                                                                          |
| ------------------------ | ------------------------------------------------------------------------------------------------- |
| Phase name               | Phase 8: Inventory Eligibility and Tracking Refactor                                              |
| Initial implementation   | Behavior-neutral resolver + eligibility refactor                                                  |
| Stored legacy field      | Keep `product_variants.inventory_behavior` in Phase 8                                             |
| Tracking terms           | `inventory` and `non_inventory`                                                                   |
| Ledger gate              | `Inventory::Eligibility` remains authoritative                                                    |
| Resolver                 | `Inventory::TrackingResolver` maps legacy and future values                                       |
| Legacy mapping           | `standard_physical` → `inventory`; all other legacy values → `non_inventory`                      |
| Product defaults         | Deferred                                                                                          |
| Variant overrides        | Deferred                                                                                          |
| Inventory source         | Workflow-driven; do not persist on variants                                                       |
| Source hints             | Deferred from 8-1/8-2                                                                             |
| Buyback source inference | `buyback_eligible` may imply trade-in expectation, but does not replace buyback eligibility rules |
| POS snapshots            | Continue storing legacy behavior strings in 8-1/8-2                                               |
| COGS                     | Deferred; new subsystem, not a rename of current inventory valuation                              |
| Non-inventory receipts   | Out of scope; receipt posting continues to require inventory eligibility                          |
| Roadmap renumber         | Existing Reporting and Accounting phase becomes Phase 9                                           |

---

## Open Decisions

Resolve before Phase 8-3 or later work.

| # | Decision                                                                                        | Recommendation                                                                  |
| - | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| 1 | Should product defaults be live inheritance or create-time seeding only?                        | Prefer create-time seeding; variant should remain operational authority.        |
| 2 | Should `inventory_tracking_override` be nullable override or required final value?              | Prefer nullable override during transition; consider final value later.         |
| 3 | Should non-inventory variants ever appear on purchase orders or receipts without stock posting? | Treat as separate product decision after 8-1/8-2.                               |
| 4 | Should UI expose legacy non-inventory behavior values to admins?                                | Hide from normal users; advanced/admin only if still needed.                    |
| 5 | Should COGS use ledger cost source, new costing fields, or both?                                | Define in Phase 8-5; do not conflate with `pricing_model`.                      |
| 6 | When should `inventory_behavior` be removed?                                                    | Only after resolvers, UI, snapshots, seeds, tests, and migrations are complete. |

---

## Goals

Phase 8 should provide a safer, clearer inventory eligibility foundation.

The primary goals are:

1. Introduce `Inventory::TrackingResolver`. **[MVP]**
2. Map legacy `inventory_behavior` values to `inventory` / `non_inventory`. **[MVP]**
3. Keep all Phase 8-1/8-2 behavior neutral. **[MVP]**
4. Update `Inventory::Eligibility` to use the resolver. **[MVP]**
5. Remove direct eligibility comparisons to `"standard_physical"` outside the resolver/eligibility layer. **[MVP]**
6. Keep POS legacy snapshots readable. **[MVP]**
7. Keep buyback eligibility dual-gated. **[MVP]**
8. Keep inventory source workflow-driven through ledger movements. **[MVP]**
9. Add tests for all legacy inventory behavior mappings. **[MVP]**
10. Add tests for POS snapshot compatibility. **[MVP]**
11. Document the transition path and roadmap renumbering. **[MVP]**
12. Prepare product defaults and variant overrides for a later slice. **[Deferred]**
13. Prepare UI terminology cleanup for a later slice. **[Deferred]**
14. Prepare POS COGS/margin reporting for a later subsystem. **[Deferred]**

---

## Non-Goals

Phase 8-1 and 8-2 do not include:

* Removing `product_variants.inventory_behavior`.
* Renaming database columns.
* Adding product-level inventory tracking defaults.
* Adding variant-level inventory tracking override fields.
* Changing Add Item wizard defaults.
* Changing which variants can post inventory.
* Allowing non-inventory receipt posting.
* Creating purchase/receipt history for non-inventory variants.
* Adding inventory source columns to products or variants.
* Adding source hint UI.
* Implementing dropship.
* Implementing service capacity workflows.
* Implementing digital fulfillment workflows.
* Implementing recipe/component inventory.
* Implementing POS COGS snapshots.
* Implementing operational margin reports.
* Implementing GL export.
* Changing `pricing_model` semantics.
* Conflating `pricing_model` with future `costing_method`.
* Rebuilding historical POS snapshots.
* Migrating old POS snapshot values.
* Reclassifying completed transactions.

---

## Major Capabilities

| Capability                 | Priority | Description                                                                                                     |
| -------------------------- | -------- | --------------------------------------------------------------------------------------------------------------- |
| Tracking resolver          | MVP      | Maps legacy and future values to `inventory` / `non_inventory`.                                                 |
| Central eligibility gate   | MVP      | `Inventory::Eligibility` becomes the single mutation gate for stock posting.                                    |
| Legacy compatibility       | MVP      | Existing `inventory_behavior` strings continue to work.                                                         |
| POS snapshot compatibility | MVP      | POS posting resolves legacy snapshots safely.                                                                   |
| Buyback eligibility update | MVP      | Buyback replaces direct `standard_physical` check with inventory tracking gate while retaining all other rules. |
| Direct gate cleanup        | MVP      | Remove direct eligibility comparisons to `"standard_physical"` from services.                                   |
| Documentation              | MVP      | Add Phase 8 roadmap/spec/implementation docs and update AGENTS/roadmap references.                              |
| Product defaults           | Deferred | Add product-level default tracking after MVP.                                                                   |
| Variant overrides          | Deferred | Add variant-level override after MVP.                                                                           |
| UI cleanup                 | Deferred | Replace raw behavior enum with Inventory / Non-Inventory language.                                              |
| POS COGS                   | Deferred | Add sale-line COGS snapshots and operational margin reporting later.                                            |

---

## Internal Phase Breakdown

Phase 8 is implemented as workstreams **8-1** through **8-5**.

Workstreams **8-1** and **8-2** are the implementation target for the first release.

---

## Phase 8-1: Inventory::TrackingResolver and Central Eligibility

> **MVP:** Implement now.
>
> **Schema changes:** None.
>
> **Behavior changes:** None intended.

### Purpose

Introduce a central resolver that translates current legacy inventory behavior strings into the new inventory tracking language.

This workstream does not change the database or user-facing behavior. It creates a compatibility layer so the rest of the application can ask:

```text
Is this inventory-tracked?
```

instead of asking:

```text
Is inventory_behavior exactly "standard_physical"?
```

### Includes

* New service: `Inventory::TrackingResolver`
* Legacy mapping from `inventory_behavior` values
* Boolean helper for inventory eligibility checks
* Compatibility for variants, tracking strings, and legacy behavior strings
* Update `Inventory::Eligibility` to use resolver
* Improved eligibility error message
* Tests for all legacy behavior mappings
* Tests for `Inventory::Eligibility`

### New Service

Add:

```text
app/services/inventory/tracking_resolver.rb
```

Recommended API:

```ruby
module Inventory
  class TrackingResolver
    INVENTORY_TRACKING = "inventory"
    NON_INVENTORY_TRACKING = "non_inventory"

    LEGACY_INVENTORY_BEHAVIORS = %w[standard_physical].freeze

    def self.resolve(value)
      # returns "inventory" or "non_inventory"
    end

    def self.resolve!(value)
      # strict version; raises on nil/unknown if needed later
    end

    def self.inventory?(value)
      resolve(value) == INVENTORY_TRACKING
    end

    def self.tracking_for_behavior(behavior)
      LEGACY_INVENTORY_BEHAVIORS.include?(behavior.to_s) ? INVENTORY_TRACKING : NON_INVENTORY_TRACKING
    end
  end
end
```

### Mapping

Explicit Phase 8-1 mapping:

| Legacy value          | Tracking result |
| --------------------- | --------------- |
| `standard_physical`   | `inventory`     |
| `digital_asset`       | `non_inventory` |
| `drop_ship`           | `non_inventory` |
| `composite_recipe`    | `non_inventory` |
| `capacitated_service` | `non_inventory` |
| `pure_financial`      | `non_inventory` |
| `non_inventory`       | `non_inventory` |

The resolver should also accept future tracking strings directly:

| Input           | Tracking result |
| --------------- | --------------- |
| `inventory`     | `inventory`     |
| `non_inventory` | `non_inventory` |

### Nil and unknown behavior

Fail closed.

| Input                       | Recommended behavior                          |
| --------------------------- | --------------------------------------------- |
| `nil`                       | `inventory?` returns false                    |
| unknown string              | `inventory?` returns false                    |
| `resolve!` with nil/unknown | may raise, if strict behavior is needed later |

### Inventory::Eligibility Update

Update:

```text
app/services/inventory/eligibility.rb
```

From:

```ruby
variant.inventory_behavior == "standard_physical"
```

To:

```ruby
Inventory::TrackingResolver.inventory?(variant)
```

The error message should include both the resolved tracking value and the legacy behavior value for support/debugging.

Example:

```text
Variant is not inventory-eligible. tracking=non_inventory inventory_behavior=digital_asset
```

### Primary question answered

> Can ShelfStack resolve stock eligibility using `inventory` / `non_inventory` terminology while preserving existing behavior?

### Exit Criteria

Phase 8-1 is complete when:

1. `Inventory::TrackingResolver` exists.
2. `standard_physical` resolves to `inventory`.
3. All other current legacy behavior values resolve to `non_inventory`.
4. Resolver accepts a product variant.
5. Resolver accepts a legacy behavior string.
6. Resolver accepts `inventory` and `non_inventory` directly.
7. Resolver fails closed for nil/unknown values.
8. `Inventory::Eligibility` uses the resolver.
9. Existing inventory posting behavior is unchanged.
10. Eligibility error messages include useful debug context.
11. Tests cover all seven current legacy inventory behavior values.
12. Tests cover `inventory?` with variants, legacy strings, future tracking strings, nil, and unknown input.
13. Existing inventory tests pass.

---

## Phase 8-2: Replace Direct Gates, Preserve POS Snapshots, and Document

> **MVP:** Implement now.
>
> **Schema changes:** None.
>
> **Behavior changes:** None intended.

### Purpose

Replace direct service-level comparisons to `"standard_physical"` with calls to the central resolver or eligibility gate.

This phase completes the behavior-neutral transition by ensuring inventory mutation paths and related operational services no longer hard-code legacy inventory behavior values.

### Includes

* Replace direct buyback tracking checks
* Replace direct POS tracking checks
* Preserve POS snapshot compatibility
* Keep receipt/RTV/adjustment behavior unchanged
* Add POS tests for snapshot values
* Add buyback tests for non-inventory variants
* Add roadmap/spec/implementation documentation
* Update AGENTS.md and roadmap references
* Add grep verification guidance

### Mutation Gate Rule

Use this rule for code changes:

```text
Inventory::TrackingResolver maps values.
Inventory::Eligibility remains the authoritative mutation gate.
```

Recommended usage:

| Area                | Preferred call                                                               |
| ------------------- | ---------------------------------------------------------------------------- |
| Inventory posting   | `Inventory::Eligibility`                                                     |
| Receipt posting     | `Inventory::Eligibility`                                                     |
| Adjustment posting  | `Inventory::Eligibility`                                                     |
| RTV posting         | `Inventory::Eligibility`                                                     |
| Buyback eligibility | Existing buyback rules + `Inventory::Eligibility` or resolver                |
| POS posting         | Snapshot-first tracking resolution, delegating to resolver/eligibility logic |
| Presenters/lookups  | Resolver can be used directly for display                                    |

### Call Sites to Change

| File                                    | Change                                                                                                         |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `app/services/buybacks/eligibility.rb`  | Replace direct `variant.inventory_behavior == "standard_physical"` with tracking resolver or eligibility gate. |
| `app/services/buybacks/resolve_item.rb` | Replace direct `standard_physical` check with tracking resolver or eligibility gate.                           |
| `app/services/pos/post_inventory.rb`    | Resolve snapshot first, variant fallback second, then gate via resolver.                                       |

### POS Snapshot Policy

Do not change snapshot write paths in Phase 8-1/8-2.

POS transaction lines continue storing legacy `inventory_behavior_snapshot` strings. The resolver must read those values compatibly.

For POS posting:

```ruby
tracking_input =
  line.inventory_behavior_snapshot.presence ||
  line.product_variant

Inventory::TrackingResolver.inventory?(tracking_input)
```

Rules:

| Situation                             | Behavior                      |
| ------------------------------------- | ----------------------------- |
| Completed line has snapshot           | Trust snapshot first.         |
| Draft/editable line lacks snapshot    | Fall back to current variant. |
| Snapshot is `standard_physical`       | Inventory posting allowed.    |
| Snapshot is any other legacy behavior | Inventory posting skipped.    |
| No variant                            | Inventory posting skipped.    |

### Buyback Eligibility Policy

Buyback remains dual-gated.

Existing rules stay intact:

```text
condition.buyback_eligible
sub_department.buyback_allowed
inventory eligible
variant active
```

Only the tracking check changes implementation.

Do **not** replace buyback eligibility with condition logic alone.

### Receipt Behavior

Receipt posting remains inventory-only in Phase 8-1/8-2.

Do not introduce:

* non-inventory receipt posting
* non-stock purchase receipt history
* purchasing history for service/non-inventory items
* receipt lines that skip stock posting

Those are separate product/UX decisions.

### Documentation Targets

Create:

```text
docs/roadmap/phase-8-inventory-eligibility-and-tracking-refactor.md
docs/specifications/phase-8-inventory-eligibility-and-tracking-spec.md
docs/implementation/phase-8-1-8-2-completion.md
```

Update:

```text
AGENTS.md
docs/roadmap.md
docs/specifications/phase-4-inventory-foundation-spec.md
```

### AGENTS.md Updates

Add Phase 8 to Primary Documentation.

Add current development priority:

```text
Phase 8: Inventory Eligibility and Tracking Refactor
```

Clarify Phase 4 inventory eligibility:

```text
Inventory-eligible means Inventory::TrackingResolver resolves to inventory through Inventory::Eligibility.
```

### Roadmap Updates

Update:

```text
docs/roadmap.md
```

Add:

```text
Phase 8 — Inventory Eligibility and Tracking Refactor
```

Renumber:

```text
Reporting and Accounting → Phase 9
```

### Grep Verification

The acceptance criterion should not ban all mentions of `standard_physical`, because legacy mappers, seed data, tests, snapshot writers, and docs may still mention it.

The target is:

```text
No direct eligibility comparison to "standard_physical" outside TrackingResolver / Inventory::Eligibility.
```

Suggested verification:

```bash
rg 'inventory_behavior\s*==\s*["'\'']standard_physical|["'\'']standard_physical["'\'']\s*==\s*inventory_behavior' app test
```

Allowed references:

```text
Inventory::TrackingResolver
AddItem::InventoryBehaviorMapper
legacy snapshot writers
tests
seeds
docs
```

### Primary question answered

> Can ShelfStack remove duplicated inventory eligibility string checks while preserving legacy POS snapshots and current posting behavior?

### Exit Criteria

Phase 8-2 is complete when:

1. No inventory mutation service directly checks `inventory_behavior == "standard_physical"` outside the resolver/eligibility layer.
2. Buyback eligibility uses the new tracking gate while preserving condition/subdepartment/active checks.
3. Buyback item resolution uses the new tracking gate where applicable.
4. POS inventory posting resolves `inventory_behavior_snapshot` first.
5. POS inventory posting falls back to variant behavior when no snapshot exists.
6. POS inventory posting continues to skip non-inventory/digital/service/financial legacy behaviors.
7. Receipt posting behavior is unchanged.
8. RTV behavior is unchanged.
9. Adjustment behavior is unchanged.
10. Existing inventory, buyback, and POS tests pass.
11. New POS tests cover legacy snapshot values.
12. New buyback tests cover non-inventory tracking rejection.
13. Phase 8 roadmap document exists.
14. Phase 8 specification document exists.
15. Phase 8 implementation note exists after 8-1/8-2 completion.
16. AGENTS.md references Phase 8.
17. Roadmap renumbers Reporting and Accounting to Phase 9.
18. Phase 4 inventory spec cross-references the resolver implementation path.
19. Verification grep confirms no stray direct eligibility comparisons.
20. No database migrations are introduced in 8-1/8-2.

---

## Phase 8-3: Product Defaults and Variant Overrides

> **Deferred.**
>
> **Schema changes:** Yes.
>
> **Behavior changes:** Possible; requires careful migration and UI review.

### Purpose

Add product-level inventory tracking defaults and variant-level overrides once the resolver is established.

This allows ShelfStack to support easier item setup while preserving SKU-level operational control.

### Includes

* Product-level default inventory tracking
* Variant-level inventory tracking override or effective value
* Resolver update for defaults/overrides
* Backfill strategy
* Mixed-product reporting
* Add Item seeding updates
* Validation/reporting tools

### Proposed Schema

Add to `products`:

```text
default_inventory_tracking
```

Allowed values:

```text
inventory
non_inventory
```

Add to `product_variants`:

```text
inventory_tracking_override
```

Allowed values:

```text
inventory
non_inventory
```

Nullable during transition.

### Recommended Resolution Chain

Use this safer transition chain:

```text
variant.inventory_tracking_override
  → tracking_for_behavior(variant.inventory_behavior)
  → product.default_inventory_tracking
  → product_type default
```

This avoids product defaults accidentally overriding established variant-level legacy behavior.

### Product Defaults vs Variant Authority

Preferred long-term rule:

```text
Product default:
  Helps seed new variants.

Variant tracking:
  Determines actual SKU behavior.

Transactions:
  Snapshot what was true at the time.
```

Product default should not silently change existing variant behavior.

### Backfill Strategy

Recommended:

| Target                                       | Source                                      |
| -------------------------------------------- | ------------------------------------------- |
| Variant tracking override or effective value | Current `inventory_behavior` mapping        |
| Product default                              | Product type default                        |
| Mixed products                               | Report only; do not majority-rule normalize |

Avoid majority-rule backfill.

Do not set product defaults from “most variants are inventory” because mixed products may be intentional.

### Product Type Default Mapping

Suggested create-time defaults:

| Product type    | Default inventory tracking |
| --------------- | -------------------------- |
| `physical`      | `inventory`                |
| `digital`       | `non_inventory`            |
| `service`       | `non_inventory`            |
| `financial`     | `non_inventory`            |
| `non_inventory` | `non_inventory`            |

### Mixed Product Report

Add a validation/reporting task to flag products whose variants resolve to mixed tracking states.

Example:

```text
Product has inventory and non-inventory variants.
Review before setting product-level default.
```

### Primary question answered

> Can ShelfStack support product-level setup defaults without losing variant-level SKU accuracy?

### Exit Criteria

Phase 8-3 is complete when:

1. Product default inventory tracking field exists.
2. Variant inventory tracking override field exists or an equivalent final tracking field exists.
3. Resolver supports product defaults and variant overrides.
4. Existing legacy behavior still resolves safely.
5. Backfill preserves existing variant behavior.
6. Product defaults are seeded from product type, not majority variant behavior.
7. Mixed variant tracking products are reported for review.
8. Add Item can seed tracking defaults from product type/product default.
9. Existing inventory posting behavior is preserved unless intentionally changed.
10. Tests cover product defaults, variant overrides, legacy fallback, and mixed products.

---

## Phase 8-4: UI Cleanup — Inventory / Non-Inventory

> **Deferred.**
>
> **Depends on:** Phase 8-1/8-2; preferably Phase 8-3.

### Purpose

Replace user-facing raw `inventory_behavior` choices with the clearer Inventory / Non-Inventory concept.

The goal is to prevent users from treating dropship, service, digital, financial, and recipe behavior as inventory tracking choices.

### Includes

* Items workspace inventory tracking labels
* Add Item wizard tracking control
* Variant form cleanup
* Presenter/lookup updates
* Admin-only legacy behavior exposure if needed
* Optional inventory source hints
* Help text explaining inventory vs non-inventory

### Items Workspace

Show a clear label:

```text
Inventory Tracking: Inventory
```

or:

```text
Inventory Tracking: Non-Inventory
```

Use `Inventory::TrackingResolver`.

### Variant Form

Replace normal-user raw enum control in:

```text
app/views/items/shared/variant_forms/_advanced.html.erb
```

with:

```text
Inventory tracking:
  Inventory
  Non-Inventory
```

Keep legacy `inventory_behavior` hidden or admin-only until removed.

### Lookup/Presenter Changes

Expose:

```text
inventory_tracking
```

alongside legacy:

```text
inventory_behavior
```

in client-facing payloads where needed.

Potential files:

```text
app/services/purchasing/line_lookup_presenter.rb
app/services/pos/line_lookup_presenter.rb
app/services/inventory/variant_lookup.rb
app/presenters/items/item_operations_presenter.rb
```

### Source Hints

Optional and display-only.

Examples:

| Condition / history        | Display hint              |
| -------------------------- | ------------------------- |
| Buyback-eligible condition | Usually trade-in          |
| Recent receipt history     | Supplier                  |
| Recent buyback history     | Trade-in                  |
| No ledger history          | Unknown / not yet stocked |

Do not persist source hints on variants.

### Primary question answered

> Can the UI describe inventory tracking in the language staff actually need without exposing unused or future behavior values?

### Exit Criteria

Phase 8-4 is complete when:

1. Items workspace displays Inventory / Non-Inventory labels.
2. Variant form no longer presents raw legacy behavior enum to normal users.
3. Add Item uses inventory tracking language.
4. Existing legacy behavior values remain readable.
5. Admin or support workflows can still inspect legacy behavior if needed.
6. POS and purchasing line lookup payloads expose inventory tracking.
7. Help text explains that inventory items use stock ledger and non-inventory items do not.
8. Dropship, service, digital, financial, and recipe concepts are not shown as inventory tracking choices.
9. Tests or system specs cover the updated form behavior.

---

## Phase 8-5: POS COGS and Operational Margin Subsystem

> **Deferred.**
>
> **New subsystem:** This is not a rename of existing inventory valuation.
>
> **Accounting scope:** Operational margin reporting only; full GL export remains Phase 9.

### Purpose

Add sale-time COGS snapshots and operational margin reporting after inventory tracking terminology is stable.

Phase 4–7 inventory costing supports management inventory valuation and ledger cost basis. It does not yet provide a full POS line COGS subsystem.

Phase 8-5 defines and implements how POS sales capture cost at sale time.

### Includes

* POS line COGS snapshot fields
* Inventory sale COGS from current cost basis
* Buyback/trade-in stock COGS from accepted offer / ledger basis
* Non-inventory item COGS policy
* Open-ring cost policy
* Gift card / financial no-COGS treatment
* Return/reversal COGS behavior
* Operational margin reports
* Tests for sales, returns, open-ring, non-inventory, and financial lines

### Candidate POS Fields

Add to `pos_transaction_lines` or a related COGS detail table:

```text
unit_cogs_cents
total_cogs_cents
cogs_source
costing_method_snapshot
revenue_treatment
```

### COGS Policy Questions

Resolve before implementation:

| Question                                     | Needed decision                                                |
| -------------------------------------------- | -------------------------------------------------------------- |
| When is COGS recognized?                     | At sale completion, fulfillment, or posting?                   |
| What cost basis is used for inventory items? | Moving average, receipt layer, manual standard cost, or other? |
| How are returns handled?                     | Reverse original COGS or use current cost?                     |
| How do open-ring lines get cost?             | Subdepartment policy, manual cost, no cost?                    |
| How do non-inventory services get cost?      | Manual, percent of price, no cost?                             |
| How are financial passthroughs reported?     | Clearing/liability, not merchandise margin.                    |
| How does COGS relate to `pricing_model`?     | Keep separate; map explicitly only where needed.               |

### Do Not Conflate With Pricing Model

`pricing_model` and `pricing_model_override` describe pricing/supplier semantics.

They should not become the COGS engine by default.

If a pricing model influences COGS, define an explicit mapping through a COGS policy resolver.

### Primary question answered

> Can ShelfStack report operational gross margin by sale line without confusing inventory tracking, pricing models, and accounting export?

### Exit Criteria

Phase 8-5 is complete when:

1. POS line COGS policy is documented.
2. Inventory sale lines snapshot unit and total COGS.
3. Used/trade-in sale lines snapshot appropriate cost basis.
4. Non-inventory sale lines use documented costing policy.
5. Gift card and financial lines do not create merchandise COGS.
6. Returns reverse or recalculate COGS according to documented policy.
7. Margin reports use POS COGS snapshots.
8. `pricing_model` remains separate from COGS policy.
9. Tests cover sales, returns, open-ring, non-inventory, gift card, and passthrough scenarios.
10. Full GL export remains deferred to Phase 9.

---

## Models Introduced

Phase 8-1 and Phase 8-2 introduce **no new database tables**.

### Phase 8-1/8-2

| Model/table                | Change                                                            |
| -------------------------- | ----------------------------------------------------------------- |
| `product_variants`         | No schema change; continue reading `inventory_behavior`.          |
| `pos_transaction_lines`    | No schema change; continue reading `inventory_behavior_snapshot`. |
| `inventory_ledger_entries` | No schema change.                                                 |
| `inventory_balances`       | No schema change.                                                 |

### Deferred Phase 8-3

Potential columns:

| Table              | Column                        | Purpose                                            |
| ------------------ | ----------------------------- | -------------------------------------------------- |
| `products`         | `default_inventory_tracking`  | Product-level default for new variants.            |
| `product_variants` | `inventory_tracking_override` | Variant-level tracking override during transition. |

### Deferred Phase 8-5

Potential POS COGS fields:

| Table                   | Column                    | Purpose                                            |
| ----------------------- | ------------------------- | -------------------------------------------------- |
| `pos_transaction_lines` | `unit_cogs_cents`         | Unit COGS snapshot.                                |
| `pos_transaction_lines` | `total_cogs_cents`        | Extended COGS snapshot.                            |
| `pos_transaction_lines` | `cogs_source`             | Source of COGS calculation.                        |
| `pos_transaction_lines` | `costing_method_snapshot` | Costing policy at transaction time.                |
| `pos_transaction_lines` | `revenue_treatment`       | Merchandise, service, liability, passthrough, etc. |

---

## Services Introduced

| Service                         | MVP | Purpose                                                                        |
| ------------------------------- | --- | ------------------------------------------------------------------------------ |
| `Inventory::TrackingResolver`   | Yes | Maps legacy behavior/future tracking values to `inventory` or `non_inventory`. |
| `Inventory::SourceHint`         | No  | Optional future display-only hint; not persisted.                              |
| `Inventory::CogsPolicyResolver` | No  | Future POS COGS policy resolver.                                               |

### Services Updated

| Service                            | Phase    | Change                                        |
| ---------------------------------- | -------- | --------------------------------------------- |
| `Inventory::Eligibility`           | 8-1      | Uses `Inventory::TrackingResolver`.           |
| `Buybacks::Eligibility`            | 8-2      | Replaces direct `standard_physical` check.    |
| `Buybacks::ResolveItem`            | 8-2      | Replaces direct `standard_physical` check.    |
| `Pos::PostInventory`               | 8-2      | Uses snapshot-first tracking resolution.      |
| `AddItem::InventoryBehaviorMapper` | Deferred | Continues setting legacy behavior in 8-1/8-2. |

---

## Key Design Decisions

### Inventory tracking is not fulfillment

Inventory tracking answers:

```text
Does this variant use stock ledger and on-hand quantity?
```

It does not answer:

```text
Is this digital?
Is this dropship?
Is this a service?
Is this financial?
Is this a recipe/composite item?
```

Those belong to future fulfillment, service, financial, or production workflows.

---

### Dropship is a workflow, not a product type

Dropship should not be modeled as a product type or inventory tracking type.

Future dropship support should be a fulfillment workflow:

```text
customer order
→ vendor fulfillment
→ supplier cost
→ no store stock ledger
```

No dropship workflow is implemented in Phase 8.

---

### Inventory source remains workflow-driven

Do not persist inventory source on product or variant records.

Actual source comes from the event that creates the ledger movement:

| Workflow        | Ledger signal                                                                     |
| --------------- | --------------------------------------------------------------------------------- |
| Receipt         | `movement_type: received`, `cost_source: receipt_cost`                            |
| Buyback         | `movement_type: used_buyback`, `cost_source: buyback_offer` / `no_value_donation` |
| Adjustment      | opening balance / manual adjustment movement                                      |
| Transfer        | transfer movement                                                                 |
| POS sale        | sale movement                                                                     |
| Customer return | return movement                                                                   |

Condition `buyback_eligible` may be used as a default expectation that a used condition often comes from trade-in, but it is not the authoritative source.

---

### Buyback remains dual-gated

Buyback eligibility is not only inventory tracking.

It remains:

```text
condition.buyback_eligible
sub_department.buyback_allowed
inventory eligible
variant active
```

Phase 8 changes only the inventory tracking leg.

---

### POS snapshots remain legacy-compatible

Completed POS lines may carry legacy `inventory_behavior_snapshot` values.

Phase 8-1/8-2 must continue reading those values correctly.

Do not migrate historical snapshots in the MVP.

---

### Receipt behavior remains inventory-only

Non-inventory receipt policy is explicitly out of scope.

In Phase 8-1/8-2:

```text
non-inventory variants still cannot post stock receipts
```

Any future support for ordering or receiving non-stock items without stock ledger impact needs a separate product decision.

---

### Pricing model is not costing method

`pricing_model` remains separate from future COGS/costing policy.

Do not rename `pricing_model` to `costing_method`.

Do not make POS COGS depend implicitly on `pricing_model` without an explicit policy mapping.

---

### Product defaults should not override existing variants

When product defaults are added later, they should support easier setup but not unexpectedly change existing SKU behavior.

Preferred model:

```text
Product default:
  create-time seed

Variant:
  operational authority

Transaction:
  snapshot at time of action
```

---

## Testing Strategy

### Phase 8-1 Tests

Add:

```text
test/services/inventory/tracking_resolver_test.rb
```

Cover:

* `standard_physical` → `inventory`
* `digital_asset` → `non_inventory`
* `drop_ship` → `non_inventory`
* `composite_recipe` → `non_inventory`
* `capacitated_service` → `non_inventory`
* `pure_financial` → `non_inventory`
* `non_inventory` → `non_inventory`
* direct input `inventory`
* direct input `non_inventory`
* variant input
* nil input
* unknown string input

Expand:

```text
test/services/inventory/eligibility_test.rb
```

Cover one non-eligible case per legacy behavior value.

### Phase 8-2 Tests

Add or expand:

```text
test/services/buybacks/eligibility_test.rb
test/services/buybacks/resolve_item_test.rb
test/services/pos/post_inventory_test.rb
```

POS snapshot tests:

| Scenario                                                            | Expected                |
| ------------------------------------------------------------------- | ----------------------- |
| snapshot `standard_physical`                                        | posts inventory         |
| snapshot `non_inventory`                                            | skips inventory         |
| snapshot `digital_asset`                                            | skips inventory         |
| no snapshot, variant `standard_physical`                            | posts inventory         |
| no snapshot, variant `non_inventory`                                | skips inventory         |
| return line with return-to-stock disposition and inventory snapshot | posts return movement   |
| return line without return-to-stock disposition                     | skips inventory posting |

Buyback tests:

| Scenario                                                                       | Expected |
| ------------------------------------------------------------------------------ | -------- |
| buyback-eligible condition + buyback-allowed subdepartment + inventory variant | eligible |
| non-inventory variant                                                          | rejected |
| buyback-ineligible condition                                                   | rejected |
| subdepartment not buyback allowed                                              | rejected |
| inactive variant                                                               | rejected |

### Verification Command

Run:

```bash
bin/rails test test/services/inventory/ test/services/buybacks/ test/services/pos/post_inventory_test.rb
```

Check direct comparisons:

```bash
rg 'inventory_behavior\s*==\s*["'\'']standard_physical|["'\'']standard_physical["'\'']\s*==\s*inventory_behavior' app test
```

Expected result:

```text
No direct eligibility comparisons outside TrackingResolver / Inventory::Eligibility.
```

---

## Acceptance Criteria: Phase 8-1 and 8-2

Phase 8-1 and 8-2 are complete when all of the following are true.

### Resolver and eligibility

1. `Inventory::TrackingResolver` exists.
2. Resolver maps `standard_physical` to `inventory`.
3. Resolver maps all other current legacy inventory behavior values to `non_inventory`.
4. Resolver accepts both legacy behavior strings and future tracking strings.
5. Resolver fails closed for nil/unknown values.
6. `Inventory::Eligibility` uses the resolver.
7. Inventory eligibility error messages include resolved tracking/debug context.

### Behavior neutrality

1. Same variants are inventory-eligible as before.
2. Same variants are inventory-ineligible as before.
3. Receipt posting behavior is unchanged.
4. RTV behavior is unchanged.
5. Adjustment behavior is unchanged.
6. POS inventory posting behavior is unchanged.
7. Buyback eligibility behavior is unchanged except for the implementation of the inventory tracking check.

### Direct gate cleanup

1. No direct eligibility comparison to `"standard_physical"` remains outside resolver/eligibility.
2. Buyback services use the new tracking gate.
3. POS posting uses the new tracking gate.
4. Lookup/presenter behavior remains compatible.

### POS snapshots

1. POS posting trusts `inventory_behavior_snapshot` first.
2. POS posting falls back to variant behavior when snapshot is blank.
3. Legacy snapshot values remain readable.
4. No historical snapshot migration is required.

### Documentation

1. `docs/roadmap/phase-8-inventory-eligibility-and-tracking-refactor.md` exists.
2. `docs/specifications/phase-8-inventory-eligibility-and-tracking-spec.md` exists.
3. `docs/implementation/phase-8-1-8-2-completion.md` exists after completion.
4. `docs/roadmap.md` adds Phase 8.
5. Reporting and Accounting is renumbered to Phase 9.
6. `AGENTS.md` references Phase 8 as current development priority.
7. Phase 4 inventory spec cross-references `Inventory::TrackingResolver` / `Inventory::Eligibility`.

### Tests

1. Resolver tests cover all legacy behaviors.
2. Eligibility tests cover inventory and non-inventory cases.
3. Buyback tests cover inventory tracking rejection.
4. POS tests cover legacy snapshot compatibility.
5. Existing inventory, buyback, POS, receiving, and adjustment tests pass.
6. No live external services or unrelated integration changes are introduced.

---

## Deferred Items

The following are intentionally deferred.

| Item                                          | Reason                                                                |
| --------------------------------------------- | --------------------------------------------------------------------- |
| Product default inventory tracking            | Requires schema and migration decisions.                              |
| Variant inventory tracking override           | Requires schema and UI decisions.                                     |
| Product default majority backfill             | Avoid; mixed products may be intentional.                             |
| Inventory source on variants                  | Source is workflow-driven and belongs to ledger movements.            |
| Inventory source hints                        | Useful UI later, but may expand scope.                                |
| UI replacement of raw inventory behavior enum | Should follow resolver and possibly schema cleanup.                   |
| Non-inventory receipt history                 | Separate purchasing/product decision.                                 |
| Dropship workflow                             | Fulfillment workflow, not inventory tracking.                         |
| Digital fulfillment workflow                  | Separate workflow.                                                    |
| Service capacity workflow                     | Separate workflow.                                                    |
| Composite/recipe inventory                    | Separate production/inventory design.                                 |
| POS COGS snapshots                            | New subsystem; not part of behavior-neutral refactor.                 |
| Operational margin reporting                  | Depends on POS COGS policy.                                           |
| GL export                                     | Phase 9 reporting/accounting.                                         |
| Removal of `inventory_behavior`               | Only after compatibility, UI, data, tests, and snapshots are handled. |

---

## Phase 8 Exit Criteria

Phase 8 as a whole is complete when all selected slices are complete.

For the initial implementation, Phase 8-1 and 8-2 are complete when the acceptance criteria above pass.

Full Phase 8 completion, including deferred slices, requires:

1. Inventory tracking terminology is `inventory` / `non_inventory` throughout the app.
2. All inventory mutation paths use the centralized tracking/eligibility gate.
3. Product defaults and variant overrides are implemented or explicitly rejected.
4. User-facing forms no longer expose raw legacy inventory behavior choices to normal users.
5. POS snapshot compatibility is preserved.
6. Historical records remain readable.
7. COGS/margin work is either implemented as Phase 8-5 or moved to a later documented phase.
8. `inventory_behavior` is either removed or formally retained as a legacy/internal field with documented purpose.
9. Documentation is updated across roadmap, specs, implementation notes, AGENTS, and relevant Phase 4–7 cross-references.

---

## Related Documents

```text
docs/roadmap.md
docs/roadmap/phase-4-inventory-foundation.md
docs/roadmap/phase-5-purchasing-and-receiving.md
docs/roadmap/phase-6-pos-foundation.md
docs/roadmap/phase-7a-customer-demand.md
docs/roadmap/phase-8-inventory-eligibility-and-tracking-refactor.md

docs/specifications/phase-8-inventory-eligibility-and-tracking-spec.md
docs/specifications/phase-8-test-plan.md

docs/implementation/phase-8-1-8-2-completion.md

AGENTS.md

app/models/product_variant.rb
app/services/inventory/eligibility.rb
app/services/inventory/post.rb
app/services/pos/post_inventory.rb
app/services/buybacks/eligibility.rb
app/services/buybacks/resolve_item.rb
app/services/purchasing/post_receipt.rb
app/services/purchasing/post_return_to_vendor.rb
app/services/add_item/inventory_behavior_mapper.rb
```