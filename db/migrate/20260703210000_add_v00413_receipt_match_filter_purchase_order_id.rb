# frozen_string_literal: true

class AddV00413ReceiptMatchFilterPurchaseOrderId < ActiveRecord::Migration[8.0]
  def change
    add_reference :receipts, :match_filter_purchase_order, foreign_key: { to_table: :purchase_orders }, index: true
  end
end
