# frozen_string_literal: true

class CreatePhase7cUsedBuyback < ActiveRecord::Migration[8.1]
  def change
    change_table :customers, bulk: true do |t|
      t.string :first_name
      t.string :last_name
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :country_code, null: false, default: "US"
      t.string :region_code
      t.string :postal_code
      t.string :phone_normalized
      t.string :email_normalized
      t.date :date_of_birth
      t.string :customer_number
      t.references :created_by_user, foreign_key: { to_table: :users }
      t.references :updated_by_user, foreign_key: { to_table: :users }
      t.references :merged_into_customer, foreign_key: { to_table: :customers }
    end

    change_table :product_conditions, bulk: true do |t|
      t.boolean :buyback_eligible, null: false, default: false
      t.boolean :buyback_default, null: false, default: false
      t.integer :buyback_sort_order
      t.integer :buyback_price_factor_bps
      t.boolean :buyback_requires_review, null: false, default: false
    end

    create_table :buyback_sequences do |t|
      t.references :workstation, null: false, foreign_key: true, index: { unique: true }
      t.integer :last_sequence, null: false, default: 0
      t.timestamps
    end

    create_table :buyback_sessions do |t|
      t.string :buyback_number
      t.references :store, null: false, foreign_key: true
      t.references :workstation, foreign_key: true
      t.references :pos_register_session, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string :status, null: false, default: "draft"
      t.string :payout_mode
      t.date :business_date
      t.integer :total_cash_offer_cents, null: false, default: 0
      t.integer :total_trade_credit_offer_cents, null: false, default: 0
      t.integer :accepted_payout_cents, null: false, default: 0
      t.integer :donation_value_cents, null: false, default: 0
      t.references :stored_value_account, foreign_key: true
      t.references :stored_value_ledger_entry, foreign_key: { to_table: :stored_value_ledger_entries }
      t.references :pos_cash_movement, foreign_key: true
      t.references :inventory_posting, foreign_key: true
      t.boolean :needs_label, null: false, default: true
      t.boolean :needs_review, null: false, default: false
      t.boolean :needs_cleaning, null: false, default: false
      t.boolean :hold_for_review, null: false, default: false
      t.text :processing_notes
      t.datetime :quoted_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.datetime :voided_at
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.references :completed_by_user, foreign_key: { to_table: :users }
      t.references :cancelled_by_user, foreign_key: { to_table: :users }
      t.references :voided_by_user, foreign_key: { to_table: :users }
      t.text :void_reason
      t.text :notes
      t.string :seller_display_name_snapshot
      t.string :seller_first_name_snapshot
      t.string :seller_last_name_snapshot
      t.string :seller_address_line1_snapshot
      t.string :seller_address_line2_snapshot
      t.string :seller_city_snapshot
      t.string :seller_region_code_snapshot
      t.string :seller_postal_code_snapshot
      t.string :seller_country_code_snapshot
      t.string :seller_phone_snapshot
      t.string :seller_email_snapshot
      t.boolean :seller_identity_verified, null: false, default: false
      t.boolean :seller_age_confirmed, null: false, default: false
      t.datetime :seller_terms_accepted_at
      t.datetime :seller_signature_captured_at
      t.timestamps
    end

    add_index :buyback_sessions, :buyback_number, unique: true, where: "buyback_number IS NOT NULL"
    add_index :buyback_sessions, %i[store_id status]

    create_table :buyback_pricing_rules do |t|
      t.string :name, null: false
      t.references :sub_department, foreign_key: true
      t.references :product_condition, foreign_key: true
      t.string :base_price_source, null: false, default: "variant_selling_price"
      t.integer :resale_price_factor_bps
      t.integer :cash_offer_bps, null: false
      t.integer :trade_credit_offer_bps, null: false
      t.integer :minimum_offer_cents, null: false, default: 0
      t.integer :maximum_offer_cents
      t.integer :rounding_increment_cents, null: false, default: 100
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    create_table :buyback_reject_reasons do |t|
      t.string :reason_key, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    add_index :buyback_reject_reasons, :reason_key, unique: true

    create_table :buyback_lines do |t|
      t.references :buyback_session, null: false, foreign_key: true
      t.integer :line_number, null: false
      t.string :status, null: false, default: "pending"
      t.string :outcome
      t.references :catalog_item, foreign_key: true
      t.references :product, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.references :created_catalog_item, foreign_key: { to_table: :catalog_items }
      t.references :created_product, foreign_key: { to_table: :products }
      t.references :created_product_variant, foreign_key: { to_table: :product_variants }
      t.references :product_condition, foreign_key: true
      t.references :buyback_pricing_rule, foreign_key: true
      t.references :buyback_reject_reason, foreign_key: true
      t.string :identifier_entered
      t.string :identifier_normalized
      t.string :title_snapshot
      t.string :creator_snapshot
      t.string :format_snapshot
      t.string :condition_snapshot
      t.string :variant_sku_snapshot
      t.references :sub_department, foreign_key: true
      t.integer :list_price_cents
      t.integer :current_selling_price_cents
      t.integer :suggested_resale_price_cents
      t.integer :accepted_resale_price_cents
      t.integer :suggested_cash_offer_cents
      t.integer :suggested_trade_credit_offer_cents
      t.integer :accepted_offer_cents
      t.boolean :resale_price_overridden, null: false, default: false
      t.boolean :offer_overridden, null: false, default: false
      t.text :override_reason
      t.boolean :signed_copy, null: false, default: false
      t.text :special_notes
      t.boolean :needs_label, null: false, default: true
      t.boolean :needs_review, null: false, default: false
      t.boolean :needs_cleaning, null: false, default: false
      t.boolean :hold_for_review, null: false, default: false
      t.integer :quantity, null: false, default: 1
      t.references :inventory_ledger_entry, foreign_key: true
      t.references :void_inventory_ledger_entry, foreign_key: { to_table: :inventory_ledger_entries }
      t.text :notes
      t.timestamps
    end

    add_index :buyback_lines, %i[buyback_session_id line_number], unique: true

    create_table :buyback_voids do |t|
      t.references :buyback_session, null: false, foreign_key: true, index: { unique: true }
      t.references :store, null: false, foreign_key: true
      t.references :workstation, null: false, foreign_key: true
      t.references :pos_register_session, foreign_key: true
      t.datetime :voided_at, null: false
      t.references :voided_by_user, null: false, foreign_key: { to_table: :users }
      t.text :void_reason, null: false
      t.references :pos_authorization, foreign_key: true
      t.references :inventory_posting, foreign_key: true
      t.references :void_stored_value_ledger_entry, foreign_key: { to_table: :stored_value_ledger_entries }
      t.references :void_cash_movement, foreign_key: { to_table: :pos_cash_movements }
      t.text :notes
      t.timestamps
    end

    %i[catalog_items products product_variants].each do |table|
      change_table table, bulk: true do |t|
        t.string :source, null: false, default: "manual"
        t.boolean :needs_review, null: false, default: false
        t.references :created_from_buyback_session, foreign_key: { to_table: :buyback_sessions }
      end
    end

    change_table :pos_cash_movements, bulk: true do |t|
      t.string :source_type
      t.bigint :source_id
      t.references :reverses_cash_movement, foreign_key: { to_table: :pos_cash_movements }
    end

    add_index :pos_cash_movements, %i[source_type source_id]
  end
end
