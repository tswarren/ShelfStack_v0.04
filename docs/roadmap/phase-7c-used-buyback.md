# Phase 7C Used Buyback Specification

Parent roadmap: `docs/roadmap.md`
Related phases:

```text
Phase 4  Inventory Foundation
Phase 6  POS Foundation
Phase 7A Customer Demand / Customers
Phase 7B Customer Credit / Stored Value
```

Phase 7C depends on:

* Inventory postings and ledger entries.
* POS register sessions and cash movements.
* Customers.
* Stored value accounts and ledger entries.
* Product conditions, products, product variants, and catalog items.

Inventory remains authoritative at the `store_id + product_variant_id` grain, and balances must be updated through inventory postings rather than direct mutation.   Phase 7B already provides the stored-value foundation, including the `trade_credit` account type intended for future buyback use.

---

# 1. Purpose

Phase 7C adds the used buyback workflow.

It answers:

> How does ShelfStack let staff evaluate used items, offer cash or trade credit, accept selected items, track no-value donations, pay the seller, and add accepted inventory into stock with correct cost basis, audit history, and customer-credit linkage?

Used buyback is **not** a POS return. It is a separate operational workflow that integrates with:

```text
Customers
Product / catalog intake
Product variants
Inventory postings
Register cash movements
Stored value trade credit
Receipts / slips
Audit events
Reports
```

---

# 2. Locked decisions

| Area                                          | Decision                                                                                                                                      |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Used variant strategy                         | Use **graded used variants** with existing Phase 3 condition keys (Very Fine / Fine grading, not alternate names).                          |
| Variant eligibility                           | Require **both** `sub_departments.buyback_allowed = true` **and** `product_conditions.buyback_eligible = true`.                             |
| Inventory void source                         | Use a separate `buyback_voids` record as the inventory/stored-value void source (mirrors `pos_voids`; do not reuse `BuybackSession` as source). |
| Session numbering                             | Assign `buyback_number` at completion from per-workstation `buyback_sequences` (mirrors POS transaction numbering).                         |
| Trade-credit redemption (MVP)                 | Reachable by stored-value **identifier lookup** or **explicit account selection**; POS does not auto-pick `trade_credit` over `merchandise_credit`. |
| Inventory availability                        | Accepted items post immediately and are sellable immediately. Processing flags are tracked operationally.                                     |
| Payout mode                                   | MVP supports one payout mode per buyback session: `cash`, `trade_credit`, or `no_value_donation`. No split cash + trade-credit payout in MVP. |
| Seller identity                               | Anonymous sellers are not allowed. A `customer_id` is required.                                                                               |
| Customer records                              | Extend existing `customers` table with structured name/address fields.                                                                        |
| Donations                                     | No-value donations are supported and can post inventory with zero cost.                                                                       |
| Catalog creation                              | Buyback may create catalog/product/variant records through a constrained intake path.                                                         |
| Intake-created records                        | Buyback-created item records are marked `needs_review`.                                                                                       |
| Corrections                                   | Completed buybacks are corrected through reversal/void workflows, not mutation.                                                               |
| Consignment                                   | Deferred.                                                                                                                                     |
| Copy-level inventory                          | Deferred.                                                                                                                                     |
| Jurisdiction-specific legal compliance engine | Deferred.                                                                                                                                     |
| GL/accounting export                          | Deferred to Phase 8.                                                                                                                          |

---

# 3. In scope

Phase 7C includes:

```text
customer-required buyback sessions
buyback_number assignment via buyback_sequences
structured customer identity/address fields
dual eligibility: sub_department.buyback_allowed and product_condition.buyback_eligible
graded buyback-eligible used conditions (existing Phase 3 keys)
buyback item scan/search/resolve (reuse Phase 6.5 ISBN lookup where applicable)
constrained buyback catalog/product/variant intake
buyback line pricing with documented precedence
cash offer and trade-credit offer calculation
staff price/offer override with permission and reason
accepted, rejected, and donated line outcomes
cash payout via register paid_out movement
trade-credit payout via stored_value trade_credit issue
trade-credit redemption via identifier or explicit account selection
no-value donation inventory posting
immediate inventory posting for accepted/donated lines
buyback receipt/slip
buyback_voids void/reversal workflow
buyback reports
permissions
audit events
tests
```

---

# 4. Out of scope

Phase 7C does not include:

```text
anonymous buybacks
split cash + trade-credit payout
consignment
copy-level inventory
rare/collectible workflow
jurisdiction-specific secondhand dealer compliance automation
stored seller identity-document numbers
GL journal entries
multi-store stored-value liability settlement
advanced pricing feeds
automated online resale valuation
```

Signed, remainder, special-edition, or other non-buyback conditions may be noted on a buyback line (`signed_copy` flag, `special_notes`), but they must not create or target non-buyback variants in the MVP.

---

# 5. Existing table changes

## 5.1 `customers`

Phase 7A introduced a lightweight `customers` table with `display_name`, `email`, `phone`, `preferred_contact_method`, `notes`, and `active`.  Phase 7C extends it for required seller identity.

Add:

```text
first_name string nullable
last_name string nullable
address_line1 string nullable
address_line2 string nullable
city string nullable
country_code string not null default "US"
region_code string nullable
postal_code string nullable
phone_normalized string nullable
email_normalized string nullable
date_of_birth date nullable
customer_number string nullable
created_by_user_id bigint nullable FK users
updated_by_user_id bigint nullable FK users
merged_into_customer_id bigint nullable FK customers
```

Rules:

* `display_name` remains required.
* New records should generate `display_name` from `first_name` and `last_name` when possible.
* Address fields use `address_line1` / `address_line2` to match `stores` naming.
* `country_code` defaults to `US`.
* `region_code` stores state/province using the local two-letter code when applicable.
* `date_of_birth` is optional and should only be required by store policy.
* Sensitive ID-document numbers should **not** be stored on `customers` in MVP.
* If identity verification is later required, store transaction-level verification snapshots on `buyback_sessions`.

## 5.2 `product_conditions`

Phase 3 already models product conditions and product variants, including variant condition, SKU, selling price, and inventory behavior. Phase 7C adds explicit buyback eligibility on top of the **existing seeded condition keys** in `db/seeds/phase3_catalog_products.rb`.

Add:

```text
buyback_eligible boolean not null default false
buyback_default boolean not null default false
buyback_sort_order integer nullable
buyback_price_factor_bps integer nullable
buyback_requires_review boolean not null default false
```

`buyback_price_factor_bps` is optional. When present, it participates in pricing as a condition-level default/fallback (see §7.5).

Seed matrix (upsert by existing `condition_key`; do not introduce alternate keys such as `used_very_good` or `used_fair`):

| `condition_key`    | Name                 | `buyback_eligible` | `buyback_default` | `buyback_requires_review` | Notes                              |
| ------------------ | -------------------- | -----------------: | ----------------: | ------------------------: | ---------------------------------- |
| `used_like_new`    | Used - Like New      |               true |             false |                     false | Highest normal used grade          |
| `used_very_fine`   | Used - Very Fine     |               true |             false |                     false |                                    |
| `used_fine`        | Used - Fine          |               true |             false |                     false |                                    |
| `used_good`        | Used - Good          |               true |              true |                     false | Recommended buyback default        |
| `used_poor`        | Used - Poor          |               true |             false |                     false | Usually review/low value           |
| `used_ex_library`  | Used - Ex-Library    |               true |             false |                      true | Eligible with staff review         |
| `used_book_club`   | Used - Book Club     |               true |             false |                      true | Eligible with staff review         |

Non-buyback conditions (keep `buyback_eligible = false`):

| `condition_key`     | `buyback_eligible` | Rule                                                |
| ------------------- | -----------------: | --------------------------------------------------- |
| `new`               |              false | Never selectable in buyback                         |
| `signed_copy`       |              false | Capture via `signed_copy` line flag, not as condition |
| `remainder`         |              false | Not normal customer buyback                         |
| `special_edition`   |              false | Note in `special_notes`; deferred rare workflow     |

## 5.3 `sub_departments`

Phase 2/3B already exposes `buyback_allowed` on `sub_departments` (seeded in CSV, resolved via `ClassificationDefaultsResolver`).

Rules:

* Buyback line acceptance and intake require `sub_departments.buyback_allowed = true` for the line's resolved subdepartment.
* `buyback_allowed` is a **classification gate**; it does not replace `product_conditions.buyback_eligible`.
* Both gates must pass before a line can be accepted, posted, or used for intake variant creation.

## 5.4 `catalog_items`, `products`, `product_variants`

Add to **all three** tables:

```text
catalog_items
products
product_variants
```

Columns:

```text
source string not null default "manual"
needs_review boolean not null default false
created_from_buyback_session_id bigint nullable FK buyback_sessions
```

Recommended values for buyback intake:

```text
source = "buyback_intake"
needs_review = true
```

Buyback-created catalog items, products, and variants should be reviewable from the Items workspace.

## 5.5 `inventory_postings.posting_type`

`used_buyback` is already reserved in Phase 4. Phase 7C adds:

```text
buyback_void
```

Completion posting:

```text
posting_type = used_buyback
source_type = BuybackSession
source_id = buyback_session.id
```

Void posting (mirrors `pos_void`):

```text
posting_type = buyback_void
source_type = BuybackVoid
source_id = buyback_void.id
reversal_of_posting_id = original used_buyback posting
```

`inventory_postings` enforces unique `(source_type, source_id)`. A void **must not** reuse `BuybackSession` as the posting source.

## 5.6 `inventory_ledger_entries`

`used_buyback` is already reserved as a `movement_type`. Phase 7C does **not** add a separate void movement type.

Original ledger line:

```text
movement_type = used_buyback
quantity_delta = +1
```

Void reversal line (mirrors `Pos::PostVoidInventory`):

```text
movement_type = used_buyback
quantity_delta = negated original quantity_delta
unit_cost_cents = original line unit_cost_cents
cost_source = original line cost_source
```

Extend controlled `cost_source` values:

```text
buyback_offer
no_value_donation
```

`retail_source` remains `variant_selling_price` or `unknown` per existing `Inventory::CostEstimator` behavior. Do not add buyback-specific retail sources until `CostEstimator` supports explicit retail input. Ledger retail snapshots therefore depend on `product_variants.selling_price_cents` at posting time (see §7.3 and §7.10).

## 5.7 `pos_cash_movements`

Phase 6 already supports `paid_in` and `paid_out` register movements. Phase 7C uses this table for cash buyback payouts.

Add:

```text
source_type string nullable
source_id bigint nullable
reverses_cash_movement_id bigint nullable FK pos_cash_movements
```

Cash buyback payout:

```text
movement_type = paid_out
reason_code = used_buyback
source_type = BuybackSession
source_id = buyback_session.id
```

Cash buyback void/reversal, when appropriate:

```text
movement_type = paid_in
reason_code = buyback_void
source_type = BuybackVoid
source_id = buyback_void.id
reverses_cash_movement_id = original_cash_movement.id
```

## 5.8 `stored_value_reason_codes`

Phase 7B requires reason codes for manual/system issuance. Add seeds:

| `reason_key`                 | Name                         | Use                                      |
| ---------------------------- | ---------------------------- | ---------------------------------------- |
| `buyback_trade_credit_issue` | Buyback Trade Credit Issue   | Trade-credit payout at buyback completion |
| `buyback_trade_credit_void`  | Buyback Trade Credit Void    | Reversal of buyback trade-credit issue   |

Trade-credit payout uses `buyback_trade_credit_issue`. Void reversal uses `buyback_trade_credit_void` (via `StoredValue::VoidEntry` / reversal entry pattern).

---

# 6. New tables

## 6.1 `buyback_sequences`

Per-workstation sequence counter for `buyback_number` assignment (mirrors `pos_workstation_sequences`).

| Field                       | Type     | Notes                          |
| --------------------------- | -------- | ------------------------------ |
| `id`                        | bigint   | PK                             |
| `workstation_id`            | bigint   | Required; unique               |
| `last_sequence`             | integer  | Default 0; incremented on assign |
| `created_at` / `updated_at` | datetime | Rails timestamps               |

Rules:

* One row per workstation.
* `buyback_number` is assigned at **completion**, not at session start.
* Format mirrors POS transaction numbers with a buyback prefix in the sequence segment:

```text
{store_number}-{workstation_number}-B{sequence:06d}
```

Example: `0001-03-B000042`

Implementation may follow `Pos::TransactionNumberAssigner` / `Buybacks::BuybackNumberAssigner`.

## 6.2 `buyback_sessions`

Represents one seller interaction.

| Field                            | Type     | Notes                                                             |
| -------------------------------- | -------- | ----------------------------------------------------------------- |
| `id`                             | bigint   | PK                                                                |
| `buyback_number`                 | string   | Nullable until completion; unique per store when present          |
| `store_id`                       | bigint   | Required                                                          |
| `workstation_id`                 | bigint   | Nullable until completion context known                           |
| `pos_register_session_id`        | bigint   | Required for cash payout; nullable otherwise                      |
| `customer_id`                    | bigint   | Required; anonymous sellers not allowed                           |
| `status`                         | string   | Controlled value                                                  |
| `payout_mode`                    | string   | `cash`, `trade_credit`, `no_value_donation`                       |
| `business_date`                  | date     | From register session when present; otherwise store business date |
| `total_cash_offer_cents`         | integer  | Default 0                                                         |
| `total_trade_credit_offer_cents` | integer  | Default 0                                                         |
| `accepted_payout_cents`          | integer  | Final payout amount; default 0                                    |
| `donation_value_cents`           | integer  | Optional estimated retail value of no-value donations             |
| `stored_value_account_id`        | bigint   | Nullable; required for trade-credit payout                        |
| `stored_value_ledger_entry_id`   | bigint   | Nullable; trade-credit issue                                      |
| `pos_cash_movement_id`           | bigint   | Nullable; cash payout                                             |
| `inventory_posting_id`           | bigint   | Nullable; completion inventory posting                            |
| `needs_label`                       | boolean  | Default true                                                      |
| `needs_review`                      | boolean  | Default false                                                     |
| `needs_cleaning`                    | boolean  | Default false                                                     |
| `hold_for_review`                   | boolean  | Default false                                                     |
| `processing_notes`                  | text     | Nullable                                                          |
| `quoted_at`                         | datetime | Nullable                                                          |
| `completed_at`                      | datetime | Nullable                                                          |
| `cancelled_at`                      | datetime | Nullable                                                          |
| `voided_at`                         | datetime | Nullable                                                          |
| `created_by_user_id`                | bigint   | Required                                                          |
| `completed_by_user_id`              | bigint   | Nullable                                                          |
| `cancelled_by_user_id`              | bigint   | Nullable                                                          |
| `voided_by_user_id`                 | bigint   | Nullable                                                          |
| `void_reason`                       | text     | Nullable                                                          |
| `notes`                             | text     | Nullable                                                          |
| `created_at` / `updated_at`         | datetime | Rails timestamps                                                  |

Seller snapshots:

```text
seller_display_name_snapshot
seller_first_name_snapshot
seller_last_name_snapshot
seller_address_line1_snapshot
seller_address_line2_snapshot
seller_city_snapshot
seller_region_code_snapshot
seller_postal_code_snapshot
seller_country_code_snapshot
seller_phone_snapshot
seller_email_snapshot
```

Optional policy fields:

```text
seller_identity_verified boolean not null default false
seller_age_confirmed boolean not null default false
seller_terms_accepted_at datetime nullable
seller_signature_captured_at datetime nullable
```

Statuses:

```text
draft
quoted
completed
cancelled
voided
```

Rules:

* `customer_id` is required.
* `buyback_number` is assigned at completion from `buyback_sequences` for the session workstation.
* `payout_mode` is required before completion.
* `pos_register_session_id` is required when `payout_mode = cash`.
* `stored_value_account_id` is required when `payout_mode = trade_credit`.
* Completed sessions are append-only operational facts.
* Completed sessions may only be corrected by void/reversal via `buyback_voids`.

## 6.3 `buyback_lines`

Represents one evaluated item. UI should treat quantity as 1 for books/media.

| Field                                | Type     | Notes                                    |
| ------------------------------------ | -------- | ---------------------------------------- |
| `id`                                 | bigint   | PK                                       |
| `buyback_session_id`                 | bigint   | Required                                 |
| `line_number`                        | integer  | Required; unique per session             |
| `status`                             | string   | Controlled value                         |
| `outcome`                            | string   | Controlled value                         |
| `catalog_item_id`                    | bigint   | Nullable until resolved                  |
| `product_id`                         | bigint   | Nullable until resolved                  |
| `product_variant_id`                 | bigint   | Required before accepted/donated posting |
| `created_catalog_item_id`            | bigint   | Nullable                                 |
| `created_product_id`                 | bigint   | Nullable                                 |
| `created_product_variant_id`         | bigint   | Nullable                                 |
| `product_condition_id`               | bigint   | Required before accepted/donated posting |
| `buyback_pricing_rule_id`            | bigint   | Nullable                                 |
| `buyback_reject_reason_id`           | bigint   | Nullable                                 |
| `identifier_entered`                 | string   | Nullable                                 |
| `identifier_normalized`              | string   | Nullable                                 |
| `title_snapshot`                     | string   | Required before completion               |
| `creator_snapshot`                   | string   | Nullable                                 |
| `format_snapshot`                    | string   | Nullable                                 |
| `condition_snapshot`                 | string   | Nullable                                 |
| `variant_sku_snapshot`               | string   | Nullable                                 |
| `sub_department_id`                  | bigint   | Nullable                                 |
| `list_price_cents`                   | integer  | Nullable                                 |
| `current_selling_price_cents`        | integer  | Nullable                                 |
| `suggested_resale_price_cents`       | integer  | Nullable                                 |
| `accepted_resale_price_cents`        | integer  | Nullable                                 |
| `suggested_cash_offer_cents`         | integer  | Nullable                                 |
| `suggested_trade_credit_offer_cents` | integer  | Nullable                                 |
| `accepted_offer_cents`               | integer  | Nullable; zero for donation              |
| `resale_price_overridden`            | boolean  | Default false                            |
| `offer_overridden`                   | boolean  | Default false                            |
| `override_reason`                    | text     | Nullable; required for overrides         |
| `signed_copy`                        | boolean  | Default false                            |
| `special_notes`                      | text     | Nullable                                 |
| `needs_label`                        | boolean  | Default true                             |
| `needs_review`                       | boolean  | Default false                            |
| `needs_cleaning`                     | boolean  | Default false                            |
| `hold_for_review`                    | boolean  | Default false                            |
| `quantity`                           | integer  | Default 1                                |
| `inventory_ledger_entry_id`          | bigint   | Nullable                                 |
| `void_inventory_ledger_entry_id`     | bigint   | Nullable                                 |
| `notes`                              | text     | Nullable                                 |
| `created_at` / `updated_at`          | datetime | Rails timestamps                         |

Statuses:

```text
pending
priced
accepted
rejected
posted
voided
```

Outcomes:

```text
accepted_for_cash
accepted_for_trade_credit
accepted_as_donation
rejected_returned_to_seller
rejected_recycle
```

Rules:

* `quantity` defaults to 1.
* Accepted/donated lines require `product_variant_id`.
* Accepted/donated lines require a buyback-eligible `product_condition_id`.
* Rejected lines do not post inventory.
* Donated lines may post inventory with `accepted_offer_cents = 0`.

## 6.4 `buyback_voids`

Represents one void event for a completed buyback session (mirrors `pos_voids`). Serves as the polymorphic **source** for void inventory postings and void cash movements.

| Field                            | Type     | Notes                                           |
| -------------------------------- | -------- | ----------------------------------------------- |
| `id`                             | bigint   | PK                                              |
| `buyback_session_id`             | bigint   | Required; unique (one void per session)         |
| `store_id`                       | bigint   | Required                                        |
| `workstation_id`                 | bigint   | Required                                        |
| `pos_register_session_id`        | bigint   | Nullable; required when reversing cash payout   |
| `voided_at`                      | datetime | Required                                        |
| `voided_by_user_id`              | bigint   | Required                                        |
| `void_reason`                    | text     | Required                                        |
| `pos_authorization_id`           | bigint   | Nullable; manager auth when cash was paid out   |
| `inventory_posting_id`           | bigint   | Nullable; `buyback_void` reversal posting       |
| `void_stored_value_ledger_entry_id` | bigint | Nullable; reversal of trade-credit issue     |
| `void_cash_movement_id`          | bigint   | Nullable; counter `paid_in` when cash recovered |
| `notes`                          | text     | Nullable                                        |
| `created_at` / `updated_at`      | datetime | Rails timestamps                                |

Rules:

* Created only for `completed` sessions; marks session `voided`.
* Void inventory posts with `source: BuybackVoid`, not `BuybackSession`.
* Must not mutate original completion postings, ledger entries, or stored-value rows.

## 6.5 `buyback_pricing_rules`

Defines suggested resale and offer calculations.

| Field                       | Type     | Notes                                       |
| --------------------------- | -------- | ------------------------------------------- |
| `id`                        | bigint   | PK                                          |
| `name`                      | string   | Required                                    |
| `sub_department_id`         | bigint   | Nullable; null means broad/default          |
| `product_condition_id`      | bigint   | Nullable; null means all buyback conditions |
| `base_price_source`         | string   | Controlled value                            |
| `resale_price_factor_bps`   | integer  | Nullable                                    |
| `cash_offer_bps`            | integer  | Required                                    |
| `trade_credit_offer_bps`    | integer  | Required                                    |
| `minimum_offer_cents`       | integer  | Default 0                                   |
| `maximum_offer_cents`       | integer  | Nullable                                    |
| `rounding_increment_cents`  | integer  | Default 100                                 |
| `active`                    | boolean  | Default true                                |
| `sort_order`                | integer  | Default 0                                   |
| `created_at` / `updated_at` | datetime | Rails timestamps                            |

Base price sources:

```text
product_list_price
variant_selling_price
condition_adjusted_list_price
manual_resale_price
```

Rules:

* The system should show both cash and trade-credit offers.
* Trade credit may be more generous than cash.
* Staff may override resale price and offer with permission and reason.
* Accepted offer becomes the inventory cost basis.
* Donation cost basis is zero.

Pricing precedence (resolution order):

1. **`buyback_pricing_rules`** — primary source for suggested resale price and cash/trade-credit offers when a matching active rule exists (most specific `sub_department_id` + `product_condition_id` wins).
2. **`product_conditions.buyback_price_factor_bps`** — condition-level default/fallback when no rule factor applies; may combine with `default_list_price_factor_bps` for `condition_adjusted_list_price` base sources.
3. **`sub_departments.default_pricing_model`** — classification default only (e.g. `buyback_resale` indicates department intent); does not override an explicit pricing rule or condition factor.

`sub_departments.default_margin_target_bps` remains an inventory **cost estimation** fallback for non-buyback postings; buyback accepted lines use `accepted_offer_cents` as cost basis (`cost_source = buyback_offer`).

## 6.6 `buyback_reject_reasons`

| Field                       | Type     | Notes            |
| --------------------------- | -------- | ---------------- |
| `id`                        | bigint   | PK               |
| `reason_key`                | string   | Required; unique |
| `name`                      | string   | Required         |
| `description`               | text     | Nullable         |
| `active`                    | boolean  | Default true     |
| `sort_order`                | integer  | Default 0        |
| `created_at` / `updated_at` | datetime | Rails timestamps |

Suggested seeds:

```text
poor_condition
not_needed
overstocked
not_resellable
missing_components
outdated
duplicate_copy
counterfeit_or_suspicious
other
```

---

# 7. Core business rules

## 7.1 Seller rules

* A buyback session must have a `customer_id`.
* Anonymous buybacks are not allowed.
* If required customer identity/address fields are missing, completion is blocked.
* Seller snapshots are captured at completion.
* Store policy may require age confirmation, identity verification, or terms acceptance.
* Do not store sensitive identity-document numbers in MVP.

## 7.2 Used-only variant rules

Buyback may only create, select, accept, or post inventory against variants whose condition is explicitly buyback-eligible.

Do not infer buyback eligibility from:

```text
new_condition = false
condition name
SKU component
staff-entered label
```

Validation before accepting/posting a line:

```text
product_variant_id present
product_condition_id present
sub_department_id present
sub_department.buyback_allowed == true
product_variant.condition_id == product_condition_id
product_condition.buyback_eligible == true
Inventory::Eligibility.eligible?(product_variant)  # legacy: inventory_behavior == standard_physical
product_variant.active == true
```

New, signed, remainder, special-edition, or other non-buyback variants may be shown for context, but they must not be selectable.

## 7.3 Graded used variant creation

If no eligible graded used variant exists, the buyback workflow may create one through:

```text
Buybacks::FindOrCreateGradedUsedVariant
```

The service must:

1. Require a buyback-eligible product condition on a buyback-allowed subdepartment.
2. Default to the configured `buyback_default` condition (`used_good`).
3. Reject `new_condition = true`.
4. Reject non-buyback conditions.
5. Set `inventory_behavior = standard_physical`.
6. Generate a variant SKU using the selected used condition.
7. Set `selling_price_cents` from `accepted_resale_price_cents` before inventory posting.
8. Mark buyback-created catalog item, product, and variant `source = buyback_intake` and `needs_review = true`.

Selling price timing (retail snapshots):

* `Inventory::CostEstimator` derives ledger `retail_source` from `variant.selling_price_cents` only.
* Before `Inventory::Post`, ensure `product_variants.selling_price_cents` reflects `accepted_resale_price_cents` for the target variant.
* On **new** graded used variant creation, set selling price during create.
* On **existing** variant selection, update `selling_price_cents` when staff accepts a resale price override; otherwise the ledger retail snapshot reflects the variant's current selling price.

## 7.4 Catalog/product intake creation

The buyback workflow may create:

```text
catalog_item
  -> product
    -> graded used product_variant
```

Only through a constrained buyback intake path.

Required minimum fields:

```text
identifier, if present
title
format
subdepartment
buyback condition
resale price
offer amount
```

Optional fields:

```text
creator/author
publisher/label/studio
publication/release year
notes
```

Rules:

* Search first, create second.
* Exact identifier matches should prefer existing catalog records.
* Likely duplicates must be shown before creating a new intake record.
* Buyback-created `catalog_items`, `products`, and `product_variants` are marked `source = buyback_intake` and `needs_review = true`.
* For ISBN/barcode resolution, reuse Phase 6.5 external lookup services where applicable (local identifier search first, synchronous ISBNdb on miss); do not duplicate lookup/import logic in buyback-only code paths.
* Full catalog maintenance remains outside the buyback workflow.

## 7.5 Pricing rules

Pricing resolution follows §6.5 precedence: `buyback_pricing_rules` first, then `product_conditions.buyback_price_factor_bps`, then subdepartment `default_pricing_model` as classification context only.

Each priced line should show:

```text
suggested resale price
suggested cash offer
suggested trade-credit offer
```

At acceptance:

* If session payout mode is `cash`, use the cash offer.
* If session payout mode is `trade_credit`, use the trade-credit offer.
* If line outcome is donation, use zero offer.
* Staff overrides require permission and reason.

## 7.6 Payout rules

MVP supports one payout mode per session:

```text
cash
trade_credit
no_value_donation
```

No split cash + trade-credit payout in MVP.

Donation nuance:

* A session may include donated lines with zero value.
* Cash and trade credit may not both be used on the same completed session.

## 7.7 Cash payout

Cash payout creates:

```text
pos_cash_movements.movement_type = paid_out
amount_cents = accepted_payout_cents
reason_code = used_buyback
source_type = BuybackSession
source_id = buyback_session.id
```

Cash payout requires an open register session.

## 7.8 Trade-credit payout

Trade-credit payout creates or credits a `trade_credit` stored value account and issues via `StoredValue::Issue`:

```text
stored_value_accounts.account_type = trade_credit
stored_value_ledger_entries.entry_type = issue
amount_delta_cents = accepted_payout_cents
reason_code = buyback_trade_credit_issue
source_type = BuybackSession
source_id = buyback_session.id
```

Stored value ledger entries remain append-only; void uses `StoredValue::VoidEntry` with `buyback_trade_credit_void`.

Trade-credit redemption at POS (MVP):

* POS `store_credit` tender is compatible with `trade_credit` accounts (`Pos::StoredValueTenderSupport`), but default customer account resolution creates/finds `merchandise_credit`, not `trade_credit`.
* MVP **requires** one of:
  * stored-value **identifier lookup** (scan/swipe trade-credit identifier at POS), or
  * **explicit account selection** from the customer's stored-value accounts (Customers workspace or POS account picker).
* Auto-preferring `trade_credit` when a customer has both merchandise and trade balances is **out of scope** for 7C MVP.

Completion should issue or ensure a printable trade-credit identifier when the account uses identifier-based redemption.

## 7.9 No-value donation

No-value donation creates no cash movement and no stored value ledger entry.

Accepted donated lines post inventory:

```text
quantity_delta = +1
unit_cost_cents = 0
cost_source = no_value_donation
```

## 7.10 Inventory posting

Accepted and donated lines post inventory through `Inventory::Post` in a **single** completion posting per session.

Completion posting:

```text
inventory_postings.posting_type = used_buyback
inventory_postings.source_type = BuybackSession
inventory_postings.source_id = buyback_session.id
```

Ledger line (per accepted/donated buyback line):

```text
movement_type = used_buyback
quantity_delta = +1
manual_unit_cost_cents = accepted_offer_cents
cost_source = buyback_offer or no_value_donation
retail_source = variant_selling_price (from variant.selling_price_cents via CostEstimator)
```

Rules:

* Only accepted/donated lines post inventory.
* Rejected lines do not post inventory.
* Buyback inventory is immediately sellable in MVP.
* Processing flags remain operational signals and do not block posting.
* Ensure variant `selling_price_cents` is set per §7.3 before posting so retail snapshots are meaningful.
* Subsequent buybacks into the same used variant replace balance `unit_cost_cents` with the latest offer (no moving-average blend for buyback cost in MVP); document operationally if needed.

---

# 8. Completion transaction boundary

`Buybacks::CompleteSession` must be atomic.

Recommended order:

```text
validate session
validate customer requirements
validate payout mode
validate accepted/donated lines
validate buyback_allowed subdepartments and buyback-eligible variants
assign buyback_number from buyback_sequences
lock stored value account if trade credit
create cash movement if cash
create stored value issue if trade credit
create inventory posting and ledger entries
snapshot seller and line data
mark session completed
create receipt/slip
audit events
commit
```

If any step fails, the entire completion rolls back.

---

# 9. Void / reversal workflow

Completed buybacks must not be edited in place.

`Buybacks::VoidSession` creates a `buyback_voids` row and reversing records (mirrors `Pos::VoidTransaction` + `Pos::PostVoidInventory`):

| Original effect                        | Reversal                                                                 |
| -------------------------------------- | ------------------------------------------------------------------------ |
| Inventory +1 per accepted/donated line | `buyback_void` posting via `Inventory::Post`, `source: BuybackVoid`, negated `used_buyback` lines, `reversal_of_posting` → completion posting |
| Cash paid out                          | `paid_in` counter movement with `reverses_cash_movement_id`, `source: BuybackVoid` |
| Trade credit issued                    | `StoredValue::VoidEntry` with `buyback_trade_credit_void`                |
| Donation inventory posted              | Inventory -1 with original zero cost preserved on reversal line            |

Void inventory posting:

```text
posting_type = buyback_void
source_type = BuybackVoid
source_id = buyback_void.id
reversal_of_posting_id = buyback_session.inventory_posting_id
```

Void rules:

* Requires permission.
* Requires reason on `buyback_voids.void_reason`.
* Requires manager authorization (`pos_authorization_id`) if cash was paid out.
* One void per completed session (`buyback_voids.buyback_session_id` unique).
* Must not mutate original ledger entries, stored-value rows, or completion cash movements.
* Must not delete buyback lines.
* Must mark the original session `voided`.

---

# 10. Services

Recommended service boundaries:

```text
Buybacks::StartSession
Buybacks::BuybackNumberAssigner
Buybacks::ResolveItem
Buybacks::CreateIntakeItem
Buybacks::FindOrCreateGradedUsedVariant
Buybacks::PriceLine
Buybacks::AcceptLine
Buybacks::RejectLine
Buybacks::CompleteSession
Buybacks::VoidSession
Buybacks::PostVoidInventory
Buybacks::ReceiptBuilder
Buybacks::ReportBuilder
```

## `Buybacks::ResolveItem`

Responsibilities:

```text
local exact identifier lookup
local fuzzy title/creator lookup
Phase 6.5 external ISBN lookup handoff when local miss (reuse existing services)
return existing catalog/product/variant matches
return eligible graded used variants for buyback-allowed subdepartments
show non-buyback variants as warnings/context only
```

## `Buybacks::CreateIntakeItem`

Responsibilities:

```text
create minimal catalog item
create product
create graded used product variant
mark catalog_item, product, and variant source = buyback_intake
mark catalog_item, product, and variant needs_review = true
audit creation
```

## `Buybacks::PriceLine`

Responsibilities:

```text
select pricing rule
calculate resale price
calculate cash offer
calculate trade-credit offer
apply rounding
enforce min/max
snapshot pricing inputs
```

## `Buybacks::CompleteSession`

Responsibilities:

```text
validate
assign buyback_number
post cash/stored value/inventory atomically
snapshot seller data
snapshot line data
mark completed
emit audit events
```

## `Buybacks::PostVoidInventory`

Responsibilities (mirrors `Pos::PostVoidInventory`):

```text
load completion inventory posting from buyback_session
build negated used_buyback line payloads preserving cost snapshots
post buyback_void via Inventory::Post with source BuybackVoid
set reversal_of_posting to completion posting
```

---

# 11. UI requirements

## 11.1 Primary surface

Add a Buybacks workflow under Store Operations or POS/Register.

Recommended routes:

```text
/buybacks
/buybacks/new
/buybacks/:id
/buybacks/:id/edit
/buybacks/:id/receipt
```

## 11.2 Screen layout

```text
Buyback Session
  Seller panel
  Scan/search item panel
  Lines table
  Pricing/condition panel
  Offer summary
  Processing flags
  Payout panel
  Complete / Cancel / Void actions
```

## 11.3 Seller panel

Shows:

```text
customer lookup
create customer
name
phone/email
address
required-fields status
identity/age/terms policy status, if configured
```

Completion is blocked until required seller fields are complete.

## 11.4 Line table

Recommended columns:

```text
Item
Identifier
Condition
Resale price
Cash offer
Trade-credit offer
Outcome
Processing flags
Actions
```

## 11.5 Condition selector

Label:

```text
Buyback condition
```

Only show conditions where:

```text
product_conditions.buyback_eligible = true
```

and only on lines whose resolved subdepartment has `buyback_allowed = true`.

Do not show a raw general variant condition selector.

## 11.6 Non-buyback variant warning

If an item has New/Signed/etc. variants but no eligible used variant:

```text
Existing variants found:
- New Hardcover — not eligible for buyback
- Signed Copy Hardcover — not eligible for buyback

No graded used variant exists yet.
[Create Used Variant]
```

## 11.7 Trade-credit redemption guidance

Receipt/slip and completion UI should show trade-credit identifier and remind staff that POS redemption requires identifier scan or explicit account selection (not automatic `merchandise_credit` resolution).

---

# 12. Receipts and slips

A completed buyback receipt/slip should show:

```text
store header
buyback_number
business date/time
staff/cashier
seller name
accepted lines
donated lines
rejected lines, optionally
condition
resale price
offer amount
payout mode
cash paid or trade credit issued
trade credit identifier/balance, when applicable
signature/terms footer, if configured
```

Receipt/slip reprints should be audited.

---

# 13. Permissions

Add:

```text
buybacks.view
buybacks.create
buybacks.update
buybacks.create_intake_item
buybacks.price_override
buybacks.accept
buybacks.reject
buybacks.complete
buybacks.pay_cash
buybacks.pay_trade_credit
buybacks.accept_donation
buybacks.cancel
buybacks.void
buybacks.reports.view
```

Related permissions may also be required:

```text
customers.create
customers.update
stored_value.issue
stored_value.void
inventory.post
items.create
items.create_variant
```

Supervisor/manager authorization should be required for:

```text
large cash payout
large trade-credit payout
manual price override
manual offer override
void after payout
intake item creation after duplicate warning
accepting no-identifier item
```

---

# 14. Audit events

Add:

```text
buyback.session.created
buyback.session.updated
buyback.session.quoted
buyback.session.completed
buyback.session.cancelled
buyback.session.voided
buyback.void.created

buyback.line.added
buyback.line.resolved
buyback.line.priced
buyback.line.accepted
buyback.line.rejected
buyback.line.donated
buyback.line.voided

buyback.price.overridden
buyback.offer.overridden

buyback.paid.cash
buyback.paid.trade_credit
buyback.inventory.posted
buyback.receipt.printed

buyback.intake.catalog_item_created
buyback.intake.product_created
buyback.intake.product_variant_created
```

Stored value actions should also emit existing stored value ledger events. Cash payout should appear in register activity. Inventory posting should appear in inventory audit/reporting.

---

# 15. Reports

Minimum operational reports:

```text
buyback activity by date/store
cash paid out by date/store/register
trade credit issued by date/store
no-value donations by date/store
accepted item count
rejected item count
donated item count
average payout
buybacks by staff user
buybacks by customer
buybacks by subdepartment
buyback inventory value added
buyback-created records needing review
voided buybacks
price/offer overrides
```

Register reports should include buyback cash paid out so drawer reconciliation remains meaningful.

Stored value liability reports should include trade-credit issuance from buybacks.

---

# 16. Test requirements

Required test coverage:

```text
customer required before completion
missing required seller fields block completion
cannot accept line when sub_department.buyback_allowed is false
cannot accept New variant
cannot accept signed_copy variant
cannot accept non-buyback condition
cannot create non-buyback variant from buyback
buyback_number assigned at completion from per-workstation sequence
can create intake catalog item + product + graded used variant
intake-created catalog_item, product, and variant marked needs_review and source buyback_intake
exact identifier match prefers existing catalog record
duplicate warning appears before new intake creation
pricing rule precedence over condition factor defaults
price rule calculates cash offer
price rule calculates trade-credit offer
price override requires permission and reason
offer override requires permission and reason
cash payout creates paid_out cash movement with BuybackSession source
trade-credit payout creates stored_value issue with buyback_trade_credit_issue
no-value donation creates no payout
accepted cash line posts inventory +1 with cost_source buyback_offer
accepted trade-credit line posts inventory +1
donated line posts inventory +1 with zero cost and cost_source no_value_donation
ledger retail_source uses variant_selling_price after selling price set
rejected line posts no inventory
completion rolls back if cash movement fails
completion rolls back if stored value issue fails
completion rolls back if inventory posting fails
void creates buyback_voids row
void inventory uses buyback_void posting source BuybackVoid not BuybackSession
void reverses inventory posting with negated used_buyback lines
void reverses stored value issue with buyback_trade_credit_void
void creates cash counter-movement when applicable
void does not mutate original records
receipt/slip renders buyback_number, accepted, donated, rejected, and payout details
```

---

# 17. Exit criteria

Phase 7C is complete when:

1. Staff can create a buyback session.
2. A customer is required; anonymous sellers are not allowed.
3. Customers support structured name and address fields (`address_line1`, `address_line2`).
4. Seller identity fields are snapshotted at completion.
5. Staff can scan/search by ISBN/barcode/title.
6. Staff can match to an existing catalog item/product/variant.
7. Staff can create a constrained buyback intake catalog item, product, and graded used variant.
8. Buyback-created `catalog_items`, `products`, and `product_variants` are marked `needs_review` and `source = buyback_intake`.
9. Staff can select only buyback-eligible conditions on buyback-allowed subdepartments.
10. New, signed, remainder, special-edition, and other non-buyback variants cannot be selected or created through buyback.
11. System calculates suggested resale price, cash offer, and trade-credit offer per pricing precedence (§6.5).
12. Staff can override resale price or offer only with permission and reason.
13. Staff can accept, reject, or mark lines as no-value donation.
14. MVP payout is single-mode: cash, trade credit, or no-value donation.
15. Cash payout creates a register paid-out cash movement linked to `BuybackSession`.
16. Trade-credit payout creates a `trade_credit` stored value issue with `buyback_trade_credit_issue`.
17. Trade-credit redemption at POS is documented and reachable via identifier lookup or explicit account selection.
18. No-value donation creates no payout.
19. Accepted and donated lines post inventory through `Inventory::Post` with `posting_type = used_buyback`.
20. Inventory cost basis equals accepted payout value (`cost_source = buyback_offer`), or zero for donations (`no_value_donation`).
21. Accepted inventory is immediately sellable.
22. `buyback_number` is assigned at completion from per-workstation `buyback_sequences`.
23. Processing flags such as `needs_label`, `needs_review`, `needs_cleaning`, and `hold_for_review` are tracked.
24. Buyback receipt/slip shows `buyback_number` and payout details.
25. Completed buybacks can be voided via `buyback_voids` and reversing records.
26. Void inventory posts with `posting_type = buyback_void` and `source = BuybackVoid`.
27. Original cash, stored value, and inventory records are not mutated during correction.
28. Buyback activity appears in operational reports.
29. Permissions and audit events are implemented.
30. Tests cover eligibility, payout, inventory posting, intake creation, numbering, rollback, and void behavior.

---

# 18. Recommended companion docs

```text
docs/roadmap/phase-7c-used-buyback.md
docs/specifications/phase-7c-used-buyback-spec.md
docs/specifications/phase-7c-data-model.md
docs/specifications/phase-7c-test-plan.md
```
