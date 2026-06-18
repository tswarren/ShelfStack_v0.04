# frozen_string_literal: true

class AddPurchaseRequestLineToPurchaseOrderLines < ActiveRecord::Migration[8.0]
  def change
    add_reference :purchase_order_lines, :purchase_request_line, foreign_key: true, index: true
  end
end
