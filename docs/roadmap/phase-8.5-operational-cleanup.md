# Phase 8.5 - Operational Cleanup

## Phase goal

Before building reporting, make sure the operational records are **complete, consistent, auditable, and report-ready**.

P0 should focus on facts that reports will depend on:

* What was sold?  
* What discount was applied, by whom, and why?  
* What tax was charged or overridden, and why?  
* How was the transaction tendered?  
* Which customer was linked?  
* What was ordered, from which vendor, at what expected cost?  
* Which items are orderable?  
* Which vendor should be used by default?  
* What buyback payout was offered and completed?

UI cleanup should support those workflows, but avoid turning P0 into a general redesign. Follow the existing ShelfStack visual direction: consistent spacing/alignment, restrained use of accents, and readable operational layouts.

---

# Recommended P0 epics

## Epic 1 — POS discount auditability

### Problem

Discounts need to become reportable and auditable. Current or planned reports will need to distinguish:

* manual markdowns,  
* promotions,  
* damaged-item discounts,  
* employee/staff discounts,  
* price overrides,  
* transaction-level discounts,  
* item-level discounts,  
* discounts requiring approval.

### Scope

Implement a structured discount model that supports:

* discount reason tracking,  
* discount type tracking,  
* item-level discounts,  
* transaction-level discounts,  
* multiple stacked discounts,  
* discount allocation back to affected lines,  
* non-discountable rules,  
* gift card sale line protection.

### Suggested model

#### `discount_reasons`

Seedable/admin-maintainable list.

| Field | Notes |
| :---- | :---- |
| `id` | Primary key |
| `reason_key` | Unique, stable key (lowercase snake_case) |
| `name` | User-facing name |
| `requires_note` | Boolean |
| `requires_authorization` | Boolean |
| `active` | Boolean |
| `sort_order` | Optional |

Example reasons:

* `damaged`  
* `promotion`  
* `price_match`  
* `staff_discount`  
* `manager_adjustment`  
* `customer_service`  
* `loyalty`  
* `other`

#### `pos_discount_applications`

Audit record for each discount applied. **Implemented field names** (see [phase-8.5-1-data-model.md](../specifications/phase-8.5-1-data-model.md)):

| Field | Notes |
| :---- | :---- |
| `pos_transaction_id` | Required |
| `pos_transaction_line_id` | Required for `scope: line`; must be blank for `scope: transaction` |
| `scope` | `line`, `transaction` |
| `source` | `manual`, `system`, `promotion`, `legacy` |
| `discount_method` | `amount`, `percent`, `price_override` |
| `discount_reason_id` | Required |
| `entered_percent_bps` | Basis points when method is percent |
| `entered_amount_cents` | Cents when method is amount |
| `target_price_cents` | For price override |
| `base_amount_cents`, `calculated_discount_cents`, `applied_discount_cents` | Application totals |
| `stack_order` | Stacking sequence |
| `note`, `applied_by_user_id`, `approved_by_user_id`, `applied_at` | Audit |
| `voided_at`, `voided_by_user_id`, `void_reason` | Void before completion |
| `details` | JSONB, default `{}` |

Line-level allocated amounts live on `pos_discount_allocations`, not on the application row.

### Discount calculation rules

Recommended order:

1. Start with line base unit price snapshot.  
2. Apply line-level discounts in `stack_order`.  
3. Calculate line subtotal.  
4. Apply transaction-level discounts only to eligible lines.  
5. Allocate transaction discount back to eligible lines proportionally.  
6. Do not allow final line total below zero.  
7. Do not apply discounts to tax, gift cards, store credit issuance, or non-discountable lines.

### Stacking behavior

Support this even if the first UI is simple.

Examples:

| Scenario | Expected behavior |
| :---- | :---- |
| 10% damaged discount \+ $2 manager adjustment on same line | Two discount application records |
| 20% transaction discount after item markdown | Transaction discount applies to already-discounted eligible subtotal |
| Gift card line in transaction with transaction discount | Gift card line excluded from allocation |
| Non-discountable variant in transaction with transaction discount | Variant excluded from allocation |

### Non-discountable precedence

Use the strictest rule:

If any governing level marks the item non-discountable, it is non-discountable.

Applicable levels:

* department,  
* subdepartment,  
* merchandise class if applicable,  
* product,  
* product variant,  
* system rule.

Gift card sale lines should always be system non-discountable.

### Suggested helper/service objects

* `Pos::DiscountEligibilityResolver`  
* `Pos::DiscountCalculator`  
* `Pos::TransactionDiscountAllocator`  
* `Pos::DiscountAuditBuilder`

### Acceptance criteria

* A cashier can apply a line discount with a reason.  
* A cashier can apply a transaction discount with a reason.  
* Multiple discounts can be applied to the same line or transaction.  
* Transaction discounts exclude non-discountable lines.  
* Gift card sale lines cannot be discounted.  
* Completed transactions retain immutable discount audit records.  
* Discount activity can be reported by date, register, cashier, reason, type, line, transaction, and approval status.

---

# Epic 2 — POS tax exception tracking

**Status:** Implemented in Phase 8.5-2 (8.5-2a transaction exemption + 8.5-2b line override). See [phase-8.5-2_pos_tax_exemption_tracking.md](phase-8.5-2_pos_tax_exemption_tracking.md).

## Problem

Reporting needs to explain tax results, especially when tax differs from the default calculation.

ShelfStack needs structured support for:

* transaction tax exemption,  
* line tax-rate override,  
* tax-exempt reason tracking,  
* tax override reason tracking,  
* auditability.

## Scope

Implement:

* full transaction tax-exempt flag/reason,  
* line-level tax override,  
* required reason/note support,  
* user/timestamp audit fields,  
* tax recalculation behavior.

## Suggested model

### `tax_exception_reasons`

| Field | Notes |
| :---- | :---- |
| `id` | Primary key |
| `code` | Unique |
| `name` | User-facing |
| `exception_type` | `exemption`, `rate_override`, `both` |
| `requires_note` | Boolean |
| `requires_certificate` | Boolean |
| `is_active` | Boolean |

Example reasons:

* `RESALE`  
* `NONPROFIT`  
* `SCHOOL`  
* `GOVERNMENT`  
* `OUT_OF_STATE`  
* `MANUAL_CORRECTION`  
* `WRONG_TAX_CATEGORY`  
* `OTHER`

### Transaction-level fields

Add to `pos_transactions` or a related `pos_tax_exemptions` table.

| Field | Notes |
| :---- | :---- |
| `tax_exempt` | Boolean |
| `tax_exception_reason_id` | Nullable unless exempt |
| `tax_exemption_note` | Optional/required by reason |
| `tax_exemption_certificate_number` | Optional |
| `tax_exempt_set_by_user_id` | Nullable |
| `tax_exempt_set_at` | Nullable |

A separate table is cleaner if you expect richer exemption records.

### Line-level fields

Add to `pos_transaction_lines` or create `pos_line_tax_overrides`.

| Field | Notes |
| :---- | :---- |
| `tax_rate_id` | Normal applied rate |
| `tax_rate_snapshot` | Existing/current snapshot pattern |
| `tax_override_rate_id` | Nullable |
| `tax_override_reason_id` | Nullable |
| `tax_override_note` | Nullable |
| `tax_override_by_user_id` | Nullable |
| `tax_override_at` | Nullable |
| `tax_cents` | Final calculated tax |

## Tax calculation rules

Recommended order:

1. Determine normal taxability from product/variant/tax category.  
2. Determine normal tax rate from store/rate rules.  
3. Apply line-level tax override if present.  
4. Apply transaction-level tax exemption if set.  
5. Store final tax amount and snapshots on completion.

For reporting, preserve:

* normal expected rate,  
* overridden rate if applicable,  
* final tax amount,  
* reason,  
* user,  
* timestamp.

## UX requirements

From POS screen:

* cashier can mark transaction tax-exempt,  
* reason is required,  
* certificate/reference is optional or required by reason,  
* cashier can modify a line’s tax rate,  
* override reason is required,  
* affected totals update immediately.

## Acceptance criteria

* A transaction can be marked tax-exempt only with a reason.  
* A line tax rate can be overridden only with a reason.  
* Tax totals recalculate immediately.  
* Completed transactions preserve exemption/override audit details.  
* Tax report can separate normal tax, exempt sales, overridden tax, and zero-tax non-taxable lines.

---

# Epic 3 — POS customer linkage and tender detail cleanup

## Problem

Customer, tender, refund, gift card, and store credit reporting depend on better transaction-level structure.

## Scope

Implement:

* optional customer link on all POS transactions,  
* add/edit customer path available from POS,  
* clearer tender detail entry,  
* keyboard shortcut for saving tender line,  
* tender-type-specific detail fields.

## Customer linkage

### Transaction fields

| Field | Notes |
| :---- | :---- |
| `customer_id` | Nullable |
| `customer_snapshot` | Recommended for audit |
| `customer_attached_by_user_id` | Nullable |
| `customer_attached_at` | Nullable |

### UX requirements

From POS:

* search customer,  
* create customer,  
* edit customer,  
* attach customer to active transaction,  
* remove customer before completion,  
* preserve customer snapshot on completion.

Customer attachment should be optional for normal sales but required or strongly encouraged for:

* customer pickup,  
* special orders,  
* store credit,  
* gift certificates/cards if tied to account,  
* buyback,  
* tax-exempt transactions.

## Tender detail fields

Current tender records should support detail fields by tender type.

### Common tender fields

| Field | Notes |
| :---- | :---- |
| `pos_transaction_id` | Required |
| `tender_type` | `cash`, `check`, `card`, `gift_certificate`, `store_credit`, etc. |
| `amount_cents` | Required |
| `direction` | `payment`, `refund` |
| `status` | `pending`, `accepted`, `voided` |
| `reference_number` | Optional |
| `details_snapshot` | JSON snapshot, if preferred |
| `accepted_by_user_id` | Required |
| `accepted_at` | Timestamp |

### Cash

| Field | Notes |
| :---- | :---- |
| `cash_received_cents` | Optional |
| `change_due_cents` | Calculated |

Cash should be the only tender that allows over-tendering for change.

### Check

| Field | Notes |
| :---- | :---- |
| `check_number` | Optional/required by store setting |
| `check_name` | Optional |
| `check_reference` | Optional |

### Card

| Field | Notes |
| :---- | :---- |
| `card_brand` | Optional |
| `last_four` | Optional |
| `authorization_code` | Optional |
| `processor_reference` | Optional |
| `terminal_id` | Optional |

### Gift certificate / gift card

| Field | Notes |
| :---- | :---- |
| `gift_card_account_id` | Nullable depending on implementation |
| `gift_card_number_snapshot` | Masked |
| `balance_before_cents` | Recommended |
| `balance_after_cents` | Recommended |

### Store credit

| Field | Notes |
| :---- | :---- |
| `store_credit_account_id` | Required if account-based |
| `balance_before_cents` | Recommended |
| `balance_after_cents` | Recommended |

## Shortcut behavior

P0 should include only shortcuts that support tendering and audit workflows.

| Action | Shortcut |
| :---- | :---- |
| Tender / Settle | `/t` |
| Cash | `/tc` |
| Check | `/tk` |
| Card | `/td` |
| Gift certificate | `/tg` |
| Store credit | `/ts` |
| Gift card | `/gc` |
| Balance | `/b` |
| Refund | `/r` |
| Discount previous line | `/d` |
| Discount transaction | `/dt` |
| Customer pickup | `/p` |
| Suspend | `/s` |
| Cancel | `/cxl` |
| Help | `/?` |

## Acceptance criteria

* Every POS transaction can optionally link to a customer.  
* Customer can be added or edited from POS without abandoning the transaction.  
* Tender entry fields change based on tender type.  
* Tender line can be saved by keyboard.  
* Cash supports change due.  
* Non-cash tenders cannot over-tender unless explicitly configured.  
* Tender activity can be reported by type, date, register, cashier, and transaction.

---

# Epic 4 — Order-line economics and eligibility

## Problem

Purchase orders need reliable line-level economics before purchasing, receiving, margin, and vendor reports can be trusted.

You noted that the app lost the ability to edit:

* line price,  
* cost,  
* supplier discount.

That should be restored before reporting.

## Scope

Implement editable PO line economics with recalculation rules and ordering eligibility validation.

## Suggested PO line fields

| Field | Notes |
| :---- | :---- |
| `product_variant_id` | Required |
| `vendor_id` | Through PO |
| `quantity_ordered` | Required |
| `list_price_cents` | Vendor/publisher list price snapshot |
| `expected_retail_price_cents` | Store selling price snapshot |
| `supplier_discount_percent` | Nullable |
| `expected_unit_cost_cents` | Expected net cost |
| `cost_source` | `vendor_source`, `manual`, `import`, `default`, etc. |
| `price_source` | `variant`, `vendor_source`, `manual`, `import` |
| `manual_cost_override` | Boolean |
| `manual_price_override` | Boolean |
| `line_note` | Optional |
| `source_snapshot` | Recommended JSON snapshot |

## Recalculation rules

Use predictable field behavior:

| User edits | System recalculates |
| :---- | :---- |
| List price \+ discount | Expected unit cost |
| Expected unit cost | Supplier discount, if list price exists |
| Supplier discount | Expected unit cost |
| Expected retail price | Does not change cost |
| Quantity | Line totals only |

Important distinction:

* **Retail price** affects what the store expects to sell the item for.  
* **List price** affects supplier discount math.  
* **Expected unit cost** affects purchasing and future receiving valuation.

## Order eligibility

Only allow normal vendor ordering for variants that are:

* not used,  
* orderable,  
* physical/inventory-tracked or otherwise explicitly orderable,  
* linked to an active product,  
* not discontinued unless override is allowed.

Recommended eligibility helper:

`Purchasing::OrderEligibilityResolver`

### Rules

| Condition | Behavior |
| :---- | :---- |
| Used variant | Block from normal vendor PO |
| Gift card / service / non-inventory variant | Block from vendor PO |
| Missing vendor source | Allow with warning, based on earlier Phase 5 decision |
| Discontinued product/variant | Block or require manager override |
| Inactive vendor | Block |
| Missing cost | Warn, but allow manual cost entry |

## Acceptance criteria

* User can edit list price, supplier discount, expected cost, and expected retail price on PO line.  
* Related fields recalculate immediately.  
* Manual overrides are preserved and visible.  
* Used variants cannot be added to normal vendor orders.  
* Missing vendor source produces warning, not hard block.  
* PO line stores enough snapshots to report expected margin later.

---

# Epic 5 — TBO simplification

## Problem

TBOs should represent individual demand, not behave like mini purchase orders.

You want:

* single-item TBO records,  
* no multi-line TBOs,  
* optional vendor,  
* easy conversion into purchase order lines later.

## Scope

Replace or revise TBO behavior so each TBO is one requested item.

## Suggested model

Consider naming the model `ToBeOrderedItem` or `PurchaseDemand`.

If keeping user-facing terminology, use `TboItem`.

| Field | Notes |
| :---- | :---- |
| `id` | Primary key |
| `product_variant_id` | Required |
| `quantity` | Required, default `1` |
| `preferred_vendor_id` | Nullable |
| `customer_id` | Nullable |
| `source` | `manual`, `pos`, `item_page`, `customer_request`, etc. |
| `status` | `open`, `ordered`, `cancelled`, `fulfilled` |
| `needed_by` | Optional |
| `note` | Optional |
| `created_by_user_id` | Required |
| `ordered_purchase_order_line_id` | Nullable |
| `fulfilled_at` | Nullable |
| `cancelled_at` | Nullable |

## TBO rules

* One TBO \= one variant.  
* Quantity can be greater than one, but no multiple line items.  
* Vendor is optional.  
* If preferred vendor is known, prefill it.  
* If customer is attached, preserve customer link.  
* TBO can later be pulled into a PO.  
* Once converted to PO line, status becomes `ordered`.

## Acceptance criteria

* User can create a TBO for exactly one variant.  
* User cannot add multiple line items to a TBO.  
* Vendor is optional.  
* Customer link is optional.  
* TBO can be filtered by vendor, status, customer, and item.  
* TBO records are ready for future “build order from TBOs” workflow.

---

# Epic 6 — Item/vendor data quality

## Problem

Reporting and ordering will depend on reliable vendor defaults and clearer item warnings.

## Scope

Implement:

* preferred vendor on products,  
* preferred vendor on variants,  
* Ingram import option to set preferred/default vendor,  
* cleaner warning logic on item overview pages.

## Preferred vendor fields

Use one term consistently. I recommend **preferred vendor** in the app UI.

### `products`

| Field | Notes |
| :---- | :---- |
| `preferred_vendor_id` | Nullable FK to vendors |

### `product_variants`

| Field | Notes |
| :---- | :---- |
| `preferred_vendor_id` | Nullable FK to vendors |

## Vendor precedence

When choosing a vendor for ordering:

1. Variant preferred vendor.  
2. Product preferred vendor.  
3. Active product variant vendor marked default/preferred.  
4. Active product vendor source.  
5. No vendor; user must choose or continue with warning where allowed.

## Ingram import option

Add import setting:

“Set Ingram as preferred vendor for imported/updated products and variants.”

Behavior:

* If product is created, set product preferred vendor.  
* If variant is created, set variant preferred vendor.  
* If variant already exists, update preferred vendor only if user selected overwrite/update option.  
* Create or update vendor source records when Ingram item data is available.  
* Do not overwrite manually selected preferred vendor unless explicitly requested.

## Item warnings

Create a centralized warning builder instead of scattering conditions through views.

Suggested service:

`Items::OperationalWarningBuilder`

### Warning categories

| Severity | Meaning |
| :---- | :---- |
| `blocking` | User cannot complete expected action |
| `warning` | Action allowed, but likely problematic |
| `info` | Useful operational note |

### Suggested warnings

| Warning | Severity |
| :---- | :---- |
| Variant has no price | Blocking for sale |
| Variant has no tax category | Warning/blocking depending on app rules |
| Variant is inactive | Blocking |
| Variant is non-inventory but has stock balance | Warning |
| Variant is inventory-tracked but no stock record exists | Info/warning |
| No preferred/default vendor | Warning for ordering |
| No active vendor source | Warning for ordering |
| Used variant cannot be vendor ordered | Info |
| Product/variant discontinued | Warning/blocking |
| Cost missing | Warning |
| External identifier missing | Info |

## Acceptance criteria

* Product form supports nullable preferred vendor.  
* Variant form supports nullable preferred vendor.  
* Ingram import can assign preferred vendor.  
* Existing manually selected preferred vendors are not overwritten unless requested.  
* Item overview warnings are centralized, consistent, and actionable.  
* Warnings distinguish sale issues, ordering issues, inventory issues, and data-quality issues.

---

# Epic 7 — Buyback printable receipt

## Problem

Buyback records need presentable customer-facing output and internal audit support.

## Scope

Implement printable buyback receipt for completed buybacks.

Proposal printout cleanup can be included if small, but the completed receipt is P0.

## Receipt contents

### Header

* store name,  
* store address/contact,  
* buyback receipt number,  
* date/time,  
* cashier/buyer,  
* customer if attached.

### Lines

| Field | Notes |
| :---- | :---- |
| Item description | Snapshot |
| Identifier | ISBN/UPC/SKU if available |
| Condition | If captured |
| Quantity | Usually 1, but support quantity |
| Offer amount | Cash/store credit value |
| Accepted/rejected status | If receipt includes proposal context |

### Totals

* total accepted value,  
* cash paid,  
* store credit issued,  
* rejected line count if relevant.

### Footer

* buyback policy text,  
* “All buybacks are final” language if desired,  
* signature line if store requires,  
* internal transaction/reference number.

## Audit behavior

* Receipt should be reproducible after completion.  
* Use snapshots, not live item data.  
* Buyback record should show whether receipt was printed, reprinted, and by whom if that matters.

## Acceptance criteria

* Completed buyback can generate printable customer receipt.  
* Receipt uses buyback snapshots.  
* Receipt clearly shows payout method.  
* Receipt can be reprinted.  
* Buyback activity can later be reported by date, customer, buyer, payout method, and item.

---

# Suggested implementation order

## 1\. POS discount model and calculation

This is the highest-risk reporting dependency.

Deliver first:

* discount reasons,  
* discount applications,  
* stacking support,  
* non-discountable resolver,  
* gift card exclusion,  
* basic UI.

## 2\. POS tax exception model

Deliver second:

* transaction tax exemption,  
* line override,  
* reasons,  
* recalculation,  
* audit fields.

## 3\. POS tender/customer cleanup

Deliver third:

* customer link,  
* customer add/edit path,  
* tender detail fields,  
* tender save shortcut.

## 4\. Order-line economics

Deliver fourth:

* editable price/cost/discount,  
* recalculation,  
* snapshots,  
* order eligibility checks.

## 5\. Preferred vendor \+ item warnings

Deliver fifth:

* preferred vendor fields,  
* Ingram import option,  
* warning builder.

## 6\. TBO simplification

Deliver sixth:

* single-item TBO model/UI,  
* optional vendor,  
* conversion-ready status structure.

## 7\. Buyback receipt

Deliver seventh:

* printable completed receipt,  
* snapshot-based output.

---

# P0 exclusions

These should remain out of P0 unless they fall out naturally from the above work:

* full buy-2-get-1 promotion engine,  
* sales-based order suggestions,  
* combining unsubmitted orders,  
* moving PO lines between vendors,  
* receiving multiple POs on one receipt,  
* mass item updates,  
* external data refresh/overwrite workflow,  
* full `/items` page redesign,  
* thumbnail/image attachment work.

They are valuable, but they do not need to block report readiness.  