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
| Used variant strategy                         | Use **graded used variants**.                                                                                                                 |
| Variant eligibility                           | Buyback may only create/select variants whose condition is explicitly buyback-eligible.                                                       |
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
structured customer identity/address fields
graded buyback-eligible used conditions
buyback item scan/search/resolve
constrained buyback catalog/product/variant intake
buyback line pricing
cash offer and trade-credit offer calculation
staff price/offer override with permission and reason
accepted, rejected, and donated line outcomes
cash payout via register paid-out movement
trade-credit payout via stored_value trade_credit issue
no-value donation inventory posting
immediate inventory posting for accepted/donated lines
buyback receipt/slip
void/reversal workflow
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

Signed, collectible, remainder, damaged, or special copies may be noted on a buyback line, but they must not create or target special non-buyback variants in the MVP.

---

# 5. Existing table changes

## 5.1 `customers`

Phase 7A introduced a lightweight `customers` table with `display_name`, `email`, `phone`, `preferred_contact_method`, `notes`, and `active`.  Phase 7C extends it for required seller identity.

Add:

```text
first_name string nullable
last_name string nullable
address1 string nullable
address2 string nullable
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
* `country_code` defaults to `US`.
* `region_code` stores state/province using the local two-letter code when applicable.
* `date_of_birth` is optional and should only be required by store policy.
* Sensitive ID-document numbers should **not** be stored on `customers` in MVP.
* If identity verification is later required, store transaction-level verification snapshots on `buyback_sessions`.

## 5.2 `product_conditions`

Phase 3 already models product conditions and product variants, including variant condition, SKU, selling price, and inventory behavior.   Phase 7C adds explicit buyback eligibility.

Add:

```text
buyback_eligible boolean not null default false
buyback_default boolean not null default false
buyback_sort_order integer nullable
buyback_price_factor_bps integer nullable
buyback_requires_review boolean not null default false
```

Seed graded used conditions:

| `condition_key`  | Name             | `new_condition` | `buyback_eligible` | `buyback_default` | Notes                     |
| ---------------- | ---------------- | --------------: | -----------------: | ----------------: | ------------------------- |
| `used_like_new`  | Used - Like New  |           false |               true |             false | Highest normal used grade |
| `used_very_good` | Used - Very Good |           false |               true |             false |                           |
| `used_good`      | Used - Good      |           false |               true |              true | Recommended default       |
| `used_fair`      | Used - Fair      |           false |               true |             false |                           |
| `used_poor`      | Used - Poor      |           false |               true |             false | Usually review/low value  |

Non-buyback examples:

| Condition   | `buyback_eligible` | Rule                                                 |
| ----------- | -----------------: | ---------------------------------------------------- |
| New         |              false | Never selectable in buyback                          |
| Signed      |              false | Capture as note/flag, not variant condition          |
| Remainder   |              false | Not normal customer buyback                          |
| Collectible |              false | Deferred rare/collectible workflow                   |
| Damaged     |              false | Reject or note; do not target normal buyback variant |

## 5.3 `catalog_items`, `products`, `product_variants`

Add review/source markers where practical:

```text
source string not null default "manual"
needs_review boolean not null default false
created_from_buyback_session_id bigint nullable FK buyback_sessions
```

At minimum, add these to:

```text
catalog_items
product_variants
```

Recommended values:

```text
source = "buyback_intake"
needs_review = true
```

Buyback-created records should be reviewable from the Items workspace.

## 5.4 `inventory_postings.posting_type`

Add:

```text
used_buyback
used_buyback_void
```

## 5.5 `inventory_ledger_entries.movement_type`

Add:

```text
used_buyback
used_buyback_void
```

## 5.6 `pos_cash_movements`

Phase 6 already supports `paid_in` and `paid_out` register movements.  Phase 7C uses this table for cash buyback payouts.

Recommended additions:

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
reason_code = used_buyback_void
reverses_cash_movement_id = original_cash_movement.id
```

---

# 6. New tables

## 6.1 `buyback_sessions`

Represents one seller interaction.

| Field                               | Type     | Notes                                                             |
| ----------------------------------- | -------- | ----------------------------------------------------------------- |
| `id`                                | bigint   | PK                                                                |
| `store_id`                          | bigint   | Required                                                          |
| `workstation_id`                    | bigint   | Nullable                                                          |
| `pos_register_session_id`           | bigint   | Required for cash payout; nullable otherwise                      |
| `customer_id`                       | bigint   | Required; anonymous sellers not allowed                           |
| `status`                            | string   | Controlled value                                                  |
| `payout_mode`                       | string   | `cash`, `trade_credit`, `no_value_donation`                       |
| `business_date`                     | date     | From register session when present; otherwise store business date |
| `total_cash_offer_cents`            | integer  | Default 0                                                         |
| `total_trade_credit_offer_cents`    | integer  | Default 0                                                         |
| `accepted_payout_cents`             | integer  | Final payout amount; default 0                                    |
| `donation_value_cents`              | integer  | Optional estimated retail value of no-value donations             |
| `stored_value_account_id`           | bigint   | Nullable; required for trade-credit payout                        |
| `stored_value_ledger_entry_id`      | bigint   | Nullable; trade-credit issue                                      |
| `pos_cash_movement_id`              | bigint   | Nullable; cash payout                                             |
| `inventory_posting_id`              | bigint   | Nullable; inventory posting for accepted/donated lines            |
| `void_inventory_posting_id`         | bigint   | Nullable                                                          |
| `void_stored_value_ledger_entry_id` | bigint   | Nullable                                                          |
| `void_cash_movement_id`             | bigint   | Nullable                                                          |
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
seller_address1_snapshot
seller_address2_snapshot
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
* `payout_mode` is required before completion.
* `pos_register_session_id` is required when `payout_mode = cash`.
* `stored_value_account_id` is required when `payout_mode = trade_credit`.
* Completed sessions are append-only operational facts.
* Completed sessions may only be corrected by void/reversal.

## 6.2 `buyback_lines`

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

## 6.3 `buyback_pricing_rules`

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

## 6.4 `buyback_reject_reasons`

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
product_variant.condition_id == product_condition_id
product_condition.buyback_eligible == true
product_variant.inventory_behavior == "standard_physical"
product_variant.active == true
```

New, signed, remainder, collectible, damaged, or other non-buyback variants may be shown for context, but they must not be selectable.

## 7.3 Graded used variant creation

If no eligible graded used variant exists, the buyback workflow may create one through:

```text
Buybacks::FindOrCreateGradedUsedVariant
```

The service must:

1. Require a buyback-eligible product condition.
2. Default to the configured `buyback_default` condition.
3. Reject `new_condition = true`.
4. Reject non-buyback conditions.
5. Set `inventory_behavior = standard_physical`.
6. Generate a variant SKU using the selected used condition.
7. Set selling price from accepted resale price.
8. Mark buyback-created variants `needs_review = true`.

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
* Buyback-created records are marked `source = buyback_intake` and `needs_review = true`.
* Full catalog maintenance remains outside the buyback workflow.

## 7.5 Pricing rules

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

Trade-credit payout creates a stored value issue:

```text
stored_value_accounts.account_type = trade_credit
stored_value_ledger_entries.entry_type = issue
amount_delta_cents = accepted_payout_cents
source_type = BuybackSession
source_id = buyback_session.id
```

Stored value ledger entries remain append-only, with corrections handled by reversal entries.

## 7.9 No-value donation

No-value donation creates no cash movement and no stored value ledger entry.

Accepted donated lines post inventory:

```text
quantity_delta = +1
unit_cost_cents = 0
cost_source = no_value_donation
```

## 7.10 Inventory posting

Accepted and donated lines post inventory through `Inventory::Post`.

Posting:

```text
inventory_postings.posting_type = used_buyback
inventory_postings.source_type = BuybackSession
inventory_postings.source_id = buyback_session.id
```

Ledger entry:

```text
movement_type = used_buyback
quantity_delta = +1
unit_cost_cents = accepted_offer_cents
unit_retail_cents = accepted_resale_price_cents
cost_source = buyback_offer or no_value_donation
retail_source = buyback_pricing_rule or staff_override
```

Rules:

* Only accepted/donated lines post inventory.
* Rejected lines do not post inventory.
* Buyback inventory is immediately sellable in MVP.
* Processing flags remain operational signals and do not block posting.

---

# 8. Completion transaction boundary

`Buybacks::CompleteSession` must be atomic.

Recommended order:

```text
validate session
validate customer requirements
validate payout mode
validate accepted/donated lines
validate buyback-eligible variants
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

`Buybacks::VoidSession` creates reversing records:

| Original effect                        | Reversal                                                 |
| -------------------------------------- | -------------------------------------------------------- |
| Inventory +1 per accepted/donated line | Inventory -1 per posted line                             |
| Cash paid out                          | Counter cash movement, when cash is recovered/authorized |
| Trade credit issued                    | Stored value reversal entry                              |
| Donation inventory posted              | Inventory -1 with zero-cost reversal                     |

Void rules:

* Requires permission.
* Requires reason.
* Requires manager authorization if cash was paid.
* Must not mutate original ledger entries.
* Must not delete buyback lines.
* Must mark the original session `voided`.

---

# 10. Services

Recommended service boundaries:

```text
Buybacks::StartSession
Buybacks::ResolveItem
Buybacks::CreateIntakeItem
Buybacks::FindOrCreateGradedUsedVariant
Buybacks::PriceLine
Buybacks::AcceptLine
Buybacks::RejectLine
Buybacks::CompleteSession
Buybacks::VoidSession
Buybacks::ReceiptBuilder
Buybacks::ReportBuilder
```

## `Buybacks::ResolveItem`

Responsibilities:

```text
local exact identifier lookup
local fuzzy title/creator lookup
external lookup handoff when available
return existing catalog/product/variant matches
return eligible graded used variants
show non-buyback variants as warnings/context only
```

## `Buybacks::CreateIntakeItem`

Responsibilities:

```text
create minimal catalog item
create product
create graded used product variant
mark records source = buyback_intake
mark records needs_review = true
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
post cash/stored value/inventory atomically
snapshot seller data
snapshot line data
mark completed
emit audit events
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

Only show:

```text
product_conditions.buyback_eligible = true
```

Do not show a raw general variant condition selector.

## 11.6 Non-buyback variant warning

If an item has New/Signed/etc. variants but no eligible used variant:

```text
Existing variants found:
- New Hardcover — not eligible for buyback
- Signed Hardcover — not eligible for buyback

No graded used variant exists yet.
[Create Used Variant]
```

---

# 12. Receipts and slips

A completed buyback receipt/slip should show:

```text
store header
buyback session number
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
cannot accept New variant
cannot accept Signed variant
cannot accept non-buyback condition
cannot create non-buyback variant from buyback
can create intake catalog item + product + graded used variant
intake-created records are marked needs_review
exact identifier match prefers existing catalog record
duplicate warning appears before new intake creation
price rule calculates cash offer
price rule calculates trade-credit offer
price override requires permission and reason
offer override requires permission and reason
cash payout creates paid_out cash movement
trade-credit payout creates stored_value issue
no-value donation creates no payout
accepted cash line posts inventory +1
accepted trade-credit line posts inventory +1
donated line posts inventory +1 with zero cost
rejected line posts no inventory
completion rolls back if cash movement fails
completion rolls back if stored value issue fails
completion rolls back if inventory posting fails
void reverses inventory posting
void reverses stored value issue
void creates cash counter-movement when applicable
void does not mutate original records
receipt/slip renders accepted, donated, rejected, and payout details
```

---

# 17. Exit criteria

Phase 7C is complete when:

1. Staff can create a buyback session.
2. A customer is required; anonymous sellers are not allowed.
3. Customers support structured name and address fields.
4. Seller identity fields are snapshotted at completion.
5. Staff can scan/search by ISBN/barcode/title.
6. Staff can match to an existing catalog item/product/variant.
7. Staff can create a constrained buyback intake catalog item, product, and graded used variant.
8. Buyback-created records are marked `needs_review`.
9. Staff can select only buyback-eligible graded used conditions.
10. New, signed, remainder, collectible, damaged, and other non-buyback variants cannot be selected or created through buyback.
11. System calculates suggested resale price, cash offer, and trade-credit offer.
12. Staff can override resale price or offer only with permission and reason.
13. Staff can accept, reject, or mark lines as no-value donation.
14. MVP payout is single-mode: cash, trade credit, or no-value donation.
15. Cash payout creates a register paid-out cash movement.
16. Trade-credit payout creates a `trade_credit` stored value issue.
17. No-value donation creates no payout.
18. Accepted and donated lines post inventory through `Inventory::Post`.
19. Inventory cost basis equals accepted payout value, or zero for no-value donations.
20. Accepted inventory is immediately sellable.
21. Processing flags such as `needs_label`, `needs_review`, `needs_cleaning`, and `hold_for_review` are tracked.
22. Buyback receipt/slip is available.
23. Completed buybacks can be voided through reversing records.
24. Original cash, stored value, and inventory records are not mutated during correction.
25. Buyback activity appears in operational reports.
26. Permissions and audit events are implemented.
27. Tests cover eligibility, payout, inventory posting, intake creation, rollback, and void behavior.

---

# 18. Recommended companion docs

```text
docs/roadmap/phase-7c-used-buyback.md
docs/specifications/phase-7c-used-buyback-spec.md
docs/specifications/phase-7c-data-model.md
docs/specifications/phase-7c-test-plan.md
```
