# frozen_string_literal: true

class AddPhase7aPosCustomerLinks < ActiveRecord::Migration[8.1]
  def change
    add_reference :pos_transactions, :customer, foreign_key: true

    add_reference :pos_transaction_lines, :customer_request_line, foreign_key: true
    add_reference :pos_transaction_lines, :special_order, foreign_key: true
    add_reference :pos_transaction_lines, :inventory_reservation, foreign_key: true
  end
end
