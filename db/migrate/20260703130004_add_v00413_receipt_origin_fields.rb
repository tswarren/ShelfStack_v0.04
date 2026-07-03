# frozen_string_literal: true

class AddV00413ReceiptOriginFields < ActiveRecord::Migration[8.0]
  def change
    change_table :receipts, bulk: true do |t|
      t.string :origin_method, null: false, default: "manual"
      t.string :receiving_mode, null: false, default: "vendor_shipment"
      t.string :vendor_shipment_destination, null: false, default: "store"
      t.string :vendor_shipment_reference
      t.string :vendor_packing_slip_number
      t.string :vendor_invoice_number
      t.string :tracking_number
      t.datetime :received_at
    end

    change_table :receipt_lines, bulk: true do |t|
      t.string :origin_method
      t.string :external_line_reference
      t.string :vendor_line_reference
      t.integer :shipment_notice_quantity
    end
  end
end
