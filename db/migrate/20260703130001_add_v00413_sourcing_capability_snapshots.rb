# frozen_string_literal: true

class AddV00413SourcingCapabilitySnapshots < ActiveRecord::Migration[8.0]
  def change
    change_table :sourcing_attempts, bulk: true do |t|
      t.string :availability_workflow_snapshot
      t.string :availability_source_snapshot
      t.string :order_submission_method_snapshot
      t.string :acknowledgment_method_snapshot
      t.string :shipment_notice_method_snapshot
      t.string :invoice_method_snapshot
      t.string :technical_acknowledgment_method_snapshot
      t.jsonb :fulfillment_methods_supported_snapshot
      t.string :vendor_capability_source_snapshot
    end
  end
end
