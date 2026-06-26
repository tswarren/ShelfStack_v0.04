# frozen_string_literal: true

class CreatePhase853aOrderingReadiness < ActiveRecord::Migration[8.1]
  COST_SOURCES = %w[vendor_source manual import default unknown].freeze
  PRICE_SOURCES = %w[variant vendor_source manual import unknown].freeze

  def change
    add_reference :products, :preferred_vendor, foreign_key: { to_table: :vendors }
    add_reference :product_variants, :preferred_vendor, foreign_key: { to_table: :vendors }
    add_column :product_variants, :orderable, :boolean, null: false, default: true

    change_table :purchase_order_lines, bulk: true do |t|
      t.integer :expected_retail_price_cents
      t.integer :expected_line_cost_cents
      t.integer :expected_line_retail_cents
      t.integer :expected_margin_cents
      t.integer :expected_margin_bps
      t.string :cost_source, null: false, default: "unknown"
      t.string :price_source, null: false, default: "unknown"
      t.boolean :manual_cost_override, null: false, default: false
      t.boolean :manual_price_override, null: false, default: false
      t.text :line_note
      t.jsonb :source_snapshot, default: {}
    end

    add_check_constraint :purchase_order_lines,
                         "cost_source IN ('#{COST_SOURCES.join("','")}')",
                         name: "purchase_order_lines_cost_source_chk"
    add_check_constraint :purchase_order_lines,
                         "price_source IN ('#{PRICE_SOURCES.join("','")}')",
                         name: "purchase_order_lines_price_source_chk"
  end
end
