# frozen_string_literal: true

module Purchasing
  class SyncPoLineVendorQuantitiesFromSourcing
    class SyncError < StandardError; end

    def self.call!(purchase_order_line:, source_response: nil)
      new(purchase_order_line:, source_response:).call!
    end

    def initialize(purchase_order_line:, source_response: nil)
      @purchase_order_line = purchase_order_line
      @source_response = source_response
    end

    def call!
      raise SyncError, "Purchase order line is required" if purchase_order_line.blank?

      PurchaseOrderLine.transaction do
        locked_line = PurchaseOrderLine.lock.find(purchase_order_line.id)
        responses = VendorResponse.where(purchase_order_line_id: locked_line.id, final_response: true)

        confirmed = responses.sum(:quantity_confirmed)
        backordered = responses.sum(:quantity_backordered)
        canceled = responses.sum(:quantity_canceled) + responses.sum(:quantity_unavailable)

        locked_line.vendor_quantity_sync_update = true
        locked_line.assign_attributes(
          quantity_confirmed_by_vendor: confirmed,
          quantity_backordered_by_vendor: backordered,
          quantity_canceled_by_vendor: canceled,
          vendor_quantities_recorded_at: Time.current,
          vendor_quantities_source_type: "sourcing_response",
          vendor_quantities_source_id: source_response&.id || responses.order(:id).last&.id
        )
        locked_line.vendor_quantity_state = PoLineQuantitySummary.for(locked_line).derive_vendor_quantity_state
        locked_line.status = PoLineStatusDeriver.derive(locked_line)
        locked_line.save!
        locked_line
      end
    end

    private

    attr_reader :purchase_order_line, :source_response
  end
end
