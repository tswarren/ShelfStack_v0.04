# Phase 7C Used Buyback — Workflow Correction & Implementation Instructions

Branch: `phase-7c-used-buyback`
Audience: ShelfStack programmers
Purpose: revise the current Phase 7C implementation so the buyback workflow matches actual bookstore counter operations before merge.

This document consolidates the review observations and the proposed corrected workflow. The current branch is structurally close, but it moves too quickly from “resolved item” to “accepted line.” The corrected workflow must separate **intake**, **pricing**, **proposal**, **customer decision**, **payout selection**, and **final posting**. 

---

# 1. Summary

The current Phase 7C branch has the right foundation:

* `buyback_sessions`
* `buyback_lines`
* `buyback_voids`
* dual eligibility checks
* `used_buyback` inventory posting
* `buyback_void` reversal posting
* trade-credit stored value issue
* cash paid-out movement
* source/review markers for intake-created records

However, the workflow is not yet correct. The branch currently exposes line actions that mostly jump from **Resolve/Create** directly to **Accept/Reject**, with no full proposal-pricing step. The line actions partial only shows resolve, create intake item, accept, and reject controls.  The controller has `price_override` and `offer_override` actions, but the UI does not make pricing and offer adjustment a first-class part of the workflow.

The workflow should become:

```text
1. Select/add/edit customer
2. Intake items
3. Work the list: match/create records, condition, pricing, offers
4. Save/print proposal
5. Customer accepts/declines per line
6. Customer may donate refused items
7. Staff selects payout method
8. Final processing posts cash/trade credit/inventory
```

---

# 2. Core rule

No irreversible operational effects should happen until final processing.

Before final processing, the session may create draft/proposal data and constrained intake records, but it must not:

```text
create cash paid-out movement
issue trade credit
post inventory
mark inventory lines posted
complete the buyback
```

Those happen only when the customer has made decisions and staff completes the final buyback.

---

# 3. Existing issues to fix before merge

## 3.1 Stored-value ledger entries need buyback source linkage

`StoredValue::Post` supports a `source:` argument and writes that source to the ledger entry.

But `StoredValue::Issue` and `StoredValue::VoidEntry` do not currently accept/pass `source`.

### Required change

Extend:

```ruby
StoredValue::Issue
StoredValue::VoidEntry
```

to accept:

```ruby
source: nil
```

and pass it to `StoredValue::Post`.

Buyback issue should call:

```ruby
StoredValue::Issue.call(
  account: account,
  store: session.store,
  actor: actor,
  amount_cents: amount,
  reason_code: reason,
  source: session,
  notes: "Buyback #{session.buyback_number}"
)
```

Buyback void should call:

```ruby
StoredValue::VoidEntry.call(
  entry: session.stored_value_ledger_entry,
  store: session.store,
  actor: actor,
  reason_code: reason,
  source: buyback_void,
  notes: "Void buyback #{session.buyback_number}"
)
```

---

## 3.2 Trade-credit receipt must show a redeemable identifier

The current receipt builder only exposes a masked identifier display.  A masked value is not enough for later redemption if POS redemption depends on identifier scan/lookup or explicit account selection.

### Required change

Implement a buyback trade-credit issuance slip.

The slip must provide one of:

```text
full generated identifier at time of issue
authorized reprint/decrypt path
printed barcode/lookup code
```

The final receipt can remain masked, but the issuance slip must give the customer something usable for redemption.

---

## 3.3 Void inventory mapping must support duplicate variants

`Buybacks::PostVoidInventory` currently maps void entries back to lines using `product_variant_id`.  That can fail if a buyback includes two lines for the same graded used variant.

### Required change

Map void entries by original ledger line number:

```ruby
void_entry = posting.inventory_ledger_entries.find_by(
  line_number: line.inventory_ledger_entry.line_number
)
```

This preserves one-to-one line reversal history.

---

## 3.4 Existing catalog item with no product should not block intake

`CreateIntakeItem` currently raises if an existing catalog item has no active product.  The buyback workflow should create the missing buyback-intake product and graded used variant.

### Required change

If an existing catalog item is found but no active product exists:

```text
create product
create/find graded used variant
mark created product/variant source = buyback_intake
mark created product/variant needs_review = true
continue workflow
```

---

## 3.5 `Format.order(:sort_order)` fallback is unsafe

`CreateIntakeItem` falls back to:

```ruby
Format.active_records.order(:sort_order).first
```

The `Format` model does not show a `sort_order` field.

### Required change

Use an existing column:

```ruby
Format.active_records.order(:name).first
```

or:

```ruby
Format.active_records.order(:format_key).first
```

---

# 4. Corrected user workflow

## Stage 1 — Select, create, or edit seller/customer

### Goal

Every buyback must start with a known customer.

Anonymous sellers are not allowed. `BuybackSession` already requires `customer_id`.

### Required UI

The buyback start screen must support:

```text
Search/select existing customer
Create new customer
Edit existing customer
Start buyback
```

The user already has a path to create a customer. Add a path to edit the selected existing customer before continuing.

### Programmer notes

Add links/buttons from the seller panel:

```text
New customer
Edit customer
Change customer
```

After create/edit, return to the buyback workflow.

---

## Stage 2 — Intake items

### Goal

Staff should quickly scan/enter everything the customer brought in without needing to resolve, price, or accept each item immediately.

### Required behavior

The intake screen should allow:

```text
scan ISBN/barcode
enter identifier manually
enter title manually
add line
remove line
save draft
resume draft later
```

At this stage, lines may be incomplete.

### Recommended status

Use either:

```text
pending
```

with UI label “Intake,” or add:

```text
intake
```

to `BuybackLine::STATUSES`.

---

## Stage 3 — Work the item list

### Goal

Staff works each line into a priced proposal.

Each line should support:

```text
match existing catalog/product/variant
create constrained intake record if needed
select buyback condition
show proposed resale price
show proposed cash offer
show proposed trade-credit offer
edit resale price
edit cash offer
edit trade-credit offer
mark special flags, such as signed copy
save line proposal
```

### Important correction

Do not accept the line immediately after selecting a variant.

Current code allows direct accept after variant selection.  That should be replaced with an explicit pricing/proposal step.

---

# 5. Pricing model changes

## 5.1 Separate suggested, proposed, and accepted values

The current `accepted_offer_cents` is doing too much. It is being used before final customer acceptance and before payout method is selected.

### Add or repurpose fields

Recommended `buyback_lines` pricing fields:

```text
suggested_resale_price_cents
proposed_resale_price_cents

suggested_cash_offer_cents
proposed_cash_offer_cents

suggested_trade_credit_offer_cents
proposed_trade_credit_offer_cents

accepted_offer_cents
```

Meaning:

| Field type             | Meaning                                              |
| ---------------------- | ---------------------------------------------------- |
| `suggested_*`          | System-calculated values from pricing rules          |
| `proposed_*`           | Staff-facing offer values presented to the customer  |
| `accepted_offer_cents` | Final payout value, set only during final processing |

### Final assignment rule

At final processing:

```ruby
if payout_mode == "cash"
  line.accepted_offer_cents = line.proposed_cash_offer_cents
elsif payout_mode == "trade_credit"
  line.accepted_offer_cents = line.proposed_trade_credit_offer_cents
elsif line.donated_by_customer?
  line.accepted_offer_cents = 0
end
```

---

## 5.2 Cash and trade-credit offers must be independently editable

The proposal view must show and allow editing of:

```text
proposed cash offer
proposed trade-credit offer
```

These should not be hidden behind one generic “Offer” field.

### Required UI columns

Replace:

```text
Offer
```

with:

```text
Cash offer
Trade-credit offer
Final offer
```

The current line table displays a single offer value and falls back to cash offer.  That is why the trade-credit value feels invisible.

---

## 5.3 Override behavior

Override fields should distinguish resale, cash, and trade credit.

Recommended additions:

```text
resale_price_overridden
cash_offer_overridden
trade_credit_offer_overridden
resale_price_override_reason
cash_offer_override_reason
trade_credit_offer_override_reason
```

If keeping one `override_reason`, make sure the UI clearly identifies which field was overridden.

### Service changes

Replace or extend:

```ruby
Buybacks::ApplyOfferOverride
```

Current `ApplyOfferOverride` only writes `accepted_offer_cents`.

It should instead support:

```ruby
offer_type: "cash" | "trade_credit"
```

and update:

```text
proposed_cash_offer_cents
```

or:

```text
proposed_trade_credit_offer_cents
```

not `accepted_offer_cents`.

---

# 6. Condition update behavior

## Required behavior

Throughout the workflow, staff may update an item’s condition.

When condition changes:

```text
recalculate suggested resale price
recalculate suggested cash offer
recalculate suggested trade-credit offer
update proposed values unless manually overridden
show that recalculation happened
```

The current `UpdateLine` recalculates suggested values when product condition or subdepartment changes.  That is good, but it must be extended to update the new proposed fields consistently.

### MVP rule

For MVP:

```text
If a value has not been manually overridden:
  replace proposed value with recalculated suggested value.

If a value has been manually overridden:
  keep the overridden proposed value.
```

### Example

```text
Condition changed from Used - Good to Used - Fine.

Suggested resale changed from $8.00 to $10.00.
Suggested cash changed from $2.00 to $2.50.
Suggested trade credit changed from $3.00 to $3.50.
```

---

# 7. Fix condition-rate inconsistency during intake

## Current problem

When creating a new intake variant, `CreateIntakeItem` passes:

```ruby
line.accepted_resale_price_cents || line.suggested_resale_price_cents || 0
```

into variant creation.

That means the new used variant may be created with:

```text
0
stale suggested resale price
incorrect price before condition factor is applied
```

Then later pricing may use `variant_selling_price` as the base, compounding the incorrect value.

## Required correction

Do not create or update the graded used variant with a placeholder/stale resale price.

Correct sequence:

```text
select condition
select/enter base/list price
run PriceLine
set suggested resale/cash/trade values
set proposed resale/cash/trade values
create/find graded used variant using proposed resale price
show proposal line
```

## Pricing base precedence

For newly created intake items, pricing should use:

```text
1. staff-entered list/base price
2. product list_price_cents
3. existing variant selling_price_cents, only if selecting an existing variant
4. manual resale price
```

Avoid using a just-created variant’s `selling_price_cents` as the initial pricing base.

---

# 8. Proposal stage

## Goal

Staff must be able to save and print a proposal before the customer decides.

### Session status

Use existing:

```text
quoted
```

or add:

```text
proposal
```

Recommended session lifecycle:

```text
draft
intake
quoted
customer_decision
completed
cancelled
voided
```

If avoiding new statuses, map as:

| UI stage                      | Existing status |
| ----------------------------- | --------------- |
| Intake                        | `draft`         |
| Proposal saved                | `quoted`        |
| Customer decision in progress | `quoted`        |
| Finalized                     | `completed`     |

## Proposal document

Add:

```ruby
Buybacks::ProposalBuilder
```

or extend `ReceiptBuilder` with a proposal mode.

Proposal should show:

```text
buyback/proposal number
store
seller/customer
staff user
date/time
line item
identifier
condition
proposed resale price
proposed cash offer
proposed trade-credit offer
notes
proposal expiration, optional
customer decision area
```

The proposal must not imply that inventory, cash, or trade credit has already been posted.

---

# 9. Customer decision stage

## Required behavior

Customer accepts or declines offer per line.

Add shortcuts:

```text
Accept all
Decline all
Donate declined
Return declined
```

## Line outcomes should be decision-oriented

Current line outcomes combine payout and decision:

```text
accepted_for_cash
accepted_for_trade_credit
accepted_as_donation
rejected_returned_to_seller
rejected_recycle
```

That is too early because payout method is selected later.

### Recommended outcomes

```text
accepted_by_customer
declined_by_customer
donated_by_customer
rejected_by_store
recycle_with_permission
```

Final payout is a session-level choice, not a line outcome.

### Inventory and payout effects

| Outcome                   |                       Inventory posted? |              Payout? |
| ------------------------- | --------------------------------------: | -------------------: |
| `accepted_by_customer`    |                                     Yes | Cash or trade credit |
| `donated_by_customer`     |                                     Yes |                 Zero |
| `declined_by_customer`    |                                      No |                 None |
| `rejected_by_store`       |                                      No |                 None |
| `recycle_with_permission` | No, unless explicitly modeled otherwise |                 None |

---

# 10. Payout selection

## Required behavior

Payout method is selected after customer decisions are saved.

MVP payout methods:

```text
cash
trade_credit
no_value_donation
```

However, clarify this rule:

```text
no_value_donation is only the session payout mode when all posted lines are donations.
```

If a session includes both paid accepted lines and donated lines, payout mode should be:

```text
cash
```

or:

```text
trade_credit
```

Donated lines still post with zero cost.

---

# 11. Final processing

## Required behavior

Final processing creates operational effects atomically.

Existing `CompleteSession` already has the right general transaction shape.  It needs to run after proposal/customer decision, not immediately after early line acceptance.

Final processing should:

```text
validate customer/seller requirements
validate line decisions
validate payout mode
derive accepted_offer_cents per line from selected payout mode
create cash paid_out, if cash
issue trade_credit, if trade_credit
post accepted/donated inventory
snapshot seller fields
snapshot final line values
mark completed
generate final receipt/slip
```

## Completion line selection

Final posting lines are:

```text
accepted_by_customer
donated_by_customer
```

Declined/rejected lines do not post.

## Cost basis

```text
accepted_by_customer + cash payout:
  unit_cost_cents = proposed_cash_offer_cents

accepted_by_customer + trade_credit payout:
  unit_cost_cents = proposed_trade_credit_offer_cents

donated_by_customer:
  unit_cost_cents = 0
  cost_source = no_value_donation
```

---

# 12. Services to add/change

## Replace current acceptance model

Current `AcceptLine` sets payout-specific outcomes and accepted offer too early.

Refactor toward:

```ruby
Buybacks::UpdateProposalLine
Buybacks::SaveProposal
Buybacks::RecordCustomerDecision
Buybacks::AcceptAllLines
Buybacks::DeclineAllLines
Buybacks::DonateDeclinedLines
Buybacks::CompleteSession
```

## Recommended service responsibilities

### `Buybacks::UpdateProposalLine`

Updates:

```text
condition
subdepartment
base/list price
proposed resale price
proposed cash offer
proposed trade-credit offer
manual override flags/reasons
signed/special flags
processing flags
```

Recalculates suggested values when condition/subdepartment/base price changes.

---

### `Buybacks::SaveProposal`

Sets session to:

```text
quoted
```

Validates:

```text
all proposal lines have condition
all proposal lines have proposed resale/cash/trade values
all accepted-intent lines have eligible variants or constrained intake records
```

Does not post inventory/cash/stored value.

---

### `Buybacks::RecordCustomerDecision`

Sets line outcome:

```text
accepted_by_customer
declined_by_customer
donated_by_customer
rejected_by_store
recycle_with_permission
```

Does not assign final payout amount.

---

### `Buybacks::CompleteSession`

Refactor to:

```text
derive accepted_offer_cents from selected payout mode
post only accepted/donated lines
allow donated lines within cash/trade_credit sessions
require no_value_donation mode only when all posted lines are donations
```

---

# 13. UI changes

## 13.1 Session screen should become staged

Recommended sections:

```text
Seller
Intake
Work Items / Pricing
Proposal
Customer Decision
Payout
Final Processing
```

Only show later sections when prior sections are sufficiently complete.

---

## 13.2 Line table columns

Replace current compact table with:

| Column        | Purpose                               |
| ------------- | ------------------------------------- |
| #             | Line number                           |
| Item          | Title, identifier, match status       |
| Condition     | Buyback condition                     |
| Proposed sale | Editable proposal resale              |
| Cash offer    | Editable proposed cash                |
| Trade credit  | Editable proposed trade               |
| Decision      | Customer decision                     |
| Status        | Intake/resolved/priced/offered/posted |
| Actions       | Edit, resolve, reject, donate, etc.   |

---

## 13.3 Line pricing panel

Each line needs a visible pricing panel with:

```text
condition
base/list price
suggested resale price
proposed resale price
suggested cash offer
proposed cash offer
suggested trade-credit offer
proposed trade-credit offer
override reason
signed copy flag
special notes
needs label/review/cleaning flags
save line proposal
```

---

## 13.4 Proposal actions

Add session-level buttons:

```text
Save proposal
Print proposal
Accept all
Decline all
Donate declined
Return declined
Proceed to payout
```

---

## 13.5 Payout panel

After decisions:

```text
Paid accepted total
Donation count/value
Declined count
Cash payout total
Trade-credit payout total
Select payout method
Complete buyback
```

---

# 14. Data model changes

## Required additions to `buyback_lines`

Add:

```text
proposed_resale_price_cents
proposed_cash_offer_cents
proposed_trade_credit_offer_cents
cash_offer_overridden
trade_credit_offer_overridden
cash_offer_override_reason
trade_credit_offer_override_reason
resale_price_override_reason
base_price_cents
base_price_source
customer_decision_at
```

Potentially replace current outcome values with:

```text
accepted_by_customer
declined_by_customer
donated_by_customer
rejected_by_store
recycle_with_permission
```

If preserving old values for compatibility, add new `customer_decision` field instead:

```text
customer_decision
```

and treat old `outcome` as deprecated or internal.

## Optional additions to `buyback_sessions`

```text
proposal_saved_at
proposal_printed_at
customer_decision_at
payout_selected_at
```

---

# 15. Tests to add

Add tests for the workflow correction, not just completion.

## Pricing and condition tests

```text
changing condition recalculates suggested resale/cash/trade
changing condition updates proposed values when not overridden
changing condition preserves overridden proposed cash/trade values
new intake item applies condition factor before variant creation
new intake item does not create variant with zero/stale resale price
```

## Trade-credit tests

```text
trade-credit proposed value can be edited
cash proposed value can be edited independently
final accepted offer uses proposed_trade_credit_offer_cents when payout_mode = trade_credit
final accepted offer uses proposed_cash_offer_cents when payout_mode = cash
```

## Proposal tests

```text
proposal can be saved without posting inventory
proposal can be printed without issuing payout
proposal shows cash and trade-credit values
```

## Decision tests

```text
accept all marks all offered lines accepted_by_customer
decline all marks all offered lines declined_by_customer
donate declined marks declined lines donated_by_customer
declined lines do not post inventory
donated lines post inventory with zero cost
```

## Completion tests

```text
cash completion posts paid_out only after customer decision
trade-credit completion issues stored value only after customer decision
completion derives accepted_offer_cents from payout mode
mixed accepted + donated lines complete correctly
no_value_donation mode allowed only when all posted lines are donations
```

## Existing fix tests

```text
stored value issue source is buyback_session
stored value void source is buyback_void
void inventory maps duplicate variants by original line number
existing catalog item with no product creates buyback-intake product
format fallback does not use missing sort_order column
```

---

# 16. Suggested implementation order

## Step 1 — Fix blocking correctness issues

```text
stored value source passthrough
redeemable trade-credit issuance slip
void duplicate-line mapping
existing catalog item with no product
Format fallback
```

## Step 2 — Add proposal pricing fields

```text
proposed resale
proposed cash
proposed trade credit
override flags/reasons
base price/source
```

## Step 3 — Refactor line services

```text
UpdateProposalLine
RecordCustomerDecision
AcceptAllLines
DeclineAllLines
DonateDeclinedLines
```

## Step 4 — Refactor UI into staged workflow

```text
Seller
Intake
Work Items
Proposal
Customer Decision
Payout
Complete
```

## Step 5 — Refactor completion

```text
derive final accepted_offer_cents at completion
post only accepted/donated lines
allow donated lines in cash/trade sessions
```

## Step 6 — Add tests and documentation

```text
service tests
integration tests
proposal/receipt tests
docs/spec updates
implementation completion note
```

---

# 17. Definition of done

This correction is done when:

1. Staff can select, create, or edit a customer before starting/continuing buyback.
2. Staff can intake multiple items without matching/pricing immediately.
3. Staff can resolve or create records per line.
4. Staff can select/update condition per line.
5. Condition changes recalculate suggested resale, cash, and trade-credit values.
6. Staff can edit proposed sale price.
7. Staff can edit proposed cash offer.
8. Staff can edit proposed trade-credit offer.
9. Staff can save and print a proposal before customer decision.
10. Proposal does not post inventory, cash, or stored value.
11. Customer can accept/decline per line.
12. Staff has Accept All and Decline All shortcuts.
13. Customer can donate refused/declined items.
14. Payout method is selected after decisions.
15. Final processing creates cash paid-out or trade credit only after decision/payout selection.
16. Accepted paid lines post inventory with cost equal to the selected payout value.
17. Donated lines post inventory with zero cost.
18. Declined/rejected lines do not post inventory.
19. Trade-credit issue/void ledger entries are sourced to buyback records.
20. Trade-credit receipt/slip contains a usable redemption identifier.
21. Void inventory maps duplicate variants correctly.
22. Existing catalog item without product can continue through constrained buyback intake.
23. No newly created intake variant is created with stale/placeholder condition pricing.
24. Tests cover the full staged workflow.

---

# Bottom line for programmers

The current branch has a strong foundation, but the workflow should be refactored before merge.

The implementation should stop treating line acceptance as the next step after resolve/create. Instead, Phase 7C should work like this:

```text
Intake items.
Resolve/create records.
Price the proposal.
Print/present proposal.
Record customer decisions.
Choose payout.
Post final buyback.
```

This will fix the missing trade-credit adjustment path and the inconsistent condition-rate behavior because pricing becomes a first-class workflow stage rather than a side effect of item creation or acceptance.
