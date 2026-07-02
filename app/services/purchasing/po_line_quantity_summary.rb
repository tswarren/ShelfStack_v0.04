# frozen_string_literal: true

module Purchasing
  class PoLineQuantitySummary
    VENDOR_QUANTITY_STATES = %w[
      unconfirmed
      partially_confirmed
      confirmed
      backordered
      canceled
      mixed
    ].freeze

    def self.for(purchase_order_line)
      new(purchase_order_line)
    end

    def initialize(purchase_order_line)
      @purchase_order_line = purchase_order_line
    end

    def vendor_quantities_recorded?
      purchase_order_line.vendor_quantities_recorded_at.present?
    end

    def accepted_quantity
      purchase_order_line.quantity_received.to_i
    end

    def closed_short_quantity
      purchase_order_line.quantity_closed_short.to_i
    end

    def effective_inbound_supply
      base = vendor_quantities_recorded? ? purchase_order_line.quantity_confirmed_by_vendor.to_i : purchase_order_line.quantity_ordered.to_i
      [ base - accepted_quantity - closed_short_quantity, 0 ].max
    end

    def open_to_receive_quantity
      effective_inbound_supply
    end

    def open_supply_before_allocation_claims
      effective_inbound_supply
    end

    def derive_vendor_quantity_state
      return "unconfirmed" unless vendor_quantities_recorded?

      ordered = purchase_order_line.quantity_ordered.to_i
      confirmed = purchase_order_line.quantity_confirmed_by_vendor.to_i
      backordered = purchase_order_line.quantity_backordered_by_vendor.to_i
      canceled = purchase_order_line.quantity_canceled_by_vendor.to_i

      positive_buckets = [ confirmed, backordered, canceled ].count(&:positive?)
      return "mixed" if positive_buckets > 1
      return "canceled" if canceled.positive? && canceled >= ordered
      return "backordered" if backordered.positive?
      return "confirmed" if confirmed == ordered
      return "partially_confirmed" if confirmed.positive?
      return "canceled" if ordered.positive?

      "unconfirmed"
    end

    private

    attr_reader :purchase_order_line
  end
end
