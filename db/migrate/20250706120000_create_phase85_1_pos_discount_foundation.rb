# frozen_string_literal: true

class CreatePhase851PosDiscountFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :discount_reasons do |t|
      t.string :reason_key, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :requires_note, null: false, default: false
      t.boolean :requires_authorization, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0

      t.timestamps
    end

    add_index :discount_reasons, :reason_key, unique: true
    add_index :discount_reasons, :name, unique: true

    create_table :pos_discount_applications do |t|
      t.references :pos_transaction, null: false, foreign_key: true
      t.references :pos_transaction_line, foreign_key: true
      t.references :discount_reason, null: false, foreign_key: true
      t.references :pos_authorization, foreign_key: true
      t.string :scope, null: false
      t.string :source, null: false
      t.string :discount_method, null: false
      t.integer :entered_amount_cents
      t.integer :entered_percent_bps
      t.integer :target_price_cents
      t.integer :base_amount_cents, null: false, default: 0
      t.integer :calculated_discount_cents, null: false, default: 0
      t.integer :applied_discount_cents, null: false, default: 0
      t.integer :stack_order, null: false
      t.text :note
      t.references :applied_by_user, null: false, foreign_key: { to_table: :users }
      t.references :approved_by_user, foreign_key: { to_table: :users }
      t.datetime :applied_at, null: false
      t.datetime :voided_at
      t.references :voided_by_user, foreign_key: { to_table: :users }
      t.text :void_reason
      t.jsonb :details, null: false, default: {}

      t.timestamps
    end

    add_index :pos_discount_applications,
              %i[pos_transaction_id voided_at stack_order],
              name: "index_pos_discount_apps_on_txn_voided_stack"

    add_check_constraint :pos_discount_applications,
                         "scope IN ('line', 'transaction')",
                         name: "pos_discount_applications_scope_chk"
    add_check_constraint :pos_discount_applications,
                         "source IN ('manual', 'system', 'promotion', 'legacy')",
                         name: "pos_discount_applications_source_chk"
    add_check_constraint :pos_discount_applications,
                         "discount_method IN ('amount', 'percent', 'price_override')",
                         name: "pos_discount_applications_discount_method_chk"
    add_check_constraint :pos_discount_applications,
                         "base_amount_cents >= 0",
                         name: "pos_discount_applications_base_amount_cents_chk"
    add_check_constraint :pos_discount_applications,
                         "calculated_discount_cents >= 0",
                         name: "pos_discount_applications_calculated_discount_cents_chk"
    add_check_constraint :pos_discount_applications,
                         "applied_discount_cents >= 0",
                         name: "pos_discount_applications_applied_discount_cents_chk"
    add_check_constraint :pos_discount_applications,
                         "entered_percent_bps IS NULL OR (entered_percent_bps >= 0 AND entered_percent_bps <= 10000)",
                         name: "pos_discount_applications_entered_percent_bps_chk"

    create_table :pos_discount_allocations do |t|
      t.references :pos_discount_application, null: false, foreign_key: true
      t.references :pos_transaction, null: false, foreign_key: true
      t.references :pos_transaction_line, null: false, foreign_key: true
      t.string :scope, null: false
      t.integer :allocation_base_cents, null: false, default: 0
      t.integer :allocated_discount_cents, null: false, default: 0
      t.integer :line_number_snapshot
      t.references :product_variant, foreign_key: true
      t.references :product, foreign_key: true
      t.references :sub_department, foreign_key: true
      t.references :department, foreign_key: true
      t.references :tax_category, foreign_key: true
      t.string :variant_sku_snapshot
      t.string :variant_name_snapshot
      t.string :product_name_snapshot
      t.string :sub_department_name_snapshot
      t.string :department_name_snapshot

      t.timestamps
    end

    add_check_constraint :pos_discount_allocations,
                         "scope IN ('line', 'transaction')",
                         name: "pos_discount_allocations_scope_chk"
    add_check_constraint :pos_discount_allocations,
                         "allocation_base_cents >= 0",
                         name: "pos_discount_allocations_allocation_base_cents_chk"
    add_check_constraint :pos_discount_allocations,
                         "allocated_discount_cents >= 0",
                         name: "pos_discount_allocations_allocated_discount_cents_chk"

    add_column :departments, :discountable, :boolean, null: false, default: true
    add_column :sub_departments, :discountable, :boolean, null: false, default: true
    add_column :products, :discountable, :boolean, null: false, default: true
    add_column :product_variants, :discountable, :boolean, null: false, default: true
  end
end
