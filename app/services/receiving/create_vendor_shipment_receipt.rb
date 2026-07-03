# frozen_string_literal: true

module Receiving
  class CreateVendorShipmentReceipt
    class CreateError < StandardError; end

    def self.call!(store:, vendor:, created_by_user:, attrs: {})
      new(store:, vendor:, created_by_user:, attrs:).call!
    end

    def initialize(store:, vendor:, created_by_user:, attrs: {})
      @store = store
      @vendor = vendor
      @created_by_user = created_by_user
      @attrs = attrs
    end

    def call!
      Receipt.create!(
        store: store,
        vendor: vendor,
        receipt_type: attrs[:purchase_order_id].present? ? "po_backed" : "direct",
        purchase_order_id: attrs[:purchase_order_id],
        status: "draft",
        origin_method: attrs[:origin_method] || "manual",
        receiving_mode: receiving_mode,
        vendor_shipment_destination: "store",
        vendor_shipment_reference: attrs[:vendor_shipment_reference],
        vendor_packing_slip_number: attrs[:vendor_packing_slip_number],
        vendor_invoice_number: attrs[:vendor_invoice_number],
        tracking_number: attrs[:tracking_number],
        received_at: attrs[:received_at]
      )
    end

    private

    attr_reader :store, :vendor, :created_by_user, :attrs

    def receiving_mode
      return "single_po" if attrs[:purchase_order_id].present?
      return "direct" if attrs[:direct]

      "vendor_shipment"
    end
  end
end
