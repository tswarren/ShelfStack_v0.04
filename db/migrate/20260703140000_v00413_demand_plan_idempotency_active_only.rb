# frozen_string_literal: true

class V00413DemandPlanIdempotencyActiveOnly < ActiveRecord::Migration[8.0]
  def change
    remove_index :purchase_order_line_demand_plans,
                 name: "idx_po_line_demand_plans_store_idempotency",
                 if_exists: true

    add_index :purchase_order_line_demand_plans,
              %i[store_id idempotency_key],
              unique: true,
              where: "idempotency_key IS NOT NULL AND status IN ('planned', 'partially_converted')",
              name: "idx_po_line_demand_plans_store_idempotency_active"
  end
end
