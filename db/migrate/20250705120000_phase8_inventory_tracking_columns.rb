# frozen_string_literal: true

class Phase8InventoryTrackingColumns < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :default_inventory_tracking, :string
    add_column :product_variants, :inventory_tracking_override, :string

    add_check_constraint :products,
      "default_inventory_tracking IS NULL OR default_inventory_tracking IN ('inventory', 'non_inventory')",
      name: "products_default_inventory_tracking_chk"

    add_check_constraint :product_variants,
      "inventory_tracking_override IS NULL OR inventory_tracking_override IN ('inventory', 'non_inventory')",
      name: "product_variants_inventory_tracking_override_chk"
  end
end
