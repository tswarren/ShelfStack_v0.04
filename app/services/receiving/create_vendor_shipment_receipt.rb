# frozen_string_literal: true

module Receiving
  class CreateVendorShipmentReceipt
    class CreateError < StandardError; end

    def self.call!(store:, vendor:, attrs: {})
      new(store:, vendor:, attrs:).call!
    end

    def initialize(store:, vendor:, attrs: {})
      @store = store
      @vendor = vendor
      @attrs = attrs
    end

    def call!
      Receipt.create!(
        store: store,
        vendor: vendor,
        receipt_type: "direct",
        match_filter_purchase_order_id: attrs[:match_filter_purchase_order_id],
        status: "draft",
        origin_method: attrs[:origin_method] || "manual",
        receiving_mode: "vendor_shipment",
        vendor_shipment_destination: "store",
        vendor_shipment_reference: attrs[:vendor_shipment_reference],
        vendor_packing_slip_number: attrs[:vendor_packing_slip_number],
        vendor_invoice_number: attrs[:vendor_invoice_number],
        tracking_number: attrs[:tracking_number],
        received_at: attrs[:received_at]
      )
    end

    private

    attr_reader :store, :vendor, :attrs
  end
end
