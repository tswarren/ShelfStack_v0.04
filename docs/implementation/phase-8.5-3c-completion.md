# Phase 8.5-3c Completion — Receiving Allocation Visibility

**Status:** Complete (pending merge)

## Purpose

Read-only receipt UX showing how accepted quantity splits between special orders and stock, before and after posting. No changes to `Receiving::AllocateCustomerDemandFromReceipt` or `Purchasing::PostReceipt`.

## Deliverables

### Presenter (`Orders::ReceiptShowPresenter`)

- `stock_quantity_label` — **Projected stock quantity** (draft) vs **Actual stock quantity** (posted)
- `pre_post_allocation_message` — draft hint when FIFO will auto-allocate on post
- `customer_allocation_rows` — projected from PO allocations (draft) or `receipt_line_allocations` (posted)
- `allocation_summary_rows` — accepted / customer / stock split per receipt line
- `po_allocation_rows` — PO allocation qty vs received vs remaining with customer names

### Views

- Receipt **show**: customer allocations, PO special order allocations, allocation summary panels
- Receipt **edit** (draft PO-backed): pre-post allocation message via `@allocation_preview`

### Tests

- `test/presenters/orders/receipt_show_presenter_test.rb` — projected vs actual labels, post workflow, PO allocation rows
- Regression: `test/services/receiving/allocate_customer_demand_from_receipt_test.rb` (unchanged FIFO)
- Regression: `test/services/purchasing/post_receipt_test.rb` (unchanged post behavior)

## Verification

```bash
./dev/rails-docker bin/rails test test/presenters/orders/receipt_show_presenter_test.rb
./dev/rails-docker bin/rails test test/services/receiving/allocate_customer_demand_from_receipt_test.rb
./dev/rails-docker bin/rails test test/services/purchasing/post_receipt_test.rb
```

## Out of scope (unchanged)

- Manual receipt allocation UI
- `allocation_type` column on `receipt_line_allocations`
- Changes to FIFO allocation logic
