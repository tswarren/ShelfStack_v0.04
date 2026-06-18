# frozen_string_literal: true

class CreatePhase5PurchasingAndReceiving < ActiveRecord::Migration[8.1]
  RETURNABILITY_STATUSES = %w[returnable non_returnable conditional unknown].freeze
  RETURNABILITY_CHECK = "returnability_status IN (#{RETURNABILITY_STATUSES.map { |s| "'#{s}'" }.join(', ')})"
  RETURNABILITY_NULLABLE_CHECK = "returnability_status IS NULL OR #{RETURNABILITY_CHECK}"
  SUPPLIER_DISCOUNT_CHECK = "supplier_discount_bps IS NULL OR (supplier_discount_bps >= 0 AND supplier_discount_bps <= 10000)"

  def change
    remove_index :vendors, :default_pricing_model, if_exists: true
    remove_column :vendors, :default_pricing_model, :string
    remove_column :vendors, :default_margin_target_bps, :integer

    add_column :product_variants, :returnability_status, :string, null: false, default: "unknown"
    add_check_constraint :product_variants, RETURNABILITY_CHECK,
                         name: "chk_product_variants_returnability_status"

    add_column :inventory_balances, :moving_average_unit_cost_cents, :integer
    add_check_constraint :inventory_balances,
                         "moving_average_unit_cost_cents IS NULL OR moving_average_unit_cost_cents >= 0",
                         name: "chk_inventory_balances_moving_average_unit_cost_cents"

    create_table :product_vendors do |t|
      t.references :product, null: false, foreign_key: true, index: true
      t.references :vendor, null: false, foreign_key: true, index: true
      t.string :vendor_item_number
      t.integer :supplier_discount_bps
      t.string :returnability_status
      t.boolean :preferred, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :product_vendors, %i[product_id vendor_id], unique: true
    add_index :product_vendors, :active
    add_check_constraint :product_vendors, SUPPLIER_DISCOUNT_CHECK,
                         name: "chk_product_vendors_supplier_discount_bps"
    add_check_constraint :product_vendors, RETURNABILITY_NULLABLE_CHECK,
                         name: "chk_product_vendors_returnability_status"

    create_table :product_variant_vendors do |t|
      t.references :product_variant, null: false, foreign_key: true, index: true
      t.references :vendor, null: false, foreign_key: true, index: true
      t.string :vendor_item_number
      t.integer :supplier_discount_bps
      t.string :returnability_status
      t.boolean :preferred, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :product_variant_vendors, %i[product_variant_id vendor_id], unique: true,
              name: "idx_product_variant_vendors_variant_vendor"
    add_index :product_variant_vendors, :active
    add_check_constraint :product_variant_vendors, SUPPLIER_DISCOUNT_CHECK,
                         name: "chk_product_variant_vendors_supplier_discount_bps"
    add_check_constraint :product_variant_vendors, RETURNABILITY_NULLABLE_CHECK,
                         name: "chk_product_variant_vendors_returnability_status"

    create_table :vendor_terms do |t|
      t.references :vendor, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.integer :net_days
      t.jsonb :terms_data, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :vendor_terms, %i[vendor_id name], unique: true
    add_index :vendor_terms, :active

    create_table :purchase_requests do |t|
      t.references :store, null: false, foreign_key: true, index: true
      t.string :status, null: false, default: "open"
      t.text :notes
      t.timestamps
    end
    add_index :purchase_requests, %i[store_id status]

    create_table :purchase_request_lines do |t|
      t.references :purchase_request, null: false, foreign_key: true, index: true
      t.integer :line_number, null: false
      t.references :product_variant, null: false, foreign_key: true, index: true
      t.integer :requested_quantity, null: false
      t.string :request_reason
      t.string :status, null: false, default: "open"
      t.timestamps
    end
    add_index :purchase_request_lines, %i[purchase_request_id line_number],
              unique: true, name: "idx_purchase_request_lines_request_line_number"
    add_check_constraint :purchase_request_lines, "requested_quantity > 0",
                         name: "chk_purchase_request_lines_requested_quantity"

    create_table :purchase_orders do |t|
      t.references :store, null: false, foreign_key: true, index: true
      t.references :vendor, null: false, foreign_key: true, index: true
      t.string :status, null: false, default: "draft"
      t.text :notes
      t.datetime :submitted_at
      t.references :submitted_by_user, foreign_key: { to_table: :users }, index: true
      t.timestamps
    end
    add_index :purchase_orders, %i[store_id status]
    add_index :purchase_orders, %i[vendor_id status]

    create_table :purchase_order_lines do |t|
      t.references :purchase_order, null: false, foreign_key: true, index: true
      t.integer :line_number, null: false
      t.references :product_variant, null: false, foreign_key: true, index: true
      t.references :vendor, null: false, foreign_key: true, index: true
      t.references :product_variant_vendor, foreign_key: true, index: true
      t.integer :quantity_ordered, null: false
      t.integer :quantity_received, null: false, default: 0
      t.string :variant_sku_snapshot
      t.string :variant_name_snapshot
      t.string :vendor_item_number_snapshot
      t.integer :unit_list_price_cents
      t.integer :supplier_discount_bps
      t.integer :unit_cost_cents
      t.string :returnability_status_snapshot
      t.string :status, null: false, default: "open"
      t.timestamps
    end
    add_index :purchase_order_lines, %i[purchase_order_id line_number],
              unique: true, name: "idx_purchase_order_lines_order_line_number"
    add_check_constraint :purchase_order_lines, "quantity_ordered > 0",
                         name: "chk_purchase_order_lines_quantity_ordered"
    add_check_constraint :purchase_order_lines, "quantity_received >= 0",
                         name: "chk_purchase_order_lines_quantity_received"
    add_check_constraint :purchase_order_lines, SUPPLIER_DISCOUNT_CHECK,
                         name: "chk_purchase_order_lines_supplier_discount_bps"

    create_table :receipts do |t|
      t.references :store, null: false, foreign_key: true, index: true
      t.references :vendor, null: false, foreign_key: true, index: true
      t.references :purchase_order, foreign_key: true, index: true
      t.string :receipt_type, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :posted_at
      t.references :posted_by_user, foreign_key: { to_table: :users }, index: true
      t.references :inventory_posting, foreign_key: true, index: true
      t.timestamps
    end
    add_index :receipts, %i[store_id status]
    add_index :receipts, :receipt_type

    create_table :receipt_lines do |t|
      t.references :receipt, null: false, foreign_key: true, index: true
      t.integer :line_number, null: false
      t.references :product_variant, null: false, foreign_key: true, index: true
      t.references :purchase_order_line, foreign_key: true, index: true
      t.integer :quantity_expected, null: false, default: 0
      t.integer :quantity_received, null: false, default: 0
      t.integer :quantity_accepted, null: false, default: 0
      t.integer :quantity_rejected, null: false, default: 0
      t.integer :unit_list_price_cents
      t.integer :supplier_discount_bps
      t.integer :unit_cost_cents
      t.timestamps
    end
    add_index :receipt_lines, %i[receipt_id line_number],
              unique: true, name: "idx_receipt_lines_receipt_line_number"
    add_check_constraint :receipt_lines, "quantity_expected >= 0",
                         name: "chk_receipt_lines_quantity_expected"
    add_check_constraint :receipt_lines, "quantity_received >= 0",
                         name: "chk_receipt_lines_quantity_received"
    add_check_constraint :receipt_lines, "quantity_accepted >= 0",
                         name: "chk_receipt_lines_quantity_accepted"
    add_check_constraint :receipt_lines, "quantity_rejected >= 0",
                         name: "chk_receipt_lines_quantity_rejected"
    add_check_constraint :receipt_lines, SUPPLIER_DISCOUNT_CHECK,
                         name: "chk_receipt_lines_supplier_discount_bps"

    create_table :receiving_discrepancies do |t|
      t.references :receipt_line, null: false, foreign_key: true, index: true
      t.string :discrepancy_type, null: false
      t.integer :quantity_delta, null: false
      t.text :notes
      t.timestamps
    end

    create_table :returns_to_vendor do |t|
      t.references :store, null: false, foreign_key: true, index: true
      t.references :vendor, null: false, foreign_key: true, index: true
      t.string :status, null: false, default: "draft"
      t.text :notes
      t.datetime :posted_at
      t.references :posted_by_user, foreign_key: { to_table: :users }, index: true
      t.references :inventory_posting, foreign_key: true, index: true
      t.timestamps
    end
    add_index :returns_to_vendor, %i[store_id status]

    create_table :return_to_vendor_lines do |t|
      t.references :return_to_vendor, null: false, foreign_key: { to_table: :returns_to_vendor }, index: true
      t.integer :line_number, null: false
      t.references :product_variant, null: false, foreign_key: true, index: true
      t.integer :quantity, null: false
      t.integer :unit_list_price_cents
      t.integer :supplier_discount_bps
      t.integer :unit_cost_cents
      t.integer :credit_amount_cents
      t.timestamps
    end
    add_index :return_to_vendor_lines, %i[return_to_vendor_id line_number],
              unique: true, name: "idx_return_to_vendor_lines_rtv_line_number"
    add_check_constraint :return_to_vendor_lines, "quantity > 0",
                         name: "chk_return_to_vendor_lines_quantity"
    add_check_constraint :return_to_vendor_lines, SUPPLIER_DISCOUNT_CHECK,
                         name: "chk_return_to_vendor_lines_supplier_discount_bps"
  end
end
