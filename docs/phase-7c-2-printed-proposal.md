# Spec: Printable Buyback Proposal & Seller Election

## Purpose

Create a formal, letter-size printable buyback proposal that staff can present to the seller before customer decision and payout. The document should clearly show:

* Items the store is willing to buy.
* Items the store is not accepting.
* Estimated resale, cash offer, and trade-credit offer.
* Seller payout election.
* Disposition choice for unaccepted/declined items.
* Seller and staff sign-off.
* Internal processing section.

The current print proposal is too minimal. It only renders a basic heading, seller, line table, totals, and back link.  It also renders inside the standard application layout, which is likely contributing to the “print page is blank” issue.

The uploaded proposal examples contain the right business sections: itemized valuation, rejected items, payout choice, disposition of unaccepted items, final sign-off, and internal register-use area. 

---

# 1. Scope

## In scope

Implement a **letter-size printable Buyback Proposal & Seller Election** document.

Primary output:

```text
8.5" x 11" printable HTML page
```

The document should be printable from the browser using a dedicated print layout and print stylesheet.

## Out of scope for this pass

* 3-inch thermal receipt proposal format.
* Full regulatory/legal compliance workflow.
* Barcode/QR proposal lookup.
* PDF generation.
* Electronic signature capture.
* Store-specific legal text management UI.

---

# 2. Terminology

Use **Buyback Proposal & Seller Election** as the document title.

Avoid “trade-in” unless that term is already used elsewhere in the app. ShelfStack has been using **buyback**, so the print document should stay consistent.

Recommended title:

```text
BUYBACK PROPOSAL & SELLER ELECTION
```

---

# 3. Business rules

## 3.1 Proposal is not final payout

The proposal must clearly state that it is not a completed transaction.

Required language near the top:

```text
This proposal does not finalize payout. Final payout is issued only after the seller selects a payout option and staff completes the buyback.
```

## 3.2 Seller chooses one payout method

The seller must select only one:

```text
[ ] Accept cash offer
[ ] Accept trade-credit offer
[ ] Reject offer and reclaim items
```

The document should show both offer values, but it must not imply that both are payable.

## 3.3 Unaccepted item disposition is separate

The seller must choose what happens to items not purchased by the store:

```text
[ ] Return unaccepted items to seller today
[ ] Seller authorizes store to donate, recycle, or discard unaccepted items
```

This supports the current workflow where refused items may be marked as donated.

## 3.4 Identification / seller verification section is configurable

Do **not** hardcode a full government ID block as a universal requirement.

Instead, include a configurable verification section:

```text
Seller verification:
[ ] Required seller information verified
[ ] ID checked, if required by store policy
Verified by: __________
```

A fuller ID block may be added later behind store configuration. The uploaded proposal includes a government-issued ID block, but that should be treated as store-policy/legal-configuration content, not a default universal requirement. 

---

# 4. Proposed document layout

## 4.1 Header

Required fields:

```text
Store name
Store address/contact, if available
Document title
Buyback/proposal number
Date/time
Staff evaluator
Seller/customer name
Customer phone/email, if available
Customer account/customer number, if available
```

Example:

```text
BOOKSTORE NAME
BUYBACK PROPOSAL & SELLER ELECTION

Proposal #: BB-001-B000123
Date/time: 06/24/2026 12:05 PM
Staff: JDS
Seller: Pat Seller
Phone: (555) 123-4567
Customer #: CUST-000421
```

---

## 4.2 Seller verification summary

Show a compact seller/customer verification checklist.

Example:

```text
SELLER VERIFICATION

[ ] Seller/customer information verified
[ ] Required ID checked, if required by store policy
[ ] Seller confirms they are authorized to sell/trade these items

Verified by: ______________________
```

Do not print full ID numbers by default.

---

## 4.3 Items offered for purchase

Show all proposal lines the store is willing to buy.

Recommended columns:

| Column             | Source                                                           |
| ------------------ | ---------------------------------------------------------------- |
| #                  | `buyback_line.line_number`                                       |
| Item               | `title_snapshot`                                                 |
| Identifier         | `identifier_entered` or primary identifier snapshot if available |
| Condition          | `condition_snapshot` or `product_condition.name`                 |
| Estimated resale   | `proposed_resale_price_cents`                                    |
| Cash offer         | `proposed_cash_offer_cents`                                      |
| Trade-credit offer | `proposed_trade_credit_offer_cents`                              |

Example table:

```text
ITEMS OFFERED FOR PURCHASE

#  Item                      Identifier       Condition    Resale   Cash   Credit
1  The Great Gatsby          9780000000001    Very Good    $6.00    $1.50  $2.40
2  Sapiens                   9780000000002    Like New     $12.00   $3.00  $4.80
```

---

## 4.4 Items not accepted

Show lines with store rejection / not accepted outcomes separately.

Recommended columns:

| Column | Source                                |
| ------ | ------------------------------------- |
| #      | `line_number`                         |
| Item   | `title_snapshot`                      |
| Reason | `buyback_reject_reason.name` or notes |

Example:

```text
ITEMS NOT ACCEPTED FOR PURCHASE

#  Item                         Reason
5  Dune                         Heavy water damage / musty odor
6  Da Vinci Code                Overstocked title
```

---

## 4.5 Totals

Show totals in a summary block.

Required totals:

```text
Total estimated resale value
Total cash offer
Total trade-credit offer
```

Example:

```text
PROPOSAL TOTALS

Estimated resale value:       $27.00
Cash offer:                    $6.75
Trade-credit offer:           $10.80
```

---

## 4.6 Seller election

Include checkboxes and signature lines.

Recommended wording:

```text
SELLER ELECTION

Choose one payout option:

[ ] I accept the cash offer of: __________________________ $6.75

[ ] I accept the trade-credit offer of: __________________ $10.80

[ ] I reject this offer and will reclaim my items today.
```

---

## 4.7 Unaccepted item disposition

Recommended wording:

```text
UNACCEPTED ITEMS

Choose one option for items not accepted for purchase or declined by seller:

[ ] Return unaccepted items to me today.

[ ] I authorize the store to donate, recycle, or discard unaccepted items according to store policy.
```

Optional store-policy note:

```text
Items left behind may be handled according to store policy.
```

Make this text configurable later.

---

## 4.8 Acknowledgment and signature

Recommended wording:

```text
ACKNOWLEDGMENT

By signing below, I confirm that I am authorized to sell or trade these items.
I understand that accepted items become final once payout is processed.

Seller signature: _______________________________ Date: _______________

Staff signature: ________________________________ Date: _______________
```

Keep this short. Avoid long legal blocks in hardcoded templates.

---

## 4.9 Internal register-use section

Recommended section:

```text
FOR INTERNAL USE ONLY

[ ] Cash paid out
[ ] Trade credit issued

Cash movement ID: _______________________________
Stored value account/reference: __________________
Processed by: ___________________________________
Processed date/time: ____________________________
```

This is not the final receipt. It is a processing aid.

---

# 5. Print layout requirements

## 5.1 Dedicated print layout

Create a dedicated print layout:

```text
app/views/layouts/print.html.erb
```

Do not render the print proposal inside the standard application layout.

Current controller renders `layout: "application"` for `print_proposal`.  Change this to:

```ruby
render layout: "print"
```

## 5.2 Print CSS

The print layout must include CSS for letter paper.

Minimum CSS requirements:

```css
@page {
  size: letter;
  margin: 0.5in;
}

body {
  background: white;
  color: black;
  font-size: 11pt;
}

.print-page {
  max-width: 7.5in;
  margin: 0 auto;
}

.no-print {
  display: none !important;
}

table {
  width: 100%;
  border-collapse: collapse;
}

th,
td {
  border-bottom: 1px solid #ccc;
  padding: 4px 6px;
  vertical-align: top;
}

thead {
  display: table-header-group;
}

tr {
  break-inside: avoid;
}

.signature-line {
  border-bottom: 1px solid #000;
  height: 1.5em;
}
```

## 5.3 No app chrome

Printed output must not include:

```text
Navigation
Sidebar
Action buttons
Back link
Flash messages
Regular app header/footer
```

The current proposal view includes a “Back to session” link, which should be shown only on screen and hidden from print.

Use:

```erb
<div class="no-print">
  <button onclick="window.print()">Print proposal</button>
  <%= link_to "Back to buyback", buybacks_session_path(@buyback_session) %>
</div>
```

---

# 6. Controller changes

Current method:

```ruby
def print_proposal
  @proposal = ProposalBuilder.build(@buyback_session)
  @buyback_session.update!(proposal_printed_at: Time.current)
  AuditEvents.record!(actor: current_user, event_name: "buyback.proposal.printed", auditable: @buyback_session)
  render layout: "application"
end
```

Required change:

```ruby
def print_proposal
  @proposal = ProposalBuilder.build(@buyback_session)
  @buyback_session.update!(proposal_printed_at: Time.current)
  AuditEvents.record!(
    actor: current_user,
    event_name: "buyback.proposal.printed",
    auditable: @buyback_session
  )

  render layout: "print"
end
```

Also ensure the route only permits proposal printing when the session is `quoted`, `decision`, or later.

---

# 7. View changes

Replace:

```text
app/views/buybacks/sessions/print_proposal.html.erb
```

with a structured print view.

Suggested structure:

```erb
<% content_for :title, "Buyback Proposal #{@buyback_session.buyback_number}" %>

<div class="no-print print-actions">
  <button type="button" onclick="window.print()">Print proposal</button>
  <%= link_to "Back to buyback", buybacks_session_path(@buyback_session) %>
</div>

<section class="proposal-header">
  <h1>BUYBACK PROPOSAL & SELLER ELECTION</h1>
  <p><strong><%= @buyback_session.store.name %></strong></p>

  <dl class="proposal-meta">
    <dt>Proposal #</dt>
    <dd><%= @buyback_session.buyback_number %></dd>

    <dt>Date/time</dt>
    <dd><%= l(@buyback_session.proposal_saved_at || Time.current, format: :short) %></dd>

    <dt>Seller</dt>
    <dd><%= @buyback_session.customer.display_name %></dd>

    <dt>Staff</dt>
    <dd><%= @buyback_session.created_by_user&.display_name || @buyback_session.created_by_user&.username %></dd>
  </dl>
</section>

<section>
  <h2>Seller Verification</h2>
  <p>[ ] Seller/customer information verified</p>
  <p>[ ] Required ID checked, if required by store policy</p>
  <p>Verified by: _______________________________</p>
</section>

<section>
  <h2>Items Offered for Purchase</h2>
  <!-- table -->
</section>

<section>
  <h2>Items Not Accepted for Purchase</h2>
  <!-- table -->
</section>

<section>
  <h2>Proposal Totals</h2>
  <!-- totals -->
</section>

<section>
  <h2>Seller Election</h2>
  <!-- payout checkboxes -->
</section>

<section>
  <h2>Unaccepted Items</h2>
  <!-- disposition checkboxes -->
</section>

<section>
  <h2>Acknowledgment</h2>
  <!-- short acknowledgment and signature lines -->
</section>

<section>
  <h2>For Internal Use Only</h2>
  <!-- internal processing fields -->
</section>
```

---

# 8. Data requirements

The proposal view needs access to:

## Session

```text
buyback_number
status
proposal_saved_at
proposal_printed_at
store
customer
created_by_user
```

## Customer

```text
display_name
phone
email
customer_number, if present
```

## Lines

```text
line_number
title_snapshot
identifier_entered or identifier snapshot
condition_snapshot
product_condition.name
proposed_resale_price_cents
proposed_cash_offer_cents
proposed_trade_credit_offer_cents
outcome
buyback_reject_reason.name
notes
```

## Totals

From `ProposalBuilder`:

```text
resale_cents
cash_offer_cents
trade_credit_offer_cents
```

If rejected lines are not currently included in `ProposalBuilder`, either extend the builder or query them separately in the print view/controller.

---

# 9. ProposalBuilder changes

Update `Buybacks::ProposalBuilder` to return separate line groups:

```ruby
Result = Data.define(
  :session,
  :offered_lines,
  :not_accepted_lines,
  :totals
)
```

Recommended grouping:

```ruby
offered_lines = lines.reject(&:store_rejected?)
not_accepted_lines = lines.select(&:store_rejected?)
```

If declined/donated decisions exist when reprinting later, the document may still show original proposal values, but rejected/not-accepted items should remain visibly separate.

---

# 10. Print behavior

## Required behavior

When staff clicks **Print proposal**:

1. Browser opens printable proposal page.
2. Page shows a no-print toolbar.
3. Staff clicks **Print proposal**, or browser print dialog opens automatically if desired.
4. Physical printout contains only the formatted proposal, not app navigation.

## Optional behavior

Auto-open print dialog:

```javascript
window.addEventListener("load", () => window.print())
```

Do not enable auto-print by default until the print layout is stable.

---

# 11. Styling requirements

## Visual hierarchy

Use clear section headings:

```text
Seller Verification
Items Offered for Purchase
Items Not Accepted
Proposal Totals
Seller Election
Unaccepted Items
Acknowledgment
For Internal Use Only
```

## Table design

* Use simple black/gray borders.
* Avoid dense application styling.
* Repeat table headers on page breaks.
* Avoid splitting individual item rows across pages.

## Signature areas

Use large blank signature lines. Do not make signature areas too small.

## Page size

Optimize for:

```text
US letter, portrait orientation
```

---

# 12. Acceptance criteria

## Printing

* Proposal renders with `layout: "print"`.
* Browser print preview shows the document content.
* Printed output does not include app nav, buttons, or the back link.
* Table headers repeat when lines span multiple pages.
* Line rows avoid splitting across page breaks.

## Content

* Proposal header includes store, proposal number, date/time, seller, and staff.
* Offered items show item, condition, estimated resale, cash offer, and trade-credit offer.
* Not accepted items show item and reason.
* Totals show estimated resale, cash offer, and trade-credit offer.
* Seller election section includes cash, trade-credit, and reject options.
* Unaccepted-item disposition section includes return and donate/recycle options.
* Seller and staff signature lines are present.
* Internal register-use section is present.

## Workflow

* Printing a proposal records `proposal_printed_at`.
* Printing records audit event `buyback.proposal.printed`.
* Proposal clearly states that payout is not final until completion.
* Proposal can be printed in `quoted` and `decision` states.
* Completed buybacks should still be able to reprint the proposal for audit/history if permitted.

## Security / privacy

* Full government ID numbers are not printed by default.
* Seller verification language is generic/configurable.
* Customer phone/email display follows existing customer data visibility rules.

---

# 13. Future enhancements

Defer these until the letter-size print proposal works reliably:

```text
3-inch thermal proposal format
PDF export
QR/barcode lookup
Electronic signature capture
Store-configurable legal text
Configurable seller verification / ID block
Automatic print dialog
Multi-copy print mode: customer copy + store copy
```

---

# Developer summary

Replace the current basic proposal print view with a formal letter-size print document.

Core changes:

```text
1. Add app/views/layouts/print.html.erb.
2. Change print_proposal to render layout: "print".
3. Replace print_proposal.html.erb with structured Buyback Proposal & Seller Election.
4. Extend ProposalBuilder to expose offered and not-accepted lines separately.
5. Add print CSS for letter paper.
6. Hide app controls from print output.
7. Keep full ID/legal language configurable, not hardcoded.
```

This turns the proposal into a usable counter document: valuation summary, seller election form, disposition authorization, and internal processing aid.
