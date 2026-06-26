# Phase 8.5-3c Spec — Receiving Allocation Visibility

## Purpose

Read-only UX for customer vs stock split on receipts. **No** changes to `Receiving::AllocateCustomerDemandFromReceipt` or `PostReceipt`.

## Labels by receipt state

| Receipt state | Stock quantity label |
| ------------- | -------------------- |
| Draft | Projected stock quantity |
| Posted | Actual stock quantity |

## Display

* Linked special orders, customer names
* PO allocation qty vs received vs remaining
* Pre-post: projected auto-allocation message
* Post-post: actual `receipt_line_allocations` rows

Prefer computed display; optional `allocation_type` column deferred unless UI cannot derive split.
