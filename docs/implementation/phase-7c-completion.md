# Phase 7C Used Buyback — Completion Record

Completed: 2026-06-23

## Summary

Phase 7C delivers used buyback as an operational workspace (`/buybacks`) with draft session workflow, dual eligibility gates, single payout mode per session (cash, trade credit, or no-value donation), inventory posting via `used_buyback`, and void via `buyback_voids` mirroring POS void patterns.

## Deliverables

### Schema

- Extended `customers` with structured seller identity fields
- Extended `product_conditions` with buyback flags
- Extended `catalog_items`, `products`, `product_variants` with `source`, `needs_review`, `created_from_buyback_session_id`
- Extended `pos_cash_movements` with polymorphic `source` and `reverses_cash_movement_id`
- New tables: `buyback_sequences`, `buyback_sessions`, `buyback_lines`, `buyback_voids`, `buyback_pricing_rules`, `buyback_reject_reasons`

### Services

```text
Buybacks::Eligibility
Buybacks::SellerRequirements
Buybacks::StartSession
Buybacks::AddLine / UpdateLine
Buybacks::ResolveItem
Buybacks::CreateIntakeItem
Buybacks::FindOrCreateGradedUsedVariant
Buybacks::PriceLine
Buybacks::ApplyPriceOverride / ApplyOfferOverride
Buybacks::AcceptLine / RejectLine
Buybacks::CancelSession
Buybacks::CompleteSession
Buybacks::PostInventory
Buybacks::VoidSession
Buybacks::PostVoidInventory
Buybacks::BuybackNumberAssigner
Buybacks::ReceiptBuilder
Buybacks::ReportBuilder
```

### UI

- `/buybacks` workspace with session list, new session, session screen, receipt
- Customer form extended with seller address fields
- Register session show links buyback cash payouts
- Items index filter: buyback intake needs review
- Nav link when `buybacks.view` granted

### Seeds

- `db/seeds/phase7c_permissions.rb` — all `buybacks.*` permissions
- `db/seeds/phase7c_buyback.rb` — condition matrix, reject reasons, starter pricing rules
- `db/seeds/phase7b_stored_value.rb` — `buyback_trade_credit_issue` / `buyback_trade_credit_void` reason codes

## Verification

```bash
docker compose run --rm web bin/rails db:migrate
docker compose run --rm web bin/rails db:seed
docker compose run --rm web bin/rails test test/services/buybacks
```

## Known gaps / deferred

- Setup CRUD for `buyback_pricing_rules` (MVP uses seeds only)
- Customer merge workflow (`merged_into_customer_id` schema only)
- Copy-level inventory and split payouts remain out of scope per roadmap §4
