# frozen_string_literal: true

class AddV00413VendorCapabilities < ActiveRecord::Migration[8.0]
  def change
    change_table :vendors, bulk: true do |t|
      t.string :availability_workflow, null: false, default: "manual_review"
      t.string :availability_source, null: false, default: "manual"
      t.string :order_submission_method, null: false, default: "manual"
      t.string :acknowledgment_method, null: false, default: "manual"
      t.string :shipment_notice_method, null: false, default: "none"
      t.string :invoice_method, null: false, default: "manual"
      t.string :technical_acknowledgment_method, null: false, default: "none"
      t.jsonb :fulfillment_methods_supported, null: false, default: ["ship_to_store"]
    end
  end
end
