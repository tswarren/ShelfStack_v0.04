# frozen_string_literal: true

class DropV00410LegacyOrdering < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :pos_transaction_lines, :inventory_reservations, if_exists: true
    remove_foreign_key :pos_transaction_lines, :customer_request_lines, if_exists: true
    remove_foreign_key :pos_transaction_lines, :special_orders, if_exists: true
    remove_foreign_key :purchase_order_lines, :purchase_request_lines, if_exists: true
    remove_foreign_key :customer_contact_events, :customer_requests, if_exists: true
    remove_foreign_key :customer_contact_events, :customer_request_lines, if_exists: true

    remove_reference :pos_transaction_lines, :inventory_reservation, if_exists: true
    remove_reference :pos_transaction_lines, :customer_request_line, if_exists: true
    remove_reference :pos_transaction_lines, :special_order, if_exists: true
    remove_reference :purchase_order_lines, :purchase_request_line, if_exists: true
    remove_reference :customer_contact_events, :customer_request, if_exists: true
    remove_reference :customer_contact_events, :customer_request_line, if_exists: true

    drop_table :receipt_line_allocations, if_exists: true
    drop_table :purchase_order_line_allocations, if_exists: true
    drop_table :inventory_reservations, if_exists: true
    drop_table :purchase_request_lines, if_exists: true
    drop_table :purchase_requests, if_exists: true
    drop_table :special_orders, if_exists: true
    drop_table :customer_request_lines, if_exists: true
    drop_table :customer_requests, if_exists: true
    drop_table :customer_request_sequences, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
