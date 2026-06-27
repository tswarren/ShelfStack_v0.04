# ShelfStack Architecture Map

Quick reference: domain → tables → services → workspace → documentation.

For layering principles see [architecture.md](architecture.md). For business concepts see [domain-model.md](domain-model.md).

---

| Domain | Key tables | Key services | Workspace | Docs |
| ------ | ---------- | ------------ | --------- | ---- |
| Foundation | `users`, `roles`, `permissions`, `stores`, `workstations`, `user_sessions`, `audit_events` | `Authorization`, `SessionLifecycle`, `WorkstationAssignmentService`, `AuditEvents` | `/setup`, login | [phase-1-foundation-spec.md](specifications/phase-1-foundation-spec.md) |
| Classification / tax | `departments`, `sub_departments`, `tax_categories`, `store_tax_rates`, `store_tax_category_rates` | `TaxRateLookup`, `ClassificationDefaultsResolver` | `/setup` | [phase-2-classification-and-tax-spec.md](specifications/phase-2-classification-and-tax-spec.md) |
| Catalog / SKU | `catalog_items`, `catalog_item_identifiers`, `products`, `product_variants` | `CatalogIdentifierService`, `SkuGenerator`, `ProductNameRenderer`, `MetadataParser` | `/items`, `/setup` | [phase-3-catalog-products-variants-spec.md](specifications/phase-3-catalog-products-variants-spec.md) |
| External lookup | (uses catalog tables) | ISBNdb local-first lookup, Add Item import | `/items/add` | [phase-6.5-completion.md](implementation/phase-6.5-completion.md) |
| Inventory | `inventory_postings`, `inventory_ledger_entries`, `inventory_balances`, `inventory_adjustments` | `Inventory::Post`, `Inventory::BalanceUpdater`, `Inventory::TrackingResolver`, `Inventory::Eligibility` | `/inventory` | [phase-4-inventory-foundation-spec.md](specifications/phase-4-inventory-foundation-spec.md) |
| Purchasing | `purchase_orders`, `purchase_order_lines`, `receipts`, `receipt_lines`, `returns_to_vendor` | `Purchasing::PostReceipt`, `Purchasing::MovingAverageCost`, `Purchasing::OrderEligibilityResolver` | `/orders` | [phase-5-purchasing-and-receiving-spec.md](specifications/phase-5-purchasing-and-receiving-spec.md) |
| POS | `pos_register_sessions`, `pos_transactions`, `pos_transaction_lines`, `pos_tenders`, `pos_voids` | `Pos::CompleteTransaction`, `Pos::CommandBarRouter` → `Pos::CommandRegistry` (10-C), `Pos::TaxRecalculator`, `Pos::DiscountRecalculator` | `/pos` | [phase-6-pos-foundation-spec.md](specifications/phase-6-pos-foundation-spec.md), [phase-10c-pos-keyboard-workspace-spec.md](specifications/phase-10c-pos-keyboard-workspace-spec.md) |
| Stored value | `stored_value_accounts`, `stored_value_ledger_entries`, `stored_value_identifiers` | `StoredValue::Post`, `StoredValue::Issue`, `StoredValue::RedeemCredit`, `Pos::PostStoredValueLedger` | `/pos`, `/customers` | [phase-7b-pos-settlement-spec.md](specifications/phase-7b-pos-settlement-spec.md) |
| Customer demand | `customer_requests`, `customer_request_lines`, `special_orders`, `inventory_reservations` | `CustomerRequests::HeaderStatusResolver`, `InventoryReservations::Expire` | `/customers`, `/items` | [phase-7a-customer-demand-spec.md](specifications/phase-7a-customer-demand-spec.md) |
| Buyback | `buyback_sessions`, `buyback_session_lines`, `buyback_voids` | `Buybacks::CompleteSession`, `Buybacks::VoidSession`, `Buybacks::PriceLine` | `/buybacks` | [phase-7c-used-buyback-spec.md](specifications/phase-7c-used-buyback-spec.md) |
| Operational reports | (reads operational tables/snapshots) | Report query objects under `Reports::` | `/reports` | [phase-9b-reports-spec.md](specifications/phase-9b-reports-spec.md) |
| Interaction / UX | (no domain tables) | Shared modal/drawer shells; `Pos::CommandRegistry` (10-C) | All workspaces | [phase-10a-interaction-infrastructure-spec.md](specifications/phase-10a-interaction-infrastructure-spec.md) |
| GL / export | (deferred) | Phase 9c financial postings | — | [phase-9c-gl-shaped-financial-layer.md](roadmap/phase-9c-gl-shaped-financial-layer.md) |

---

## Authoritative schema index

Phase data model documents and [schema-reference.md](schema-reference.md). Runtime source of truth: `db/schema.rb`.

## Authoritative business rules

Service objects in `app/services/` — not Stimulus controllers or view conditionals. POS command routing and workflow state belong in Ruby services/registry objects (see Phase 10-C).
