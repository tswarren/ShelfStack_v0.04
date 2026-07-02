# frozen_string_literal: true

module Sourcing
  class ValidatePoLineLink
    class ValidationError < StandardError; end

    def self.call!(demand_line:, purchase_order_line:, quantity: nil)
      new(demand_line:, purchase_order_line:, quantity:).call!
    end

    def initialize(demand_line:, purchase_order_line:, quantity: nil)
      @demand_line = demand_line
      @purchase_order_line = purchase_order_line
      @quantity = quantity&.to_i
    end

    def call!
      raise ValidationError, "Purchase order line is required" if purchase_order_line.blank?

      if demand_line.store_id != purchase_order_line.purchase_order.store_id
        raise ValidationError, "Purchase order line must belong to the same store"
      end

      if demand_line.product_variant_id != purchase_order_line.product_variant_id
        raise ValidationError, "Purchase order line variant must match demand line"
      end

      inbound = DemandAllocations::InboundAvailability.new(purchase_order_line: purchase_order_line)
      unless inbound.eligible?
        raise ValidationError, "Purchase order line is not eligible for inbound allocation"
      end

      if quantity.present? && quantity.positive?
        available = inbound.available_for
        if quantity > available
          raise ValidationError, "Insufficient inbound quantity (#{available})"
        end
      end

      true
    end

    private

    attr_reader :demand_line, :purchase_order_line, :quantity
  end
end
