# Phase 4: Inventory Foundation

## Purpose

Phase 4 establishes ShelfStack’s inventory ledger and store-level balance foundation.

It answers:

What quantity of each product variant does each store currently have, how did that quantity change, and what is its current estimated value?

Phase 4 is the first true inventory phase. It does not implement purchasing, receiving, POS sales, used buybacks, consignment intake, or inter-store transfer workflows. Instead, it creates the ledger, posting, balance, adjustment, valuation, and audit foundation those later workflows will use.

## Core Design Principle

Inventory is tracked at the `product_variant + store` level.

```
Product Variant -> Inventory Posting -> Inventory Ledger Entries -> Inventory Balance
```

Product-level, department-level, store-level, and enterprise-wide inventory views are rollups from variant/store balances. ShelfStack should never treat product-level or enterprise-level quantities as the source of truth.

## Authoritative Balance Grain

The authoritative inventory balance grain is:

```
store_id + product_variant_id
```

Each balance represents the current quantity and value of one product variant at one store.

Location-level detail may be captured as optional context on ledger entries and adjustments, but location-level balances are deferred. Inventory locations are not the authoritative business grain in Phase 4 because stores may not consistently track movement between sales floor, back room, receiving area, and similar internal locations.

## Inventory Eligibility

Phase 4 supports quantity-tracked variants only.

A product variant may receive inventory ledger entries only when its inventory behavior allows physical inventory tracking.

Initial enforcement (Phase 3 `product_variants.inventory_behavior` values):

```
standard_physical    -> inventory ledger eligible
digital_asset        -> not eligible
drop_ship            -> not eligible for store on-hand inventory
composite_recipe     -> not eligible as finished-good inventory in Phase 4
capacitated_service  -> not inventory; future capacity/attendance model
pure_financial       -> not inventory; future stored-value ledger
non_inventory        -> not eligible
```

Condition, source, and pricing distinctions do not determine inventory eligibility. New, used, signed, remainder, damaged, and consignment variants may all eventually be physical inventory if their `inventory_behavior` is `standard_physical`.

## In Scope

Phase 4 includes:

* Inventory ledger posting model  
* Store-level inventory balances  
* Quantity on hand  
* Quantity available, initially equal to quantity on hand  
* Negative on-hand support  
* Cost and retail value snapshots  
* Opening inventory adjustments  
* Manual quantity adjustments  
* Inventory reason codes  
* Inventory audit events  
* Store-level stock views  
* Product and product variant stock views  
* Negative inventory exception views  
* Balance rebuild or integrity-check tooling

## Deferred

Phase 4 does not include:

* Purchase orders  
* Receiving batches  
* POS sales or returns  
* Customer holds/reservations  
* Quantity committed/held  
* Used buyback workflow  
* Consignment intake workflow  
* Vendor returns  
* Inter-store transfer workflow  
* Location-level balance invariants  
* True accounting-grade average cost or COGS  
* Copy-level inventory tracking

## Ledger Posting Model

Phase 4 should use a grouped posting model.

```
inventory_postings
  has many inventory_ledger_entries
```

An `inventory_posting` is the atomic posted event. An `inventory_ledger_entry` is one inventory effect within that event.

Example:

```
Posting: Manual adjustment #1042

Entry 1: Store 001 / Variant A / +3
Entry 2: Store 001 / Variant B / -1
Entry 3: Store 001 / Variant C / +6
```

This structure supports multi-line adjustments now and future workflows later, including receiving, POS, returns, buybacks, vendor returns, and inter-store transfers.

## Inventory Postings

`inventory_postings` are posted facts, not drafts.

Expected fields include:

```
id
posting_type
source_type
source_id
store_id nullable
posted_at
posted_by_user_id
workstation_id nullable
idempotency_key
reversal_of_posting_id nullable
reversed_by_posting_id nullable
notes
timestamps
```

Phase 4 posting types:

```
opening_inventory
manual_adjustment
balance_correction
```

Future posting types may include:

```
receiving
pos_sale
customer_return
vendor_return
used_buyback
transfer
```

## Inventory Ledger Entries

`inventory_ledger_entries` store the quantity and value effects of a posting.

Expected fields include:

```
id
inventory_posting_id
line_number
product_variant_id
store_id
inventory_location_id nullable
movement_type
quantity_delta
unit_cost_cents nullable
total_cost_cents nullable
unit_retail_cents nullable
total_retail_cents nullable
cost_source
retail_source
reason_code_id nullable
occurred_at
timestamps
```

Phase 4 movement types should be limited to the actual Phase 4 write paths:

```
opening_balance
manual_adjustment
correction
recount_adjustment
```

Future movement types such as `received`, `sold`, `customer_return`, `used_buyback`, `vendor_return`, `transfer_in`, and `transfer_out` should be reserved for later phases.

## Inventory Balances

`inventory_balances` are cached projections from posted ledger entries.

Expected grain:

```
store_id + product_variant_id
```

Expected fields include:

```
store_id
product_variant_id
quantity_on_hand
quantity_available
inventory_cost_value_cents
inventory_retail_value_cents
estimated_unit_cost_cents
unit_retail_cents
cost_source
retail_source
last_posting_id
timestamps
```

Phase 4 should allow negative balances. Negative on-hand is an operational exception, not a posting blocker.

Core invariant:

```
inventory_balances.quantity_on_hand
=
sum(inventory_ledger_entries.quantity_delta)
for the same store + product_variant
```

## Valuation

Retail value is based on the product variant’s current retail/selling price at posting time.

Cost value uses the best available method in this order:

1. Manual cost entered on the adjustment/opening inventory line  
2. Product variant default or expected cost, if present  
3. Estimated cost from subdepartment target margin  
4. Unknown or zero cost with `cost_source = unknown`

Target-margin estimate:

```
estimated_cost = retail_price * (1 - target_margin)
```

Phase 4 valuation is management inventory value, not final accounting-grade cost of goods sold. Later receiving, vendor order, used buyback, and consignment workflows will provide stronger actual-cost sources.

Ledger entries should snapshot cost and retail values so historical postings are not silently rewritten when product variant prices or subdepartment margins change later.

## Adjustments

Phase 4 includes the first inventory write workflows:

* Opening inventory adjustment  
* Manual quantity adjustment

Suggested adjustment statuses:

```
draft
posted
cancelled
```

Draft adjustments may be edited. Posted adjustments are locked. Corrections should be made through a new posting or reversal, not by editing posted ledger entries.

## Posting Rules

Posting an adjustment should happen inside one database transaction:

```
create inventory_posting
create inventory_ledger_entries
update inventory_balances
write audit event
commit
```

If any step fails, nothing posts.

Each source workflow should post only once. Phase 4 should enforce idempotency so the same adjustment cannot create duplicate ledger entries.

## Inventory Locations

Phase 4 may introduce `inventory_locations` as setup/reference data and optional context.

Examples:

```
Sales Floor
Back Room
Receiving Area
Damaged/Review
Offsite/Event
```

However, Phase 4 should not make location balances authoritative. Moving inventory between locations inside a store is informational and should not affect store-level quantity, cost value, or retail value.

Location-level balances and intra-store location transfer workflows are deferred until ShelfStack has enough operational workflow support to keep them reliable.

## Inter-Store Transfers

Inter-store transfer workflows remain deferred to Advanced Store Operations.

Phase 4 should still make the ledger capable of supporting future grouped multi-entry postings, where later transfer workflows can create paired entries:

```
Store A / Variant X: -3
Store B / Variant X: +3
```

The Phase 4 ledger should support this pattern technically, but should not include transfer tables, transfer UI, in-transit inventory, shipped/received lifecycle, or discrepancy handling.

## Audit Events

Phase 4 should audit key inventory actions:

* adjustment created  
* adjustment cancelled  
* adjustment posted  
* inventory posting created  
* ledger entries posted  
* negative inventory created or cleared  
* balance rebuilt or integrity check run

Audit events should include user, store, workstation/session context where available.

## Read Surfaces

Minimum Phase 4 views:

* Inventory by store  
* Inventory for one product variant  
* Inventory rollup on product detail  
* Product-level rollup across variants  
* Enterprise inventory rollup  
* Negative inventory exception list  
* Ledger history for a variant/store  
* Adjustment detail with posted ledger entries

## Recommended Tables

```
inventory_postings
inventory_ledger_entries
inventory_balances
inventory_adjustments
inventory_adjustment_lines
inventory_reason_codes
inventory_locations
```

Possible later tables:

```
inventory_location_balances
inventory_location_movements
inventory_transfers
inventory_transfer_lines
inventory_reservations
```

## Recommended Services

```
Inventory::Post
Inventory::PostAdjustment
Inventory::BalanceUpdater
Inventory::CostEstimator
Inventory::Availability
Inventory::Valuation
Inventory::RebuildBalances
Inventory::BalanceIntegrityCheck
```

Controllers should remain thin. Posting, valuation, idempotency, balance updates, audit creation, and transaction safety belong in services.

## Exit Criteria

Phase 4 is complete when:

* Quantity-tracked product variants can receive opening inventory.  
* Staff can post manual inventory adjustments.  
* Posting creates immutable grouped inventory postings and ledger entries.  
* Store-level balances update from posted ledger entries.  
* Negative on-hand is allowed and visible as an exception.  
* Cost and retail value are captured using Phase 4 valuation rules.  
* Non-inventory variants are blocked from inventory postings.  
* Inventory views show stock by store, product, and product variant.  
* Ledger history is visible for a variant/store.  
* Balance integrity can be checked or rebuilt from the ledger.  
* Later workflows can post inventory effects through the same ledger model without directly mutating balances.
