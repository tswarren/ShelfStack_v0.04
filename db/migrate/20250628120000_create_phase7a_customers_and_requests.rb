# frozen_string_literal: true

class CreatePhase7aCustomersAndRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.references :home_store, foreign_key: { to_table: :stores }
      t.string :display_name, null: false
      t.string :email
      t.string :phone
      t.string :preferred_contact_method
      t.text :notes
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :customers, :active
    add_index :customers, :display_name

    create_table :customer_request_sequences do |t|
      t.references :store, null: false, foreign_key: true, index: { unique: true }
      t.integer :last_sequence, null: false, default: 0
      t.timestamps
    end

    create_table :customer_requests do |t|
      t.references :store, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.string :request_number, null: false
      t.string :status, null: false, default: "new"
      t.string :source, null: false, default: "in_store"
      t.string :preferred_contact_method
      t.date :needed_by_date
      t.datetime :expires_at
      t.references :assigned_to_user, foreign_key: { to_table: :users }
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :last_contacted_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.text :cancellation_reason
      t.text :unfillable_reason
      t.string :customer_name_snapshot
      t.string :customer_email_snapshot
      t.string :customer_phone_snapshot
      t.text :notes
      t.timestamps
    end

    add_index :customer_requests, %i[store_id request_number], unique: true
    add_index :customer_requests, %i[store_id status]

    create_table :customer_request_lines do |t|
      t.references :customer_request, null: false, foreign_key: true
      t.integer :line_number, null: false
      t.string :request_type, null: false
      t.string :status, null: false, default: "new"
      t.references :catalog_item, foreign_key: true
      t.references :product, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.integer :requested_quantity, null: false, default: 1
      t.integer :approved_quantity, null: false, default: 0
      t.integer :ordered_quantity, null: false, default: 0
      t.integer :filled_quantity, null: false, default: 0
      t.integer :cancelled_quantity, null: false, default: 0
      t.string :provisional_title
      t.string :provisional_creator
      t.string :provisional_identifier
      t.string :provisional_format
      t.integer :quoted_price_cents
      t.integer :max_customer_price_cents
      t.text :notes
      t.timestamps
    end

    add_index :customer_request_lines, %i[customer_request_id line_number], unique: true,
              name: "idx_customer_request_lines_request_line_number"
    add_index :customer_request_lines, %i[status request_type]

    add_check_constraint :customer_request_lines, "requested_quantity > 0",
                         name: "chk_customer_request_lines_requested_quantity"
    add_check_constraint :customer_request_lines, "approved_quantity >= 0",
                         name: "chk_customer_request_lines_approved_quantity"
    add_check_constraint :customer_request_lines, "ordered_quantity >= 0",
                         name: "chk_customer_request_lines_ordered_quantity"
    add_check_constraint :customer_request_lines, "filled_quantity >= 0",
                         name: "chk_customer_request_lines_filled_quantity"
    add_check_constraint :customer_request_lines, "cancelled_quantity >= 0",
                         name: "chk_customer_request_lines_cancelled_quantity"
  end
end
