# Phase 8.5-3b Spec — TBO Simplification

## Purpose

Improve TBO usability on existing `purchase_requests` / `purchase_request_lines` without schema changes to TBO tables.

## In scope

* Single-line TBO create via `PurchaseRequests::CreateSingleLine` (UI + service)
* `:tbo` eligibility on create; full PO eligibility at build
* Suggested vendor display on TBO list and `from_tbo` (from extended resolver, not stored on TBO line)
* PO eligibility warnings on `from_tbo` rows

## Out of scope

* Model validation enforcing one line per request (breaks legacy multi-line)
* `preferred_vendor_id` on `purchase_request_lines`
* `customer_id` on TBO

## Legacy behavior

Multi-line purchase requests remain viewable and buildable where already supported.
