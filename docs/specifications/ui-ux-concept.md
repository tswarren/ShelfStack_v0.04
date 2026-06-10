# ShelfStack UX recommendation

ShelfStack should use a **workflow-first UX**, not a table-first/admin CRUD UX.

The schema is now broad enough to support cataloging, inventory, POS, receiving, special orders, gift cards, store credit, buybacks, vendor returns, and stock valuation. If the UX mirrors the tables directly, it will feel overwhelming. The interface should organize those tables into a few clear workspaces.

---

# 1. Primary UX principle

Use this mental model:

```
Front counter = fast transaction work
Inventory desk = stock movement and receiving work
Catalog desk = item/product maintenance
Customer desk = holds, credits, special orders
Manager desk = approvals, reporting, controls
```

The user should not need to know whether they are editing `catalog_items`, `stock_items`, `stock_variants`, `stock_movements`, or `purchase_order_allocations`. The screen should guide them through the workflow.

---

# 2. Recommended app workspaces

## Main navigation

```
Dashboard
POS
Inventory
Catalog
Orders
Customers
Reports
Admin
```

## Workspace meaning

| Workspace | Primary users | Purpose |
| :---- | :---- | :---- |
| **Dashboard** | Everyone | Today’s store status, tasks, alerts |
| **POS** | Clerks/front counter | Sales, returns, gift cards, store credit, buybacks |
| **Inventory** | Stock staff/managers | Receiving, adjustments, counts, stock lookup |
| **Catalog** | Inventory/catalog staff | Catalog items, stock items, stock variants |
| **Orders** | Buyers/managers | Purchase orders, special orders, vendor returns |
| **Customers** | Clerks/managers | Customer profiles, credits, holds, special orders |
| **Reports** | Managers | Sales, inventory value, cash, margins, buybacks |
| **Admin** | Admins | Stores, users, permissions, tax, departments, tenders |

---

# 3. Dashboard UX

The dashboard should answer:

```
What needs attention today?
```

## Suggested dashboard cards

```
Open register sessions
Suspended POS transactions
Pending approvals
Special orders received but not picked up
Purchase orders expected soon
Low-stock / out-of-stock items
Vendor returns pending credit
Inventory value summary
Cash variance alerts
Gift card / store credit exceptions
```

## Example layout

```
----------------------------------------------------
ShelfStack Dashboard

Today
- Register 1 open since 9:02 AM
- 2 suspended transactions
- 3 pending supervisor approvals
- 4 special orders ready for pickup

Inventory
- 18 low-stock items
- $42,318 inventory cost value
- $71,940 retail value

Operations
- 2 receiving batches pending
- 1 vendor return awaiting credit
----------------------------------------------------
```

---

# 4. POS workspace

The POS needs to be the fastest, most focused part of the app.

## POS screen layout

I recommend a **three-panel layout**:

```
----------------------------------------------------
[ Search / Scan / Command Bar ]

[ Cart / Transaction Lines ]        [ Item / Customer / Totals Panel ]

[ Tender / Actions Bar ]
----------------------------------------------------
```

## Left/main panel: transaction lines

Shows:

```
Item description
SKU / identifier
Quantity
Unit price
Adjustments
Tax
Line total
Return/original-sale indicator
```

## Right panel: context

Dynamically shows:

```
Selected item details
Stock availability
Customer profile
Gift card balance
Store credit balance
Special order status
Transaction totals
```

## Bottom action bar

Large, keyboard-friendly actions:

```
Add Item
Open Ring
Return
Discount
Tax Exempt
Gift Card
Store Credit
Suspend
Void
Tender
Complete
```

---

## POS workflows to support

### Sale

```
Scan/search item
→ Add line
→ Apply adjustments if needed
→ Take tender
→ Complete
→ Create stock movement
```

### Open-ring sale

```
Choose department
→ Enter description/amount
→ Calculate tax
→ Complete
```

### Return/refund

```
Lookup receipt or scan item
→ Select original line if available
→ Enter return reason/disposition
→ Refund to tender/store credit/gift card
→ Create stock movement if returned to stock
```

### Exchange

Treat as:

```
Return line + Sale line in same transaction
```

The UI can label it “Exchange,” but the underlying model can remain POS lines and tender balancing.

### Gift card sale

```
Choose gift card activation
→ Enter amount
→ Assign/scan card number
→ Complete sale
→ Create gift card ledger entry
```

### Gift card redemption

```
Choose gift card tender
→ Scan card
→ Validate balance
→ Apply tender
→ Create redemption ledger entry
```

### Store credit redemption

```
Select customer
→ Show credit balance
→ Apply store credit tender
→ Create customer credit ledger entry
```

### Suspended transaction

```
Suspend
→ Optional reason
→ Resume from POS queue
```

---

# 5. POS should use keyboard-first commands

For bookstore/front-counter speed, make POS usable without a mouse.

## Suggested command bar

```
Scan ISBN, SKU, gift card, receipt number, or type command...
```

Examples:

```
9780140177398
SKU12345
/giftcard 25
/open Books 12.99
/return R-100245
/discount 10%
/taxexempt nonprofit
/suspend
```

This can coexist with buttons.

---

# 6. Item detail / stock lookup UX

A front-line user needs a compact item page that combines catalog, stock, and availability.

## Recommended item detail layout

```
----------------------------------------------------
The Hobbit
J.R.R. Tolkien · Paperback · ISBN 978...

[New Paperback]       $16.99
On hand: 4   Reserved: 1   Available: 3
On order: 10   Special order: 2   On-order available: 8

[Used - Good]         $8.00
On hand: 2   Available: 2

[Used - Acceptable]   $5.00
On hand: 1   Available: 1
----------------------------------------------------
Actions:
Sell | Reserve | Special Order | Receive | Adjust | View History
----------------------------------------------------
```

This screen should not expose the user to the fact that data comes from:

```
catalog_items
stock_items
stock_variants
stock_balances
purchase_order_lines
purchase_order_allocations
stock_reservations
```

It should simply present the operational view.

---

# 7. Catalog / stock management UX

Catalog and stock setup should be split into two related views.

## Catalog item view

Answers:

```
What is this item?
```

Shows:

```
Title
Subtitle
Creator
Identifier
Format
Publisher
Publication date
Subjects
Description
Search/abbreviation keys
Linked stock items
```

## Stock item / variant view

Answers:

```
How do we sell and stock this item?
```

Shows:

```
SKU
Stock item type
Variants
Condition
Sale price
Default cost
Department
Merchandise category
Tax category
Tracking method
Availability by store
```

## Recommended UX pattern

Use tabs:

```
Catalog
Stock Variants
Inventory
Orders
Sales History
Movements
```

---

# 8. Receiving UX

Receiving should feel like a controlled checklist.

## Receiving batch screen

```
Receiving Batch #123
Vendor: Ingram
Store: Main
Status: Pending

PO Line                         Ordered  Received  Backordered  Cancelled  Cost
The Hobbit - New Paperback      10       [ 6 ]      [ 4 ]        [ 0 ]      $9.80
Dune - New Paperback            5        [ 5 ]      [ 0 ]        [ 0 ]      $11.25

[Save Draft] [Complete Receiving]
```

When completed:

```
Update PO line quantities
Create stock movements
Update stock balances
Update inventory value
```

## Key UX rule

Before completion, receiving lines are editable.

After completion, they should be locked or corrected only through adjustment/reversal workflows.

---

# 9. Purchase order UX

Purchase orders should support both manual and suggested ordering.

## PO list filters

```
Draft
Sent
Confirmed
Partially received
Complete
Cancelled
Expected soon
Overdue
```

## PO detail actions

```
Add line
Send
Confirm
Receive
Cancel line
Close PO
Allocate to special order
```

## Recommended PO line display

```
Item
Variant
Ordered
Confirmed
Received
Cancelled
Backordered
Open
Allocated
Available on order
Expected cost
Expected retail
```

---

# 10. Special order UX

Special orders should be customer-centered.

## Customer special order screen

```
Customer: Jane Smith
Special Order #502
Status: Ordered

Requested:
- The Art of Fermentation
  Requested: 1
  Ordered: 1
  Received: 0
  Deposit: $5.00
  Status: Ordered

Actions:
Allocate PO Line
Mark Received
Notify Customer
Fulfill at POS
Cancel
```

## Special order board

A manager/front-counter queue:

```
Requested
Ordered
Received
Notified
Ready for pickup
Abandoned
Cancelled
```

This should be one of the dashboard’s most important task queues.

---

# 11. Used buyback UX

Used buyback should be a guided workflow, not a POS cart line.

## Buyback flow

```
1. Select/create customer
2. Add items
3. Evaluate item condition
4. Set resale price
5. Calculate cash/store-credit offer
6. Customer accepts/rejects
7. Complete payout
```

## Buyback screen

```
Used Buyback #884
Customer: Jane Smith
Status: Evaluating

Item                         Condition   Resale   Cash Offer   Credit Offer   Disposition
The Hobbit                   Good        $8.00    $2.00        $4.00          Accepted
Old Textbook                  Poor        —        —            —              Rejected

Totals:
Resale value: $8.00
Cash offer: $2.00
Store credit offer: $4.00

Payout:
( ) Cash
( ) Store Credit
( ) Split

[Complete Buyback]
```

On completion:

```
Accepted items create positive stock movements.
Cash payout creates register cash event.
Store credit payout creates customer credit ledger entry.
```

---

# 12. Vendor return UX

Vendor returns should feel like a controlled outbound workflow.

## Vendor return statuses

```
Draft
Requested
Approved
Shipped
Credited
Completed
Cancelled
```

## Vendor return screen

```
Vendor Return #77
Vendor: Ingram
Reason: Damaged
Status: Draft

Item                  Qty   Unit Cost   Expected Credit   Reason
Book A                2     $8.00       $16.00            Damaged
Book B                1     $12.00      $12.00            Overstock

[Approve] [Ship Return] [Record Credit]
```

On shipping:

```
Create negative stock movement.
Reduce inventory value.
```

On credit:

```
Record actual credit.
Close workflow.
```

---

# 13. Inventory adjustment UX

Manual adjustments need strict reason tracking.

## Adjustment screen

```
Stock Adjustment #44
Store: Main
Reason: Cycle count correction

Item                    Current Qty   New Qty   Delta   Cost Basis
The Hobbit - Used Good  4             3         -1      Current Average

[Submit for Approval] [Complete Adjustment]
```

## Best UX

Allow either:

```
Enter quantity delta
```

or:

```
Enter counted/new quantity
```

Then calculate delta.

For normal users, “new counted quantity” is usually safer.

---

# 14. Inventory count UX

If included in Phase 1 or Phase 2, make it a scanning workflow.

## Count screen

```
Cycle Count: Used Paperbacks
Expected counts hidden? Yes/No

Scan item:
[________________]

Counted:
The Hobbit - Used Good     3
Dune - Used Acceptable     2

Variance report:
The Hobbit expected 4, counted 3, variance -1
```

Final approval should create stock adjustment lines.

---

# 15. Customer UX

Customer profiles should consolidate operational activity.

## Customer page tabs

```
Profile
Purchases
Returns
Special Orders
Store Credit
Gift Cards
Buybacks
Reservations
Notes
```

## Customer summary card

```
Jane Smith
Phone: ...
Email: ...

Store credit balance: $14.00
Open special orders: 2
Items on hold: 1
Recent purchases: 5
```

This makes front-counter workflows easier.

---

# 16. Manager approvals UX

Approvals should be a central queue and inline prompt.

## Approval queue

```
Pending Approvals

Type                  Requested By   Amount   Reason        Source
Markdown              Clerk A        -$10     Damaged       POS #1002
Cash Paid Out         Clerk B        $25      Supplies      Register 1
No-receipt Return     Clerk C        $18      Customer      POS #1005
Stock Adjustment      Clerk A        -3 qty   Count diff    Adjustment #44
```

## Inline approval

When clerk attempts restricted action:

```
Supervisor approval required
Reason: Markdown over limit

Supervisor PIN:
[________]

[Approve] [Reject]
```

This should create `pos_approvals` or a generic approval record.

---

# 17. Reports UX

Reports should be grouped by operational question.

## Sales reports

```
Daily sales
Sales by department
Sales by category
Sales by tender
Discounts/markdowns
Returns/refunds
Tax collected
Gift card sales/redemptions
Store credit issued/redeemed
```

## Inventory reports

```
Inventory value
On hand by category
Available stock
On order
Special order allocated
Low stock
Dead stock
Stock movement history
Vendor return status
```

## Cash/register reports

```
Register session summary
Expected vs actual cash
Paid in/out
Cash drops
Cash variance
No-sale events
```

## Buyback reports

```
Buybacks by date
Cash paid out
Store credit issued
Resale value added
Accepted/rejected items
```

---

# 18. Admin UX

Admin screens should be boring, stable, and controlled.

## Admin areas

```
Stores
Registers
Users
Roles
Permissions
Departments
Merchandise categories
Tax categories
Store tax rates
Tender types
Product formats
Stock conditions
Vendors
```

These can be conventional CRUD screens.

The rest of the app should be workflow-first.

---

# 19. Recommended controller/workspace organization

## POS namespace

```
/pos
/pos/transactions
/pos/transactions/:id/lines
/pos/transactions/:id/adjustments
/pos/transactions/:id/tenders
/pos/transactions/:id/complete
/pos/transactions/:id/suspend
/pos/transactions/:id/void
```

## Inventory namespace

```
/inventory
/inventory/stock_items
/inventory/stock_variants
/inventory/receiving_batches
/inventory/stock_adjustments
/inventory/stock_counts
/inventory/movements
```

## Orders namespace

```
/orders/purchase_orders
/orders/special_orders
/orders/vendor_returns
```

## Customer namespace

```
/customers
/customers/:id/special_orders
/customers/:id/store_credit
/customers/:id/buybacks
```

## Manager namespace

```
/manager/approvals
/manager/reports
/manager/register_sessions
```

---

# 20. Recommended visual style

For ShelfStack, I would use a **workstation-style interface**:

```
Dense but readable
Keyboard-friendly
Clear tables
Strong status labels
Minimal animation
Large POS action targets
Persistent search/scan bar
Clear audit/status cues
```

Avoid making it too card-heavy. Cards are useful for dashboards and summaries, but operational workflows need tables, queues, and forms.

## Design pattern

Use:

```
Header
Persistent workspace nav
Search/scan bar
Main work area
Right-side context panel
Bottom action bar for POS/receiving workflows
```

---

# 21. Phase 1 UX priorities

Build these first:

```
Dashboard
POS sale/return screen
Item/stock lookup screen
Receiving workflow
Purchase order workflow
Used buyback workflow
Customer profile with store credit
Gift card activation/redemption
Register open/close
Manager approval queue
Inventory summary report
```

Defer:

```
Advanced promotions engine
Full cycle count workflow
Advanced loyalty
Detailed price history UI
Advanced consignment settlement
Multi-store transfer UI
Offline sync conflict UI
```

---

# Bottom line

ShelfStack should be organized around **store workflows**, not database objects.

The most important UX rule is:

```
Users should interact with sales, receiving, buybacks, special orders, returns, and register sessions — not with raw stock_movements, stock_balances, ledger entries, or allocation rows.
```

The service layer can handle the complex table updates behind the scenes. The UX should present clean, task-oriented screens that match how bookstore staff actually work.

Yes. That makes strong sense, and it is an important UX requirement for ShelfStack.

The best way to describe this is:

ShelfStack should use **reactive, workflow-driven forms** with **real-time calculation, inline validation, automatic row continuation, and live transaction summaries**.

Or more simply:

Forms should behave like operational workpads, not static data-entry screens.

---

# Recommended terminology

Use these terms in your UX/spec documents:

| Term | Meaning |
| :---- | :---- |
| **Reactive forms** | Fields, totals, statuses, and dependent values update immediately as the user enters data. |
| **Live calculations** | Totals, taxes, margins, inventory value, expected costs, and balances recalculate in real time. |
| **Inline validation** | Errors/warnings appear next to the field as soon as the system can detect them. |
| **Automatic row continuation** | When a user completes a line item, a new blank line is automatically added. |
| **Progressive disclosure** | Additional fields appear only when relevant. |
| **Preview-before-commit** | The screen shows calculated effects before the user completes/finalizes the workflow. |
| **Workflow workpad** | The form acts like a live workspace for building a transaction/order/batch. |
| **Non-destructive draft state** | Entries can be edited freely until the user completes/posts/finalizes the record. |

---

# Suggested UX principle

I would write it this way:

```
ShelfStack screens should be dynamic and workflow-oriented. As users enter lines, quantities, prices, discounts, tax exemptions, tenders, receiving quantities, or payout amounts, the interface should immediately preview calculated totals, balances, margins, taxes, inventory effects, and validation warnings. Users should not need to save or refresh a form to understand the effect of their entry.
```

---

# How this applies by workflow

## POS

POS should update immediately as the transaction is built.

Examples:

```
Scan/add item → line appears immediately
Change quantity → subtotal, tax, total update
Apply discount → net amount and tax update
Add tender → balance due updates
Redeem gift card → remaining gift card balance previews
Return item → refund amount previews
Tax exemption → exempt amount and tax reduction update
```

The POS screen should always show:

```
Gross amount
Adjustments
Net amount
Tax
Total due
Tendered amount
Balance due / change due
Inventory effect preview
```

---

## Purchase orders

PO entry should feel like a spreadsheet/workpad.

Examples:

```
Add stock variant → expected cost and sale price populate
Enter quantity → line extended cost updates
Finish a line → new blank line appears automatically
Change cost or discount → margin preview updates
Allocate to special order → on-order available quantity updates
```

A PO should show live:

```
Total quantity ordered
Total expected cost
Total expected retail
Expected gross margin
Allocated quantity
Unallocated on-order quantity
```

---

## Receiving

Receiving should preview both quantity and value effects.

Examples:

```
Enter quantity received → received total updates
Enter backordered quantity → open order balance updates
Enter actual unit cost → inventory value preview updates
Complete batch → stock movement preview becomes posted movement
```

Before completion, the screen should show:

```
On-hand increase preview
Inventory cost value increase
Open PO quantity after receiving
Backordered/cancelled quantities
Cost variance from expected
```

---

## Used buybacks

Buyback evaluation should update offers and inventory effects live.

Examples:

```
Set resale price → cash/store-credit offer previews
Change condition → suggested resale price changes
Accept/reject item → payout totals update
Choose cash/store credit/split → drawer/credit impact previews
Complete buyback → stock movement and payout records are created
```

The buyback screen should show:

```
Total resale value
Cash offer
Store credit offer
Final payout
Inventory value added
Cash drawer impact
Store credit liability impact
```

---

## Vendor returns

Vendor returns should preview outbound inventory and credit impact.

Examples:

```
Enter quantity returned → stock reduction preview updates
Enter expected credit → return total updates
Ship return → negative stock movements are created
Record credit → expected vs actual credit variance updates
```

---

## Inventory adjustments

Adjustments should preview the before/after state.

Examples:

```
Enter counted quantity → variance calculated
Enter quantity delta → new quantity previewed
Change cost basis → inventory value impact recalculated
Submit adjustment → approval required if variance threshold exceeded
```

Show:

```
Current quantity
New quantity
Variance
Current inventory value
Adjusted inventory value
Value difference
```

---

# Recommended phrase for requirements docs

You can describe the behavior like this:

```
ShelfStack forms should support reactive line-entry behavior. Transactional screens should recalculate dependent values in real time as users enter or modify data. Line-oriented workflows such as POS transactions, purchase orders, receiving batches, used buybacks, vendor returns, and stock adjustments should automatically maintain a ready blank line after the last completed line, allowing continuous keyboard-driven entry without requiring the user to click “Add line” repeatedly.

Calculated values should be previewed before posting and committed only when the user completes the workflow. Draft records may be edited freely; completed records should become locked and corrected only through reversal, adjustment, or follow-up workflows.
```

---

# Important distinction: preview vs. posted

This is the key architectural concept.

## Draft state

While the user is entering data:

```
Totals are previews.
Inventory effects are previews.
Gift card/store credit effects are previews.
Register cash effects are previews.
Validation warnings are live.
```

## Completed state

When the user clicks complete/post/finalize:

```
Stock movements are created.
Ledger entries are created.
Register cash events are created.
Balances are updated.
Transaction becomes locked.
```

That distinction should be explicit in the UX spec.

---

# Technical description

If you are describing this for Rails implementation, I would call it:

```
Hotwire/Turbo-driven reactive forms with Stimulus controllers for local calculations and server-backed recalculation/validation where authoritative business rules are required.
```

A practical split:

| Calculation type | Where it can happen |
| :---- | :---- |
| Simple line math | Client-side Stimulus |
| Display subtotal previews | Client-side Stimulus |
| Tax calculation | Server-backed or shared service |
| Gift card balance validation | Server-backed |
| Inventory availability | Server-backed |
| Approval requirement checks | Server-backed |
| Final posting | Server-side service only |

---

# Best short label

For your project documentation, I would call this:

## **Reactive Operational Workflows**

Definition:

```
Reactive Operational Workflows are dynamic, line-oriented screens that continuously recalculate totals, validate entries, preview downstream effects, and support uninterrupted data entry while preserving a clear distinction between editable draft state and posted transaction state.
```

That phrase fits ShelfStack well because it applies equally to POS, purchasing, receiving, buybacks, returns, stock adjustments, and register workflows.  