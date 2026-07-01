# frozen_string_literal: true

class CreateV0046DemandFoundation < ActiveRecord::Migration[8.0]
  def change
    create_table :demand_line_sequences do |t|
      t.references :store, null: false, foreign_key: true, index: { unique: true }
      t.integer :last_sequence, null: false, default: 0
      t.timestamps
    end

    create_table :stock_considerations do |t|
      t.references :store, null: false, foreign_key: true
      t.string :status, null: false, default: "open"
      t.references :product, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.string :provisional_title
      t.string :provisional_identifier
      t.string :provisional_creator
      t.text :reason
      t.string :priority
      t.integer :quantity_suggested
      t.text :notes
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.references :reviewed_by_user, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.references :converted_by_user, foreign_key: { to_table: :users }
      t.datetime :converted_at
      t.references :dismissed_by_user, foreign_key: { to_table: :users }
      t.datetime :dismissed_at
      t.text :dismiss_reason
      t.timestamps
    end

    add_index :stock_considerations, %i[store_id status]

    create_table :demand_lines do |t|
      t.references :store, null: false, foreign_key: true
      t.string :demand_number, null: false
      t.string :source, null: false
      t.string :purpose, null: false
      t.string :capture_intent
      t.string :status, null: false, default: "open"
      t.references :product, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.references :customer, foreign_key: true
      t.string :customer_name_snapshot
      t.string :customer_email_snapshot
      t.string :customer_phone_snapshot
      t.string :preferred_contact_method
      t.integer :quantity_requested, null: false, default: 1
      t.date :needed_by_date
      t.datetime :expires_at
      t.string :provisional_title
      t.string :provisional_identifier
      t.string :provisional_creator
      t.text :notes
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.references :matched_by_user, foreign_key: { to_table: :users }
      t.datetime :matched_at
      t.references :canceled_by_user, foreign_key: { to_table: :users }
      t.datetime :canceled_at
      t.text :cancel_reason
      t.references :expired_by_user, foreign_key: { to_table: :users }
      t.datetime :expired_at
      t.references :stock_consideration, foreign_key: true
      t.timestamps
    end

    add_index :demand_lines, %i[store_id demand_number], unique: true
    add_index :demand_lines, %i[store_id status]
    add_index :demand_lines, %i[source purpose status]
    add_check_constraint :demand_lines, "quantity_requested > 0", name: "chk_demand_lines_quantity_requested"
  end
end
